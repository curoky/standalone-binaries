# mise — portable helper lookup and cross-test inputs.
#
# Why local:
# 1. Nixpkgs patches helper commands to absolute store paths. Artifact hash
#    normalization would leave dead paths, so installed helpers must resolve
#    from the user's PATH.
# 2. `pkgsStatic` selects target Git for checks; that Git fails its own musl test
#    before mise builds. Mise only needs a build-machine Git, so use native Git.
# 3. The DNS regression test expects immediate failure, but the build proxy turns
#    the invalid host into a timeout and poisons other HTTP tests through a
#    shared lock. Skip only that environment-dependent case.
#
# The check-input and DNS changes can regress independently; PATH-based helper
# lookup is permanent portability behavior.
{
  lib,
  mise,
  nativeGit,
}:

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
