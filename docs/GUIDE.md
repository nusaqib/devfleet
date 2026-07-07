# devfleet — The Complete Guide

Reproducible, scalable, maintainable development VMs as code, across multiple
operating systems. This guide explains **what it is, how it works, and how to
use and extend it.**

---

## 1. The mental model

devfleet treats a development VM the way you'd treat a container image: something
you **build once, version, and boot many times** — never something you configure
by hand. Three tools each own exactly one job:

```
   ┌─────────────┐        ┌─────────────┐        ┌─────────────┐
   │   PACKER    │        │   VAGRANT   │        │   ANSIBLE   │
   │             │        │             │        │             │
   │  builds a   │──box──▶│  boots the  │        │ provisions  │
   │  golden     │        │  box into a │        │ the machine │
   │  image per  │        │  running VM │        │ (packages,  │
   │  OS         │        │             │        │  config)    │
   └─────────────┘        └─────────────┘        └─────────────┘
         │                       │                       ▲
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                    both call the SAME Ansible playbook
```

The single most important idea: **the same Ansible role runs at build time
(inside Packer) and at run time (inside Vagrant).** That's what makes the whole
thing reproducible — there is one source of truth for "what a dev box contains,"
and it can't drift between how an image is baked and how a VM is provisioned.

A healthy sign you'll see constantly: after a fresh `vagrant up`, the runtime
Ansible run reports **`changed=0`**. Everything was already baked into the image;
runtime provisioning only *converges* — it changes nothing because there's
nothing left to do.

---

## 2. How reproducibility actually works

| Goal | How devfleet achieves it |
|------|--------------------------|
| **Reproducible** | Pinned ISO checksums, pinned box versions, one shared Ansible role. Rebuild the image → identical result. |
| **Multi-OS** | Each OS is one `*.pkrvars.hcl` + one unattended-install file. OS *differences* are variables and family-specific task files, not forked scripts. |
| **Scalable** | Add a running VM by adding one line to `machines.yaml`. The Vagrantfile loops over it — no Ruby edits. |
| **Maintainable** | Three tools, one job each. Any layer can be swapped (e.g. VirtualBox → libvirt) without rewriting the others. Everything is linted in CI. |

### The build → run flow, end to end

1. **`packer build`** boots a throwaway VM from the OS installer ISO.
2. An **unattended install** (autoinstall / preseed / kickstart) installs the OS
   headless and creates the `vagrant` user with the insecure SSH key.
3. Packer runs the **shared `base` playbook** with `devfleet_context=image`.
4. A cleanup script shrinks the image; Packer exports it as a **Vagrant box**.
5. `scripts/build.sh` registers it as `devfleet/<os>`.
6. **`vagrant up <name>`** boots that box, then re-runs the **same playbook**
   with `devfleet_context=runtime` (idempotent — usually `changed=0`).

---

## 3. Directory tour

```
devfleet/
├── packer/
│   ├── sources.pkr.hcl        # ONE reusable virtualbox-iso source (+ plugins)
│   ├── build.pkr.hcl          # shared provisioning + vagrant box post-processor
│   ├── variables.pkr.hcl      # variable DECLARATIONS
│   ├── ubuntu-2404.pkrvars.hcl \
│   ├── debian-12.pkrvars.hcl   }  per-OS VALUES (ISO, checksum, boot_command)
│   ├── rocky-9.pkrvars.hcl    /
│   ├── http/                  # unattended installs served to the installer
│   │   ├── ubuntu/{user-data,meta-data}   # Subiquity autoinstall (cloud-init)
│   │   ├── debian/preseed.cfg             # debian-installer preseed
│   │   └── rocky/ks.cfg                   # Anaconda kickstart
│   └── scripts/{ansible-prereqs.sh,cleanup.sh}
├── vagrant/
│   ├── Vagrantfile            # data-driven; reads machines.yaml, loops over it
│   └── machines.yaml          # THE FLEET — add a VM by adding a line here
├── ansible/
│   ├── ansible.cfg
│   ├── requirements.yml       # Ansible collections (community.general)
│   ├── playbooks/base.yml     # the ONE playbook used at build AND run time
│   ├── roles/
│   │   ├── base/              # minimal, always-on (users, ssh, core packages)
│   │   │   ├── tasks/{main,Debian,RedHat}.yml   # family-aware
│   │   │   ├── defaults/main.yml
│   │   │   └── meta/main.yml
│   │   └── devtools/          # dev environment: toolchain, CLI utils, containers
│   │       ├── tasks/{main,Debian,RedHat}.yml   # docker.io | podman per family
│   │       ├── defaults/main.yml
│   │       └── meta/main.yml
│   └── inventory/local.ini    # for running the playbook by hand
├── boxes/                     # versioned box catalog: <os>/metadata.json + .box
├── scripts/
│   ├── build.sh               # build one OS box + publish it (versioned)
│   ├── publish-box.sh         # write versioned Vagrant metadata + register
│   ├── serve-boxes.sh         # serve the catalog over HTTP for teammates
│   ├── lint.sh                # validate every layer (CI parity)
│   └── install-host-tooling.sh# one-shot host setup (Ubuntu 24.04)
├── .github/workflows/lint.yml # CI: packer/ansible/vagrant validation
├── Makefile                   # make build / up / down / destroy / lint
└── docs/{GUIDE.md,roadmap.md}
```

---

## 4. Prerequisites

Host tooling (Ubuntu 24.04 host — one command sets it all up):

```bash
sudo scripts/install-host-tooling.sh   # VirtualBox 7.1, Packer, Vagrant, Ansible
newgrp vboxusers                        # or log out/in
```

> **Provider note.** This repo uses **VirtualBox** for cross-platform portability.
> On a Linux host that already runs **libvirt/KVM**, the two hypervisors contend
> for VT-x — only one can hold it at a time. Shut down KVM VMs before running
> VirtualBox VMs (or make libvirt the provider on that host; the design supports
> swapping providers).

---

## 5. Common workflows

```bash
# Validate everything without booting a VM (fast; same checks as CI):
make lint

# Build boxes (Packer). ~8-15 min each; downloads the ISO on first run.
make build-ubuntu          # or build-debian / build-rocky
make build                 # all three

# Boot & use the fleet (Vagrant):
make up                    # boot all defined machines
cd vagrant && vagrant up ubuntu       # boot just one
vagrant ssh ubuntu                    # log in
vagrant provision ubuntu              # re-run the base playbook
make status                # what's running
make down                  # halt (keeps the disks)
make destroy               # remove the VMs (boxes stay; rebuildable)
```

### Box versioning & sharing with teammates

Every `build.sh` run publishes a **versioned** box into `boxes/<os>/` with a
Vagrant `metadata.json` (auto-bumps the patch version, or pass an explicit one):

```bash
scripts/build.sh ubuntu-2404            # → next version, e.g. 2.0.1
scripts/build.sh ubuntu-2404 3.0.0      # → explicit version
```

Pin a version per machine in `machines.yaml` with `box_version: "2.0.0"` (omit to
always use the latest). To share boxes with teammates, serve the catalog and
publish with a matching base URL:

```bash
# On the box host:
DEVFLEET_BOX_BASE_URL=http://boxhost:8099 scripts/build.sh ubuntu-2404
scripts/serve-boxes.sh 8099
# On a teammate's machine:
vagrant box add http://boxhost:8099/ubuntu-2404/metadata.json
```

### Shared folders: native vs rsync

Boxes bake in **VirtualBox Guest Additions** where they compile, giving native
`vboxsf` shared folders (live, bidirectional). Where GA won't build (currently
**Rocky 9** — VBox 7.1 GA vs the EL9 kernel), the box transparently falls back to
**rsync** (one-way sync at `up`/`reload`/`vagrant rsync`). This is controlled
per-OS by `synced_folder_type` in `machines.yaml`; the build never fails on GA,
and each box records the result in `/etc/devfleet-guest-additions`.

### Watching a long Packer build

A build runs an OS installer headless. To confirm it's progressing (not stuck at
a boot menu), snapshot the console:

```bash
VBoxManage controlvm <os_name> screenshotpng /tmp/vm.png
```

---

## 6. How to extend

### Add a package to every OS
Edit `ansible/roles/base/defaults/main.yml` → `base_common_packages`. Rebuild the
images (`make build`) to bake it in, or `vagrant provision` to apply at runtime.

### Add OS-family-specific setup
Put apt logic in `roles/base/tasks/Debian.yml`, dnf logic in `RedHat.yml`. They're
auto-included by `main.yml` based on `ansible_os_family`.

### Add a new dev-tooling role (e.g. `docker`, `languages`)
1. `ansible/roles/<name>/tasks/main.yml` (+ `defaults/`, family files as needed).
2. Add it to `ansible/playbooks/base.yml` under `roles:` (or make a new playbook).

### Add a new OS (e.g. Fedora, AlmaLinux)
1. Create `packer/<os>.pkrvars.hcl` (ISO URL, `sha256:` checksum, `guest_os_type`,
   `boot_command`, `http_directory`).
2. Create the unattended-install file under `packer/http/<os>/`.
3. `scripts/build.sh <os>` — screenshot early to tune the `boot_command`.

### Add a running machine
Add an entry to `vagrant/machines.yaml`:
```yaml
  - name: ubuntu-big
    box: devfleet/ubuntu-2404
    ssh_port: 2225
    memory: 8192
    cpus: 4
```
`vagrant up ubuntu-big`. No Ruby edits — the Vagrantfile iterates the list.

### Customize ONE machine differently (per-machine profiles)
Any single machine can diverge from the fleet via two optional `machines.yaml`
keys — no changes to the others:

- **`gui: true`** — boots the VM with a visible window + extra video memory
  (for a desktop; pair with a desktop role for something to display).
- **`extra_vars: {…}`** — merged into that machine's runtime Ansible run, so it
  can opt into extra roles. Gate roles in `base.yml` on the variable:
  ```yaml
  # base.yml
      - role: desktop
        when: devfleet_install_desktop | default(false) | bool
  ```
  ```yaml
  # machines.yaml — only THIS machine gets the desktop role + a window
    - name: ubuntu-desktop
      box: devfleet/ubuntu-2404
      ssh_port: 2226
      gui: true
      extra_vars: { devfleet_install_desktop: true }
  ```
`vagrant up ubuntu-desktop` (runtime), or bake it into a dedicated box by setting
the same var at build time. This is the general lever for "install X on just one
box" — write a role, toggle it per machine.

---

## 7. Troubleshooting — the real gotchas

These are things that actually bit us; documented so they don't bite again.

| Symptom | Cause & fix |
|---------|-------------|
| `packer validate`: *no checksum found* | The pinned ISO point-release moved. Fetch the current filename/checksum and update the `*.pkrvars.hcl` (`sha256:` value). |
| `Unknown post-processor type "vagrant"` | The Vagrant post-processor is a separate plugin in Packer ≥1.15. It's declared in `sources.pkr.hcl`; run `packer init packer`. |
| `Error finding "http/…"` | `http_directory` is relative to Packer's CWD. It's anchored with `${path.root}` — keep it that way. |
| `Output directory exists` | A leftover from an aborted run. `build.sh` passes `-force`; each OS has its own `output-<os>/`. |
| Build sits forever at **Waiting for SSH** | The unattended install never triggered *or* login failed. **Screenshot the console.** If stuck at the boot menu, the `boot_command` is wrong for that ISO's bootloader (GRUB vs isolinux — see below). If it reached a login prompt, the password/SSH-key setup in the install file is wrong. |
| GRUB vs isolinux boot commands | VirtualBox boots most ISOs in **BIOS** mode. Ubuntu/Rocky-DVD use GRUB (`e` to edit, `<f10>`/Ctrl-X to boot); Debian netinst and the **Rocky boot ISO** use **isolinux** (`<tab>` to append options, `<enter>` to boot). Using the wrong one leaves you stuck at the menu. |
| Ansible: *`community.general.yaml` callback removed* | Version skew — a newer collection dropped that callback. `ansible.cfg` uses the built-in `default` callback with `result_format=yaml` instead. |
| GA fails to compile (`Error 2`, `incompatible-pointer-types`) | Some OS/kernel/GA-version combos don't build (seen on Rocky 9.8 with VBox 7.1 GA). This is **best-effort** — the build continues and that OS uses rsync (`synced_folder_type: rsync` in `machines.yaml`). Check `/etc/devfleet-guest-additions` in the box. |
| Vagrant: `vboxsf` mount fails for an OS | That box's GA didn't build. Set `synced_folder_type: rsync` for it in `machines.yaml`. |

---

## 8. CI

`.github/workflows/lint.yml` runs on every push/PR — three parallel jobs:
`packer validate` (per OS), `ansible-lint` + `--syntax-check`, and
`vagrant validate`. No VMs are booted (CI runners have no nested virtualization),
so it's a fast static gate. Run the same checks locally with `make lint`.

---

## 9. Where to go next

See [roadmap.md](roadmap.md). Phase 3 is about turning proven base boxes into
genuinely useful dev environments: baking in Guest Additions, adding real
dev-tooling roles (languages, editors, dotfiles), box versioning/hosting, and
scheduled security-patch rebuilds.
