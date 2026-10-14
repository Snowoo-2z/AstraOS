# AstraOS build system
# One-command flow for beginners: make run

ASM ?= nasm
QEMU ?= qemu-system-i386
QEMU_KEYBOARD ?= fr
QEMU_DISPLAY ?= gtk,show-cursor=off
QEMU_DISPLAY_FLAGS := $(if $(QEMU_DISPLAY),-display $(QEMU_DISPLAY),)
QEMU_FLAGS ?= -no-reboot -no-shutdown
QEMU_FULLSCREEN ?= -full-screen

BUILD_DIR := build
BOOT_SRC := boot/boot.asm
KERNEL_SRC := kernel/kernel.asm
KERNEL_MODULES := $(wildcard kernel/include/*.inc kernel/core/*.asm kernel/drivers/*.asm kernel/ui/*.asm kernel/data.asm)
BOOT_BIN := $(BUILD_DIR)/boot.bin
KERNEL_BIN := $(BUILD_DIR)/kernel.bin
HEADLESS_KERNEL_BIN := $(BUILD_DIR)/kernel-headless.bin
IMAGE := $(BUILD_DIR)/astraos.img
HEADLESS_IMAGE := $(BUILD_DIR)/astraos-headless.img

# The bootloader reads this many sectors after the boot sector.
# Keep it intentionally generous for the tiny kernel and fail if we outgrow it.
KERNEL_SECTORS := 256
FLOPPY_SECTORS := 2880
FLOPPY_SIZE := 1474560

.PHONY: all run run-windowed run-headless image image-headless clean doctor

all: image

image: $(IMAGE)

image-headless: $(HEADLESS_IMAGE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BOOT_BIN): $(BOOT_SRC) | $(BUILD_DIR)
	$(ASM) -f bin -D KERNEL_SECTORS=$(KERNEL_SECTORS) $< -o $@

# The normal image boots straight into the Aurora graphical desktop.
$(KERNEL_BIN): $(KERNEL_SRC) $(KERNEL_MODULES) | $(BUILD_DIR)
	$(ASM) -f bin $(KERNEL_SRC) -o $@

# Keep a separate serial-first kernel for WSL, SSH and CI without weakening
# the normal desktop boot experience.
$(HEADLESS_KERNEL_BIN): $(KERNEL_SRC) $(KERNEL_MODULES) | $(BUILD_DIR)
	$(ASM) -f bin -D HEADLESS_BOOT=1 $(KERNEL_SRC) -o $@

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

$(HEADLESS_IMAGE): $(BOOT_BIN) $(HEADLESS_KERNEL_BIN)
	@kernel_size=$$(wc -c < $(HEADLESS_KERNEL_BIN)); \
	max_size=$$(( $(KERNEL_SECTORS) * 512 )); \
	if [ $$kernel_size -gt $$max_size ]; then \
		echo "Headless kernel is $$kernel_size bytes, but bootloader only loads $$max_size bytes."; \
		exit 1; \
	fi
	dd if=/dev/zero of=$(HEADLESS_IMAGE) bs=512 count=$(FLOPPY_SECTORS) status=none
	dd if=$(BOOT_BIN) of=$(HEADLESS_IMAGE) bs=512 count=1 conv=notrunc status=none
	dd if=$(HEADLESS_KERNEL_BIN) of=$(HEADLESS_IMAGE) bs=512 seek=1 conv=notrunc status=none
	@echo "Built $(HEADLESS_IMAGE) ($(FLOPPY_SIZE) bytes)."

# Full-screen Aurora is the default product experience.
run: doctor $(IMAGE)
	$(QEMU) -drive file=$(IMAGE),format=raw,if=floppy -boot a -m 32M -k $(QEMU_KEYBOARD) $(QEMU_DISPLAY_FLAGS) $(QEMU_FULLSCREEN) $(QEMU_FLAGS)

# Useful while developing beside an editor or on a smaller display.
run-windowed: QEMU_FULLSCREEN :=
run-windowed: run

# Useful on WSL/SSH/no-GUI machines. This image deliberately starts in the
# serial/text shell and does not request a graphical display or full-screen.
run-headless: doctor $(HEADLESS_IMAGE)
	$(QEMU) -drive file=$(HEADLESS_IMAGE),format=raw,if=floppy -boot a -m 32M -display none -serial mon:stdio $(QEMU_FLAGS)

doctor:
	@command -v $(ASM) >/dev/null 2>&1 || { echo "Missing: $(ASM). Install with: sudo apt install nasm"; exit 1; }
	@command -v $(QEMU) >/dev/null 2>&1 || { echo "Missing: $(QEMU). Install with: sudo apt install qemu-system-x86"; exit 1; }
	@echo "Tools OK. Run: make run"

clean:
	rm -rf $(BUILD_DIR)
