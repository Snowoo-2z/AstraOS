; ------------------------------------------------------------
; Interrupt Descriptor Table + timer IRQ
; ------------------------------------------------------------
setup_interrupts:
    call setup_idt
    call remap_pic
    call init_pit
    call init_ps2_mouse
    sti
    ret

setup_idt:
    pusha

    mov edi, idt
    mov ecx, IDT_ENTRIES * 8
    xor eax, eax
    rep stosb

    xor ebx, ebx
.all_entries:
    mov eax, isr_default
    call set_idt_entry
    inc ebx
    cmp ebx, IDT_ENTRIES
    jb .all_entries

    xor ebx, ebx
.exception_entries:
    mov eax, [exception_handlers + ebx * 4]
    call set_idt_entry
    inc ebx
    cmp ebx, 32
    jb .exception_entries

    mov ebx, 32              ; IRQ0 after PIC remap
    mov eax, isr_timer
    call set_idt_entry

    mov ebx, 33              ; IRQ1 keyboard after PIC remap
    mov eax, isr_keyboard
    call set_idt_entry

    mov ebx, 44              ; IRQ12 mouse after PIC remap
    mov eax, isr_mouse
    call set_idt_entry

    lidt [idt_descriptor]
    popa
    ret

; eax = handler address, ebx = vector index
set_idt_entry:
    push edx
    push edi

    mov edi, idt
    mov edx, ebx
    shl edx, 3
    add edi, edx

    mov word [edi], ax
    mov word [edi + 2], CODE_SEG
    mov byte [edi + 4], 0
    mov byte [edi + 5], IDT_FLAGS
    shr eax, 16
    mov word [edi + 6], ax

    pop edi
    pop edx
    ret

remap_pic:
    mov al, 0x11
    out PIC1_CMD, al
    call io_wait
    out PIC2_CMD, al
    call io_wait

    mov al, 0x20             ; master PIC vectors: 32..39
    out PIC1_DATA, al
    call io_wait
    mov al, 0x28             ; slave PIC vectors: 40..47
    out PIC2_DATA, al
    call io_wait

    mov al, 0x04             ; slave is on IRQ2
    out PIC1_DATA, al
    call io_wait
    mov al, 0x02
    out PIC2_DATA, al
    call io_wait

    mov al, 0x01             ; 8086/88 mode
    out PIC1_DATA, al
    call io_wait
    out PIC2_DATA, al
    call io_wait

    mov al, 0xF8             ; unmask IRQ0 timer, IRQ1 keyboard, IRQ2 cascade
    out PIC1_DATA, al
    mov al, 0xEF             ; unmask IRQ12 mouse on the slave PIC
    out PIC2_DATA, al
    ret

init_pit:
    mov al, 0x36             ; channel 0, lobyte/hibyte, mode 3
    out PIT_CMD, al
    mov ax, PIT_DIVISOR      ; 1193182 / 11932 ~= 100 Hz
    out PIT_CH0, al
    mov al, ah
    out PIT_CH0, al
    ret

io_wait:
    push eax
    xor al, al
    out 0x80, al
    pop eax
    ret

init_ps2_mouse:
    ; Enable the auxiliary PS/2 device and start mouse streaming.
    call ps2_wait_input
    mov al, 0xA8             ; enable auxiliary device
    out 0x64, al

    call ps2_wait_input
    mov al, 0x20             ; read controller command byte
    out 0x64, al
    call ps2_wait_output
    in al, 0x60
    or al, 00000010b         ; enable IRQ12
    and al, 11011111b        ; enable mouse clock
    mov bl, al

    call ps2_wait_input
    mov al, 0x60             ; write controller command byte
    out 0x64, al
    call ps2_wait_input
    mov al, bl
    out 0x60, al

    mov al, 0xF6             ; defaults
    call mouse_send_command
    mov al, 0xF4             ; enable data reporting
    call mouse_send_command

    mov byte [mouse_enabled], 1
    call init_vmmouse_absolute
    ret

; Enable the absolute VMMouse protocol exposed by QEMU PC machines. If the
; hypervisor does not provide it, AstraOS silently keeps the PS/2 fallback.
init_vmmouse_absolute:
    pusha
    mov byte [vmmouse_enabled], 0

    mov ebx, VMMOUSE_ENABLE
    mov ecx, VMMOUSE_CMD_COMMAND
    call vmmouse_hypercall

    xor ebx, ebx
    mov ecx, VMMOUSE_CMD_STATUS
    call vmmouse_hypercall
    mov esi, eax
    and eax, VMMOUSE_ERROR
    cmp eax, VMMOUSE_ERROR
    je .done
    and esi, 0xFFFF
    jz .done

    mov ebx, 1
    mov ecx, VMMOUSE_CMD_DATA
    call vmmouse_hypercall
    cmp eax, VMMOUSE_VERSION
    jne .done

    mov ebx, VMMOUSE_REQUEST_ABSOLUTE
    mov ecx, VMMOUSE_CMD_COMMAND
    call vmmouse_hypercall
    mov byte [vmmouse_enabled], 1

.done:
    popa
    ret

; ebx = argument, ecx = command. Outputs follow the VMMouse ABI:
; eax = status/buttons, ebx = x, ecx = y, edx = wheel.
vmmouse_hypercall:
    mov eax, VMMOUSE_MAGIC
    mov edx, VMMOUSE_PORT
    in eax, dx
    ret

mouse_send_command:
    push eax
    call ps2_wait_input
    mov al, 0xD4
    out 0x64, al
    call ps2_wait_input
    pop eax
    out 0x60, al
    call ps2_wait_output
    in al, 0x60              ; ACK, ignored for now
    ret

ps2_wait_input:
    push ecx
    mov ecx, 100000
.wait:
    in al, 0x64
    test al, 00000010b
    jz .done
    loop .wait
.done:
    pop ecx
    ret

ps2_wait_output:
    push ecx
    mov ecx, 100000
.wait:
    in al, 0x64
    test al, 00000001b
    jnz .done
    loop .wait
.done:
    pop ecx
    ret

isr_timer:
    pusha
    inc dword [timer_ticks]
    mov al, 0x20
    out PIC1_CMD, al
    popa
    iretd

isr_keyboard:
    pusha
    inc dword [keyboard_irq_count]
    in al, 0x60
    call keyboard_process_scancode
    cmp al, 0
    je .eoi
    inc dword [keyboard_char_count]
    call keyboard_buffer_push
.eoi:
    mov al, 0x20
    out PIC1_CMD, al
    popa
    iretd

isr_mouse:
    pusha
    inc dword [mouse_irq_count]
    in al, 0x60
    call mouse_process_byte
    mov al, 0x20
    out PIC2_CMD, al
    out PIC1_CMD, al
    popa
    iretd

mouse_process_byte:
    push ebx
    push ecx

    mov bl, [mouse_packet_index]
    cmp bl, 0
    jne .store

    ; First byte must have bit 3 set. Otherwise we are out of sync.
    test al, 00001000b
    jz .done

.store:
    xor ebx, ebx
    mov bl, [mouse_packet_index]
    mov [mouse_packet + ebx], al
    inc byte [mouse_packet_index]
    cmp byte [mouse_packet_index], 3
    jb .done

    mov byte [mouse_packet_index], 0
    cmp byte [vmmouse_enabled], 1
    jne .relative_packet
    call vmmouse_read_events
    jmp .done

.relative_packet:
    inc dword [mouse_packet_count]

    ; X movement, signed 8-bit.
    movsx eax, byte [mouse_packet + 1]
    imul eax, MOUSE_SCALE
    add [mouse_x], eax
    call clamp_mouse_x

    ; PS/2 Y is positive upward; screen Y is positive downward.
    movsx eax, byte [mouse_packet + 2]
    imul eax, MOUSE_SCALE
    neg eax
    add [mouse_y], eax
    call clamp_mouse_y

    mov al, [mouse_packet]
    and al, 00000111b
    mov [mouse_buttons], al

    test al, 00000001b
    jz .left_released
    cmp byte [mouse_left_down], 1
    je .mark_update
    mov byte [mouse_left_down], 1
    mov byte [mouse_left_click], 1
    jmp .mark_update

.left_released:
    mov byte [mouse_left_down], 0

.mark_update:
    mov byte [mouse_updated], 1

.done:
    pop ecx
    pop ebx
    ret

; Drain absolute mouse events from the QEMU VMMouse queue. Host coordinates
; are normalized to 0..65535, so they remain aligned even when QEMU scales the
; 320x200 framebuffer to a larger Windows desktop window.
vmmouse_read_events:
    pusha
    mov byte [vmmouse_read_budget], 8

.next_event:
    xor ebx, ebx
    mov ecx, VMMOUSE_CMD_STATUS
    call vmmouse_hypercall
    mov esi, eax
    and eax, VMMOUSE_ERROR
    cmp eax, VMMOUSE_ERROR
    je .disable
    mov eax, esi
    and eax, 0xFFFF
    cmp eax, 4
    jb .done

    mov ebx, 4
    mov ecx, VMMOUSE_CMD_DATA
    call vmmouse_hypercall
    mov esi, eax             ; packet flags and buttons
    mov edi, ecx             ; preserve Y while scaling X

    test esi, VMMOUSE_RELATIVE_PACKET
    jnz .relative

    ; x = host_x * MOUSE_MAX_X / 65535
    mov eax, ebx
    mov edx, MOUSE_MAX_X
    mul edx
    mov ebx, 65535
    div ebx
    mov [mouse_x], eax

    ; y = host_y * MOUSE_MAX_Y / 65535
    mov eax, edi
    mov edx, MOUSE_MAX_Y
    mul edx
    mov ebx, 65535
    div ebx
    mov [mouse_y], eax
    jmp .buttons

.relative:
    add [mouse_x], ebx
    neg edi
    add [mouse_y], edi
    call clamp_mouse_x
    call clamp_mouse_y

.buttons:
    xor eax, eax
    test esi, VMMOUSE_LEFT_BUTTON
    jz .no_left
    or al, 00000001b
.no_left:
    test esi, VMMOUSE_RIGHT_BUTTON
    jz .no_right
    or al, 00000010b
.no_right:
    test esi, VMMOUSE_MIDDLE_BUTTON
    jz .buttons_ready
    or al, 00000100b
.buttons_ready:
    mov [mouse_buttons], al

    test al, 00000001b
    jz .left_released
    cmp byte [mouse_left_down], 1
    je .mark_update
    mov byte [mouse_left_down], 1
    mov byte [mouse_left_click], 1
    jmp .mark_update
.left_released:
    mov byte [mouse_left_down], 0
.mark_update:
    inc dword [mouse_packet_count]
    mov byte [mouse_updated], 1

    dec byte [vmmouse_read_budget]
    jnz .next_event
    jmp .done

.disable:
    mov byte [vmmouse_enabled], 0
.done:
    popa
    ret

clamp_mouse_x:
    cmp dword [mouse_x], 0
    jge .check_max
    mov dword [mouse_x], 0
    ret
.check_max:
    cmp dword [mouse_x], MOUSE_MAX_X
    jle .done
    mov dword [mouse_x], MOUSE_MAX_X
.done:
    ret

clamp_mouse_y:
    cmp dword [mouse_y], 0
    jge .check_max
    mov dword [mouse_y], 0
    ret
.check_max:
    cmp dword [mouse_y], MOUSE_MAX_Y
    jle .done
    mov dword [mouse_y], MOUSE_MAX_Y
.done:
    ret

isr_default:
    pusha
    mov al, 0x20
    out PIC2_CMD, al
    out PIC1_CMD, al
    popa
    iretd

%macro ISR_EXCEPTION 1
isr_exception_%1:
    cli
    push dword %1
    jmp exception_common
%endmacro

%assign exception_index 0
%rep 32
ISR_EXCEPTION exception_index
%assign exception_index exception_index + 1
%endrep

exception_common:
    pusha
    mov esi, exception_text
    call print_string
    mov esi, exception_vector_text
    call print_string
    mov eax, [esp + 32]
    call print_dec
    call print_newline
    mov esi, exception_hint_text
    call print_string
    popa
.halt:
    hlt
    jmp .halt

reboot_system:
.wait_controller:
    in al, 0x64
    test al, 00000010b
    jnz .wait_controller
    mov al, 0xFE
    out 0x64, al
.halt:
    hlt
    jmp .halt

