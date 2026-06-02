; ============================================================
; BERLIN EDITOR v3.0 - 5 строк, с сохранением
; ============================================================
use16
org 0x100

ROWS equ 5

start:
    ; Сохраняем сегменты программы
    mov [prog_seg], ds
    mov [prog_es], es

    call vga_init
    call clear_buffer
    call vga_clear
    call draw_top_frame
    call draw_bottom_frame

    mov dl, 0
    mov dh, 2
    call vga_set_pos
    call update_cursor

main_loop:
    mov ah, 0x00
    int 0x16

    cmp ah, 0x3C        ; F2 - выход
    je exit_program

    cmp ah, 0x3B        ; F1 - сохранить
    je save_file

    cmp al, 0x0D
    je new_line

    cmp al, 0x08
    je backspace

    cmp ah, 0x4B
    je cursor_left

    cmp ah, 0x4D
    je cursor_right

    cmp ah, 0x48
    je cursor_up

    cmp ah, 0x50
    je cursor_down

    cmp al, 0x20
    jb main_loop

    call put_char
    call update_cursor
    jmp main_loop
; ============================================================
; F1 - СОХРАНИТЬ ФАЙЛ (ТУПО 400 БАЙТ)
; ============================================================
save_file:
    ; Запрашиваем имя файла
    call clear_status
    mov dh, 24
    mov dl, 2
    call vga_set_pos
    mov si, msg_save
    call print_status_text

    mov di, file_name
    mov cx, 0

.input_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D
    je .do_save

    cmp al, 0x08
    je .backspace

    cmp cx, 8
    je .input_loop

    stosb
    inc cx

    push ax
    mov ah, 0x17
    call vga_print_status
    pop ax
    jmp .input_loop

.backspace:
    cmp cx, 0
    je .input_loop

    dec di
    dec cx
    mov byte [di], ' '

    push ax
    push dx
    call get_cursor_xy_status
    dec dl
    call vga_set_pos
    mov al, ' '
    mov ah, 0x17
    call vga_print_status
    call vga_set_pos
    pop dx
    pop ax
    jmp .input_loop

.do_save:
    ; Добавляем .TXT
    mov al, '.'
    stosb
    mov si, ext_txt
    mov cx, 3
.ext_loop:
    lodsb
    stosb
    loop .ext_loop
    mov al, 0
    stosb

    ; === СОХРАНЯЕМ ===
    mov ds, [prog_seg]
    mov es, [prog_es]

    ; Создаём файл
    mov ah, 0x3C
    mov cx, 0
    mov dx, file_name
    int 0x21
    jc .error

    ; Записываем 400 байт
    mov ds, [prog_seg]
    mov ah, 0x40
    mov bx, 1
    mov dx, text_buffer
    mov cx, 80 * 10    ; 400
    int 0x21
    jc .error

    ; Закрываем
    mov ah, 0x3E
    int 0x21

    call clear_status
    mov dh, 24
    mov dl, 2
    call vga_set_pos
    mov si, msg_saved
    call print_status_text
    jmp .wait

.error:
    call clear_status
    mov dh, 24
    mov dl, 2
    call vga_set_pos
    mov si, msg_error
    call print_status_text

.wait:
    mov ah, 0x00
    int 0x16

    call clear_status
    mov dh, 24
    mov dl, 2
    call vga_set_pos
    mov si, status_text
    call print_status_text
    jmp start
; ============================================================
; ПОСТРОИТЬ ДАННЫЕ ДЛЯ СОХРАНЕНИЯ
; ============================================================
build_save_data:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    push cs
    pop ds
    push cs
    pop es

    mov si, text_buffer
    mov di, save_buffer
    mov word [save_size], 0

    mov cx, ROWS

.row_loop:
    push cx

    ; Копируем 80 символов строки
    mov cx, 80
    rep movsb
    add word [save_size], 80

    ; Добавляем CR+LF
    mov al, 0x0D
    stosb
    mov al, 0x0A
    stosb
    add word [save_size], 2

    pop cx
    loop .row_loop

    ; Убираем последний CRLF
    sub di, 2
    sub word [save_size], 2

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

tmp_si: dw 0   ; временное хранение SI

; ============================================================
; ЗАПИСЬ СИМВОЛА В БУФЕР И НА ЭКРАН
; ============================================================
put_char:
    push ax
    push bx
    push es
    push di

    ; Проверяем границы (только 5 строк)
    call get_cursor_xy
    cmp dh, 2+ROWS-1
    ja .done

    mov bx, [vga_offset]
    shr bx, 1
    mov [text_buffer + bx], al

    mov ah, [fon_color]
    mov es, [vga_seg]
    mov di, [vga_offset]
    stosw
    mov [vga_offset], di

.done:
    pop di
    pop es
    pop bx
    pop ax
    ret

; ============================================================
; ОЧИСТКА БУФЕРА
; ============================================================
clear_buffer:
    push ax
    push cx
    push es
    push di

    push cs
    pop es
    mov di, text_buffer
    mov cx, 80 * ROWS
    mov al, ' '
    rep stosb

    pop di
    pop es
    pop cx
    pop ax
    ret

; ============================================================
; УПРАВЛЕНИЕ КУРСОРОМ
; ============================================================
cursor_left:
    call get_cursor_xy
    cmp dl, 0
    je .done
    dec dl
    call vga_set_pos
.done:
    call update_cursor
    jmp main_loop

cursor_right:
    call get_cursor_xy
    cmp dl, 79
    je .done
    inc dl
    call vga_set_pos
.done:
    call update_cursor
    jmp main_loop

cursor_up:
    call get_cursor_xy
    cmp dh, 2
    je .done
    dec dh
    call vga_set_pos
.done:
    call update_cursor
    jmp main_loop

cursor_down:
    call get_cursor_xy
    cmp dh, 2+ROWS-1
    je .done
    inc dh
    call vga_set_pos
.done:
    call update_cursor
    jmp main_loop

update_cursor:
    push ax
    push bx
    push dx
    call get_cursor_xy
    mov ah, 0x02
    mov bh, 0
    int 0x10
    pop dx
    pop bx
    pop ax
    ret

get_cursor_xy:
    push ax
    mov ax, [vga_offset]
    shr ax, 1
    mov dl, 80
    div dl
    mov dh, al
    mov dl, ah
    pop ax
    ret

; ============================================================
; НОВАЯ СТРОКА
; ============================================================
new_line:
    call get_cursor_xy
    cmp dh, 2+ROWS-1
    je .done
    inc dh
    mov dl, 0
    call vga_set_pos
    call update_cursor
.done:
    jmp main_loop

; ============================================================
; BACKSPACE
; ============================================================
backspace:
    call get_cursor_xy
    cmp dl, 0
    je .prev_line

    dec dl
    call vga_set_pos

    mov bx, [vga_offset]
    shr bx, 1
    mov byte [text_buffer + bx], ' '

    push es
    push di
    mov es, [vga_seg]
    mov di, [vga_offset]
    mov ax, 0x0720
    stosw
    pop di
    pop es

    call update_cursor
    jmp main_loop

.prev_line:
    cmp dh, 2
    je .done
    dec dh
    mov dl, 79
    call vga_set_pos
    call update_cursor
.done:
    jmp main_loop

; ============================================================
; РАМКИ
; ============================================================
draw_top_frame:
    pusha
    mov dh, 1
    mov dl, 0
    call vga_set_pos
    mov cx, 80
.top:
    mov al, '='
    call vga_print
    loop .top
    popa
    ret

draw_bottom_frame:
    pusha
    mov dh, 2+ROWS
    mov dl, 0
    call vga_set_pos
    mov cx, 80
.bottom:
    mov al, '='
    call vga_print
    loop .bottom

    mov dh, 24
    mov dl, 0
    call vga_set_pos
    mov byte [fon_color], 0x17
    mov cx, 80
.status:
    mov al, ' '
    call vga_print
    loop .status

    mov dh, 24
    mov dl, 2
    call vga_set_pos
    mov si, status_text
    call print_status_text
    mov byte [fon_color], 0x07
    popa
    ret

; ============================================================
; СТАТУС-БАР
; ============================================================
vga_print_status:
    push ax
    push es
    push di
    mov byte [fon_color], 0x17
    mov es, [vga_seg]
    mov di, [vga_offset]
    stosw
    mov [vga_offset], di
    mov byte [fon_color], 0x07
    pop di
    pop es
    pop ax
    ret

print_status_text:
    push ax
    mov ah, 0x17
.loop:
    lodsb
    test al, al
    jz .done
    call vga_print_status
    jmp .loop
.done:
    pop ax
    ret

clear_status:
    push ax
    push es
    push di
    push cx
    mov es, [vga_seg]
    mov di, 160*24
    mov cx, 80
    mov ax, 0x1720
    rep stosw
    pop cx
    pop di
    pop es
    pop ax
    ret

get_cursor_xy_status:
    push ax
    mov ax, [vga_offset]
    shr ax, 1
    mov dl, 80
    div dl
    mov dh, al
    mov dl, ah
    pop ax
    ret

; ============================================================
; VGA
; ============================================================
vga_print:
    push ax
    push es
    push di
    mov ah, [fon_color]
    mov es, [vga_seg]
    mov di, [vga_offset]
    stosw
    mov [vga_offset], di
    pop di
    pop es
    pop ax
    ret

vga_set_pos:
    push ax
    push bx
    push dx
    movzx bx, dh
    movzx ax, dl
    push ax
    mov ax, 80
    mul bx
    pop bx
    add ax, bx
    shl ax, 1
    mov [vga_offset], ax
    pop dx
    pop bx
    pop ax
    ret

vga_init:
    push ax
    mov ax, 0x0003
    int 0x10
    mov ax, 0xB800
    mov [vga_seg], ax
    pop ax
    ret

vga_clear:
    push ax
    push es
    push di
    push cx
    mov es, [vga_seg]
    xor di, di
    mov cx, 80*25
    mov ax, 0x0720
    rep stosw
    pop cx
    pop di
    pop es
    pop ax
    ret

clear_full:
    push ax
    push es
    push di
    push cx
    mov es, [vga_seg]
    xor di, di
    mov cx, 80*25
    mov ax, 0x0720
    rep stosw
    pop cx
    pop di
    pop es
    pop ax
    ret

; ============================================================
; ВЫХОД
; ============================================================
exit_program:
    call clear_full
    ret

; ============================================================
; ДАННЫЕ
; ============================================================
vga_seg:     dw 0xB800
vga_offset:  dw 0
fon_color:   db 0x07
prog_seg:    dw 0
prog_es:     dw 0

status_text: db 'F1=Save F2=Exit ', 24, '=Up ', 25, '=Down ', 26, '=Right ', 27, '=Left', 0
msg_save:    db 'Save as: ', 0
msg_saved:   db 'Saved! Press any key...', 0
msg_error:   db 'Error! Press any key...', 0
ext_txt:     db 'TXT'
file_name:   times 13 db 0

text_buffer: times 80*ROWS db ' '
save_buffer: times 512 db 0
save_size:   dw 0
