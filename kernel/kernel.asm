; AstraOS 32-bit kernel
; A tiny protected-mode shell using VGA text output, PS/2 keyboard input,
; and serial output/input for headless QEMU.

[org 0x10000]
[bits 32]

VIDEO_MEMORY equ 0xB8000
VGA_WIDTH    equ 80
VGA_HEIGHT   equ 25
VGA_ATTR     equ 0x0F          ; white on black
INPUT_MAX    equ 96
COM1         equ 0x3F8
CODE_SEG     equ 0x08
DATA_SEG     equ 0x10

IDT_ENTRIES      equ 256
IDT_FLAGS        equ 0x8E
PIT_FREQUENCY_HZ equ 100
PIT_DIVISOR      equ 11932

PIC1_CMD  equ 0x20
PIC1_DATA equ 0x21
PIC2_CMD  equ 0xA0
PIC2_DATA equ 0xA1
PIT_CMD   equ 0x43
PIT_CH0   equ 0x40

KEYBOARD_LAYOUT_FR equ 0
KEYBOARD_LAYOUT_US equ 1

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

; ------------------------------------------------------------
; Command shell
; ------------------------------------------------------------
execute_command:
    cmp dword [input_len], 0
    je .done

    mov esi, input_buffer
    mov edi, cmd_help
    call string_equals
    cmp eax, 1
    je .help

    mov esi, input_buffer
    mov edi, cmd_about
    call string_equals
    cmp eax, 1
    je .about

    mov esi, input_buffer
    mov edi, cmd_clear
    call string_equals
    cmp eax, 1
    je .clear

    mov esi, input_buffer
    mov edi, cmd_reboot
    call string_equals
    cmp eax, 1
    je .reboot

    mov esi, input_buffer
    mov edi, cmd_mem
    call string_equals
    cmp eax, 1
    je .mem

    mov esi, input_buffer
    mov edi, cmd_version
    call string_equals
    cmp eax, 1
    je .version

    mov esi, input_buffer
    mov edi, cmd_uptime
    call string_equals
    cmp eax, 1
    je .uptime

    call is_kbd_command
    cmp eax, 1
    je .kbd

    call is_ai_command
    cmp eax, 1
    je .ai

    mov esi, unknown_text
    call print_string
    jmp .done

.help:
    mov esi, help_text
    call print_string
    jmp .done

.about:
    mov esi, about_text
    call print_string
    jmp .done

.clear:
    call clear_screen
    jmp .done

.reboot:
    mov esi, reboot_text
    call print_string
    call reboot_system
    jmp .done

.mem:
    mov esi, mem_text
    call print_string
    jmp .done

.version:
    mov esi, version_text
    call print_string
    jmp .done

.uptime:
    call print_uptime
    jmp .done

.kbd:
    call execute_kbd_command
    jmp .done

.ai:
    mov esi, ai_text
    call print_string

.done:
    ret

print_prompt:
    mov esi, prompt_text
    call print_string
    ret

string_equals:
    push esi
    push edi
.compare:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .no
    cmp al, 0
    je .yes
    inc esi
    inc edi
    jmp .compare
.yes:
    mov eax, 1
    jmp .end
.no:
    xor eax, eax
.end:
    pop edi
    pop esi
    ret

is_ai_command:
    cmp byte [input_buffer], 'a'
    jne .no
    cmp byte [input_buffer + 1], 'i'
    jne .no
    mov al, [input_buffer + 2]
    cmp al, 0
    je .yes
    cmp al, ' '
    je .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

is_kbd_command:
    cmp byte [input_buffer], 'k'
    jne .no
    cmp byte [input_buffer + 1], 'b'
    jne .no
    cmp byte [input_buffer + 2], 'd'
    jne .no
    mov al, [input_buffer + 3]
    cmp al, 0
    je .yes
    cmp al, ' '
    je .yes
.no:
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

execute_kbd_command:
    cmp byte [input_buffer + 3], 0
    je .show
    cmp byte [input_buffer + 3], ' '
    jne .usage

    cmp byte [input_buffer + 4], 'f'
    jne .try_us
    cmp byte [input_buffer + 5], 'r'
    jne .usage
    cmp byte [input_buffer + 6], 0
    jne .usage
    mov byte [keyboard_layout], KEYBOARD_LAYOUT_FR
    mov esi, kbd_set_fr_text
    call print_string
    ret

.try_us:
    cmp byte [input_buffer + 4], 'u'
    jne .usage
    cmp byte [input_buffer + 5], 's'
    jne .usage
    cmp byte [input_buffer + 6], 0
    jne .usage
    mov byte [keyboard_layout], KEYBOARD_LAYOUT_US
    mov esi, kbd_set_us_text
    call print_string
    ret

.show:
    cmp byte [keyboard_layout], KEYBOARD_LAYOUT_US
    je .show_us
    mov esi, kbd_current_fr_text
    call print_string
    ret

.show_us:
    mov esi, kbd_current_us_text
    call print_string
    ret

.usage:
    mov esi, kbd_usage_text
    call print_string
    ret

; ------------------------------------------------------------
; Interrupt Descriptor Table + timer IRQ
; ------------------------------------------------------------
setup_interrupts:
    call setup_idt
    call remap_pic
    call init_pit
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
    mov eax, isr_exception
    call set_idt_entry
    inc ebx
    cmp ebx, 32
    jb .exception_entries

    mov ebx, 32              ; IRQ0 after PIC remap
    mov eax, isr_timer
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

    mov al, 0xFE             ; unmask IRQ0 timer only
    out PIC1_DATA, al
    mov al, 0xFF
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

isr_timer:
    pusha
    inc dword [timer_ticks]
    mov al, 0x20
    out PIC1_CMD, al
    popa
    iretd

isr_default:
    pusha
    mov al, 0x20
    out PIC2_CMD, al
    out PIC1_CMD, al
    popa
    iretd

isr_exception:
    cli
    pusha
    mov esi, exception_text
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

; ------------------------------------------------------------
; Input: serial first, then PS/2 keyboard scancodes.
; ------------------------------------------------------------
read_char:
.poll:
    call serial_read_char
    cmp al, 0
    jne .done

    call keyboard_read_char
    cmp al, 0
    jne .done

    ; Sleep until the next timer interrupt instead of burning CPU.
    hlt
    jmp .poll
.done:
    ret

keyboard_read_char:
    in al, 0x64
    test al, 00000001b
    jz .none

    in al, 0x60

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

; ------------------------------------------------------------
; Output: VGA text mode mirrored to serial.
; ------------------------------------------------------------
print_string:
    lodsb
    cmp al, 0
    je .done
    call put_char
    jmp print_string
.done:
    ret

print_uptime:
    pusha
    mov esi, uptime_prefix
    call print_string

    mov eax, [timer_ticks]
    xor edx, edx
    mov ebx, PIT_FREQUENCY_HZ
    div ebx
    call print_dec

    mov esi, uptime_seconds_text
    call print_string

    mov eax, [timer_ticks]
    call print_dec

    mov esi, uptime_ticks_suffix
    call print_string
    popa
    ret

print_dec:
    pusha
    cmp eax, 0
    jne .convert
    mov al, '0'
    call put_char
    jmp .done

.convert:
    mov edi, dec_buffer + 10
    mov byte [edi], 0
    mov ebx, 10

.next_digit:
    xor edx, edx
    div ebx
    dec edi
    add dl, '0'
    mov [edi], dl
    test eax, eax
    jnz .next_digit

    mov esi, edi
    call print_string

.done:
    popa
    ret

put_char:
    pusha
    mov [current_char], al
    call serial_write_char

    mov al, [current_char]
    cmp al, 10
    je .newline
    cmp al, 13
    je .newline
    cmp al, 8
    je .backspace

    call cursor_to_edi
    mov al, [current_char]
    mov ah, VGA_ATTR
    mov [edi], ax

    inc dword [cursor_x]
    cmp dword [cursor_x], VGA_WIDTH
    jl .finish

.newline:
    mov dword [cursor_x], 0
    inc dword [cursor_y]
    jmp .finish

.backspace:
    cmp dword [cursor_x], 0
    jne .backspace_same_line
    cmp dword [cursor_y], 0
    je .finish
    dec dword [cursor_y]
    mov dword [cursor_x], VGA_WIDTH - 1
    jmp .erase_after_backspace

.backspace_same_line:
    dec dword [cursor_x]

.erase_after_backspace:
    call cursor_to_edi
    mov ax, (VGA_ATTR << 8) | ' '
    mov [edi], ax

.finish:
    call scroll_if_needed
    call update_cursor
    popa
    ret

cursor_to_edi:
    mov eax, [cursor_y]
    mov ebx, VGA_WIDTH
    mul ebx
    add eax, [cursor_x]
    shl eax, 1
    mov edi, VIDEO_MEMORY
    add edi, eax
    ret

clear_screen:
    pusha
    mov edi, VIDEO_MEMORY
    mov ecx, VGA_WIDTH * VGA_HEIGHT
    mov ax, (VGA_ATTR << 8) | ' '
    rep stosw
    mov dword [cursor_x], 0
    mov dword [cursor_y], 0
    call update_cursor
    popa
    ret

scroll_if_needed:
    pusha
    cmp dword [cursor_y], VGA_HEIGHT
    jl .done

    mov esi, VIDEO_MEMORY + (VGA_WIDTH * 2)
    mov edi, VIDEO_MEMORY
    mov ecx, (VGA_HEIGHT - 1) * VGA_WIDTH
    rep movsw

    mov edi, VIDEO_MEMORY + ((VGA_HEIGHT - 1) * VGA_WIDTH * 2)
    mov ecx, VGA_WIDTH
    mov ax, (VGA_ATTR << 8) | ' '
    rep stosw

    mov dword [cursor_y], VGA_HEIGHT - 1
.done:
    popa
    ret

update_cursor:
    pusha
    mov eax, [cursor_y]
    mov ebx, VGA_WIDTH
    mul ebx
    add eax, [cursor_x]
    mov ebx, eax

    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc dx
    mov al, bl
    out dx, al

    dec dx
    mov al, 0x0E
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    popa
    ret

; ------------------------------------------------------------
; Data
; ------------------------------------------------------------
cursor_x dd 0
cursor_y dd 0
input_len dd 0
timer_ticks dd 0
current_char db 0
shift_down db 0
keyboard_layout db KEYBOARD_LAYOUT_FR
dec_buffer times 11 db 0

input_buffer times INPUT_MAX db 0

cmd_help    db 'help', 0
cmd_about   db 'about', 0
cmd_clear   db 'clear', 0
cmd_reboot  db 'reboot', 0
cmd_mem     db 'mem', 0
cmd_version db 'version', 0
cmd_uptime  db 'uptime', 0

banner:
    db '========================================', 10
    db ' AstraOS 0.0.2 Pulse', 10
    db ' 32-bit protected mode kernel', 10
    db ' Open source MIT - black and white', 10
    db ' Keyboard: FR AZERTY by default', 10
    db ' Interrupts: IDT/PIC/PIT timer online', 10
    db '========================================', 10, 10
    db 'Type help to begin.', 10, 10, 0

prompt_text db 'astra> ', 0

help_text:
    db 'Commands:', 10
    db '  help     Show this help', 10
    db '  about    What AstraOS is', 10
    db '  version  Show version', 10
    db '  uptime   Show timer ticks since boot', 10
    db '  mem      Memory philosophy', 10
    db '  ai       Local AI concept stub', 10
    db '  kbd      Show keyboard layout', 10
    db '  kbd fr   Switch to French AZERTY', 10
    db '  kbd us   Switch to US QWERTY', 10
    db '  clear    Clear the screen', 10
    db '  reboot   Restart the VM', 10, 10, 0

about_text:
    db 'AstraOS is a tiny x86 operating system made from scratch.', 10
    db 'This first base boots with a 16-bit loader, switches to 32-bit', 10
    db 'protected mode, then starts a minimal command shell.', 10
    db 'Goal: stay light in RAM, modular, and ready for AI tooling later.', 10, 10, 0

version_text db 'AstraOS 0.0.2 Pulse - kernel32', 10, 10, 0

mem_text:
    db 'Memory status:', 10
    db '  CPU mode : 32-bit protected mode', 10
    db '  Timer    : PIT IRQ0 at 100 Hz', 10
    db '  Idle     : HLT sleep between polls', 10
    db '  Kernel   : fixed low-memory image loaded at 0x10000', 10
    db '  Heap     : not enabled yet', 10
    db '  Design   : tiny kernel first, optional AI layer later', 10, 10, 0

ai_text:
    db 'AstraAI local stub online.', 10
    db 'I am not a real model yet: no wasted RAM, no cloud dependency.', 10
    db 'Next steps: intent parser, command suggestions, then optional model bridge.', 10
    db 'For now, try: help, mem, clear, version.', 10, 10, 0

uptime_prefix db 'Uptime: ', 0
uptime_seconds_text db 's (ticks: ', 0
uptime_ticks_suffix db ')', 10, 10, 0
exception_text db 'AstraOS kernel panic: CPU exception. System halted.', 10, 0

kbd_current_fr_text db 'Keyboard layout: FR AZERTY. Use kbd us to switch.', 10, 10, 0
kbd_current_us_text db 'Keyboard layout: US QWERTY. Use kbd fr to switch.', 10, 10, 0
kbd_set_fr_text db 'Keyboard switched to FR AZERTY.', 10, 10, 0
kbd_set_us_text db 'Keyboard switched to US QWERTY.', 10, 10, 0
kbd_usage_text db 'Usage: kbd, kbd fr, or kbd us.', 10, 10, 0

unknown_text db 'Unknown command. Type help.', 10, 10, 0
reboot_text db 'Rebooting AstraOS...', 10, 0

; Minimal PS/2 scancode set 1 maps. Serial input is also supported, which is
; easier for headless QEMU and non-US host keyboards.
; The FR map is ASCII-only on purpose: accents are simplified so the shell can
; stay tiny and predictable in early development.
keymap_fr:
    db 0, 0
    db '&','e',34,39,'(','-','e','_','c','a',')','='
    db 8, 9
    db 'a','z','e','r','t','y','u','i','o','p','^','$'
    db 13, 0
    db 'q','s','d','f','g','h','j','k','l','m','u','2'
    db 0, '*'
    db 'w','x','c','v','b','n',',',';',':','!'
    db 0,'*',0,' '
keymap_fr_end:
keymap_len equ keymap_fr_end - keymap_fr

keymap_fr_shift:
    db 0, 0
    db '1','2','3','4','5','6','7','8','9','0',']','+'
    db 8, 9
    db 'A','Z','E','R','T','Y','U','I','O','P','"','L'
    db 13, 0
    db 'Q','S','D','F','G','H','J','K','L','M','%',' '
    db 0, 'u'
    db 'W','X','C','V','B','N','?','.','/','s'
    db 0,'*',0,' '

keymap_us:
    db 0, 0
    db '1','2','3','4','5','6','7','8','9','0','-','='
    db 8, 9
    db 'q','w','e','r','t','y','u','i','o','p',91,93
    db 13, 0
    db 'a','s','d','f','g','h','j','k','l',59,39,96
    db 0, 92
    db 'z','x','c','v','b','n','m',44,46,47
    db 0,'*',0,' '

keymap_us_shift:
    db 0, 0
    db '!','@','#','$','%','^','&','*','(',')','_','+'
    db 8, 9
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}'
    db 13, 0
    db 'A','S','D','F','G','H','J','K','L',':',34,'~'
    db 0, '|'
    db 'Z','X','C','V','B','N','M','<','>','?'
    db 0,'*',0,' '


; Interrupt Descriptor Table storage.
align 8
idt times IDT_ENTRIES * 8 db 0
idt_descriptor:
    dw IDT_ENTRIES * 8 - 1
    dd idt
