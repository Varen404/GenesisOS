BUILD  := build
IMAGE  := $(BUILD)/genesis.img
BOOT   := $(BUILD)/boot.bin
KERNEL := $(BUILD)/kernel.bin

# Adresse physique du kernel, partagee par le bootloader et le kernel.
KERNEL_ADDRESS := 0x10000

.PHONY: all run clean

all: $(IMAGE)

# Image disque : secteur de boot, puis kernel, arrondi a un multiple de 512 octets.
$(IMAGE): $(BOOT) $(KERNEL)
	cat $^ > $@
	truncate --size=%512 $@

$(KERNEL): kernel/kernel.asm | $(BUILD)
	nasm -f bin -DKERNEL_ADDRESS=$(KERNEL_ADDRESS) $< -o $@

# Le secteur de boot depend du kernel : il doit connaitre sa taille en secteurs.
$(BOOT): boot/boot.asm boot/print.inc boot/gdt.inc $(KERNEL) | $(BUILD)
	nasm -f bin -I boot/ -DKERNEL_ADDRESS=$(KERNEL_ADDRESS) -DKERNEL_SECTORS=$$(( ($$(stat -c %s $(KERNEL)) + 511) / 512 )) $< -o $@

$(BUILD):
	mkdir -p $@

run: $(IMAGE)
	qemu-system-i386 -drive format=raw,file=$(IMAGE)

clean:
	rm -rf $(BUILD)
