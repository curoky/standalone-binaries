# cloc — sibling-perl wrapper with its Perl modules bundled.
#
# `cloc` is a Perl script; the wrapper resolves the sibling static `perl`
# (../../perl/bin/perl relative to the install) and sets PERL5LIB to the bundled
# modules so the relocatable tarball has no PATH or store dependency.
#
# `doInstallCheck = false` is not recoverable: the stock installCheck runs
# `$out/bin/cloc` (the sibling wrapper), and the sandbox has no sibling perl, so
# it fails with "perl: No such file or directory".
{
  lib,
  cloc,
  perl,
  perlPackages,
  rsync,
  writeText,
}:

let
  wrapperScript = writeText "wrapper.sh" ''
    #!/usr/bin/env bash

    script_path="$(readlink -f "$0")"
    root=$(cd "$(dirname "$script_path")" && pwd)/..
    store=$root/..

    export PERL5LIB=$root/lib/perl5:$PERL5LIB
    for d in "$root"/lib/perl5/site_perl/*/; do
      [ -d "$d" ] && export PERL5LIB=$d:$PERL5LIB
    done
    exec -a "$0" $store/perl/bin/perl "$root/bin/_cloc" "$@"
  '';
in

cloc.overrideAttrs (oldAttrs: rec {
  nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [
    perl
    rsync
  ];
  doInstallCheck = false;
  postFixup = "";
  postInstall = ''
    chmod +w $out/bin/
    mv $out/bin/cloc $out/bin/_cloc
    cp ${wrapperScript} $out/bin/cloc
    chmod +x $out/bin/cloc

    mkdir -p $out/lib/perl5
    rsync -a ${perlPackages.Moo}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.AlgorithmDiff}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.RoleTiny}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.SubQuote}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.ParallelForkManager}/lib/perl5/ $out/lib/perl5/
    rsync -a ${perlPackages.RegexpCommon}/lib/perl5/ $out/lib/perl5/
  '';
})
