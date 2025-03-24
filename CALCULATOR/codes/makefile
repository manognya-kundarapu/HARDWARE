# Target microcontroller (ATmega328P for Arduino Uno)
MCU = atmega328p
F_CPU = 16000000UL

# Project files
TARGET = calci
SRC = $(TARGET).c
OBJ = $(TARGET).o
ELF = $(TARGET).elf
HEX = $(TARGET).hex
EEP = $(TARGET).eep

# Compiler and flags
CC = avr-gcc
OBJCOPY = avr-objcopy
CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os -Wall
LDFLAGS = -mmcu=$(MCU) -lm  # Link math library for trigonometric functions

# AVRDUDE settings (for flashing)
AVRDUDE = avrdude
PROGRAMMER = arduino
PORT = /dev/ttyACM0
BAUDRATE = 115200

# Build rules
all: $(HEX) $(EEP)

$(HEX): $(ELF)
	$(OBJCOPY) -O ihex -R .eeprom $< $@

$(EEP): $(ELF)
	$(OBJCOPY) -j .eeprom --set-section-flags=.eeprom="alloc,load" \
	--change-section-lma .eeprom=0 -O ihex $< $@

$(ELF): $(OBJ)
	$(CC) $(LDFLAGS) -o $@ $^

$(OBJ): $(SRC)
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f $(OBJ) $(ELF) $(HEX) $(EEP)

flash: $(HEX)
	$(AVRDUDE) -p $(MCU) -c $(PROGRAMMER) -P $(PORT) -b $(BAUDRATE) -U flash:w:$<

.PHONY: all clean flash
