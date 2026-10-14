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

