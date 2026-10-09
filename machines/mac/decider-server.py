"""Authenticated, serialized Jev Choice adapter for the native Decider readout."""
import hmac
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import subprocess
import sys
import time


def main():
    command, model, calibration, key_file = sys.argv[1:]
    cfg = json.loads(Path(calibration).read_text())
    if cfg.get('version') != '2b-v11' or cfg.get('layout') != 'plain':
        raise ValueError('expected Decider 2b v11, plain prompt layout')
    temperature = cfg['temperature_by_type']['choice']
    key = Path(key_file).read_text().strip()
    if not key:
        raise ValueError('empty authentication key')
    engine = subprocess.Popen([command, model], stdin=subprocess.PIPE,
                              stdout=subprocess.PIPE, text=True, bufsize=1)
    if not json.loads(engine.stdout.readline()).get('ready'):
        raise RuntimeError('Decider failed to load')

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Do not log authorization headers, page content or task inputs.

        def reply(self, status, body):
            data = json.dumps(body).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def authenticated(self):
            if not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + key):
                self.reply(401, {'error': 'authentication required'})
                return False
            return True

        def do_GET(self):
            if self.authenticated():
                self.reply(200 if self.path == '/health' else 404,
                           {'model': 'Mapika/decider-2b', 'version': 'v11', 'backend': 'llama.cpp Metal', 'ready': True})

        def do_POST(self):
            if not self.authenticated():
                return
            if self.path != '/v1/systemone':
                self.reply(404, {'error': 'use /v1/systemone'})
                return
            try:
                self.connection.settimeout(15)
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 65536:
                    raise ValueError('request must contain 1..65536 bytes')
                body = json.loads(self.rfile.read(length))
                questions = body['questions']
                if len(questions) != 1:
                    raise ValueError('one Choice field required: all candidates share one forward pass')
                name, spec = next(iter(questions.items()))
                if spec.get('type', 'choice') != 'choice':
                    raise ValueError('this browser adapter supports Choice fields')
                criteria = spec['criteria']
                if not isinstance(criteria, dict) or not 2 <= len(criteria) <= 255:
                    raise ValueError('2..255 candidate criteria required')
                names = list(criteria)
                options = [n if criteria[n] in (None, '') else n + ': ' + str(criteria[n]) for n in names]
                state = body['state']
                context = state if isinstance(state, str) else json.dumps(state, ensure_ascii=False)
                request = {'context': context, 'question': spec['instructions'],
                           'options': options, 'temperature': temperature}
                started = time.monotonic()
                engine.stdin.write(json.dumps(request) + '\n'); engine.stdin.flush()
                output = engine.stdout.readline()
                if not output:
                    raise RuntimeError('Decider worker disconnected')
                result = json.loads(output)
                if 'error' in result:
                    raise ValueError(result['error'])
                probs = result.pop('probabilities')
                chosen = result.pop('index')
                self.reply(200, {'model': 'Mapika/decider-2b', 'version': 'v11',
                    'answers': {name: {'choice': names[chosen], 'confidence': probs[chosen],
                                       'probs': dict(zip(names, probs))}},
                    'stats': {**result, 'elapsed_ms': round((time.monotonic()-started)*1000, 1)}})
            except (ValueError, KeyError, TypeError):
                self.reply(400, {'error': 'invalid or oversized decision request'})
            except (OSError, RuntimeError):
                self.reply(503, {'error': 'Decider worker unavailable'})

    # One request at a time: concurrent local agents queue for this model.
    server = HTTPServer(('127.0.0.1', 8082), Handler)
    server.timeout = 30
    print('Decider 2b v11 ready on authenticated localhost:8082', flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
        engine.stdin.close()
        engine.wait(timeout=10)


if __name__ == '__main__':
    main()
