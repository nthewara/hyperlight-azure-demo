# Live Demo Script

The exact commands to show **Hyperlight** and **Nanvix-on-Hyperlight** running live on the Azure VM.

> Connect first: `ssh azureuser@<PUBLIC_IP>` (the deploy outputs print this).

---

## 0. Prove the hypervisor is real (the make-or-break check)

```bash
ls -l /dev/kvm        # device node must exist
kvm-ok                # must print: "KVM acceleration can be used"
grep -oE 'vmx|svm' /proc/cpuinfo | sort -u   # vmx => Intel VT-x nested virt
```

Expected:
```
crw-rw---- 1 root kvm 10, 232 ... /dev/kvm
INFO: /dev/kvm exists
KVM acceleration can be used
vmx
```

---

## 1. Hyperlight — a function executing inside an OS-free micro-VM

```bash
cd ~/hyperlight
cargo run --example hello-world
```

Expected output:
```
Hello, World! I am executing inside of a VM :)
```

That string was produced by a guest function running inside a **hardware-isolated micro-VM with no kernel or OS**. Warm runs complete in ~0.2 s end-to-end (the micro-VM create + guest call itself is microsecond-order; the rest is process startup).

To (re)build the guests first (already done by cloud-init):
```bash
cd ~/hyperlight && just rg          # build the rust guest binaries (x86_64-unknown-none)
```

---

## 2. Nanvix — a microkernel running a Rust program inside a Hyperlight micro-VM

[Nanvix](https://github.com/nanvix/nanvix) is a Microsoft Research microkernel co-designed with Hyperlight. Its `microvm` machine boots the microkernel **inside a Hyperlight micro-VM** and runs a POSIX user program.

```bash
cd ~/nanvix
./bin/nanvixd.elf -console-file /dev/stdout -- ./bin/hello-rust-nostd.elf
```

Key lines from the (verbose) microkernel boot:
```
[INFO][microvm] parse_bootinfo(): single-binary initrd detected ... cmdline="hello-rust-nostd.elf"
[INFO][kernel] spawn_servers(): spawning server: "hello-rust-nostd.elf"
[TRACE][posix::start] __nanvix_libc_start_main(): ...
Hello, world from Rust!
[TRACE] exit(): status=ExitStatus(0)
[TRACE][kernel] kmain(): the system will shutdown now!
```

`Hello, world from Rust!` is printed by a Rust program running **on the Nanvix microkernel, inside a Hyperlight micro-VM** — POSIX userspace with hardware isolation and no host OS in the guest.

Try other prebuilt guests too, e.g.:
```bash
./bin/nanvixd.elf -console-file /dev/stdout -- ./bin/thread-rust.elf
./bin/nanvixd.elf -console-file /dev/stdout -- ./bin/stress-rust.elf
```

---

## What this proves
| Layer | What runs | Isolation |
|-------|-----------|-----------|
| Hyperlight | a single Rust guest function (no OS) | hypervisor (KVM) |
| Nanvix-on-Hyperlight | a full POSIX program on a microkernel | hypervisor (KVM) + microkernel |

Both spin up in milliseconds and tear down cleanly — the core Hyperlight value proposition (hardware-isolated, OS-free, fast micro-VMs), demonstrated on stock Azure compute.
