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

    mov esi, mouse_mode_text
    call print_string
    cmp byte [vmmouse_enabled], 1
    jne .relative_mode
    mov esi, mouse_absolute_text
    call print_string
    jmp .mode_done
.relative_mode:
    mov esi, mouse_relative_text
    call print_string
.mode_done:
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

