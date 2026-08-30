# lima, darwin-only, hostside limactl + helpers + bundled guest agents.
#
# Upstream nixpkgs wrapProgram bakes qemu's /nix/store path into limactl's PATH
# (see pkgs/by-name/li/lima/package.nix installPhase). That would retain a
# /nix/store reference and violate invariant #1. Per this repo's model the
# runtime deps are installed separately, and darwin lima defaults to the VZ
# backend (Virtualization.framework) rather than qemu, so we drop the wrapper
# and let limactl resolve any external tools from the user's ambient PATH.
#
# The real binary is built into $out/bin/limactl directly (no wrapProgram), so
# the sibling *.lima helper scripts, shell completions and the bundled guest
# agents / templates under share/lima all stay intact and relocatable.
#
# Artifact's guarded Darwin Go/CGO normalization relocates libresolv only in
# matching host executables, leaving guest ELF files alone. It preserves the
# upstream limactl signature's virtualization entitlement when re-signing.
{
  lima,
}:

lima.overrideAttrs (_oldAttrs: {
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r _output/* $out
    installShellCompletion --cmd limactl \
      --bash <($out/bin/limactl completion bash) \
      --fish <($out/bin/limactl completion fish) \
      --zsh <($out/bin/limactl completion zsh)
    runHook postInstall
  '';
})
