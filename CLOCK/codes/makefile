# Target microcontroller
MCU = atmega328p
F_CPU = 16000000UL

# Output files
TARGET = clock
SRC = $(TARGET).c
OBJ = $(TARGET).o
ELF = $(TARGET).elf
HEX = $(TARGET).hex
EEP = $(TARGET).eep

# Compiler flags
CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -Wall

all: $(HEX) $(EEP)

$(HEX): $(ELF)
	avr-objcopy -O ihex -R .eeprom $< $@

$(EEP): $(ELF)
	avr-objcopy -j .eeprom --set-section-flags=.eeprom="alloc,load" \
	--change-section-lma .eeprom=0 -O ihex $< $@

$(ELF): $(OBJ)
	avr-gcc $(CFLAGS) -o $@ $^

$(OBJ): $(SRC)
	avr-gcc $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJ) $(ELF) $(HEX) $(EEP)

flash: $(HEX)
	avrdude -p $(MCU) -c arduino -P /dev/ttyACM0 -b 115200 -U flash:w:$<

.PHONY: all clean flash
