{ pkgs, lib, ... }:
let
  proxy = pkgs.writeShellApplication {
    name = "mac-llm-ssh-proxy";
    runtimeInputs = [ pkgs.netcat-openbsd ];
    text = ''
      case "''${MAC_LLM_ROUTE:-auto}" in
        lan) exec nc 192.168.1.190 22 ;;
        public) exec nc home.munchy.gay 2223 ;;
        auto)
          if nc -z -w 2 192.168.1.190 22; then
            exec nc 192.168.1.190 22
          fi
          exec nc home.munchy.gay 2223
          ;;
        *) echo "MAC_LLM_ROUTE must be auto, lan or public" >&2; exit 1 ;;
      esac
    '';
  };
  # Separate explicit SSH config avoids interactive TTY settings and pins the
  # same Mac host key already used by DesktopWake in shared.nix.
  sshConfig = pkgs.writeText "mac-llm-ssh-config" ''
    Host MacLLM
      HostName home.munchy.gay
      Port 2223
      ProxyCommand ${proxy}/bin/mac-llm-ssh-proxy
      User lee
      RequestTTY no
      StrictHostKeyChecking yes
      HostKeyAlias mac-llm
      UserKnownHostsFile ${pkgs.writeText "mac-llm-known-hosts" ''
        mac-llm ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDu2uN52fnfRHaVsX03qMXg0PCZYx8U/KX7cB+hInR5+
      ''}
  '';
  helper = name: action: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.python3 pkgs.claude-code pkgs.openssh ];
    text = ''
${lib.optionalString (!pkgs.stdenv.hostPlatform.isDarwin) "export MAC_LLM_SSH_CONFIG=${sshConfig}"}
      exec python3 ${./mac-llm.py} ${action} "$@"
    '';
  };
in {
  home.packages = [
    (helper "mac-code" "code")
    (helper "mac-code-status" "status")
  ];
}
