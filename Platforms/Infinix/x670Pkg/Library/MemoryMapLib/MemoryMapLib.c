#include <Library/MemoryMapLib.h>

// The stock X670 DTB reports RAM at 0x40000000 with a 0x3e605000-byte span.
// Keep the allocator below 0x50000000 until dynamic secure carveouts are
// resolved from LK/Android handoff data. The display buffer is separately
// reserved at its measured LK address.
STATIC EFI_MEMORY_REGION_DESCRIPTOR gMemoryDescriptor[] = {
  // Name, Address, Length, HobOption, ResourceType, ResourceAttribute, MemoryType, ArmAttribute
  {"UEFI Stack",       0x40000000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_CAP, BsData, WRITE_BACK},
  {"BootShim trampoline", 0x4007F000, 0x00001000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH},
  {"UEFI FD",          0x40080000, 0x00200000, AddMem, SYS_MEM, SYS_MEM_CAP, BsData, WRITE_BACK},
  {"DXE Heap",         0x40280000, 0x03C00000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK},
  {"Display Reserved", 0x76C10000, 0x01000000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH},

  {"GIC Distributor",    0x0C000000, 0x00040000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"GIC Redistributors", 0x0C040000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"WatchDog Timer",     0x10007000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Keypad",             0x10010000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display Config",     0x14000000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display Mutex",      0x14001000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
  {"Display DSI",        0x14013000, 0x00001000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE},
};

VOID
GetMemoryMap (
  OUT EFI_MEMORY_REGION_DESCRIPTOR **MemoryDescriptor,
  OUT UINT8                         *MemoryDescriptorCount
  )
{
  *MemoryDescriptor = gMemoryDescriptor;
  *MemoryDescriptorCount = ARRAY_SIZE (gMemoryDescriptor);
}
