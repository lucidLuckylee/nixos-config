"""Pinentry for gpg-agent that asks for passphrases in the Quickshell bar.

Every Assuan command is relayed to a fallback pinentry, except a plain GETPIN,
which goes to the bar over a Unix socket while Quickshell is listening.
Confirmations and new passphrases (SETREPEAT) stay with the fallback.
"""

import json
import os
import socket
import subprocess
import sys
from urllib.parse import unquote

SOCKET = os.path.join(
    os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"),
    "quickshell-pinentry.sock",
)
CANCELLED = "ERR 83886179 Operation cancelled <Pinentry>\n"

fallback = subprocess.Popen(
    [os.environ["PINENTRY_FALLBACK"], *sys.argv[1:]],
    stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
)


def send(line):
    sys.stdout.write(line)
    sys.stdout.flush()


def relay(line):
    """Pass one command to the fallback and its full response back."""
    fallback.stdin.write(line)
    fallback.stdin.flush()
    while reply := fallback.stdout.readline():
        send(reply)
        if reply.startswith(("OK", "ERR")):
            return
    sys.exit(1)


def ask(prompt):
    """Return the bar's reply, or None if the bar cannot be reached."""
    try:
        with socket.socket(socket.AF_UNIX) as sock:
            sock.connect(SOCKET)
            sock.sendall((json.dumps(prompt) + "\n").encode())
            reply = sock.makefile(encoding="utf-8").readline()
    except OSError:
        return None
    return json.loads(reply) if reply else None


def encode(pin):
    return pin.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


send(fallback.stdout.readline())

prompt = {}
repeat = False
for line in sys.stdin:
    command, _, arg = line.rstrip("\r\n").partition(" ")
    command = command.upper()

    if command in ("SETDESC", "SETPROMPT", "SETERROR", "SETTITLE"):
        prompt[command[3:].lower()] = unquote(arg)
    elif command == "SETREPEAT":
        repeat = True

    if command == "GETPIN" and not repeat:
        reply = ask(prompt)
        if reply is not None:
            if "pin" in reply:
                send(f"D {encode(reply['pin'])}\nOK\n")
            else:
                send(CANCELLED)
            continue

    relay(line)
    if command == "BYE":
        break
