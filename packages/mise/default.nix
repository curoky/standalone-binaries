{
  lib,
  mise,
  nativeGit,
}:

# nixpkgs patches helper commands to absolute Nix store paths. The artifact
# normalizer can erase those references, but the resulting paths then point at
# nonexistent store entries. Keep mise portable by resolving external helpers
# through the user's PATH instead.
#
# The static target set also resolves nativeCheckInputs.git to pkgsStatic.git.
# Its checkPhase fails t3434-rebase-i18n under musl before mise can build, while
# mise's tests only need a build-platform Git executable. Replace that one
# check input with native Git; the shipped mise and its linked libraries remain
# from pkgsStatic. The DNS regression test expects an invalid hostname to fail
# immediately, but the build environment's proxy turns it into a timeout; skip
# only that environment-dependent test (its shared lock otherwise poisons seven
# unrelated HTTP tests).
mise.overrideAttrs (oldAttrs: {
  postPatch = ''
    patchShebangs --build \
      ./test/data/plugins/**/bin/* \
      ./src/fake_asdf.rs \
      ./src/cli/generate/git_pre_commit.rs \
      ./src/cli/generate/snapshots/*.snap
  '';

  nativeCheckInputs =
    lib.take 2 oldAttrs.nativeCheckInputs ++ [ nativeGit ] ++ lib.drop 3 oldAttrs.nativeCheckInputs;

  checkFlags = (oldAttrs.checkFlags or [ ]) ++ [
    "--skip=http::tests::test_reqwest_dns_error_is_not_transient_and_opens_circuit"
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
