{
  description = "Standalone, portable prebuilt tool binaries built with Nix";

  inputs = {
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-gcc15-2026-09-07.url = "github:NixOS/nixpkgs/dc5d91f840324650bac8c379428c7037a416959a";
    nixpkgs-s6-2026-08-23.url = "github:NixOS/nixpkgs/56c02bc00adcf003215cc4bd996d6efaf4cff188";
    nixpkgs-2605.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-2511.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-2211.url = "github:NixOS/nixpkgs/nixos-22.11";
  };

  outputs =
    inputs:
    let
      lib = inputs.nixpkgs-unstable.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      channels = {
        unstable = inputs.nixpkgs-unstable;
        "26.05" = inputs.nixpkgs-2605;
        "25.11" = inputs.nixpkgs-2511;
        "25.05" = inputs.nixpkgs-2505;
        "24.11" = inputs.nixpkgs-2411;
        "24.05" = inputs.nixpkgs-2405;
        "22.11" = inputs.nixpkgs-2211;
      };
      pins = {
        "gcc15-pin" = inputs.nixpkgs-gcc15-2026-09-07;
        "s6-pin" = inputs.nixpkgs-s6-2026-08-23;
      };
      makeSystemOutputs = import ./lib/make-system-outputs.nix {
        inherit
          lib
          systems
          channels
          pins
          ;
      };
      perSystemOutputs = lib.genAttrs systems makeSystemOutputs;
    in
    lib.genAttrs [
      "packages"
      "tarballs"
      "probe"
      "sources"
      "cacheRoots"
    ] (name: lib.mapAttrs (_: outputs: outputs.${name}) perSystemOutputs);
}
