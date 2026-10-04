# AstraOS build system
# One-command flow for beginners: make run

ASM ?= nasm
QEMU ?= qemu-system-i386
QEMU_KEYBOARD ?= fr

BUILD_DIR := build
BOOT_SRC := boot/boot.asm
KERNEL_SRC := kernel/kernel.asm
BOOT_BIN := $(BUILD_DIR)/boot.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
IMAGE := $(BUILD_DIR)/astraos.img

# The bootloader reads this many sectors after the boot sector.
# Keep it intentionally generous for the tiny kernel and fail if we outgrow it.
KERNEL_SECTORS := 192
FLOPPY_SECTORS := 2880
FLOPPY_SIZE := 1474560

.PHONY: all run run-headless image clean doctor

all: image

image: $(IMAGE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): $(BOOT_SRC) | $(BUILD_DIR)
	$(ASM) -f bin -D KERNEL_SECTORS=$(KERNEL_SECTORS) $< -o $@

$(KERNEL_BIN): $(KERNEL_SRC) | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

$(IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	@kernel_size=$$(wc -c < $(KERNEL_BIN)); \
	max_size=$$(( $(KERNEL_SECTORS) * 512 )); \
	if [ $$kernel_size -gt $$max_size ]; then \
		echo "Kernel is $$kernel_size bytes, but bootloader only loads $$max_size bytes."; \
		echo "Increase KERNEL_SECTORS in Makefile and rebuild."; \
		exit 1; \
	fi
	dd if=/dev/zero of=$(IMAGE) bs=512 count=$(FLOPPY_SECTORS) status=none
	dd if=$(BOOT_BIN) of=$(IMAGE) bs=512 count=1 conv=notrunc status=none
	dd if=$(KERNEL_BIN) of=$(IMAGE) bs=512 seek=1 conv=notrunc status=none
	@echo "Built $(IMAGE) ($(FLOPPY_SIZE) bytes)."
	@echo "Kernel size: $$(wc -c < $(KERNEL_BIN)) bytes / $$(( $(KERNEL_SECTORS) * 512 )) bytes loaded."

run: doctor $(IMAGE)
	$(QEMU) -drive file=$(IMAGE),format=raw,if=floppy -boot a -m 32M -k $(QEMU_KEYBOARD)

# Useful on WSL/SSH/no-GUI machines. Output is mirrored to serial and input works over serial.
run-headless: doctor $(IMAGE)
	$(QEMU) -drive file=$(IMAGE),format=raw,if=floppy -boot a -m 32M -display none -serial mon:stdio

doctor:
	@command -v $(ASM) >/dev/null 2>&1 || { echo "Missing: $(ASM). Install with: sudo apt install nasm"; exit 1; }
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "Missing: $(QEMU). Install with: sudo apt install qemu-system-x86"; exit 1; }
	@echo "Tools OK. Run: make run"

clean:
	rm -rf $(BUILD_DIR)
