# watchexec — build only the product CLI.
#
# Stock runs a bare `cargo build` at the workspace root, and the install hook
# would then publish the `test-socketfd` test crate alongside the CLI. Restrict
# the build to `watchexec-cli` so only the product binary is produced.
{
  watchexec,
}:

watchexec.overrideAttrs (oldAttrs: {
  cargoBuildFlags = (oldAttrs.cargoBuildFlags or [ ]) ++ [
    "--package=watchexec-cli"
  ];
})
