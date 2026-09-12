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
