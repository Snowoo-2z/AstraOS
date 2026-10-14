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

    mov al, 4
    mov esi, fs_name_system
    call explorer_print_item

    mov al, 5
    mov esi, fs_name_commands
    call explorer_print_item

    mov al, 6
    mov esi, fs_name_notes
    call explorer_print_item

    mov al, 7
    mov esi, fs_name_credits
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
    cmp byte [explorer_selected], 3
    je .license
    cmp byte [explorer_selected], 4
    je .system
    cmp byte [explorer_selected], 5
    je .commands
    cmp byte [explorer_selected], 6
    je .notes
    jmp .credits

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
    jmp .wait
.system:
    mov esi, fs_system_text
    call print_string
    jmp .wait
.commands:
    mov esi, fs_commands_text
    call print_string
    jmp .wait
.notes:
    call print_note_file
    jmp .wait
.credits:
    mov esi, fs_credits_text
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

