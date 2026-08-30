# colima, darwin-only, colima binary only.
#
# Upstream nixpkgs wrapProgram bakes lima-full/qemu/docker /nix/store paths into
# colima's PATH (see pkgs/by-name/co/colima/package.nix postInstall). That would
# retain /nix/store references and violate invariant #1. Per this repo's model
# the runtime deps (lima, docker, ...) are installed separately, so we drop the
# wrapper and let colima resolve them from the user's ambient PATH. Shell
# completions are preserved.
#
# CGO stays on. Artifact's guarded Darwin Go/CGO normalization handles the
# Nix libresolv dependency; this override only changes runtime packaging.
{
  colima,
}:

colima.overrideAttrs (_oldAttrs: {
  postInstall = ''
    installShellCompletion --cmd colima \
      --bash <($out/bin/colima completion bash) \
      --fish <($out/bin/colima completion fish) \
      --zsh <($out/bin/colima completion zsh)
  '';
})
