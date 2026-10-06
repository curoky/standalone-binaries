# mise — portable helper lookup and environment-dependent test adjustment.
#
# Why local:
# 1. Nixpkgs patches helper commands to absolute store paths. Artifact hash
#    normalization would leave dead paths, so installed helpers must resolve
#    from the user's PATH.
# 2. New process tests assume FHS coreutils paths and an env-based Python
#    shebang, neither of which exists in the Nix sandbox. Point test-only code
#    at native check tools instead of skipping its protocol coverage.
# 3. The static musl test constructor runs before Rust captures argv, so its
#    `--list` guard misses nextest's concurrent list processes and they race while
#    resetting the shared fixture tree. Use nextest's explicit phase marker too.
#
# The test changes can regress independently; PATH-based helper lookup is
# permanent portability behavior. The shared native Git check tool remains
# selected by `packages/static-build-tools.nix`.
{
  buildPackages,
  lib,
  mise,
}:

mise.overrideAttrs (oldAttrs: {
  postPatch = ''
    substituteInPlace ./src/testing.rs \
      --replace-fail \
        'std::env::args_os().any(|a| a == "--list")' \
        'std::env::var_os("NEXTEST_TEST_PHASE").as_deref() == Some(std::ffi::OsStr::new("list")) || std::env::args_os().any(|a| a == "--list")'

    substituteInPlace ./crates/mise-util/src/agecrypt/fixtures/age-plugin-se.py \
      --replace-fail \
        '#!/usr/bin/env python3' \
        '#!${buildPackages.python3}/bin/python3'

    substituteInPlace \
      ./crates/mise-util/src/cmd/tests.rs \
      ./crates/mise-util/src/inline_command.rs \
      --replace-fail \
        '"/usr/bin:/bin"' \
        '"${lib.makeBinPath [ buildPackages.coreutils ]}"'

    patchShebangs --build \
      ./test/data/plugins/**/bin/* \
      ./src/fake_asdf.rs \
      ./src/cli/generate/git_pre_commit.rs \
      ./src/cli/generate/snapshots/*.snap
  '';

  nativeCheckInputs = (oldAttrs.nativeCheckInputs or [ ]) ++ [
    buildPackages.python3
  ];

  postInstall = ''
    installManPage ./man/man1/mise.1

    installShellCompletion \
      --bash ./completions/mise.bash \
      --fish ./completions/mise.fish \
      --zsh ./completions/_mise

    mkdir -p $out/lib/mise
    touch $out/lib/mise/.disable-self-update
  '';
})
