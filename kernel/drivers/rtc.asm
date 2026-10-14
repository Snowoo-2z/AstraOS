; ------------------------------------------------------------
; CMOS real-time clock
; ------------------------------------------------------------
rtc_read_time:
    pusha

.wait_update:
    mov al, 0x0A
    out 0x70, al
    in al, 0x71
    test al, 0x80
    jnz .wait_update

    mov al, 0x02            ; minutes
    call rtc_read_register
    mov [rtc_minute], al

    mov al, 0x04            ; hours
    call rtc_read_register
    mov [rtc_hour], al

    mov al, 0x0B            ; status B: binary/BCD and 12/24 hour mode
    call rtc_read_register
    mov [rtc_status_b], al

    test al, 0x04           ; bit 2: values are already binary
    jnz .hour_mode

    mov al, [rtc_minute]
    call rtc_bcd_to_binary
    mov [rtc_minute], al

    mov al, [rtc_hour]
    mov ah, al
    and al, 0x7F
    call rtc_bcd_to_binary
    test ah, 0x80           ; keep PM flag from 12-hour BCD mode
    jz .store_hour
    or al, 0x80
.store_hour:
    mov [rtc_hour], al

.hour_mode:
    test byte [rtc_status_b], 0x02
    jnz .format_text        ; already 24-hour

    mov al, [rtc_hour]
    mov ah, al
    and al, 0x7F
    cmp al, 12
    jne .not_twelve
    xor al, al              ; 12 AM -> 00
.not_twelve:
    test ah, 0x80
    jz .hour_ready
    add al, 12
.hour_ready:
    mov [rtc_hour], al

.format_text:
    movzx eax, byte [rtc_hour]
    xor edx, edx
    mov ebx, 10
    div ebx
    add al, '0'
    add dl, '0'
    mov [gui_clock_text], al
    mov [gui_clock_text + 1], dl

    movzx eax, byte [rtc_minute]
    xor edx, edx
    mov ebx, 10
    div ebx
    add al, '0'
    add dl, '0'
    mov [gui_clock_text + 3], al
    mov [gui_clock_text + 4], dl
    popa
    ret

; al = CMOS register, returns al = value
rtc_read_register:
    out 0x70, al
    in al, 0x71
    ret

; al = packed BCD, returns binary
rtc_bcd_to_binary:
    push ebx
    xor ebx, ebx
    mov bl, al
    and al, 0x0F
    and bl, 0xF0
    shr bl, 4
    imul ebx, ebx, 10
    add al, bl
    pop ebx
    ret
