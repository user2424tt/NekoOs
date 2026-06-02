use16
org 0x100

start:
    call clear_screen
    call draw_frame

    ; Начальные параметры
    mov byte [ball_x], 40
    mov byte [ball_y], 4
    mov byte [ball_dx], 1
    mov byte [ball_dy], 1
    mov byte [paddle_x], 35
    mov byte [paddle_y], 23
    mov byte [score], 0
    mov byte [game_over], 0

game_loop:
    cmp byte [game_over], 1
    je show_game_over

    ; Проверка клавиш (не блокирующая)
    mov ah, 0x01
    int 0x16
    jz no_key

    mov ah, 0x00
    int 0x16

    ; F2 - выход
    cmp ah, 0x3C
    je exit_prog

    ; Стрелка влево
    cmp ah, 0x4B
    je move_left

    ; Стрелка вправо
    cmp ah, 0x4D
    je move_right

no_key:
    ; Двигаем мяч
    call move_ball

    ; Проверка столкновений
    call check_collision

    ; Рисуем всё
    call draw_all

    ; Задержка
    call delay

    cmp byte [game_over], 1
    je game_loop

    jmp game_loop

move_left:
    cmp byte [paddle_x], 2
    je game_loop
    dec byte [paddle_x]
    jmp game_loop

move_right:
    cmp byte [paddle_x], 71
    je game_loop
    inc byte [paddle_x]
    jmp game_loop

; ============================================================
; ДВИЖЕНИЕ МЯЧА
; ============================================================
move_ball:
    ; Обновляем X
    mov al, [ball_dx]
    add [ball_x], al

    ; Обновляем Y
    mov al, [ball_dy]
    add [ball_y], al
    ret
; ============================================================
; ЗВУК БИП
; ============================================================
beep:
    push ax
    push cx

    in al, 0x61           ; Получить состояние динамика
    push ax                ; Сохранить исходное состояние
    or al, 00000011b      ; Установить два младших бита
    out 0x61, al          ; Включить динамик

    mov al, 0xB6          ; Настроить таймер
    out 0x43, al

    mov al, 100           ; Высота звука (частота)
    out 0x42, al          ; Младший байт частоты
    mov al, 5              ; Старший байт частоты (5*256+100 = 1380)
    out 0x42, al

    mov cx, 100            ; Длительность (внешний цикл)

.zvuk:
    push cx
    mov cx, 1000           ; Внутренний цикл задержки
.cicle:
    loop .cicle
    pop cx
    loop .zvuk

    pop ax                 ; Получить исходное состояние
    and al, 11111100b     ; Сбросить два младших бита
    out 0x61, al          ; Выключить динамик

    pop cx
    pop ax
    ret
check_collision:
    ; Стены слева/справа
    cmp byte [ball_x], 2
    jg .check_right
    mov byte [ball_dx], 1
    call beep           ; ← ЗВУК
    jmp .check_top

.check_right:
    cmp byte [ball_x], 77
    jl .check_top
    mov byte [ball_dx], -1
    call beep           ; ← ЗВУК

.check_top:
    ; Потолок
    cmp byte [ball_y], 2
    jg .check_paddle
    mov byte [ball_dy], 1
    call beep           ; ← ЗВУК

.check_paddle:
    ; Проверяем, на уровне ракетки ли мяч
    cmp byte [ball_y], 22
    jl .check_bottom

    ; Проверяем, попали ли по ракетке
    mov al, [ball_x]
    sub al, [paddle_x]
    cmp al, -1
    jl .miss
    cmp al, 10
    jg .miss

    ; Попали!
    mov byte [ball_dy], -1
    inc byte [score]
    call beep           ; ← ЗВУК (другой тон для ракетки)

    call draw_score
    jmp .done

.miss:
    cmp byte [ball_y], 24
    jl .done
    mov byte [game_over], 1
    call beep           ; ← ЗВУК при проигрыше
    call beep           ; ← двойной БИП
    jmp .done

.check_bottom:
    cmp byte [ball_y], 24
    jl .done
    mov byte [ball_dy], -1
    call beep           ; ← ЗВУК

.done:
    ret
; ============================================================
; НАРИСОВАТЬ ВСЁ
; ============================================================
draw_all:
    push ax
    push bx
    push es
    push di

    mov ax, 0xB800
    mov es, ax

    ; Стираем старый мяч
    call erase_ball

    ; Стираем старую ракетку
    call erase_paddle

    ; Рисуем ракетку
    call draw_paddle

    ; Рисуем мяч
    call draw_ball

    pop di
    pop es
    pop bx
    pop ax
    ret

erase_ball:
    movzx ax, [ball_old_y]
    mov bx, 160
    mul bx
    movzx bx, [ball_old_x]
    shl bx, 1
    add bx, ax

    mov di, bx
    mov ax, 0x0720
    stosw
    ret

erase_paddle:
    movzx ax, [paddle_y]
    mov bx, 160
    mul bx
    movzx bx, [paddle_old_x]
    shl bx, 1
    add bx, ax

    mov di, bx
    mov cx, 10
    mov ax, 0x0720
    rep stosw
    ret

draw_ball:
    movzx ax, [ball_y]
    mov bx, 160
    mul bx
    movzx bx, [ball_x]
    shl bx, 1
    add bx, ax

    mov di, bx
    mov ax, 0x0F30    ; белый '0'
    stosw

    ; Сохраняем позицию
    mov al, [ball_x]
    mov [ball_old_x], al
    mov al, [ball_y]
    mov [ball_old_y], al
    ret

draw_paddle:
    movzx ax, [paddle_y]
    mov bx, 160
    mul bx
    movzx bx, [paddle_x]
    shl bx, 1
    add bx, ax

    mov di, bx
    mov cx, 10
    mov ax, 0x073D    ; серый '='
    rep stosw

    ; Сохраняем позицию
    mov al, [paddle_x]
    mov [paddle_old_x], al
    ret

draw_score:
    push ax
    push es
    push di

    mov ax, 0xB800
    mov es, ax
    mov di, 160 + 34

    mov al, 'S'
    stosw
    mov al, 'c'
    stosw
    mov al, 'o'
    stosw
    mov al, 'r'
    stosw
    mov al, 'e'
    stosw
    mov al, ':'
    stosw
    mov al, ' '
    stosw

    mov al, [score]
    add al, '0'
    stosw

    pop di
    pop es
    pop ax
    ret

; ============================================================
; ПОКАЗАТЬ GAME OVER
; ============================================================
show_game_over:
    call clear_screen

    mov ax, 0xB800
    mov es, ax

    mov di, 160*10 + 30
    mov si, msg_game_over
    call print_to_vram

    mov di, 160*12 + 30
    mov si, msg_score
    call print_to_vram

    mov di, 160*12 + 38
    mov al, [score]
    add al, '0'
    mov ah, 0x07
    stosw

    mov di, 160*14 + 28
    mov si, msg_restart
    call print_to_vram

.wait:
    mov ah, 0x00
    int 0x16

    ; F1 - заново
    cmp ah, 0x3B
    je restart

    ; F2 - выход
    cmp ah, 0x3C
    je exit_prog

    jmp .wait

restart:
    mov byte [ball_x], 40
    mov byte [ball_y], 4
    mov byte [ball_dx], 1
    mov byte [ball_dy], 1
    mov byte [paddle_x], 35
    mov byte [score], 0
    mov byte [game_over], 0

    call clear_screen
    call draw_frame
    jmp game_loop

; ============================================================
; ЗАДЕРЖКА
; ============================================================
delay:
    push ax
    push cx
    push dx

    mov ah, 0x00
    int 0x1A    ; получить время

    add dx, 2   ; задержка ~2 тика (110 мс)
    mov bx, dx

.wait_tick:
    int 0x1A
    cmp dx, bx
    jb .wait_tick

    pop dx
    pop cx
    pop ax
    ret

; ============================================================
; ОЧИСТКА ЭКРАНА
; ============================================================
clear_screen:
    push ax
    push es
    push di
    push cx

    mov ax, 0xB800
    mov es, ax
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
; РАМКА
; ============================================================
draw_frame:
    push ax
    push es
    push di
    push cx

    mov ax, 0xB800
    mov es, ax

    ; Верхняя строка
    mov di, 160
    mov al, 0xC9
    mov ah, 0x07
    stosw
    mov al, 0xCD
    mov cx, 78
.top:
    stosw
    loop .top
    mov al, 0xBB
    stosw

    ; Боковые (строки 2-24)
    mov cx, 23
    mov di, 160*2
.sides:
    mov al, 0xBA
    mov ah, 0x07
    stosw
    add di, 156
    stosw
    add di, 2
    loop .sides

    ; Нижняя строка
    mov di, 160*24
    mov al, 0xC8
    stosw
    mov al, 0xCD
    mov cx, 78
.bottom:
    stosw
    loop .bottom
    mov al, 0xBC
    stosw

    ; Линия над ракеткой
    mov di, 160*22
    mov al, 0xC4
    mov cx, 80
.line:
    stosw
    loop .line

    pop cx
    pop di
    pop es
    pop ax
    ret

; ============================================================
; ВЫВОД НА ВИДЕОПАМЯТЬ
; ============================================================
print_to_vram:
    mov ah, 0x07
.loop:
    lodsb
    test al, al
    jz .done
    stosw
    jmp .loop
.done:
    ret

; ============================================================
; ВЫХОД
; ============================================================
exit_prog:
    mov ax, 0x0003
    int 0x10
    ret

; ============================================================
; ДАННЫЕ
; ============================================================
ball_x:      db 40
ball_y:      db 4
ball_old_x:  db 40
ball_old_y:  db 4
ball_dx:     db 1
ball_dy:     db 1

paddle_x:     db 35
paddle_old_x: db 35
paddle_y:     db 23

score:     db 0
game_over: db 0

msg_game_over: db 'GAME OVER', 0
msg_score:     db 'Score: ', 0
msg_restart:   db 'F1=Restart  F2=Exit', 0
