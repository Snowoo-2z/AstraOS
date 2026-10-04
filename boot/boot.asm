; AstraOS boot sector
; Loads the 32-bit kernel from the floppy image, enables protected mode,
; and jumps to the kernel entry point at 0x10000.

[org 0x7C00]
[bits 16]

KERNEL_OFFSET  equ 0x10000
KERNEL_SEGMENT equ 0x1000

MEMORY_MAP_COUNT   equ 0x8000
MEMORY_MAP_ENTRIES equ 0x8004
E820_ENTRY_SIZE    equ 24
E820_MAX_ENTRIES   equ 32

%ifndef KERNEL_SECTORS
%define KERNEL_SECTORS 64
%endif

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti

    mov [boot_drive], dl

    ; VGA text mode 80x25.
    mov ax, 0x0003
    int 0x10

    call detect_memory

    ; Be explicit after BIOS calls: keep our boot data in segment zero.
    xor ax, ax
    mov ds, ax
    mov es, ax

    call load_kernel

    cli
    call enable_a20

    lgdt [gdt_descriptor]

    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

    jmp CODE_SEG:init_protected_mode

detect_memory:
    ; Ask the BIOS for the physical memory map (E820) while we are still
    ; in real mode. The 32-bit kernel later reads it at 0x8000.
    xor ax, ax
    mov ds, ax
    mov es, ax
    xor ebx, ebx
    xor bp, bp
    mov word [MEMORY_MAP_COUNT], 0
    mov di, MEMORY_MAP_ENTRIES

.next_entry:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov eax, 0xE820
    mov edx, 0x534D4150       ; 'SMAP'
    mov ecx, E820_ENTRY_SIZE
    mov dword [es:di + 20], 1 ; request ACPI 3.x extended attributes
    int 0x15
    jc .failed

    cmp eax, 0x534D4150
    jne .failed
    cmp ecx, 20
    jb .failed

    inc bp
    add di, E820_ENTRY_SIZE
    cmp bp, E820_MAX_ENTRIES
    jae .done

    test ebx, ebx
    jne .next_entry

.done:
    xor ax, ax
    mov ds, ax
    mov [MEMORY_MAP_COUNT], bp
    ret

.failed:
    ; If E820 is not available, keep count at zero. The kernel still boots.
    xor ax, ax
    mov ds, ax
    cmp bp, 0
    jne .done
    mov word [MEMORY_MAP_COUNT], 0
    ret

load_kernel:
    mov ax, KERNEL_SEGMENT
    mov es, ax
    xor bx, bx         ; ES:BX = 0x1000:0x0000 = physical 0x10000
    mov si, KERNEL_SECTORS
    mov ch, 0          ; cylinder
    mov dh, 0          ; head
    mov cl, 2          ; sector 2, sector 1 is the boot sector

.read_sector:
    pusha
    mov ax, KERNEL_SEGMENT
    mov es, ax
    mov ah, 0x02       ; BIOS read sectors
    mov al, 0x01       ; one sector at a time keeps CHS simple
    mov dl, [boot_drive]
    int 0x13
    jc disk_error
    popa

    add bx, 512
    inc cl
    cmp cl, 19         ; 1.44 MiB floppy: sectors 1..18
    jne .next_sector
    mov cl, 1
    inc dh
    cmp dh, 2          ; heads 0..1
    jne .next_sector
    mov dh, 0
    inc ch

.next_sector:
    dec si
    jnz .read_sector
    ret

disk_error:
    mov si, disk_error_message
    call print_string_16
.halt:
    hlt
    jmp .halt

print_string_16:
    lodsb
    cmp al, 0
    je .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print_string_16
.done:
    ret

enable_a20:
    ; Fast A20 gate. Enough for QEMU and most modern machines.
    in al, 0x92
    or al, 00000010b
    out 0x92, al
    ret

; -------------------------
; Global Descriptor Table
; -------------------------
gdt_start:

gdt_null:
    dq 0x0000000000000000

gdt_code:
    dw 0xFFFF             ; limit low
    dw 0x0000             ; base low
    db 0x00               ; base middle
    db 10011010b          ; present, ring 0, code, executable, readable
    db 11001111b          ; 4 KiB granularity, 32-bit, limit high
    db 0x00               ; base high

gdt_data:
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b          ; present, ring 0, data, writable
    db 11001111b
    db 0x00

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

boot_drive db 0
disk_error_message db 'AstraOS: disk read error', 13, 10, 0

[bits 32]
init_protected_mode:
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    mov ebp, 0x90000
    mov esp, ebp

    jmp CODE_SEG:KERNEL_OFFSET

times 510 - ($ - $$) db 0
dw 0xAA55
