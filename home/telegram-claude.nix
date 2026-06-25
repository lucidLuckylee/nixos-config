# Claude Code Telegram Bot
#
# Runs claude-code-telegram as a systemd user service.
# Secrets are read from pass (password-store).
#
# Setup:
#   1. Create bot via @BotFather, get your ID from @userinfobot
#   2. Store secrets in pass:
#      pass insert telegram/claude-bot/token
#      pass insert telegram/claude-bot/username
#      pass insert telegram/claude-bot/allowed-users
#   3. systemctl --user enable --now claude-telegram
#
{ pkgs, lib, config, ... }:
let
  startScript = pkgs.writeShellScript "claude-telegram-start" ''
    set -euo pipefail

    # Read secrets from pass
    export TELEGRAM_BOT_TOKEN="$(${pkgs.pass}/bin/pass show telegram/claude-bot/token)"
    export TELEGRAM_BOT_USERNAME="$(${pkgs.pass}/bin/pass show telegram/claude-bot/username)"
    export ALLOWED_USERS="$(${pkgs.pass}/bin/pass show telegram/claude-bot/allowed-users)"
    export APPROVED_DIRECTORY="/home/lucy/Projects"
    export AGENTIC_MODE=true
    export VERBOSE_LEVEL=1

    exec ${pkgs.uv}/bin/uvx \
      --python ${pkgs.python3}/bin/python3 \
      --from "git+https://github.com/RichardAtCT/claude-code-telegram@v1.3.0" \
      claude-telegram-bot
  '';
in {
  systemd.user.services.claude-telegram = {
    Unit = {
      Description = "Claude Code Telegram Bot";
      After = [ "network-online.target" "gpg-agent.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${startScript}";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = [
        "PATH=${lib.makeBinPath [ pkgs.claude-code pkgs.git pkgs.uv pkgs.pass pkgs.gnupg pkgs.coreutils pkgs.bash ]}"
        "HOME=${config.home.homeDirectory}"
        "GNUPGHOME=${config.home.homeDirectory}/.gnupg"
      ];
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
