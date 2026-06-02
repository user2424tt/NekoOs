use16
 section .text
 org 0x7E00
 use16
section .text

procedur_init:
mov [boot_disk],dl
cmp dl,0
jz set_A_disk
cmp dl,1
jz set_B_disk
        mov di,char_disk
        mov al,'N'
        stosb
initializaition_interput:
cli
;interput 21h
mov di,0x21*4
mov word [di],interput21
mov ax,cs
mov word [di+2],ax
;interput 20h
mov di,0x20*4
mov word [di],interput20
mov ax,cs
mov word [di+2],ax
; Установка пользовательского обработчика таймера (int 1Ch)
setup_timer:

    mov di, 0x1C*4
    mov word [di], timer_handler
    mov ax, cs
    mov word [di+2], ax


    sti
    call init_video_mode
    call clear_screen_color
    call detect_floppy_drives
    jmp BEGIN
    set_A_disk:
        mov di,char_disk
        mov al,'A'
        stosb
        jmp initializaition_interput
    set_B_disk:
        mov di,char_disk
        mov al,'B'
        stosb
        jmp initializaition_interput

; Обработчик таймера (заглушка)
timer_handler:
    ;pusha
    ; Здесь будет твой код таймера
    ; Вызывается ~18.2 раза в секунду
    ;popa
    iret
; Установить скорость системного таймера
; Вход: AX = делитель частоты
;       1193180 / делитель = частота в Гц
set_timer_speed:
    push ax
    mov al, 00110110b    ; Канал 0, младший+старший байт, режим 3, двоичный
    out 43h, al
    pop ax
    out 40h, al          ; Младший байт
    mov al, ah
    out 40h, al          ; Старший байт
    ret
interput20:
xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp,[steck_save]
;call clear_screen_color ;clear scren or no clear scren
jmp go_kernel
int20: int 20h
interput21:
;Переключаем DS на ядро для работы
    push ds
    ; load ds on kernel data.
    push cs
    pop ds
    mov [user_ds], ds        ; Сохраняем DS программы
    mov [user_dx], dx
    mov [user_cx], cx
    mov [user_ax], ax
    pop ds


    ; ES тоже на ядро
    ;push cs
    ;pop es
    ; ... остальные cmp ...
    test ah,ah
    jz end_programm
    cmp ah, 0x01
    jz keyboard_block
    cmp ah, 0x02
    jz print_char_interput
    cmp ah, 0x03
    jz write_com1
    cmp ah, 0x04
    jz read_com1
    cmp ah, 0x06
    jz key_noBlock
    cmp ah, 0x08
    jz keyboard_block
    cmp ah, 0x09
    jz print_string_interput
    ; В interput21:
cmp ah, 0Ah
jz buffered_input

    cmp ah,0x3C
    jz int21_create_file
    cmp ah, 0x3D
    jz int21_open_file
    cmp ah, 0x3E
    jz int21_close_file
    cmp ah, 0x3F
    jz int21_read_file
    cmp ah,40h
    jz int21_write_file
    cmp ah, 0x42
    jz int21_seek_file

    iret
;Interput Function
key_noBlock:
cmp dl,0FFH
jz .read_key
mov ah,0xE
mov al,dl
int 10H
iret
.read_key
mov ah,01H
int 16H
iret
end_programm: ;rewrite ,is interput no stable

    jmp interput20
print_char_interput:
mov ah,0x0E
mov al,dl
int 10h
iret
keyboard_block:
mov ah,0x00
int 0x16
iret
write_com1: ;------------------------------------Не доделана нужна блокирующая функция-------------------------------
mov dx,0x3F8
in al,dx
iret
read_com1:
mov al,dl
mov dx,0x3Fb
out dx,al
iret
print_string_interput:
mov ah, 0x0e; Устанавливаем значение AH для вывода символа
    mov bh,0x00; Страница
    mov si,dx
    string_loop_interput:
        lodsb            ; загружаем очередной символ в al
        cmp al,'$'      ; нулевой символ означает конец строки
        jz  string_loop_interput_exit
        int  0x10        ; вызываем функцию BIOS
        jmp  string_loop_interput
    string_loop_interput_exit:

    iret

buffered_input:
    push ds
    push es

    ; DS:DX = адрес буфера программы
    mov es, [user_ds]
    mov di, [user_dx]

    ; [ES:DI] = максимальная длина (уже установлена)
    mov ah, 0Ch    ; Очистить буфер клавиатуры
    int 21h

    xor cx, cx
.read_loop:
    mov ah, 00h    ; Ждать клавишу
    int 16h

    cmp al, 13     ; Enter?
    je .done
    cmp al, 8      ; Backspace?
    je .backspace

    stosb           ; Сохранить в буфер
    inc cx
    cmp cl, [es:di] ; Достигли максимума?
    jae .done

    mov ah, 0Eh    ; Echo
    int 10h
    jmp .read_loop

.backspace:
    dec cx
    dec di
    mov ah, 0Eh
    mov al, 8
    int 10h
    mov al, ' '
    int 10h
    mov al, 8
    int 10h
    jmp .read_loop

.done:
    mov [es:di+1], cl  ; Фактическая длина

    pop es
    pop ds
    iret

; ============================================================
; АНАЛОГ parse_filename ДЛЯ ПРЕРЫВАНИЙ
; Копирует имя из сегмента программы в fat_name ядра
; Вход: [user_ds]:[user_dx] -> имя файла в программе
; Выход: fat_name заполнено в сегменте ядра
; ============================================================
int21_parse_filename:
    pusha
    push es

    ; Очищаем fat_name в сегменте ядра
    mov di, fat_name
    mov cx, 11
    mov al, ' '
    rep stosb

    ; Копируем имя из сегмента программы [user_ds]:[user_dx] -> ds:fat_name
    mov es, [user_ds]       ; ES = сегмент программы
    mov si, [user_dx]       ; SI = смещение имени в программе
    mov di, fat_name        ; DI = буфер в ядре
    mov cx, 12

.copy_loop:
    mov al, [es:si]         ; Читаем из программы
    mov [di], al            ; Пишем в ядро
    inc si
    inc di
    cmp al, 0
    je .done
    cmp al, ' '
    je .done
    loop .copy_loop
.done:

    pop es
    popa
    ret

; ============================================================
; АНАЛОГ find_file ДЛЯ ПРЕРЫВАНИЙ
; Ищет файл из fat_name в корневом каталоге
; Выход: CF=1 если не найден
;        first_cluster, file_size заполнены
; ============================================================
int21_find_file:
    pusha
    push es

    ; Читаем Root Dir в 0x0500:0x0000
    mov ax, 0x0500
    mov es, ax
    xor bx, bx
    mov ax, 19
    mov cx, 14

.read_root:
    call read_sector
    add bx, 512
    inc ax
    loop .read_root

    ; Ищем файл
    mov ax, 0x0500
    mov es, ax
    xor di, di
    mov cx, 224

.search:
    mov al, [es:di]
    cmp al, 0x00
    je .not_found
    cmp al, 0xE5
    je .next

    ; Сравниваем с fat_name
    push di
    mov si, fat_name
    mov cx, 11
    repe cmpsb
    pop di
    je .found

.next:
    add di, 32
    loop .search

.not_found:
    pop es
    popa
    stc
    ret

.found:
    mov ax, [es:di+26]      ; Первый кластер
    mov [first_cluster], ax
    mov ax, [es:di+28]      ; Размер
    mov [file_size], ax
    pop es
    popa
    clc
    ret
; ============================================================
; INT 21h AH=3Dh - ОТКРЫТЬ ФАЙЛ
; Вход: DS = 0x3000 (сегмент программы)
;       DX = смещение имени файла в программе
;       Al = Open Mod
; Выход: AX = 1 (успех), AX = 2 (файл не найден)
; ============================================================
int21_open_file:
    pusha
    push es
    push ds

    ; 1. ES = CS (ядро) для доступа к буферам ядра
    push cs
    pop es


    ; 2. Копируем имя файла из DS:DX (программа) во временный буфер ядра
    mov si, dx
    mov di, temp_name
    mov cx, 12
.copy_loop:
    lodsb
    stosb
    cmp al, 0
    je .name_done
    loop .copy_loop
.name_done:

    ; 3. Переключаем DS на ядро (сегмент 0x0000)
    mov ax, 0x0000
    mov ds, ax

    ; 4. Парсим имя файла (temp_name → fat_name)
    mov si, temp_name
    call parse_filename

    ; 5. Ищем файл в корневом каталоге
    call find_file
    jc .not_found

    ; 6. Загружаем FAT
    call load_fat

    ; 7. Сохраняем параметры файла в SFT
    mov ax, [first_cluster]
    mov [sft_cluster], ax
    mov ax, [file_size]
    mov [sft_size], ax
    mov word [sft_offset], 0
    mov byte [sft_used], 1

    ; 8. Загружаем файл в буфер 0x7000:0x0000
    mov ax, 0x7000
    mov es, ax
    xor bx, bx

    mov ax, [first_cluster]
    mov [current_cluster], ax

.load_loop:
    cmp word [current_cluster], 0xFF8
    jae .loaded

    mov ax, [current_cluster]
    sub ax, 2
    add ax, 33
    call int_read_sector
    add bx, 512

    mov ax, [current_cluster]
    call get_next_cluster
    mov [current_cluster], ax
    jmp .load_loop

.loaded:

    pop ds
    pop es
    popa
    mov ax, 1
    clc
    iret

.not_found:

    pop ds
    pop es
    popa
    mov ax, 2
    stc
    iret
open_mod: db 0
; ------------------------------------------------------------
; ПОДПРОГРАММЫ
; ------------------------------------------------------------
int_read_sector:
    pusha
    xor dx, dx
    mov cx, 18
    div cx
    inc dl
    mov cl, dl
    xor dx, dx
    mov ch, 2
    div ch
    mov ch, al
    mov dh, ah
    mov dl, [drive_num]
    mov ax, 0x0201
    int 0x13
    popa
    ret

; ------------------------------------------------------------
; ДАННЫЕ
; ------------------------------------------------------------
drive_num:      db 0
cluster:        dw 0
int_file_name:  times 11 db ' '  ; 11 байт, БЕЗ ТОЧКИ!
; ============================================================
; INT 21h / AH = 3Eh - ЗАКРЫТЬ ФАЙЛ
; ============================================================
int21_close_file:
    pusha
    push ds
    push es

    push cs
    pop ds
    push cs
    pop es

    mov byte [sft_used], 0
    mov word [sft_offset], 0

    pop es
    pop ds
    popa
    mov ax, 0
    clc
    iret
;-------------int 21 AH=3CH create file-----------------------
int21_create_file:
push ds
push es
mov si,dx
push bx
mov bx,cx
xor ax,ax
mov es,ax

mov [int_atribut],bl
pop bx
mov di,int21_file_name
.llop:
lodsb
cmp al,'.'
stosb
jz .end_llop
jmp .llop
.end_llop:
mov cx,3
rep movsb
;reload segment
xor ax,ax
mov ds,ax
mov es,ax
;debug name file
;mov si,int21_file_name
;call print_string
;call new_label
mov si,int21_file_name
call parse_filename
;mov si,fat_name
;call print_string
;call new_label
call find_free_entry
jc do_create_disk_full
    call int_fill_entry_buffer

    ; Прямо указываем сектор 19!
    mov ax, 19
    call write_root_sector
    jc do_create_error

    mov si, msg_created
    call print_message
    call new_label
;end interput
mov cx,11
rep stosb
pop es
pop ds
mov ax,1
iret
int21_file_name: times 11 db 0
int_atribut: db 0
int_fill_entry_buffer:
pusha

    mov ax, 0x0500
    mov es, ax
    mov di, [found_offset]

    ; 1. Имя файла (11 байт)
    mov si, fat_name
    mov cx, 11
    rep movsb
    pusha
    mov al,[int_atribut]
    ; 2. Атрибуты (0x20 = архивный)
    mov byte [es:di], al
    popa
    inc di

    ; 3. Резерв (10 байт нулей)
    mov cx, 10
    mov al, 0
    rep stosb

    ; 4. Время создания (0)
    mov word [es:di], 0x0000
    add di, 2

    ; 5. Дата создания (0)
    mov word [es:di], 0x0000
    add di, 2

    ; 6. Первый кластер (0 = пустой файл)
    mov word [es:di], 0x0000
    add di, 2

    ; 7. Размер файла (4 байта = 0)
    mov word [es:di], 0x0000
    add di, 2
    mov word [es:di], 0x0000

    popa
    ret
; ============================================================
; GET_LAST_CLUSTER — находит последний кластер в цепочке
; Вход: AX = первый кластер файла
; Выход: AX = последний кластер (тот что указывает на 0xFF8+)
;        CF=0 успех, CF=1 ошибка
; Портит: AX, CX
; ============================================================
get_last_cluster:
    push bx

    mov cx, ax              ; CX = текущий кластер
    cmp cx, 0xFF8           ; если первый уже EOC?
    jae .is_last

.walk_loop:
    mov ax, cx              ; AX = текущий кластер
    call get_next_cluster   ; AX = следующий

    cmp ax, 0xFF8           ; следующий — конец?
    jae .found_last         ; да → текущий (CX) последний

    cmp ax, 0x002           ; невалидный кластер (< 2)?
    jb .error

    mov cx, ax              ; идём дальше
    jmp .walk_loop

.found_last:
    mov ax, cx              ; возвращаем последний кластер
    clc
    jmp .exit

.is_last:
    mov ax, cx              ; первый и есть последний
    clc
    jmp .exit

.error:
    xor ax, ax
    stc

.exit:
    pop bx
    ret
; ============================================================
; INT 21h AH=40h - WRITE TO FILE (полная версия)
; Вход: DS:DX = адрес данных в программе
;       CX = количество байт для записи
; Выход: AX = количество записанных байт
; ============================================================
;-------------------int 21h Ah=40h Write to file--------------
int21_write_file:
;cmp bx,0 ;write current file
;jz int21_write_new
;cmp bx,1
;jz int21_add_write
;int21_write_new:
push ds
push es
push dx
xor ax,ax
mov ds,ax
mov es,ax
mov [write_count],cx
mov [data_size],cx

.copy_byite:
pop dx
pop es
pop ds
push ds
push es
mov si,dx
push cs
pop ax
mov es,ax
mov di,data_text
rep movsb
mov ax,es
mov ds,ax
;mov si,copy_msg
;call print_string
;mov si,write_page
;call print_string
;call new_label


;mov si,fat_name
;call print_string
;call new_label
call find_free_cluster
jc error_write
mov [data_free_cluster],ax
test ax,ax
jz cluster_zero
;call print_hex_word
;call new_label
call find_file_offset
call fill_entry_in_buffer_write

    ; Прямо указываем сектор 19!
    mov ax, 19
    call write_root_sector
    jc do_create_error

    mov si, msg_created
    call print_message
    call new_label
; rebot segment register
xor ax,ax
mov es,ax
mov ds,ax
; write FAT12
mov ax,[data_free_cluster]
mov bx,0xFF8
call mark_cluster
; Запись данных в кластер 17
mov ax, [data_free_cluster]  ; AX = 17
sub ax, 2                    ; AX = 15
add ax, 33                   ; AX = 48 (LBA сектор)

mov bx, data_text
call write_sector            ; записываем 1 сектор

mov ah,0x0E
mov al, 'O'
    int 0x10
    mov al, 'K'
    int 0x10
jmp int21_clear_write_page

;int21_add_write:

int21_clear_write_page:;-------clear Write Page----
push cs
pop ax
mov ds,ax
mov es,ax
mov cx,512
xor ax,ax
mov di,data_text
rep stosb
xor ax,ax
mov [write_count],ax
pop es
pop ds
iret
write_page times 512 db 0
msg_er_mod db 'Error mod',0
copy_msg db 'Copy: ',0
write_count dw 0
; ============================================================
; INT 21h AH=3Fh - ЧИТАТЬ ИЗ ФАЙЛА
; ============================================================
int21_read_file:
    cld
    push ds
    xor ax,ax
    mov ds,ax

    mov ax,[sft_offset]
    mov si,ax
    mov ax,0x7000
    mov ds,ax
    mov di,dx
    xor ax,ax
    .loop_sb:
    lodsb
    test al,al
    jz .exit_sb
    stosb
    loop .loop_sb
    .exit_sb:
    xor ax,ax
    mov ds,ax
    mov ax,si
    mov [sft_offset],ax
    pop ds
    xor ax,ax
    iret

; ============================================================
; INT 21h / AH = 42h - SEEK
; ============================================================
int21_seek_file:
    pusha
    push ds
    push es

    push cs
    pop ds

    cmp byte [sft_used], 1
    jne .err
    cmp al, 0
    jne .err
    cmp dx, [sft_size]
    ja .err

    mov [sft_offset], dx

    pop es
    pop ds
    popa
    mov ax, dx
    clc
    iret

.err:
    pop es
    pop ds
    popa
    xor ax, ax
    stc
    iret
; ============================================================
; ОТЛАДОЧНАЯ: вывод слова в HEX
; ============================================================
print_hex_word:
    pusha
    push ax

    mov al, ah
    shr al, 4
    call .nibble
    mov al, ah
    and al, 0x0F
    call .nibble

    pop ax
    shr al, 4
    call .nibble
    and al, 0x0F
    call .nibble

    popa
    ret

.nibble:
    cmp al, 10
    jl .digit
    add al, 'A' - 10
    jmp .print
.digit:
    add al, '0'
.print:
    pusha
    mov ah, 0x0E
    int 0x10
    popa
    ret
; -----------------------------------------------------------------------------
; SYSTEM FILE TABLE (SFT)
; -----------------------------------------------------------------------------
user_ds:      dw 0
user_dx:      dw 0
user_cx:      dw 0
user_ax:      dw 0
bytes_read:   dw 0

sft_used:     db 0
sft_cluster:  dw 0
sft_offset:   dw 0
sft_size:     dw 0
temp_name:    times 13 db 0

begin_msg db 'Disk '
char_disk db ' ',':',0

BEGIN:
; Устанавливаем позицию курсора в 23,0
    mov ah, 0x02
    mov bh, 0x00
    mov dh,22
    mov dl,0
    int 0x10
mov si,begin_msg
call print_message
xor ax,ax
mov es,ax
mov di,comand
;---------------shel-----------
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
;low string
; Устанавливаем позицию курсора в 23,0
    mov ah, 0x02
    mov bh, 0x00
    mov dh,23
    mov dl,0
    int 0x10
mov al,'-'
mov cx,80
.loop1
call print_char
loop .loop1
; Строка подсказок в самом низу (строка 24)
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 24
    mov dl, 0
    int 0x10

; Выводим фон строки (чёрный фон, белый текст)
    mov cx, 80
    mov ah, 0x09
    mov al, ' '
    mov bh, 0
    mov bl, 0Fh        ; Чёрный фон (0), белый текст (F)
    int 0x10

; Устанавливаем курсор опять в начало 24 строки
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 0
    int 0x10

; F1 Help
    mov si, f1_text
    call print_string
    mov al, ' '
    call print_char

; F2 User
;    mov si, f2_text
;    call print_string
;    mov al, ' '
    call print_char

; F3 View
;    mov si, f3_text
;    call print_string
;    mov al, ' '
;    call print_char

; F4
;    mov si, f4_text
;    call print_string
;    mov al, ' '
;    call print_char

; F5
;    mov si, f5_text
;    call print_string
;    mov al, ' '
;    call print_char

; F6
;    mov si, f6_text
;    call print_string
;    mov al, ' '
;    call print_char

; F7
;    mov si, f7_text
;    call print_string
;    mov al, ' '
;    call print_char

; F8 Delete
;    mov si, f8_text
;    call print_string

; Версия в правом углу
    mov ah, 0x02
    mov bh, 0
    mov dh, 24
    mov dl, 60
    int 0x10
    mov si, version_text
    call print_string

; Возвращаем курсор в строку ввода (22)
    mov ah, 0x02
    mov bh, 0x00
    mov dh, 22
    mov dl, 9
    int 0x10

    jmp KERNEL

; Данные для подсказок
f1_text: db 'F1=history comand', 0
f2_text: db 'F2=User', 0
f3_text: db 'F3=View', 0
f4_text: db 'F4=Edit', 0
f5_text: db 'F5=Copy', 0
f6_text: db 'F6=Move', 0
f7_text: db 'F7=MkDir', 0
f8_text: db 'F8=Delete', 0
version_text: db 'NekoOS 0.47+', 0
KERNEL:
mov ah,0x00
int 0x16           ; AH = скан-код, AL = ASCII
stosb
cmp al,13
jz comands

cmp ah,48h         ; Стрелка вверх
jz up_arrow
cmp ah,50h         ; Стрелка вниз
jz down_arrow
cmp ah,4Bh         ; Стрелка влево
jz left_arrow
cmp ah,4Dh         ; Стрелка вправо
jz right_arrow
cmp ah,0x3B
jz print_history
mov ah,0x0E
int 10h
cmp al,0x8
jz BackSpace
jmp KERNEL
new_label:
mov ah,0x0E
mov al,0Ah
int 10h
mov ah,0x0E
mov al,0Dh
int 10h
ret
; ============================================================
; Smart_print — умный цветной вывод строки
; Вход: SI = адрес строки
;       DH = цвет текста (0-F), если >F то белый (F)
;       DL = цвет фона (0-7), если >7 то чёрный (0)
;       CX = количество байт для печати (0 = печатать до нуля)
; ============================================================
smart_print:
    pusha

    ; Проверяем цвет текста
    cmp dh, 0Fh
    jbe .text_ok
    mov dh, 0Fh        ; Белый по умолчанию
.text_ok:

    ; Проверяем цвет фона
    cmp dl, 07h
    jbe .bg_ok
    mov dl, 00h        ; Чёрный по умолчанию
.bg_ok:

    ; Формируем атрибут: фон в старших 4 битах, текст в младших
    mov bh, dl
    shl bh, 4
    or bh, dh           ; BH = атрибут

    ; Проверяем CX
    cmp cx, 0
    je .print_until_zero

    ; CX != 0 — печатаем ровно CX символов
    mov ah, 0x09
    mov bl, bh
    mov bh, 0
.print_loop:
    lodsb
    push cx
    mov cx, 1
    int 0x10
    ; Двигаем курсор
    mov ah, 0x03
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop cx
    loop .print_loop
    jmp .done

    ; CX = 0 — печатаем пока не встретим 0
.print_until_zero:
    mov ah, 0x09
    mov bl, bh
    mov bh, 0
.zero_loop:
    lodsb
    test al, al
    jz .done
    push cx
    mov cx, 1
    int 0x10
    ; Двигаем курсор
    mov ah, 0x03
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop cx
    jmp .zero_loop

.done:
    popa
    ret
print_message:
    mov ah, 0x0e; Устанавливаем значение AH для вывода символа
    mov bh,0x00; Страница
    puts_loop:
        lodsb            ; загружаем очередной символ в al
        test al, al      ; нулевой символ означает конец строки
        jz   puts_loop_exit
        int  0x10        ; вызываем функцию BIOS
        jmp  puts_loop
    puts_loop_exit:
    ret
;---------------------------------------BackSpace-------------------------
BackSpace:
dec di
mov si,comand
cmp si,di
jne decriminal
mov ah,0x0E
mov al,'>'
int 10h
jmp KERNEL
decriminal:
dec di
mov ah,0ah
mov al,' '
mov bh,0
mov cx,1
int 10h
jmp KERNEL
print_history:
    call clear_screen_color

    ; Заголовок
    mov ah, 0x02
    mov bh, 0
    mov dh, 0
    mov dl, 25
    int 0x10
    call new_label
    mov si, history_header
    call print_string

    call new_label
    call new_label

    mov si, history_table
    mov cx, 10
    mov bx, 1               ; Номер команды (начинаем с 1)
.line_loop:
    push cx

    ; Выводим номер
    push bx
    mov al, ' '
    call print_char
    mov ax, bx
    call print_dec
    mov al, '.'
    call print_char
    mov al, ' '
    call print_char
    pop bx

    ; Выводим команду
    mov cx, 50
.char_loop:
    lodsb
    cmp al, 0
    je .skip
    cmp al, 13
    je .skip
    call print_char
.skip:
    loop .char_loop

    call new_label

    inc bx                  ; Следующий номер
    pop cx
    loop .line_loop

    ; Закрывающая строка
    call new_label
    mov si, history_footer
    call print_string
    call new_label

    jmp BEGIN
history_header: db '=== HISTORY COMAND ===', 0
history_footer: db '======================', 0
up_arrow:
    dec di
    ; Скролл вниз на 1 строку (сдвигаем текст вниз)
    mov ah, 07h
    mov al, 1          ; 1 строка
    mov bh, 17h        ; Белый на синем
    mov ch, 0          ; Верхняя строка окна
    mov cl, 0          ; Левая колонка
    mov dh, 24         ; Нижняя строка
    mov dl, 79         ; Правая колонка
    int 10h
    jmp KERNEL

down_arrow:
    dec di
    ; Скролл вверх на 1 строку (сдвигаем текст вверх)
    mov ah, 06h
    mov al, 1
    mov bh, 17h
    mov ch, 0
    mov cl, 0
    mov dh, 24
    mov dl, 79
    int 10h
    jmp KERNEL


history_table: times 50*10 db 0
history_index:  dw 0        ; Куда сохранять следующую команду (0-6)
history_pos:    dw 11        ; 0 = текущий ввод, 1-7 = позиция в истории

; Стрелка вправо — более новая команда
right_arrow:
    dec di


    jmp KERNEL

; Стрелка влево — более старая команда
left_arrow:
    dec di


    jmp KERNEL

saave_cmd:
mov ax,50
mov bx,[history_index]
mul bx
mov di,history_table
add di,ax
mov ax,[history_index]
inc ax
cmp ax,9
jnz .write_comand
xor ax,ax
.write_comand:
mov [history_index],ax
mov si,comand
mov cx,50
rep movsb
ret
;----------------------------Обработчик команд--------------------------
    comands:
call saave_cmd
call clear_screen_color
call new_label
mov si,help_com
mov di,comand
rep_help:
cmpsb
jnz com_prog ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz print_help
jmp rep_help
com_prog:
mov si,prog1
mov di,comand
rep_prog:
cmpsb
jnz com_disk_info ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz print_prog
jmp rep_prog
com_disk_info:
mov di,comand
mov si,com_inf_disk
rep_disk_inf:
cmpsb
jnz com_sys_ifo ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz start_ifo_disk
jmp rep_disk_inf
com_sys_ifo:
mov di,comand
mov si,inf_com
rep_sys_inf:
cmpsb
jnz com_clear_screen ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz print_sys_inf
jmp rep_sys_inf
com_clear_screen:
mov di,comand
mov si,clear_com
rep_clear_screen:
cmpsb
jnz com_ls ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz cmd_color_clear_scren
jmp rep_clear_screen

com_ls:
mov di,comand
mov si,com_list
rep_list:
cmpsb
jnz com_type
mov al,[si]
test al,al
jz comand_list
jmp rep_list
com_type:
mov di,comand
mov si,cmd_type
rep_type:
cmpsb
jnz com_load
mov al,[si]
test al,al
jz do_type
jmp rep_type
com_load:
mov di,comand
mov si,cmd_load
rep_load:
cmpsb
jnz com_run
mov al,[si]
test al,al
jz do_load
jmp rep_load
com_run:
mov di,comand
mov si,cmd_run
rep_run:
cmpsb
jnz com_create
mov al,[si]
test al,al
jz do_run
jmp rep_run
; ============================================================
; Обновлённый обработчик команд (добавить create)
; ============================================================
com_create:
    mov di, comand
    mov si, cmd_create
    rep_create:
        cmpsb
        jnz com_write        ; Следующая команда
        mov al, [si]
        test al, al
        jz do_create
        jmp rep_create
com_write:
    mov di,comand
    mov si, cmd_write
    rep_write:
        cmpsb
        jnz com_ru        ; Следующая команда
        mov al, [si]
        test al, al
        jz do_write
        jmp rep_write
com_ru:
    mov di,comand
    mov si,ru_com
    rep_ru:
    cmpsb
        jnz com_tasks        ; Следующая команда
        mov al, [si]
        test al, al
        jz do_ru
        jmp rep_ru
        ; В секцию comands добавить после com_run:

com_tasks:
    mov di, comand
    mov si, cmd_tasks
    rep_tasks:
        cmpsb
        jnz com_kill
        mov al, [si]
        test al, al
        jz list_tasks
        jmp rep_tasks

com_kill:
    mov di, comand
    mov si, cmd_kill
    rep_kill:
        cmpsb
        jnz go_kernel
        mov al, [si]
        test al, al
        jz kill_task
        jmp rep_kill
com_cmd_a:
mov di, comand
    mov si, cmd_a
    rep_cmd_a:
        cmpsb
        jnz go_kernel
        mov al, [si]
        test al, al
        ;jz on_a
        jmp rep_cmd_a
;--------------------------------adres-----------------
print_adres:
mov ax,MMM
call print_hex
call new_label
jmp go_kernel
do_ru:
call new_label
mov si,ru_mesg
call print_string
call new_label
jmp go_kernel

;---------------------------Descktop------------------
; ============================================================
; ЦВЕТНЫЕ ФУНКЦИИ ВЫВОДА (белый текст на синем фоне)
; ============================================================
clear_screen_non_color:
    pusha
    mov ah, 0x02
    mov bh, 0x00
    xor dx, dx
    int 0x10

    mov cx, 80*25
    mov ah, 0x0E
    mov al, ' '
.clear_loop:
    int 0x10
    loop .clear_loop

    mov ah, 0x02
    mov bh, 0x00
    xor dx, dx
    int 0x10
    popa
    ret
; ------------------------------------------------------------
; Установка видеорежима 80x25 цветной текст
; ------------------------------------------------------------
init_video_mode:
    pusha
    mov ax, 0x0003      ; Режим 80x25, 16 цветов
    int 0x10
    popa
    ret

; ------------------------------------------------------------
; Очистка экрана с синим фоном
; ------------------------------------------------------------
clear_screen_color:
    pusha
    ; Устанавливаем позицию курсора в 0,0
    mov ah, 0x02
    mov bh, 0x00
    xor dx, dx
    int 0x10

    ; Заполняем экран синим фоном
    mov cx, 80*25       ; 80 колонок x 25 строк
    mov ah, 0x09        ; Функция записи символа с атрибутом
    mov al, ' '         ; Пробел
    mov bh, 0x00        ; Страница 0
    mov bl, 0x17        ; Белый (1) на синем (7) фоне
    int 0x10

    ; Устанавливаем курсор обратно
    mov ah, 0x02
    mov bh, 0x00
    xor dx, dx
    int 0x10
    popa
    ret

; ------------------------------------------------------------
; Цветной вывод символа (белый на синем)
; ------------------------------------------------------------
print_char_color:
    pusha
    mov ah, 0x09        ; Write character with attribute
    mov bh, 0x00        ; Page 0
    mov cx, 1           ; Один символ
    mov bl, 0x17        ; Атрибут: белый (0x0F) на синем (0x10) = 0x17
    int 0x10

    ; Двигаем курсор
    mov ah, 0x03        ; Get cursor position
    mov bh, 0x00
    int 0x10
    inc dl              ; Увеличиваем колонку
    mov ah, 0x02        ; Set cursor position
    int 0x10
    popa
    ret

; ------------------------------------------------------------
; Цветной вывод строки (белый на синем)
; Вход: SI -> строка (заканчивается 0)
; ------------------------------------------------------------
print_string_color:
    pusha
.loop:
    lodsb               ; Загружаем символ
    test al, al         ; Проверяем на 0
    jz .done

    push si
    mov ah, 0x09        ; Выводим символ с атрибутом
    mov bh, 0x00
    mov cx, 1
    mov bl, 0x17        ; Белый на синем
    int 0x10

    ; Двигаем курсор вправо
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    inc dl
    mov ah, 0x02
    int 0x10
    pop si
    jmp .loop
.done:
    popa
    ret

; ------------------------------------------------------------
; Цветной вывод сообщения с новой строкой
; Вход: SI -> строка
; ------------------------------------------------------------
print_message_color:
    call print_string_color
    call new_label_color
    ret

; ------------------------------------------------------------
; Новая строка с сохранением цвета фона
; ------------------------------------------------------------
new_label_color:
    pusha
    ; Получаем текущую позицию
    mov ah, 0x03
    mov bh, 0x00
    int 0x10
    ; Переходим на новую строку
    inc dh              ; Следующая строка
    xor dl, dl          ; Колонка 0
    mov ah, 0x02
    int 0x10
    popa
    ret
;------------------------------disk------------------
; Получаем параметры диска
start_ifo_disk:
    mov dl, 0x80       ; DL = номер диска (0x80 = первый HDD)
    mov ah, 0x08       ; Функция GET DRIVE PARAMETERS
    mov di, 0x0000     ; ES:DI = буфер (необязательно)
    int 0x13
    jc disk_error      ; Если CF=1 - ошибка
    ; Результаты в регистрах:
    ; BL = тип диска
    ; CH = младшие 8 битов максимального номера цилиндра
    ; CL = биты 6-7: старшие 2 бита максимального номера цилиндра
    ;      биты 0-5: максимальный номер сектора
    ; DH = максимальный номер головки
    ; DL = количество накопителей

    ; Вычисляем общее количество секторов
    call calculate_total_sectors
    ; Выводим результат
    mov si, success_msg
    call print_string

    mov ax, [total_sectors]
    call print_hex
    call new_label
    jmp go_kernel
    disk_error:
    mov si, error_msg
    call print_string
    call new_label
    jmp go_kernel

; Вычисление общего количества секторов
calculate_total_sectors:
    ; Восстанавливаем полный номер цилиндра
    mov al, cl
    and al, 0xC0       ; Берем старшие 2 бита из CL
    shr al, 6          ; Сдвигаем вправо
    mov ah, ch         ; AH = младшие 8 бит цилиндра
    ; Теперь AX = максимальный номер цилиндра

    inc ax             ; Количество цилиндров = max_cylinder + 1

    mov bl, dh
    inc bl             ; Количество головок = max_head + 1

    mov bh, cl
    and bh, 0x3F       ; Максимальный номер сектора (биты 0-5)

    ; Вычисляем: total = cylinders * heads * sectors_per_track
    mul bl             ; AX = cylinders * heads
    mul bh             ; AX = (cylinders * heads) * sectors_per_track

    mov [total_sectors], ax
    ret

; Данные
success_msg: db 'Total sectors: ', 0
error_msg: db 'Disk error!', 0
total_sectors: dw 0

;--------------------------------FAT12-------------------------------------
comand_list:

    mov si, msg_header
    call print_string

    ; Читаем Root Directory
    mov ax, 0x0500
    mov es, ax
    xor bx, bx
    mov ax, 19
    mov cx, 14
.read_root:
    call read_sector
    add bx, 512
    inc ax
    loop .read_root

    ; Сканируем файлы
    mov ax, 0x0500
    mov es, ax
    xor di, di              ; Используем DI вместо SI
    mov cx, 224

.scan:
    push cx

    mov al, [es:di]
    cmp al, 0x00
    je .done
    cmp al, 0xE5
    je .next

    mov al, [es:di+11]      ; Атрибут
    test al, 0x08
    jnz .next
    test al, 0x10
    jnz .next
    cmp al, 0x0F
    je .next

    ; Выводим имя (8 символов)
    push di
    mov cx, 8
.name_loop:
    mov al, [es:di]
    cmp al, ' '
    je .name_done
    call print_char
    inc di
    loop .name_loop
.name_done:

    ; Расширение
    pop di
    push di
    mov al, [es:di+8]
    cmp al, ' '
    je .no_ext

    mov al, '.'
    call print_char

    mov cx, 3
    add di, 8
.ext_loop:
    mov al, [es:di]
    cmp al, ' '
    je .ext_done
    call print_char
    inc di
    loop .ext_loop
.ext_done:

.no_ext:
    pop di

    ; РАЗМЕР ФАЙЛА - ИСПРАВЛЕНО
    push di
    mov si, msg_size
    call print_string

    mov ax, [es:di+28]      ; Берем младшее слово размера
    mov dx, [es:di+30]      ; Старшее слово (если нужно)

    ; Если файл больше 64K, DX будет не 0
    cmp dx, 0
    je .print_size

    ; Выводим старшую часть (упрощенно)
    push ax
    mov ax, dx
    call print_hex
    pop ax

.print_size:
    call print_dec

    mov si, msg_bytes
    call print_string
    pop di

.next:
    pop cx
    add di, 32
    loop .scan

.done:
    pop cx
    mov si, msg_ready
    call print_string
    jmp go_kernel

; ------------------------------------------------------------
; ЧТЕНИЕ СЕКТОРА
; ------------------------------------------------------------
read_sector:
    pusha
    xor dx, dx
    mov cx, 18
    div cx
    inc dl
    mov cl, dl
    xor dx, dx
    mov ch, 2
    div ch
    mov ch, al
    mov dh, ah
    mov dl, [boot_disk]
    mov ax, 0x0201
    int 0x13

    jnc .ok                   ; Если CF=0 (нет ошибки)

    ; ОШИБКА! Выводим 'E' и номер ошибки
    mov al,ah
    call print_hex_byte
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    mov al, ah                ; AH содержит код ошибки
    add al, '0'
    int 0x10
    call new_label                     ; Зависаем для диагностики
    ;сброс контроллера диска
    mov ah,0
    mov dl,[boot_disk]
    int 13h
    jmp go_kernel
.ok:
    popa
    ret
; ------------------------------------------------------------
; ВЫВОД
; ------------------------------------------------------------
print_char:
    mov ah, 0x0E
    int 0x10
    ret

print_string:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp print_string
.done:
    ret

print_dec:
    push ax
    push bx
    push cx
    push dx
    mov bx, 10
    mov cx, 0
.div_loop:
    xor dx, dx
    div bx
    push dx
    inc cx
    test ax, ax
    jnz .div_loop
.print_loop:
    pop ax
    add al, '0'
    call print_char
    loop .print_loop
    pop dx
    pop cx
    pop bx
    pop ax
    ret

print_hex:
    push ax
    push bx
    mov bx, ax
    mov al, bh
    shr al, 4
    call .nibble
    mov al, bh
    and al, 0x0F
    call .nibble
    mov al, bl
    shr al, 4
    call .nibble
    mov al, bl
    and al, 0x0F
    call .nibble
    pop bx
    pop ax
    ret
.nibble:
    cmp al, 10
    jl .digit
    add al, 'A'-10
    jmp .out
.digit:
    add al, '0'
.out:
    call print_char
    ret

; ------------------------------------------------------------
; ДАННЫЕ
; ------------------------------------------------------------
msg_header: db 'Files on disk:', 13, 10
            db '==============', 13, 10, 0
msg_size:   db ' - ', 0
msg_bytes:  db ' bytes', 13, 10, 0
msg_ready:  db 13, 10, 'Ready.', 13, 10, 0
; ============================================================
; TASK MANAGER v3 (безопасные сегменты, чистый интерфейс)
; ============================================================
MAX_TASKS       equ 4
TASK_ENTRY_SIZE equ 13         ; 11 байт имени + 2 байта сегмента

; Таблица задач
task_table: times TASK_ENTRY_SIZE * MAX_TASKS db 0

; Сегменты для задач
task_segments: dw 0x3000, 0x4000, 0x5000, 0x6000

; ------------------------------------------------------------
; add_task — добавить задачу в таблицу
; Вход:  SI → fat_name (11 байт, использует DS)
; Выход: AX = сегмент задачи (0 = нет места)
;        CF = 0 успех, CF = 1 таблица полна
; ------------------------------------------------------------
add_task:
    push cx
    push di
    push si
    push ds
    push es

    push cs
    pop es
    push cs
    pop ds

    mov di, task_table
    xor cx, cx              ; индекс слота

.search:
    cmp cx, MAX_TASKS
    jae .full

    cmp byte [di], 0
    je .found

    add di, TASK_ENTRY_SIZE
    inc cx
    jmp .search

.full:
    xor ax, ax
    stc
    jmp .exit

.found:
    ; Копируем имя (11 байт)
    push cx
    mov cx, 11
    rep movsb
    pop cx

    ; Возвращаем сегмент из task_segments
    mov si, task_segments
    shl cx, 1
    add si, cx
    mov ax, [si]

    clc

.exit:
    pop es
    pop ds
    pop si
    pop di
    pop cx
    ret

; ------------------------------------------------------------
; find_task — найти задачу по имени
; Вход:  SI → fat_name (11 байт, использует DS)
; Выход: AX = сегмент задачи (0 = не найдена)
;        CF = 0 найдена, CF = 1 не найдена
; ------------------------------------------------------------
find_task:
    push cx
    push di
    push si
    push ds
    push es

    push cs
    pop es
    push cs
    pop ds

    mov di, task_table
    xor cx, cx

.check:
    cmp cx, MAX_TASKS
    jae .not_found

    cmp byte [di], 0
    je .not_found

    push si
    push di
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    pop si
    je .found

    add di, TASK_ENTRY_SIZE
    inc cx
    jmp .check

.not_found:
    xor ax, ax
    stc
    jmp .exit

.found:
    mov si, task_segments
    shl cx, 1
    add si, cx
    mov ax, [si]
    clc

.exit:
    pop es
    pop ds
    pop si
    pop di
    pop cx
    ret

; ------------------------------------------------------------
; remove_task — удалить задачу по имени
; Вход:  SI → fat_name (11 байт)
; Выход: CF = 0 удалена, CF = 1 не найдена
; ------------------------------------------------------------
remove_task:
    push cx
    push di
    push si
    push es

    push cs
    pop es

    mov di, task_table
    xor cx, cx

.check:
    cmp cx, MAX_TASKS
    jae .not_found

    cmp byte [di], 0
    je .not_found

    push si
    push di
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    pop si
    je .found

    add di, TASK_ENTRY_SIZE
    inc cx
    jmp .check

.not_found:
    stc
    jmp .exit

.found:
    mov byte [di], 0         ; очищаем слот
    clc

.exit:
    pop es
    pop si
    pop di
    pop cx
    ret

; ------------------------------------------------------------
; list_tasks — показать все задачи
; ------------------------------------------------------------
list_tasks:
    push cx
    push si
    push di
    push ds
    push es

    push cs
    pop ds
    push cs
    pop es

    call new_label
    mov si, msg_task_header
    call print_message
    call new_label

    mov di, task_table
    xor cx, cx
    mov bl, '1'

.show:
    cmp cx, MAX_TASKS
    jae .done

    cmp byte [di], 0
    je .next

    ; Номер задачи
    mov al, bl
    call print_char
    mov al, '.'
    call print_char
    mov al, ' '
    call print_char

    ; Имя (8 символов)
    push cx
    push di
    mov cx, 8
.name_loop:
    mov al, [di]
    cmp al, ' '
    je .show_ext
    call print_char
    inc di
    loop .name_loop
    jmp .show_ext2

.show_ext:
    add di, cx

.show_ext2:
    mov al, '.'
    call print_char

    add di, 8
    mov cx, 3
.ext_loop:
    mov al, [di]
    cmp al, ' '
    je .ext_done
    call print_char
    inc di
    loop .ext_loop

.ext_done:
    pop di
    pop cx

    ; Выводим сегмент
    mov al, ' '
    call print_char
    mov al, '@'
    call print_char

    push si
    mov si, task_segments
    push cx
    shl cx, 1
    add si, cx
    mov ax, [si]
    pop cx
    pop si
    call print_hex

    mov al, ':'
    call print_char
    mov ax, 0x0100
    call print_hex
    call new_label

.next:
    add di, TASK_ENTRY_SIZE
    inc cx
    inc bl
    jmp .show

.done:
    pop es
    pop ds
    pop di
    pop si
    pop cx
    jmp go_kernel

; ============================================================
; КОМАНДА LOAD — загружает программу через менеджер задач
; ============================================================
do_load:
    mov si, comand+5
    call parse_filename

    ; Проверяем, не загружена ли уже
    mov si, fat_name
    call find_task
    jnc .already_loaded

    ; Ищем файл на диске
    call find_file
    jc .not_found

    ; Добавляем в таблицу задач
    mov si, fat_name
    call add_task
    jc .table_full
    mov [load_segment], ax

    ; Загружаем FAT
    call load_fat

    ; Грузим файл в память
    mov es, [load_segment]
    mov bx, 0x0100
    mov ax, [first_cluster]
    mov [current_cluster], ax

.load_loop:
    mov ax, [current_cluster]
    cmp ax, 0xFF8
    jae .loaded

    sub ax, 2
    add ax, 33
    call read_sector

    add bx, 512

    mov ax, [current_cluster]
    call get_next_cluster
    mov [current_cluster], ax
    jmp .load_loop

.loaded:
    mov si, msg_loaded_ok
    call print_message
    jmp go_kernel

.already_loaded:
    mov si, msg_already_loaded
    call print_message
    jmp go_kernel

.not_found:
    mov si, msg_not_found
    call print_message
    jmp go_kernel

.table_full:
    mov si, msg_task_full
    call print_message
    jmp go_kernel

; ============================================================
; КОМАНДА RUN — запускает загруженную программу с аргументами
; Формат: run name.com arg1 arg2 arg3
; ============================================================
do_run:
    ; Парсим имя файла (после "run ")
    mov si, comand+4
    call parse_filename

    ; Ищем задачу в таблице
    mov si, fat_name
    call find_task
    jc .not_loaded

    ; AX = сегмент задачи
    mov [run_segment], ax

    ; --- Заполняем PSP: строку аргументов ---
    ; Сначала найдём начало аргументов в командной строке
    ; Пропускаем "run " (4 символа), затем имя файла
    mov si, comand+4

    ; Пропускаем имя файла (до пробела или конца)
.skip_name:
    lodsb
    cmp al, ' '
    je .found_args
    cmp al, 0
    je .no_args
    jmp .skip_name

.found_args:
    ; SI сейчас указывает на первый символ после пробела
    ; (может быть пробел, если несколько пробелов — пропустим)
    cmp byte [si], ' '
    jne .copy_args
    inc si
    jmp .found_args

.copy_args:
    ; Считаем длину и копируем в PSP
    mov es, [run_segment]
    mov di, 0x0081           ; Буфер аргументов в PSP
    xor cx, cx               ; Счётчик длины

.copy_loop:
    mov al, [si]
    cmp al, 0                ; Конец командной строки?
    je .done_copy
    cmp al, 0x0D             ; CR?
    je .done_copy
    stosb
    inc cx
    inc si
    cmp cx, 126              ; Максимум 126 байт аргументов
    je .done_copy
    jmp .copy_loop

.done_copy:
    ; Добавляем CR (0x0D) в конец
    mov al, 0x0D
    stosb

    ; Записываем длину в PSP:0x80
    mov byte [es:0x0080], cl

    jmp .run_program

.no_args:
    mov es, [run_segment]
    mov byte [es:0x0080], 0   ; Длина = 0
    mov byte [es:0x0081], 0x0D ; Просто CR

.run_program:
    call clear_screen_non_color
    ; Сохраняем стек ядра
    mov [steck_save], sp

    ; Настраиваем окружение программы

    mov ax, [run_segment]

    mov es, ax
    push ax
    mov di,0x00
    mov ax,[int20]
    stosw
    pop ax
    mov ds, ax
    mov ss, ax
    mov sp, 0xFFFE

    ; Передаём сегмент PSP в DS и ES (уже сделано выше)
    mov dl, [boot_disk]

    ; Запуск программы
    push 0x0000        ; для RET
    push ax
    push 0x0100
    retf

.not_loaded:
    mov si, msg_not_loaded
    call print_message
    jmp go_kernel

; ============================================================
; КОМАНДА KILL — удаляет задачу из таблицы
; ============================================================
kill_task:
    mov si, comand+5
    call parse_filename

    mov si, fat_name
    call remove_task
    jc .not_found

    mov si, msg_kill_ok
    call print_message
    ; Установка пользовательского обработчика таймера (int 1Ch)
    ; Reboot timer interput

    cli
    mov di, 0x1C*4
    mov word [di], timer_handler
    mov ax, cs
    mov word [di+2], ax


    sti
    jmp go_kernel

.not_found:
    mov si, msg_not_found
    call print_message
    jmp go_kernel

; ------------------------------------------------------------
; ДАННЫЕ
; ------------------------------------------------------------
msg_already_loaded: db 'Task already loaded!', 0
; Данные для run
run_segment:        dw 0
msg_running_task:   db 'Running task at ', 0
msg_not_loaded:     db 'Task not loaded! Use "load" first.', 0
steck_save:         dw 0
;-------------------------------------------------
; КОМАНДА TYPE - ВЫВОДИТ ТЕКСТОВЫЙ ФАЙЛ НА ЭКРАН
; Формат: type FILENAME.EXT
; Использует менеджер памяти для загрузки файла
; -------------------------------------------------
do_type:
    ; 1. Парсим имя файла
    mov si, comand+5
    call parse_filename

    ; 2. Ищем файл в каталоге
    call find_file
    jc .not_found

    ; 3. Загружаем FAT
    call load_fat

    ; 4. Ищем свободный слот в таблице задач для временной загрузки
    mov si, fat_name
    call find_task
    jnc .use_existing_segment   ; если файл уже загружен как задача

    ; Ищем свободный сегмент через таблицу задач
    call find_free_task_slot
    jc .no_memory
    mov [type_segment], ax

    jmp .load_file

.use_existing_segment:
    ; Файл уже загружен, используем его сегмент
    mov [type_segment], ax
    mov si, msg_using_loaded
    call print_string
    call new_label

.load_file:
    ; 5. Загружаем файл в память
    mov es, [type_segment]
    mov bx, 0x0100             ; смещение как у программ
    mov ax, [first_cluster]
    mov [current_cluster], ax
    mov word [bytes_loaded], 0

.load_loop:
    mov ax, [current_cluster]
    cmp ax, 0xFF8
    jae .loaded

    ; Читаем сектор
    sub ax, 2
    add ax, 33
    push bx
    call read_sector
    pop bx

    ; Считаем байты
    mov ax, [file_size]
    sub ax, [bytes_loaded]
    cmp ax, 512
    jae .full_sector

    ; Последний сектор — сохраняем точный размер
    mov [bytes_in_last], ax
    jmp .loaded

.full_sector:
    add word [bytes_loaded], 512
    add bx, 512

    ; Следующий кластер
    mov ax, [current_cluster]
    call get_next_cluster
    mov [current_cluster], ax
    jmp .load_loop

.loaded:
    ; 6. Выводим содержимое на экран
    call new_label
    mov si, msg_type_start
    call print_string
    call new_label
    call new_label

    ; Настраиваемся на вывод
    mov ds, [type_segment]
    mov si, 0x0100             ; начало данных
    mov cx, [file_size]        ; общий размер файла

.print_loop:
    lodsb                      ; читаем байт из сегмента файла
    cmp al, 0                  ; конец текста?
    je .print_done
    cmp al, 0x1A               ; EOF маркер?
    je .print_done
    call print_char
    loop .print_loop

.print_done:
    ; Восстанавливаем DS на ядро
    push cs
    pop ds

    call new_label
    call new_label

    ; 7. Если это была временная загрузка — освобождаем память
    mov si, fat_name
    call find_task
    jnc .keep_segment          ; если задача загружена — не трогаем

    ; Освобождаем временный сегмент (заполняем нулями)
    mov es, [type_segment]
    xor di, di
    mov cx, 0x8000             ; 64K слов = 128K байт
    xor ax, ax
    rep stosw

.keep_segment:
    ; Восстанавливаем сегменты
    push cs
    pop ds
    push cs
    pop es

    mov si, msg_type_end
    call print_string
    call new_label
    jmp go_kernel

.not_found:
    mov si, msg_not_found
    call print_string
    call new_label
    jmp go_kernel

.no_memory:
    mov si, msg_type_no_memory
    call print_string
    call new_label
    jmp go_kernel

; ------------------------------------------------------------
; Поиск свободного слота в таблице задач
; Выход: AX = свободный сегмент, CF=1 если нет
; ------------------------------------------------------------
find_free_task_slot:
    push cx
    push si
    push di
    push es

    push cs
    pop es

    mov di, task_table
    xor cx, cx
    mov si, task_segments

.search:
    cmp cx, MAX_TASKS
    jae .not_found

    cmp byte [es:di], 0
    je .found

    add di, TASK_ENTRY_SIZE
    add si, 2
    inc cx
    jmp .search

.not_found:
    stc
    pop es
    pop di
    pop si
    pop cx
    ret

.found:
    mov ax, [si]
    clc
    pop es
    pop di
    pop si
    pop cx
    ret

; ------------------------------------------------------------
; ДАННЫЕ ДЛЯ TYPE
; ------------------------------------------------------------
type_segment:    dw 0
bytes_loaded:    dw 0
bytes_in_last:   dw 0
msg_type_start:  db '=== FILE CONTENT ===', 0
msg_type_end:    db '=== END OF FILE ===', 0
msg_type_no_memory: db 'Error: No free memory to load file!', 0
msg_using_loaded:   db 'Using already loaded file...', 0

cmd_type: db 'type', 0
; -----------------------------------------------------------------------------
; ПАРСЕР ИМЕНИ ФАЙЛА (строка -> 11 байт 'NAME    EXT')
; ВХОД: DS:SI = исходная строка
; ВЫХОД: fat_name = 11 байт
; -----------------------------------------------------------------------------
parse_filename:
    pusha
    mov di, fat_name
    mov cx, 11
    mov al, ' '
    rep stosb               ; Заполняем пробелами

    mov di, fat_name
    mov cx, 8
.copy_name:
    lodsb
    cmp al, 0
    je .done
    cmp al, '.'
    je .copy_ext
    cmp al, ' '
    je .done
    cmp cx, 0
    je .skip_to_ext
    stosb
    dec cx
    jmp .copy_name

.skip_to_ext:
    lodsb
    cmp al, '.'
    je .copy_ext
    cmp al, 0
    je .done
    jmp .skip_to_ext

.copy_ext:
    mov di, fat_name+8
    mov cx, 3
.copy_ext_loop:
    lodsb
    cmp al, 0
    je .done
    stosb
    loop .copy_ext_loop
.done:
    popa
    ret

; -----------------------------------------------------------------------------
; ПОИСК ФАЙЛА В КОРНЕВОМ КАТАЛОГЕ
; ВЫХОД: CF=1 если не найден
;        first_cluster = номер первого кластера
;        file_size = размер файла
; -----------------------------------------------------------------------------
find_file:
    ; Читаем Root Dir в 0x0500:0x0000
    mov ax, 0x0500
    mov es, ax
    xor bx, bx
    mov ax, 19
    mov cx, 14
.read_root:
    call read_sector
    add bx, 512
    inc ax
    loop .read_root

    ; Ищем файл
    mov ax, 0x0500
    mov es, ax
    xor di, di
    mov cx, 224

.search:
    mov al, [es:di]
    cmp al, 0x00
    je .not_found
    cmp al, 0xE5
    je .next

    push di
    mov si, fat_name
    mov cx, 11
    repe cmpsb
    pop di
    je .found

.next:
    add di, 32
    loop .search

.not_found:
    stc
    ret

.found:
    mov ax, [es:di+26]      ; Первый кластер
    mov [first_cluster], ax
    mov ax, [es:di+28]      ; Размер
    mov [file_size], ax
    clc
    ret

; -----------------------------------------------------------------------------
; ЗАГРУЗКА FAT В 0x1000:0x0000
; -----------------------------------------------------------------------------
load_fat:
    cmp byte [fat_loaded], 1
    je .done

    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ax, 1
    mov cx, 9
.read_fat:
    call read_sector
    add bx, 512
    inc ax
    loop .read_fat

    mov byte [fat_loaded], 1
.done:
    ret

; -----------------------------------------------------------------------------
; ПОЛУЧЕНИЕ СЛЕДУЮЩЕГО КЛАСТЕРА ИЗ FAT12
; ВХОД: AX = текущий кластер
; ВЫХОД: AX = следующий кластер
; -----------------------------------------------------------------------------
get_next_cluster:
    push ds
    push si

    mov si, ax
    shr ax, 1
    add si, ax              ; SI = cluster * 1.5

    push ax
    mov ax, 0x1000
    mov ds, ax
    pop ax
    mov ax, [si]            ; Читаем слово из FAT

    test word [.temp], 1
    jz .even
    shr ax, 4
    jmp .done
.even:
    and ax, 0x0FFF
.done:
    mov [.temp], ax
    pop si
    pop ds
    ret
.temp: dw 0
; -----------------------------------------------------------------------------
; ВЫВОД БАЙТА В HEX
; -----------------------------------------------------------------------------
print_hex_byte:
    push ax
    shr al, 4
    call .nibble
    pop ax
    and al, 0x0F
    call .nibble
    ret
.nibble:
    cmp al, 10
    jl .digit
    add al, 'A'-10
    jmp .out
.digit:
    add al, '0'
.out:
    call print_char
    ret

; ============================================================
; КОМАНДА CREATE - СОЗДАТЬ ФАЙЛ
; Формат: create FILENAME.EXT
; ============================================================
do_create:
    mov si, comand+7
    call parse_filename
    call find_file
    jnc do_create_already_exists
    call find_free_entry
    jc do_create_disk_full
    call fill_entry_in_buffer

    ; Прямо указываем сектор 19!
    mov ax, 19
    call write_root_sector
    jc do_create_error

    mov si, msg_created
    call print_message
    call new_label
    jmp go_kernel

do_create_already_exists:
    mov si, msg_already_exists
    call print_message
    call new_label
    jmp go_kernel

do_create_disk_full:
    mov si, msg_disk_full
    call print_message
    call new_label
    jmp go_kernel

do_create_error:
    mov si, msg_write_error
    call print_message
    call new_label
    jmp go_kernel

; ============================================================
; ПОИСК СВОБОДНОЙ ЗАПИСИ В КОРНЕВОМ КАТАЛОГЕ
; Выход: CF=1 если нет места, иначе found_offset = смещение
; ============================================================
find_free_entry:
    pusha

    ; Читаем корневой каталог в 0x0500
    mov ax, 0x0500
    mov es, ax
    xor bx, bx
    mov ax, 19
    mov cx, 14
.read_root:
    call read_sector
    add bx, 512
    inc ax
    loop .read_root

    ; Ищем свободную запись
    mov ax, 0x0500
    mov es, ax
    xor di, di
    mov cx, 224

.search:
    mov al, [es:di]
    cmp al, 0x00            ; Свободно
    je .found
    cmp al, 0xE5            ; Удалённый файл
    je .found
    add di, 32
    loop .search

    ; Нет свободного места
    stc
    popa
    ret

.found:
    mov [found_offset], di
    clc
    popa
    ret

; ============================================================
; ЗАПОЛНИТЬ ЗАПИСЬ В БУФЕРЕ 0x0500
; ============================================================
fill_entry_in_buffer:
    pusha

    mov ax, 0x0500
    mov es, ax
    mov di, [found_offset]

    ; 1. Имя файла (11 байт)
    mov si, fat_name
    mov cx, 11
    rep movsb

    ; 2. Атрибуты (0x20 = архивный)
    mov byte [es:di], 0x20
    inc di

    ; 3. Резерв (10 байт нулей)
    mov cx, 10
    mov al, 0
    rep stosb

    ; 4. Время создания (0)
    mov word [es:di], 0x0000
    add di, 2

    ; 5. Дата создания (0)
    mov word [es:di], 0x0000
    add di, 2

    ; 6. Первый кластер (0 = пустой файл)
    mov word [es:di], 0x0000
    add di, 2

    ; 7. Размер файла (4 байта = 0)
    mov word [es:di], 0x0000
    add di, 2
    mov word [es:di], 0x0000

    popa
    ret

; ============================================================
; ЗАПИСАТЬ СЕКТОР КОРНЕВОГО КАТАЛОГА НА ДИСК
; Использует read_sector, но с записью
; ============================================================
write_root_sector:
    pusha

    push ax                 ; Сохраняем номер сектора

    mov ah, 0x0E
    mov al, 'W'
    int 0x10
    mov al, ':'
    int 0x10
    pop ax
    push ax
    call print_hex
    mov al, ' '
    int 0x10
    pop ax

    ; Устанавливаем ES:BX на НАЧАЛО сектора в буфере
    mov bx, [found_offset]
    shr bx, 9               ; BX = found_offset / 512
    shl bx, 9               ; BX = начало сектора в буфере
    mov ax, 0x0500
    mov es, ax

    ; Восстанавливаем номер сектора
    mov ax, 19              ; Или вычислить: 19 + found_offset/512

    ; CHS-трансляция
    xor dx, dx
    mov cx, 18
    div cx
    inc dl
    mov cl, dl

    xor dx, dx
    mov ch, 2
    div ch
    mov ch, al
    mov dh, ah

    mov dl, [boot_disk]
    mov ax, 0x0301
    int 0x13

    jnc .ok
    mov al, 'E'
    int 0x10
    popa
    stc
    ret

.ok:
    mov al, 'O'
    int 0x10
    mov al, 'K'
    int 0x10
    popa
    clc
    ret
; ============================================================
; ДАННЫЕ
; ============================================================
msg_created:        db 'File created successfully.', 0
msg_already_exists: db 'Error: File already exists.', 0
msg_disk_full:      db 'Error: Disk is full.', 0
msg_write_error:    db 'Error writing to disk.', 0
found_offset:       dw 0

; ============================================================
; КОМАНДА WRITE (исправленная, с отладкой)
; ============================================================
do_write:
    mov si,comand+6
    call parse_filename
    mov si,fat_name
    call print_string
    call new_label

    ; Ищем свободный кластер
    call find_free_cluster
    jc error_write
    mov [data_free_cluster],ax
    test ax,ax
    jz cluster_zero
    call print_hex_word
    call new_label

    ; Находим запятую в командной строке
    mov si,comand+6

.skip_name_loop:
    lodsb
    cmp al,','
    je .found_comma
    cmp al,0
    je error_write
    jmp .skip_name_loop

.found_comma:
    ; Пропускаем пробелы после запятой
.skip_spaces:
    lodsb
    cmp al,' '
    je .skip_spaces
    dec si               ; возвращаемся на первый символ данных

    push si
    pusha
    call new_label
    mov si,mesg_start_copy
    call print_string
    call new_label
    popa
    pop si

    ; Копируем данные в буфер
    mov di,data_text
    xor cx,cx

.data_copy_loop:
    lodsb
    cmp al,0
    je data_copy_end
    cmp al,0x0D
    je data_copy_end
    stosb
    inc cx
    cmp cx,512
    je data_copy_end
    jmp .data_copy_loop

data_copy_end:
    mov [data_size],cx

    ; Выводим отладочную информацию
    mov si,mesge_write_size
    call print_string
    mov ax,[data_size]
    call print_dec
    call new_label

    mov si,data_text
    call print_string
    call new_label

    ; Создаём файл в корневом каталоге
    call find_file
    jnc do_create_already_exists
    call find_free_entry
    jc do_create_disk_full
    call fill_entry_in_buffer_write

    ; Записываем корневой каталог
    mov ax, 19
    call write_root_sector
    jc do_create_error

    mov si, msg_created
    call print_message
    call new_label

    ; Обновляем сегментные регистры
    xor ax,ax
    mov es,ax
    mov ds,ax

    ; Записываем FAT
    mov ax,[data_free_cluster]
    mov bx,0xFF8
    call mark_cluster

    ; Записываем данные в кластер
    mov ax, [data_free_cluster]
    sub ax, 2
    add ax, 33

    mov bx, data_text
    call write_sector

    mov ah,0x0E
    mov al, 'O'
    int 0x10
    mov al, 'K'
    int 0x10
    call new_label

    jmp go_kernel
    jmp go_kernel

msg_no_data:       db 'Error: No data to write!', 0
msg_write_success: db 'Write completed!', 0
msg_dir_full:      db 'Error: Directory full!', 0
;function for write
error_write:
mov si,msg_er_write
call print_string
call new_label
jmp go_kernel
cluster_zero:
mov si,msg_cluster_zero
call print_string
call new_label
; rebot segment register
xor ax,ax
mov es,ax
mov ds,ax
jmp go_kernel
;----------------write data space-------------
msg_er_write: db 'Errror',0
msg_cluster_zero: db 'Cluster Zero cod',0
data_text: times 512 db 0 ,'$';Bufer == Claster
data_size: dw 0
mesge_write_size: db 'Size byte: ',0
mesg_start_copy: db 'start copy',0
data_free_cluster: dw 0

; ------------------------------------------------------------
; mark_cluster - пометить кластер в FAT12
; Вход: AX = номер кластера
;       BX = значение (0x000 - свободен, 0xFF8 - EOC, 0xFF7 - bad)
; Выход: CF=0 - успех, CF=1 - ошибка
; ------------------------------------------------------------
mark_cluster:
    push ax
    push bx
    push cx
    push si
    push ds
    push es

    ; Устанавливаем DS на FAT (0x1000)
    push 0x1000
    pop ds

    ; Вычисляем смещение cluster * 1.5
    mov cx, ax              ; сохраняем номер кластера
    mov si, ax
    shr ax, 1
    add si, ax              ; SI = cluster * 1.5

    ; Читаем текущее слово
    mov ax, [si]

    ; Изменяем нужные 12 бит в зависимости от четности
    test cx, 1
    jz .even

    ; НЕЧЕТНЫЙ кластер: значение в СТАРШИХ 12 битах
    and ax, 0x000F          ; сохраняем младшие 4 бита
    shl bx, 4               ; сдвигаем новое значение в старшие биты
    or ax, bx               ; объединяем
    jmp .write

.even:
    ; ЧЕТНЫЙ кластер: значение в МЛАДШИХ 12 битах
    and ax, 0xF000          ; сохраняем старшие 4 бита
    or ax, bx               ; добавляем новое значение

.write:
    ; Записываем обратно
    mov [si], ax

    clc
    jmp .done

.done:
    pop es
    pop ds
    pop si
    pop cx
    pop bx
    pop ax
    ret
; ------------------------------------------------------------
; find_free_cluster - поиск свободного кластера в FAT12
; Начинает поиск с кластера 3
; Вход:  DS = 0x1000 (FAT загружена по этому адресу)
; Выход: AX = номер свободного кластера (0 = не найдено)
;        CF = 0 - успех, 1 - ошибка/нет места
; ------------------------------------------------------------
find_free_cluster:
    push bx
    push cx
    push si
mov ax,0x1000
mov ds,ax

    mov cx, 3           ; начинаем с кластера 3 (не с 2!)
    xor si, si

.search:
    cmp cx, 4084        ; максимальный кластер для FAT12
    jg .not_found

    ; Вычисляем смещение в FAT для 12-битной записи
    push cx
    mov ax, cx
    mov si, ax
    shr ax, 1
    add si, ax          ; SI = cluster * 1.5

    mov ax, [si]        ; читаем слово из FAT
    pop cx

    ; Извлекаем 12 бит в зависимости от четности кластера
    test cx, 1
    jz .even
    shr ax, 4           ; нечетный - старшие 12 бит
    jmp .check
.even:
    and ax, 0x0FFF      ; четный - младшие 12 бит
.check:
    cmp ax, 0x000       ; свободный кластер?
    je .found

    inc cx
    jmp .search

.not_found:
    xor ax, ax
    stc
    jmp .done

.found:
    mov ax, cx
    clc

.done:
    pop si
    pop cx
    pop bx
    push ax
    xor ax,ax
    mov ds,ax
    pop ax
    ret
; ============================================================
; find_file_offset - ищет файл в Root Dir и возвращает смещение
; Вход:  fat_name = 11 байт имени (8.3 формат, БЕЗ точки)
;        ES должен быть 0x0500 (буфер Root Dir уже загружен)
; Выход: CF=0, found_offset = смещение записи в буфере
;        CF=1, файл не найден
; ============================================================
find_file_offset:
    pusha
    push es

    ; Загружаем Root Directory в 0x0500
    mov ax, 0x0500
    mov es, ax
    xor bx, bx
    mov ax, 19
    mov cx, 14
.read_root:
    call read_sector
    add bx, 512
    inc ax
    loop .read_root

    ; Сканируем записи
    mov ax, 0x0500
    mov es, ax
    xor di, di
    mov cx, 224

.search:
    mov al, [es:di]
    cmp al, 0x00           ; Конец каталога
    je .not_found
    cmp al, 0xE5           ; Удалённый файл
    je .next

    ; Сравниваем имя (11 байт)
    push di
    mov si, fat_name
    push cx
    mov cx, 11
    repe cmpsb
    pop cx
    pop di
    je .found

.next:
    add di, 32
    loop .search

.not_found:
    pop es
    popa
    stc
    ret

.found:
    mov [found_offset], di  ; Сохраняем смещение
    pop es
    popa
    clc
    ret
; ------------------------------------------------------------
; function write, AX LBA Adres,ES:BX
; ------------------------------------------------------------
write_sector:
    pusha
    xor dx, dx
    mov cx, 18
    div cx
    inc dl
    mov cl, dl
    xor dx, dx
    mov ch, 2
    div ch
    mov ch, al
    mov dh, ah
    mov dl, [boot_disk]
    mov ax, 0x0301
    int 0x13

    jnc .ok                   ; Если CF=0 (нет ошибки)

    ; ОШИБКА! Выводим 'E' и номер ошибки
    mov al,ah
    call print_hex_byte
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    mov al, ah                ; AH содержит код ошибки
    add al, '0'
    int 0x10
    call new_label                     ; Зависаем для диагностики
    ;сброс контроллера диска
    mov ah,0
    mov dl,[boot_disk]
    int 13h
    jmp go_kernel
.ok:
    popa
    ret


; ============================================================
; ЗАПОЛНИТЬ ЗАПИСЬ В БУФЕРЕ 0x0500
; ============================================================
fill_entry_in_buffer_write:
    pusha

    mov ax, 0x0500
    mov es, ax
    mov di, [found_offset]

    ; 1. Имя файла (11 байт)
    mov si, fat_name
    mov cx, 11
    rep movsb

    ; 2. Атрибуты (0x20 = архивный)
    mov byte [es:di], 0x20
    inc di

    ; 3. Резерв (10 байт нулей)
    mov cx, 10
    mov al, 0
    rep stosb

    ; 4. Время создания (0)
    mov word [es:di], 0x0000
    add di, 2

    ; 5. Дата создания (0)
    mov word [es:di], 0x0000
    add di, 2
    pusha
    mov ax,[data_free_cluster]
    ; 6. furst claster (nuber furst cluster)
    mov word [es:di], ax
    popa
    add di, 2
    pusha
    mov ax,[data_size]
    ; 7. Размер файла (4 байта = 0)
    mov word [es:di],ax
    popa
    add di, 2
    mov word [es:di], 0x0000

    popa
    ret
; -----------------------------------------------------------------------------
; ДАННЫЕ ДЛЯ ФАЙЛОВОЙ СИСТЕМЫ
; -----------------------------------------------------------------------------
fat_name:       times 12 db 0
first_cluster:  dw 0
file_size:      dw 0
current_cluster: dw 0
fat_loaded:     db 0

prog_cluster:   dw 0
prog_size:      dw 0

msg_not_found:  db 'File not found!', 13, 10, 0
msg_loaded:     db 'Loaded: ', 0
msg_running:    db 'Running program...', 0
msg_done:       db 'Program finished.', 0
cmd_load:  db 'load', 0
cmd_run:   db 'run', 0
; ============================================================
; ДЕТЕКТОР ФЛОППИ-ДИСКОВОДОВ ЧЕРЕЗ CMOS (16 бит)
; ============================================================
detect_floppy_drives:
    pusha

    mov si, msg_fdd_detect_start
    call print_string
    call new_label

    ; Читаем CMOS ячейку 0x10
    mov al, 0x10
    out 0x70, al
    in al, 0x71          ; AL = информация о дисководах

    ; Сохраняем сырое значение для отладки
    mov [cmos_raw_value], al

    ; Выводим сырое значение
    mov si, msg_cmos_raw
    call print_string
    movzx ax, byte [cmos_raw_value]
    call print_hex
    call new_label

    ; Извлекаем Primary (старшие 4 бита)
    mov al, [cmos_raw_value]
    shr al, 4
    and al, 0x0F
    mov [primary_type], al

    ; Извлекаем Secondary (младшие 4 бита)
    mov al, [cmos_raw_value]
    and al, 0x0F
    mov [secondary_type], al

    ; === ВЫВОД ИНФОРМАЦИИ О PRIMARY ===
    mov si, msg_primary
    call print_string

    mov al, [primary_type]
    call fdd_type_string
    call print_string
    call new_label

    ; Доп. информация о типе
    cmp byte [primary_type], 4
    jne .check_primary_other

    ; Это 1.44 МБ - стандартный дисковод!
    mov si, msg_primary_1440_detected
    call print_string
    call new_label

    mov byte [fdd_available], 1

.check_primary_other:
    cmp byte [primary_type], 0
    jne .primary_available
    jmp .check_secondary

.primary_available:
    mov byte [fdd_available], 1

    ; === ВЫВОД ИНФОРМАЦИИ О SECONDARY ===
.check_secondary:
    mov si, msg_secondary
    call print_string

    mov al, [secondary_type]
    call fdd_type_string
    call print_string
    call new_label

    cmp byte [secondary_type], 4
    jne .done

    mov si, msg_secondary_1440_detected
    call print_string
    call new_label

.done:
    ; Итоговая информация
    call new_label
    mov si, msg_fdd_summary
    call print_string
    call new_label

    cmp byte [fdd_available], 1
    je .fdd_found

    ; Дисководов нет
    mov si, msg_no_fdd
    call print_string
    call new_label
    jmp .exit

.fdd_found:
    mov si, msg_fdd_detected
    call print_string
    call new_label

    ; Выводим параметры дисковода (стандартные для 1.44MB)
    mov si, msg_fdd_params
    call print_string
    call new_label

    mov si, msg_cylinders
    call print_string
    mov ax, 80
    call print_dec
    call new_label

    mov si, msg_heads
    call print_string
    mov ax, 2
    call print_dec
    call new_label

    mov si, msg_sectors
    call print_string
    mov ax, 18
    call print_dec
    call new_label

    mov si, msg_total_size
    call print_string
    mov ax, 2880          ; 80*2*18 = 2880 секторов
    call print_dec
    mov si, msg_sectors_text
    call print_string
    call new_label
    mov ax, 1440          ; 2880 * 512 / 1024 = 1440 КБ
    call print_dec
    mov si, msg_kb_text
    call print_string
    call new_label

.exit:
    popa
    ret

; Данные
cmos_raw_value:    db 0
primary_type:      db 0
secondary_type:    db 0
fdd_available:     db 0

msg_fdd_detect_start: db 'Floppy detection start...', 0
msg_cmos_raw:         db 'CMOS raw value: 0x', 0
msg_primary:          db 'Primary: ', 0
msg_secondary:        db 'Secondary: ', 0
msg_primary_1440_detected:   db '1.44MB drive detected as primary!', 0
msg_secondary_1440_detected: db '1.44MB drive detected as secondary!', 0
msg_fdd_summary:      db '--- Summary ---', 0
msg_no_fdd:           db 'No floppy drives found!', 0
msg_fdd_detected:     db 'Floppy drive(s) detected!', 0
msg_fdd_params:       db 'Standard 1.44MB parameters:', 0
msg_cylinders:        db 'Cylinders: ', 0
msg_heads:            db 'Heads: ', 0
msg_sectors:          db 'Sectors per track: ', 0
msg_total_size:       db 'Total: ', 0
msg_sectors_text:     db ' sectors (', 0
msg_kb_text:          db ' KB)', 0
; ============================================================
; fdd_type_string — возвращает строку с типом дисковода
; Вход: AL = код типа (0-5)
; Выход: SI = указатель на строку
; ============================================================
fdd_type_string:
    push ax

    cmp al, 0
    je .type_0
    cmp al, 1
    je .type_1
    cmp al, 2
    je .type_2
    cmp al, 3
    je .type_3
    cmp al, 4
    je .type_4
    cmp al, 5
    je .type_5

    ; Неизвестный тип
    mov si, msg_unknown_type
    jmp .done

.type_0:
    mov si, msg_no_drive
    jmp .done
.type_1:
    mov si, msg_360kb
    jmp .done
.type_2:
    mov si, msg_12mb
    jmp .done
.type_3:
    mov si, msg_720kb
    jmp .done
.type_4:
    mov si, msg_144mb
    jmp .done
.type_5:
    mov si, msg_288mb
    jmp .done

.done:
    pop ax
    ret

; Строки с названиями типов
msg_no_drive:      db 'No drive', 0
msg_360kb:         db '360 KB (5.25")', 0
msg_12mb:          db '1.2 MB (5.25")', 0
msg_720kb:         db '720 KB (3.5")', 0
msg_144mb:         db '1.44 MB (3.5")', 0
msg_288mb:         db '2.88 MB (3.5")', 0
msg_unknown_type:  db 'Unknown type', 0
;------------------------------print-----------------
print_help:
mov si,help_message
call print_message
call new_label
mov si,help_message1
call print_message
call new_label
mov si,help_message2
call print_message
call new_label
jmp go_kernel
print_prog:
mov si,mesage
call print_message
call new_label
mov si,message1
call print_message
call new_label
mov si,message2
call print_message
call new_label
jmp go_kernel
print_sys_inf:
mov si,system_mesg
call print_message
call new_label
jmp go_kernel
cmd_color_clear_scren:
call clear_screen_color
jmp go_kernel
clear_screen:
pusha
mov ah,0x02
mov bh,0x00
mov dh,0x00
mov dl,0x00
int 0x10
mov cx,80*25
mov ah,0x0E
mov al,' '
clear_loop:
int 0x10
loop clear_loop
popa
mov ah,0x02
mov bh,0x00
mov dh,0x00
mov dl,0x00
int 0x10
jmp go_kernel
message_eror_disk: db 'error disk',0
mesg_succes_install: db 'os installed',0
;----------------------------------EROR and KERNEL PANIC---------------------------------
error_disk:
mov si,message_eror_disk
call print_message
call new_label
jmp go_kernel
go_kernel:
xor ax,ax
mov di,comand
mov cx,256
rep stosb
jmp BEGIN
;-----------------------------command------------------
comand: times 256 db 0
help_com: db 'help',0
prog1: db 'prog1',0
com_inf_disk: db 'disk-i-s',0
inf_com: db 'sys-i',0
clear_com: db 'clear',0
install_com: db 'install os',0
fmp_com: db 'fmp help',0
create_fmp_com: db 'fmp create',0
data_fmp_com: db 'fmp data',0
ls_fmp_com: db 'fmp ls',0
flopy_fmp_com: db 'fmp flopy',0

disk_fmp_com: db 'fmp disk',0

fmp_install_flopy2: db 'fmp flopy2 install app',0
adres_com: db 'adres',0
com_mmm_call: db 'call programm',0
com_list: db 'ls',0
comand_type: db 'type',0
cmd_create: db 'create', 0
cmd_write: db 'write',0
ru_com: db 'ru-com',0
cmd_tasks: db 'tasks', 0
cmd_kill:  db 'kill', 0
cmd_a: db 'A:',0
cmd_b: db 'B:',0
;----------------------------mesg---------------------
mesage: db 'programm start',0
message1: db   'start kernel sucssec!', 0
message2: db   'Hello Welcom to Plan B.',0
message3: db   'for to help menu write command help',0
help_message: db    'welcom to help menu',0
help_message1: db   'command1 help open help menu',0
help_message2: db 'command2 prog1 open programm1',0ah,0dh,'command3 disk-i-s print disk sector inform',0ah,0dh,'command4 sys-i print system information',0ah,0dh,'command5 clear is clear screen',0ah,0dh,0
system_mesg: db 'Operation system Neko',0ah,0dh,'version 0.47+',0ah,0dh,'cod name Silence',0
fmp_help_msg: db 'File Memory Protocol',0ah,0dh,'Main command',0ah,0dh,'1. fmp help is list comand fmp',0ah,0dh,'2. fmp create (name file) is create file on hdd',0ah,0dh,'3. fmp ls is scan file on hdd',0
ru_mesg: db 'Привет мир попытка русификации или украинизации',0
msg_load_start:     db '=== LOAD START ===', 13, 10, 0
msg_parsed_name:    db 'Parsed name: "', 0
msg_file_found:     db 'File found on disk!', 13, 10, 0
msg_free_slot_ok:   db 'Free slot found at: 0x', 0
msg_add_task_start: db '=== ADD TASK START ===', 13, 10, 0
msg_fat_name_is:    db 'fat_name to add: "', 0
msg_slot_addr:      db 'Slot address: 0x', 0
msg_slot_free:      db 'Slot is FREE, copying...', 13, 10, 0
msg_slot_busy:      db 'ERROR: Slot is BUSY!', 13, 10, 0
msg_slot_content:   db 'Current slot content: "', 0
msg_write_check:    db 'After copy, slot contains: "', 0
msg_segment_is:     db 'Segment in table: 0x', 0
; ------------------------------------------------------------
; ДАННЫЕ ДЛЯ МЕНЕДЖЕРА ЗАДАЧ
; ------------------------------------------------------------
msg_task_header: db '=== Loaded Tasks ===', 0
msg_loaded_ok:   db 'Loaded and added to task table.', 0
msg_task_full:   db 'Task table is full! Cannot load.', 0
msg_kill_ok:     db 'Task removed.', 0
load_segment:    dw 0
;-----------------------------------BOOT DISK---------------------------------------------------
boot_disk: db 0
;-------------------------------File memory Protocol---------------------
FMP:
db 'name:'
name_file: times 20 db 1
db 0
db 'vd:'
virtual_diretcion: times 20 db 1
db 0
db 'data:'
data_file: times 250 db 1
db 0
end: db '.end',0
end_kernel:db 0
;------------------------------------------------------MMM--------------------------------------------------
MMM:

