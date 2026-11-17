_Head:
  b     _Start          /* Match the stock/XNU Image entry stub */
  .long 0               /* Reserved code1 word */

#if REQUIRES_KERNEL_HEADER == 1
_StackBase:
  .quad IMAGE_TEXT_OFFSET /* Text Offset from a 2 MiB-aligned DRAM base */

_StackSize:
  .quad IMAGE_SIZE       /* Image size, including the shim and appended FD */
  .quad IMAGE_FLAGS      /* Match the stock ARM64 header flags */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .quad 0               /* Reserved */
  .ascii "ARM\x64"      /* ARM64 Magic */
  .long 0               /* Reserved */
#endif

_Start:
  // Mirror the XNU shim's minimal entry setup before doing framebuffer I/O.
  // Keep LK's DTB in x0 untouched for the firmware handoff.
  msr   daifset, #0xf
  msr   spsel, #1
  isb
  ldr   x9, =0x40040000
  mov   sp, x9

  // Stop the MTK watchdog before a full-frame clear and DSI refresh.
  ldr   x9, =0x10007000
  ldr   w10, [x9]
  bic   w10, w10, #1
  and   w10, w10, #0x00ffffff
  mov   w11, #0
  movk  w11, #0x2200, lsl #16
  orr   w10, w10, w11
  str   w10, [x9]

  // The boot image is loaded at FD_BASE. Copying the appended FD there
  // overwrites this shim, so take over the panel before starting that copy.
  bl    _X670DisplayHandoff

  // Run the FD copy loop from the unused page below FD_BASE. The FD is
  // loaded immediately after this shim, and the copy destination overlaps
  // the shim itself, so executing the loop in place is unsafe.
  adr   x7, _CopyAndEnter
  ldr   x9, =(FD_BASE - 0x1000)
  mov   x10, #(_CopyAndEnterEnd - _CopyAndEnter)
_CopyStub:
  ldr   w11, [x7], #4
  str   w11, [x9], #4
  subs  x10, x10, #4
  b.ne  _CopyStub

  // The copied routine must be visible to instruction fetch before we jump
  // into the scratch page. Clean addresses covering its 72-byte body.
  ldr   x9, =(FD_BASE - 0x1000)
  dc    cvac, x9
  add   x11, x9, #32
  dc    cvac, x11
  add   x11, x9, #64
  dc    cvac, x11
  add   x11, x9, #96
  dc    cvac, x11
  dsb   sy
  ic    iallu
  dsb   sy
  isb

  adr   x4, _Payload
  ldr   x5, =FD_BASE
  ldr   x6, =FD_SIZE
  ldr   x8, =FD_SIZE
  ldr   x17, =(FD_BASE + SEC_ENTRY_OFFSET)
  ldr   x9, =(FD_BASE - 0x1000)
  br    x9

// This routine is copied verbatim to RAM below FD_BASE. All branches are
// PC-relative and all input addresses/sizes are passed in registers.
_CopyAndEnter:
_CopyLoop:
  ldr   w2, [x4], #4
  ldr   w3, [x4], #4
  str   w2, [x5], #4
  str   w3, [x5], #4
  subs  x6, x6, #8
  b.ne  _CopyLoop

  // Publish the copied XIP SEC image before entering it.
  mov   x9, x5
  sub   x9, x9, x8
  add   x10, x9, x8
_CleanFd:
  dc    cvac, x9
  add   x9, x9, #64
  cmp   x9, x10
  b.lo  _CleanFd
  dsb   sy
  ic    iallu
  dsb   sy
  isb
  br    x17
_CopyAndEnterEnd:

_X670DisplayHandoff:
  // Match XNU's first visible takeover: clear the complete inherited panel red.
  ldr   x6, =0x76c10000
  mov   w7, #0
  movk  w7, #0xffff, lsl #16
  mov   x8, #2400
_X670RedRow:
  mov   x9, #1080
_X670RedPixel:
  str   w7, [x6], #4
  subs  x9, x9, #1
  b.ne  _X670RedPixel
  add   x6, x6, #32
  subs  x8, x8, #1
  b.ne  _X670RedRow

  // Write back the changed framebuffer before asking DSI to refresh it.
  ldr   x9, =0x76c10000
  ldr   x10, =163200
_X670Clean:
  dc    cvac, x9
  add   x9, x9, #64
  subs  x10, x10, #1
  b.ne  _X670Clean
  dsb   sy

  // The previous LK splash may still own the command queue. Match XNU's
  // timer-based 100 ms wait before programming another transfer.
  mrs   x12, cntpct_el0
  mrs   x13, cntfrq_el0
  mov   x14, #10
  udiv  x13, x13, x14
  add   x13, x13, x12
  ldr   x9, =0x1401300c
_X670WaitDsi:
  ldr   w11, [x9]
  tbz   w11, #31, _X670DsiReady
  mrs   x12, cntpct_el0
  cmp   x12, x13
  b.lo  _X670WaitDsi
_X670DsiReady:
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
  // Hold the red frame briefly before SEC replaces it with live Mu logs.
  mrs   x12, cntpct_el0
  mrs   x13, cntfrq_el0
  mov   x14, #4
  udiv  x13, x13, x14
  add   x13, x13, x12
_X670DisplayDelay:
  mrs   x12, cntpct_el0
  cmp   x12, x13
  b.lo  _X670DisplayDelay
  ret

_Dead:
  b     _Dead

.text
.align 4

_Payload:
