# smartmontools (Darwin) — CLI with no Nix store paths, native build tools.
#
# Why local:
# 1. `smartctl` otherwise compiles the Nix path of the external drive database.
#    Disable that lookup and use its built-in database.
# 2. Point optional local database/config discovery at `/etc`, while installing
#    package-owned samples under `$out/etc`.
# 3. Static autoreconf/hostname pull in the failing Darwin static Perl even
#    though they run only during the build. Inject native build tools instead.
#
# The build-tool override may regress when static Perl works; the CLI resource
# policy remains.
{
  autoreconfHook,
  hostname,
  smartmontools,
}:

(smartmontools.override {
  inherit autoreconfHook hostname;
}).overrideAttrs
  (old: {
    configureFlags = (old.configureFlags or [ ]) ++ [
      "--sysconfdir=/etc"
      "--with-drivedbdir=no"
    ];

    installFlags = (old.installFlags or [ ]) ++ [
      "sysconfdir=$(out)/etc"
      "smartdscriptdir=$(out)/etc"
    ];
  })
