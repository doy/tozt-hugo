---
title: writing an nes game, part 4
date: "2014-10-19T20:00:00"
tags: [hacker school, nes]
---

# graphics

Now that we can handle input, it's time to learn how to draw things. All
drawing on the NES is handled by the PPU. The PPU does sprite-based drawing,
meaning that all drawing is two dimensional, and happens in 8x8 blocks. Colors
are determined by a 16-color palette, of which a given sprite can only use
four colors (transparency being one of the colors). There is a background
layer, containing 32x30 tiles, and a set of up to 64 sprites, which can each
be either in front of or behind the background.

The PPU has its own memory space and mostly just runs on its own, handling the
redrawing automatically every frame. In order to tell it what to do, we have
to load various bits of data into its memory. As mentioned in an earlier post,
the PPU is only capable of doing one thing at a time, so this drawing must
happen at the beginning of the NMI interrupt, when we are guaranteed to be in
VBlank.

There are four steps involved in drawing a sprite. First, we need the sprite
itself. The pixel data for sprites is stored in the *pattern table*, and is
typically (although not always) stored in CHR-ROM. It contains 16 bytes per
sprite, where each pixel contains two bits of data, so each sprite can contain
at most four colors (including transparent). Since CHR-ROM banks are 8KB
each, this provides enough room for two sets of 256 tiles - typically one set
is used for the background and the other set is used for foreground sprites,
although this is not required. The patterns are laid out in memory as two
chunks of 8 bytes each, where the first 8 bytes correspond to the high bit for
the pixel, and the second 8 bytes correspond to the low bit for the pixel
(each byte representing a row of pixels in the sprite). To help with
generating this sprite data, I have written a script called
[pnm2chr](https://metacpan.org/pod/distribution/Games-NES-SpriteMaker/bin/pnm2chr),
which can convert images in the .PBM/.PGM/.PPM formats (which most image
editors can produce) into CHR-ROM data, so that you can edit sprites in an
image editor instead of a hex editor.

Once we have the pattern data, we then need the *palette table*, to determine
the actual colors that will be displayed for a given sprite. The way that
colors are determined is actually quite convoluted, going through several
layers of indirection. As a basis, the NES is capable of producing 52 distinct
colors (actually 51, since one of the colors ($0D) is outside of the NTSC
[gamut](https://en.wikipedia.org/wiki/Gamut), and can damage older TVs if
used). From those 52 colors, only 16 can be used at a time (although the 16
colors can be distinct for the background layer and the sprite layer), and
this set of 16 colors is known as the palette.

To determine which palette color to use for each pixel in a given background
tile, the two bits from the pattern table are combined with two additional
bits of data from the *attribute table* to create a four bit number (the
pattern bits being the low bits and the attribute bits being the high bits).
The attribute table is a 64-byte chunk of memory which stores two bits for
each 16x16 pixel area of the screen (so each sprite shares the same two-bit
palette with three other sprites in a 2x2 block). The attribute data itself is
packed into bytes such that each byte corresponds to a 4x4 block of sprites.
This is all pretty confusing, so here is a diagram (from the [NES Technical
Documentation](http://emu-docs.org/NES/nestech.txt)) which will hopefully make
things a bit clearer:

    +------------+------------+
    |  Square 0  |  Square 1  |  #0-F represents an 8x8 tile
    |   #0  #1   |   #4  #5   |
    |   #2  #3   |   #6  #7   |  Square [x] represents four (4) 8x8 tiles
    +------------+------------+   (i.e. a 16x16 pixel grid)
    |  Square 2  |  Square 3  |
    |   #8  #9   |   #C  #D   |
    |   #A  #B   |   #E  #F   |
    +------------+------------+

     Attribute Byte
       (Square #)
    ----------------
        33221100
        ||||||+--- Upper two (2) colour bits for Square 0 (Tiles #0,1,2,3)
        ||||+----- Upper two (2) colour bits for Square 1 (Tiles #4,5,6,7)
        ||+------- Upper two (2) colour bits for Square 2 (Tiles #8,9,A,B)
        +--------- Upper two (2) colour bits for Square 3 (Tiles #C,D,E,F)

For sprites, the upper two bits of the palette index is specified when
requesting the sprite to be drawn.

The data about which background tile to draw is then stored in the *name
table*. This is a sequence of bytes which correspond to offsets into the
pattern table. For instance, to draw the first pattern in the pattern table,
you would write a $00 to the corresponding location in the name table. The
name table data is the combined with the appropriate attribute table data to
get a palette index, which is then looked up in the palette table to determine
the actual colors to use when drawing the tile.

The data about which sprites to draw is stored in an entirely separate area of
memory (not part of any address space at all), called the SPR-RAM (sprite
RAM). It is 256 bytes long, and holds four bytes for each of the 64 sprites
that the NES is capable of drawing at any given time. The first byte holds the
vertical offset for the sprite (where the top left of the screen is (0, 0)),
the second byte holds the index into the pattern table for the sprite to draw,
the third byte holds various attributes about the sprite, and the fourth byte
holds the horizontal offset for the sprite. The sprite attributes contain
these bits of data:

* The low two bits (bits 0 and 1) contain the high bits of the palette index,
  as described above.
* Bit 5 is set if the sprite should be drawn behind the background.
* Bit 6 is set if the sprite should be flipped horizontally.
* Bit 7 is set if the sprite should be flipped vertically.

If you don't need all 64 sprites, you should just move the horizontal and
vertical coordinates such that the sprite is offscreen ($FE or so).

Now that we have seen all of the different pieces of the PPU memory, here is
how it is all laid out in memory:

    $0000: Pattern Table 0 (typically in CHR-ROM)
    $1000: Pattern Table 1 (typically in CHR-ROM)
    $2000: Name Table 0
    $23C0: Attribute Table 0
    $2400: Name Table 1
    $27C0: Attribute Table 1
    $2800: (used for mirroring, which I won't discuss here)
    $2BC0: (used for mirroring, which I won't discuss here)
    $2C00: (used for mirroring, which I won't discuss here)
    $2FC0: (used for mirroring, which I won't discuss here)
    $3000: (used for mirroring, which I won't discuss here)
    $3F00: Palette Table 0 (used for the background)
    $3F10: Palette Table 1 (used for sprites)
    $3F20: (used for mirroring, which I won't discuss here)
    $4000: (used for mirroring, which I won't discuss here)

So, to draw a background sprite at the top left of the screen, you would write
the sprite index to VRAM address $2000 (assuming default settings).

The final piece of information necessary to be able to use the PPU is how to
transfer data from main memory into VRAM. This is done via certain
memory-mapped IO addresses.

First, to copy data into SPR-RAM, you should write all of the sprite data to a
single page (a page is a 256-byte chunk of data whose addresses all start with
the same byte) in RAM, and then write the page number into address $4014 (the
$02 page ($0200-$02FF) is typically used for this purpose). The address to
start writing from can be set by writing a byte to address $2003, and so you
typically want to write $00 into $2003 before starting a full page transfer
with $4014. If you want to write to only certain parts of SPR-RAM, you can do
this via address $2004 - set the base address to write to via $2003 as above,
and then write a sequence of bytes to $2004 to store them into SPR-RAM.

To copy data into the main VRAM address space, you use the addresses $2006 and
$2007 in the same way that $2003 and $2004 were used for SPR-RAM, except that
you need to write two bytes into $2006 before you start writing to $2007,
since the address space is larger. Since the order of the bytes matters here,
you can read from $2002 to ensure that the next byte written to $2006 will be
the high byte of the address. Note that $2006 is also used for scrolling
(which is based on the last address written to), and so you generally want to
write $2000 back into $2006 at the end of drawing.

Finally, you need to initialize the PPU in a few ways in order to allow
drawing, which is done via $2000 and $2001. These addresses hold quite a few
different configuration bits, but the most important ones are:

* Bit 7 of $2000 should be set to enable NMI interrupts (we did this last
  time).
* Bit 4 of $2000 should be set to use pattern table 1 instead of 0 for
  the background.
* Bit 3 of $2000 should be set to use pattern table 1 instead of 0 for
  sprites.
* Bit 0 of $2000 should be set to use name table 1 instead of 0 (this is
  actually more complicated due to mirroring, but we won't get into that).
* Bit 4 of $2001 should be set to enable the sprite layer.
* Bit 3 of $2001 should be set to enable the background layer.

The default pattern and name tables will be fine for now, and so
initialization should set $2000 to $%10000000 and $2001 to $%00011000.

[Here](/blog/sprites.s) is a sample program which draws a background
and a sprite, and allows you to move the sprite around the background with the
controller D-pad. It will require a CHR-ROM data file with actual patterns in
it, so you can download that from [here]({{urls.media}}/sprites.chr)

Further reading:
* [NES ASM Tutorial](http://nixw0rm.altervista.org/files/nesasm.pdf)
* [NES technical documentation](http://emu-docs.org/NES/nestech.txt)
* [NES ROM Quickstart](http://sadistech.com/nesromtool/romdoc.html)
* [NES 101](http://hackipedia.org/Platform/Nintendo/NES/tutorial%2c%20NES%20programming%20101/NES101.html)
* [CHR ROM vs. CHR RAM](http://wiki.nesdev.com/w/index.php/CHR_ROM_vs._CHR_RAM)
* [CHR data layout for The Legend of Zelda](http://www.computerarcheology.com/wiki/wiki/NES/Zelda) (Note that unlike what is described above, Zelda stores its pattern data in RAM rather than ROM.)
