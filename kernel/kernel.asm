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
FILE_LIST_START_ROW equ 6
MOUSE_MAX_X equ 312
MOUSE_MAX_Y equ 190
GUI_VRAM equ 0xA0000
GUI_BACKBUFFER equ 0x300000

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
    mov edi, cmd_mouse
    call string_equals
    cmp eax, 1
    je .mouse

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

    mov esi, input_buffer
    mov edi, cmd_gui
    call string_equals
    cmp eax, 1
    je .explorer

    mov esi, input_buffer
    mov edi, cmd_desktop
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

.mouse:
    call print_mouse_info
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
    call gui_explorer
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
    inc dword [mouse_packet_count]

    ; X movement, signed 8-bit.
    movsx eax, byte [mouse_packet + 1]
    add [mouse_x], eax
    call clamp_mouse_x

    ; PS/2 Y is positive upward; screen Y is positive downward.
    movsx eax, byte [mouse_packet + 2]
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

print_mouse_info:
    pusha
    mov esi, mouse_header_text
    call print_string

    mov esi, mouse_state_text
    call print_string
    cmp byte [mouse_enabled], 1
    je .enabled
    mov esi, off_text
    call print_string
    jmp .state_done
.enabled:
    mov esi, on_text
    call print_string
.state_done:
    call print_newline

    mov esi, mouse_x_text
    call print_string
    mov eax, [mouse_x]
    call print_dec
    mov esi, mouse_y_text
    call print_string
    mov eax, [mouse_y]
    call print_dec
    call print_newline

    mov esi, mouse_buttons_text
    call print_string
    movzx eax, byte [mouse_buttons]
    call print_dec
    call print_newline

    mov esi, mouse_irq_text
    call print_string
    mov eax, [mouse_irq_count]
    call print_dec
    call print_newline

    mov esi, mouse_packets_text
    call print_string
    mov eax, [mouse_packet_count]
    call print_dec
    call print_newline
    call print_newline
    popa
    ret

; ------------------------------------------------------------
; First graphical interface: VGA mode 13h file explorer.
; ------------------------------------------------------------
gui_explorer:
    pusha
    cli
    call vga_set_mode_13h
    sti

    mov dword [mouse_x], 160
    mov dword [mouse_y], 100
    mov byte [mouse_left_click], 0
    mov byte [mouse_updated], 1
    mov byte [gui_hover], 255

.gui_loop:
    call gui_update_hover
    call gui_render_desktop

.wait_event:
    call serial_read_char
    cmp al, 0
    jne .handle_key

    call keyboard_buffer_pop
    cmp al, 0
    jne .handle_key

    cmp byte [mouse_updated], 0
    jne .mouse_event

    hlt
    jmp .wait_event

.mouse_event:
    mov byte [mouse_updated], 0
    cmp byte [mouse_left_click], 1
    jne .gui_loop
    mov byte [mouse_left_click], 0
    cmp byte [gui_hover], 255
    je .gui_loop
    call gui_open_hovered_file
    jmp .gui_loop

.handle_key:
    call lower_char
    cmp al, 'q'
    je .reboot
    cmp al, 'r'
    je .gui_loop
    cmp al, '1'
    jb .gui_loop
    cmp al, '4'
    ja .gui_loop
    sub al, '1'
    mov [gui_hover], al
    call gui_open_hovered_file
    jmp .gui_loop

.reboot:
    call reboot_system
    popa
    ret

gui_update_hover:
    pusha
    mov byte [gui_hover], 255

    mov eax, [mouse_y]
    cmp eax, 58
    jb .done
    cmp eax, 128
    ja .done

    mov eax, [mouse_x]
    cmp eax, 24
    jb .check_roadmap
    cmp eax, 82
    ja .check_roadmap
    mov byte [gui_hover], 0
    jmp .done

.check_roadmap:
    cmp eax, 94
    jb .check_ai
    cmp eax, 152
    ja .check_ai
    mov byte [gui_hover], 1
    jmp .done

.check_ai:
    cmp eax, 164
    jb .check_license
    cmp eax, 222
    ja .check_license
    mov byte [gui_hover], 2
    jmp .done

.check_license:
    cmp eax, 234
    jb .done
    cmp eax, 304
    ja .done
    mov byte [gui_hover], 3

.done:
    popa
    ret

gui_render_desktop:
    pusha
    mov dword [gfx_target], GUI_BACKBUFFER
    mov byte [rect_color], 0
    mov dword [rect_x], 0
    mov dword [rect_y], 0
    mov dword [rect_w], 320
    mov dword [rect_h], 200
    call gfx_fill_rect

    mov byte [rect_color], 8
    mov dword [rect_x], 0
    mov dword [rect_y], 0
    mov dword [rect_w], 320
    mov dword [rect_h], 18
    call gfx_fill_rect

    mov esi, gui_title_text
    mov ebx, 8
    mov ecx, 5
    mov dl, 15
    call gfx_draw_text

    mov byte [rect_color], 15
    mov dword [rect_x], 10
    mov dword [rect_y], 28
    mov dword [rect_w], 300
    mov dword [rect_h], 150
    call gfx_fill_rect
    call gfx_draw_window_border

    mov esi, gui_window_title_text
    mov ebx, 18
    mov ecx, 35
    mov dl, 0
    call gfx_draw_text

    mov al, 0
    mov ebx, 24
    mov ecx, 68
    mov esi, gui_readme_label
    call gfx_draw_file_icon

    mov al, 1
    mov ebx, 94
    mov ecx, 68
    mov esi, gui_roadmap_label
    call gfx_draw_file_icon

    mov al, 2
    mov ebx, 164
    mov ecx, 68
    mov esi, gui_ai_label
    call gfx_draw_file_icon

    mov al, 3
    mov ebx, 234
    mov ecx, 68
    mov esi, gui_license_label
    call gfx_draw_file_icon

    mov esi, gui_footer_text
    mov ebx, 18
    mov ecx, 188
    mov dl, 15
    call gfx_draw_text

    call gfx_draw_cursor
    call gfx_present
    popa
    ret

gfx_draw_window_border:
    pusha
    mov byte [rect_color], 15
    mov dword [rect_x], 10
    mov dword [rect_y], 28
    mov dword [rect_w], 300
    mov dword [rect_h], 1
    call gfx_fill_rect
    mov dword [rect_y], 177
    call gfx_fill_rect
    mov dword [rect_x], 10
    mov dword [rect_y], 28
    mov dword [rect_w], 1
    mov dword [rect_h], 150
    call gfx_fill_rect
    mov dword [rect_x], 309
    call gfx_fill_rect
    popa
    ret

; al = icon index, ebx/ecx = x/y, esi = label
gfx_draw_file_icon:
    pusha
    mov [gui_icon_index], al
    mov [gui_icon_x], ebx
    mov [gui_icon_y], ecx
    mov [gui_icon_label], esi

    mov byte [rect_color], 7
    cmp al, [gui_hover]
    jne .color_ok
    mov byte [rect_color], 15
.color_ok:
    mov eax, [gui_icon_x]
    mov [rect_x], eax
    mov eax, [gui_icon_y]
    mov [rect_y], eax
    mov dword [rect_w], 48
    mov dword [rect_h], 32
    call gfx_fill_rect

    mov byte [rect_color], 8
    mov eax, [gui_icon_x]
    add eax, 4
    mov [rect_x], eax
    mov eax, [gui_icon_y]
    sub eax, 5
    mov [rect_y], eax
    mov dword [rect_w], 22
    mov dword [rect_h], 7
    call gfx_fill_rect

    mov esi, [gui_icon_label]
    mov ebx, [gui_icon_x]
    mov ecx, [gui_icon_y]
    add ecx, 40
    mov dl, 0
    call gfx_draw_text
    popa
    ret

gui_open_hovered_file:
    pusha
    call gui_render_viewer

.wait:
    call serial_read_char
    cmp al, 0
    jne .key
    call keyboard_buffer_pop
    cmp al, 0
    jne .key
    cmp byte [mouse_left_click], 1
    je .mouse_back
    hlt
    jmp .wait

.mouse_back:
    mov byte [mouse_left_click], 0
    jmp .done

.key:
    call lower_char
    cmp al, 'q'
    je .reboot
    cmp al, 'b'
    je .done
    cmp al, 13
    je .done
    cmp al, 10
    je .done
    jmp .wait

.reboot:
    call reboot_system
.done:
    popa
    ret

gui_render_viewer:
    pusha
    mov dword [gfx_target], GUI_BACKBUFFER
    mov byte [rect_color], 0
    mov dword [rect_x], 0
    mov dword [rect_y], 0
    mov dword [rect_w], 320
    mov dword [rect_h], 200
    call gfx_fill_rect

    mov byte [rect_color], 15
    mov dword [rect_x], 16
    mov dword [rect_y], 18
    mov dword [rect_w], 288
    mov dword [rect_h], 164
    call gfx_fill_rect

    mov byte [rect_color], 8
    mov dword [rect_x], 16
    mov dword [rect_y], 18
    mov dword [rect_w], 288
    mov dword [rect_h], 16
    call gfx_fill_rect

    mov esi, gui_viewer_title
    mov ebx, 22
    mov ecx, 23
    mov dl, 15
    call gfx_draw_text

    cmp byte [gui_hover], 0
    je .readme
    cmp byte [gui_hover], 1
    je .roadmap
    cmp byte [gui_hover], 2
    je .ai
    jmp .license

.readme:
    mov esi, gui_readme_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_readme_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_readme_line3
    mov ecx, 74
    call gfx_draw_text
    jmp .footer

.roadmap:
    mov esi, gui_roadmap_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_roadmap_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_roadmap_line3
    mov ecx, 74
    call gfx_draw_text
    jmp .footer

.ai:
    mov esi, gui_ai_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_ai_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_ai_line3
    mov ecx, 74
    call gfx_draw_text
    jmp .footer

.license:
    mov esi, gui_license_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_license_line2
    mov ecx, 62
    call gfx_draw_text

.footer:
    mov esi, gui_viewer_footer
    mov ebx, 24
    mov ecx, 166
    mov dl, 0
    call gfx_draw_text
    call gfx_draw_cursor
    call gfx_present
    popa
    ret

vga_set_mode_13h:
    pusha
    mov esi, vga_13_regs

    mov dx, 0x3C2
    lodsb
    out dx, al

    xor ecx, ecx
.seq_loop:
    cmp ecx, 5
    je .unlock_crtc
    mov dx, 0x3C4
    mov al, cl
    out dx, al
    inc dx
    lodsb
    out dx, al
    inc ecx
    jmp .seq_loop

.unlock_crtc:
    mov dx, 0x3D4
    mov al, 0x03
    out dx, al
    inc dx
    in al, dx
    or al, 0x80
    out dx, al

    dec dx
    mov al, 0x11
    out dx, al
    inc dx
    in al, dx
    and al, 0x7F
    out dx, al

    xor ecx, ecx
.crtc_loop:
    cmp ecx, 25
    je .gc_loop_start
    mov dx, 0x3D4
    mov al, cl
    out dx, al
    inc dx
    lodsb
    out dx, al
    inc ecx
    jmp .crtc_loop

.gc_loop_start:
    xor ecx, ecx
.gc_loop:
    cmp ecx, 9
    je .ac_loop_start
    mov dx, 0x3CE
    mov al, cl
    out dx, al
    inc dx
    lodsb
    out dx, al
    inc ecx
    jmp .gc_loop

.ac_loop_start:
    xor ecx, ecx
.ac_loop:
    cmp ecx, 21
    je .ac_done
    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov al, cl
    out dx, al
    lodsb
    out dx, al
    inc ecx
    jmp .ac_loop

.ac_done:
    mov dx, 0x3DA
    in al, dx
    mov dx, 0x3C0
    mov al, 0x20
    out dx, al
    popa
    ret

gfx_fill_rect:
    pusha
    mov dword [rect_row], 0
.row:
    mov eax, [rect_row]
    cmp eax, [rect_h]
    jae .done

    mov eax, [rect_y]
    add eax, [rect_row]
    imul eax, 320
    add eax, [rect_x]
    mov edi, [gfx_target]
    add edi, eax
    mov ecx, [rect_w]
    mov al, [rect_color]
    rep stosb

    inc dword [rect_row]
    jmp .row
.done:
    popa
    ret

gfx_present:
    pusha
    mov esi, GUI_BACKBUFFER
    mov edi, GUI_VRAM
    mov ecx, 16000          ; 320 * 200 / 4
    rep movsd
    popa
    ret

gfx_draw_cursor:
    pusha
    ; Simple software arrow. Drawn into the backbuffer before presenting.
    mov byte [rect_color], 15
    mov dword [glyph_row], 0
.arrow_row:
    cmp dword [glyph_row], 8
    jae .tail
    mov eax, [mouse_x]
    mov [rect_x], eax
    mov eax, [mouse_y]
    add eax, [glyph_row]
    mov [rect_y], eax
    mov eax, [glyph_row]
    inc eax
    mov [rect_w], eax
    mov dword [rect_h], 1
    call gfx_fill_rect
    inc dword [glyph_row]
    jmp .arrow_row

.tail:
    mov byte [rect_color], 0
    mov eax, [mouse_x]
    add eax, 1
    mov [rect_x], eax
    mov eax, [mouse_y]
    add eax, 2
    mov [rect_y], eax
    mov dword [rect_w], 1
    mov dword [rect_h], 5
    call gfx_fill_rect
    popa
    ret

; esi = string, ebx = x, ecx = y, dl = color
gfx_draw_text:
    pusha
    mov [text_x], ebx
    mov [text_y], ecx
    mov [text_color], dl
.next:
    lodsb
    cmp al, 0
    je .done
    mov ebx, [text_x]
    mov ecx, [text_y]
    mov dl, [text_color]
    call gfx_draw_char
    add dword [text_x], 6
    jmp .next
.done:
    popa
    ret

; al = char, ebx = x, ecx = y, dl = color
gfx_draw_char:
    pusha
    call lower_char
    cmp al, 'a'
    jb .check_digit
    cmp al, 'z'
    ja .check_digit
    sub al, 32

.check_digit:
    mov [glyph_x], ebx
    mov [glyph_y], ecx
    mov [glyph_color], dl
    mov byte [glyph_char], al

    mov esi, font_blank
    cmp al, 'A'
    jb .digit
    cmp al, 'Z'
    ja .digit
    movzx eax, al
    sub eax, 'A'
    imul eax, 7
    mov esi, font_letters
    add esi, eax
    jmp .draw

.digit:
    mov al, [glyph_char]
    cmp al, '0'
    jb .special
    cmp al, '9'
    ja .special
    movzx eax, al
    sub eax, '0'
    imul eax, 7
    mov esi, font_digits
    add esi, eax
    jmp .draw

.special:
    mov al, [glyph_char]
    cmp al, ':'
    je .colon
    cmp al, '-'
    je .dash
    cmp al, '/'
    je .slash
    cmp al, '.'
    je .dot
    cmp al, '>'
    je .gt
    cmp al, '*'
    je .star
    jmp .draw
.colon:
    mov esi, font_colon
    jmp .draw
.dash:
    mov esi, font_dash
    jmp .draw
.slash:
    mov esi, font_slash
    jmp .draw
.dot:
    mov esi, font_dot
    jmp .draw
.gt:
    mov esi, font_gt
    jmp .draw
.star:
    mov esi, font_star

.draw:
    mov dword [glyph_row], 0
.row:
    cmp dword [glyph_row], 7
    jae .done
    mov ebx, [glyph_row]
    mov al, [esi + ebx]
    mov [glyph_bits], al
    mov dword [glyph_col], 0
.col:
    cmp dword [glyph_col], 5
    jae .next_row
    mov ebx, [glyph_col]
    mov al, [font_masks + ebx]
    test byte [glyph_bits], al
    jz .skip_pixel

    mov eax, [glyph_y]
    add eax, [glyph_row]
    imul eax, 320
    add eax, [glyph_x]
    add eax, [glyph_col]
    mov edi, [gfx_target]
    add edi, eax
    mov al, [glyph_color]
    mov [edi], al

.skip_pixel:
    inc dword [glyph_col]
    jmp .col
.next_row:
    inc dword [glyph_row]
    jmp .row
.done:
    popa
    ret

file_explorer:
    pusha
    mov byte [explorer_selected], 0
    mov byte [explorer_exit], 0
    mov byte [mouse_updated], 1

.render:
    call render_file_explorer

.wait_key:
    call serial_read_char
    cmp al, 0
    jne .handle_key

    call keyboard_buffer_pop
    cmp al, 0
    jne .handle_key

    cmp byte [mouse_updated], 0
    jne .handle_mouse

    hlt
    jmp .wait_key

.handle_key:
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

.handle_mouse:
    call explorer_handle_mouse
    cmp byte [explorer_exit], 1
    je .quit
    jmp .render

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
    call render_mouse_cursor
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

explorer_handle_mouse:
    pusha
    mov byte [mouse_updated], 0

    mov eax, [mouse_y]
    shr eax, 3               ; convert pixels to VGA text row
    cmp eax, FILE_LIST_START_ROW
    jb .consume_click

    sub eax, FILE_LIST_START_ROW
    cmp eax, FILE_COUNT
    jae .consume_click

    mov [explorer_selected], al
    cmp byte [mouse_left_click], 1
    jne .done
    mov byte [mouse_left_click], 0
    call explorer_open_selected
    jmp .done

.consume_click:
    cmp byte [mouse_left_click], 1
    jne .done
    mov byte [mouse_left_click], 0

.done:
    popa
    ret

render_mouse_cursor:
    pusha
    mov eax, [mouse_y]
    shr eax, 3
    cmp eax, VGA_HEIGHT - 1
    jle .y_ok
    mov eax, VGA_HEIGHT - 1
.y_ok:
    mov ecx, eax             ; row

    mov eax, [mouse_x]
    shr eax, 3
    cmp eax, VGA_WIDTH - 1
    jle .x_ok
    mov eax, VGA_WIDTH - 1
.x_ok:
    mov ebx, eax             ; column

    mov eax, ecx
    mov edx, VGA_WIDTH
    mul edx
    add eax, ebx
    shl eax, 1
    mov edi, VIDEO_MEMORY
    add edi, eax
    mov ax, (0xF0 << 8) | '*'
    mov [edi], ax
    popa
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
mouse_irq_count dd 0
mouse_packet_count dd 0
mouse_x dd 320
mouse_y dd 100
paging_enabled dd 0
heap_next dd HEAP_START
temp_value dd 0
mmap_index dd 0
mmap_remaining dd 0
mmap_ptr dd 0
gfx_target dd GUI_BACKBUFFER
rect_x dd 0
rect_y dd 0
rect_w dd 0
rect_h dd 0
rect_row dd 0
text_x dd 0
text_y dd 0
glyph_x dd 0
glyph_y dd 0
glyph_row dd 0
glyph_col dd 0
gui_icon_x dd 0
gui_icon_y dd 0
gui_icon_label dd 0
current_char db 0
shift_down db 0
keyboard_layout db KEYBOARD_LAYOUT_FR
mouse_packet_index db 0
mouse_buttons db 0
mouse_left_down db 0
mouse_left_click db 0
mouse_updated db 0
mouse_enabled db 0
gui_hover db 255
gui_icon_index db 0
rect_color db 0
text_color db 0
glyph_color db 0
glyph_char db 0
glyph_bits db 0
explorer_selected db 0
explorer_exit db 0
kbd_head db 0
kbd_tail db 0
dec_buffer times 11 db 0
cpu_vendor times 13 db 0
mouse_packet times 3 db 0
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
cmd_mouse   db 'mouse', 0
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
cmd_gui db 'gui', 0
cmd_desktop db 'desktop', 0

banner:
    db '========================================', 10
    db ' AstraOS 0.0.6 Pointer', 10
    db ' 32-bit protected mode kernel', 10
    db ' Open source MIT - black and white', 10
    db ' Keyboard: IRQ1 FR AZERTY by default', 10
    db ' Interrupts: IDT/PIC/PIT online', 10
    db ' Memory: BIOS E820 map + tiny heap', 10
    db ' Files: mouse-driven RAM explorer', 10
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
    db '  mouse    Show PS/2 mouse status', 10
    db '  ls       List RAM files', 10
    db '  explorer Interactive RAM file explorer', 10
    db '  files    Alias for explorer', 10
    db '  explorateur Alias FR', 10
    db '  gui      Start graphical explorer', 10
    db '  desktop  Alias for gui', 10
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

version_text db 'AstraOS 0.0.6 Pointer - kernel32', 10, 10, 0

mem_header_text db 'Memory status:', 10, 0
mem_mode_text:
    db '  CPU mode : 32-bit protected mode', 10
    db '  Timer    : PIT IRQ0 at 100 Hz', 10
    db '  Keyboard : IRQ1 ring buffer', 10
    db '  Mouse    : IRQ12 PS/2 pointer', 10
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
mouse_header_text db 'Mouse status:', 10, 0
mouse_state_text db '  state   : ', 0
mouse_x_text db '  x       : ', 0
mouse_y_text db ' y: ', 0
mouse_buttons_text db '  buttons : ', 0
mouse_irq_text db '  IRQ12   : ', 0
mouse_packets_text db '  packets : ', 0
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

gui_title_text db 'ASTRAOS GUI', 0
gui_window_title_text db 'FILES', 0
gui_footer_text db 'MOUSE CLICK OPEN  Q REBOOT', 0
gui_viewer_title db 'FILE VIEWER', 0
gui_viewer_footer db 'CLICK OR ENTER BACK  Q REBOOT', 0
gui_readme_label db 'README', 0
gui_roadmap_label db 'ROADMAP', 0
gui_ai_label db 'AI', 0
gui_license_label db 'LICENSE', 0
gui_readme_line1 db 'ASTRAOS GRAPHICAL FILE EXPLORER', 0
gui_readme_line2 db 'MODE 13H 320X200 VGA', 0
gui_readme_line3 db 'MOUSE DRIVER USES IRQ12', 0
gui_roadmap_line1 db 'NEXT REAL DISK FILESYSTEM', 0
gui_roadmap_line2 db 'WINDOWS ICONS AND PROGRAMS', 0
gui_roadmap_line3 db 'THEN USER MODE AND ACCOUNTS', 0
gui_ai_line1 db 'ASTRAAI STAYS LIGHT', 0
gui_ai_line2 db 'LOCAL COMMAND HELPER FIRST', 0
gui_ai_line3 db 'NO HEAVY MODEL IN KERNEL', 0
gui_license_line1 db 'MIT OPEN SOURCE', 0
gui_license_line2 db 'SNW 2026', 0

vga_13_regs:
    db 0x63
    db 0x03,0x01,0x0F,0x00,0x0E
    db 0x5F,0x4F,0x50,0x82,0x54,0x80,0xBF,0x1F,0x00,0x41,0x00,0x00,0x00,0x00,0x00,0x00,0x9C,0x0E,0x8F,0x28,0x40,0x96,0xB9,0xA3,0xFF
    db 0x00,0x00,0x00,0x00,0x00,0x40,0x05,0x0F,0xFF
    db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,0x41,0x00,0x0F,0x00,0x00

font_masks db 16,8,4,2,1
font_blank db 0,0,0,0,0,0,0
font_colon db 0,4,4,0,4,4,0
font_dash db 0,0,0,31,0,0,0
font_slash db 1,2,4,8,16,0,0
font_dot db 0,0,0,0,0,12,12
font_gt db 16,8,4,2,4,8,16
font_star db 4,21,14,31,14,21,4
font_digits:
    db 14,17,19,21,25,17,14
    db 4,12,4,4,4,4,14
    db 14,17,1,2,4,8,31
    db 30,1,1,14,1,1,30
    db 2,6,10,18,31,2,2
    db 31,16,30,1,1,17,14
    db 6,8,16,30,17,17,14
    db 31,1,2,4,8,8,8
    db 14,17,17,14,17,17,14
    db 14,17,17,15,1,2,12
font_letters:
    db 14,17,17,31,17,17,17
    db 30,17,17,30,17,17,30
    db 14,17,16,16,16,17,14
    db 30,17,17,17,17,17,30
    db 31,16,16,30,16,16,31
    db 31,16,16,30,16,16,16
    db 14,17,16,23,17,17,15
    db 17,17,17,31,17,17,17
    db 14,4,4,4,4,4,14
    db 7,2,2,2,18,18,12
    db 17,18,20,24,20,18,17
    db 16,16,16,16,16,16,31
    db 17,27,21,21,17,17,17
    db 17,25,21,19,17,17,17
    db 14,17,17,17,17,17,14
    db 30,17,17,30,16,16,16
    db 14,17,17,17,21,18,13
    db 30,17,17,30,20,18,17
    db 15,16,16,14,1,1,30
    db 31,4,4,4,4,4,4
    db 17,17,17,17,17,17,14
    db 17,17,17,17,17,10,4
    db 17,17,17,21,21,21,10
    db 17,17,10,4,10,17,17
    db 17,17,10,4,4,4,4
    db 31,1,2,4,8,16,31

explorer_header_text:
    db '========================================', 10
    db ' AstraOS File Explorer', 10
    db ' RAM filesystem /   Mouse enabled', 10
    db '========================================', 10, 10
    db 'Files:', 10, 0
explorer_footer_text:
    db 10
    db 'Controls: mouse click=open  z/k=up  s/j=down  Enter/o=open  q=quit', 10, 0
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
