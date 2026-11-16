##
# X670 Infinix Note 12 G96 (MediaTek MT6781)
# SPDX-License-Identifier: BSD-2-Clause-Patent
##
[Defines]
  PLATFORM_NAME                  = x670
  PLATFORM_GUID                  = 9677F3C8-973F-44C7-BD1D-9C315BC5EDAF
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010005
  OUTPUT_DIRECTORY               = Build/x670Pkg
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = DEBUG|RELEASE
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = x670Pkg/x670.fdf
  USE_CUSTOM_DISPLAY_DRIVER      = 1
  USE_PHYSICAL_TIMER             = 1

!include SiliciumPkg/SiliciumPkg.dsc.inc

[PcdsFixedAtBuild]
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x40000000
  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0x40000000
  gArmPlatformTokenSpaceGuid.PcdCPUCorePrimaryStackSize|0x40000
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x0C000000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x0C040000
  gArmPlatformTokenSpaceGuid.PcdCoreCount|8
  gArmPlatformTokenSpaceGuid.PcdClusterCount|2
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemManufacturer|"Infinix"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemModel|"Note 12 G96"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"X670"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"Infinix_X670"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemBoardModel|"X670"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosProcessorModel|"MediaTek Helio G96"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosProcessorPartNumber|"MT6781"
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|1080
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|2400
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32

[LibraryClasses]
  MemoryMapLib|x670Pkg/Library/MemoryMapLib/MemoryMapLib.inf
  SerialPortLib|x670Pkg/Library/X670FrameBufferSerialPortLib/X670FrameBufferSerialPortLib.inf
  PlatformSecLib|MT6789Pkg/Library/PlatformSecLib/PlatformSecLib.inf

[Components]
  x670Pkg/X670SimpleFbDxe.inf
  x670Pkg/X670KeyDxe.inf
