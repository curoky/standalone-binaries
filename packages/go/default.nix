# Go — portable musl-static SDK.
#
# Why local:
# 1. Nixpkgs' cross bootstrap records its private target compiler, musl loader,
#    CGO setting and data paths as the installed SDK defaults. Regenerate those
#    values to match upstream binary releases while leaving bootstrap variables
#    in effect during the build.
# 2. Go's internal linker does not recognize the bundled race runtime as needing
#    external linkage; `go test -race` then fails with `hole in findfunctab`.
#    Force external linking only for race builds.
# 3. `debug/dwarf` and `debug/elf` ship a deliberately dynamic ELF fixture.
#    It is test data, not SDK runtime content, but the strict artifact gate must
#    reject every dynamic ELF, so remove those testdata directories.
#
# The SDK layout is product packaging. Regress generated defaults and race-mode
# linking independently when stock static Go matches upstream behavior; retain
# the strict artifact boundary.
{ go }:

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
