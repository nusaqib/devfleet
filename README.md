# devfleet

Reproducible, scalable, maintainable development VM infrastructure as code — designed to support multiple operating systems from a single source of truth.

📖 **New here? Read the [full guide](docs/GUIDE.md)** — architecture, workflows, how to extend, and troubleshooting.

## Stack (chosen)

- **Providers:** VirtualBox (portable) **and** libvirt/QEMU (KVM, fast on Linux) —
  built from one codebase; a box name carries both
- **OS matrix:** Ubuntu 24.04, Debian 12, Rocky 9
- **Cloud:** out of scope for now (local only)

## Philosophy

Three tools, one job each — so any layer can be swapped without rewriting the others:

| Layer        | Tool       | Responsibility                                              |
|--------------|------------|-------------------------------------------------------------|
| **Build**    | Packer     | Bake immutable, versioned base images per OS (golden images)|
| **Run**      | Vagrant    | Spin up local VMs from those images for day-to-day dev      |
| **Provision**| Ansible    | Install/configure tooling — shared across build *and* run   |

The key to **reproducibility** is that provisioning lives in Ansible roles used by
*both* Packer (build time) and Vagrant/Terraform (run time). The key to **multi-OS**
is that each OS is just another Packer template + Vagrant box entry that reuses the
same OS-agnostic roles wherever possible.

## Layout

```
devfleet/
├── packer/
│   ├── sources.pkr.hcl        # ONE reusable virtualbox-iso source (DRY)
│   ├── build.pkr.hcl          # shared provisioning + vagrant box output
│   ├── variables.pkr.hcl      # variable declarations
│   ├── *.pkrvars.hcl          # per-OS values (ubuntu-2404, debian-12, rocky-9)
│   ├── http/                  # unattended installs: autoinstall/preseed/kickstart
│   └── scripts/               # ansible-prereqs.sh, cleanup.sh
├── vagrant/
│   ├── Vagrantfile            # data-driven, reads machines.yaml
│   └── machines.yaml          # the fleet definition — add a VM by adding a line
├── ansible/
│   ├── ansible.cfg
│   ├── base.yml     # the ONE playbook used at build AND run time
│   ├── roles/base/            # family-aware (Debian.yml / RedHat.yml)
│   └── inventory/local.ini
├── scripts/                   # build.sh, lint.sh
├── Makefile                   # make build / up / lint / destroy
└── docs/                      # roadmap, decisions
```

## Prerequisites

Install on the host (none are present yet):

```bash
# Debian/Ubuntu host example
sudo apt-get install -y virtualbox
# Packer & Vagrant via HashiCorp apt repo, Ansible via pip/apt:
sudo apt-get install -y packer vagrant ansible ansible-lint
vagrant plugin install vagrant-vbguest   # optional: keeps guest additions in sync
```

## Quick start

```bash
make lint                 # validate every layer (no VMs needed)
make build-ubuntu         # packer build → registers box devfleet/ubuntu-2404
cd vagrant && vagrant up ubuntu   # boot it; runs the same base playbook
# or: make build && make up       # all three OSes end to end
```

## Design principles

- **Immutable images, mutable config** — rebuild images to change the base; use
  Ansible for anything that changes often.
- **DRY across OSes** — OS differences are expressed as variables, not forked scripts.
- **Pin everything** — image versions, box versions, role versions, tool versions.
- **CI-linted** — `packer validate`, `ansible-lint` + syntax-check, and
  `vagrant validate` run on every push/PR via
  [.github/workflows/lint.yml](.github/workflows/lint.yml). No VMs booted in CI.

## Status

Scaffold only. Next steps in `docs/roadmap.md`.
