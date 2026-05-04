; qwerkyDOS v1.0  --  Pure 65C02 Assembly
; For sim65 simulator
; Assembler: ca65 (cc65 suite)

        .setcpu "65C02"
        .include "sim65.inc"        ; defines SYS_PUTC, SYS_GETC, SYS_EXIT

; ---------------------------------------------------------------------------
; Memory layout (we control everything)
; ---------------------------------------------------------------------------
        .segment "CODE"             ; starts at $C000 from linker config

; ---------------------------------------------------------------------------
; Reset entry point
; ---------------------------------------------------------------------------
reset:
        sei                         ; no interrupts
        cld                         ; binary mode always
        ldx #$FF
        txs                         ; stack = $01FF

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
        ; Show prompt
        jsr     newline
        lda     #'q'
        jsr     putchar
        lda     #'>'
        jsr     putchar
        lda     #' '
        jsr     putchar

        ; Read a line into linebuf
        jsr     read_line

        ; Echo newline
        jsr     newline

        ; Parse and execute command
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
; Command table and execution
; ---------------------------------------------------------------------------
exec_command:
        ; Convert linebuf to uppercase
        ldx     #0
@upper:
        lda     linebuf,x
        beq     @done
        cmp     #'a'
        bcc     @next
        cmp     #'z'+1
        bcs     @next
        sec
        sbc     #$20
        sta     linebuf,x
@next:
        inx
        bne     @upper          ; safe, linebuf is 80 chars max
@done:

        ; Check for empty line
        lda     linebuf
        beq     @return

        ; Compare with known commands
        ldx     #<cmd_table
        ldy     #>cmd_table
        stx     $00
        sty     $01             ; ZP pointer to table
        ldy     #0

@cmd_loop:
        lda     ($00),y
        beq     @unknown        ; end of table (null)
        tax                     ; command handler low byte
        iny
        lda     ($00),y
        sta     $03             ; handler high byte
        iny
        stx     $02             ; handler low byte (little-endian)
        ; Now ($00),y points to command string (null-terminated)
        ; Compare string at ($00),y with linebuf
        sty     $04             ; save Y offset
        ldx     #0
@strcmp:
        lda     ($00),y
        cmp     linebuf,x
        bne     @next_cmd
        iny
        inx
        lda     ($00),y
        bne     @strcmp         ; still comparing
        lda     linebuf,x
        bne     @next_cmd       ; linebuf longer => no match
        ; Exact match! Jump to handler
        jmp     ($0002)

@next_cmd:
        ; Skip remaining chars of command name to find next entry
        ldy     $04
@skip:
        lda     ($00),y
        beq     @end_of_string
        iny
        bne     @skip
@end_of_string:
        iny                     ; skip past null terminator
        ; Now ($00),y is start of next handler+string pair
        ; Check if we reached end of table (null byte)
        lda     ($00),y
        bne     @cmd_loop
        ; Fall through to unknown

@unknown:
        lda     #<str_unknown
        ldy     #>str_unknown
        jsr     print_string
@return:
        rts

str_unknown:
        .byte   "? Unknown command. Type HELP.", $0D, $0A, 0

; ---------------------------------------------------------------------------
; Command handlers (all return with RTS, preserve regs except A,X,Y)
; ---------------------------------------------------------------------------
cmd_help:
        lda     #<str_help
        ldy     #>str_help
        jsr     print_string
        rts

cmd_cls:
        ; Clear screen: print 25 newlines
        ldx     #25
@loop:
        jsr     newline
        dex
        bne     @loop
        rts

cmd_beep:
        lda     #$07            ; bell
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
        ; Exit back to sim65 monitor
        ; sim65 SYS_EXIT = $FF00
        jsr     exit_sim
        ; Should not return, but just in case
        brk

        ; ------- Command table format: --------
        ; Each entry: 2 bytes handler address, then null-terminated name.
        ; End of table is a null byte.

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
        .byte   0               ; end marker

str_help:
        .byte   "Commands: HELP, CLS, BEEP, MEM, VER, Q", $0D, $0A, 0
str_mem:
        .byte   "Free: lots. Top of RAM: $C000 (ROM starts).", $0D, $0A, 0
str_ver:
        .byte   "qwerkyDOS v1.0   (c) 1982 qwerky Micro", $0D, $0A, 0

; ---------------------------------------------------------------------------
; Console I/O using sim65's built-in monitor
; ---------------------------------------------------------------------------
putchar:
        ; Character in A
        ; sim65 SYS_PUTC = $FF0F
        jsr     $FF0F
        rts

getchar:
        ; Returns char in A
        ; sim65 SYS_GETC = $FF12
        jsr     $FF12
        rts

exit_sim:
        ; sim65 SYS_EXIT = $FF00
        jmp     $FF00

; ---------------------------------------------------------------------------
; Print a null-terminated string via pointer in A/Y (low/high)
; ---------------------------------------------------------------------------
print_string:
        sta     $10
        sty     $11             ; ZP pointer
        ldy     #0
@loop:
        lda     ($10),y
        beq     @done
        jsr     putchar
        iny
        bne     @loop           ; safe for strings <256, we can add inc for longer
@done:
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
; Read a line into linebuf, handle backspace, max 79 chars
; ---------------------------------------------------------------------------
read_line:
        ldx     #0              ; buffer index
        stx     linepos
@key_loop:
        jsr     getchar
        cmp     #$0D            ; Enter
        beq     @done
        cmp     #$0A
        beq     @done
        cmp     #$08            ; Backspace
        beq     @backspace
        cmp     #$7F            ; Delete
        beq     @backspace
        ; Printable character?
        cmp     #$20
        bcc     @key_loop       ; ignore other control chars
        cmp     #$7F
        bcs     @key_loop
        ; Insert into buffer if not full
        cpx     #79
        bcs     @key_loop       ; buffer full, ignore
        sta     linebuf,x
        inx
        jsr     putchar         ; echo
        bne     @key_loop       ; always branch

@backspace:
        cpx     #0
        beq     @key_loop       ; nothing to delete
        dex
        ; echo backspace-space-backspace
        lda     #$08
        jsr     putchar
        lda     #$20
        jsr     putchar
        lda     #$08
        jsr     putchar
        bne     @key_loop

@done:
        ; null-terminate
        lda     #0
        sta     linebuf,x
        rts

; ---------------------------------------------------------------------------
; Data area (in RAM segment, but initial values from ROM if needed)
; We'll place these in a BSS section so they're zeroed on reset.
; ---------------------------------------------------------------------------
        .segment "BSS"
linebuf:    .res    80
linepos:    .res    1

; ---------------------------------------------------------------------------
; Hardware vectors
; ---------------------------------------------------------------------------
        .segment "VECTORS"
        .word   reset           ; NMI ($FFFA)
        .word   reset           ; RESET ($FFFC)
        .word   reset           ; IRQ/BRK ($FFFE)