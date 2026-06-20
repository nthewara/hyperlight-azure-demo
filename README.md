# Hyperlight Azure Demo

An Azure VM lab that demos **[Microsoft Hyperlight](https://github.com/hyperlight-dev/hyperlight)** — a lightweight VMM that runs untrusted code inside **OS-free, hardware-isolated micro-VMs** that start in milliseconds, with guest function calls completing in microseconds.

This repo provisions an Intel **D4s_v5** VM (nested virtualization → KVM) via **Bicep**, installs the Rust toolchain + builds Hyperlight from the upstream repo, and runs a guest function **inside a micro-VM** to prove it works end-to-end. It also builds **[Nanvix](https://github.com/nanvix/nanvix)** (a Microsoft Research microkernel co-designed with Hyperlight) and runs a program inside a Nanvix micro-VM guest.

> Status: see the [tracking issue](https://github.com/nthewara/hyperlight-azure-demo/issues/1) for live progress. Deployed values (RG / public IP / captured demo output) are filled in once the lab is up.

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
- `az login` into subscription `b9d87a00-…-cfd7a9d745d2`
- Azure CLI with Bicep, an SSH keypair, your public IP (`curl https://api.ipify.org`)

### Steps
```bash
cd infra-bicep
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
cloud-init runs the demo automatically on first boot. To show it live yourself:

```bash
ssh azureuser@<PUBLIC_IP>

# 1. prove the hypervisor is there
ls -l /dev/kvm && kvm-ok

# 2. (re)run the micro-VM demo
bash ~/hl-demo-scripts/run-demo.sh      # or: ~/repo/scripts/run-demo.sh
# equivalently, by hand:
cd ~/hl-demo/guest && cargo hyperlight build
cd ~/hl-demo/host  && cargo run --release
```

Expected output (a function executed **inside the micro-VM**):
```
Hello, World! Today is Monday.
2 + 3 = 5
count = 1
count = 2
count = 3
count after restore = 1
```

The first boot's captured evidence is in `~/demo-output.txt` and `/var/log/hyperlight-demo.log` on the VM.

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
Microsoft **corp network IPs (167.220.x.x) cannot reach Azure VM public IPs.** This lab locks SSH to a home IP, so public-IP SSH works. If you're on corp net and it times out, use **Azure Bastion** or **Tailscale** instead (the NSG rule and routing would need adjusting).

---
_Attribution: Nirmal Thewarathanthri (GitHub: [nthewara](https://github.com/nthewara))._
