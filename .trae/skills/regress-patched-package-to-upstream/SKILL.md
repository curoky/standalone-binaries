---
name: "regress-patched-package-to-upstream"
description: "Check whether a locally patched package under packages/ can drop its patch and go back to the plain upstream nixpkgs build (because nixpkgs fixed the issue), then perform the regression. Invoke when reviewing/updating packages/ entries, bumping nixpkgs, or auditing whether local patches are still needed."
---

# Regress a Patched Package Back to Upstream

Local patched derivations in `packages/` exist **only** to work around a
`nixpkgs` (usually `pkgsStatic.<x>`) build/link failure or portability problem.
Once upstream nixpkgs fixes that problem, the patch is dead weight: it should be
removed and the package regressed to the plain upstream build. Use this skill to
verify a patch is obsolete and to perform the regression cleanly.

Read `DESIGN.md` first — the patch policy and package-selection model live there.
This skill is the inverse of `patch-nixpkgs-standalone`: that one adds a patch
when the stock static build fails; this one removes it when the stock build works
again.

## Principle

**Prefer the upstream package whenever it builds and meets the portability goal.**
A local package is a liability (maintenance, drift from upstream, larger diff).
If `nixpkgs.pkgsStatic.<x>` (or the appropriate stock build) now compiles, links,
and passes the portability check, delete the local patch and use upstream via the
manifest.

## When to run this

- Auditing/reviewing entries under `packages/`.
- After bumping a `nixpkgs` input (`unstable`/`26.05`/... in `flake.nix`).
- When a package's `default.nix`/`darwin.nix` comment says it patches around a
  specific upstream bug — check if that bug is gone.

## Procedure

1. **Identify why the patch exists.** Read the local
   `packages/<pkg>/*.nix` and its comments. The comment almost always names the
   exact failure (e.g. "darwin `pkgsStatic.perl` fails at `mktables`",
   "`liboapv` ships only a `.dylib`"). That failure is your regression test.

2. **Test the stock upstream build.** Build the plain upstream derivation the
   patch was replacing, for the target platform(s):
   - Full static route: `nix build nixpkgs#pkgsStatic.<x>` (matching the pinned
     input the manifest would use).
   - If that's what the patch worked around and it now **builds and links**, the
     patch is a candidate for removal.
   - Reproduce on **every** platform the package targets (Linux + darwin). A fix
     on one platform does not imply the other.

3. **Verify the upstream build still meets the portability goal** (same checks as
   `patch-nixpkgs-standalone`):
   - **Linux:** `file`/`ldd` → statically linked, no `/nix` runtime refs.
   - **macOS:** `otool -L` on the binary and every shipped `.dylib`/`.bundle`/`.so`
     → only `/usr/lib/*`, `/System/Library/Frameworks/*`, or `@loader_path`
     entries; **zero** `/nix/store`.
   - If upstream builds but still fails portability, the patch is **not** yet
     obsolete — keep it. Only regress when upstream is both buildable AND portable.

4. **Perform the regression** once verified:
   - If the whole package can use upstream directly, **delete** `packages/<pkg>/`
     and remove its `callPackage ./<pkg>` line from
     [packages/local.nix](file:///workspace/standalone-binaries/packages/local.nix)
     (`common`/`linux`/`darwin` set), then add/adjust the entry in
     [manifests/default.nix](file:///workspace/standalone-binaries/manifests/default.nix)
     (`isStatic = true`, correct `version`/`platforms`/`output`/`alias`).
   - If only **one platform** is fixed, drop just that platform's local file
     (e.g. remove `darwin.nix`, keep `default.nix`) and switch that platform to
     the manifest/upstream build; keep the still-needed platform patched.
   - If the patch only *partially* regressed (e.g. a feature-reduction override no
     longer needs one disabled feature), shrink the override to the minimum still
     required rather than removing the whole package.

5. **Clean up orphans your change created:** unused patch files, wrapper scripts,
   vendored configs under `packages/<pkg>/`, and now-dead `callPackage` wiring.
   Do not remove unrelated pre-existing code.

6. **Rebuild the final standalone output** for the affected package(s) and re-run
   the verification checks to confirm the regressed build is still portable.

7. **Update `DESIGN.md`** in the same change if the regression alters the package
   selection model (e.g. a package moves from a `packages/` local override to a
   manifest entry, or a documented per-platform strategy no longer applies).

## Guardrails

- Do not regress on assumption — always build and verify upstream on **all**
  target platforms first.
- Only regress when upstream is both **buildable** and **portable**. Buildable
  but non-portable is not a reason to drop the patch.
- Keep the diff surgical: remove only what the obsolete patch owned.
- If unsure whether a platform is truly fixed (e.g. can't test darwin locally),
  say so and ask before deleting that platform's patch.
