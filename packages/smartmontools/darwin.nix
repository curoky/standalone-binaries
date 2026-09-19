# smartmontools (Darwin) — CLI with no Nix store paths, native build tools.
#
#   - `--with-drivedbdir=no`: `smartctl` otherwise embeds a Nix store path to
#     the external drive DB; disable it and rely on the compiled-in DB.
#   - `--sysconfdir=/etc` + installFlags to `$out/etc`: point the optional local
#     DB / config at the system `/etc`.
#   - `autoreconfHook`/`hostname` are overridden to native: as static build
#     tools they would drag in a failing static Perl.
{
  autoreconfHook,
  hostname,
  smartmontools,
}:

(smartmontools.override {
  inherit autoreconfHook hostname;
}).overrideAttrs (old: {
  configureFlags = (old.configureFlags or [ ]) ++ [
    "--sysconfdir=/etc"
    "--with-drivedbdir=no"
  ];

  installFlags = (old.installFlags or [ ]) ++ [
    "sysconfdir=$(out)/etc"
    "smartdscriptdir=$(out)/etc"
  ];
})
