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
sleeping     DB
color        DB
frame_count  DB
.ENDE

  .bank 0 slot 0
  .org $0000
RESET:
  SEI
  CLD
  LDX #$FF
  TXS
  INX
  STX $2000.w
  STX $2001.w
  STX $4010.w
  LDX #$40
  STX $4017.w

vblankwait1:
  BIT $2002
  BPL vblankwait1

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

  LDA #%10000001
  STA color

vblankwait2:
  BIT $2002
  BPL vblankwait2

  LDA #%10000000
  STA $2000

loop:
  INC sleeping
wait_for_vblank_end:
  LDA sleeping
  BNE wait_for_vblank_end

  ; controller 1 latch
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  ; controller 1 clock, reading the state of the A button
  LDA $4016
  AND #%00000001
  BNE change_color
  JMP loop_end
  ; reading the rest of the buttons is unnecessary, so we don't do it

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
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA color
  STA $2001

  LDA #$00
  STA sleeping
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
