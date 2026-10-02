{
  runCommand,
  buildPackages,
}:
runCommand "standalone-artifact-tool"
  {
    nativeBuildInputs = [ buildPackages.go ];
  }
  ''
    cp -R ${./.} source
    chmod -R u+w source
    cd source
    export CGO_ENABLED=0
    export GO111MODULE=off
    export GOCACHE=$TMPDIR/go-cache
    mkdir -p "$out/bin"
    go build -trimpath -ldflags="-s -w" -o "$out/bin/artifact"
  ''
