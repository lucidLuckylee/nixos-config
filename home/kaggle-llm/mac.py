"""One SSH tunnel per invocation; source and tools stay in the local cwd."""
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

from client import NoRedirect, agent_command

MODEL = 'qwen3.5-9b'
KEY_FILE = '.config/mac-llm/api-key'


def ready(root, key):
    req = urllib.request.Request(root + '/v1/models', headers={'Authorization': 'Bearer ' + key})
    with urllib.request.build_opener(NoRedirect).open(req, timeout=3) as response:
        return MODEL in [entry['id'] for entry in json.load(response)['data']]


def run(root, key, args):
    if not ready(root, key):
        raise ValueError('Qwen model is absent from server')
    if sys.argv[1] == 'status':
        print('Mac Qwen endpoint is authenticated and ready: ' + MODEL)
        return 0
    command, env = agent_command(root, key, MODEL, args)
    env['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] = '32768'
    return subprocess.call(command, env=env)


def main():
    if sys.platform == 'darwin':
        return run('http://127.0.0.1:8081', (Path.home() / KEY_FILE).read_text().strip(), sys.argv[2:])
    ssh = ['ssh', '-F', os.environ['MAC_LLM_SSH_CONFIG'], '-T',
           '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=30',
           '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3']
    key = subprocess.check_output(ssh + ['MacLLM', 'cat ~/.config/mac-llm/api-key'], text=True).strip()
    if not key or any(c in key for c in '\r\n'):
        raise ValueError('invalid server key')
    # Ask the OS for a free port. Each concurrent agent gets its own tunnel.
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    tunnel = subprocess.Popen(ssh + ['-N', '-o', 'ExitOnForwardFailure=yes',
                                    '-L', f'127.0.0.1:{port}:127.0.0.1:8081', 'MacLLM'])
    try:
        root = f'http://127.0.0.1:{port}'
        deadline = time.monotonic() + 20
        while True:
            if tunnel.poll() is not None:
                raise ValueError('SSH tunnel failed')
            try:
                if ready(root, key):
                    break
            except urllib.error.HTTPError:
                raise ValueError('Mac server is loading or authentication failed; check its log') from None
            except urllib.error.URLError:
                if time.monotonic() >= deadline:
                    raise ValueError('Mac server is unavailable; check its log') from None
                time.sleep(0.25)
        return run(root, key, sys.argv[2:])
    finally:
        tunnel.terminate()
        try:
            tunnel.wait(timeout=5)
        except subprocess.TimeoutExpired:
            tunnel.kill()
            tunnel.wait()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
    except (ValueError, OSError, KeyError, subprocess.SubprocessError) as exc:
        # Never print HTTP response bodies or remote key output.
        if isinstance(exc, ValueError):
            sys.exit('mac-code: ' + str(exc))
        sys.exit('mac-code: connection failed; check SSH access and the Mac inference service')
