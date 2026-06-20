#!/usr/bin/env bash
# Standalone Hyperlight demo runner — run ON the VM to (re)execute the demo
# after cloud-init, or to demo live. Safe to run multiple times.
set -uo pipefail

export PATH="$HOME/.cargo/bin:/usr/lib/llvm-18/bin:$PATH"
source "$HOME/.cargo/env" 2>/dev/null || true

echo "=========================================="
echo " Hyperlight micro-VM demo"
echo "=========================================="

echo
echo "### 1. Hypervisor check (KVM must be usable) ###"
ls -l /dev/kvm
kvm-ok || true
echo "groups: $(groups)"

echo
echo "### 2. Toolchain versions ###"
rustc --version
cargo --version
cargo hyperlight --version 2>/dev/null || echo "cargo-hyperlight not found"

echo
echo "### 3. Build the guest (OS-free ELF binary) ###"
cd "$HOME/hl-demo/guest"
cargo hyperlight build

echo
echo "### 4. Run the host -> spins up micro-VM, calls guest functions ###"
cd "$HOME/hl-demo/host"
echo "--- timed run ---"
/usr/bin/time -v cargo run --release

echo
echo "Done. A function returned from inside a hardware-isolated, OS-free micro-VM."
