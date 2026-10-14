; AstraOS 32-bit kernel
; A tiny protected-mode shell using VGA text output, PS/2 keyboard input,
; and serial output/input for headless QEMU.

[org 0x10000]
[bits 32]

%include "kernel/include/config.inc"

kernel_entry:
    cli
    cld

    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    call serial_init
    call setup_paging
    call setup_interrupts
    call clear_screen

    mov esi, banner
    call print_string
    call print_prompt

.main_loop:
    call read_char

    cmp al, 13
    je .enter_pressed
    cmp al, 10
    je .enter_pressed

    cmp al, 8
    je .backspace_pressed
    cmp al, 127
    je .backspace_pressed

    cmp al, 32
    jb .main_loop
    cmp al, 126
    ja .main_loop

    ; Keep command parsing beginner-friendly: uppercase becomes lowercase.
    cmp al, 'A'
    jb .store_char
    cmp al, 'Z'
    ja .store_char
    add al, 32

.store_char:
    mov ebx, [input_len]
    cmp ebx, INPUT_MAX - 1
    jae .main_loop

    mov [input_buffer + ebx], al
    inc ebx
    mov [input_len], ebx
    call put_char
    jmp .main_loop

.backspace_pressed:
    mov ebx, [input_len]
    cmp ebx, 0
    je .main_loop

    dec ebx
    mov [input_len], ebx
    mov byte [input_buffer + ebx], 0
    mov al, 8
    call put_char
    jmp .main_loop

.enter_pressed:
    mov al, 10
    call put_char

    mov ebx, [input_len]
    mov byte [input_buffer + ebx], 0
    call execute_command

    mov dword [input_len], 0
    mov byte [input_buffer], 0
    call print_prompt
    jmp .main_loop


; AstraOS kernel modules. NASM includes them in this exact order to keep
; the flat binary layout while the source remains readable and maintainable.
%include "kernel/core/shell.asm"
%include "kernel/core/memory.asm"
%include "kernel/core/interrupts.asm"
%include "kernel/drivers/input.asm"
%include "kernel/drivers/text.asm"
%include "kernel/ui/gui.asm"
%include "kernel/ui/explorer.asm"
%include "kernel/data.asm"
