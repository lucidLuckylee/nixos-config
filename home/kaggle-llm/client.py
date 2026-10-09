"""Runtime-only credentials and process-scoped Claude Code provider selection."""
import json
import os
from pathlib import Path
import shlex
import stat
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


def load():
    values = {}
    path = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'kaggle-llm/env'
    if path.exists():
        info = path.stat()
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) & 0o077:
            raise ValueError('runtime env file must be owned by you with mode 0600')
        for line in path.read_text().splitlines():
            parts = shlex.split(line, comments=True)
            if parts and parts[0] == 'export':
                parts = parts[1:]
            if not parts:
                continue
            if len(parts) != 1 or '=' not in parts[0]:
                raise ValueError('env file accepts literal KEY=value assignments only')
            key, value = parts[0].split('=', 1)
            if key not in {'KAGGLE_LLM_URL', 'KAGGLE_LLM_API_KEY', 'KAGGLE_LLM_MODEL', 'KAGGLE_LLM_PASS_ENTRY'}:
                raise ValueError('unknown setting in runtime env file')
            values[key] = value
    for key in ('KAGGLE_LLM_URL', 'KAGGLE_LLM_API_KEY', 'KAGGLE_LLM_MODEL', 'KAGGLE_LLM_PASS_ENTRY'):
        if key in os.environ:
            values[key] = os.environ[key]
    url = values.get('KAGGLE_LLM_URL', '').rstrip('/')
    parsed = urllib.parse.urlsplit(url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password
            or parsed.query or parsed.fragment or parsed.path not in ('', '/v1')):
        raise ValueError('KAGGLE_LLM_URL must be an HTTPS server URL, optionally ending in /v1')
    root = url[:-3] if url.endswith('/v1') else url
    key = values.get('KAGGLE_LLM_API_KEY', '')
    if not key and values.get('KAGGLE_LLM_PASS_ENTRY'):
        result = subprocess.run(['pass', 'show', values['KAGGLE_LLM_PASS_ENTRY']],
                                capture_output=True, text=True, check=True)
        key = result.stdout.splitlines()[0] if result.stdout else ''
    if not key or any(c in key for c in '\r\n'):
        raise ValueError('set KAGGLE_LLM_API_KEY or KAGGLE_LLM_PASS_ENTRY')
    return root, key, values.get('KAGGLE_LLM_MODEL', 'qwen3.8-27b')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None  # Never forward the bearer token to a redirect destination.


def main():
    root, key, model = load()
    if sys.argv[1] == 'status':
        opener = urllib.request.build_opener(NoRedirect)
        req = urllib.request.Request(root + '/v1/models', headers={'Authorization': 'Bearer ' + key})
        with opener.open(req, timeout=30) as response:
            models = [item['id'] for item in json.load(response)['data']]
        if model not in models:
            raise ValueError('configured model is absent from authenticated /v1/models')
        print('Authenticated endpoint is ready; model: ' + model)
        return
    env = os.environ.copy()
    # Remove conflicting credentials/routes inherited from other providers.
    for name in tuple(env):
        if name.startswith(('ANTHROPIC_', 'KAGGLE_LLM_')) or name in {
            'OPENAI_API_KEY', 'OPENAI_BASE_URL', 'CLAUDE_CODE_USE_BEDROCK',
            'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY'}:
            env.pop(name, None)
    env.update(ANTHROPIC_BASE_URL=root, ANTHROPIC_AUTH_TOKEN=key,
               ANTHROPIC_MODEL=model, ANTHROPIC_SMALL_FAST_MODEL=model,
               ANTHROPIC_DEFAULT_OPUS_MODEL=model, ANTHROPIC_DEFAULT_SONNET_MODEL=model,
               ANTHROPIC_DEFAULT_HAIKU_MODEL=model, CLAUDE_CODE_SUBAGENT_MODEL=model)
    # Override the managed haiku subagent setting for this invocation only.
    settings = json.dumps({'env': {'CLAUDE_CODE_SUBAGENT_MODEL': model}})
    os.execvpe('claude', ['claude', '--settings', settings, '--model', model, *sys.argv[2:]], env)


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as exc:
        sys.exit('kaggle-code: endpoint returned HTTP ' + str(exc.code))
    except (ValueError, OSError, KeyError, subprocess.SubprocessError):
        sys.exit('kaggle-code: configuration or connection failed; check HTTPS URL, model, credentials, file mode (0600), and server readiness')
