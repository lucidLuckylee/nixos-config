# Qwen inference only: no development repositories are copied to this service.
{ pkgs, ... }:
let
  data = "/Users/lee/Library/Application Support/mac-llm";
  keyDir = "/Users/lee/.config/mac-llm";
  server = pkgs.writeShellScript "mac-llm-server" ''
    set -eu
    umask 077
    mkdir -p '${data}' '${keyDir}'
    chmod 700 '${keyDir}'
    if [ ! -s '${keyDir}/api-key' ]; then
      ${pkgs.openssl}/bin/openssl rand -hex 32 > '${keyDir}/api-key'
    fi
    chmod 600 '${keyDir}/api-key'
    export HOME=/Users/lee
    export LLAMA_CACHE='${data}'
    # Keep the inference host reachable during idle periods, including away from home.
    exec /usr/bin/caffeinate -i ${pkgs.llama-cpp}/bin/llama-server \
      --hf-repo unsloth/Qwen3.5-9B-GGUF \
      --hf-file Qwen3.5-9B-Q5_K_M.gguf \
      --no-mmproj --alias qwen3.5-9b \
      --host 127.0.0.1 --port 8081 \
      --api-key-file '${keyDir}/api-key' \
      --jinja --chat-template-file ${./qwen3.5-agent.jinja} --ctx-size 32768 --parallel 1 \
      --n-gpu-layers 99 --flash-attn on
  '';
in {
  environment.systemPackages = [ pkgs.llama-cpp ];

  # A daemon running as lee also works before a GUI login. Wait for the
  # encrypted Nix volume just as window-manager.nix does.
  launchd.daemons.mac-llm.serviceConfig = {
    ProgramArguments = [ "/bin/sh" "-c" ''
      n=0
      while [ ! -x '${server}' ] && [ "$n" -lt 120 ]; do
        sleep 1
        n=$((n + 1))
      done
      exec '${server}'
    '' ];
    UserName = "lee";
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 30;
    StandardOutPath = "/Users/lee/Library/Logs/mac-llm.log";
    StandardErrorPath = "/Users/lee/Library/Logs/mac-llm.log";
  };
}
