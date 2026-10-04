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
KBD_BUFFER_SIZE equ 32

MEMORY_MAP_COUNT   equ 0x8000
MEMORY_MAP_ENTRIES equ 0x8004
E820_ENTRY_SIZE    equ 24

HEAP_START equ 0x200000
HEAP_SIZE  equ 0x100000
HEAP_END   equ HEAP_START + HEAP_SIZE

COM1         equ 0x3F8
CODE_SEG     equ 0x08
DATA_SEG     equ 0x10

IDT_ENTRIES      equ 256
IDT_FLAGS        equ 0x8E
PAGE_ENTRIES     equ 1024
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
FILE_COUNT equ 4

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

    mov esi, input_buffer
    mov edi, cmd_cpu
    call string_equals
    cmp eax, 1
    je .cpu

    mov esi, input_buffer
    mov edi, cmd_irq
    call string_equals
    cmp eax, 1
    je .irq

    mov esi, input_buffer
    mov edi, cmd_heap
    call string_equals
    cmp eax, 1
    je .heap

    mov esi, input_buffer
    mov edi, cmd_alloc
    call string_equals
    cmp eax, 1
    je .alloc

    mov esi, input_buffer
    mov edi, cmd_mmap
    call string_equals
    cmp eax, 1
    je .mmap

    mov esi, input_buffer
    mov edi, cmd_paging
    call string_equals
    cmp eax, 1
    je .paging

    mov esi, input_buffer
    mov edi, cmd_status
    call string_equals
    cmp eax, 1
    je .status

    mov esi, input_buffer
    mov edi, cmd_ls
    call string_equals
    cmp eax, 1
    je .ls

    mov esi, input_buffer
    mov edi, cmd_explorer
    call string_equals
    cmp eax, 1
    je .explorer

    mov esi, input_buffer
    mov edi, cmd_files
    call string_equals
    cmp eax, 1
    je .explorer

    mov esi, input_buffer
    mov edi, cmd_explorateur
    call string_equals
    cmp eax, 1
    je .explorer

    mov esi, input_buffer
    mov edi, cmd_fichiers
    call string_equals
    cmp eax, 1
    je .explorer

    call is_cat_command
    cmp eax, 1
    je .cat

    call is_echo_command
    cmp eax, 1
    je .echo

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
    call print_memory_info
    jmp .done

.version:
    mov esi, version_text
    call print_string
    jmp .done

.uptime:
    call print_uptime
    jmp .done

.cpu:
    call print_cpu_info
    jmp .done

.irq:
    call print_irq_info
    jmp .done

.heap:
    call print_heap_info
    jmp .done

.alloc:
    call allocate_demo_block
    jmp .done

.mmap:
    call print_memory_map
    jmp .done

.paging:
    call print_paging_info
    jmp .done

.status:
    call print_status_info
    jmp .done

.ls:
    call print_file_list
    jmp .done

.explorer:
    call file_explorer
    jmp .done

.cat:
    call execute_cat_command
    jmp .done

.echo:
    call execute_echo_command
    jmp .done

.kbd:
    call execute_kbd_command
    jmp .done

.ai:
    call execute_ai_command

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

lower_char:
    cmp al, 'A'
    jb .done
    cmp al, 'Z'
    ja .done
    add al, 32
.done:
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

is_cat_command:
    cmp byte [input_buffer], 'c'
    jne .no
    cmp byte [input_buffer + 1], 'a'
    jne .no
    cmp byte [input_buffer + 2], 't'
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

is_echo_command:
    cmp byte [input_buffer], 'e'
    jne .no
    cmp byte [input_buffer + 1], 'c'
    jne .no
    cmp byte [input_buffer + 2], 'h'
    jne .no
    cmp byte [input_buffer + 3], 'o'
    jne .no
    mov al, [input_buffer + 4]
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

execute_cat_command:
    cmp byte [input_buffer + 3], ' '
    jne .usage

    mov esi, input_buffer + 4
    mov edi, fs_name_readme
    call string_equals
    cmp eax, 1
    je .readme

    mov esi, input_buffer + 4
    mov edi, fs_name_roadmap
    call string_equals
    cmp eax, 1
    je .roadmap

    mov esi, input_buffer + 4
    mov edi, fs_name_ai
    call string_equals
    cmp eax, 1
    je .ai

    mov esi, input_buffer + 4
    mov edi, fs_name_license
    call string_equals
    cmp eax, 1
    je .license

    mov esi, cat_not_found_text
    call print_string
    ret

.readme:
    mov esi, fs_readme_text
    call print_string
    ret
.roadmap:
    mov esi, fs_roadmap_text
    call print_string
    ret
.ai:
    mov esi, fs_ai_text
    call print_string
    ret
.license:
    mov esi, fs_license_text
    call print_string
    ret
.usage:
    mov esi, cat_usage_text
    call print_string
    ret

execute_echo_command:
    cmp byte [input_buffer + 4], 0
    je .newline
    cmp byte [input_buffer + 4], ' '
    jne .usage
    mov esi, input_buffer + 5
    call print_string
.newline:
    call print_newline
    ret
.usage:
    mov esi, echo_usage_text
    call print_string
    ret

execute_ai_command:
    cmp byte [input_buffer + 2], 0
    je .intro
    cmp byte [input_buffer + 2], ' '
    jne .intro

    mov esi, input_buffer + 3
    mov edi, ai_arg_mem
    call string_equals
    cmp eax, 1
    je .mem

    mov esi, input_buffer + 3
    mov edi, ai_arg_memoire
    call string_equals
    cmp eax, 1
    je .mem

    mov esi, input_buffer + 3
    mov edi, ai_arg_files
    call string_equals
    cmp eax, 1
    je .files

    mov esi, input_buffer + 3
    mov edi, ai_arg_fichiers
    call string_equals
    cmp eax, 1
    je .files

    mov esi, input_buffer + 3
    mov edi, ai_arg_clavier
    call string_equals
    cmp eax, 1
    je .kbd

    mov esi, input_buffer + 3
    mov edi, ai_arg_kbd
    call string_equals
    cmp eax, 1
    je .kbd

    mov esi, input_buffer + 3
    mov edi, ai_arg_cpu
    call string_equals
    cmp eax, 1
    je .cpu

    mov esi, input_buffer + 3
    mov edi, ai_arg_irq
    call string_equals
    cmp eax, 1
    je .irq

    mov esi, input_buffer + 3
    mov edi, ai_arg_heap
    call string_equals
    cmp eax, 1
    je .heap

    mov esi, ai_unknown_text
    call print_string
    ret

.intro:
    mov esi, ai_text
    call print_string
    ret
.mem:
    mov esi, ai_mem_text
    call print_string
    ret
.files:
    mov esi, ai_files_text
    call print_string
    ret
.kbd:
    mov esi, ai_kbd_text
    call print_string
    ret
.cpu:
    mov esi, ai_cpu_text
    call print_string
    ret
.irq:
    mov esi, ai_irq_text
    call print_string
    ret
.heap:
    mov esi, ai_heap_text
    call print_string
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
; Paging: identity-map the first 4 MiB.
; ------------------------------------------------------------
setup_paging:
    pusha

    mov edi, page_directory
    mov ecx, PAGE_ENTRIES
    xor eax, eax
    rep stosd

    mov edi, page_table0
    xor ebx, ebx
    mov ecx, PAGE_ENTRIES

.fill_table:
    mov eax, ebx
    or eax, 0x003           ; present + writable
    mov [edi], eax
    add ebx, 4096
    add edi, 4
    loop .fill_table

    mov eax, page_table0
    or eax, 0x003
    mov [page_directory], eax

    mov eax, page_directory
    mov cr3, eax
    mov eax, cr0
    or eax, 0x80000000      ; enable paging
    mov cr0, eax
    jmp .flush

.flush:
    mov dword [paging_enabled], 1
    popa
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

    mov al, 0xFC             ; unmask IRQ0 timer and IRQ1 keyboard
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

print_newline:
    push eax
    mov al, 10
    call put_char
    pop eax
    ret

print_hex32:
    pusha
    mov esi, hex_prefix
    call print_string
    mov ebx, eax
    mov ecx, 8

.next_nibble:
    rol ebx, 4
    mov al, bl
    and al, 0x0F
    cmp al, 9
    jbe .digit
    add al, 'A' - 10
    jmp .emit

.digit:
    add al, '0'

.emit:
    call put_char
    loop .next_nibble
    popa
    ret

get_usable_kib:
    push ebx
    push ecx
    push edx
    push esi

    xor eax, eax
    movzx ecx, word [MEMORY_MAP_COUNT]
    mov esi, MEMORY_MAP_ENTRIES

.next_entry:
    test ecx, ecx
    jz .done
    cmp dword [esi + 16], 1
    jne .skip
    add eax, [esi + 8]       ; length low dword, enough for the tiny VM target

.skip:
    add esi, E820_ENTRY_SIZE
    dec ecx
    jmp .next_entry

.done:
    shr eax, 10              ; bytes -> KiB
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

print_memory_info:
    pusha
    mov esi, mem_header_text
    call print_string

    mov esi, mem_mode_text
    call print_string

    mov esi, mem_map_count_text
    call print_string
    movzx eax, word [MEMORY_MAP_COUNT]
    call print_dec
    call print_newline

    mov esi, mem_usable_text
    call print_string
    call get_usable_kib
    mov [temp_value], eax
    call print_dec
    mov esi, kib_open_text
    call print_string
    mov eax, [temp_value]
    shr eax, 10
    call print_dec
    mov esi, mib_close_text
    call print_string

    call print_heap_info
    popa
    ret

print_heap_info:
    pusha
    mov esi, heap_header_text
    call print_string

    mov esi, heap_start_text
    call print_string
    mov eax, HEAP_START
    call print_hex32
    call print_newline

    mov esi, heap_next_text
    call print_string
    mov eax, [heap_next]
    call print_hex32
    call print_newline

    mov esi, heap_used_text
    call print_string
    mov eax, [heap_next]
    sub eax, HEAP_START
    mov [temp_value], eax
    call print_dec
    mov esi, bytes_text
    call print_string
    mov eax, [temp_value]
    shr eax, 10
    call print_dec
    mov esi, kib_suffix_text
    call print_string

    mov esi, heap_free_text
    call print_string
    mov eax, HEAP_END
    sub eax, [heap_next]
    mov [temp_value], eax
    call print_dec
    mov esi, bytes_text
    call print_string
    mov eax, [temp_value]
    shr eax, 10
    call print_dec
    mov esi, kib_suffix_text
    call print_string

    popa
    ret

allocate_demo_block:
    pusha
    mov eax, [heap_next]
    mov ebx, eax
    add ebx, 256
    cmp ebx, HEAP_END
    ja .fail

    mov [heap_next], ebx
    mov [temp_value], eax

    mov edi, eax
    mov ecx, 64              ; 64 dwords = 256 bytes
    xor eax, eax
    rep stosd

    mov esi, alloc_ok_text
    call print_string
    mov eax, [temp_value]
    call print_hex32
    call print_newline
    call print_heap_info
    jmp .done

.fail:
    mov esi, alloc_fail_text
    call print_string

.done:
    popa
    ret

print_cpu_info:
    pusha
    mov esi, cpu_header_text
    call print_string

    mov eax, 0
    cpuid
    mov [cpu_vendor + 0], ebx
    mov [cpu_vendor + 4], edx
    mov [cpu_vendor + 8], ecx
    mov byte [cpu_vendor + 12], 0

    mov esi, cpu_vendor_text
    call print_string
    mov esi, cpu_vendor
    call print_string
    call print_newline

    mov eax, 1
    cpuid
    mov [temp_value], edx
    mov esi, cpu_features_edx_text
    call print_string
    mov eax, [temp_value]
    call print_hex32
    call print_newline

    mov [temp_value], ecx
    mov esi, cpu_features_ecx_text
    call print_string
    mov eax, [temp_value]
    call print_hex32
    call print_newline
    call print_newline
    popa
    ret

print_irq_info:
    pusha
    mov esi, irq_header_text
    call print_string

    mov esi, irq_timer_text
    call print_string
    mov eax, [timer_ticks]
    call print_dec
    call print_newline

    mov esi, irq_keyboard_text
    call print_string
    mov eax, [keyboard_irq_count]
    call print_dec
    call print_newline

    mov esi, irq_chars_text
    call print_string
    mov eax, [keyboard_char_count]
    call print_dec
    call print_newline

    mov esi, irq_buffer_text
    call print_string
    movzx eax, byte [kbd_head]
    call print_dec
    mov esi, irq_tail_text
    call print_string
    movzx eax, byte [kbd_tail]
    call print_dec
    call print_newline
    call print_newline
    popa
    ret

print_memory_map:
    pusha
    mov esi, mmap_header_text
    call print_string

    movzx eax, word [MEMORY_MAP_COUNT]
    cmp eax, 0
    jne .has_map

    mov esi, mmap_none_text
    call print_string
    jmp .done

.has_map:
    mov [mmap_remaining], eax
    mov dword [mmap_index], 0
    mov dword [mmap_ptr], MEMORY_MAP_ENTRIES

.next_entry:
    cmp dword [mmap_remaining], 0
    je .done

    mov esi, mmap_entry_text
    call print_string
    mov eax, [mmap_index]
    call print_dec

    mov esi, mmap_base_text
    call print_string
    mov edi, [mmap_ptr]
    mov eax, [edi]
    call print_hex32

    mov esi, mmap_len_text
    call print_string
    mov edi, [mmap_ptr]
    mov eax, [edi + 8]
    call print_hex32

    mov esi, mmap_type_text
    call print_string
    mov edi, [mmap_ptr]
    mov eax, [edi + 16]
    call print_dec
    call print_newline

    add dword [mmap_ptr], E820_ENTRY_SIZE
    inc dword [mmap_index]
    dec dword [mmap_remaining]
    jmp .next_entry

.done:
    call print_newline
    popa
    ret

print_paging_info:
    pusha
    mov esi, paging_header_text
    call print_string

    mov esi, paging_state_text
    call print_string
    cmp dword [paging_enabled], 1
    je .enabled
    mov esi, off_text
    call print_string
    jmp .state_done
.enabled:
    mov esi, on_text
    call print_string
.state_done:
    call print_newline

    mov esi, paging_cr0_text
    call print_string
    mov eax, cr0
    call print_hex32
    call print_newline

    mov esi, paging_cr3_text
    call print_string
    mov eax, cr3
    call print_hex32
    call print_newline

    mov esi, paging_dir_text
    call print_string
    mov eax, page_directory
    call print_hex32
    call print_newline

    mov esi, paging_table_text
    call print_string
    mov eax, page_table0
    call print_hex32
    call print_newline
    call print_newline
    popa
    ret

print_status_info:
    pusha
    mov esi, status_header_text
    call print_string

    mov esi, status_version_text
    call print_string
    mov esi, version_text
    call print_string

    mov esi, status_ticks_text
    call print_string
    mov eax, [timer_ticks]
    call print_dec
    call print_newline

    mov esi, status_e820_text
    call print_string
    movzx eax, word [MEMORY_MAP_COUNT]
    call print_dec
    call print_newline

    mov esi, status_heap_next_text
    call print_string
    mov eax, [heap_next]
    call print_hex32
    call print_newline

    mov esi, status_paging_text
    call print_string
    cmp dword [paging_enabled], 1
    je .paging_on
    mov esi, off_text
    call print_string
    jmp .done_paging
.paging_on:
    mov esi, on_text
    call print_string
.done_paging:
    call print_newline
    call print_newline
    popa
    ret

print_file_list:
    pusha
    mov esi, fs_list_text
    call print_string
    popa
    ret

file_explorer:
    pusha
    mov byte [explorer_selected], 0
    mov byte [explorer_exit], 0

.render:
    call render_file_explorer

.wait_key:
    call read_char
    call lower_char

    cmp al, 'q'
    je .quit
    cmp al, 27
    je .quit

    cmp al, 'z'             ; AZERTY up
    je .up
    cmp al, 'k'
    je .up
    cmp al, 'p'
    je .up

    cmp al, 's'             ; AZERTY down
    je .down
    cmp al, 'j'
    je .down
    cmp al, 'n'
    je .down

    cmp al, 13
    je .open
    cmp al, 10
    je .open
    cmp al, 'o'
    je .open

    jmp .wait_key

.up:
    cmp byte [explorer_selected], 0
    jne .up_dec
    mov byte [explorer_selected], FILE_COUNT - 1
    jmp .render
.up_dec:
    dec byte [explorer_selected]
    jmp .render

.down:
    inc byte [explorer_selected]
    cmp byte [explorer_selected], FILE_COUNT
    jb .render
    mov byte [explorer_selected], 0
    jmp .render

.open:
    call explorer_open_selected
    cmp byte [explorer_exit], 1
    je .quit
    jmp .render

.quit:
    call clear_screen
    mov esi, explorer_exit_text
    call print_string
    popa
    ret

render_file_explorer:
    pusha
    call clear_screen
    mov esi, explorer_header_text
    call print_string

    mov al, 0
    mov esi, fs_name_readme
    call explorer_print_item

    mov al, 1
    mov esi, fs_name_roadmap
    call explorer_print_item

    mov al, 2
    mov esi, fs_name_ai
    call explorer_print_item

    mov al, 3
    mov esi, fs_name_license
    call explorer_print_item

    mov esi, explorer_footer_text
    call print_string
    popa
    ret

; al = item index, esi = zero-terminated filename
explorer_print_item:
    pusha
    mov bl, al
    cmp bl, [explorer_selected]
    jne .normal
    mov esi, explorer_selected_marker
    call print_string
    jmp .name
.normal:
    mov esi, explorer_normal_marker
    call print_string
.name:
    popa
    push esi
    call print_string
    mov esi, explorer_file_suffix
    call print_string
    pop esi
    ret

explorer_open_selected:
    pusha
    call clear_screen
    cmp byte [explorer_selected], 0
    je .readme
    cmp byte [explorer_selected], 1
    je .roadmap
    cmp byte [explorer_selected], 2
    je .ai
    jmp .license

.readme:
    mov esi, fs_readme_text
    call print_string
    jmp .wait
.roadmap:
    mov esi, fs_roadmap_text
    call print_string
    jmp .wait
.ai:
    mov esi, fs_ai_text
    call print_string
    jmp .wait
.license:
    mov esi, fs_license_text
    call print_string

.wait:
    mov esi, explorer_view_footer_text
    call print_string

.wait_key:
    call read_char
    call lower_char
    cmp al, 'q'
    je .quit
    cmp al, 27
    je .quit
    cmp al, 'b'
    je .back
    cmp al, 8
    je .back
    cmp al, 13
    je .back
    cmp al, 10
    je .back
    jmp .wait_key

.quit:
    mov byte [explorer_exit], 1
    popa
    ret
.back:
    mov byte [explorer_exit], 0
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
keyboard_irq_count dd 0
keyboard_char_count dd 0
paging_enabled dd 0
heap_next dd HEAP_START
temp_value dd 0
mmap_index dd 0
mmap_remaining dd 0
mmap_ptr dd 0
current_char db 0
shift_down db 0
keyboard_layout db KEYBOARD_LAYOUT_FR
explorer_selected db 0
explorer_exit db 0
kbd_head db 0
kbd_tail db 0
dec_buffer times 11 db 0
cpu_vendor times 13 db 0
kbd_buffer times KBD_BUFFER_SIZE db 0

input_buffer times INPUT_MAX db 0

cmd_help    db 'help', 0
cmd_about   db 'about', 0
cmd_clear   db 'clear', 0
cmd_reboot  db 'reboot', 0
cmd_mem     db 'mem', 0
cmd_version db 'version', 0
cmd_uptime  db 'uptime', 0
cmd_cpu     db 'cpu', 0
cmd_irq     db 'irq', 0
cmd_heap    db 'heap', 0
cmd_alloc   db 'alloc', 0
cmd_mmap    db 'mmap', 0
cmd_paging  db 'paging', 0
cmd_status  db 'status', 0
cmd_ls      db 'ls', 0
cmd_explorer db 'explorer', 0
cmd_files   db 'files', 0
cmd_explorateur db 'explorateur', 0
cmd_fichiers db 'fichiers', 0

banner:
    db '========================================', 10
    db ' AstraOS 0.0.5 Navigator', 10
    db ' 32-bit protected mode kernel', 10
    db ' Open source MIT - black and white', 10
    db ' Keyboard: IRQ1 FR AZERTY by default', 10
    db ' Interrupts: IDT/PIC/PIT online', 10
    db ' Memory: BIOS E820 map + tiny heap', 10
    db ' Files: interactive RAM explorer', 10
    db '========================================', 10, 10
    db 'Type help to begin.', 10, 10, 0

prompt_text db 'astra> ', 0

help_text:
    db 'Commands:', 10
    db '  help     Show this help', 10
    db '  about    What AstraOS is', 10
    db '  version  Show version', 10
    db '  uptime   Show timer ticks since boot', 10
    db '  mem      Show memory and heap info', 10
    db '  mmap     Show BIOS E820 memory map', 10
    db '  paging   Show paging/CR3 info', 10
    db '  status   Show compact system status', 10
    db '  heap     Show tiny bump allocator state', 10
    db '  alloc    Allocate a 256-byte demo block', 10
    db '  cpu      Show CPUID vendor/features', 10
    db '  irq      Show interrupt counters', 10
    db '  ls       List RAM files', 10
    db '  explorer Interactive RAM file explorer', 10
    db '  files    Alias for explorer', 10
    db '  explorateur Alias FR', 10
    db '  cat NAME Print a RAM file', 10
    db '  echo TXT Print text', 10
    db '  ai       Local AI helper', 10
    db '  kbd      Show keyboard layout', 10
    db '  kbd fr   Switch to French AZERTY', 10
    db '  kbd us   Switch to US QWERTY', 10
    db '  clear    Clear the screen', 10
    db '  reboot   Restart the VM', 10, 10, 0

about_text:
    db 'AstraOS is a tiny x86 operating system made from scratch.', 10
    db 'This first base boots with a 16-bit loader, switches to 32-bit', 10
    db 'protected mode, starts IRQ-driven input, a timer, memory map,', 10
    db 'paging, a RAM file explorer, and a tiny shell. Light, modular, AI-ready.', 10, 10, 0

version_text db 'AstraOS 0.0.5 Navigator - kernel32', 10, 10, 0

mem_header_text db 'Memory status:', 10, 0
mem_mode_text:
    db '  CPU mode : 32-bit protected mode', 10
    db '  Timer    : PIT IRQ0 at 100 Hz', 10
    db '  Keyboard : IRQ1 ring buffer', 10
    db '  Paging   : identity map first 4 MiB', 10
    db '  Idle     : HLT sleep between IRQs', 10
    db '  Kernel   : fixed low-memory image loaded at 0x10000', 10, 0
mem_map_count_text db '  E820 entries : ', 0
mem_usable_text db '  Usable RAM   : ', 0
kib_open_text db ' KiB (', 0
mib_close_text db ' MiB)', 10, 10, 0
heap_header_text db 'Tiny heap:', 10, 0
heap_start_text db '  start : ', 0
heap_next_text db '  next  : ', 0
heap_used_text db '  used  : ', 0
heap_free_text db '  free  : ', 0
bytes_text db ' bytes / ', 0
kib_suffix_text db ' KiB', 10, 0
alloc_ok_text db 'Allocated 256 bytes at ', 0
alloc_fail_text db 'Heap allocation failed: no space left.', 10, 10, 0
hex_prefix db '0x', 0
on_text db 'on', 0
off_text db 'off', 0
paging_header_text db 'Paging status:', 10, 0
paging_state_text db '  state : ', 0
paging_cr0_text db '  CR0   : ', 0
paging_cr3_text db '  CR3   : ', 0
paging_dir_text db '  dir   : ', 0
paging_table_text db '  table : ', 0
status_header_text db 'System status:', 10, 0
status_version_text db '  version : ', 0
status_ticks_text db '  ticks   : ', 0
status_e820_text db '  e820    : ', 0
status_heap_next_text db '  heap    : ', 0
status_paging_text db '  paging  : ', 0
cat_usage_text db 'Usage: cat readme|roadmap|ai|license', 10, 10, 0
cat_not_found_text db 'File not found. Type ls.', 10, 10, 0
echo_usage_text db 'Usage: echo text', 10, 10, 0

ai_text:
    db 'AstraAI local stub online.', 10
    db 'I am still rule-based: no wasted RAM, no cloud dependency.', 10
    db 'Kernel data available now: uptime, cpu, irq, mem, mmap, heap, files.', 10
    db 'Try: ai mem, ai fichiers, ai clavier, ai cpu, ai irq, ai heap.', 10, 10, 0
ai_arg_mem db 'mem', 0
ai_arg_memoire db 'memoire', 0
ai_arg_files db 'files', 0
ai_arg_fichiers db 'fichiers', 0
ai_arg_clavier db 'clavier', 0
ai_arg_kbd db 'kbd', 0
ai_arg_cpu db 'cpu', 0
ai_arg_irq db 'irq', 0
ai_arg_heap db 'heap', 0
ai_mem_text db 'AstraAI: utilise mem pour le resume, mmap pour la carte BIOS, heap pour l allocateur.', 10, 10, 0
ai_files_text db 'AstraAI: utilise explorer pour naviguer, ls pour lister, cat readme pour lire.', 10, 10, 0
ai_kbd_text db 'AstraAI: le clavier est en IRQ1. Utilise kbd, kbd fr, ou kbd us.', 10, 10, 0
ai_cpu_text db 'AstraAI: utilise cpu pour CPUID et paging pour CR0/CR3.', 10, 10, 0
ai_irq_text db 'AstraAI: utilise irq pour les compteurs et uptime pour le timer.', 10, 10, 0
ai_heap_text db 'AstraAI: utilise heap pour l etat, alloc pour reserver 256 octets de test.', 10, 10, 0
ai_unknown_text db 'AstraAI: je connais surtout mem, fichiers, clavier, cpu, irq, heap pour le moment.', 10, 10, 0

uptime_prefix db 'Uptime: ', 0
uptime_seconds_text db 's (ticks: ', 0
uptime_ticks_suffix db ')', 10, 10, 0
exception_text db 'AstraOS kernel panic: CPU exception.', 10, 0
exception_vector_text db '  vector: ', 0
exception_hint_text db 'System halted to protect the kernel.', 10, 0

cpu_header_text db 'CPU info:', 10, 0
cpu_vendor_text db '  vendor       : ', 0
cpu_features_edx_text db '  features EDX : ', 0
cpu_features_ecx_text db '  features ECX : ', 0
irq_header_text db 'Interrupt counters:', 10, 0
irq_timer_text db '  timer ticks   : ', 0
irq_keyboard_text db '  keyboard IRQs : ', 0
irq_chars_text db '  chars queued  : ', 0
irq_buffer_text db '  buffer head   : ', 0
irq_tail_text db ' tail: ', 0
mmap_header_text db 'BIOS E820 memory map:', 10, 0
mmap_none_text db '  No E820 map provided by the bootloader.', 10, 0
mmap_entry_text db '  #', 0
mmap_base_text db ' base=', 0
mmap_len_text db ' len=', 0
mmap_type_text db ' type=', 0

kbd_current_fr_text db 'Keyboard layout: FR AZERTY. Use kbd us to switch.', 10, 10, 0
kbd_current_us_text db 'Keyboard layout: US QWERTY. Use kbd fr to switch.', 10, 10, 0
kbd_set_fr_text db 'Keyboard switched to FR AZERTY.', 10, 10, 0
kbd_set_us_text db 'Keyboard switched to US QWERTY.', 10, 10, 0
kbd_usage_text db 'Usage: kbd, kbd fr, or kbd us.', 10, 10, 0

explorer_header_text:
    db '========================================', 10
    db ' AstraOS File Explorer', 10
    db ' RAM filesystem /', 10
    db '========================================', 10, 10
    db 'Files:', 10, 0
explorer_footer_text:
    db 10
    db 'Controls: z/k=up  s/j=down  Enter/o=open  q=quit', 10, 0
explorer_view_footer_text:
    db 10
    db 'Controls: b/Enter=back  q=quit explorer', 10, 0
explorer_exit_text db 'Exited file explorer.', 10, 10, 0
explorer_selected_marker db ' > ', 0
explorer_normal_marker db '   ', 0
explorer_file_suffix db '  [ram]', 10, 0

fs_name_readme db 'readme', 0
fs_name_roadmap db 'roadmap', 0
fs_name_ai db 'ai', 0
fs_name_license db 'license', 0
fs_list_text:
    db 'RAM files:', 10
    db '  readme', 10
    db '  roadmap', 10
    db '  ai', 10
    db '  license', 10, 10, 0
fs_readme_text:
    db 'readme:', 10
    db '  AstraOS is a tiny 32-bit OS base: bootloader, protected mode,', 10
    db '  IDT, PIC, PIT, IRQ keyboard, paging, E820 memory, heap, ramfs.', 10, 10, 0
fs_roadmap_text:
    db 'roadmap:', 10
    db '  next: stronger exceptions, real filesystem on disk, programs,', 10
    db '  user/kernel separation, then accounts and a smarter AstraAI.', 10, 10, 0
fs_ai_text:
    db 'ai:', 10
    db '  AstraAI starts as a local rule helper so the kernel stays tiny.', 10
    db '  It suggests commands without loading a heavy model by default.', 10, 10, 0
fs_license_text db 'license: MIT open source.', 10, 10, 0

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

exception_handlers:
    dd isr_exception_0, isr_exception_1, isr_exception_2, isr_exception_3
    dd isr_exception_4, isr_exception_5, isr_exception_6, isr_exception_7
    dd isr_exception_8, isr_exception_9, isr_exception_10, isr_exception_11
    dd isr_exception_12, isr_exception_13, isr_exception_14, isr_exception_15
    dd isr_exception_16, isr_exception_17, isr_exception_18, isr_exception_19
    dd isr_exception_20, isr_exception_21, isr_exception_22, isr_exception_23
    dd isr_exception_24, isr_exception_25, isr_exception_26, isr_exception_27
    dd isr_exception_28, isr_exception_29, isr_exception_30, isr_exception_31

; Paging structures are part of the kernel image and identity-mapped.
align 4096
page_directory times PAGE_ENTRIES dd 0
page_table0 times PAGE_ENTRIES dd 0
