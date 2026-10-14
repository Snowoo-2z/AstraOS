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
    call gui_activate_hover
    jmp .gui_loop

.handle_key:
    call lower_char
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
    cmp al, '4'
    ja .gui_loop
    sub al, '1'
    mov [gui_hover], al
    call gui_open_hovered_file
    jmp .gui_loop

.open_explorer:
    mov byte [gui_window_open], GUI_WINDOW_FILES
    jmp .gui_loop

.close_window:
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

gui_activate_hover:
    pusha
    cmp byte [gui_hover], GUI_HOVER_NONE
    je .done

    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .desktop
    cmp byte [gui_window_open], GUI_WINDOW_FILES
    je .files
    cmp byte [gui_window_open], GUI_WINDOW_ABOUT
    je .about
    jmp .done

.desktop:
    cmp byte [gui_hover], 1
    je .open_about
    ; FILES icon and ASTRA taskbar button both open the explorer.
    cmp byte [gui_hover], 0
    je .open_files
    cmp byte [gui_hover], 2
    je .open_files
    jmp .done

.files:
    cmp byte [gui_hover], 4
    je .close
    cmp byte [gui_hover], 4
    jae .done
    call gui_open_hovered_file
    jmp .done

.about:
    cmp byte [gui_hover], 4
    je .close
    jmp .done

.open_files:
    mov byte [gui_window_open], GUI_WINDOW_FILES
    jmp .done
.open_about:
    mov byte [gui_window_open], GUI_WINDOW_ABOUT
    jmp .done
.close:
    mov byte [gui_window_open], GUI_WINDOW_NONE
.done:
    popa
    ret

gui_update_hover:
    pusha
    mov byte [gui_hover], GUI_HOVER_NONE

    cmp byte [gui_window_open], GUI_WINDOW_NONE
    je .desktop

    ; Every window has a close button in the same place.
    mov eax, [mouse_y]
    cmp eax, 20
    jb .window_content
    cmp eax, 38
    ja .window_content
    mov eax, [mouse_x]
    cmp eax, 288
    jb .window_content
    cmp eax, 306
    ja .window_content
    mov byte [gui_hover], 4
    jmp .done

.window_content:
    cmp byte [gui_window_open], GUI_WINDOW_FILES
    jne .done
    mov eax, [mouse_y]
    cmp eax, 54
    jb .done
    cmp eax, 126
    ja .done
    mov eax, [mouse_x]
    cmp eax, 80
    jb .done
    cmp eax, 132
    jbe .file0
    cmp eax, 136
    jb .done
    cmp eax, 188
    jbe .file1
    cmp eax, 192
    jb .done
    cmp eax, 244
    jbe .file2
    cmp eax, 248
    jb .done
    cmp eax, 304
    ja .done
    mov byte [gui_hover], 3
    jmp .done
.file0:
    mov byte [gui_hover], 0
    jmp .done
.file1:
    mov byte [gui_hover], 1
    jmp .done
.file2:
    mov byte [gui_hover], 2
    jmp .done

.desktop:
    mov eax, [mouse_y]
    cmp eax, 30
    jb .taskbar
    cmp eax, 90
    ja .desktop_about
    mov eax, [mouse_x]
    cmp eax, 10
    jb .done
    cmp eax, 68
    ja .done
    mov byte [gui_hover], 0
    jmp .done

.desktop_about:
    mov eax, [mouse_y]
    cmp eax, 98
    jb .taskbar
    cmp eax, 158
    ja .taskbar
    mov eax, [mouse_x]
    cmp eax, 10
    jb .done
    cmp eax, 68
    ja .done
    mov byte [gui_hover], 1
    jmp .done

.taskbar:
    mov eax, [mouse_y]
    cmp eax, 179
    jb .done
    mov eax, [mouse_x]
    cmp eax, 4
    jb .done
    cmp eax, 66
    ja .done
    mov byte [gui_hover], 2
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

    call gui_draw_taskbar

    cmp byte [gui_window_open], GUI_WINDOW_FILES
    je .files
    cmp byte [gui_window_open], GUI_WINDOW_ABOUT
    je .about
    jmp .finish
.files:
    call gui_draw_files_window
    jmp .finish
.about:
    call gui_draw_about_window

.finish:
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
    cmp byte [gui_window_open], GUI_WINDOW_NONE
    jne .button_ready
    cmp byte [gui_hover], 2
    jne .button_ready
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

    mov esi, gui_task_status
    mov ebx, 265
    mov ecx, 186
    mov dl, 15
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
    mov ebx, 82
    mov ecx, 26
    mov dl, 15
    call gfx_draw_text

    mov al, 0
    mov ebx, 84
    mov ecx, 66
    mov esi, gui_readme_label
    call gfx_draw_file_icon
    mov al, 1
    mov ebx, 140
    mov ecx, 66
    mov esi, gui_roadmap_label
    call gfx_draw_file_icon
    mov al, 2
    mov ebx, 196
    mov ecx, 66
    mov esi, gui_ai_label
    call gfx_draw_file_icon
    mov al, 3
    mov ebx, 252
    mov ecx, 66
    mov esi, gui_license_label
    call gfx_draw_file_icon

    mov esi, gui_files_status
    mov ebx, 84
    mov ecx, 146
    mov dl, 8
    call gfx_draw_text
    popa
    ret

gui_draw_about_window:
    pusha
    call gui_draw_window_frame

    mov esi, gui_about_title
    mov ebx, 82
    mov ecx, 26
    mov dl, 15
    call gfx_draw_text

    mov esi, gui_about_line1
    mov ebx, 88
    mov ecx, 58
    mov dl, 0
    call gfx_draw_text
    mov esi, gui_about_line2
    mov ecx, 74
    call gfx_draw_text
    mov esi, gui_about_line3
    mov ecx, 90
    call gfx_draw_text
    mov esi, gui_about_line4
    mov ecx, 106
    call gfx_draw_text
    mov esi, gui_about_hint
    mov ecx, 140
    mov dl, 8
    call gfx_draw_text
    popa
    ret

gui_draw_window_frame:
    pusha
    ; Shadow.
    mov byte [rect_color], 8
    mov dword [rect_x], 75
    mov dword [rect_y], 23
    mov dword [rect_w], 237
    mov dword [rect_h], 149
    call gfx_fill_rect

    ; White client area and black title bar.
    mov byte [rect_color], 15
    mov dword [rect_x], 70
    mov dword [rect_y], 18
    mov dword [rect_w], 238
    mov dword [rect_h], 150
    call gfx_fill_rect
    mov byte [rect_color], 0
    mov dword [rect_x], 70
    mov dword [rect_y], 18
    mov dword [rect_w], 238
    mov dword [rect_h], 22
    call gfx_fill_rect

    ; Close button.
    mov byte [rect_color], 15
    cmp byte [gui_hover], 4
    jne .close_ready
    mov byte [rect_color], 7
.close_ready:
    mov dword [rect_x], 290
    mov dword [rect_y], 22
    mov dword [rect_w], 14
    mov dword [rect_h], 14
    call gfx_fill_rect
    mov esi, gui_close_label
    mov ebx, 295
    mov ecx, 25
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

