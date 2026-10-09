# Model inference only: no development repositories are copied to these services.
{ pkgs, lib, ... }:
let
  data = "/Users/lee/Library/Application Support/mac-llm";
  keyDir = "/Users/lee/.config/mac-llm";
  makeServer = { name, repo, file, model, port, context, claude ? false }:
    pkgs.writeShellScript name ''
      set -eu
      umask 077
      mkdir -p '${data}' '${keyDir}'
      chmod 700 '${keyDir}'
      if [ ! -s '${keyDir}/api-key' ]; then
        # Both daemons may start together. Publish a complete key atomically;
        # the losing daemon uses the same key rather than replacing it.
        key_tmp=$(${pkgs.coreutils}/bin/mktemp '${keyDir}/key.XXXXXX')
        ${pkgs.openssl}/bin/openssl rand -hex 32 > "$key_tmp"
        ${pkgs.coreutils}/bin/ln "$key_tmp" '${keyDir}/api-key' 2>/dev/null || true
        ${pkgs.coreutils}/bin/rm "$key_tmp"
      fi
      test -s '${keyDir}/api-key'
      chmod 600 '${keyDir}/api-key'
      export HOME=/Users/lee
      export LLAMA_CACHE='${data}'
      exec /usr/bin/caffeinate -i ${pkgs.llama-cpp}/bin/llama-server \
        --hf-repo ${repo} --hf-file ${file} \
        --no-mmproj --alias ${model} \
        --host 127.0.0.1 --port ${toString port} \
        --api-key-file '${keyDir}/api-key' --jinja \
        ${lib.optionalString claude "--chat-template-file ${./qwen3.5-agent.jinja}"} \
        --ctx-size ${toString context} --parallel 1 \
        --cache-type-k q8_0 --cache-type-v q8_0 \
        --n-gpu-layers 99 --flash-attn on
    '';
  coding = makeServer {
    name = "mac-llm-server";
    repo = "unsloth/Qwen3.5-9B-GGUF";
    file = "Qwen3.5-9B-Q5_K_M.gguf";
    model = "qwen3.5-9b";
    port = 8081;
    context = 229376;
    claude = true;
  };
  decider = pkgs.stdenv.mkDerivation {
    pname = "decider-logits";
    version = "2b-v11";
    dontUnpack = true;
    buildInputs = [ pkgs.llama-cpp pkgs.nlohmann_json ];
    buildPhase = ''
      $CXX -std=c++17 -O2 ${./decider.cpp} \
        -I${lib.getDev pkgs.llama-cpp}/include \
        -L${lib.getLib pkgs.llama-cpp}/lib -lllama -o decider-logits
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp decider-logits $out/bin/
    '';
  };
  browsing = pkgs.writeShellScript "mac-decider-server" ''
    set -eu
    umask 077
    model_dir='${data}/decider-2b-v11'
    mkdir -p "$model_dir" '${keyDir}'
    chmod 700 '${keyDir}'
    if [ ! -s '${keyDir}/api-key' ]; then
      key_tmp=$(${pkgs.coreutils}/bin/mktemp '${keyDir}/key.XXXXXX')
      ${pkgs.openssl}/bin/openssl rand -hex 32 > "$key_tmp"
      ${pkgs.coreutils}/bin/ln "$key_tmp" '${keyDir}/api-key' 2>/dev/null || true
      ${pkgs.coreutils}/bin/rm "$key_tmp"
    fi
    test -s '${keyDir}/api-key'
    chmod 600 '${keyDir}/api-key'
    # Pin both the v11 weights and fitted calibration. Download outside the
    # store, publishing only complete files; session restarts reuse the cache.
    base=https://huggingface.co/Mapika/decider-2b-GGUF/resolve/ff2e5e687327eda9ac34e9a3ca84d3f400672c87
    for file in decider-2b-v11-Q8_0.gguf decider_config.json; do
      if [ ! -s "$model_dir/$file" ]; then
        ${pkgs.curl}/bin/curl --fail --location --retry 3 \
          "$base/$file" -o "$model_dir/$file.partial"
        case "$file" in
          *.gguf) expected=3657848acb4851da4465ab4abad7c6fe273c7e1f15e83629cd6da972a5282cb3 ;;
          *) expected=6e4891f2754a1c18a10f8dadb0c04e439e7f79fab0333d56641491bd4a05e722 ;;
        esac
        printf '%s  %s\n' "$expected" "$model_dir/$file.partial" | ${pkgs.coreutils}/bin/sha256sum --check
        ${pkgs.coreutils}/bin/mv "$model_dir/$file.partial" "$model_dir/$file"
      fi
    done
    exec /usr/bin/caffeinate -i ${pkgs.python3}/bin/python3 ${./decider-server.py} \
      ${decider}/bin/decider-logits "$model_dir/decider-2b-v11-Q8_0.gguf" \
      "$model_dir/decider_config.json" '${keyDir}/api-key'
  '';
  service = name: server: {
    # Wait for the encrypted Nix volume just as window-manager.nix does.
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
    StandardOutPath = "/Users/lee/Library/Logs/${name}.log";
    StandardErrorPath = "/Users/lee/Library/Logs/${name}.log";
  };
in {
  environment.systemPackages = [ pkgs.llama-cpp ];
  launchd.daemons.mac-llm.serviceConfig = service "mac-llm" coding;
  launchd.daemons.mac-browser-llm.serviceConfig = service "mac-browser-llm" browsing;
}
