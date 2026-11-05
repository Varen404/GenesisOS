BUILD  := build
IMAGE  := $(BUILD)/genesis.img
BOOT   := $(BUILD)/boot.bin
KERNEL := $(BUILD)/kernel.bin

.PHONY: all run clean

all: $(IMAGE)

# Image disque : secteur de boot, puis kernel, arrondi a un multiple de 512 octets.
$(IMAGE): $(BOOT) $(KERNEL)
	cat $^ > $@
	truncate --size=%512 $@

$(KERNEL): kernel/kernel.asm boot/print.inc | $(BUILD)
	nasm -f bin -I boot/ $< -o $@

# Le secteur de boot depend du kernel : il doit connaitre sa taille en secteurs.
$(BOOT): boot/boot.asm boot/print.inc $(KERNEL) | $(BUILD)
	nasm -f bin -I boot/ -DKERNEL_SECTORS=$$(( ($$(stat -c %s $(KERNEL)) + 511) / 512 )) $< -o $@

$(BUILD):
	mkdir -p $@

run: $(IMAGE)
	qemu-system-i386 -drive format=raw,file=$(IMAGE)

clean:
	rm -rf $(BUILD)
