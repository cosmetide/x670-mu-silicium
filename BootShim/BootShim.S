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
  mov   x19, x0
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
  adr   x7, _TrampolineStart
  ldr   x9, =(FD_BASE - 0x1000)
  mov   x10, #(_TrampolineEnd - _TrampolineStart)
_CopyStub:
  ldr   w11, [x7], #4
  str   w11, [x9], #4
  subs  x10, x10, #4
  b.ne  _CopyStub

  // Make the copied trampoline visible to instruction fetch.
  ldr   x9, =(FD_BASE - 0x1000)
  ldr   x10, =(_TrampolineEnd - _TrampolineStart)
  add   x10, x9, x10
_CleanTrampoline:
  dc    cvac, x9
  add   x9, x9, #64
  cmp   x9, x10
  b.lo  _CleanTrampoline
  dsb   sy
  ic    iallu
  dsb   sy
  isb

  // Route early synchronous faults to the diagnostic trampoline. The vector
  // table is placed at the aligned second half of the reserved scratch page.
  ldr   x9, =(FD_BASE - 0x1000)
  add   x9, x9, #0x800
  msr   vbar_el1, x9
  isb

  // Visible progress labels over the red XNU takeover frame.
  adr   x0, _TextShimReady
  mov   x1, #32
  bl    _X670Log
  adr   x0, _TextCopyStart
  mov   x1, #64
  bl    _X670Log

  adr   x4, _Payload
  ldr   x5, =FD_BASE
  ldr   x6, =FD_SIZE
  ldr   x8, =FD_SIZE
  ldr   x17, =(FD_BASE + SEC_ENTRY_OFFSET)
  mov   x0, x19
  ldr   x9, =(FD_BASE - 0x1000)
  br    x9

_TrampolineStart:
// This routine is copied verbatim to RAM below FD_BASE. All branches are
// PC-relative and all input addresses/sizes are passed in registers.
_CopyAndEnter:
  // This is the only refresh inside the transfer path. Avoid repeated DSI
  // updates while copying so the panel queue cannot interrupt the FD move.
  stp   x4, x5, [sp, #-48]!
  stp   x6, x8, [sp, #16]
  str   x17, [sp, #32]
  adr   x0, _TextCopyLoopEntry
  mov   x1, #96
  bl    _X670Log
  ldr   x17, [sp, #32]
  ldp   x6, x8, [sp, #16]
  ldp   x4, x5, [sp], #48
  // Copy the FD directly. Exception stage markers separate source reads,
  // destination writes, and the remaining transfer without DSI refreshes.
_CopyLoop:
  mov   x16, #1
  ldr   w2, [x4], #4
  ldr   w3, [x4], #4
  mov   x16, #2
  str   w2, [x5], #4
  str   w3, [x5], #4
  mov   x16, #3
  subs  x6, x6, #8
  b.eq  _CopyFinished
  b     _CopyLoop

_CopyFinished:
  // Do not queue another DSI transfer here. The entry log already proves the
  // shim owns the panel; let Mu's SEC logger take over after the XIP copy.
  // Publish the copied XIP SEC image before entering it.
  mov   x9, x5
  sub   x9, x9, x16
  add   x10, x9, x16
_CleanFd:
  dc    cvac, x9
  add   x9, x9, #64
  cmp   x9, x10
  b.lo  _CleanFd
  dsb   sy
  ic    iallu
  dsb   sy
  isb
  mov   x0, x19
  br    x17

// A synchronous exception while reading or writing the appended FD is
// reported in place. x16 identifies whether the source or destination faulted.
_CopyException:
  msr   daifset, #0xf
  cmp   x16, #1
  b.eq  _CopyReadFault
  cmp   x16, #2
  b.eq  _CopyWriteFault
  adr   x0, _TextCopyLoopFault
  b     _CopyExceptionLog
_CopyReadFault:
  adr   x0, _TextCopyReadFault
  b     _CopyExceptionLog
_CopyWriteFault:
  adr   x0, _TextCopyWriteFault
_CopyExceptionLog:
  mov   x1, #160
  bl    _X670Log
_CopyExceptionHang:
  wfe
  b     _CopyExceptionHang

// Draw a white 5x7 uppercase log line on the inherited 1080x2400 panel.
// x0 = NUL-terminated text, x1 = top pixel row. This routine and its font,
// messages, and refresh helper are included in the copied trampoline block.
_X670Log:
  mov   x29, x30
  mov   x20, x0
  mov   x21, x1
  mov   x22, #24
  ldr   x23, =0x76c10000
  adr   x24, _X670Font5x7
  mov   w25, #0xffff
  movk  w25, #0xffff, lsl #16
_LogChar:
  ldrb  w0, [x20], #1
  cbz   w0, _LogDone
  cmp   w0, #32
  b.eq  _LogSpace
  sub   w1, w0, #65
  cmp   w1, #25
  b.hi  _LogChar
  mov   x2, #7
  madd  x3, x1, x2, x24
  mov   x26, #0
_LogRow:
  ldrb  w5, [x3], #1
  mov   x6, x21
  add   x6, x6, x26, lsl #1
  add   x6, x6, x26
  mov   w12, #16
  mov   x27, #0
_LogColumn:
  tst   w5, w12
  b.eq  _LogPixelSkip
  mov   x8, x22
  add   x8, x8, x27, lsl #1
  add   x8, x8, x27
  mov   x9, #4352
  madd  x10, x6, x9, x23
  add   x10, x10, x8, lsl #2
  str   w25, [x10]
  str   w25, [x10, #4]
  str   w25, [x10, #8]
  add   x10, x10, x9
  str   w25, [x10]
  str   w25, [x10, #4]
  str   w25, [x10, #8]
  add   x10, x10, x9
  str   w25, [x10]
  str   w25, [x10, #4]
  str   w25, [x10, #8]
_LogPixelSkip:
  lsr   w12, w12, #1
  add   x27, x27, #1
  cmp   x27, #5
  b.lo  _LogColumn
  add   x26, x26, #1
  cmp   x26, #7
  b.lo  _LogRow
  add   x22, x22, #24
  b     _LogChar
_LogSpace:
  add   x22, x22, #18
  b     _LogChar
_LogDone:
  bl    _X670Refresh
  mov   x30, x29
  ret

_X670Refresh:
  // Clean the full framebuffer before refreshing the command-mode panel.
  ldr   x9, =0x76c10000
  ldr   x10, =163200
_RefreshClean:
  dc    cvac, x9
  add   x9, x9, #64
  subs  x10, x10, #1
  b.ne  _RefreshClean
  dsb   sy

  // Wait up to 100 ms for the previous transfer before reusing the DSI queue.
  mrs   x12, cntpct_el0
  mrs   x13, cntfrq_el0
  mov   x14, #10
  udiv  x13, x13, x14
  add   x13, x13, x12
  ldr   x9, =0x1401300c
_WaitDsi:
  ldr   w11, [x9]
  tbz   w11, #31, _DsiReady
  mrs   x12, cntpct_el0
  cmp   x12, x13
  b.lo  _WaitDsi
_DsiReady:
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
  ret

_TextShimReady:
  .asciz "SHIM DISPLAY OK"
_TextCopyStart:
  .asciz "FD COPY START"
_TextCopyDone:
  .asciz "FD COPY DONE"
_TextSecEntry:
  .asciz "SEC ENTRY"
_TextCopyLoopEntry:
  .asciz "COPY LOOP ENTRY"
_TextCopyLoopFault:
  .asciz "COPY LOOP FAULT"
_TextCopyReadFault:
  .asciz "COPY READ FAULT"
_TextCopyWriteFault:
  .asciz "COPY WRITE FAULT"

.align 4
_X670Font5x7:
  .byte 14,17,17,31,17,17,17 // A
  .byte 30,17,17,30,17,17,30 // B
  .byte 14,17,16,16,16,17,14 // C
  .byte 30,17,17,17,17,17,30 // D
  .byte 31,16,16,30,16,16,31 // E
  .byte 31,16,16,30,16,16,16 // F
  .byte 14,17,16,23,17,17,15 // G
  .byte 17,17,17,31,17,17,17 // H
  .byte 31,4,4,4,4,4,31 // I
  .byte 7,2,2,2,18,18,12 // J
  .byte 17,18,20,24,20,18,17 // K
  .byte 16,16,16,16,16,16,31 // L
  .byte 17,27,21,21,17,17,17 // M
  .byte 17,25,21,19,17,17,17 // N
  .byte 14,17,17,17,17,17,14 // O
  .byte 30,17,17,30,16,16,16 // P
  .byte 14,17,17,17,21,18,13 // Q
  .byte 30,17,17,30,20,18,17 // R
  .byte 15,16,16,14,1,1,30 // S
  .byte 31,4,4,4,4,4,4 // T
  .byte 17,17,17,17,17,17,14 // U
  .byte 17,17,17,17,17,10,4 // V
  .byte 17,17,17,21,21,21,10 // W
  .byte 17,17,10,4,10,17,17 // X
  .byte 17,17,10,4,4,4,4 // Y
  .byte 31,1,2,4,8,16,31 // Z
  .ltorg

// VBAR_EL1 requires a 2 KiB-aligned table. The code/data above fits before
// this fixed offset; the 16 vectors consume the rest of the reserved page.
.org _TrampolineStart + 0x800, 0
_CopyVectorTable:
.rept 16
  b     _CopyException
  .space 124, 0
.endr
_TrampolineEnd:

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
