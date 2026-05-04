| qwerkyDOS v1.0 - Motorola 68000
| For QEMU: qemu-system-m68k -M virt -cpu m68000 -m 16M -kernel qwerky.elf -serial stdio

        .arch m68000
        .section .text
        .globl  _start

| Exception vector table (first 1024 bytes)
        .org    0x0000
        .long   0x00100000              | 0x000: Initial SSP (stack at 1MB)
        .long   _start                  | 0x004: Initial PC
        .space  0x100-8                 | 0x008-0x0FF: Unused vectors

| Goldfish TTY registers (QEMU virt machine)
| From QEMU source: hw/goldfish_tty.c
        UART_BASE        = 0xFF008000
        UART_PUT_CHAR    = UART_BASE + 0x00   | Write: transmit byte, Read: receive byte
        UART_BYTES_READY = UART_BASE + 0x04   | Read: number of bytes available
        UART_CMD         = UART_BASE + 0x08   | Command register

| Entry point
_start:
        lea     str_banner, %a0
        bsr     print_string
        bsr     newline
        lea     str_ready, %a0
        bsr     print_string
        bsr     newline

| Main command loop
cmd_loop:
        bsr     newline
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

| Print null-terminated string in A0
print_string:
        movem.l %d0/%a0, -(%sp)
1:      move.b  (%a0)+, %d0
        beq     2f
        bsr     putchar
        bra     1b
2:      movem.l (%sp)+, %d0/%a0
        rts

| Print newline
newline:
        move.b  #0x0D, %d0
        bsr     putchar
        move.b  #0x0A, %d0
        bsr     putchar
        rts

| Output character in D0.B to UART
putchar:
        move.l  %a0, -(%sp)
        move.l  #UART_PUT_CHAR, %a0
        move.b  %d0, (%a0)
        move.l  (%sp)+, %a0
        rts

| Input character from UART, returns in D0.B
getchar:
        movem.l %d1/%a0, -(%sp)
        move.l  #UART_BYTES_READY, %a0
1:      move.b  (%a0), %d1
        beq     1b
        move.l  #UART_PUT_CHAR, %a0
        move.b  (%a0), %d0
        movem.l (%sp)+, %d1/%a0
        rts

| Read a line into linebuf
read_line:
        movem.l %d0/%d1/%a0, -(%sp)
        lea     linebuf, %a0
        moveq   #0, %d1

1:      bsr     getchar
        cmpi.b  #0x0D, %d0
        beq     2f
        cmpi.b  #0x0A, %d0
        beq     2f
        cmpi.b  #0x08, %d0
        beq     3f
        cmpi.b  #0x7F, %d0
        beq     3f
        cmpi.b  #0x20, %d0
        blo     1b
        cmpi.b  #0x7F, %d0
        bhs     1b
        cmpi.w  #79, %d1
        bhs     1b
        move.b  %d0, (%a0)+
        addq.w  #1, %d1
        bsr     putchar
        bra     1b

3:      tst.w   %d1
        beq     1b
        subq.w  #1, %d1
        subq.l  #1, %a0
        move.b  #0x08, %d0
        bsr     putchar
        move.b  #0x20, %d0
        bsr     putchar
        move.b  #0x08, %d0
        bsr     putchar
        bra     1b

2:      move.b  #0, (%a0)
        movem.l (%sp)+, %d0/%d1/%a0
        rts

| Execute command in linebuf
exec_command:
        movem.l %d0/%d1/%a0/%a1/%a2/%a3, -(%sp)
        lea     linebuf, %a0

        move.l  %a0, %a1
1:      move.b  (%a1), %d0
        beq     2f
        cmpi.b  #'a', %d0
        blo     3f
        cmpi.b  #'z'+1, %d0
        bhs     3f
        subi.b  #0x20, %d0
        move.b  %d0, (%a1)
3:      addq.l  #1, %a1
        bra     1b
2:
        tst.b   (%a0)
        beq     cmd_exit

        lea     cmd_table, %a1

cmd_scan:
        move.l  (%a1), %d0
        beq     cmd_unknown
        move.l  %a1, %a2
        addq.l  #4, %a1
        move.l  %a0, %a3

1:      move.b  (%a1)+, %d0
        beq     2f
        cmp.b   (%a3)+, %d0
        beq     1b
3:      tst.b   (%a1)+
        bne     3b
        bra     cmd_scan

2:      tst.b   (%a3)
        bne     3b
        move.l  (%a2), %a0
        jsr     (%a0)
        bra     cmd_exit

cmd_unknown:
        lea     str_unknown, %a0
        bsr     print_string

cmd_exit:
        movem.l (%sp)+, %d0/%d1/%a0/%a1/%a2/%a3
        rts

| Command handlers
cmd_help:
        lea     str_help, %a0
        bsr     print_string
        rts

cmd_cls:
        moveq   #25, %d0
1:      bsr     newline
        subq.b  #1, %d0
        bne     1b
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
        stop    #0x2700
        rts

| Data strings
        .section .data

str_banner:
        .asciz  "\r\n+------------------------------+\r\n|                              |\r\n|   qwerkyDOS v1.0             |\r\n|   (c) 1982 qwerky Micro      |\r\n|                              |\r\n|   68000 CPU | 16MB RAM (virt)|\r\n|                              |\r\n+------------------------------+\r\n"

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

| Command table: 4-byte handler address + null-terminated name
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
        .long   0

| BSS section
        .section .bss
linebuf:
        .space  80