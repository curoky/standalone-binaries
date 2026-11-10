{
  lib,
  pkgs,
}:
let
  merge = import ./merge-package-sets.nix { inherit lib; };
  select = import ./make-manifest-packages.nix {
    inherit lib;
    allSystems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    envs.unstable.pkgsStatic = {
      first = {
        outPath = "/first";
      };
      second = {
        outPath = "/second";
      };
    };
  };
  rejected = packages: !(builtins.tryEval (builtins.attrNames packages)).success;
  splitPlatforms = {
    first = {
      platforms = [ "x86_64-linux" ];
      alias = "tool";
    };
    second = {
      platforms = [ "aarch64-darwin" ];
      alias = "tool";
    };
  };
  failures = lib.runTests {
    testDisjointSources = {
      expr = merge "x86_64-linux" {
        upstream.a = 1;
        local.b = 2;
      };
      expected = {
        a = 1;
        b = 2;
      };
    };
    testPackageValuesStayLazy = {
      expr = builtins.attrNames (
        merge "x86_64-linux" {
          upstream.a = throw "must not evaluate package a";
          local.b = throw "must not evaluate package b";
        }
      );
      expected = [
        "a"
        "b"
      ];
    };
    testUpstreamLocalCollision = {
      expr = rejected (
        merge "x86_64-linux" {
          upstream.tool = throw "must not evaluate upstream package";
          local.tool = throw "must not evaluate local package";
        }
      );
      expected = true;
    };
    testLocalGroupCollision = {
      expr = rejected (
        merge "aarch64-darwin" {
          common.tool = 1;
          darwin.tool = 2;
        }
      );
      expected = true;
    };
    testReservedOutputCollision = {
      expr = rejected (
        merge "x86_64-linux" {
          standalone.all = 1;
          aggregates.all = 2;
        }
      );
      expected = true;
    };
    testAliasCollision = {
      expr = rejected (
        select "x86_64-linux" {
          first.alias = "tool";
          second.alias = "tool";
        }
      );
      expected = true;
    };
    testPlatformAliasCollision = {
      expr = rejected (
        select "aarch64-darwin" {
          first."aarch64-darwin".alias = "second";
          second = { };
        }
      );
      expected = true;
    };
    testPlatformAliasesRemainDistinct = {
      expr = builtins.attrNames (
        select "x86_64-linux" {
          first."aarch64-darwin".alias = "second";
          second = { };
        }
      );
      expected = [
        "first"
        "second"
      ];
    };
    testLinuxPlatformSource = {
      expr = (select "x86_64-linux" splitPlatforms).tool.outPath;
      expected = "/first";
    };
    testDarwinPlatformSource = {
      expr = (select "aarch64-darwin" splitPlatforms).tool.outPath;
      expected = "/second";
    };
    testDisabledEntryStillValidated = {
      expr = rejected (
        select "x86_64-linux" {
          first = {
            platforms = [ "aarch64-darwin" ];
            alias = 1;
          };
        }
      );
      expected = true;
    };
  };
in
if failures != [ ] then
  throw "package selection tests failed: ${builtins.toJSON failures}"
else
  pkgs.runCommand "package-selection-tests" { } ''
    touch "$out"
  ''
