{ go }:

# Build the compiler itself as static musl, but keep the public toolchain
# defaults aligned with upstream Go. nixpkgs' cross build otherwise bakes its
# private target compiler, musl loader and Nix data paths into the SDK. The
# static linker does not recognize the bundled race object as requiring an
# external linker, so that one mode is made explicit without affecting pure-Go
# cross compilation.
go.overrideAttrs (oldAttrs: {
  patches = [ ];

  postPatch = (oldAttrs.postPatch or "") + ''
    substituteInPlace src/cmd/dist/buildgo.go \
      --replace-fail \
        'func defaultCCFunc(name string, defaultcc map[string]string) string {' \
        $'func defaultCCFunc(name string, defaultcc map[string]string) string {\n\t// Keep the installed SDK defaults identical to upstream binary releases.\n\t// The bootstrap itself still uses CC_FOR_TARGET and CXX_FOR_TARGET.\n\tdefaultcc = nil'

    sed -i '/^[[:space:]]*"os"$/d' src/cmd/dist/buildruntime.go
    substituteInPlace src/cmd/dist/buildruntime.go \
      --replace-fail \
        'fmt.Fprintf(&buf, "const DefaultGO386 = `%s`\n", go386)' \
        'fmt.Fprintln(&buf, "const DefaultGO386 = `sse2`")' \
      --replace-fail \
        'fmt.Fprintf(&buf, "const defaultGO_EXTLINK_ENABLED = `%s`\n", goextlinkenabled)' \
        'fmt.Fprintln(&buf, "const defaultGO_EXTLINK_ENABLED = ``")' \
      --replace-fail \
        'fmt.Fprintf(&buf, "const defaultGO_LDSO = `%s`\n", defaultldso)' \
        'fmt.Fprintln(&buf, "const defaultGO_LDSO = ``")' \
      --replace-fail \
        'fmt.Fprintf(&buf, "const DefaultCGO_ENABLED = %s\n", quote(os.Getenv("CGO_ENABLED")))' \
        'fmt.Fprintln(&buf, `const DefaultCGO_ENABLED = ""`)'

    substituteInPlace src/cmd/link/internal/ld/config.go \
      --replace-fail \
        $'\tif *flagMsan {' \
        $'\tif *flagRace {\n\t\treturn true, "race"\n\t}\n\n\tif *flagMsan {'
  '';

  postInstall = (oldAttrs.postInstall or "") + ''
    rm -rf \
      $out/share/go/src/debug/dwarf/testdata \
      $out/share/go/src/debug/elf/testdata
  '';
})
