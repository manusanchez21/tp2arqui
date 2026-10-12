ARMGNU ?= aarch64-linux-gnu
AOPS = -g --warn --fatal-warnings

all: kernel.img

asm: kernel.img

clean:
	rm -f *.o *.img *.hex *.elf *.list memory_map.txt

main.o: main.s
	$(ARMGNU)-as $(AOPS) main.s -o main.o

kernel.img: memmap main.o
	$(ARMGNU)-ld main.o -T memmap -o main.elf -Map memory_map.txt
	$(ARMGNU)-objdump -D main.elf > main.list
	$(ARMGNU)-objcopy main.elf -O ihex main.hex
	$(ARMGNU)-objcopy main.elf -O binary kernel.img

runQEMU:
	qemu-system-aarch64 -s -S -machine virt -cpu cortex-a53 -machine type=virt -nographic -smp 1 -m 64 -kernel kernel.img

runGDB:
	gdb-multiarch main.elf -ex "target remote localhost:1234" -ex "break *0x40080000" -ex "continue"
