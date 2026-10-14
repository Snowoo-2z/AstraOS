; ------------------------------------------------------------
; Input: serial first, then PS/2 keyboard scancodes.
; ------------------------------------------------------------
read_char:
.poll:
    call serial_read_char
    cmp al, 0
    jne .done

    call keyboard_buffer_pop
    cmp al, 0
    jne .done

    ; Sleep until the next timer interrupt instead of burning CPU.
    hlt
    jmp .poll
.done:
    ret

keyboard_buffer_push:
    push ebx
    push ecx

    xor ebx, ebx
    mov bl, [kbd_head]
    mov cl, bl
    inc cl
    and cl, KBD_BUFFER_SIZE - 1
    cmp cl, [kbd_tail]
    je .full

    mov [kbd_buffer + ebx], al
    mov [kbd_head], cl

.full:
    pop ecx
    pop ebx
    ret

keyboard_buffer_pop:
    push ebx

    mov bl, [kbd_tail]
    cmp bl, [kbd_head]
    je .empty

    xor ebx, ebx
    mov bl, [kbd_tail]
    mov al, [kbd_buffer + ebx]

    inc bl
    and bl, KBD_BUFFER_SIZE - 1
    mov [kbd_tail], bl
    jmp .done

.empty:
    xor eax, eax
.done:
    pop ebx
    ret

keyboard_process_scancode:
    cmp al, 0x2A       ; left shift down
    je .shift_down
    cmp al, 0x36       ; right shift down
    je .shift_down
    cmp al, 0xAA       ; left shift up
    je .shift_up
    cmp al, 0xB6       ; right shift up
    je .shift_up

    test al, 10000000b ; key release
    jnz .none

    movzx ebx, al
    cmp ebx, keymap_len
    jae .none

    cmp byte [keyboard_layout], KEYBOARD_LAYOUT_US
    je .layout_us

    cmp byte [shift_down], 0
    jne .use_fr_shift
    mov al, [keymap_fr + ebx]
    ret

.use_fr_shift:
    mov al, [keymap_fr_shift + ebx]
    ret

.layout_us:
    cmp byte [shift_down], 0
    jne .use_us_shift
    mov al, [keymap_us + ebx]
    ret

.use_us_shift:
    mov al, [keymap_us_shift + ebx]
    ret

.shift_down:
    mov byte [shift_down], 1
    jmp .none

.shift_up:
    mov byte [shift_down], 0
    jmp .none

.none:
    xor eax, eax
    ret

serial_init:
    mov dx, COM1 + 1
    mov al, 0x00
    out dx, al

    mov dx, COM1 + 3
    mov al, 0x80       ; enable DLAB
    out dx, al

    mov dx, COM1 + 0
    mov al, 0x03       ; divisor 3: 38400 baud
    out dx, al

    mov dx, COM1 + 1
    mov al, 0x00
    out dx, al

    mov dx, COM1 + 3
    mov al, 0x03       ; 8 bits, no parity, one stop bit
    out dx, al

    mov dx, COM1 + 2
    mov al, 0xC7       ; FIFO on, clear, 14-byte threshold
    out dx, al

    mov dx, COM1 + 4
    mov al, 0x0B       ; IRQs enabled, RTS/DSR set
    out dx, al
    ret

serial_read_char:
    mov dx, COM1 + 5
    in al, dx
    test al, 0x01
    jz .none
    mov dx, COM1
    in al, dx
    ret
.none:
    xor eax, eax
    ret

serial_write_char:
    push eax
    cmp al, 10
    jne .not_newline
    mov al, 13
    call serial_write_raw
    mov al, 10
    call serial_write_raw
    jmp .done

.not_newline:
    cmp al, 8
    jne .raw
    mov al, 8
    call serial_write_raw
    mov al, ' '
    call serial_write_raw
    mov al, 8
    call serial_write_raw
    jmp .done

.raw:
    call serial_write_raw
.done:
    pop eax
    ret

serial_write_raw:
    push ebx
    push edx
    mov bl, al
.wait:
    mov dx, COM1 + 5
    in al, dx
    test al, 0x20
    jz .wait
    mov dx, COM1
    mov al, bl
    out dx, al
    pop edx
    pop ebx
    ret

