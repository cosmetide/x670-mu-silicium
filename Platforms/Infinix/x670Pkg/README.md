# Infinix Note 12 G96 (X670) Mu-Silicium port

This is an initial MT6781 platform bring-up, kept separate from the Xiaomi
`stone` MT6789 platform. It uses the stock X670 Android DTB, LK's inherited
framebuffer/command-mode DSI state, and the device-specific boot image layout.

The current device tree reports 1 GiB of normal RAM beginning at `0x40000000`.
Until the secure and multimedia carveouts are fully mapped, the UEFI allocator
is intentionally limited to the low range through `0x50000000`. The inherited
framebuffer at `0x76c10000` is reserved separately. This is an early bring-up
map, not a complete Android memory map.

Button map is taken from the existing X670 U-Boot board code and the previous
X670 EDK II input driver: volume up is keypad bit 0 (EFI Up), volume down is
bit 1 (EFI Down), and power is bit 8 (Enter/select). The keypad controller is
at `0x10010000`; `MEM1` is active-low. The driver exposes both UEFI text input
protocols, including `SimpleTextInputEx`, so Mu's boot manager and menu dialogs
can receive those keys through the normal console input path.

This platform deliberately starts with the standard Mu-Silicium UEFI core,
simple framebuffer GOP, and an X670-specific logger and key driver. MT6789
GPIO, PMIC, clock, and storage implementation drivers are not enabled here;
MT6781 register compatibility for those drivers has not been established.

## Build with a smaller checkout

The X670 target does not use the all-device `Binaries` submodule or
`Silicium-ACPI`. Clone the fork without initializing every submodule, then
initialize only the packages used by this platform:

```bash
git clone --no-recurse-submodules https://github.com/cosmetide/x670-mu-silicium.git
cd x670-mu-silicium
git submodule update --init --recursive Common/Mu Common/Mu_OEM_Sample Mu_Basecore Silicon/Silicium/OpensslPkg/Library/OpensslLib/openssl
python3 build_uefi.py -d x670 -r DEBUG
```

Run the checkout from a Linux filesystem (for example, WSL's `/home/...`),
not from a Windows-mounted drive, to avoid slow Git and build-tool file scans.
