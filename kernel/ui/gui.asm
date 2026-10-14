; ------------------------------------------------------------
; AstraOS graphical desktop and window manager prototype.
; ------------------------------------------------------------
gui_desktop:
    xor eax, eax
    jmp gui_enter

gui_explorer:
    mov al, GUI_WINDOW_FILES

gui_enter:
    pusha
    mov [gui_window_open], al
    cli
    call vga_set_mode_13h
    sti

    mov dword [mouse_x], 160
    mov dword [mouse_y], 100
    mov byte [mouse_left_click], 0
    mov byte [mouse_updated], 1
    mov byte [gui_hover], GUI_HOVER_NONE
    mov byte [gui_menu_open], 0
    mov byte [gui_window_dragging], 0
    mov byte [gui_window_maximized], 0
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    mov dword [gui_window_x], 70
    mov dword [gui_window_y], 18
    mov dword [gui_window_w], 238
    mov dword [gui_window_h], 150
    mov eax, [timer_ticks]
    mov [gui_last_clock_tick], eax

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
    mov eax, [timer_ticks]
    sub eax, [gui_last_clock_tick]
    cmp eax, PIT_FREQUENCY_HZ
    jb .wait_event
    mov eax, [timer_ticks]
    mov [gui_last_clock_tick], eax
    jmp .gui_loop

.mouse_event:
    mov byte [mouse_updated], 0
    call gui_update_hover
    call gui_handle_window_drag
    cmp byte [mouse_left_click], 1
    jne .gui_loop
    mov byte [mouse_left_click], 0
    call gui_activate_hover
    jmp .gui_loop

.handle_key:
    call lower_char
    cmp byte [gui_window_open], GUI_WINDOW_NOTES
    jne .global_key
    call gui_notepad_handle_key
    jmp .gui_loop

.global_key:
    cmp al, 'q'
    je .reboot
    cmp al, 'c'
    je .center_mouse
    cmp al, 27
    je .close_window
    cmp al, 'e'
    je .open_explorer
    cmp al, 'r'
    je .gui_loop

    cmp byte [gui_window_open], GUI_WINDOW_FILES
    jne .gui_loop
    cmp al, '1'
    jb .gui_loop
    cmp al, '8'
    ja .gui_loop
    sub al, '1'
    mov [gui_hover], al
    call gui_open_hovered_file
    jmp .gui_loop

.open_explorer:
    mov byte [gui_menu_open], 0
    mov byte [gui_window_open], GUI_WINDOW_FILES
    jmp .gui_loop

.close_window:
    cmp byte [gui_menu_open], 1
    jne .close_active_window
    mov byte [gui_menu_open], 0
    jmp .gui_loop
.close_active_window:
    mov byte [gui_window_open], GUI_WINDOW_NONE
    jmp .gui_loop

.center_mouse:
    mov dword [mouse_x], 160
    mov dword [mouse_y], 100
    mov byte [mouse_updated], 1
    jmp .gui_loop

.reboot:
    call reboot_system
    popa
    ret

; al = translated key. The first notepad intentionally edits one RAM line.
gui_notepad_handle_key:
    pusha
    cmp al, 27
    je .close
    cmp al, 8
    je .backspace
    cmp al, 127
    je .backspace
    cmp al, 32
    jb .done
    cmp al, 126
    ja .done

    movzx ebx, byte [gui_note_len]
    cmp ebx, GUI_NOTE_MAX
    jae .done
    mov [gui_note_buffer + ebx], al
    inc ebx
    mov byte [gui_note_buffer + ebx], 0
    mov [gui_note_len], bl
    jmp .done

.backspace:
    movzx ebx, byte [gui_note_len]
    cmp ebx, 0
    je .done
    dec ebx
    mov byte [gui_note_buffer + ebx], 0
    mov [gui_note_len], bl
    jmp .done
.close:
    mov byte [gui_window_open], GUI_WINDOW_NONE
.done:
    popa
    ret

gui_handle_window_drag:
    pusha
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .stop
    cmp byte [gui_window_maximized], 1
    je .stop
    cmp byte [gui_window_dragging], 1
    je .move
    cmp byte [mouse_left_click], 1
    jne .done
    cmp byte [gui_hover], 9
    jne .done

    mov byte [gui_window_dragging], 1
    mov eax, [mouse_x]
    sub eax, [gui_window_x]
    mov [gui_drag_offset_x], eax
    mov eax, [mouse_y]
    sub eax, [gui_window_y]
    mov [gui_drag_offset_y], eax
    jmp .done

.move:
    cmp byte [mouse_left_down], 1
    jne .stop

    mov eax, [mouse_x]
    sub eax, [gui_drag_offset_x]
    cmp eax, 0
    jge .x_max
    xor eax, eax
.x_max:
    cmp eax, 77              ; keep the 5px shadow inside 320px
    jle .x_ready
    mov eax, 77
.x_ready:
    mov [gui_window_x], eax

    mov eax, [mouse_y]
    sub eax, [gui_drag_offset_y]
    cmp eax, 0
    jge .y_max
    xor eax, eax
.y_max:
    cmp eax, 23              ; keep window shadow above the taskbar
    jle .y_ready
    mov eax, 23
.y_ready:
    mov [gui_window_y], eax
    jmp .done

.stop:
    mov byte [gui_window_dragging], 0
.done:
    popa
    ret

gui_activate_hover:
    pusha

    ; The taskbar button always toggles the Astra menu.
    cmp byte [gui_hover], 2
    jne .check_task_window
    xor byte [gui_menu_open], 1
    jmp .done

.check_task_window:
    cmp byte [gui_hover], 17
    jne .check_window_controls
    mov al, [gui_minimized_window]
    mov [gui_window_open], al
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    jmp .done

.check_window_controls:
    cmp byte [gui_hover], 15
    je .toggle_maximize
    cmp byte [gui_hover], 16
    je .minimize

.check_menu:
    cmp byte [gui_menu_open], 1
    jne .check_target
    mov byte [gui_menu_open], 0
    cmp byte [gui_hover], 10
    je .open_files
    cmp byte [gui_hover], 11
    je .open_system
    cmp byte [gui_hover], 12
    je .open_notes
    cmp byte [gui_hover], 13
    je .open_about
    cmp byte [gui_hover], 14
    je .reboot
    jmp .done

.check_target:
    cmp byte [gui_hover], GUI_HOVER_NONE
    je .done
    cmp byte [gui_hover], 8
    je .close
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .desktop
    cmp byte [gui_window_open], GUI_WINDOW_FILES
    je .files
    jmp .done

.desktop:
    cmp byte [gui_hover], 0
    je .open_files
    cmp byte [gui_hover], 1
    je .open_about
    cmp byte [gui_hover], 3
    je .open_system
    cmp byte [gui_hover], 4
    je .open_notes
    jmp .done

.files:
    cmp byte [gui_hover], 8
    jae .done
    call gui_open_hovered_file
    jmp .done

.toggle_maximize:
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .done
    cmp byte [gui_window_maximized], 1
    je .restore_size
    mov eax, [gui_window_x]
    mov [gui_restore_x], eax
    mov eax, [gui_window_y]
    mov [gui_restore_y], eax
    mov dword [gui_window_x], 0
    mov dword [gui_window_y], 0
    mov dword [gui_window_w], 320
    mov dword [gui_window_h], 178
    mov byte [gui_window_maximized], 1
    jmp .done
.restore_size:
    mov eax, [gui_restore_x]
    mov [gui_window_x], eax
    mov eax, [gui_restore_y]
    mov [gui_window_y], eax
    mov dword [gui_window_w], 238
    mov dword [gui_window_h], 150
    mov byte [gui_window_maximized], 0
    jmp .done

.minimize:
    mov al, [gui_window_open]
    cmp al, GUI_WINDOW_NONE
    je .done
    mov [gui_minimized_window], al
    mov byte [gui_window_open], GUI_WINDOW_NONE
    mov byte [gui_window_dragging], 0
    jmp .done

.open_files:
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    mov byte [gui_window_open], GUI_WINDOW_FILES
    jmp .done
.open_about:
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    mov byte [gui_window_open], GUI_WINDOW_ABOUT
    jmp .done
.open_system:
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    mov byte [gui_window_open], GUI_WINDOW_SYSTEM
    jmp .done
.open_notes:
    mov byte [gui_minimized_window], GUI_WINDOW_NONE
    mov byte [gui_window_open], GUI_WINDOW_NOTES
    jmp .done
.close:
    mov byte [gui_window_open], GUI_WINDOW_NONE
    jmp .done
.reboot:
    call reboot_system
.done:
    popa
    ret

gui_update_hover:
    pusha
    mov byte [gui_hover], GUI_HOVER_NONE

    ; Start button remains reachable while a window is open.
    mov eax, [mouse_y]
    cmp eax, 179
    jb .menu
    mov eax, [mouse_x]
    cmp eax, 4
    jb .menu
    cmp eax, 66
    jbe .task_start
    cmp byte [gui_minimized_window], GUI_WINDOW_NONE
    je .menu
    cmp eax, 72
    jb .menu
    cmp eax, 170
    ja .menu
    mov byte [gui_hover], 17
    jmp .done
.task_start:
    mov byte [gui_hover], 2
    jmp .done

.menu:
    cmp byte [gui_menu_open], 1
    jne .window
    mov eax, [mouse_x]
    cmp eax, 4
    jb .done
    cmp eax, 114
    ja .done
    mov eax, [mouse_y]
    cmp eax, 74
    jb .done
    cmp eax, 91
    jbe .menu_files
    cmp eax, 95
    jb .done
    cmp eax, 112
    jbe .menu_system
    cmp eax, 116
    jb .done
    cmp eax, 133
    jbe .menu_notes
    cmp eax, 137
    jb .done
    cmp eax, 154
    jbe .menu_about
    cmp eax, 157
    jb .done
    cmp eax, 174
    ja .done
    mov byte [gui_hover], 14
    jmp .done
.menu_files:
    mov byte [gui_hover], 10
    jmp .done
.menu_system:
    mov byte [gui_hover], 11
    jmp .done
.menu_notes:
    mov byte [gui_hover], 12
    jmp .done
.menu_about:
    mov byte [gui_hover], 13
    jmp .done

.window:
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .desktop

    ; Window controls follow the current width.
    mov eax, [mouse_y]
    mov edx, [gui_window_y]
    add edx, 2
    cmp eax, edx
    jb .titlebar
    add edx, 18
    cmp eax, edx
    ja .titlebar

    mov eax, [mouse_x]
    mov edx, [gui_window_x]
    add edx, [gui_window_w]
    sub edx, 18
    cmp eax, edx
    jb .check_maximize
    add edx, 16
    cmp eax, edx
    ja .titlebar
    mov byte [gui_hover], 8
    jmp .done

.check_maximize:
    mov edx, [gui_window_x]
    add edx, [gui_window_w]
    sub edx, 36
    cmp eax, edx
    jb .check_minimize
    add edx, 16
    cmp eax, edx
    ja .titlebar
    mov byte [gui_hover], 15
    jmp .done

.check_minimize:
    mov edx, [gui_window_x]
    add edx, [gui_window_w]
    sub edx, 54
    cmp eax, edx
    jb .titlebar
    add edx, 16
    cmp eax, edx
    ja .titlebar
    mov byte [gui_hover], 16
    jmp .done

.titlebar:
    mov eax, [mouse_y]
    mov edx, [gui_window_y]
    cmp eax, edx
    jb .window_content
    add edx, 22
    cmp eax, edx
    ja .window_content
    mov eax, [mouse_x]
    mov edx, [gui_window_x]
    cmp eax, edx
    jb .window_content
    add edx, [gui_window_w]
    cmp eax, edx
    ja .window_content
    mov byte [gui_hover], 9
    jmp .done

.window_content:
    cmp byte [gui_window_open], GUI_WINDOW_FILES
    jne .done
    mov eax, [mouse_y]
    mov edx, [gui_window_y]
    add edx, 32
    cmp eax, edx
    jb .done
    add edx, 55
    cmp eax, edx
    jbe .row_zero
    add edx, 3
    cmp eax, edx
    jb .done
    add edx, 55
    cmp eax, edx
    ja .done
    mov byte [gui_icon_index], 4
    jmp .file_column
.row_zero:
    mov byte [gui_icon_index], 0

.file_column:
    mov eax, [mouse_x]
    mov edx, [gui_window_x]
    add edx, 10
    cmp eax, edx
    jb .done
    add edx, 52
    cmp eax, edx
    jbe .column_zero
    add edx, 4
    cmp eax, edx
    jb .done
    add edx, 52
    cmp eax, edx
    jbe .column_one
    add edx, 4
    cmp eax, edx
    jb .done
    add edx, 52
    cmp eax, edx
    jbe .column_two
    add edx, 4
    cmp eax, edx
    jb .done
    add edx, 56
    cmp eax, edx
    ja .done
    mov al, [gui_icon_index]
    add al, 3
    mov [gui_hover], al
    jmp .done
.column_zero:
    mov al, [gui_icon_index]
    mov [gui_hover], al
    jmp .done
.column_one:
    mov al, [gui_icon_index]
    inc al
    mov [gui_hover], al
    jmp .done
.column_two:
    mov al, [gui_icon_index]
    add al, 2
    mov [gui_hover], al
    jmp .done

.desktop:
    mov eax, [mouse_y]
    cmp eax, 30
    jb .done
    cmp eax, 90
    jbe .desktop_top
    cmp eax, 98
    jb .done
    cmp eax, 158
    ja .done
    mov bl, 1               ; lower row: About / Notes
    jmp .desktop_column
.desktop_top:
    xor bl, bl              ; upper row: Files / System
.desktop_column:
    mov eax, [mouse_x]
    cmp eax, 10
    jb .done
    cmp eax, 68
    jbe .desktop_left
    cmp eax, 88
    jb .done
    cmp eax, 146
    ja .done
    cmp bl, 0
    jne .desktop_notes
    mov byte [gui_hover], 3
    jmp .done
.desktop_notes:
    mov byte [gui_hover], 4
    jmp .done
.desktop_left:
    mov al, bl
    mov [gui_hover], al
.done:
    popa
    ret

gui_render_desktop:
    pusha
    mov dword [gfx_target], GUI_BACKBUFFER

    ; Minimal black desktop with a subtle monochrome identity.
    mov byte [rect_color], 0
    mov dword [rect_x], 0
    mov dword [rect_y], 0
    mov dword [rect_w], 320
    mov dword [rect_h], 200
    call gfx_fill_rect

    mov byte [rect_color], 8
    mov dword [rect_x], 78
    mov dword [rect_y], 0
    mov dword [rect_w], 2
    mov dword [rect_h], 178
    call gfx_fill_rect

    mov esi, gui_desktop_brand
    mov ebx, 232
    mov ecx, 18
    mov dl, 8
    call gfx_draw_text
    mov esi, gui_desktop_tagline
    mov ebx, 190
    mov ecx, 30
    mov dl, 8
    call gfx_draw_text

    mov al, 0
    mov ebx, 18
    mov ecx, 38
    mov esi, gui_files_label
    call gfx_draw_desktop_icon

    mov al, 1
    mov ebx, 18
    mov ecx, 106
    mov esi, gui_about_label
    call gfx_draw_desktop_icon

    mov al, 3
    mov ebx, 96
    mov ecx, 38
    mov esi, gui_system_label
    call gfx_draw_desktop_icon

    mov al, 4
    mov ebx, 96
    mov ecx, 106
    mov esi, gui_notes_label
    call gfx_draw_desktop_icon

    call gui_draw_taskbar

    cmp byte [gui_window_open], GUI_WINDOW_FILES
    je .files
    cmp byte [gui_window_open], GUI_WINDOW_ABOUT
    je .about
    cmp byte [gui_window_open], GUI_WINDOW_SYSTEM
    je .system
    cmp byte [gui_window_open], GUI_WINDOW_NOTES
    je .notes
    jmp .finish
.files:
    call gui_draw_files_window
    jmp .finish
.about:
    call gui_draw_about_window
    jmp .finish
.system:
    call gui_draw_system_window
    jmp .finish
.notes:
    call gui_draw_notepad_window

.finish:
    cmp byte [gui_menu_open], 1
    jne .draw_cursor
    call gui_draw_start_menu
.draw_cursor:
    call gfx_draw_cursor
    call gfx_present
    popa
    ret

gui_draw_taskbar:
    pusha
    mov byte [rect_color], 8
    mov dword [rect_x], 0
    mov dword [rect_y], 178
    mov dword [rect_w], 320
    mov dword [rect_h], 22
    call gfx_fill_rect

    mov byte [rect_color], 15
    cmp byte [gui_hover], 2
    je .button_active
    cmp byte [gui_menu_open], 1
    jne .button_ready
.button_active:
    mov byte [rect_color], 7
.button_ready:
    mov dword [rect_x], 4
    mov dword [rect_y], 182
    mov dword [rect_w], 62
    mov dword [rect_h], 14
    call gfx_fill_rect

    mov esi, gui_start_label
    mov ebx, 10
    mov ecx, 186
    mov dl, 0
    call gfx_draw_text

    cmp byte [gui_minimized_window], GUI_WINDOW_NONE
    je .clock
    mov byte [rect_color], 15
    cmp byte [gui_hover], 17
    jne .task_window_color_ready
    mov byte [rect_color], 7
.task_window_color_ready:
    mov dword [rect_x], 72
    mov dword [rect_y], 182
    mov dword [rect_w], 98
    mov dword [rect_h], 14
    call gfx_fill_rect

    mov esi, gui_window_title_text
    cmp byte [gui_minimized_window], GUI_WINDOW_ABOUT
    jne .task_check_system
    mov esi, gui_about_label
    jmp .task_window_label
.task_check_system:
    cmp byte [gui_minimized_window], GUI_WINDOW_SYSTEM
    jne .task_check_notes
    mov esi, gui_system_label
    jmp .task_window_label
.task_check_notes:
    cmp byte [gui_minimized_window], GUI_WINDOW_NOTES
    jne .task_window_label
    mov esi, gui_notes_label
.task_window_label:
    mov ebx, 78
    mov ecx, 186
    mov dl, 0
    call gfx_draw_text

.clock:
    mov esi, gui_task_uptime
    mov ebx, 255
    mov ecx, 186
    mov dl, 15
    call gfx_draw_text

    mov eax, [timer_ticks]
    xor edx, edx
    mov ebx, PIT_FREQUENCY_HZ
    div ebx
    xor edx, edx
    mov ebx, 10000
    div ebx
    mov eax, edx             ; show the last four uptime seconds
    mov ebx, 272
    mov ecx, 186
    mov dl, 15
    call gfx_draw_uint
    popa
    ret

gui_draw_start_menu:
    pusha
    ; Shadow and panel above the taskbar.
    mov byte [rect_color], 8
    mov dword [rect_x], 8
    mov dword [rect_y], 56
    mov dword [rect_w], 110
    mov dword [rect_h], 118
    call gfx_fill_rect
    mov byte [rect_color], 15
    mov dword [rect_x], 4
    mov dword [rect_y], 52
    mov dword [rect_w], 110
    mov dword [rect_h], 123
    call gfx_fill_rect
    mov byte [rect_color], 0
    mov dword [rect_x], 4
    mov dword [rect_y], 52
    mov dword [rect_w], 110
    mov dword [rect_h], 18
    call gfx_fill_rect

    mov esi, gui_menu_title
    mov ebx, 10
    mov ecx, 58
    mov dl, 15
    call gfx_draw_text

    mov al, 10
    mov ecx, 74
    mov esi, gui_menu_files
    call gui_draw_menu_item
    mov al, 11
    mov ecx, 95
    mov esi, gui_menu_system
    call gui_draw_menu_item
    mov al, 12
    mov ecx, 116
    mov esi, gui_menu_notes
    call gui_draw_menu_item
    mov al, 13
    mov ecx, 137
    mov esi, gui_menu_about
    call gui_draw_menu_item
    mov al, 14
    mov ecx, 157
    mov esi, gui_menu_reboot
    call gui_draw_menu_item
    popa
    ret

; al = hover id, ecx = item y, esi = label
gui_draw_menu_item:
    pusha
    mov [gui_icon_index], al
    mov [gui_icon_y], ecx
    mov [gui_icon_label], esi
    mov byte [rect_color], 15
    cmp al, [gui_hover]
    jne .background_ready
    mov byte [rect_color], 7
.background_ready:
    mov dword [rect_x], 8
    mov eax, [gui_icon_y]
    mov [rect_y], eax
    mov dword [rect_w], 102
    mov dword [rect_h], 18
    call gfx_fill_rect
    mov esi, [gui_icon_label]
    mov ebx, 14
    mov ecx, [gui_icon_y]
    add ecx, 6
    mov dl, 0
    call gfx_draw_text
    popa
    ret

; al = desktop icon index, ebx/ecx = x/y, esi = label
gfx_draw_desktop_icon:
    pusha
    mov [gui_icon_index], al
    mov [gui_icon_x], ebx
    mov [gui_icon_y], ecx
    mov [gui_icon_label], esi

    cmp al, [gui_hover]
    jne .draw_icon
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    jne .draw_icon
    mov byte [rect_color], 8
    mov eax, [gui_icon_x]
    sub eax, 5
    mov [rect_x], eax
    mov eax, [gui_icon_y]
    sub eax, 5
    mov [rect_y], eax
    mov dword [rect_w], 55
    mov dword [rect_h], 57
    call gfx_fill_rect

.draw_icon:
    mov byte [rect_color], 15
    mov eax, [gui_icon_x]
    mov [rect_x], eax
    mov eax, [gui_icon_y]
    add eax, 6
    mov [rect_y], eax
    mov dword [rect_w], 40
    mov dword [rect_h], 25
    call gfx_fill_rect

    mov byte [rect_color], 7
    mov eax, [gui_icon_x]
    add eax, 3
    mov [rect_x], eax
    mov eax, [gui_icon_y]
    mov [rect_y], eax
    mov dword [rect_w], 18
    mov dword [rect_h], 7
    call gfx_fill_rect

    mov esi, [gui_icon_label]
    mov ebx, [gui_icon_x]
    mov ecx, [gui_icon_y]
    add ecx, 37
    mov dl, 15
    call gfx_draw_text
    popa
    ret

gui_draw_files_window:
    pusha
    call gui_draw_window_frame

    mov esi, gui_window_title_text
    mov ebx, [gui_window_x]
    add ebx, 12
    mov ecx, [gui_window_y]
    add ecx, 8
    mov dl, 15
    call gfx_draw_text

    mov ebx, [gui_window_x]
    add ebx, 14
    mov ecx, [gui_window_y]
    add ecx, 48
    mov al, 0
    mov esi, gui_readme_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 1
    mov esi, gui_roadmap_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 2
    mov esi, gui_ai_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 3
    mov esi, gui_license_label
    call gfx_draw_file_icon

    mov ebx, [gui_window_x]
    add ebx, 14
    mov ecx, [gui_window_y]
    add ecx, 98
    mov al, 4
    mov esi, gui_system_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 5
    mov esi, gui_commands_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 6
    mov esi, gui_notes_label
    call gfx_draw_file_icon
    add ebx, 56
    mov al, 7
    mov esi, gui_credits_label
    call gfx_draw_file_icon

    mov esi, gui_files_status
    mov ebx, [gui_window_x]
    add ebx, 105
    mov ecx, [gui_window_y]
    add ecx, 8
    mov dl, 7
    call gfx_draw_text
    popa
    ret

gui_draw_about_window:
    pusha
    call gui_draw_window_frame

    mov esi, gui_about_title
    mov ebx, [gui_window_x]
    add ebx, 12
    mov ecx, [gui_window_y]
    add ecx, 8
    mov dl, 15
    call gfx_draw_text

    mov ebx, [gui_window_x]
    add ebx, 18
    mov ecx, [gui_window_y]
    add ecx, 40
    mov dl, 0
    mov esi, gui_about_line1
    call gfx_draw_text
    add ecx, 16
    mov esi, gui_about_line2
    call gfx_draw_text
    add ecx, 16
    mov esi, gui_about_line3
    call gfx_draw_text
    add ecx, 16
    mov esi, gui_about_line4
    call gfx_draw_text

    mov esi, gui_about_hint
    mov ecx, [gui_window_y]
    add ecx, 122
    mov dl, 8
    call gfx_draw_text
    popa
    ret

gui_draw_system_window:
    pusha
    call gui_draw_window_frame

    mov esi, gui_system_title
    mov ebx, [gui_window_x]
    add ebx, 12
    mov ecx, [gui_window_y]
    add ecx, 8
    mov dl, 15
    call gfx_draw_text

    mov ebx, [gui_window_x]
    add ebx, 18
    mov ecx, [gui_window_y]
    add ecx, 42
    mov dl, 0
    mov esi, gui_system_uptime
    call gfx_draw_text
    add ecx, 18
    mov esi, gui_system_ticks
    call gfx_draw_text
    add ecx, 18
    mov esi, gui_system_keyboard
    call gfx_draw_text
    add ecx, 18
    mov esi, gui_system_mouse
    call gfx_draw_text
    add ecx, 18
    mov esi, gui_system_heap
    call gfx_draw_text

    mov ebx, [gui_window_x]
    add ebx, 174
    mov ecx, [gui_window_y]
    add ecx, 42
    mov eax, [timer_ticks]
    xor edx, edx
    mov edi, PIT_FREQUENCY_HZ
    div edi
    mov dl, 0
    call gfx_draw_uint

    add ecx, 18
    mov eax, [timer_ticks]
    call gfx_draw_uint
    add ecx, 18
    mov eax, [keyboard_irq_count]
    call gfx_draw_uint
    add ecx, 18
    mov eax, [mouse_packet_count]
    call gfx_draw_uint
    add ecx, 18
    mov eax, [heap_next]
    sub eax, HEAP_START
    call gfx_draw_uint
    popa
    ret

gui_draw_notepad_window:
    pusha
    call gui_draw_window_frame

    mov esi, gui_notepad_title
    mov ebx, [gui_window_x]
    add ebx, 12
    mov ecx, [gui_window_y]
    add ecx, 8
    mov dl, 15
    call gfx_draw_text

    mov byte [rect_color], 7
    mov eax, [gui_window_x]
    add eax, 12
    mov [rect_x], eax
    mov eax, [gui_window_y]
    add eax, 48
    mov [rect_y], eax
    mov dword [rect_w], 214
    mov dword [rect_h], 28
    call gfx_fill_rect

    cmp byte [gui_note_len], 0
    jne .note_text
    mov esi, gui_notepad_empty
    mov dl, 8
    jmp .draw_note
.note_text:
    mov esi, gui_note_buffer
    mov dl, 0
.draw_note:
    mov ebx, [gui_window_x]
    add ebx, 18
    mov ecx, [gui_window_y]
    add ecx, 59
    call gfx_draw_text

    mov esi, gui_notepad_hint
    mov ebx, [gui_window_x]
    add ebx, 18
    mov ecx, [gui_window_y]
    add ecx, 124
    mov dl, 8
    call gfx_draw_text
    popa
    ret

gui_draw_window_frame:
    pusha
    ; Shadow is only needed for a floating window.
    cmp byte [gui_window_maximized], 1
    je .body
    mov byte [rect_color], 8
    mov eax, [gui_window_x]
    add eax, 5
    mov [rect_x], eax
    mov eax, [gui_window_y]
    add eax, 5
    mov [rect_y], eax
    mov eax, [gui_window_w]
    mov [rect_w], eax
    mov eax, [gui_window_h]
    mov [rect_h], eax
    call gfx_fill_rect

.body:
    ; White client area and black title bar.
    mov byte [rect_color], 15
    mov eax, [gui_window_x]
    mov [rect_x], eax
    mov eax, [gui_window_y]
    mov [rect_y], eax
    mov eax, [gui_window_w]
    mov [rect_w], eax
    mov eax, [gui_window_h]
    mov [rect_h], eax
    call gfx_fill_rect
    mov byte [rect_color], 0
    mov dword [rect_h], 22
    call gfx_fill_rect

    ; Minimize button.
    mov byte [rect_color], 15
    cmp byte [gui_hover], 16
    jne .min_color_ready
    mov byte [rect_color], 7
.min_color_ready:
    mov eax, [gui_window_x]
    add eax, [gui_window_w]
    sub eax, 54
    mov [rect_x], eax
    mov eax, [gui_window_y]
    add eax, 4
    mov [rect_y], eax
    mov dword [rect_w], 14
    mov dword [rect_h], 14
    call gfx_fill_rect
    mov esi, gui_minimize_label
    mov ebx, [rect_x]
    add ebx, 5
    mov ecx, [rect_y]
    add ecx, 7
    mov dl, 0
    call gfx_draw_text

    ; Maximize / restore button.
    mov byte [rect_color], 15
    cmp byte [gui_hover], 15
    jne .max_color_ready
    mov byte [rect_color], 7
.max_color_ready:
    mov eax, [gui_window_x]
    add eax, [gui_window_w]
    sub eax, 36
    mov [rect_x], eax
    mov dword [rect_w], 14
    mov dword [rect_h], 14
    call gfx_fill_rect
    mov esi, gui_maximize_label
    mov ebx, [rect_x]
    add ebx, 5
    mov ecx, [rect_y]
    add ecx, 5
    mov dl, 0
    call gfx_draw_text

    ; Close button.
    mov byte [rect_color], 15
    cmp byte [gui_hover], 8
    jne .close_ready
    mov byte [rect_color], 7
.close_ready:
    mov eax, [gui_window_x]
    add eax, [gui_window_w]
    sub eax, 18
    mov [rect_x], eax
    mov dword [rect_w], 14
    mov dword [rect_h], 14
    call gfx_fill_rect
    mov esi, gui_close_label
    mov ebx, [rect_x]
    add ebx, 5
    mov ecx, [rect_y]
    add ecx, 3
    mov dl, 0
    call gfx_draw_text
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
    mov byte [rect_color], 8
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
    cmp byte [gui_hover], 3
    je .license
    cmp byte [gui_hover], 4
    je .system
    cmp byte [gui_hover], 5
    je .commands
    cmp byte [gui_hover], 6
    je .notes
    jmp .credits

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
    jmp .footer

.system:
    mov esi, gui_system_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_system_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_system_line3
    mov ecx, 74
    call gfx_draw_text
    jmp .footer

.commands:
    mov esi, gui_commands_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_commands_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_commands_line3
    mov ecx, 74
    call gfx_draw_text
    jmp .footer

.notes:
    mov esi, gui_notes_label
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    cmp byte [gui_note_len], 0
    jne .note_content
    mov esi, gui_notepad_empty
    mov dl, 8
    jmp .draw_note_content
.note_content:
    mov esi, gui_note_buffer
    mov dl, 0
.draw_note_content:
    mov ebx, 24
    mov ecx, 68
    call gfx_draw_text
    jmp .footer

.credits:
    mov esi, gui_credits_line1
    mov ebx, 24
    mov ecx, 50
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_credits_line2
    mov ecx, 62
    call gfx_draw_text
    mov esi, gui_credits_line3
    mov ecx, 74
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

; eax = unsigned value, ebx = x, ecx = y, dl = color
gfx_draw_uint:
    pusha
    mov [gfx_number_x], ebx
    mov [gfx_number_y], ecx
    mov [text_color], dl
    mov edi, gfx_number_buffer + 10
    mov byte [edi], 0
    dec edi
    cmp eax, 0
    jne .convert
    mov byte [edi], '0'
    jmp .draw
.convert:
    mov ebp, 10
.next_digit:
    xor edx, edx
    div ebp
    add dl, '0'
    mov [edi], dl
    dec edi
    test eax, eax
    jnz .next_digit
    inc edi
.draw:
    mov esi, edi
    mov ebx, [gfx_number_x]
    mov ecx, [gfx_number_y]
    mov dl, [text_color]
    call gfx_draw_text
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

