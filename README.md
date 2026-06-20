# Hyperlight Azure Demo

An Azure VM lab that demos **[Microsoft Hyperlight](https://github.com/hyperlight-dev/hyperlight)** — a lightweight VMM that runs untrusted code inside **OS-free, hardware-isolated micro-VMs** that start in milliseconds, with guest function calls completing in microseconds.

This repo provisions an Intel **D4s_v5** VM (nested virtualization → KVM) via **Bicep**, installs the Rust toolchain + builds Hyperlight from the upstream repo, and runs a guest function **inside a micro-VM** to prove it works end-to-end. It also builds **[Nanvix](https://github.com/nanvix/nanvix)** (a Microsoft Research microkernel co-designed with Hyperlight) and runs a program inside a Nanvix micro-VM guest.

> **Status: ✅ VERIFIED working end-to-end on Azure** (2026-06-20). Both the Hyperlight micro-VM and the Nanvix-on-Hyperlight demos run and exit cleanly. Captured output: [`docs/evidence/`](docs/evidence/). See the [tracking issue](https://github.com/nthewara/hyperlight-azure-demo/issues/1) for the build log.
>
> **Live demo script:** [`docs/demo.md`](docs/demo.md) — the exact commands to show both demos.

## Why a VM (and why Intel v5)
Hyperlight needs a **hypervisor** (KVM on Linux). On Azure that means **nested virtualization**, which the **Dv5 / Dsv5 (Intel)** families support. **AMD (Dav5) does not expose nested virt the same way** — so this lab pins `Standard_D4s_v5`. The make-or-break check after boot is:

```bash
ls -l /dev/kvm     # device must exist
kvm-ok             # must say "KVM acceleration can be used"
```

## Architecture
```
You ──SSH(22)──► Azure VM (D4s_v5, Ubuntu 22.04)
   public IP        └─ KVM ─► Hyperlight host (Rust) ─► micro-VM (OS-free ELF guest)
                                                          guest fn returns in ~µs
```
- Public IP (Standard, static); **NSG allows inbound TCP 22** locked to your IP `/32`
- Tags: `purpose=hyperlight-demo`, `owner=nirmal`, `lab=true`, `inbound-access=ssh-22-open-by-design`

## Deploy (Bicep)

### Prereqs
- `az login` and select your target subscription (`az account set --subscription <SUB_ID>`)
- Azure CLI with Bicep, an SSH keypair, your public IP (`curl https://api.ipify.org`)

### Steps
```bash
cd infra-bicep
# optionally: export AZURE_SUBSCRIPTION_ID=<your-sub-id>
./deploy.sh <YOUR_IP>/32 ~/.ssh/id_ed25519.pub
```
or manually:
```bash
az deployment sub create \
  --name hyperlight-$(date +%s) --location australiaeast \
  --template-file main.bicep \
  --parameters sshSourceCidr="<YOUR_IP>/32" sshPublicKey="$(cat ~/.ssh/id_ed25519.pub)"
```
The deployment outputs print the public IP and ready-to-paste `ssh` command.

Real parameter values are passed on the command line (not committed); only `main.parameters.example.json` is in git.

## Run the demo (live)
cloud-init runs both demos automatically on first boot. The full **live-demo command sequence** is in **[`docs/demo.md`](docs/demo.md)**. Quick version:

```bash
ssh azureuser@<PUBLIC_IP>

# 1. prove the hypervisor is there
ls -l /dev/kvm && kvm-ok

# 2. Hyperlight: a guest fn inside an OS-free micro-VM
cd ~/hyperlight && cargo run --example hello-world
#   -> Hello, World! I am executing inside of a VM :)

# 3. Nanvix microkernel inside a Hyperlight micro-VM
cd ~/nanvix && ./bin/nanvixd.elf -console-file /dev/stdout -- ./bin/hello-rust-nostd.elf
#   -> ... spawning server "hello-rust-nostd.elf" ... Hello, world from Rust! ... ExitStatus(0)
```

First-boot captured evidence is in `~/hyperlight-evidence.txt` and `~/nanvix-evidence.txt` on the VM (and mirrored in [`docs/evidence/`](docs/evidence/)).

## Cost & lifecycle
`D4s_v5` ≈ **$0.30/hr** while running.

```bash
# stop billing (keep the VM)
az vm deallocate -g <RG> -n <VM>
# start again
az vm start -g <RG> -n <VM>
# full teardown
az group delete -n <RG> --yes --no-wait
```

## ⚠️ Connectivity gotcha
This lab locks inbound SSH (TCP 22) to a single `/32` — the IP you pass at deploy time. If you connect from a **different network** than the one you allow-listed (corporate networks, VPNs, and some carrier-grade NATs are common culprits), the SSH attempt will simply time out.

Fixes:
- Re-run the deploy with your current public IP (`curl https://api.ipify.org`), or update the NSG rule's source prefix, **or**
- Front the VM with **Azure Bastion** (browser/CLI SSH, no public-IP exposure), **or**
- Put the VM on an overlay like **Tailscale / WireGuard** and SSH over the private address.

---
_Attribution: Nirmal Thewarathanthri (GitHub: [nthewara](https://github.com/nthewara))._
