# CalDAV agenda for the Quickshell calendar. Credentials come from pass, like
# the other secrets; each account's entry holds `username` and `password`.
# `calendars` limits an account to those calendar names; omit it for all.
{ pkgs }:

let
  python = pkgs.python3.withPackages (p: [ p.caldav ]);

  accounts = [
    { name = "mailbox"; url = "https://dav.mailbox.org/caldav/"; entry = "mailbox.org/caldav"; }
    # iCloud needs an app-specific password from appleid.apple.com.
    { name = "icloud";  url = "https://caldav.icloud.com/";      entry = "icloud/caldav";
      calendars = [ "Privat" ]; }
  ];

  pass = "${pkgs.pass}/bin/pass";
  upper = pkgs.lib.toUpper;
  exports = account: ''
    export CALDAV_${upper account.name}_URL="${account.url}"
    export CALDAV_${upper account.name}_USERNAME="$(${pass} show ${account.entry}/username)"
    export CALDAV_${upper account.name}_PASSWORD="$(${pass} show ${account.entry}/password)"
  '' + pkgs.lib.optionalString (account ? calendars) ''
    export CALDAV_${upper account.name}_CALENDARS='${builtins.toJSON account.calendars}'
  '';
in pkgs.writeShellScript "caldav-agenda" ''
  set -euo pipefail
  export PATH="${pkgs.gnupg}/bin:$PATH"
  export CALDAV_ACCOUNTS="${pkgs.lib.concatMapStringsSep " " (a: a.name) accounts}"
  ${pkgs.lib.concatMapStrings exports accounts}
  exec ${python}/bin/python3 ${./agenda.py} "$@"
''
