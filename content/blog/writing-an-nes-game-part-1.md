---
title: writing an nes game, part 1
date: "2014-10-13T16:00:00"
tags: [hacker school, nes]
---

For the past week or so at Hacker School, I've been learning how to write
games for the NES. This was intended to just be a brief debugging detour for a
different project I was working on, but as these things tend to go, it turned
into an entire project on its own. You can see the end result at
[https://github.com/doy/nes-snake](https://github.com/doy/nes-snake), but I
wanted to go over the code to give an overview about what programming for the
NES is like.

The NES itself has three processors - a [6502
CPU](https://en.wikipedia.org/wiki/MOS_Technology_6502), a custom graphics
chip called the PPU (picture processing unit), and a custom sound chip called
the APU (audio processing unit, which I didn't use for this project). Game
data is stored in [ROM](https://en.wikipedia.org/wiki/Read-only_memory) banks,
typically with code and sprite data separate - code is stored in PRG-ROM
(which consists of some number of 16KB banks) and sprite data is stored in
CHR-ROM (which consists of some number of 8KB banks). The only difference
between these two (other than the size) is that PRG-ROM is mapped to the
address space of the CPU and CHR-ROM is mapped to the address space of the PPU
(the different chips also have different address spaces). My game is simple
enough to only require a single PRG-ROM bank and a single CHR-ROM bank.

The CPU in the NES has a single flat 16-bit address space, which contains
everything from system RAM (there is only 2KB of this), to [memory-mapped IO
ports](https://en.wikipedia.org/wiki/Memory-mapped_I/O) (so reading or writing
at specific memory locations doesn't actually access any memory, it instead
accesses some hardware pins), to battery-backed RAM on the cartridge itself
(if availble), to the actual program ROM. The PPU has its own entirely
separate 14-bit address space, which mostly holds raw sprite data, color
palettes, and information about which sprites should be drawn in which
locations on the screen (that last part is typically the only thing that needs
to be touched in a simple game).

So this is what the basic skeleton of a small NES program (which uses a
single 16KB PRG-ROM bank and a single 8KB CHR-ROM bank) looks like:

```asm
; .ROMBANKMAP describes the layout of the ROM banks that this assembly file
; will produce. They will end up laid out sequentially in the output file. In
; this case, we're writing a game that requires one 16KB PRG-ROM bank and one
; 8KB CHR-ROM bank, so we specify that there are two banks in total, and we
; then specify the sizes for each of those two banks. The output file, once
; linked, will be a 24KB file, where the first 16KB is the PRG-ROM data and
; the last 8KB is the CHR-ROM data.
.ROMBANKMAP
BANKSTOTAL  2
BANKSIZE    $4000 ; PRG-ROM is 16KB
BANKS       1
BANKSIZE    $2000 ; CHR-ROM is 8KB
BANKS       1
.ENDRO

; .MEMORYMAP describes how the ROM banks will be loaded into memory. On the
; NES, program ROM has $8000-$FFFF available to it in the address space (which
; corresponds to two banks of PRG-ROM data), but if you're only using a single
; bank, it is typically loaded at $C000 (since the interrupt vectors must be
; located at $FFFA/$FFFC/$FFFE). The CHR-ROM data isn't mapped into the main
; address space (it is instead mapped into the PPU's address space), so it
; doesn't actually matter what address we tell it to load into.
.MEMORYMAP
DEFAULTSLOT  0
SLOTSIZE     $4000
SLOT 0       $C000 ; a single PRG-ROM bank should be mapped at $C000
SLOTSIZE     $2000
SLOT 1       $0000 ; this location doesn't matter, CHR-ROM isn't in main memory
.ENDME

; .ENUM just creates a mapping of names to values. Variables don't actually
; exist in assembly - all you have is memory locations, and so variables
; can be simulated by creating aliases to locations in memory.
; .ENUM is just a convenient shortcut for defining labels that point
; to data. On the NES, the internal system RAM is located at $0000-$0800 (2KB),
; and so we can just define labels that point into that section of memory and
; use them as variables. In addition, most 6502 opcodes are shorter and faster
; if they are accessing memory within $0000-$00FF (called the "zero page"), and
; so we should try to put most common variables within that portion of memory.
; In addition to putting variables in the zero page, NES programs typically use
; $0100-$01FF for the stack (used by the PHA/PLA instructions) and $0200-$02FF
; for holding sprite data until it can be copied to the PPU, so you should
; avoid using those sections of RAM for arbitrary game data.
.ENUM $00
; global variable declarations go here
.ENDE

; This defines the first ROM bank (bank 0), and indicates that it will be
; loaded into slot 0 as defined above. 
  .bank 0 slot 0
; .org indicates the offset that the following assembly code will be created
; at, relative to the start of the current ROM bank. In this case, we're using
; an offset of $0000, so this code will be loaded into the NES address space
; starting at $C000.
  .org $0000

; The RESET label is the code that will be jumped to at power on (see below)
RESET:
  ; TODO: initialization code goes here
loop:
  ; TODO: game code goes here
  JMP loop

; The NMI label is the code that will be jumped to at the start of each frame
; (see below)
NMI:
  ; TODO: per-frame drawing code goes here
  RTI

; .orga defines the absolute address that the following assembly code will be
; created at. It must be a value within the current ROM bank. We're using .orga
; here because $FFFA is a special value to the NES, and so using it literally
; makes the code easier to understand. $FFFA is the start of three interrupt
; vectors that define which code to run when various things happen. The first
; one is the NMI handler, which runs on each frame. The second is the RESET
; handler, which runs at system startup. The third is the IRQ handler, which
; runs on external interrupts (usually from the APU or various external chips).
; We don't use the IRQ handler because we aren't doing any sound, and we aren't
; using any external chips, so it is just set to 0 (which disables it).
  .orga $FFFA
  .dw NMI   ; $FFFA contains the address to jump to at the start of each frame
  .dw RESET ; $FFFC contains the address to jump to at power-on
  .dw 0     ; $FFFE contains the address to jump to on an external interrupt

; This defines the second bank, which holds the CHR-ROM.
  .bank 1 slot 1
  .org $0000
; .incbin includes the contents of an external file literally into the output.
; Here, sprites.chr should contain the literal contents of the CHR-ROM. This is
; easier because the CHR-ROM doesn't contain any code, so defining it inline in
; the assembly code file would be quite a bit less convenient. I'll talk about
; ways to actually edit this file later.
  .incbin "sprites.chr" ; sprites.chr should be 8192 bytes
```

This is using the syntax for the WLA DX assembler, which works well on Linux
(most of the existing tutorials I've seen use various Windows-only
assemblers). I'm using the
[`wla_dx`](https://aur.archlinux.org/packages/wla_dx/) AUR package on Arch
Linux, but similar packages should be available for most distros. To compile
this code, follow these steps:

* Save the code as `test.s`
* Run `dd if=/dev/zero of=sprites.chr bs=8192 count=1` to create an empty CHR
  data file (which will be included in the output)
* Run `wla-6502 -o test.s` to generate an object file called `test.o`
* Create a file named `linkfile` which is used by the linker, with the contents

```
[objects]
test.o
```

* Run `wlalink linkfile test.rom` to create the actual ROM

This ROM is not yet in the format required to be run by most NES emulators. To
get it into this format, we need to add a 16-byte header which describes the
layout of the file. You can download the header I used from
[here](https://raw.githubusercontent.com/doy/nes-snake/master/header.bin) - it
specifies a layout containing one PRG-ROM bank and one CHR-ROM bank. If you're
interested in doing something different, you should read up on the [iNES ROM
format](http://wiki.nesdev.com/w/index.php/INES).

Once you have a file containing the header, you can create a file that will
actually work in an NES emulator by running `cat header.bin test.rom >
test.nes`. To run the ROM, I highly recommend using an emulator that aims for
accuracy - a lot of emulators out there aim for compatibility, which typically
means hacks for specific known games, and which will quite possibly just
result in breaking games that they don't know about (including new games you
are writing). Nestopia is a good recommendation if you don't know much about
the subject. To execute the ROM you just created, run `nestopia test.nes`. You
should just see a blank screen, since we haven't included any code to make it
do anything differently, but it should successfully load and run.

Next time I'll talk about the structure of the actual code in an NES game. For
further information about the topics in this post, here are some useful links:

* [WLA DX assembler reference](http://www.villehelin.com/wla.txt)
* [NES Assembly Tutorial](http://nixw0rm.altervista.org/files/nesasm.pdf)
* [NES Architecture](http://fms.komkon.org/EMUL8/NES.html)
* [NES 101](http://hackipedia.org/Platform/Nintendo/NES/tutorial%2c%20NES%20programming%20101/NES101.html)
* [NES technical documentation](http://emu-docs.org/NES/nestech.txt)
