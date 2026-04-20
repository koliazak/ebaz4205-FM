# Building PetaLinux for EBAZ4205 FM Radio

This guide describes how to configure and build the custom PetaLinux distribution required to run the FM Radio SDR project on the EBAZ4205 board.

## 1. Environment 

**Tested on:**
- **OS:** Fedora 43
- **PetaLinux:** 2025.2
- **Vivado:** 2025.2

---

## 2. PetaLinux Configuration

Initialize the PetaLinux environment and create the project:

```bash
source <path-to-petalinux>/settings.sh
cd <path-to-your-project>

petalinux-create -t project -n ebaz4205-FM --template zynq
cd ebaz4205-FM

petalinux-config --get-hw-description=<full_path>/ebaz4205-FM.xsa
```

### System Configuration (`petalinux-config`)
In the menuconfig dialog, configure the following:

* **Hardware Check:** Verify that your hardware components are presented.
* **Image Offsets:** Go to **u-boot Configuration ➔ u-boot script configuration ➔ JTAG/DDR image offsets** and set:
  * Devicetree offset: `0x100000`
  * Kernel offset: `0x200000`
  * Ramdisk image offset: `0x4000000`
  * Fit image offset: `0x6000000`
  * Boot script offset: `0x3000000`
* **Bootargs:** Go to **DT settings ➔ Kernel Bootargs** and set:
  ```text
  earlycon console=ttyPS0,115200 clk_ignore_unused root=/dev/mmcblk0p2 rw rootwait cma=8M uio_pdrv_genirq.of_id=generic-uio
  ```

### Kernel Configuration
Run `petalinux-config -c kernel` and enable UIO:
* Go to: **Device Drivers ➔ Userspace I/O drivers**
* Enable: `<*>` **Userspace I/O platform driver with generic IRQ handling**
* Save and exit.

### U-Boot Configuration
Run `petalinux-config -c u-boot`:
* Go to: **Boot Options ➔ Boot Media**
* Enable the **SD** option.
* Save and exit.

### RootFS Configuration
Run `petalinux-config -c rootfs` and choose the required packages. For the web server backend, you will need Python:
* Go to: **Filesystem Packages ➔ misc ➔ python3**
* Enable both `python3` and `python3-pip`.
* Save and exit.

### Device Tree & Build
Copy `system-user.dtsi` to `project-spec/meta-user/recipes-bsp/device-tree/files/`.

Run the build process (this will take some time):
```bash
petalinux-build
```

---

## 3. Packaging Linux

When the build is complete, generate the boot image (`BOOT.BIN`):

```bash
cd images/linux
petalinux-package --boot --fsbl zynq_fsbl.elf --fpga system.bit --u-boot u-boot.elf -o BOOT.BIN --force
```

---

## 4. Prepare SD Card

You need to divide your SD card into 2 partitions using a tool like `fdisk` or `gparted`:
* **Partition 1 (BOOT):** Primary, default offset, size `+1024MB`, FAT32 (`0x0b`), **bootable flag enabled**.
* **Partition 2 (rootfs):** Primary, default offset, remaining size, Linux (`0x83`).

Create the filesystems:
```bash
sudo mkfs.msdos -n BOOT /dev/sdb1
sudo mkfs.ext4 -L rootfs /dev/sdb2
```

Copy the boot files and unpack the root filesystem (assuming your partitions are mounted at `/mnt/BOOT` and `/mnt/rootfs`):

```bash
# 1. Copy boot files to the FAT32 partition
sudo cp BOOT.BIN boot.scr image.ub /mnt/BOOT/

# 2. Unpack the root filesystem to the ext4 partition
sudo tar xvzf rootfs.tar.gz -C /mnt/rootfs
sudo chown root:root /mnt/rootfs
sudo chmod 755 /mnt/rootfs
sync
```
