#!/usr/bin/env bash
#
# Idempotent bootstrap for the Talvio Terraform IaC development environment.
# Installs the core Terraform toolchain (Terraform, TFLint, terraform-docs) and
# initializes any Terraform configuration found in the repository.
#
# Safe to run repeatedly: every step checks for an existing, matching install
# before doing any work.

set -euo pipefail

# Pinned tool versions. Terraform tracks the HashiCorp apt repo; the others are
# pinned to a specific release for reproducible builds.
TFLINT_VERSION="v0.64.0"
TFDOCS_VERSION="v0.24.0"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }

# Print the first line of a command's output without using a pipe, so that
# `set -o pipefail` cannot trip on an early-closing reader (SIGPIPE).
first_line() {
  local out
  out="$("$@" 2>/dev/null)" || true
  printf '%s' "${out%%$'\n'*}"
}

install_terraform() {
  if command -v terraform >/dev/null 2>&1; then
    log "Terraform already installed: $(first_line terraform version)"
    return
  fi

  log "Installing Terraform via the HashiCorp apt repository"
  sudo apt-get update -qq
  sudo apt-get install -y -qq gnupg software-properties-common curl unzip

  if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then
    curl -fsSL https://apt.releases.hashicorp.com/gpg \
      | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  fi

  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  sudo apt-get update -qq
  sudo apt-get install -y -qq terraform
  log "Installed: $(first_line terraform version)"
}

install_tflint() {
  local current
  if command -v tflint >/dev/null 2>&1; then
    current="$(first_line tflint --version)"
    if [[ "$current" == *"${TFLINT_VERSION#v}"* ]]; then
      log "TFLint already installed: $current"
      return
    fi
  fi

  log "Installing TFLint ${TFLINT_VERSION}"
  curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip" -o /tmp/tflint.zip
  unzip -o -q /tmp/tflint.zip -d /tmp
  sudo install -m 0755 /tmp/tflint /usr/local/bin/tflint
  rm -f /tmp/tflint /tmp/tflint.zip
  log "Installed: $(first_line tflint --version)"
}

install_terraform_docs() {
  local current
  if command -v terraform-docs >/dev/null 2>&1; then
    current="$(first_line terraform-docs --version)"
    if [[ "$current" == *"${TFDOCS_VERSION}"* ]]; then
      log "terraform-docs already installed: $current"
      return
    fi
  fi

  log "Installing terraform-docs ${TFDOCS_VERSION}"
  curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/${TFDOCS_VERSION}/terraform-docs-${TFDOCS_VERSION}-linux-amd64.tar.gz" -o /tmp/terraform-docs.tgz
  tar -xzf /tmp/terraform-docs.tgz -C /tmp terraform-docs
  sudo install -m 0755 /tmp/terraform-docs /usr/local/bin/terraform-docs
  rm -f /tmp/terraform-docs /tmp/terraform-docs.tgz
  log "Installed: $(first_line terraform-docs --version)"
}

init_terraform() {
  # Initialize the root module only if the repository actually contains
  # Terraform configuration. Keeps the script safe for an empty repo.
  shopt -s nullglob
  local tf_files=(*.tf)
  shopt -u nullglob

  if [ ${#tf_files[@]} -eq 0 ]; then
    log "No root-level Terraform (*.tf) files found; skipping 'terraform init'"
    return
  fi

  log "Terraform configuration detected; running 'terraform init'"
  terraform init -input=false -no-color
}

main() {
  cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$(dirname "$(readlink -f "$0")")")"
  install_terraform
  install_tflint
  install_terraform_docs
  init_terraform
  log "Development environment ready."
}

main "$@"
