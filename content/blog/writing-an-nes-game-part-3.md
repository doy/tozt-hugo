---
title: writing an nes game, part 3
date: "2014-10-15T15:30:00"
tags: [hacker school, nes]
---

# input handling

Now that we have a general idea of how a program for the NES is structured,
it'd be useful to get a bit further into the specific capabilities of the NES.
One of the pretty basic (and pretty important) ones is reading input from the
controllers.

The basic structure of an NES controller is a [shift
register](https://en.wikipedia.org/wiki/Shift_register). To read the
controller inputs, you send a signal to the latch pin, which stores the state
of the input buttons in the register, and then you send a sequence of signals
to the clock pin to put the state of each button on the output in sequentially
(A, B, Select, Start, Up, Down, Left, Right). As it turns out, the code you
have to write to read from the controller maps pretty exactly to these
operations. This is what it looks like:

```asm
read_controller1:
  ; memory address $4016 corresponds to the shift register inside the
  ; controller plugged into the first controller port. writing to it sets the
  ; state of the latch pin, and so we set the latch pin high and then low in
  ; order to store the controller state in the shift register.
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  ; reading from $4016 reads the output value of the data pin and also sends a
  ; signal to the clock pin in order to put the next bit of data on the output
  ; for the next read. the value that is read has the state of the button in
  ; the low bit, and the upper bits contain various other pieces of
  ; information (such as whether a controller is plugged in at all, etc), so
  ; if we only care about the state of the button we have to mask out
  ; everything else.
read_a:
  LDA $4016
  AND #%00000001
  BEQ read_b
  ; code for if the a button is pressed
read_b:
  LDA $4016
  AND #%00000001
  BEQ read_select
  ; code for if the b button is pressed
read_select:
  LDA $4016
  AND #%00000001
  BEQ read_start
  ; code for if the select button is pressed
read_start:
  LDA $4016
  AND #%00000001
  BEQ read_up
  ; code for if the start button is pressed
read_up:
  LDA $4016
  AND #%00000001
  BEQ read_down
  ; code for if the up button is pressed
read_down:
  LDA $4016
  AND #%00000001
  BEQ read_left
  ; code for if the down button is pressed
read_left:
  LDA $4016
  AND #%00000001
  BEQ read_right
  ; code for if the left button is pressed
read_right:
  LDA $4016
  AND #%00000001
  BEQ end_read_controller1
  ; code for if the right button is pressed

end_read_controller1:
  RTS
```

Obviously this could be simplified by putting the reads in a loop (the [snake
game](https://github.com/doy/nes-snake) handles it by shifting and packing all
of the button states into a single byte which the code can query later on),
but that does require more CPU cycles, especially if not all of the buttons
are important.

In the spirit of continuing with real working code,
[here](/blog/input.s) is a sample program which changes the
background color every time you press A, rather than every second like last
time. Tomorrow, we'll work on drawing sprites!
