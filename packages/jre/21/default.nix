# jre 21
#
# Shared JRE runtime, shipped as its own package so the JVM tool lemminx can
# locate it at runtime as a co-located sibling (`$store/jre21`) instead of
# bundling a full JRE closure into a single self-extracting executable,
# mirroring how `netron` finds its `python311` sibling.
#
# Uses `jre_minimal` (jlink) trimmed to just the modules lemminx needs, which
# is far smaller than a full headless JRE. The module set matches upstream
# nixpkgs lemminx. The whole JRE tree is copied to `$out` so the sibling
# layout `$store/jre21/bin/java` works after extraction.
{
  stdenv,
  jre_minimal,
  jdk21_headless,
}:

let
  jre = jre_minimal.override {
    jdk = jdk21_headless;
    modules = [
      "java.base"
      "java.logging"
      "java.xml"
      "jdk.crypto.ec"
    ];
  };
in
stdenv.mkDerivation {
  pname = "jre21";
  version = jre.version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a ${jre}/. $out/
    chmod -R u+w $out
    runHook postInstall
  '';
}
