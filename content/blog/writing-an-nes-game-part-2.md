---
title: writing an nes game, part 2
date: "2014-10-14T15:30:00"
tags: [hacker school, nes]
---

# code layout

So before we get into the code itself, there are a couple more concepts that
will be important to understand, in order to understand why the code is laid
out the way it is.

First, we need to understand how the PPU handles drawing. The NES was designed
to work on CRT screens, which work by drawing a horizontal line at a time from
the top of the screen to the bottom, at which point it starts again at the
top. This is done by a device called an [electron
gun](https://en.wikipedia.org/wiki/Electron_gun), which fires electrons at a
screen of pixels. The key point here is that drawing is done sequentially, one
pixel at a time, and the mechanism requires some amount of time to move from
one line to the next, and to move from the bottom of the screen back to the
top. The period of time when the electron gun is moving from the end of one
line to the beginning of the next is called the "HBlank" time, and the period
of time when the electron gun is moving from the bottom of the screen back to
the top is called the "VBlank" time. Except during HBlank and VBlank, the PPU
is busy controlling what actually needs to be drawn, and manipulating it at
all can cause all kinds of weird graphical glitches, so we need to make sure
we only communicate with the PPU during HBlank or VBlank.

The way the NES handles this is to provide an interrupt (called NMI) which
fires at the beginning of every VBlank, which allows you to do all of your
drawing during a safe period of time. HBlank is harder to detect and not as
useful (since it occurs in the middle of drawing a frame), and so it is not
typically used except for some visual effects. NTSC television screens refresh
at 60 frames per second, and the CPU clock speed in the NES is approximately
1.79MHz, and so we get approximately 30,000 CPU cycles per frame, which
translates into roughly 5,000-10,000 opcodes. VBlank, though, only lasts
around 2273 cycles (roughly 400-800 opcodes), so drawing code needs to be
especially efficient. In particular, we don't want to do any game logic at all
during VBlank time, since that time is so limited.

The other aspect that needs to be handled is system initialization. When the
CPU starts up, it's in an undefined state, so we need to set things up to
ensure that the game executes in a repeatable way. Emulators tend to be
consistent in how they initialize the system state at startup, but this isn't
true of the real hardware, so it's important to do this explicitly. Also, the
PPU requires initialization, but that is handled automatically. It does take a
bit over 30,000 CPU cycles though (a little over one frame), so we wait for
two frames before starting our main game code. Two frames is plenty of time to
do any initialization we might need to do.

To illustrate these concepts, here is an example program which modifies the
background color every second. The details about how the background color is
set isn't particularly important (it's not really a feature you're likely to
use very often), but this should illustrate the basic structure of an NES
game. This isn't intended to be a lesson on 6502 assembly (there are plenty of
much better tutorials and references out there for that - see below), but just
to show how games for the NES specifically are structured.

```asm
.ROMBANKMAP
BANKSTOTAL  2
BANKSIZE    $4000
BANKS       1
BANKSIZE    $2000
BANKS       1
.ENDRO

.MEMORYMAP
DEFAULTSLOT  0
SLOTSIZE     $4000
SLOT 0       $C000
SLOTSIZE     $2000
SLOT 1       $0000
.ENDME

.ENUM $00
; declare the label 'sleeping' to refer to the byte at memory location $0000
sleeping     DB
; 'color' will then be at $0001
color        DB
; and 'frame_count' will be at $0002
frame_count  DB
.ENDE

  .bank 0 slot 0
  .org $0000
RESET:
  ; First, we disable pretty much everything while we try to get the system
  ; into a consistent state. In particular, we really don't want any
  ; interrupts to fire until the stack pointer is set up (because interrupt
  ; calls use the stack), and we don't want any drawing to be done until the
  ; PPU is initialized. 
  SEI              ; disable all IRQs
  CLD              ; disable decimal mode
  LDX #$FF
  TXS              ; Set up stack (grows down from $FF to $00, at $0100-$01FF)
  INX              ; now X = 0
  STX $2000.w      ; disable NMI (we'll enable it later once the ppu is ready)
  STX $2001.w      ; disable rendering (we're not using it in this example)
  STX $4010.w      ; disable DMC IRQs
  LDX #$40
  STX $4017.w      ; disable APU frame IRQ

  ; First wait for vblank to make sure PPU is ready. The processor sets a
  ; status bit when vblank ends, so we just loop until we notice it.
vblankwait1:
  BIT $2002        ; bit 7 of $2002 is reset once vblank ends
  BPL vblankwait1  ; and bit 7 is what is checked by BPL

  ; set everything in ram ($0000-$07FF) to $00, except for $0200-$02FF which
  ; is conventionally used to hold sprite attribute data. we set that range
  ; to $FE, since that value as a position moves the sprites offscreen, and
  ; when the sprites are offscreen, it doesn't matter which sprites are
  ; selected or what their attributes are
clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem

  ; initialize variables in ram
  LDA #%10000001
  STA color
  ; no need to initialize frame_count or sleeping, since we just set them to
  ; $00 in the clrmem loop

  ; Second wait for vblank, PPU is ready after this
vblankwait2:
  BIT $2002
  BPL vblankwait2

  LDA #%10000000   ; enable NMI interrupts now that the PPU is ready
  STA $2000

loop:
  ; sleep while vblank is happening. this serializes the code flow a bit
  ; (the NMI interrupt will almost certainly occur while we are in this loop
  ; unless we do a significant amount of processing in the main codepath, so
  ; it won't interrupt anything important). it also ensures that our game
  ; logic only executes once per frame.
  INC sleeping
wait_for_vblank_end:
  LDA sleeping
  BNE wait_for_vblank_end

  ; change color every 60 frames
  LDX frame_count
  CPX #60
  BCS change_color
  INX
  STX frame_count
  JMP loop_end

change_color:
  LDA #$00
  STA frame_count
  LDX color
  CPX #%10000001
  BEQ turn_green
  CPX #%01000001
  BEQ turn_red

turn_blue:
  LDA #%10000001
  STA color
  JMP loop_end
turn_green:
  LDA #%01000001
  STA color
  JMP loop_end
turn_red:
  LDA #%00100001
  STA color

loop_end:
  JMP loop

NMI:
  ; save the contents of the registers on the stack, since the interrupt can
  ; be called at any point in our main loop
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA color
  STA $2001

  ; indicate that we're done drawing for this frame
  LDA #$00
  STA sleeping
  ; and restore the register contents before returning
  PLA
  TAY
  PLA
  TAX
  PLA

  RTI

  .orga $FFFA
  .dw NMI
  .dw RESET
  .dw 0

  .bank 1 slot 1
  .org $0000
  .incbin "sprites.chr"
```

The first thing we do when the system turns on is disable IRQ interrupts.
Calling and returning from interrupts uses the system stack, but the stack
pointer could be pointing anywhere at this point, and so interrupts would be
confuse things quite a bit. We never reenable IRQ interrupts here because we
don't use them at all (they would be reenabled by the `CLI` instruction). Next
we disable decimal mode (this shouldn't actually do anything, since the NES
doesn't have a BCD chip, but no real reason not to do this, to avoid
confusion) and set the stack pointer to `$FF`. The stack pointer is stored in
the register named S, and it is a one-byte offset from the RAM address
`$0100`. The stack grows downward, so the stack pointer should start out
pointing to `$01FF`, and then it will be decremented by `PHA` instructions and
incremented by `PLA` instructions as necessary. Finally, we disable a bunch of
other functionality on the PPU and APU, since we don't want them to be active
until we have finished initializing.

We need to wait for a total of two frames to ensure that the PPU is entirely
initialized, so we next wait for the first frame to end, and then clear out
the entire RAM space, and then wait for the second frame to end. At this
point, the PPU is initialized, so we can enable NMI interrupts (by setting a
bit in the PPU control register at `$2000`) and begin our main loop.

The main loop is where all of the logic goes. In this example, we just
increment the frame count every frame, and change the background color (via
some magic) every 60 frames. This allows the NMI interrupt to do nothing more
than write a single value to the PPU, without requiring any logic at all. This
illustrates the basic principle of using the main game loop to set up values
in memory, which the code in the NMI interrupt can just read and act on
directly, without requiring any calculations.

Here are some more useful links discussing the topics in this post:

* [NES ASM Tutorial](http://nixw0rm.altervista.org/files/nesasm.pdf)
* [The frame and NMIs](http://wiki.nesdev.com/w/index.php/The_frame_and_NMIs)
* [6502 instruction set
  overview](http://www.dwheeler.com/6502/oneelkruns/asm1step.html)
* [6502 instruction set
  reference](http://e-tradition.net/bytes/6502/6502_instruction_set.html)
* [NES technical documentation](http://emu-docs.org/NES/nestech.txt)
