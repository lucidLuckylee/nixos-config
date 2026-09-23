# gpg-agent pinentry that prompts in the Quickshell bar, falling back to
# pinentry-qt when the bar is not running or the request needs a full dialog.
{ pkgs }:

pkgs.writeShellScriptBin "pinentry-quickshell" ''
  export PINENTRY_FALLBACK="${pkgs.pinentry-qt}/bin/pinentry-qt"
  exec ${pkgs.python3}/bin/python3 ${./pinentry.py} "$@"
''
