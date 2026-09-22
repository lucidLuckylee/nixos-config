# CalDAV agenda for the Quickshell calendar. Credentials come from pass, like
# the other secrets; the server itself is public mailbox.org documentation.
{ pkgs }:

let
  python = pkgs.python3.withPackages (p: [ p.caldav ]);
in pkgs.writeShellScript "caldav-agenda" ''
  set -euo pipefail
  export PATH="${pkgs.gnupg}/bin:$PATH"
  export CALDAV_URL="https://dav.mailbox.org/caldav/"
  export CALDAV_USERNAME="$(${pkgs.pass}/bin/pass show mailbox.org/caldav/username)"
  export CALDAV_PASSWORD="$(${pkgs.pass}/bin/pass show mailbox.org/caldav/password)"
  exec ${python}/bin/python3 ${./agenda.py} "$@"
''
