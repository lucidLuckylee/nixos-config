{ config, pkgs, lib, ... }:

# pass with its store cloned from GitHub, so every machine shares one set of
# secrets. The store lives outside the flake; only the clone is automated.

let
  store = "${config.home.homeDirectory}/.password-store";
  repo = "git@github.com:lucidLuckylee/pass-store.git";
in {
  programs.password-store = {
    enable = true;
    settings.PASSWORD_STORE_DIR = store;
  };

  # Clone if missing, fast-forward otherwise. Runs at activation on every
  # platform and from the Linux timer in linux.nix. Host keys are accepted on
  # first contact because nothing can answer a prompt here.
  home.file.".local/bin/pass-store-sync" = {
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      set -eu
      export PATH="${lib.makeBinPath [ pkgs.git pkgs.openssh ]}:$PATH"
      export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
      if [ -d "${store}/.git" ]; then
        git -C "${store}" pull --ff-only --quiet
      else
        git clone --quiet "${repo}" "${store}"
      fi
    '';
  };

  home.activation.passStoreSync = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -z "''${DRY_RUN:-}" ]; then
      "$HOME/.local/bin/pass-store-sync" \
        || echo "pass-store: sync failed; rerun ~/.local/bin/pass-store-sync when GitHub is reachable" >&2
    fi
  '';
}
