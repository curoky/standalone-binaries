{
  iana-etc,
  mailcap,
  removeReferencesTo,
  rclone,
  tzdata,
}:

rclone.overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ removeReferencesTo ];
  disallowedReferences = (oldAttrs.disallowedReferences or [ ]) ++ [
    tzdata
    mailcap
    iana-etc
  ];

  postInstall = (oldAttrs.postInstall or "") + ''
    # Nix's Go stdlib embeds these resource paths. Remove only their references,
    # retaining the existing host/built-in lookup behavior. Preserve the original
    # libresolv load command so artifact can apply its guarded CGO relocation.
    # Do not use nuke-refs: it would also destroy the resolver's matching hash.
    remove-references-to \
      -t ${tzdata} \
      -t ${mailcap} \
      -t ${iana-etc} \
      "$out/bin/rclone"
  '';
})
