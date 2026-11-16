_Head:
  adr   x1, _Payload    /* Set _Entry address */
  b     _Start          /* Jump to the real code */

#if REQUIRES_KERNEL_HEADER == 1
_StackBase:
  .quad FD_BASE         /* Text Offset */

_StackSize:
  .quad FD_SIZE         /* Image Size */
  .quad 0               /* Flags */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .ascii "ARM\x64"      /* ARM64 Magic */
  .long 0               /* Reserved */
#endif

_Start:
  mov   x4, x1
  ldr   x5, =FD_BASE
  cmp   x4, x5
  beq   _Entry
  ldr   x6,  =FD_SIZE

_CopyLoop:
  ldp   x2, x3, [x4], #16
  stp   x2, x3, [x5], #16
  subs  x6, x6, #16
  b.ne  _CopyLoop
  ldr   x5, =FD_BASE

_Entry:
  // Take over LK's inherited command-mode display before entering SEC. This
  // cyan strip is an unmistakable handoff marker; Mu's SEC logger replaces
  // it with live firmware messages as soon as the FD starts.
  bl    _X670DisplayHandoff
  br    x5

_X670DisplayHandoff:
  // Fill the first 48 framebuffer rows (1088 pixels per row including pad).
  ldr   x6, =0x76c10000
  mov   w7, #0xffff
  movk  w7, #0xff00, lsl #16
  mov   x8, #(1088 * 48)
_X670Fill:
  str   w7, [x6], #4
  subs  x8, x8, #1
  b.ne  _X670Fill

  // Write back the changed framebuffer before asking DSI to refresh it.
  ldr   x9, =0x76c10000
  ldr   x10, =((1088 * 48 * 4) / 64)
_X670Clean:
  dc    cvac, x9
  add   x9, x9, #64
  subs  x10, x10, #1
  b.ne  _X670Clean
  dsb   sy

  // Same command-mode refresh sequence as the proven X670 U-Boot console.
  ldr   x9, =0x14001000
  mov   w10, #1
  str   w10, [x9, #0x20]
  ldr   x9, =0x14000000
  mov   w10, #0x14
  str   w10, [x9, #0xf0]
  ldr   x9, =0x14013000
  ldr   w10, =0x002c3909
  str   w10, [x9, #0x200]
  mov   w10, #1
  str   w10, [x9, #0x60]
  dsb   sy
  str   wzr, [x9]
  mov   w10, #1
  str   w10, [x9]
  dsb   sy
  // Leave a short visible window before SEC replaces the marker with logs.
  mov   x11, #0x100000
_X670DisplayDelay:
  subs  x11, x11, #1
  b.ne  _X670DisplayDelay
  ret

_Dead:
  b     _Dead

.text
.align 4

_Payload:
