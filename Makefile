AS      = ca65
LD      = ld65

TARGET  = sim65
ASFLAGS = -t $(TARGET)
LDFLAGS = -t $(TARGET) -C qwerky.cfg

qwerky.bin: qwerky.o
	$(LD) $(LDFLAGS) -o $@ qwerky.o

qwerky.o: qwerky.s sim65.inc
	$(AS) $(ASFLAGS) -o qwerky.o qwerky.s

run: qwerky.bin
	sim65 qwerky.bin

clean:
	rm -f *.o *.bin