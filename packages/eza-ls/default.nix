# eza-ls — ls-compatible product front end.
#
# Why local:
# 1. Upstream eza is a separate command and does not provide this repository's
#    `ls` compatibility behavior or selected defaults.
# 2. Bundle the real eza binary beside a wrapper that translates supported `ls`
#    calls and selects the richer presentation.
# 3. Unsupported or non-interactive cases use `/bin/ls`; that host command is
#    an explicit Linux/macOS product boundary.
#
# This is an independent product package, not an upstream workaround.
{
  lib,
  stdenvNoCC,
  eza,
}:

stdenvNoCC.mkDerivation {
  pname = "eza-ls";
  inherit (eza) version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp ${lib.getExe eza} $out/bin/eza

    cp ${./ls-wrapper.sh} $out/bin/ls
    chmod +x $out/bin/ls

    runHook postInstall
  '';

  meta = {
    description = "ls-compatible front-end backed by eza";
    homepage = "https://github.com/eza-community/eza";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "ls";
  };
}
