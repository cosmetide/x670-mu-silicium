# Project Silicium UEFI for ARM64-Based Devices

<!-- ![Banner](https://github.com/Project-Silicium/Mu-Silicium/blob/main/Resources/Pictures/Banner.png) -->

## Description

This Project focuses on Making ARM-Based Devices Boot Operating Systems like Windows or Linux using Custom UEFI Firmware.

## Infinix Note 12 G96 (X670)

This fork adds an experimental Mu-Silicium port for the MediaTek MT6781 X670.
The port is in early bring-up: its build target, stock DTB, framebuffer refresh,
and button mapping are being integrated. It has not yet been validated by
booting a Mu-Silicium image on the phone. See
[`Platforms/Infinix/x670Pkg/README.md`](Platforms/Infinix/x670Pkg/README.md)
for the X670 build instructions and current hardware notes.
The fork's **Actions** tab can build the DEBUG Android boot image remotely;
the image and SHA-256 checksum are published as workflow artifacts.

## Resources

- [Status](Status.md)
- [Building](Building.md)
- [Guides](https://github.com/Project-Silicium/Guides/blob/main/README.md)
- [Discord Server](https://discord.gg/Dx2QgMx7Sv)

## Frequently asked Questions

### **Is my Device Supported in this Project?**
- To Check if your Device is Supported, Take a Look at the Status Page Referenced in the Section Above.

### **What do I do if my Device isn't Supported in this Project?**
- We made some Guides that Explain How to Port your Device that are Referenced in the Section Above.

## Credits

[Microsoft](https://github.com/microsoft/) for their [Project Mu](https://microsoft.github.io/mu/) which Powers this Project. <br>
[WOA-Project](https://github.com/WOA-Project/) for their [mu_andromeda_platforms](https://github.com/WOA-Project/mu_andromeda_platforms/) which is used as Base for this Project. <br>
[Project Aloha](https://github.com/Project-Aloha/) for their [mu_aloha_platforms](https://github.com/Project-Aloha/mu_aloha_platforms/) which is used as Reference for some SoCs. <br>
[Open Surface RT](https://openrt.gitbook.io/open-surfacert/) for their Help on Tegra Related Stuff.

[sonic011gamer](https://github.com/sonic011gamer/) and [halal-beef](https://github.com/halal-beef/) for their Amazing Work on Exynos Related Stuff.

## License

All code except drivers in `GPLDrivers` & `GPLApplications` & `GPLLibrary` directories are licensed under BSD-2-Clause. <br />
GPL Drivers are licensed under `GPLv2` or later license.
