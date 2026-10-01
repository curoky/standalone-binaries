{
  lib,
  stdenv,
  fetchFromGitHub,
  oh-my-zsh,
  zsh-syntax-highlighting,
  zsh-autosuggestions,
  zsh-completions,
  zsh-fast-syntax-highlighting,
  nativeAtuin,
  nativeStarship,
  nativeZsh,
}:

stdenv.mkDerivation rec {
  version = "1.0.0";
  pname = "zsh-plugins";

  srcs = [
    (fetchFromGitHub {
      owner = "conda-incubator";
      repo = "conda-zsh-completion";
      rev = "v0.11";
      sha256 = "sha256-OKq4yEBBMcS7vaaYMgVPlgHh7KQt6Ap+3kc2hOJ7XHk=";
      name = "conda-zsh-completion";
    })
  ];

  sourceRoot = ".";
  strictDeps = true;
  buildInputs = [
  ];

  installPhase = ''
    runHook preInstall

    cp -r ${oh-my-zsh.out} $out/
    plugins=$out/share/oh-my-zsh/custom/plugins
    chmod +w "$plugins"
    cp -r ${zsh-autosuggestions.src}/ "$plugins/zsh-autosuggestions"
    cp -r ${zsh-syntax-highlighting.src}/ "$plugins/zsh-syntax-highlighting"
    cp -r ${zsh-completions.src}/ "$plugins/zsh-completions"
    cp -r ${zsh-fast-syntax-highlighting.src}/ "$plugins/zsh-fast-syntax-highlighting"
    cp -r conda-zsh-completion "$plugins/"

    mkdir -p "$plugins/atuin" "$plugins/starship"

    # Generate shell integration once at build time. The installed scripts
    # locate their separately installed binaries from the shared binman store,
    # so neither startup-time generation nor Nix store paths are needed.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${lib.getExe nativeAtuin} init zsh --disable-up-arrow --disable-ai \
      > "$TMPDIR/atuin.plugin.zsh"
    {
      printf '%s\n' '__atuin_bin_dir="''${''${(%):-%x}:A:h:h:h:h:h:h:h}/atuin/bin"'
      printf '%s\n' 'atuin() { "''${__atuin_bin_dir}/atuin" "$@" }'
      printf '%s\n' 'export PATH="''${__atuin_bin_dir}:''${PATH}"'
      cat "$TMPDIR/atuin.plugin.zsh"
    } > "$plugins/atuin/atuin.plugin.zsh"

    ${lib.getExe nativeStarship} init zsh > "$TMPDIR/starship.plugin.zsh"
    {
      printf '%s\n' '__starship_bin="''${''${(%):-%x}:A:h:h:h:h:h:h:h}/starship/bin/starship"'
      sed 's#${lib.getExe nativeStarship}#''${__starship_bin}#g' \
        "$TMPDIR/starship.plugin.zsh"
    } > "$plugins/starship/starship.plugin.zsh"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for plugin in atuin starship; do
      script="$out/share/oh-my-zsh/custom/plugins/$plugin/$plugin.plugin.zsh"
      if grep -q '/nix/store' "$script"; then
        echo "$plugin plugin still contains a /nix/store path" >&2
        exit 1
      fi
      ${lib.getExe nativeZsh} -n "$script"
    done
    grep -q '/atuin/bin' "$out/share/oh-my-zsh/custom/plugins/atuin/atuin.plugin.zsh"
    grep -q '/starship/bin/starship' "$out/share/oh-my-zsh/custom/plugins/starship/starship.plugin.zsh"

    runHook postInstallCheck
  '';

  meta = with lib; {
    description = "zsh bundle";
  };
}
