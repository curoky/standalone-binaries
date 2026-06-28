# lemminx
#
# Eclipse LemMinX (XML Language Server) shipped as a normal package (not a
# `nix bundle` single-interface executable). It ships the prebuilt uber-jar
# plus a thin `lemminx` launcher that runs it with a JRE located at runtime
# from a co-located sibling package at `$store/jre21` (see `packages/jre/21`),
# mirroring how `netron` finds its `python311` sibling.
#
# The wrapper honors an externally provided `SBT_JAVA_HOME`, otherwise falls
# back to the sibling `$store/jre21`.
{
  lemminx,
  writeText,
}:

let
  wrapperScript = writeText "lemminx-wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    java_home="''${SBT_JAVA_HOME:-$store/jre21}"

    exec -a "$0" "$java_home/bin/java" -jar "$root/share/org.eclipse.lemminx-uber.jar" "$@"
  '';
in
lemminx.overrideAttrs (oldAttrs: {
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share
    install -Dm644 org.eclipse.lemminx/target/org.eclipse.lemminx-uber.jar $out/share

    cp ${wrapperScript} $out/bin/lemminx
    chmod +x $out/bin/lemminx

    runHook postInstall
  '';
})
