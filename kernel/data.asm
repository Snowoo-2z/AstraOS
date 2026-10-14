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
mouse_x dd 160
mouse_y dd 100
paging_enabled dd 0
heap_next dd HEAP_START
temp_value dd 0
mmap_index dd 0
mmap_remaining dd 0
mmap_ptr dd 0
gfx_target dd GUI_BACKBUFFER
gui_last_clock_tick dd 0
gui_cursor_prev_x dd 160
gui_cursor_prev_y dd 100
gui_cursor_draw_x dd 160
gui_cursor_draw_y dd 100
gui_window_x dd 70
gui_window_y dd 18
gui_window_w dd 238
gui_window_h dd 150
gui_restore_x dd 70
gui_restore_y dd 18
gui_drag_offset_x dd 0
gui_drag_offset_y dd 0
gfx_number_x dd 0
gfx_number_y dd 0
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
vmmouse_enabled db 0
vmmouse_read_budget db 0
gui_hover db GUI_HOVER_NONE
gui_previous_hover db GUI_HOVER_NONE
gui_window_open db GUI_WINDOW_NONE
gui_menu_open db 0
gui_window_dragging db 0
gui_window_maximized db 0
gui_minimized_window db GUI_WINDOW_NONE
gui_note_len db 0
gui_terminal_len db 0
gui_terminal_output db 0
rtc_hour db 0
rtc_minute db 0
rtc_status_b db 0
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
gfx_number_buffer times 11 db 0
gui_note_buffer times GUI_NOTE_MAX + 1 db 0
gui_terminal_buffer times GUI_TERMINAL_MAX + 1 db 0
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
    db ' AstraOS 0.4.0 Desktop', 10
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

version_text db 'AstraOS 0.4.0 Desktop - kernel32', 10, 10, 0

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
cat_usage_text db 'Usage: cat readme|roadmap|ai|license|system|commands|notes|credits', 10, 10, 0
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
mouse_mode_text db '  mode    : ', 0
mouse_absolute_text db 'absolute VMMouse (host synchronized)', 0
mouse_relative_text db 'relative PS/2 fallback', 0
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

gui_desktop_brand db 'ASTRA OS', 0
gui_desktop_tagline db 'LIGHT. LOCAL. YOURS.', 0
gui_splash_loading db 'LOADING DESKTOP', 0
gui_files_label db 'FILES', 0
gui_about_label db 'ABOUT', 0
gui_terminal_label db 'TERMINAL', 0
gui_start_label db 'ASTRA', 0
gui_clock_text db '00:00', 0
gui_menu_title db 'ASTRA MENU', 0
gui_menu_files db 'FILES', 0
gui_menu_terminal db 'TERMINAL', 0
gui_menu_system db 'SYSTEM', 0
gui_menu_notes db 'NOTEPAD', 0
gui_menu_about db 'ABOUT', 0
gui_menu_reboot db 'REBOOT', 0
gui_window_title_text db 'FILES', 0
gui_files_status db '8 RAM FILES', 0
gui_close_label db 'X', 0
gui_maximize_label db '*', 0
gui_minimize_label db '-', 0
gui_about_title db 'ABOUT ASTRAOS', 0
gui_about_logo db 'A', 0
gui_about_line1 db 'ASTRAOS 0.4.0 DESKTOP', 0
gui_about_line2 db '32 BIT X86 FROM SCRATCH', 0
gui_about_line3 db 'BLACK WHITE AND LIGHT', 0
gui_about_line4 db 'OPEN SOURCE MIT', 0
gui_about_hint db 'ESC OR X TO CLOSE', 0
gui_system_title db 'SYSTEM MONITOR', 0
gui_system_uptime db 'UPTIME SECONDS', 0
gui_system_ticks db 'TIMER TICKS', 0
gui_system_keyboard db 'KEYBOARD IRQS', 0
gui_system_mouse db 'MOUSE PACKETS', 0
gui_system_heap db 'HEAP USED BYTES', 0
gui_notepad_title db 'NOTEPAD', 0
gui_notepad_hint db 'TYPE  BACKSPACE  ESC CLOSE', 0
gui_notepad_empty db 'START TYPING...', 0
gui_terminal_title db 'ASTRA TERMINAL', 0
gui_terminal_prompt db 'ASTRA>', 0
gui_terminal_welcome1 db 'ASTRA TERMINAL READY', 0
gui_terminal_welcome2 db 'TYPE HELP FOR COMMANDS', 0
gui_terminal_help1 db 'HELP VERSION UPTIME LS', 0
gui_terminal_help2 db 'MEM ABOUT CLEAR REBOOT', 0
gui_terminal_version db 'ASTRAOS 0.4.0 DESKTOP', 0
gui_terminal_files1 db 'README ROADMAP AI LICENSE', 0
gui_terminal_files2 db 'SYSTEM COMMANDS NOTES CREDITS', 0
gui_terminal_about1 db 'A TINY X86 OS FROM SCRATCH', 0
gui_terminal_about2 db 'AURORA DESKTOP 32 BIT', 0
gui_terminal_uptime db 'UPTIME SECONDS', 0
gui_terminal_heap db 'HEAP USED BYTES', 0
gui_terminal_unknown db 'UNKNOWN COMMAND', 0
gui_terminal_hint db 'ENTER RUNS  ESC CLOSES', 0
gui_viewer_title db 'FILE VIEWER', 0
gui_viewer_footer db 'CLICK OR ENTER BACK  Q REBOOT', 0
gui_readme_label db 'README', 0
gui_roadmap_label db 'ROADMAP', 0
gui_ai_label db 'AI', 0
gui_license_label db 'LICENSE', 0
gui_system_label db 'SYSTEM', 0
gui_commands_label db 'COMMANDS', 0
gui_notes_label db 'NOTES', 0
gui_credits_label db 'CREDITS', 0
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
gui_system_line1 db 'ASTRAOS 0.4.0 DESKTOP', 0
gui_system_line2 db '32 BIT X86 KERNEL', 0
gui_system_line3 db 'VMMOUSE AND VGA ONLINE', 0
gui_commands_line1 db 'DESKTOP EXPLORER STATUS', 0
gui_commands_line2 db 'MEM CPU IRQ MOUSE AI', 0
gui_commands_line3 db 'HELP SHOWS EVERY COMMAND', 0
gui_credits_line1 db 'CREATED BY SNW', 0
gui_credits_line2 db 'NASM MAKE AND QEMU', 0
gui_credits_line3 db 'OPEN SOURCE MIT', 0

gui_palette:
    db 2,3,5       ; 0  background
    db 5,7,11      ; 1  surface
    db 4,18,34     ; 2  dark accent
    db 8,28,45     ; 3  secondary accent
    db 40,12,15    ; 4  dark danger
    db 28,18,40    ; 5  purple
    db 42,30,10    ; 6  amber
    db 46,49,54    ; 7  card
    db 13,16,22    ; 8  border
    db 25,30,39    ; 9  muted
    db 20,46,32    ; 10 success
    db 18,43,63    ; 11 Astra blue
    db 63,22,27    ; 12 danger
    db 45,34,63    ; 13 violet
    db 63,51,20    ; 14 warning
    db 61,62,63    ; 15 foreground

gui_palette_count equ 16

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
fs_name_system db 'system', 0
fs_name_commands db 'commands', 0
fs_name_notes db 'notes', 0
fs_name_credits db 'credits', 0
fs_list_text:
    db 'RAM files:', 10
    db '  readme', 10
    db '  roadmap', 10
    db '  ai', 10
    db '  license', 10
    db '  system', 10
    db '  commands', 10
    db '  notes', 10
    db '  credits', 10, 10, 0
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
fs_system_text:
    db 'system:', 10
    db '  AstraOS 0.4.0 Desktop, x86 protected mode, 32-bit kernel.', 10
    db '  VGA desktop, absolute mouse, paging, E820 and 100 Hz timer.', 10, 10, 0
fs_commands_text:
    db 'commands:', 10
    db '  desktop explorer ls cat mouse mem cpu irq status ai reboot', 10
    db '  Type help in the shell for the complete command list.', 10, 10, 0
fs_notes_header db 'notes:', 10, 0
fs_notes_empty db '  Empty. Open NOTEPAD on the desktop to write a RAM note.', 10, 10, 0
fs_credits_text:
    db 'credits:', 10
    db '  AstraOS is an open-source learning OS created by Snw.', 10
    db '  Built from scratch with NASM, Make and QEMU.', 10, 10, 0

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
