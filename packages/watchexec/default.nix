# watchexec — workspace target selection.
#
# Why local:
# 1. Stock runs `cargo build` for the whole workspace.
# 2. That produces the `test-socketfd` test crate, and the generic install hook
#    publishes it beside the actual CLI.
# 3. Restrict the Cargo target to `watchexec-cli` so the output contains only
#    the product binary.
#
# Remove this override when stock selects only the CLI crate.
{
  watchexec,
}:

watchexec.overrideAttrs (oldAttrs: {
  cargoBuildFlags = (oldAttrs.cargoBuildFlags or [ ]) ++ [
    "--package=watchexec-cli"
  ];
})
