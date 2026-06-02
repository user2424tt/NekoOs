use16
org 0x100

start:
    ; Очищаем экран
    mov ax, 0x0003
    int 0x10

    ; Запрашиваем имя файла
    mov si, msg_filename
    call print_str
    call input_string
    call new_line

    ; Если пустой ввод - выход
    cmp byte [input_buf], 0
    je exit_prog

    ; Копируем имя файла
    mov si, input_buf
    mov di, filename
    call copy_string

    ; Запрашиваем данные
    mov si, msg_data
    call print_str
    call input_string
    call new_line

    ; Проверяем, есть ли данные
    cmp byte [input_buf], 0
    je create_empty

    ; Создаём файл с данными
    mov ah, 0x3C
    mov cx, 0
    mov dx, filename
    int 0x21
    jc error

    ; Считаем длину данных
    mov si, input_buf
    call strlen
    mov cx, ax

    ; Записываем данные
    mov ah, 0x40
    mov bx, 1
    mov dx, input_buf
    int 0x21
    jc error

    ; Закрываем файл
    mov ah, 0x3E
    int 0x21

    ; Успех
    mov si, msg_ok
    call print_str
    jmp wait_key

create_empty:
    ; Создаём пустой файл
    mov ah, 0x3C
    mov cx, 0
    mov dx, filename
    int 0x21
    jc error

    ; Закрываем
    mov ah, 0x3E
    int 0x21

    mov si, msg_ok
    call print_str
    jmp wait_key

error:
    mov si, msg_error
    call print_str

wait_key:
    call new_line
    mov si, msg_press
    call print_str

    mov ah, 0x00
    int 0x16

exit_prog:
    mov ax, 0x0003
    int 0x10
    ret ; EXIT IBM style

; ============================================================
; ВВОД СТРОКИ
; ============================================================
input_string:
    mov di, input_buf
    xor cx, cx

.input_loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x0D          ; Enter
    je .done

    cmp al, 0x08          ; Backspace
    je .backspace

    cmp cx, 64            ; Максимум 64 символа
    je .input_loop

    stosb
    inc cx

    mov ah, 0x0E
    int 0x10
    jmp .input_loop

.backspace:
    cmp cx, 0
    je .input_loop

    dec di
    dec cx
    mov byte [di], 0

    mov ah, 0x0E
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10
    jmp .input_loop

.done:
    mov byte [di], 0
    ret

; ============================================================
; КОПИРОВАТЬ СТРОКУ
; ============================================================
copy_string:
    push si
    push di
.loop:
    lodsb
    stosb
    test al, al
    jz .done
    jmp .loop
.done:
    pop di
    pop si
    ret

; ============================================================
; ДЛИНА СТРОКИ
; ============================================================
strlen:
    push si
    xor ax, ax
.loop:
    cmp byte [si], 0
    je .done
    inc si
    inc ax
    jmp .loop
.done:
    pop si
    ret

; ============================================================
; ВЫВОД СТРОКИ
; ============================================================
print_str:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

; ============================================================
; НОВАЯ СТРОКА
; ============================================================
new_line:
    push ax
    mov ah, 0x0E
    mov al, 0x0D
    int 0x10
    mov al, 0x0A
    int 0x10
    pop ax
    ret

; ============================================================
; ДАННЫЕ
; ============================================================
msg_filename: db 'File> ', 0
msg_data:     db 'Data (press Enter for empty)> ', 0
msg_ok:       db 'File created!', 0
msg_error:    db 'Error!', 0
msg_press:    db 'Press any key...', 0

input_buf:    times 65 db 0
filename:     times 65 db 0
