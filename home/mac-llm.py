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

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Never forward the bearer token to a redirect destination.



def agent_command(root, key, model, args):
    env = os.environ.copy()
    # Remove conflicting credentials/routes inherited from other providers.
    for name in tuple(env):
        if name.startswith(('ANTHROPIC_', 'MAC_LLM_')) or name in {
            'OPENAI_API_KEY', 'OPENAI_BASE_URL', 'CLAUDE_CODE_USE_BEDROCK',
            'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY'}:
            env.pop(name, None)
    env.update(ANTHROPIC_BASE_URL=root, ANTHROPIC_AUTH_TOKEN=key,
               ANTHROPIC_MODEL=model, ANTHROPIC_SMALL_FAST_MODEL=model,
               ANTHROPIC_DEFAULT_OPUS_MODEL=model, ANTHROPIC_DEFAULT_SONNET_MODEL=model,
               ANTHROPIC_DEFAULT_HAIKU_MODEL=model, CLAUDE_CODE_SUBAGENT_MODEL=model)
    # The full MCP/plugin/tool catalogue can exceed 32K before the first turn.
    # Keep project instructions, skills and hooks, but scope optional integrations
    # and the built-in tools to this invocation. Normal Claude remains unchanged.
    settings = json.dumps({
        'env': {'CLAUDE_CODE_SUBAGENT_MODEL': model},
        'enabledPlugins': {
            'dev-browser@dev-browser-marketplace': False,
            'frontend-design@claude-plugins-official': False,
            'rust-analyzer-lsp@claude-plugins-official': False,
        },
    })
    env.update(CLAUDE_CODE_MAX_CONTEXT_TOKENS='32768',
               CLAUDE_CODE_AUTO_COMPACT_WINDOW='24576',
               CLAUDE_CODE_MAX_OUTPUT_TOKENS='4096')
    return ['claude', '--settings', settings, '--model', model,
            # Auto mode's separate safety-classifier prompt also exceeds 32K.
            # Skip prompts as requested; project safety hooks still run.
            '--permission-mode', 'bypassPermissions',
            '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}',
            '--tools', 'Bash,Read,Edit,Write,Glob,Grep,Skill', *args], env

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
