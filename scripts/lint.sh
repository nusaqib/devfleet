#!/usr/bin/env bash
# Validate every layer. Safe to run without VMs; good CI gate.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ">> packer fmt + validate"
packer fmt -check -recursive "$ROOT/packer" || packer fmt -recursive "$ROOT/packer"
packer init "$ROOT/packer"
for vf in "$ROOT"/packer/*.pkrvars.hcl; do
  echo "   validate: $(basename "$vf")"
  packer validate -var-file="$vf" "$ROOT/packer"
done

echo ">> ansible collections"
ansible-galaxy collection install -r "$ROOT/ansible/requirements.yml"

echo ">> ansible syntax + lint"
( cd "$ROOT/ansible" && ansible-playbook playbooks/base.yml --syntax-check )
if command -v ansible-lint >/dev/null 2>&1; then
  ( cd "$ROOT/ansible" && ansible-lint )
else
  echo "   (ansible-lint not installed — skipping)"
fi

echo ">> vagrant validate"
# --ignore-provider: skip provider-specific checks (e.g. vboxsf synced-folder
# "usability", which needs a running VM and fails when the vagrant-libvirt
# plugin is also installed). We only want to validate the Vagrantfile config.
( cd "$ROOT/vagrant" && vagrant validate --ignore-provider )

echo ">> all checks passed"
