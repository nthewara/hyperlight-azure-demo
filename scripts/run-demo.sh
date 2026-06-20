#!/usr/bin/env bash
# Live Hyperlight + Nanvix demo runner — run ON the VM. Safe to run repeatedly.
set -uo pipefail
source "$HOME/.cargo/env" 2>/dev/null || true
export PATH="$HOME/.cargo/bin:/usr/lib/llvm-18/bin:$PATH"

echo "=============================================="
echo " Hyperlight + Nanvix micro-VM demo"
echo "=============================================="

echo
echo "### 1. Hypervisor check (KVM must be usable) ###"
ls -l /dev/kvm
kvm-ok || true
grep -oE 'vmx|svm' /proc/cpuinfo | sort -u

echo
echo "### 2. Hyperlight: guest function inside an OS-free micro-VM ###"
if [ -d "$HOME/hyperlight" ]; then
  cd "$HOME/hyperlight"
  cargo run --example hello-world
else
  echo "(~/hyperlight not found — run cloud-init or clone hyperlight-dev/hyperlight)"
fi

echo
echo "### 3. Nanvix microkernel inside a Hyperlight micro-VM ###"
if [ -x "$HOME/nanvix/bin/nanvixd.elf" ]; then
  cd "$HOME/nanvix"
  ./bin/nanvixd.elf -console-file /dev/stdout -- ./bin/hello-rust-nostd.elf
else
  echo "(~/nanvix not built — run: cd ~/nanvix && ./z setup && ./z build -- all)"
fi

echo
echo "Done. A function (Hyperlight) and a full POSIX program (Nanvix) both ran"
echo "inside hardware-isolated, OS-free micro-VMs on this Azure VM."
