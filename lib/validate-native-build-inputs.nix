{ lib }:
root:
let
  dependencyNames = [
    "depsBuildBuild"
    "depsBuildBuildPropagated"
    "nativeBuildInputs"
    "propagatedNativeBuildInputs"
    "depsBuildTarget"
    "depsBuildTargetPropagated"
    "depsHostHost"
    "depsHostHostPropagated"
    "buildInputs"
    "propagatedBuildInputs"
    "depsTargetTarget"
    "depsTargetTargetPropagated"
    "checkInputs"
    "nativeCheckInputs"
    "installCheckInputs"
    "nativeInstallCheckInputs"
  ];
  nativeDependencyNames = [
    "depsBuildBuild"
    "depsBuildBuildPropagated"
    "nativeBuildInputs"
    "propagatedNativeBuildInputs"
    "depsBuildTarget"
    "depsBuildTargetPropagated"
    "nativeCheckInputs"
    "nativeInstallCheckInputs"
  ];
  isDerivation = value: builtins.isAttrs value && value ? drvPath;
  dependencies =
    drv: builtins.filter isDerivation (lib.concatMap (name: drv.${name} or [ ]) dependencyNames);
  closure = builtins.genericClosure {
    startSet = [
      {
        key = root.drvPath;
        value = root;
      }
    ];
    operator =
      item:
      map (value: {
        key = value.drvPath;
        inherit value;
      }) (dependencies item.value);
  };
  platformLabel =
    platform: "${platform.config}${lib.optionalString (platform.isStatic or false) "-static"}";
  mismatches = lib.concatMap (
    item:
    let
      consumer = item.value;
      buildPlatform = consumer.stdenv.buildPlatform or null;
    in
    if buildPlatform == null then
      [ ]
    else
      lib.concatMap (
        dependencyName:
        lib.concatMap (
          input:
          let
            hostPlatform = input.stdenv.hostPlatform or null;
          in
          lib.optional
            (
              hostPlatform != null
              && (
                hostPlatform.config != buildPlatform.config
                || (hostPlatform.isStatic or false) != (buildPlatform.isStatic or false)
              )
            )
            {
              consumer = consumer.name or consumer.pname or consumer.drvPath;
              dependency = input.name or input.pname or input.drvPath;
              inherit dependencyName;
              expected = platformLabel buildPlatform;
              actual = platformLabel hostPlatform;
            }
        ) (builtins.filter isDerivation (consumer.${dependencyName} or [ ]))
      ) nativeDependencyNames
  ) closure;
  formatMismatch =
    mismatch:
    "${mismatch.consumer}: ${mismatch.dependencyName} contains ${mismatch.dependency} "
    + "for ${mismatch.actual}, expected ${mismatch.expected}";
in
if mismatches == [ ] then
  root
else
  throw ''
    native build inputs must run on the build platform:
    ${lib.concatMapStringsSep "\n" formatMismatch mismatches}
  ''
