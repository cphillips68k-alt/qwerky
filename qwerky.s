; qwerkyDOS v1.0 - Motorola 68000
; For QEMU: qemu-system-m68k -M virt -cpu m68040 -m 16M -nographic -kernel qwerky.bin

        .section .text
        .globl  _start

; ---------------------------------------------------------------------------
; Exception vector table (must be first 1024 bytes)
; QEMU virt machine loads kernel at 0x0
; ---------------------------------------------------------------------------
        .org    0x0000
        .long   0x00100000              ; 0x000: Initial SSP (stack at 1MB)
        .long   _start                  ; 0x004: Initial PC (our entry point)
        .space  0x100-8                 ; 0x008-0x0FF: Other exception vectors (unused)
                                        ; Bus error, address error, illegal instr, etc.
                                        ; All point to a crash handler

; ---------------------------------------------------------------------------
; I/O addresses (QEMU virt machine)
; ---------------------------------------------------------------------------
UART_BASE   = 0xFF000000
UART_RHR    = UART_BASE + 0   ; Receive holding register
UART_THR    = UART_BASE + 0   ; Transmit holding register
UART_LSR    = UART_BASE + 5   ; Line status register
UART_LSR_RX = 0x01            ; Data ready bit
UART_LSR_TX = 0x20            ; Transmitter empty bit

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
_start:
        ; We're in supervisor mode, interrupts off
        ; Stack already set via vector table

        ; Print banner
        lea     str_banner, %a0
        bsr     print_string
        bsr     newline
        lea     str_ready, %a0
        bsr     print_string
        bsr     newline

; ---------------------------------------------------------------------------
; Main command loop
; ---------------------------------------------------------------------------
cmd_loop:
        bsr     newline
        ; Print prompt
        move.b  #'q', %d0
        bsr     putchar
        move.b  #'>', %d0
        bsr     putchar
        move.b  #' ', %d0
        bsr     putchar

        bsr     read_line
        bsr     newline
        bsr     exec_command
        bra     cmd_loop

; ---------------------------------------------------------------------------
; Print string (null-terminated) pointed to by A0
; ---------------------------------------------------------------------------
print_string:
        movem.l %d0/%a0, -(%sp)
ps_loop:
        move.b  (%a0)+, %d0
        beq     ps_done
        bsr     putchar
        bra     ps_loop
ps_done:
        movem.l (%sp)+, %d0/%a0
        rts

; ---------------------------------------------------------------------------
; Print newline (CR+LF)
; ---------------------------------------------------------------------------
newline:
        move.b  #0x0D, %d0
        bsr     putchar
        move.b  #0x0A, %d0
        bsr     putchar
        rts

; ---------------------------------------------------------------------------
; Output character in D0.B to UART
; ---------------------------------------------------------------------------
putchar:
        move.l  %d1, -(%sp)
        move.l  #UART_LSR, %a0
putchar_wait:
        move.b  (%a0), %d1
        andi.b  #UART_LSR_TX, %d1
        beq     putchar_wait
        move.l  #UART_THR, %a0
        move.b  %d0, (%a0)
        move.l  (%sp)+, %d1
        rts

; ---------------------------------------------------------------------------
; Input character from UART, returns in D0.B
; ---------------------------------------------------------------------------
getchar:
        move.l  #UART_LSR, %a0
getchar_wait:
        move.b  (%a0), %d0
        andi.b  #UART_LSR_RX, %d0
        beq     getchar_wait
        move.l  #UART_RHR, %a0
        move.b  (%a0), %d0
        rts

; ---------------------------------------------------------------------------
; Read a line into linebuf, handle backspace
; ---------------------------------------------------------------------------
read_line:
        movem.l %d0/%d1/%a0, -(%sp)
        lea     linebuf, %a0
        moveq   #0, %d1                 ; character count

rl_loop:
        bsr     getchar
        ; Check for Enter
        cmpi.b  #0x0D, %d0
        beq     rl_done
        cmpi.b  #0x0A, %d0
        beq     rl_done
        ; Check for backspace
        cmpi.b  #0x08, %d0
        beq     rl_back
        cmpi.b  #0x7F, %d0
        beq     rl_back
        ; Printable?
        cmpi.b  #0x20, %d0
        blo     rl_loop
        cmpi.b  #0x7F, %d0
        bhs     rl_loop
        ; Buffer full? (79 chars max)
        cmpi.w  #79, %d1
        bhs     rl_loop
        ; Store and echo
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        bsr     putchar
        bra     rl_loop

rl_back:
        tst.w   %d1
        beq     rl_loop
        subq.w  #1, %d1
        subq.l  #1, %a0
        ; Echo backspace-space-backspace
        move.b  #0x08, %d0
        bsr     putchar
        move.b  #0x20, %d0
        bsr     putchar
        move.b  #0x08, %d0
        bsr     putchar
        bra     rl_loop

rl_done:
        move.b  #0, (%a0)
        movem.l (%sp)+, %d0/%d1/%a0
        rts

; ---------------------------------------------------------------------------
; Command execution
; ---------------------------------------------------------------------------
exec_command:
        movem.l %d0/%d1/%a0/%a1, -(%sp)
        lea     linebuf, %a0

        ; Uppercase the line
        move.l  %a0, %a1
up_loop:
        move.b  (%a1), %d0
        beq     up_done
        cmpi.b  #'a', %d0
        blo     up_next
        cmpi.b  #'z'+1, %d0
        bhs     up_next
        subi.b  #0x20, %d0
        move.b  %d0, (%a1)
up_next:
        addq.l  #1, %a1
        bra     up_loop
up_done:

        ; Empty line?
        tst.b   (%a0)
        beq     cmd_exit

        ; Walk command table
        lea     cmd_table, %a1

cmd_scan:
        ; Check end of table (null name)
        move.w  (%a1), %d0
        beq     cmd_unknown
        ; %a1 points to handler address (4 bytes) + name string
        ; Compare strings
        move.l  %a1, %a2                ; save entry start
        addq.l  #4, %a1                 ; skip handler address
        move.l  %a0, %a3                ; linebuf pointer
cmd_cmp:
        move.b  (%a1)+, %d0
        beq     cmd_check_end           ; end of table name
        cmp.b   (%a3)+, %d0
        beq     cmd_cmp
        bra     cmd_next_entry

cmd_check_end:
        tst.b   (%a3)
        beq     cmd_match               ; both ended = match

cmd_next_entry:
        ; Skip remaining name bytes
cmd_skip:
        tst.b   (%a1)+
        bne     cmd_skip
        ; %a1 now points to next entry
        move.l  %a1, %a2                ; check if next entry exists
        move.w  (%a2), %d0
        bne     cmd_scan
        bra     cmd_unknown

cmd_match:
        move.l  %a2, %a1
        move.l  (%a1), %a0              ; load handler address
        jsr     (%a0)
        bra     cmd_exit

cmd_unknown:
        lea     str_unknown, %a0
        bsr     print_string

cmd_exit:
        movem.l (%sp)+, %d0/%d1/%a0/%a1
        rts

; ---------------------------------------------------------------------------
; Command handlers
; ---------------------------------------------------------------------------
cmd_help:
        lea     str_help, %a0
        bsr     print_string
        rts

cmd_cls:
        moveq   #25, %d0
cls_loop:
        bsr     newline
        subq.b  #1, %d0
        bne     cls_loop
        rts

cmd_beep:
        move.b  #0x07, %d0
        bsr     putchar
        rts

cmd_mem:
        lea     str_mem, %a0
        bsr     print_string
        rts

cmd_ver:
        lea     str_ver, %a0
        bsr     print_string
        rts

cmd_quit:
        ; Halt the CPU
        stop    #0x2700
        rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
        .section .data

str_banner:
        .asciz  "\r\n+------------------------------+\r\n|                              |\r\n|   qwerkyDOS v1.0             |\r\n|   (c) 2026      |\r\n|                              |\r\n|   68000 CPU | 16MB RAM (virt)|\r\n|                              |\r\n+------------------------------+\r\n"

str_ready:
        .asciz  "Ready."

str_unknown:
        .asciz  "? Unknown command. Type HELP.\r\n"

str_help:
        .asciz  "Commands: HELP, CLS, BEEP, MEM, VER, Q\r\n"

str_mem:
        .asciz  "Free: about 16MB. It's 2024, not 1982.\r\n"

str_ver:
        .asciz  "qwerkyDOS v1.0   (c) 1982 qwerky Micro\r\n"

; ---------------------------------------------------------------------------
; Command table: 4-byte handler address + null-terminated name
; ---------------------------------------------------------------------------
        .section .rodata
cmd_table:
        .long   cmd_help
        .asciz  "HELP"
        .long   cmd_cls
        .asciz  "CLS"
        .long   cmd_beep
        .asciz  "BEEP"
        .long   cmd_mem
        .asciz  "MEM"
        .long   cmd_ver
        .asciz  "VER"
        .long   cmd_quit
        .asciz  "Q"
        .long   cmd_quit
        .asciz  "QUIT"
        .long   0                       ; end marker

; ---------------------------------------------------------------------------
; BSS (uninitialized data)
; ---------------------------------------------------------------------------
        .section .bss
linebuf:
        .space  80