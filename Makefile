AS      = ca65
LD      = ld65

ASFLAGS = -t sim65c02
LDFLAGS = -t sim65c02

qwerky.bin: qwerky.o
	$(LD) $(LDFLAGS) -o $@ $< sim65c02.lib

qwerky.o: qwerky.s
	$(AS) $(ASFLAGS) -o $@ $<

run: qwerky.bin
	sim65 qwerky.bin

clean:
	rm -f *.o *.bin