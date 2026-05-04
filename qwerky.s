; qwerkyDOS v1.0  --  Pure 65C02 Assembly
; For sim65 simulator

        .setcpu "65C02"
        .export _main

; ---------------------------------------------------------------------------
; sim65 system call vectors
; ---------------------------------------------------------------------------
SYS_EXIT    = $FF00
SYS_PUTC    = $FF0F
SYS_GETC    = $FF12

; ---------------------------------------------------------------------------
; Memory layout
; ---------------------------------------------------------------------------
        .segment "CODE"

; ---------------------------------------------------------------------------
; Reset entry point
; ---------------------------------------------------------------------------
_main:
reset:
        sei
        cld
        ldx #$FF
        txs

        ; Print banner
        jsr     print_banner
        jsr     newline
        lda     #<str_ready
        ldy     #>str_ready
        jsr     print_string
        jsr     newline

; ---------------------------------------------------------------------------
; Main command loop
; ---------------------------------------------------------------------------
cmd_loop:
        jsr     newline
        lda     #'q'
        jsr     putchar
        lda     #'>'
        jsr     putchar
        lda     #' '
        jsr     putchar

        jsr     read_line
        jsr     newline
        jsr     exec_command
        jmp     cmd_loop

; ---------------------------------------------------------------------------
; Print banner
; ---------------------------------------------------------------------------
print_banner:
        lda     #<str_banner
        ldy     #>str_banner
        jsr     print_string
        rts

str_banner:
        .byte   $0D, $0A
        .byte   "+------------------------------+", $0D, $0A
        .byte   "|                              |", $0D, $0A
        .byte   "|   qwerkyDOS v1.0             |", $0D, $0A
        .byte   "|   (c) 1982 qwerky Micro      |", $0D, $0A
        .byte   "|                              |", $0D, $0A
        .byte   "|   65C02 CPU | 128K (sort of) |", $0D, $0A
        .byte   "|                              |", $0D, $0A
        .byte   "+------------------------------+", $0D, $0A
        .byte   0

str_ready:
        .byte   "Ready.", 0

; ---------------------------------------------------------------------------
; Command parser
; ---------------------------------------------------------------------------
exec_command:
        ; Uppercase the input buffer
        ldx     #0
upper_loop:
        lda     linebuf,x
        beq     upper_done
        cmp     #'a'
        bcc     upper_next
        cmp     #'z'+1
        bcs     upper_next
        sec
        sbc     #$20
        sta     linebuf,x
upper_next:
        inx
        bne     upper_loop
upper_done:

        ; Empty line check
        lda     linebuf
        beq     cmd_return

        ; Walk command table
        lda     #<cmd_table
        sta     $00
        lda     #>cmd_table
        sta     $01
        ldy     #0

cmd_match_loop:
        lda     ($00),y
        beq     cmd_unknown
        tax
        iny
        lda     ($00),y
        sta     $03
        iny
        stx     $02
        sty     $04
        ldx     #0

cmd_strcmp:
        lda     ($00),y
        cmp     linebuf,x
        bne     cmd_next
        iny
        inx
        lda     ($00),y
        bne     cmd_strcmp
        lda     linebuf,x
        bne     cmd_next
        jmp     ($0002)

cmd_next:
        ldy     $04
cmd_skip:
        lda     ($00),y
        beq     cmd_end_string
        iny
        bne     cmd_skip
cmd_end_string:
        iny
        lda     ($00),y
        bne     cmd_match_loop

cmd_unknown:
        lda     #<str_unknown
        ldy     #>str_unknown
        jsr     print_string
cmd_return:
        rts

str_unknown:
        .byte   "? Unknown command. Type HELP.", $0D, $0A, 0

; ---------------------------------------------------------------------------
; Command handlers
; ---------------------------------------------------------------------------
cmd_help:
        lda     #<str_help
        ldy     #>str_help
        jsr     print_string
        rts

cmd_cls:
        ldx     #25
cls_loop:
        jsr     newline
        dex
        bne     cls_loop
        rts

cmd_beep:
        lda     #$07
        jsr     putchar
        rts

cmd_mem:
        lda     #<str_mem
        ldy     #>str_mem
        jsr     print_string
        rts

cmd_ver:
        lda     #<str_ver
        ldy     #>str_ver
        jsr     print_string
        rts

cmd_quit:
        jmp     $FF00

; ---------------------------------------------------------------------------
; Command table: handler address (2 bytes) + null-terminated name
; ---------------------------------------------------------------------------
cmd_table:
        .word   cmd_help
        .byte   "HELP",0
        .word   cmd_cls
        .byte   "CLS",0
        .word   cmd_beep
        .byte   "BEEP",0
        .word   cmd_mem
        .byte   "MEM",0
        .word   cmd_ver
        .byte   "VER",0
        .word   cmd_quit
        .byte   "Q",0
        .word   cmd_quit
        .byte   "QUIT",0
        .byte   0

str_help:
        .byte   "Commands: HELP, CLS, BEEP, MEM, VER, Q", $0D, $0A, 0
str_mem:
        .byte   "Free: lots. Top of RAM: $C000 (ROM starts).", $0D, $0A, 0
str_ver:
        .byte   "qwerkyDOS v1.0   (c) 1982 qwerky Micro", $0D, $0A, 0

; ---------------------------------------------------------------------------
; Console I/O using sim65 monitor
; ---------------------------------------------------------------------------
putchar:
        jmp     $FF0F

getchar:
        jmp     $FF12

; ---------------------------------------------------------------------------
; Print null-terminated string, pointer in A/Y (low/high)
; ---------------------------------------------------------------------------
print_string:
        sta     $10
        sty     $11
        ldy     #0
ps_loop:
        lda     ($10),y
        beq     ps_done
        jsr     putchar
        iny
        bne     ps_loop
ps_done:
        rts

; ---------------------------------------------------------------------------
; Print newline (CR+LF)
; ---------------------------------------------------------------------------
newline:
        lda     #$0D
        jsr     putchar
        lda     #$0A
        jsr     putchar
        rts

; ---------------------------------------------------------------------------
; Read a line into linebuf with backspace handling
; ---------------------------------------------------------------------------
read_line:
        ldx     #0
rl_key_loop:
        jsr     getchar
        cmp     #$0D
        beq     rl_done
        cmp     #$0A
        beq     rl_done
        cmp     #$08
        beq     rl_backspace
        cmp     #$7F
        beq     rl_backspace
        cmp     #$20
        bcc     rl_key_loop
        cmp     #$7F
        bcs     rl_key_loop
        cpx     #79
        bcs     rl_key_loop
        sta     linebuf,x
        inx
        jsr     putchar
        bne     rl_key_loop

rl_backspace:
        cpx     #0
        beq     rl_key_loop
        dex
        lda     #$08
        jsr     putchar
        lda     #$20
        jsr     putchar
        lda     #$08
        jsr     putchar
        bne     rl_key_loop

rl_done:
        lda     #0
        sta     linebuf,x
        rts

; ---------------------------------------------------------------------------
; BSS data
; ---------------------------------------------------------------------------
        .segment "BSS"
linebuf:    .res    80