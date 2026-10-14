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
    je .desktop

    mov esi, input_buffer
    mov edi, cmd_desktop
    call string_equals
    cmp eax, 1
    je .desktop

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

.desktop:
    call gui_desktop
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

