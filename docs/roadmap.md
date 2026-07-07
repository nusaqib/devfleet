# Roadmap

## Phase 0 — Decisions ✅ (resolved 2026-07-06)
- [x] **Provider**: VirtualBox.
- [x] **OS matrix**: Ubuntu 24.04, Debian 12, Rocky 9.
- [x] **Cloud**: out of scope (local only) — `terraform/` dropped.

## Phase 1 — Ubuntu proven end-to-end ✅ (2026-07-06)
- [x] Reusable Packer source + shared build block → versioned Vagrant boxes.
- [x] Unattended installs for all three OSes (autoinstall/preseed/kickstart).
- [x] Family-aware Ansible `base` role + single playbook (build & run share it).
- [x] Data-driven multi-machine Vagrantfile (`machines.yaml`).
- [x] `scripts/build.sh`, `scripts/lint.sh`, `Makefile`, `install-host-tooling.sh`.
- [x] Host tooling installed: VirtualBox 7.1, Packer 1.15, Vagrant 2.4, Ansible 2.16.
- [x] **`make build-ubuntu` builds a working box**; `vagrant up ubuntu` boots it and
      re-runs the shared playbook (runtime context, idempotent → changed=0).

### Fixes made while getting Ubuntu green (apply to all OSes):
- Pinned exact ISO URLs + `sha256:` checksums (point releases had moved; it's mid-2026).
  Ubuntu 24.04.4, Rocky 9.8, Debian 12.11.0 (from archive — 'current' is now Debian 13).
- `vagrant` post-processor is a separate plugin in Packer 1.15 → added to required_plugins.
- `http_directory` anchored with `${path.root}` (was relative to packer's cwd).
- Per-OS `output_directory` + `packer build -force` so reruns don't collide.
- Ubuntu autoinstall password hash regenerated with `openssl passwd -6` (mine was wrong).
- `ansible.cfg`: dropped removed `community.general.yaml` callback → built-in
  `default` + `result_format=yaml` (guest had newer collection than host).
- Vagrantfile: disabled default `/vagrant` mount (needs Guest Additions we don't ship),
  ship `ansible/` via `rsync` instead.

## Phase 2 — All three OSes proven end-to-end ✅ (2026-07-06)
- [x] **Debian 12** built + boot-tested. Preseed + bento-style boot_command worked
      first try. Box ~666 MB. (Installer auto-upgraded to 12.14 during install.)
- [x] **Rocky 9.8** built + boot-tested. Kickstart worked; boot_command needed a fix:
      the boot ISO uses **isolinux (BIOS)**, not GRUB — switched from `e`/Ctrl-X
      editing to `<tab>`-append (`inst.text inst.ks=...`).
- [x] All three `vagrant up` cleanly, run the shared playbook at runtime
      (changed=0 → idempotent), full toolset present, correct hostnames.

## Phase 3 — Scale & maintain (mostly done, 2026-07-06)
- [x] CI: validate/lint on every PR (`.github/workflows/lint.yml`).
- [x] **Box versioning + hosting**: `scripts/publish-box.sh` generates versioned
      Vagrant metadata (auto-bumping semver); `scripts/serve-boxes.sh` serves the
      catalog over HTTP; `machines.yaml` supports `box_version` pinning. All boxes
      published as **v2.0.0**.
- [x] **Dev-tooling `devtools` role**: build toolchain, tmux/jq/tree/wget/pip,
      and a family-native container runtime (Docker on Debian family, Podman on
      RHEL). Wired into the shared playbook (toggle `devfleet_install_devtools`).
- [x] **Guest Additions baked in** — best-effort. Builds cleanly on Ubuntu 24.04
      and Debian 12 (→ native vboxsf shared folders). Does NOT compile on Rocky
      9.8 (VBox 7.1 GA vs the RHEL 9 kernel) → that box falls back to rsync. The
      build never fails on GA; a marker (`/etc/devfleet-guest-additions`) records
      the outcome, and `machines.yaml` sets `synced_folder_type` per OS.
- [ ] Nightly image rebuilds for security patches (scheduled workflow). — not done
- [ ] (Optional) dotfiles/editor-config role; language version managers.

### Known issue
- Ubuntu v2.0.0's GA marker reads `none` (that box built in the first parallel
  pass, before the marker line existed) — vboxsf still works. Cosmetic; a rebuild
  would set it to `ok`.
- GA on Rocky needs either a newer Guest Additions release or a kernel-module
  patch; revisit when VBox ships GA compatible with the EL9 kernel.

## Phase 3 — Scale & maintain
- [x] CI: validate/lint on every PR (`.github/workflows/lint.yml`).
- [ ] Nightly image rebuilds for security patches (scheduled workflow).
- [ ] Optional Terraform module to run the same images in the cloud.
- [ ] Docs: architecture decision records + runbook per OS.
