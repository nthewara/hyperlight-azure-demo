# Proving it's a *real* micro-VM (not a container or process)

Use these during the demo to show the audience this is genuine **hardware-level virtualization**, not a sandbox/namespace trick. Run on the VM: `ssh azureuser@<PUBLIC_IP>` (the deploy outputs print this).

---

## ⭐ The killer proof: watch it drive the KVM hypervisor (`strace`)

A container or normal Linux process **never** opens `/dev/kvm` or issues `KVM_*` ioctls. Hyperlight does — live:

```bash
cd ~/hyperlight
cargo build --example hello-world            # build once
strace -f -e trace=openat,ioctl \
  ./target/debug/examples/hello-world 2>&1 \
  | grep -E "/dev/kvm|KVM_"
```

What you'll see (and what each line means):
```
openat(.., "/dev/kvm", O_RDWR..) = 3     # open the hypervisor interface
ioctl(3, KVM_GET_API_VERSION) = 12       # talk to KVM
ioctl(3, KVM_CREATE_VM)       = 4        # >>> CREATE A VIRTUAL MACHINE
ioctl(4, KVM_CREATE_VCPU)     = 5        # >>> CREATE A VIRTUAL CPU
ioctl(5, KVM_SET_CPUID2 ...)             # set guest CPU features
ioctl(5, KVM_SET_SREGS ...)              # set segment regs (note l=1 => 64-bit long mode)
ioctl(4, KVM_SET_USER_MEMORY_REGION ...) # map guest physical memory
ioctl(5, KVM_SET_REGS {rip=0x5f900..})   # set the instruction pointer
ioctl(5, KVM_RUN)             = 0        # >>> ENTER GUEST MODE AND RUN
...
Hello, World! I am executing inside of a VM :)
```

**Talking point:** `KVM_CREATE_VM` + `KVM_CREATE_VCPU` + `KVM_RUN` = the kernel literally spun up a VM with its own virtual CPU and ran our guest code on it, isolated by the CPU's VT-x/SVM hardware. No OS, no container — a micro-VM.

Captured copy: [`docs/evidence/microvm-strace-proof.txt`](evidence/microvm-strace-proof.txt).

---

## Supporting proofs

**1. The hypervisor device exists and is usable**
```bash
ls -l /dev/kvm            # crw-rw---- root kvm
kvm-ok                    # "KVM acceleration can be used"
lsmod | grep kvm          # kvm_intel loaded
```

**2. The guest itself says so**
The example's guest function returns the string `"...I am executing inside of a VM :)"` — that code path only runs *inside* the guest.

**3. It can't run without hardware virt**
On a box without nested virt, `KVM_CREATE_VM` fails and Hyperlight errors out — i.e. it genuinely needs the hypervisor; it's not faking isolation in userspace.

**4. Nanvix takes it further** (Demo 2)
`~/nanvix/bin/nanvixd.elf ... hello-rust-nostd.elf` boots an entire **microkernel** inside the micro-VM (you'll see `[microvm] parse_bootinfo()`, CPU feature probing, a process being spawned, then `the system will shutdown now!`). That whole OS-like boot happens inside the same KVM micro-VM.

---

## One-liner for the demo
```bash
strace -f -e ioctl ~/hyperlight/target/debug/examples/hello-world 2>&1 | grep -E "KVM_(CREATE_VM|CREATE_VCPU|RUN)"
```
→ shows `KVM_CREATE_VM`, `KVM_CREATE_VCPU`, `KVM_RUN`. That's the micro-VM, proven.
