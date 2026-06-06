# AGENTS.md

## Cursor Cloud specific instructions

### What this repo is

`void0.nix` is a **Nix flake** that packages the void0 JavaScript toolchain (vite, oxlint, oxfmt, rolldown, viteplus). There is no application server, database, or `package.json` in the repo itself. Development means building and validating Nix derivations.

### Nix daemon (required in this VM)

This environment uses Determinate Nix, but **systemd is not available**, so `nix-daemon` does not start automatically. Before any `nix` command in a new shell session:

```bash
export PATH="/nix/var/nix/profiles/default/bin:$PATH"
sudo /nix/var/nix/profiles/default/bin/nix-daemon >/tmp/nix-daemon.log 2>&1 &
sleep 1
```

`~/.bashrc` already adds Nix to `PATH`; you still need to start the daemon manually.

### Build and test (matches CI)

CI builds each package with `nix build .#<pkg> -L`. To build the full toolchain bundle:

```bash
cd /workspace
nix build .#default -L
```

Individual packages: `vitejs`, `oxlint`, `oxfmt`, `rolldown`, `viteplus`, `default`.

Use built binaries via `./result/bin/` (symlink created by `nix build`).

### Dev shell

`nix develop` enters a shell with `nix-update` for bumping package versions:

```bash
nix develop
nix-update --flake vitejs    # update vitejs derivation
nix-update --flake viteplus  # bump vp from npm + refresh platform tarball hashes
```

`viteplus` ships only the Rust `vp` binary. Global commands (`vp create`, `vp migrate`, …) load JS from `vite-plus/dist/bin.js`. The wrapper defaults to:

```bash
$VP_HOME/current/node_modules/vite-plus/dist   # VP_HOME defaults to ~/.vite-plus
```

Override explicitly:

```bash
export VITE_GLOBAL_CLI_JS_SCRIPTS_DIR=/path/to/vite-plus/dist
```

Bootstrap the JS side once (official installer or manual):

```bash
curl -fsSL https://vite.plus | bash
# or: mkdir -p ~/.vite-plus/$VERSION && cd ~/.vite-plus/$VERSION && npm init -y && npm install vite-plus@$VERSION
```

Inside a project that already has `vite-plus` in `node_modules`, `vp` uses the local install and does not need the global JS tree.

### Lint / format

There are no repo-local ESLint or Prettier configs. Validation is **Nix builds** (same as `.github/workflows/ci.yml`). To exercise the packaged tools on sample JS, add files under `/tmp` and run `./result/bin/oxlint`, `./result/bin/oxfmt`, etc.

### Build time

First builds compile Rust/Node from source and can take **15–30+ minutes** for `.#default`. Subsequent builds use the Nix store cache and are much faster.

### Secrets

None required for local development. CI uses Attic cache secrets (`ATTIC_*`) only in GitHub Actions.
