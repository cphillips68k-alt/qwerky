AS      = m68k-linux-gnu-as
LD      = m68k-linux-gnu-ld
OBJCOPY = m68k-linux-gnu-objcopy

ASFLAGS = -m68040
LDFLAGS = -T linker.ld

qwerky.bin: qwerky.elf
	$(OBJCOPY) -O binary $< $@

qwerky.elf: qwerky.o
	$(LD) $(LDFLAGS) -o $@ $<

qwerky.o: qwerky.s
	$(AS) $(ASFLAGS) -o $@ $<

run: qwerky.bin
	qemu-system-m68k -M virt -cpu m68040 -m 16M -nographic -kernel qwerky.bin

debug: qwerky.bin
	qemu-system-m68k -M virt -cpu m68040 -m 16M -nographic -kernel qwerky.bin -s -S &
	gdb-multiarch -ex "target remote :1234" -ex "break _start" -ex "continue"

clean:
	rm -f *.o *.elf *.bin