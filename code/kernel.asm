use16
 section .text
 org 0x7E00
 use16
section .text

procedur_init:
mov [boot_disk],dl
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
    sti
call get_memory_map
jc error_get_memory
run_protection_mod:
mov si,enter_msg
call print_message
xor ax,ax
int 16h
cmp al,13
jz enter_protected_mode
error_get_memory:
    mov si,msg_error_memory
    call print_message
    jmp BEGIN
enter_msg: db 'Press enter for start Os',0
msg_error_memory: db 'Total memory error. Critical Error,Fatal memory. Neko Dos subsystem start',0
; ============================================================
; ПОЛУЧЕНИЕ КАРТЫ ПАМЯТИ ЧЕРЕЗ INT 0x15, EAX=0xE820
; ============================================================

get_memory_map:
    pusha
    mov di, memory_map_buffer
    xor ebx, ebx
    mov byte [memory_map_count], 0
    jmp .next_entry

.next_entry:
    mov eax, 0xE820
    mov ecx, 24
    mov edx, 0x534D4150
    int 0x15
    jc .error
    cmp eax, 0x534D4150
    jne .error

    add di, 24
    inc byte [memory_map_count]

    cmp ebx, 0
    je .done
    jmp .next_entry

.error:
    mov byte [memory_map_count], 0
    stc
    jmp .exit

.done:
    clc

.exit:
    popa
    ret

; ============================================================
; ВЫВОД КАРТЫ ПАМЯТИ - ЧАСТЬ 1 (ЗАГОЛОВОК)
; ============================================================
print_memory_map:
    pusha
    cmp byte [memory_map_count], 0
    jne .has_data
    mov si, msg_no_memory_map
    call print_string
    jmp .exit

.has_data:
    mov si, msg_memory_header
    call print_string
    mov al, [memory_map_count]
    call print_byte_dec
    call new_label

    ; Инициализация обхода блоков
    mov si, memory_map_buffer
    mov byte [.block_index], 0
    jmp .next_block

.block_index: db 0

; ============================================================
; ВЫВОД КАРТЫ ПАМЯТИ - ЧАСТЬ 2 (ОБХОД БЛОКОВ)
; ============================================================
.next_block:
    mov al, [.block_index]
    cmp al, [memory_map_count]
    jae .done_blocks

    ; Сохраняем текущий блок
    push si

    ; Выводим номер блока
    mov si, msg_block_num
    call print_string
    mov al, [.block_index]
    inc al
    call print_byte_dec
    mov si, msg_colon
    call print_string
    call new_label

    ; Восстанавливаем указатель блока
    pop si
    push si

    ; Базовый адрес
    mov si, msg_base
    call print_string
    mov eax, [si]
    call print_hex_word
    mov eax, [si+4]
    call print_hex_word
    call new_label

    pop si
    push si

    ; Длина
    mov si, msg_length
    call print_string
    mov eax, [si+8]
    call print_hex_word
    mov eax, [si+12]
    call print_hex_word
    call new_label

    pop si
    push si

    ; Тип памяти
    mov si, msg_type
    call print_string
    mov eax, [si+16]
    call print_hex_word
    call print_type_string

    call new_label
    call new_label

    pop si
    add si, 24
    inc byte [.block_index]
    jmp .next_block

.done_blocks:
    call calculate_usable_ram
    jmp .exit

.exit:
    popa
    ret

; ============================================================
; ВЫВОД СТРОКИ ТИПА ПАМЯТИ
; ============================================================
print_type_string:
    pusha
    mov eax, [si+16]
    cmp eax, 1
    je .usable
    cmp eax, 2
    je .reserved
    cmp eax, 3
    je .acpi
    cmp eax, 4
    je .nvs
    jmp .unknown

.usable:
    mov si, msg_usable
    call print_string
    jmp .done
.reserved:
    mov si, msg_reserved
    call print_string
    jmp .done
.acpi:
    mov si, msg_acpi
    call print_string
    jmp .done
.nvs:
    mov si, msg_nvs
    call print_string
    jmp .done
.unknown:
    mov si, msg_unknown
    call print_string
.done:
    popa
    ret

; ============================================================
; ПОДСЧЁТ ДОСТУПНОЙ RAM - ЧАСТЬ 1
; ============================================================
calculate_usable_ram:
    pusha
    xor eax, eax
    xor edx, edx

    mov si, memory_map_buffer
    mov byte [.block_index], 0
    jmp .sum_loop

.block_index: db 0
.total_low: dd 0
.total_high: dd 0

; ============================================================
; ПОДСЧЁТ ДОСТУПНОЙ RAM - ЧАСТЬ 2 (СУММИРОВАНИЕ)
; ============================================================
.sum_loop:
    mov al, [.block_index]
    cmp al, [memory_map_count]
    jae .done_sum

    cmp dword [si+16], 1
    jne .next_sum

    add eax, [si+8]
    adc edx, [si+12]

.next_sum:
    add si, 24
    inc byte [.block_index]
    jmp .sum_loop

.done_sum:
    mov [total_ram_low], eax
    mov [total_ram_high], edx
    jmp .print_result

; ============================================================
; ПОДСЧЁТ ДОСТУПНОЙ RAM - ЧАСТЬ 3 (ВЫВОД)
; ============================================================
.print_result:
    mov si, msg_total_ram
    call print_string

    mov ebx, eax
    shr ebx, 20
    mov eax, ebx
    call print_dec
    mov si, msg_mb
    call print_string

    cmp dword [total_ram_high], 0
    je .no_high

    mov si, msg_plus
    call print_string
    mov eax, [total_ram_high]
    shl eax, 12
    call print_dec
    mov si, msg_mb
    call print_string

.no_high:
    call new_label
    popa
    ret

; ============================================================
; ТЕСТОВАЯ ФУНКЦИЯ
; ============================================================
test_memory_map:
    call get_memory_map
    jc .error
    call print_memory_map
    jmp .done

.error:
    mov si, msg_fatal_error
    call print_string
    call new_label

.done:
    ret

; ============================================================
; ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
; ============================================================
print_byte_dec:
    pusha
    xor ah, ah
    mov bl, 10
    div bl
    add al, '0'
    add ah, '0'
    call print_char
    mov al, ah
    call print_char
    popa
    ret

; ============================================================
; ДАННЫЕ
; ============================================================
align 4
memory_map_count:   db 0
memory_map_buffer:  times 256 * 24 db 0

total_ram_low:      dd 0
total_ram_high:     dd 0

msg_no_memory_map:  db 'E820 not supported!', 0
msg_fatal_error:    db 'Fatal: Cannot get memory map!', 0
msg_memory_header:  db 'Memory Map: ', 0
msg_block_num:      db 'Block #', 0
msg_base:           db '  Base: 0x', 0
msg_length:         db '  Length: 0x', 0
msg_type:           db '  Type: 0x', 0
msg_usable:         db ' (Usable RAM)', 0
msg_reserved:       db ' (Reserved)', 0
msg_acpi:           db ' (ACPI Reclaim)', 0
msg_nvs:            db ' (ACPI NVS)', 0
msg_unknown:        db ' (Unknown)', 0
msg_total_ram:      db 'Total Usable RAM: ', 0
msg_mb:             db ' MB', 0
msg_plus:           db ' + ', 0
msg_colon:          db ': ', 0



interput20:
xor ax,ax
mov ds,ax
mov es,ax
mov ss,ax
mov sp,[steck_save]
call new_label
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

    ; 8. Загружаем файл в буфер 0x5000:0x0000
    mov ax, 0x5000
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
    ; 9. Жёстко восстанавливаем сегменты программы
    mov ax, 0x3000
    mov ds, ax
    mov es, ax

    pop ds
    pop es
    popa
    mov ax, 1
    clc
    iret

.not_found:
    ; Восстанавливаем сегменты программы
    mov ax, 0x3000
    mov ds, ax
    mov es, ax

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
mov si,int21_file_name
call print_string
call new_label
mov si,int21_file_name
call parse_filename
mov si,fat_name
call print_string
call new_label
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
;-------------------int 21h Ah=40h Write to file--------------
int21_write_file:
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
mov si,copy_msg
call print_string
mov si,write_page
call print_string
call new_label


mov si,fat_name
call print_string
call new_label
call find_free_cluster
jc error_write
mov [data_free_cluster],ax
test ax,ax
jz cluster_zero
call print_hex_word
call new_label
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



;-------clear Write Page----
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
    mov ax,0x5000
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


BEGIN:
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
KERNEL:
mov ah,0x00
int 0x16
stosb
cmp al,13
jz comands

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
;----------------------------Обработчик команд--------------------------
    comands:
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
jz clear_screen
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
; -------------------------------------------------
do_type:
    ; Парсим имя файла (пропускаем "type ")
    mov si, comand+5          ; Пропускаем "type "
    call parse_filename       ; Преобразуем в 11-байтовый формат

    ; Ищем файл в каталоге
    call find_file
    jc .not_found

    ; Загружаем FAT (если ещё не)
    call load_fat

    ; Грузим и выводим файл по одному сектору
    mov ax, [first_cluster]
    mov [current_cluster], ax

.print_loop:
    mov ax, [current_cluster]
    cmp ax, 0xFF8
    jae .done

    ; Читаем сектор в буфер
    push es
    mov ax, 0x3000            ; Буфер для файла
    mov es, ax
    xor bx, bx
    mov ax, [current_cluster]
    sub ax, 2
    add ax, 33
    call read_sector

    ; Выводим содержимое буфера (512 байт или до конца файла)
    mov cx, 512
    xor si, si
.print_bytes:
    mov al, [es:si]
    cmp al, 0                 ; Если встретили 0 - конец текста?
    je .done_print
    call print_char
    inc si
    loop .print_bytes

.done_print:
    pop es

    ; Получаем следующий кластер
    mov ax, [current_cluster]
    call get_next_cluster
    mov [current_cluster], ax
    jmp .print_loop

.done:
    call new_label
    jmp go_kernel

.not_found:
    mov si, msg_not_found
    call print_message
    jmp go_kernel

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
; КОМАНДА WRITE (РАБОТАЕТ С ДАННЫМИ!)
; ============================================================


do_write:
mov si,comand+6
call parse_filename
mov si,fat_name
call print_string
call new_label
call find_free_cluster
jc error_write
mov [data_free_cluster],ax
test ax,ax
jz cluster_zero
call print_hex_word
call new_label
mov si,comand+6
mov cx,100
xor ax,ax
data_copy_start:
lodsb
cmp al,','
jz .next
mov ah,0x0E
int 10h
loop data_copy_start
.next:
;inc si
push si
pusha
call new_label
mov si,mesg_start_copy
call print_string
call new_label
popa
pop si
mov di,data_text
xor cx,cx
data_copy:
lodsb
cmp al,0
jz data_copy_end
stosb
inc cx
jmp data_copy
data_copy_end:
mov [data_size],cx
mov si,mesge_write_size
call print_string
mov ax,[data_size]
call print_dec
call new_label
mov si,data_text
call print_string
call new_label
;create file in ROOT
call find_file
jnc do_create_already_exists
call find_free_entry
jc do_create_disk_full
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
jmp go_kernel
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
;----------------------------mesg---------------------
mesage: db 'programm start',0
message1: db   'start kernel sucssec!', 0
message2: db   'Hello Welcom to Plan B.',0
message3: db   'for to help menu write command help',0
help_message: db    'welcom to help menu',0
help_message1: db   'command1 help open help menu',0
help_message2: db 'command2 prog1 open programm1',0ah,0dh,'command3 disk-i-s print disk sector inform',0ah,0dh,'command4 sys-i print system information',0ah,0dh,'command5 clear is clear screen',0ah,0dh,0
system_mesg: db 'Operation system Neko',0ah,0dh,'version 17+',0ah,0dh,'cod name Silence',0
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
; ============================================================
; ПОЛНЫЙ ВХОД В ЗАЩИЩЁННЫЙ РЕЖИМ С ДИНАМИЧЕСКОЙ GDT
; ============================================================

enter_protected_mode:
    cli                     ; Запрещаем прерывания

    ; 1. Получаем карту памяти и вычисляем общий объём
    call get_memory_map
    jc .error
    call calculate_usable_ram  ; В EDX:EAX общий объём RAM

    ; 2. Создаём динамическую GDT на основе полученной памяти
    push eax
    call setup_dynamic_gdt
    pop eax

    ; 3. Включаем A20 через Fast A20 (порт 0x92)
    in al, 0x92
    or al, 0x02
    out 0x92, al

    ; 4. Загружаем GDT
    lgdt [gdt_descriptor]

    ; 5. Переключаемся в защищённый режим (бит PE)
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; 6. Дальний прыжок для очистки конвейера
    jmp CODE_SEG:protected_start

.error:
    ; Если не удалось получить карту памяти - используем стандартные значения
    mov eax, 0x1000000      ; 16MB по умолчанию
    call setup_dynamic_gdt
    jmp enter_protected_mode

; ============================================================
; ДИНАМИЧЕСКАЯ GDT (упрощённая версия для твоего кода)
; ============================================================

setup_dynamic_gdt:
    pusha

    ; Размещаем GDT по адресу 0x1000 (как у тебя в коде)
    mov edi, 0x1000
    mov [gdt_address], edi

    ; Получаем лимит из общей памяти
    ; EAX уже содержит total_ram_bytes (из calculate_usable_ram)
    shr eax, 12             ; Делим на 4096 (переводим в 4KB блоки)
    dec eax                 ; Лимит = количество блоков - 1
    cmp eax, 0xFFFFF
    jbe .limit_ok
    mov eax, 0xFFFFF        ; Максимальное значение для 20 бит
.limit_ok
    mov [gdt_limit_blocks], ax

    ; ---- NULL дескриптор (8 байт) ----
    mov dword [edi], 0
    mov dword [edi+4], 0
    add edi, 8

    ; ---- CODE дескриптор (8 байт) ----
    ; limit_low (младшие 16 бит)
    mov ax, [gdt_limit_blocks]
    mov [edi], ax

    ; base_low = 0
    mov word [edi+2], 0

    ; base_mid = 0
    mov byte [edi+4], 0

    ; access = 0x9A (P=1, DPL=0, S=1, Type=Code: Execute/Read)
    mov byte [edi+5], 0x9A

    ; flags + limit_high
    mov ax, [gdt_limit_blocks]
    shr ax, 16
    and al, 0x0F
    or al, 0xCF             ; G=1 (4KB), DB=1 (32-bit)
    mov byte [edi+6], al

    ; base_high = 0
    mov byte [edi+7], 0
    add edi, 8

    ; ---- DATA дескриптор (8 байт) ----
    ; limit_low
    mov ax, [gdt_limit_blocks]
    mov [edi], ax

    ; base_low = 0
    mov word [edi+2], 0

    ; base_mid = 0
    mov byte [edi+4], 0

    ; access = 0x92 (P=1, DPL=0, S=1, Type=Data: Read/Write)
    mov byte [edi+5], 0x92

    ; flags + limit_high
    mov ax, [gdt_limit_blocks]
    shr ax, 16
    and al, 0x0F
    or al, 0xCF
    mov byte [edi+6], al

    ; base_high = 0
    mov byte [edi+7], 0
    add edi, 8

    ; Вычисляем размер GDT
    mov ax, di
    sub ax, word [gdt_address]
    dec ax
    mov [gdt_descriptor], ax
    mov dword [gdt_descriptor+2], 0x1000

    popa
    ret

; ============================================================
; 32-БИТНЫЙ КОД
; ============================================================
bits 32
protected_start:
    ; Настраиваем сегментные регистры
    mov ax, DATA_SEG
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Настраиваем стек (например, в начало свободной памяти)
    mov esp, [total_ram_low]
    sub esp,4096
    and esp,0xFFFFFFF0
    ; Очищаем экран
    call clear_screen32

    ; Выводим приветствие
    mov esi, msg_protected_mode
    call print_string32

    ; Выводим информацию о памяти
    call show_memory_info


    ; Продолжение твоего ядра...
    call new_line32
    call detect_interrupt_controller
    call disable_pic
    call init_lapic
    call setup_ioapic
    call detect_and_init_timer
    mov eax,[total_ram_low]
    call init_memory_manager


    ; ... предыдущий код ...

    ; Загружаем IDT
    lidt [idt_descriptor]

    ; РАЗРЕШАЕМ прерывания
    sti
    cmp dword [lapic_timer_available],1
    jne .no_timer

    mov esi, msg_idt_loaded
    call print_string32
    call new_line32
    mov esi,debug_page_msg
    call print_string32
    call allocate_physical_page_v2
    mov [num_root],eax
    mov [root_dd],edx
    call print_dec32
    call new_line32

    ;call test_timer
    ;test divide ZERO
    ;mov eax,10
    ;mov ecx,0
    ;div ecx
    jmp shel32
    .no_timer:
    jmp $
    num_root: dd 0
    root_dd: dd 0
    debug_page_msg: db 'Page number ',0

    ;------------------------IDT--------------
; ============================================================
; МАКРОС ДЛЯ IDT В 32-БИТНОМ РЕЖИМЕ (8 байт на запись)
; ============================================================
%macro idt_entry 2
    dw (%1 & 0xFFFF)         ; offset low (биты 0-15)
    dw 0x08                  ; selector (code segment)
    db 0                     ; reserved
    db %2                    ; access rights (0x8E = Interrupt Gate, 0x8F = Trap Gate)
    dw ((%1 >> 16) & 0xFFFF) ; offset high (биты 16-31)
%endmacro

align 16

idt_start:
    ; === ИСКЛЮЧЕНИЯ CPU (0-31) ===
    idt_entry divide_error, 0x8E      ; 0 - Division Error
    idt_entry debug_exception, 0x8E   ; 1 - Debug
    idt_entry nmi_handler, 0x8E       ; 2 - NMI
    idt_entry breakpoint_handler, 0x8F ; 3 - Breakpoint (Trap Gate!)
    idt_entry overflow_handler, 0x8E  ; 4 - Overflow
    idt_entry bound_handler, 0x8E     ; 5 - Bound Range
    idt_entry invalid_opcode, 0x8E    ; 6 - Invalid Opcode
    idt_entry no_math, 0x8E           ; 7 - Device Not Available
    idt_entry double_fault, 0x8E      ; 8 - Double Fault
    idt_entry plug_handler, 0x8E      ; 9 - Coprocessor Segment Overrun
    idt_entry invalid_tss, 0x8E       ; 10 - Invalid TSS
    idt_entry no_segment, 0x8E        ; 11 - Segment Not Present
    idt_entry stack_fault, 0x8E       ; 12 - Stack Fault
    idt_entry general_protection, 0x8E ; 13 - General Protection Fault
    idt_entry page_fault, 0x8E        ; 14 - Page Fault
    idt_entry plug_handler, 0x8E      ; 15 - Reserved
    idt_entry math_fault, 0x8E        ; 16 - x87 FPU Error
    idt_entry alignment_check, 0x8E   ; 17 - Alignment Check
    idt_entry machine_check, 0x8E     ; 18 - Machine Check
    idt_entry simd_fault, 0x8E        ; 19 - SIMD Exception
    idt_entry virt_exception, 0x8E    ; 20 - Virtualization Exception
    idt_entry plug_handler, 0x8E      ; 21-31 Reserved
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E
    idt_entry plug_handler, 0x8E

    ; === АППАРАТНЫЕ ПРЕРЫВАНИЯ (32-47) ===
    idt_entry irq0_handler, 0x8E      ; 32 (0x20) - Таймер
    idt_entry irq1_handler, 0x8E      ; 33 (0x21) - Клавиатура
    idt_entry plug_handler, 0x8E      ; 34 (0x22) - Каскад PIC (не исп.)
    idt_entry plug_handler, 0x8E      ; 35 (0x23) - COM2
    idt_entry plug_handler, 0x8E      ; 36 (0x24) - COM1
    idt_entry plug_handler, 0x8E      ; 37 (0x25) - LPT2
    idt_entry irq6_handler, 0x8E      ; 38 (0x26) - Floppy
    idt_entry plug_handler, 0x8E      ; 39 (0x27) - LPT1
    idt_entry plug_handler, 0x8E      ; 40 (0x28) - RTC
    idt_entry plug_handler, 0x8E      ; 41 (0x29) - ACPI
    idt_entry plug_handler, 0x8E      ; 42 (0x2A) - NIC
    idt_entry plug_handler, 0x8E      ; 43 (0x2B) - USB
    idt_entry plug_handler, 0x8E      ; 44 (0x2C) - PS/2 Mouse
    idt_entry plug_handler, 0x8E      ; 45 (0x2D) - FPU
    idt_entry plug_handler, 0x8E      ; 46 (0x2E) - Primary HDD
    idt_entry plug_handler, 0x8E      ; 47 (0x2F) - Secondary HDD

    ; === ПОЛЬЗОВАТЕЛЬСКИЕ ПРЕРЫВАНИЯ (48-255) ===
    %assign i 48
    %rep (256 - 48)
        idt_entry plug_handler, 0x8E
    %assign i i+1
    %endrep

idt_end:

idt_descriptor:
    dw idt_end - idt_start - 1    ; Размер IDT - 1
    dd idt_start                   ; Адрес IDT (32-бит!)
; ============================================================
; ЗАГЛУШКИ ДЛЯ ВСЕХ ИСКЛЮЧЕНИЙ
; ============================================================

; 0 - Division Error
divide_error:
    push 0
    jmp exception_common

; 1 - Debug Exception
debug_exception:
    push 1
    jmp exception_common

; 2 - NMI (Non-Maskable Interrupt)
nmi_handler:
    push 2
    jmp exception_common

; 3 - Breakpoint
breakpoint_handler:
    push 3
    jmp exception_common

; 4 - Overflow
overflow_handler:
    push 4
    jmp exception_common

; 5 - Bound Range Exceeded
bound_handler:
    push 5
    jmp exception_common

; 6 - Invalid Opcode
invalid_opcode:
    push 6
    jmp exception_common

; 7 - Device Not Available (No Math Coprocessor)
no_math:
    push 7
    jmp exception_common

; 8 - Double Fault
double_fault:
    push 8
    jmp exception_common

; 9 - Coprocessor Segment Overrun (устарело)
; Используем plug_handler или отдельную заглушку

; 10 - Invalid TSS
invalid_tss:
    push 10
    jmp exception_common

; 11 - Segment Not Present
no_segment:
    push 11
    jmp exception_common

; 12 - Stack-Segment Fault
stack_fault:
    push 12
    jmp exception_common

; 13 - General Protection Fault
general_protection:
    push 13
    jmp exception_common

; 14 - Page Fault
page_fault:
    push 14
    jmp exception_common

; 15 - Reserved

; 16 - x87 Floating-Point Exception
math_fault:
    push 16
    jmp exception_common

; 17 - Alignment Check
alignment_check:
    push 17
    jmp exception_common

; 18 - Machine Check
machine_check:
    push 18
    jmp exception_common

; 19 - SIMD Floating-Point Exception
simd_fault:
    push 19
    jmp exception_common

; 20 - Virtualization Exception
virt_exception:
    push 20
    jmp exception_common

; ============================================================
; ОБЩИЙ ОБРАБОТЧИК ИСКЛЮЧЕНИЙ
; ============================================================
exception_common:
    pusha

    ; Выводим сообщение
    mov esi, msg_exception
    call print_string32

    ; Достаём номер ошибки (он был push перед jmp)
    mov eax, [esp + 32]    ; 8 регистров * 4 байта = 32
    call print_dec32

    call new_line32

    mov esi, msg_exception_halt
    call print_string32
    call new_line32

    ; Выводим регистры для отладки
    mov esi, msg_eax
    call print_string32
    mov eax, [esp + 28]
    call print_hex32
    call new_line32

    mov esi, msg_ecx
    call print_string32
    mov eax, [esp + 24]
    call print_hex32
    call new_line32

    mov esi, msg_edx
    call print_string32
    mov eax, [esp + 20]
    call print_hex32
    call new_line32

    mov esi, msg_ebx
    call print_string32
    mov eax, [esp + 16]
    call print_hex32
    call new_line32

    mov esi, msg_esp
    call print_string32
    mov eax, [esp + 12]
    call print_hex32
    call new_line32

    mov esi, msg_ebp
    call print_string32
    mov eax, [esp + 8]
    call print_hex32
    call new_line32

    mov esi, msg_esi
    call print_string32
    mov eax, [esp + 4]
    call print_hex32
    call new_line32

    mov esi, msg_edi
    call print_string32
    mov eax, [esp]
    call print_hex32
    call new_line32

    ; Зависаем
    cli
    hlt
    jmp $

; ============================================================
; ЗАГЛУШКА ДЛЯ НЕИСПОЛЬЗУЕМЫХ ВЕКТОРОВ
; ============================================================
plug_handler:
    pusha
    mov esi, msg_plug
    call print_string32
    call new_line32
    popa
    iret

; ============================================================
; ОБРАБОТЧИК ТАЙМЕРА (IRQ0 / вектор 0x20)
; ============================================================
irq0_handler:
    pushad

    ; Увеличиваем счётчик тиков
    inc dword [timer_ticks]

    ; Проверяем, есть ли callback для одноразового таймера
    cmp dword [timer_callback], 0
    je .no_callback

    ; Вызываем callback
    mov eax, [timer_callback]
    mov dword [timer_callback], 0    ; Очищаем перед вызовом
    call eax                         ; Вызываем функцию

.no_callback:
    ; Здесь будет планировщик (в будущем)

    call send_eoi
    popad
    iret
; ============================================================
; ДРАЙВЕР КЛАВИАТУРЫ
; ============================================================

; Таблица скан-кодов для US раскладки (без Shift)
keymap_lower:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0
    db 0, 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0
    db 0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`'
    db 0, '\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0
    db '*', 0, ' ', 0

; Таблица скан-кодов с Shift
keymap_upper:
    db 0, 0, '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 0
    db 0, 'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 0
    db 0, 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', '"', '~'
    db 0, '|', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '<', '>', '?', 0
    db '*', 0, ' ', 0

; Переменные драйвера
keyboard_shift: db 0
keyboard_caps:  db 0
keyboard_ctrl:  db 0
keyboard_alt:   db 0

; ============================================================
; ОСНОВНОЙ ОБРАБОТЧИК КЛАВИАТУРЫ (IRQ1)
; ============================================================
irq1_handler:
    pushad

    ; Читаем скан-код
    xor eax, eax
    in al, 0x60
     mov byte [key_ready],1
    ; Проверяем: отпускание клавиши (старший бит = 1)?
    test al, 0x80
    jnz .key_release

    ; === НАЖАТИЕ КЛАВИШИ ===
    cmp al, 0x2A        ; Left Shift
    je .shift_press
    cmp al, 0x36        ; Right Shift
    je .shift_press
    cmp al, 0x3A        ; Caps Lock
    je .caps_press
    cmp al, 0x1D        ; Left Ctrl
    je .ctrl_press
    cmp al, 0x38        ; Left Alt
    je .alt_press

    ; Проверяем специальные клавиши
    cmp al, 0x0E        ; Backspace
    je .backspace
    cmp al, 0x1C        ; Enter
    je .enter

    ; Обычная клавиша - выводим символ
    cmp al, 58          ; Максимальный скан-код в таблице
    jae .done

    ; Выбираем таблицу в зависимости от Shift/Caps
    mov ebx, keymap_lower
    cmp byte [keyboard_shift], 1
    jne .check_caps
    mov ebx, keymap_upper
    jmp .print_char

.check_caps:
    cmp byte [keyboard_caps], 1
    jne .print_char

    ; Caps Lock: инвертируем регистр для букв
    cmp al, 16          ; 'q' начинается с 0x10
    jb .print_char
    cmp al, 26          ; 'p' заканчивается на 0x19
    ja .check_letters2
    mov ebx, keymap_upper
    jmp .print_char

.check_letters2:
    cmp al, 30          ; 'a' = 0x1E
    jb .print_char
    cmp al, 39          ; 'l' = 0x26
    ja .print_char
    mov ebx, keymap_upper

.print_char:
    xlatb                ; AL = [EBX + AL]
    test al, al
    jz .done
    mov [last_key],al

    ; Выводим символ на экран
    ;mov ah, 0x0F
    ;mov edi, 0xB8000
    ;add edi, [cursor_pos32]
    ;mov [edi], ax
    ;add dword [cursor_pos32], 2

    jmp .done

.backspace:
    mov al,0x08
    mov [last_key],al
    ; Удаляем последний символ
    ;cmp dword [cursor_pos32], 0
    ;je .done
    ;sub dword [cursor_pos32], 2
    ;mov edi, 0xB8000
    ;add edi, [cursor_pos32]
    ;mov word [edi], 0x0F20    ; Пробел
    jmp .done

.enter:
    mov al,13
    mov [last_key],al
    ;call new_line32
    jmp .done

.shift_press:
    mov byte [keyboard_shift], 1
    jmp .done

.caps_press:
    xor byte [keyboard_caps], 1    ; Переключаем Caps Lock
    jmp .done

.ctrl_press:
    mov byte [keyboard_ctrl], 1
    jmp .done

.alt_press:
    mov byte [keyboard_alt], 1
    jmp .done

.key_release:
    mov byte [key_ready],0
    ; Отпускание клавиши
    and al, 0x7F        ; Снимаем старший бит

    cmp al, 0x2A        ; Left Shift
    je .shift_release
    cmp al, 0x36        ; Right Shift
    je .shift_release
    cmp al, 0x1D        ; Left Ctrl
    je .ctrl_release
    cmp al, 0x38        ; Left Alt
    je .alt_release

    jmp .done

.shift_release:
    mov byte [keyboard_shift], 0
    jmp .done

.ctrl_release:
    mov byte [keyboard_ctrl], 0
    jmp .done

.alt_release:
    mov byte [keyboard_alt], 0
.done:

    ; Отправляем EOI в APIC
    call send_eoi

    popad
    iret

; ============================================================
; ДАННЫЕ ДРАЙВЕРА
; ============================================================
last_key:       db 0         ; Последний ASCII код
key_ready:      db 0         ; Флаг готовности клавиши

command_ready: db 0


; ============================================================
; СООБЩЕНИЯ ДЛЯ ОТЛАДКИ
; ============================================================
msg_exception:       db 'Exception #', 0
msg_exception_halt:  db 'System Halted! Register dump:', 0
msg_eax:             db 'EAX: 0x', 0
msg_ecx:             db 'ECX: 0x', 0
msg_edx:             db 'EDX: 0x', 0
msg_ebx:             db 'EBX: 0x', 0
msg_esp:             db 'ESP: 0x', 0
msg_ebp:             db 'EBP: 0x', 0
msg_esi:             db 'ESI: 0x', 0
msg_edi:             db 'EDI: 0x', 0
msg_plug:            db 'Unhandled interrupt!', 0
msg_timer:           db '.', 0
msg_key:             db 'K', 0

; ============================================================
; ОБРАБОТЧИК IRQ6 ДЛЯ FDC (вектор 0x26)
; ============================================================
irq6_handler:
    pushad

    ; Устанавливаем флаг получения прерывания
    mov byte [fdd_irq_received], 1

    ; Отправляем EOI в APIC
    call send_eoi

    popad
    iret

; ============================================================
; 32-БИТНЫЕ ФУНКЦИИ ВЫВОДА (ПОЛНОСТЬЮ ИСПРАВЛЕННЫЕ)
; ============================================================

clear_screen32:
    pusha
    mov edi, 0xB8000
    mov ecx, 80*25
    mov ax, 0x0F20
    rep stosw
    mov dword [cursor_pos32], 0    ; Сбрасываем курсор!
    popa
    ret

print_string32:
    pusha
    mov edi, 0xB8000
    add edi, [cursor_pos32]        ; УЧИТЫВАЕМ ПОЗИЦИЮ КУРСОРА!
.loop:
    mov al, [esi]
    test al, al
    jz .done
    mov ah, 0x0F
    mov [edi], ax
    add edi, 2
    add dword [cursor_pos32], 2    ; Обновляем позицию курсора
    inc esi
    jmp .loop
.done:
    popa
    ret
    ;---------------------------------
    ; input al=ACSII code; OUTPUT=print_char
    ;---------------------------------
print_char32:
    pusha
    test al,al
    jz .end
    ; Выводим на экран
    mov ah, 0x0F
    mov edi, 0xB8000
    add edi, [cursor_pos32]
    mov [edi], ax
    add dword [cursor_pos32], 2
    .end:
    popa
    ret
print_hex32:
    pusha
    mov ecx, 8
    mov edi, 0xB8000
    add edi, [cursor_pos32]        ; УЧИТЫВАЕМ ПОЗИЦИЮ КУРСОРА!
.loop:
    rol eax, 4
    push eax
    and al, 0x0F
    cmp al, 10
    jl .digit
    add al, 'A' - 10
    jmp .print_char
.digit:
    add al, '0'
.print_char:
    mov ah, 0x0F
    mov [edi], ax
    add edi, 2
    add dword [cursor_pos32], 2
    pop eax
    loop .loop
    popa
    ret

print_dec32:
    pusha
    mov ecx, 10
    xor ebx, ebx

    test eax, eax
    jnz .divide
    push 0
    inc ebx
    jmp .print

.divide:
    xor edx, edx
    div ecx
    push edx
    inc ebx
    test eax, eax
    jnz .divide

.print:
    pop eax
    add al, '0'
    mov ah, 0x0F

    push ebx
    push edi
    mov edi, 0xB8000
    add edi, [cursor_pos32]
    mov [edi], ax
    add dword [cursor_pos32], 2
    pop edi
    pop ebx

    dec ebx
    jnz .print

    popa
    ret

new_line32:
    push eax
    mov eax, [cursor_pos32]
    mov edx, 0
    mov ecx, 160          ; 80*2
    div ecx               ; EAX = строка, EDX = остаток
    inc eax               ; следующая строка
    mov ecx, 160
    mul ecx               ; EAX = новая позиция
    mov [cursor_pos32], eax
    pop eax
    ret

show_memory_info:
    pusha
    mov esi, msg_ram_info
    call print_string32

    mov eax, [total_ram_low]
    shr eax, 20
    call print_dec32

    mov esi, msg_mb
    call print_string32
    call new_line32
    popa
    ret
detect_interrupt_controller:
    pusha

    mov esi, msg_checking_ic
    call print_string32

    ; Проверяем CPUID
    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x00200000
    push eax
    popfd
    pushfd
    pop eax
    xor eax, ecx
    jz .no_cpuid

    ; Проверяем APIC через CPUID
    mov eax, 1
    cpuid
    test edx, 0x00000200
    jz .pic_only

    ; APIC поддерживается - проверяем включен ли
    mov ecx, 0x1B
    rdmsr
    test eax, 0x00000800
    jnz .apic_active

    mov esi, msg_apic_disabled
    call print_string32
    call new_line32
    jmp .using_pic

.apic_active:
    mov esi, msg_apic_active
    call print_string32
    call new_line32

    ; Определяем тип APIC (xAPIC/x2APIC)
    mov ecx, 0x1B
    rdmsr
    test eax, 0x00000400   ; Бит 10 = x2APIC
    jnz .x2apic

    mov esi, msg_xapic
    call print_string32
    call new_line32
    jmp .done

.x2apic:
    mov esi, msg_x2apic
    call print_string32
    call new_line32
    jmp .done

.pic_only:
    mov esi, msg_8259pic
    call print_string32
    call new_line32

.using_pic:
    mov esi, msg_will_use_pic
    call print_string32
    call new_line32
    jmp .done

.no_cpuid:
    mov esi, msg_unknown_interput
    call print_string32
    call new_line32

.done:
    popa
    ret
disable_pic:
    ; Просто маскируем все прерывания PIC
    mov al, 0xFF
    out 0x21, al    ; Master PIC — все IRQ запрещены
    out 0xA1, al    ; Slave PIC — все IRQ запрещены
    call new_line32
    mov esi,msg_pic_disable
    call print_string32
    call new_line32
    ret
; ============================================================
; ИНИЦИАЛИЗАЦИЯ LOCAL APIC
; ============================================================
init_lapic:
    pusha

    mov esi, msg_apic_init
    call print_string32
    call new_line32

    ; 1. Получаем базовый адрес LAPIC через MSR
    mov ecx, 0x1B            ; MSR APIC_BASE
    rdmsr
    and eax, 0xFFFFF000      ; Очищаем младшие 12 бит (флаги)
    mov [lapic_base], eax

    ; Выводим базовый адрес
    mov esi, msg_apic_base_addr
    call print_string32
    mov eax, [lapic_base]
    call print_hex32
    call new_line32

    ; 2. Проверяем, включен ли APIC
    mov ecx, 0x1B
    rdmsr
    test eax, 0x800          ; Бит 11 = APIC Global Enable
    jnz .apic_enabled

    ; Включаем APIC если выключен
    or eax, 0x800
    wrmsr

.apic_enabled:
    ; 3. Читаем APIC ID
    mov esi, [lapic_base]
    mov eax, [esi + 0x20]    ; APIC ID Register (смещение 0x20)
    shr eax, 24               ; ID в старших 8 битах
    mov [apic_id], al

    mov esi, msg_apic_id
    call print_string32
    movzx eax, byte [apic_id]
    call print_dec32
    call new_line32

    ; 4. Читаем версию APIC
    mov esi, [lapic_base]
    mov eax, [esi + 0x30]    ; APIC Version Register
    and eax, 0xFF             ; Версия в младших 8 битах
    mov [apic_version], al

    mov esi, msg_apic_version
    call print_string32
    movzx eax, byte [apic_version]
    call print_dec32
    call new_line32

    ; 5. Настраиваем Spurious-Interrupt Vector Register
    mov esi, [lapic_base]
    add esi, 0x0F0            ; SVR (смещение 0xF0)
    mov eax, 0x1FF            ; Вектор 0xFF + APIC Enable (бит 8)
    mov [esi], eax

    ; 6. Настраиваем Task Priority Register (принимаем все прерывания)
    mov esi, [lapic_base]
    add esi, 0x080            ; TPR (смещение 0x80)
    mov dword [esi], 0        ; Приоритет 0 = принимаем всё

    ; 7. Настраиваем Logical Destination Register
    mov esi, [lapic_base]
    add esi, 0x0D0            ; LDR
    mov dword [esi], 0x01000000  ; Logical ID = 1

    ; 8. Настраиваем Destination Format Register
    mov esi, [lapic_base]
    add esi, 0x0E0            ; DFR
    mov dword [esi], 0xFFFFFFFF  ; Flat model

    ; Всё готово!
    mov esi, msg_apic_ok
    call print_string32
    call new_line32

    popa
    ret
; ============================================================
; ОТПРАВКА EOI (End of Interrupt)
; ============================================================
send_eoi:
    push eax
    push esi
    mov esi, [lapic_base]
    add esi, 0x0B0            ; EOI Register
    mov dword [esi], 0
    pop esi
    pop eax
    ret

; ============================================================
; ПОЛУЧЕНИЕ ТЕКУЩЕГО ВЕКТОРА ПРЕРЫВАНИЯ
; ============================================================
get_interrupt_vector:
    push esi
    mov esi, [lapic_base]
    add esi, 0x110            ; In-Service Register
    mov eax, [esi]
    pop esi
    ret
; ============================================================
; НАСТРОЙКА I/O APIC (если есть)
; ============================================================
setup_ioapic:
    pusha

    mov esi, msg_ioapic_setup
    call print_string32
    call new_line32

    ; Проверяем наличие I/O APIC по стандартному адресу
    mov dword [ioapic_base], 0xFEC00000

    ; Читаем ID I/O APIC
    mov esi, [ioapic_base]
    mov dword [esi], 0        ; Выбираем регистр ID
    mov eax, [esi + 0x10]     ; Читаем значение
    shr eax, 24
    and eax, 0x0F

    mov esi, msg_ioapic_id
    call print_string32
    call print_dec32
    call new_line32

    ; Настраиваем IRQ1 (клавиатура) → вектор 0x21
    mov esi, [ioapic_base]

    ; IOREDTBL[1] - lower 32 bits (регистр 0x12)
    mov dword [esi], 0x12     ; Выбираем регистр
    mov dword [esi + 0x10], 0x21  ; Вектор 0x21, физический режим

    ; IOREDTBL[1] - upper 32 bits (регистр 0x13)
    mov dword [esi], 0x13     ; Выбираем регистр
    mov dword [esi + 0x10], 0  ; APIC ID = 0 (BSP)

    ; Настраиваем IRQ0 (таймер) → вектор 0x20
    mov dword [esi], 0x10     ; Регистр для IRQ0
    mov dword [esi + 0x10], 0x20

    mov dword [esi], 0x11
    mov dword [esi + 0x10], 0


    ; Настраиваем IRQ6 (Floppy) → вектор 0x26
    mov dword [esi], 0x1C     ; Регистр для IRQ6 (lower)
    mov dword [esi + 0x10], 0x26  ; Вектор 0x26

    mov dword [esi], 0x1D     ; Регистр для IRQ6 (upper)
    mov dword [esi + 0x10], 0     ; APIC ID = 0

    ; ... остальной код ...
    mov esi, msg_ioapic_ok
    call print_string32
    call new_line32

    popa
    ret
; ============================================================
; РЕГИСТРЫ LAPIC TIMER
; ============================================================
LAPIC_TIMER_LVT       equ 0x320
LAPIC_TIMER_INITIAL   equ 0x380
LAPIC_TIMER_CURRENT   equ 0x390
LAPIC_TIMER_DIVIDE    equ 0x3E0

; ============================================================
; ПЕРЕМЕННЫЕ ТАЙМЕРА
; ============================================================
lapic_timer_available: dd 0
timer_ticks:          dd 0
timer_callback:       dd 0          ; Адрес функции обратного вызова
timer_frequency:      dd 0          ; Частота в Гц
cpu_ticks_per_ms:     dd 62500      ; Значение по умолчанию для QEMU
; ============================================================
; ИНИЦИАЛИЗАЦИЯ МЕНЕДЖЕРА ПАМЯТИ
; Вход: EAX = общий объём ОЗУ в байтах (из total_ram_low)
; ============================================================
init_memory_manager:
    pusha

    ; Сохраняем общий объём памяти
    mov [total_memory_bytes], eax

    ; Переводим в килобайты
    shr eax, 10                    ; Делим на 1024
    mov [total_memory_kb], eax

    ; Вычитаем резервные 20 КБ
    sub eax, RESERVED_END_KB
    shr eax, 2                     ; Делим на 4 (получаем страницы по 4КБ)
    mov [total_pages], eax

    ; Выводим информацию
    mov esi, msg_mem_total
    call print_string32
    mov eax, [total_memory_kb]
    call print_dec32
    mov esi, msg_kb
    call print_string32
    call new_line32

    mov esi, msg_pages_total
    call print_string32
    mov eax, [total_pages]
    call print_dec32
    ;call print_string32
    call new_line32

    ; Выделяем место под битовую карту
    ; Размер = total_pages / 8 байт (1 бит на страницу)
    mov eax, [total_pages]
    shr eax, 3                     ; Делим на 8
    inc eax                        ; +1 для выравнивания
    mov [pages_bitmap_size], eax

    ; Размещаем битовую карту сразу после ядра
    mov eax, [kernel_end_physical]
    add eax, 4095
    and eax, ~4095                 ; Выравниваем на страницу
    mov [pages_bitmap], eax

    ; Обнуляем битовую карту
    mov edi, [pages_bitmap]
    mov ecx, [pages_bitmap_size]
    xor al, al
    rep stosb

    ; Отмечаем страницы ядра как занятые
    mov eax, [kernel_end_physical]
    shr eax, 12                    ; Номер последней страницы ядра
    inc eax
    mov [kernel_end_page], eax

    mov ecx, eax                   ; Количество страниц ядра
    xor ebx, ebx                   ; Начинаем со страницы 0
.mark_kernel:
    push ecx
    push ebx
    call mark_page_used
    pop ebx
    inc ebx
    pop ecx
    loop .mark_kernel

    ; Рассчитываем пользовательские страницы
    mov eax, [total_pages]
    shr eax, 1                     ; Делим пополам (ОЗУ/2)
    mov [user_pages_count], eax

    mov eax, [kernel_end_page]
    mov [user_pages_start], eax    ; Начинаются после ядра

    ; Рассчитываем начало зарезервированных страниц
    mov eax, [total_pages]
    sub eax, (RESERVED_END_KB * 1024) / PAGE_SIZE
    mov [reserved_pages_start], eax

    ; Отмечаем зарезервированные страницы
    mov ecx, (RESERVED_END_KB * 1024) / PAGE_SIZE
    mov ebx, [reserved_pages_start]
.mark_reserved:
    push ecx
    push ebx
    call mark_page_used
    pop ebx
    inc ebx
    pop ecx
    loop .mark_reserved

    mov esi, msg_mem_init_ok
    call print_string32
    call new_line32

    popa
    ret

; Сообщения
msg_mem_total:    db 'Total memory: ', 0
msg_kb:           db ' KB', 0
msg_pages_total:  db 'Total pages: ', 0
msg_mem_init_ok:  db 'Memory manager initialized', 0
; ============================================================
; ОТМЕТИТЬ СТРАНИЦУ КАК ЗАНЯТУЮ
; Вход: EBX = номер страницы
; ============================================================
mark_page_used:
    push eax
    push edi
    push ecx

    ; Вычисляем позицию в битовой карте
    mov eax, ebx
    mov edi, [pages_bitmap]

    ; Находим байт: page / 8
    push ebx
    shr ebx, 3
    add edi, ebx
    pop ebx

    ; Находим бит внутри байта: page % 8
    and ebx, 7
    mov cl, bl
    mov al, 1
    shl al, cl

    ; Устанавливаем бит
    or byte [edi], al

    pop ecx
    pop edi
    pop eax
    ret

; ============================================================
; ОТМЕТИТЬ СТРАНИЦУ КАК СВОБОДНУЮ
; ============================================================
mark_page_free:
    push eax
    push edi
    push ecx

    mov eax, ebx
    mov edi, [pages_bitmap]

    shr ebx, 3
    add edi, ebx

    and eax, 7
    mov cl, al
    mov al, 1
    shl al, cl
    not al

    and byte [edi], al

    pop ecx
    pop edi
    pop eax
    ret

; ============================================================
; ПРОВЕРИТЬ, СВОБОДНА ЛИ СТРАНИЦА
; Вход: EBX = номер страницы
; Выход: CF=0 свободна, CF=1 занята
; ============================================================
is_page_free:
    push eax
    push edi
    push ecx

    mov eax, ebx
    mov edi, [pages_bitmap]

    shr ebx, 3
    add edi, ebx

    and eax, 7
    mov cl, al
    mov al, 1
    shl al, cl

    test byte [edi], al
    jz .free
    stc                          ; Занята
    jmp .done
.free:
    clc                          ; Свободна
.done:
    pop ecx
    pop edi
    pop eax
    ret
; ============================================================
; ВЫДЕЛИТЬ ОДНУ СТРАНИЦУ USER SPACE
; Выход: EAX = физический адрес страницы (0 если нет)
; ============================================================
allocate_page:
    push ebx
    push ecx

    ; Ищем свободную страницу в пользовательской области
    mov ebx, [user_pages_start]
    mov ecx, [user_pages_count]

.search:
    cmp ecx, 0
    je .not_found

    push ecx
    push ebx
    call is_page_free
    pop ebx
    pop ecx

    jnc .found                  ; CF=0 значит свободна

    inc ebx
    dec ecx
    jmp .search

.found:
    ; Отмечаем как занятую
    push ebx
    call mark_page_used
    pop ebx

    ; Вычисляем физический адрес
    mov eax, ebx
    shl eax, 12                ; Умножаем на 4096

    pop ecx
    pop ebx
    ret

.not_found:
    xor eax, eax                ; Возвращаем 0
    pop ecx
    pop ebx
    ret

; ============================================================
; ОСВОБОДИТЬ СТРАНИЦУ
; Вход: EAX = физический адрес страницы
; ============================================================
free_page:
    push ebx

    ; Вычисляем номер страницы
    shr eax, 12                ; Делим на 4096
    mov ebx, eax

    ; Отмечаем как свободную
    call mark_page_free

    pop ebx
    ret
; ============================================================
; НАСТРОЙКА ПЕЙДЖИНГА
; ============================================================
setup_paging:
    pusha

    ; Выделяем страницу для каталога страниц
    call allocate_page
    mov [page_directory], eax

    ; Выделяем страницу для таблицы страниц ядра
    call allocate_page
    mov [page_table_kernel], eax

    ; Заполняем каталог страниц
    mov edi, [page_directory]

    ; Первый Entry: таблица ядра (0-4 МБ)
    mov eax, [page_table_kernel]
    or eax, 3                  ; Present + Read/Write
    mov [edi], eax

    ; Остальные Entries пока пустые
    mov ecx, 1023
    xor eax, eax
    add edi, 4
.clear_dir:
    mov [edi], eax
    add edi, 4
    loop .clear_dir

    ; Заполняем таблицу страниц ядра
    mov edi, [page_table_kernel]
    mov ecx, 1024
    mov eax, 0                 ; Начинаем с физического адреса 0
    mov ebx, 3                 ; Present + Read/Write

.fill_kernel:
    mov [edi], eax
    or dword [edi], ebx
    add eax, PAGE_SIZE
    add edi, 4
    loop .fill_kernel

    ; Загружаем CR3
    mov eax, [page_directory]
    mov cr3, eax

    ; Включаем пейджинг
    mov eax, cr0
    or eax, 0x80000000         ; Бит PG (Paging)
    mov cr0, eax

    mov esi, msg_paging_ok
    call print_string32
    call new_line32

    popa
    ret

msg_paging_ok: db 'Paging enabled!', 0

test_memory_manager:
    ; Выделяем 5 страниц
    mov ecx, 5
.alloc_loop:
    push ecx
    call allocate_page
    pop ecx

    test eax, eax
    jz .error

    ; Выводим адрес
    push ecx
    push eax
    mov esi, msg_allocated
    call print_string32
    pop eax
    call print_hex32
    call new_line32
    pop ecx

    loop .alloc_loop

    mov esi, msg_mem_test_ok
    call print_string32
    ret

.error:
    mov esi, msg_mem_error
    call print_string32
    ret

msg_allocated:    db 'Allocated page at 0x', 0
msg_mem_test_ok:  db 'Memory test passed!', 0
msg_mem_error:    db 'Memory allocation failed!', 0
; ============================================================
; МАППИНГ ФИЗИЧЕСКОЙ СТРАНИЦЫ В ВИРТУАЛЬНЫЙ АДРЕС
; Вход: EAX = номер физической страницы (0, 1, 2, ...)
;       EBX = виртуальный адрес для маппинга
; ============================================================
map_page:
    pusha

    ; Вычисляем физический адрес из номера страницы
    ; phys_addr = page_num * 4096
    shl eax, 12                    ; EAX = физический адрес страницы
    mov [.phys_addr], eax

    ; Извлекаем индекс каталога (старшие 10 бит)
    mov edx, ebx
    shr edx, 22                    ; Dir index = bits 31-22
    and edx, 0x3FF                 ; 10 бит (0-1023)
    mov [.dir_index], edx

    ; Извлекаем индекс таблицы (средние 10 бит)
    mov ecx, ebx
    shr ecx, 12                    ; Сдвигаем offset
    and ecx, 0x3FF                 ; Table index = bits 21-12
    mov [.table_index], ecx

    ; Проверяем, существует ли таблица страниц
    mov edx, [page_directory]
    mov eax, [.dir_index]
    shl eax, 2                     ; Умножаем на 4 (размер PDE)
    add edx, eax                   ; EDX = адрес PDE

    mov eax, [edx]                 ; Читаем PDE
    test eax, 1                    ; Проверяем бит Present
    jnz .table_exists

    ; Таблицы нет — создаём новую
    push edx
    call allocate_physical_page    ; Выделяем физическую страницу
    pop edx

    test eax, eax
    jz .error                      ; Не удалось выделить

    ; Очищаем новую таблицу
    push eax
    mov edi, eax
    mov ecx, 1024
    xor eax, eax
    rep stosd
    pop eax

    ; Создаём PDE: phys_addr | Present | Read/Write
    or eax, 3
    mov [edx], eax                 ; Сохраняем PDE

.table_exists:
    ; Получаем адрес таблицы страниц
    and eax, 0xFFFFF000            ; Очищаем флаги
    mov [.table_addr], eax

    ; Записываем PTE
    mov eax, [.table_addr]
    mov ecx, [.table_index]
    shl ecx, 2                     ; Умножаем на 4
    add eax, ecx                   ; EAX = адрес PTE

    ; phys_addr | Present | Read/Write
    mov edx, [.phys_addr]
    or edx, 3
    mov [eax], edx

    ; Сбрасываем TLB (обновляем кеш страниц)
    mov eax, cr3
    mov cr3, eax

    mov esi, msg_map_ok
    call print_string32

    ; Выводим информацию
    mov esi, msg_virt
    call print_string32
    mov eax, ebx
    call print_hex32

    mov esi, msg_phys
    call print_string32
    mov eax, [.phys_addr]
    call print_hex32
    call new_line32

    popa
    clc                           ; Успех
    ret

.error:
    mov esi, msg_map_error
    call print_string32
    popa
    stc                           ; Ошибка
    ret

; Локальные переменные
.phys_addr:   dd 0
.dir_index:   dd 0
.table_index: dd 0
.table_addr:  dd 0

msg_map_ok:    db 'Mapped: ', 0
msg_virt:      db 'Virt=0x', 0
msg_phys:      db ' Phys=0x', 0
msg_map_error: db 'Failed to map page!', 0
; ============================================================
; ВЫДЕЛИТЬ ФИЗИЧЕСКУЮ СТРАНИЦУ (для таблиц)
; Выход: EAX = физический адрес (0 если ошибка)
; ============================================================
allocate_physical_page:
    push ebx
    push ecx

    ; Ищем свободную страницу
    mov ebx, [kernel_end_page]     ; Начинаем с конца ядра

.search:
    cmp ebx, [total_pages]
    jae .not_found

    push ebx
    call is_page_free
    pop ebx

    jnc .found

    inc ebx
    jmp .search

.found:
    push ebx
    call mark_page_used
    pop ebx

    mov eax, ebx
    shl eax, 12                    ; Номер → адрес

    pop ecx
    pop ebx
    ret

.not_found:
    xor eax, eax
    pop ecx
    pop ebx
    ret

; ============================================================
; ВЫДЕЛИТЬ ФИЗИЧЕСКУЮ СТРАНИЦУ (ВЫШЕ 1 МБ)
; Вход: нет
; Выход: EAX = номер физической страницы (0 если ошибка)
;        EDX = физический адрес страницы
; ============================================================
allocate_physical_page_v2:
    push ebx
    push ecx

    mov ebx, 256               ; Начинаем с 1 МБ

.search:
    cmp ebx, [total_pages]
    jae .not_found

    cmp ebx, [reserved_pages_start]
    jae .not_found

    push ebx
    call is_page_free
    pop ebx
    jnc .found

    inc ebx
    jmp .search

.not_found:
    xor eax, eax
    xor edx, edx
    pop ecx
    pop ebx
    ret

.found:
    push ebx
    call mark_page_used
    pop ebx

    ; ВАЖНО: EAX = номер страницы, EDX = физический адрес
    mov eax, ebx               ; Номер страницы (например, 256)
    mov edx, ebx
    shl edx, 12                ; Физический адрес (например, 0x100000)

    pop ecx
    pop ebx
    ret

; ============================================================
; ОСВОБОДИТЬ ФИЗИЧЕСКУЮ СТРАНИЦУ
; Вход: EAX = номер страницы
; ============================================================
free_physical_page_v2:
    push ebx
    mov ebx, eax
    call mark_page_free
    pop ebx
    ret
; ============================================================
; ПОКАЗАТЬ СТАТИСТИКУ ПАМЯТИ ДЛЯ RING 3 (ПОЛЬЗОВАТЕЛЬСКОЙ ОБЛАСТИ)
; ============================================================
show_memory_stats:
    pusha

    mov esi, msg_mem_stats_header
    call print_string32
    call new_line32
    call new_line32

    ; 1. Общая физическая память
    mov esi, msg_total_phys
    call print_string32
    mov eax, [total_memory_kb]
    call print_dec32
    mov esi, msg_kb
    call print_string32
    call new_line32

    ; 2. Всего страниц
    mov esi, msg_total_pages
    call print_string32
    mov eax, [total_pages]
    call print_dec32
    call new_line32

    ; 3. Размер страницы
    mov esi, msg_page_size
    call print_string32
    mov eax, PAGE_SIZE
    call print_dec32
    mov esi, msg_bytes
    call print_string32
    call new_line32
    call new_line32

    ; 4. Пользовательская область
    mov esi, msg_user_header
    call print_string32
    call new_line32

    ; Диапазон пользовательских страниц
    mov esi, msg_user_range
    call print_string32
    mov eax, [user_pages_start]
    call print_dec32
    mov esi, msg_dash
    call print_string32
    mov eax, [user_pages_start]
    add eax, [user_pages_count]
    dec eax
    call print_dec32
    call new_line32

    ; Всего пользовательских страниц
    mov esi, msg_user_total
    call print_string32
    mov eax, [user_pages_count]
    call print_dec32
    mov esi, msg_pages_text
    call print_string32
    call new_line32

    ; Размер пользовательской области в КБ
    mov esi, msg_user_size
    call print_string32
    mov eax, [user_pages_count]
    shl eax, 2             ; Умножаем на 4 (4096/1024 = 4 КБ на страницу)
    call print_dec32
    mov esi, msg_kb
    call print_string32
    call new_line32

    ; Размер в МБ
    mov esi, msg_user_size_mb
    call print_string32
    mov eax, [user_pages_count]
    shr eax, 8             ; Делим на 256 (4096*256 = 1 МБ)
    call print_dec32
    mov esi, msg_mb
    call print_string32
    call new_line32
    call new_line32

    ; 5. Статистика использования
    mov esi, msg_usage_header
    call print_string32
    call new_line32

    ; Подсчитываем занятые пользовательские страницы
    mov ecx, [user_pages_count]
    mov ebx, [user_pages_start]
    xor edx, edx            ; Счётчик занятых страниц

.count_used:
    push ecx
    push ebx
    call is_page_free
    pop ebx
    pop ecx

    jc .is_used            ; CF=1 значит занята
    jmp .next

.is_used:
    inc edx

.next:
    inc ebx
    dec ecx
    jnz .count_used

    mov [used_pages], edx

    ; Выводим занятые страницы
    mov esi, msg_used_pages
    call print_string32
    mov eax, edx
    call print_dec32
    mov esi, msg_pages_text
    call print_string32
    call new_line32

    ; Вычисляем свободные страницы
    mov eax, [user_pages_count]
    sub eax, edx
    mov [free_pages], eax

    ; Выводим свободные страницы
    mov esi, msg_free_pages
    call print_string32
    call print_dec32
    mov esi, msg_pages_text
    call print_string32
    call new_line32

    ; Процент использования
    mov eax, edx
    shl eax, 10            ; Умножаем на 1024 для точности
    xor edx, edx
    div dword [user_pages_count]
    shr eax, 2             ; Делим на 4 чтобы получить 0-100
    ; EAX = (used * 256 / total) = процент * 2.56, но примерно

    mov esi, msg_usage_percent
    call print_string32
    call print_dec32
    mov esi, msg_percent
    call print_string32
    call new_line32

    ; 6. Резервная область
    call new_line32
    mov esi, msg_reserved_header
    call print_string32
    call new_line32

    mov esi, msg_reserved_size
    call print_string32
    mov eax, RESERVED_END_KB
    call print_dec32
    mov esi, msg_kb
    call print_string32
    call new_line32

    mov esi, msg_reserved_pages
    call print_string32
    mov eax, (RESERVED_END_KB * 1024) / PAGE_SIZE
    call print_dec32
    mov esi, msg_pages_text
    call print_string32
    call new_line32

    popa
    ret

; Переменные для статистики
used_pages:  dd 0
free_pages:  dd 0

; Сообщения
msg_mem_stats_header:  db '=== MEMORY STATISTICS ===', 0
msg_total_phys:        db 'Total physical memory: ', 0
msg_total_pages:       db 'Total pages: ', 0
msg_page_size:         db 'Page size: ', 0
msg_user_header:       db '--- User Space (Ring 3) ---', 0
msg_user_range:        db 'Page range: ', 0
msg_dash:              db ' - ', 0
msg_user_total:        db 'Total pages available: ', 0
msg_pages_text:        db ' pages', 0
msg_user_size:         db 'Total size: ', 0
msg_user_size_mb:      db 'Total size: ', 0
msg_usage_header:      db '--- Usage Statistics ---', 0
msg_used_pages:        db 'Used pages: ', 0
msg_free_pages:        db 'Free pages: ', 0
msg_usage_percent:     db 'Usage: ', 0
msg_percent:           db '%', 0
msg_reserved_header:   db '--- Reserved Area ---', 0
msg_reserved_size:     db 'Reserved size: ', 0
msg_reserved_pages:    db 'Reserved pages: ', 0
; ============================================================
; ОБНАРУЖЕНИЕ И ИНИЦИАЛИЗАЦИЯ LAPIC TIMER
; ============================================================
detect_and_init_timer:
    pusha

    mov esi, msg_timer_detect
    call print_string32
    call new_line32

    ; Проверяем наличие LAPIC (читаем версию)
    mov esi, [lapic_base]
    mov eax, [esi + 0x30]       ; APIC Version Register

    ; Версия APIC >= 0x14 (20) значит есть таймер?
    cmp al, 0x14
    jae .timer_present

    ; Таймера нет или старая версия
    mov esi, msg_no_lapic_timer
    call print_string32
    call new_line32

    mov dword [lapic_timer_available], 0
    jmp .done

.timer_present:
    mov dword [lapic_timer_available], 1

    mov esi, msg_lapic_timer_ok
    call print_string32
    call new_line32

    ; Настраиваем таймер
    call setup_lapic_timer

    mov esi, msg_timer_ready
    call print_string32
    call new_line32

.done:
    popa
    ret

; ============================================================
; НАСТРОЙКА LAPIC TIMER
; ============================================================
setup_lapic_timer:
    pusha

    mov esi, [lapic_base]

    ; 1. Устанавливаем делитель
    ; Биты 0-3: 0=2, 1=4, 2=8, 3=16, ... 7=128
    mov dword [esi + LAPIC_TIMER_DIVIDE], 3    ; Делитель = 16

    ; 2. Устанавливаем начальное значение счётчика
    ; Для QEMU (~1 GHz): 1GHz/16/1000 = 62500 тиков на 1 мс
    mov eax, [cpu_ticks_per_ms]
    mov [timer_frequency], eax                  ; Сохраняем для будущей калибровки
    mov dword [esi + LAPIC_TIMER_INITIAL], eax

    ; 3. Настраиваем LVT таймера
    ; Бит 17 = периодический режим (1) или одноразовый (0)
    ; Биты 8-15 = вектор прерывания (0x20)
    ; Бит 16 = маска (0 = разрешено)
    mov dword [esi + LAPIC_TIMER_LVT], 0x20 | (1 << 17)
    ;              вектор 0x20 | периодический режим

    ; Сбрасываем счётчики
    mov dword [timer_ticks], 0
    mov dword [timer_callback], 0

    popa
    ret

; ============================================================
; ФУНКЦИЯ: УСТАНОВКА ОДНОРАЗОВОГО ТАЙМЕРА
; Вход: EAX = задержка в миллисекундах
;       EBX = адрес функции обратного вызова
; ============================================================
set_timeout:
    pusha

    ; Сохраняем callback
    mov [timer_callback], ebx

    ; Вычисляем количество тиков для задержки
    ; ticks = ms * ticks_per_ms
    mov ecx, [cpu_ticks_per_ms]
    mul ecx                        ; EDX:EAX = ms * ticks_per_ms

    ; Настраиваем LAPIC на одноразовый режим
    mov esi, [lapic_base]

    ; Устанавливаем начальное значение счётчика
    mov dword [esi + LAPIC_TIMER_INITIAL], eax

    ; Переключаем в одноразовый режим (сбрасываем бит 17)
    mov dword [esi + LAPIC_TIMER_LVT], 0x20
    ;              вектор 0x20 | одноразовый режим

    popa
    ret

; ============================================================
; ФУНКЦИЯ: ПОЛУЧИТЬ ТЕКУЩЕЕ ВРЕМЯ В ТИКАХ
; ============================================================
get_ticks:
    mov eax, [timer_ticks]
    ret

; ============================================================
; ФУНКЦИЯ: ЗАДЕРЖКА В МИЛЛИСЕКУНДАХ (блокирующая)
; ============================================================
sleep_ms:
    push ebx
    push ecx

    mov ebx, eax                   ; Сохраняем задержку
    call get_ticks                  ; Текущее время
    mov ecx, eax

    ; Вычисляем целевое время
    ; Для простоты: ticks_per_ms = 1 (если настроено на 1 мс)
    ; Иначе нужно умножать
    add ebx, ecx                    ; EBX = текущие тики + задержка

.wait_loop:
    call get_ticks
    cmp eax, ebx
    jl .wait_loop                   ; Ждём пока текущие < целевых

    pop ecx
    pop ebx
    ret

; ============================================================
; ФУНКЦИЯ: ВОЗВРАТ ТАЙМЕРА В ПЕРИОДИЧЕСКИЙ РЕЖИМ
; ============================================================
reset_timer_periodic:
    push eax
    push esi

    mov esi, [lapic_base]
    mov eax, [cpu_ticks_per_ms]
    mov dword [esi + LAPIC_TIMER_INITIAL], eax

    ; Периодический режим
    mov dword [esi + LAPIC_TIMER_LVT], 0x20 | (1 << 17)

    pop esi
    pop eax
    ret

; ============================================================
; ИСПРАВЛЕННАЯ КОМАНДНАЯ ОБОЛОЧКА
; ============================================================
press_key_msg: db 'key press to continiu',0
shel32:
; Выводим приглашение
    mov esi,press_key_msg
    call print_string32
    call block_key32
    call clear_screen32
    call detect_floppy_drives
    call fdc_reset
    call fdc_recalibrate
    call fdc_specify
    call new_line32
    call test_read_sector
    begin32:
    mov esi, shell_prompt
    call print_string32
    mov edi,command_buffer32
shel_loop:
    call block_key32
    stosb
    cmp al,13
    jz comand_shel32

    call print_char32

    jmp shel_loop
comand_shel32:
call new_line32
mov esi,clear_com
mov edi,command_buffer32
rep_clear_screen32:
cmpsb
jnz com_ls32
mov al,[esi]
test al,al
jz clear_com32_temp
jmp rep_clear_screen32
com_ls32:
mov esi,com_list
mov edi, command_buffer32
rep_list32:
cmpsb
jnz begin32
mov al,[esi]
test al,al
jz ls32
jmp rep_list32
jmp begin32
memory_static_temp:
call show_memory_stats
jmp begin32
clear_com32_temp:
call clear_screen32
jmp begin32
ls32:
call new_line32
call comand_list32
jmp begin32
;=============================================================
;Function Kernel
;=============================================================
;----read key input=none , output= ASCIIchar in al
read_key32:
xor eax,eax
mov al,[key_ready]
cmp al,1
jnz .none_end
mov byte [key_ready],0
xor eax,eax
mov al,[last_key]
ret
.none_end:
xor eax,eax
ret
block_key32:
call read_key32
test al,al
jz block_key32
ret
; ============================================================
; КОМАНДА LIST (32-бит) - ПРОСМОТР ФАЙЛОВ НА ДИСКЕ
; ============================================================
comand_list32:
    pusha

    ; Выделяем страницу под буфер чтения
    call allocate_physical_page
    test eax, eax
    jz .error_no_memory

    ; Сохраняем информацию о выделенной странице
    mov [list_buffer_page], eax      ; Номер страницы
    mov [list_buffer_phys], edx      ; Физический адрес

    ; Маппим страницу на виртуальный адрес для удобства
    push eax
    mov eax, edx                     ; Физический адрес
    mov ebx, LIST_BUFFER_VIRT        ; Виртуальный адрес
    call map_page
    pop eax

    ; Выводим заголовок
    mov esi, msg_header32
    call print_string32
    call new_line32

    ; Читаем Root Directory (сектор 19, 14 секторов)
    mov ecx, 14
    mov esi, 19                      ; Начальный сектор

.read_root:
    push ecx
    push esi

    ; Читаем сектор через FDC
    mov eax, esi                     ; LBA адрес
    mov edi, LIST_BUFFER_VIRT        ; Куда читать
    call fdc_read_sector

    ; Сканируем записи в буфере
    mov edi, LIST_BUFFER_VIRT
    mov ecx, 16                      ; 16 записей по 32 байта = 512 байт

.scan_entry:
    push ecx

    mov al, [edi]                    ; Первый байт записи
    cmp al, 0x00                     ; Конец каталога
    je .done_scan
    cmp al, 0xE5                     ; Удалённый файл
    je .next_entry

    ; Проверяем атрибуты
    mov al, [edi+11]                 ; Байт атрибутов
    test al, 0x08                    ; Метка тома?
    jnz .next_entry
    test al, 0x10                    ; Директория?
    jnz .next_entry
    cmp al, 0x0F                     ; Длинное имя?
    je .next_entry

    ; Выводим имя файла (8 символов)
    push edi
    mov ecx, 8
.print_name:
    mov al, [edi]
    cmp al, ' '
    je .print_ext
    call print_char32
    inc edi
    loop .print_name

.print_ext:
    pop edi
    mov al, [edi+8]
    cmp al, ' '
    je .print_size

    ; Выводим точку и расширение
    mov al, '.'
    call print_char32

    push edi
    add edi, 8
    mov ecx, 3
.print_ext_loop:
    mov al, [edi]
    cmp al, ' '
    je .print_size_pop
    call print_char32
    inc edi
    loop .print_ext_loop

.print_size_pop:
    pop edi

.print_size:
    ; Выводим размер файла
    mov esi, msg_size32
    call print_string32

    mov eax, [edi+28]               ; Размер файла (младшие 4 байта)
    call print_dec32

    mov esi, msg_bytes32
    call print_string32
    call new_line32

.next_entry:
    add edi, 32
    pop ecx
    dec ecx
    jnz .scan_entry

.done_scan:
    pop esi
    inc esi                          ; Следующий сектор
    pop ecx
    dec ecx
    jnz .read_root

    ; Освобождаем буфер
    mov eax, [list_buffer_page]
    call free_physical_page

    mov esi, msg_ready32
    call print_string32
    call new_line32

    popa
    ret

.error_no_memory:
    mov esi, msg_no_memory32
    call print_string32
    call new_line32
    popa
    ret

; Переменные для команды list
list_buffer_page: dd 0
list_buffer_phys: dd 0

; Виртуальный адрес для временного буфера
LIST_BUFFER_VIRT equ 0x00400000    ; 4 МБ (временная область)

; Сообщения
msg_header32:    db 'Files on disk:', 13, 10
                 db '==============', 13, 10, 0
msg_size32:      db ' - ', 0
msg_bytes32:     db ' bytes', 13, 10, 0
msg_ready32:     db 'Ready.', 13, 10, 0
msg_no_memory32: db 'Error: No memory for buffer!', 0
; ============================================================
; ПРИМЕР: ТЕСТОВАЯ ФУНКЦИЯ ОБРАТНОГО ВЫЗОВА
; ============================================================
test_callback:
    pusha
    mov esi, msg_callback_done
    call print_string32
    call new_line32
    popa
    ret
; ============================================================
; ОСВОБОДИТЬ ФИЗИЧЕСКУЮ СТРАНИЦУ (С ПРОВЕРКОЙ)
; Вход: EAX = номер страницы
; Выход: CF=0 успех, CF=1 ошибка
; ============================================================
free_physical_page:
    push ebx

    ; Проверяем что номер страницы валидный
    cmp eax, [total_pages]
    jae .error

    ; Проверяем что страница не из резервной области
    cmp eax, [reserved_pages_start]
    jae .error

    ; Освобождаем
    mov ebx, eax
    call mark_page_free

    pop ebx
    clc
    ret

.error:
    pop ebx
    stc
    ret
; ============================================================
; ПРИМЕР ИСПОЛЬЗОВАНИЯ В PROTECTED_START
; ============================================================
test_timer:
    pusha

    mov esi, msg_test_timer
    call print_string32
    call new_line32

    ; Тест 1: Ждём 3 секунды (блокирующий сон)
    mov esi, msg_sleep_3s
    call print_string32
    call new_line32

    mov eax, 3000              ; 3000 мс = 3 секунды
    call sleep_ms

    mov esi, msg_sleep_done
    call print_string32
    call new_line32

    ; Тест 2: Устанавливаем таймер на 5 секунд с callback
    mov esi, msg_set_timeout
    call print_string32
    call new_line32

    mov eax, 5000              ; 5000 мс = 5 секунд
    mov ebx, test_callback     ; Функция которая вызовется
    call set_timeout

    mov esi, msg_timeout_set
    call print_string32
    call new_line32

    ; Возвращаем таймер в периодический режим после использования
    ; (вызывается в test_callback или вручную)

    popa
    ret

; Сообщения
msg_timer_detect:    db 'Detecting LAPIC timer...', 0
msg_no_lapic_timer:  db 'LAPIC timer not available!', 0
msg_lapic_timer_ok:  db 'LAPIC timer present and configured', 0
msg_timer_ready:     db 'Timer ready for scheduler', 0
msg_test_timer:      db '=== Testing Timer ===', 0
msg_sleep_3s:        db 'Sleeping for 3 seconds...', 0
msg_sleep_done:      db 'Sleep completed!', 0
msg_set_timeout:     db 'Setting 5 second timeout...', 0
msg_timeout_set:     db 'Timeout set, callback will execute in 5s', 0
msg_callback_done:   db '*** CALLBACK EXECUTED! ***', 0
; ============================================================
; ОБРАБОТЧИКИ КОМАНД
; ============================================================
cmd_help_handler:
    mov esi, msg_help_title
    call print_string32
    call new_line32
    call new_line32

    mov esi, msg_help_help
    call print_string32
    call new_line32

    mov esi, msg_help_sysi
    call print_string32
    call new_line32

    mov esi, msg_help_clear
    call print_string32
    call new_line32

    mov esi, msg_help_meminfo
    call print_string32
    call new_line32

    mov esi, msg_help_crash
    call print_string32
    call new_line32

    mov esi, msg_help_reboot
    call print_string32
    call new_line32
    ret

cmd_sysinfo_handler:
    mov esi, msg_os_name
    call print_string32
    call new_line32
    mov esi, msg_os_ver
    call print_string32
    call new_line32
    call show_memory_info
    ret

reboot_system:
    mov esi, msg_rebooting
    call print_string32
    ; Небольшая задержка
    mov ecx, 0xFFFFF
.delay:
    loop .delay
    ; Перезагрузка через контроллер клавиатуры
    mov al, 0xFE
    out 0x64, al
    hlt
    jmp $

FLOPPY_SECTORS      equ 18


; ============================================================
; БАЗОВЫЕ ФУНКЦИИ ОЖИДАНИЯ
; ============================================================

; Ожидание RQM=1, DIO=0 (готов к записи в FIFO)
fdc_wait_write:
    push ecx
    mov ecx, 0xFFFFF

.loop:
    mov dx, FDC_MSR
    in al, dx
    and al, 0xC0              ; Маска RQM|DIO
    cmp al, 0x80              ; RQM=1, DIO=0
    je .ready
    dec ecx
    jnz .loop

    ; Таймаут
    stc
    pop ecx
    ret

.ready:
    clc
    pop ecx
    ret

; Ожидание RQM=1, DIO=1 (готов к чтению из FIFO)
fdc_wait_read:
    push ecx
    mov ecx, 0xFFFFF

.loop:
    mov dx, FDC_MSR
    in al, dx
    and al, 0xC0              ; Маска RQM|DIO
    cmp al, 0xC0              ; RQM=1, DIO=1
    je .ready
    dec ecx
    jnz .loop

    ; Таймаут
    stc
    pop ecx
    ret

.ready:
    clc
    pop ecx
    ret

; ============================================================
; ОТПРАВКА БАЙТА В КОНТРОЛЛЕР
; ============================================================
fdc_send:
    push edx
    call fdc_wait_write
    jc .error

    mov dx, FDC_FIFO
    out dx, al

    pop edx
    clc
    ret

.error:
    pop edx
    stc
    ret

; ============================================================
; ПОЛУЧЕНИЕ БАЙТА ИЗ КОНТРОЛЛЕРА
; ============================================================
fdc_recv:
    push edx
    call fdc_wait_read
    jc .error

    mov dx, FDC_FIFO
    in al, dx

    pop edx
    clc
    ret

.error:
    pop edx
    xor al, al
    stc
    ret

; ============================================================
; ПРОВЕРКА СТАТУСА ПРЕРЫВАНИЯ
; ============================================================
fdc_sense_int:
    call fdc_wait_write
    jc .error

    mov dx, FDC_FIFO
    mov al, FDC_CMD_SENSE
    out dx, al

    ; Читаем ST0 и текущий цилиндр
    call fdc_wait_read
    mov dx, FDC_FIFO
    in al, dx                 ; ST0

    call fdc_wait_read
    mov dx, FDC_FIFO
    in al, dx                 ; Cylinder

    clc
    ret

.error:
    stc
    ret
; ============================================================
; ВКЛЮЧИТЬ МОТОР ДИСКОВОДА
; Вход: AL = номер дисковода (0 или 1)
; ============================================================
fdc_motor_on:
    push eax

    cmp al, 0
    je .drive_a
    cmp al, 1
    je .drive_b

.drive_a:
    mov dx, FLOPPY_DOR
    mov al, 0x1C          ; Drive A, Motor A ON
    out dx, al
    jmp .done

.drive_b:
    mov dx, FLOPPY_DOR
    mov al, 0x2D          ; Drive B, Motor B ON
    out dx, al

.done:
    mov eax, 500
    call sleep_ms
    pop eax
    ret

; ============================================================
; ПОЗИЦИОНИРОВАНИЕ ГОЛОВКИ (SEEK)
; Вход: CH = цилиндр, DH = головка, DL = привод
; ============================================================
fdc_seek:
    pusha

    ; Формируем байт привода/головки
    mov al, dh
    shl al, 2
    and al, 0x04
    or al, dl

    ; Отправляем команду SEEK
    mov dx, FLOPPY_FIFO
    mov ah, FLOPPY_CMD_SEEK
    call fdc_send_byte
    jc .error

    mov al, ah              ; Привод/головка
    call fdc_send_byte
    jc .error

    mov al, ch              ; Цилиндр
    call fdc_send_byte
    jc .error

    ; Ждём прерывания
    call fdc_wait_irq
    jc .error

    ; Sense Interrupt
    call fdc_sense_interrupt

    popa
    clc
    ret

.error:
    popa
    stc
    ret

; ============================================================
; ВЫКЛЮЧИТЬ МОТОР FDC
; ============================================================
fdc_motor_off:
    mov dx, FDC_DOR
    mov al, 0x0C              ; Motor OFF
    out dx, al
    ret
; ============================================================
; ОТПРАВКА БАЙТА В FDC
; ============================================================
fdc_send_byte:
    push ecx
    push edx

    mov ecx, 0xFFFF
.wait:
    mov dx, FLOPPY_MSR
    in al, dx
    and al, 0xC0           ; RQM + DIO
    cmp al, 0x80           ; RQM=1, DIO=0
    je .send
    loop .wait

    stc
    pop edx
    pop ecx
    ret

.send:
    mov dx, FLOPPY_FIFO
    mov al, ah             ; Байт для отправки в AH
    out dx, al
    clc
    pop edx
    pop ecx
    ret

; ============================================================
; ЧТЕНИЕ БАЙТА ИЗ FDC
; ============================================================
fdc_read_byte:
    push ecx
    push edx

    mov ecx, 0xFFFF
.wait:
    mov dx, FLOPPY_MSR
    in al, dx
    and al, 0xC0           ; RQM + DIO
    cmp al, 0xC0           ; RQM=1, DIO=1
    je .read
    loop .wait

    xor al, al
    stc
    pop edx
    pop ecx
    ret

.read:
    mov dx, FLOPPY_FIFO
    in al, dx
    clc
    pop edx
    pop ecx
    ret

; ============================================================
; ОЖИДАНИЕ IRQ6 ОТ FDC
; ============================================================
fdc_wait_irq:
    push ecx
    mov ecx, 0xFFFFF

.wait:
    cmp byte [fdd_irq_received], 1
    je .done
    loop .wait

    stc
    pop ecx
    ret

.done:
    mov byte [fdd_irq_received], 0
    clc
    pop ecx
    ret

; ============================================================
; SENSE INTERRUPT (проверка состояния после операции)
; ============================================================
fdc_sense_interrupt:
    pusha

    ; Отправляем команду
    mov dx, FLOPPY_FIFO
    mov al, FLOPPY_CMD_SENSE_INTERRUPT
    out dx, al

    ; Читаем результат
    call fdc_read_byte
    mov [fdc_st0], al

    call fdc_read_byte
    mov [fdc_cylinder], al

    popa
    ret

; ============================================================
; НАСТРОЙКА DMA ДЛЯ ЧТЕНИЯ
; ============================================================
setup_fdc_dma:
    pusha

    ; Маскируем канал 2
    mov al, 0x06
    out 0x0A, al

    ; Сбрасываем байтовый указатель
    xor al, al
    out 0x0C, al

    ; Режим: одиночная передача, чтение из периферии
    mov al, 0x46
    out 0x0B, al

    ; Адрес буфера
    mov eax, fdc_dma_buffer
    ; Преобразуем в физический адрес (если нужно)
    out 0x04, al            ; Младший байт
    shr eax, 8
    out 0x04, al            ; Средний байт
    shr eax, 8
    out 0x81, al            ; Страница (старший байт)

    ; Сбрасываем байтовый указатель
    xor al, al
    out 0x0C, al

    ; Размер передачи (511 = 512-1)
    mov ax, 511
    out 0x05, al            ; Младший байт
    mov al, ah
    out 0x05, al            ; Старший байт

    ; Размаскируем канал 2
    mov al, 0x02
    out 0x0A, al

    popa
    ret
; ============================================================
; ТЕСТ ЧТЕНИЯ СЕКТОРА
; ============================================================
test_read_sector:
    pusha

    mov esi, msg_testing_read
    call print_string32
    call new_line32

    ; Читаем сектор 0 (загрузочный сектор) с диска A:
    mov eax, 0               ; LBA 0
    mov bl, 0                ; Drive A
    mov edi, test_buffer     ; Куда читать
    call fdc_read_sector

    jc .failed

    ; Выводим первые 32 байта для проверки
    mov esi, msg_first_bytes
    call print_string32
    call new_line32

    mov ecx, 32
    mov esi, test_buffer
.show_bytes:
    lodsb
    push eax
    shr al, 4
    call .nibble
    pop eax
    and al, 0x0F
    call .nibble
    mov al, ' '
    call print_char32
    loop .show_bytes
    call new_line32

    jmp .done

.failed:
    mov esi, msg_read_failed
    call print_string32
    call new_line32

.done:
    popa
    ret

.nibble:
    add al, '0'
    cmp al, '9'
    jbe .print
    add al, 7
.print:
    call print_char32
    ret

msg_testing_read:  db 'Testing sector read...', 0
msg_first_bytes:   db 'First 32 bytes of sector 0:', 0
msg_read_failed:   db 'Read failed!', 0

test_buffer: resb 512
; ============================================================
; ЧТЕНИЕ СЕКТОРА С ФЛОППИ-ДИСКОВОДА
; Вход: EAX = номер LBA сектора (0-2879)
;       BL  = номер дисковода (0=A, 1=B)
;       EDI = буфер для данных (минимум 512 байт)
; Выход: CF=0 успех, CF=1 ошибка
;        AL  = код ошибки (если CF=1)
; ============================================================
fdc_read_sector:
    pusha

    ; Сохраняем параметры
    mov [.lba], eax
    mov [.drive], bl
    mov [.buf], edi

    ; === ПРОВЕРКА ПАРАМЕТРОВ ===
    cmp eax, 2880              ; Максимум 2880 секторов (80*2*18)
    jae .error_params

    cmp bl, 1                  ; Только дисководы 0 и 1
    ja .error_params

    ; === ШАГ 1: Конвертация LBA → CHS ===
    xor edx, edx
    mov ecx, FLOPPY_SECTORS_PER_TRACK * FLOPPY_HEADS  ; 36
    div ecx
    mov [.cyl], al             ; C = LBA / 36

    mov eax, edx
    xor edx, edx
    mov ecx, FLOPPY_SECTORS_PER_TRACK  ; 18
    div ecx
    mov [.head], al            ; H = (LBA % 36) / 18
    inc dl
    mov [.sect], dl            ; S = (LBA % 18) + 1

    ; Выводим отладочную информацию
    mov esi, msg_reading_sector
    call print_string32
    call new_line32

    mov esi, msg_lba_addr
    call print_string32
    mov eax, [.lba]
    call print_dec32
    call new_line32

    mov esi, msg_chs_params
    call print_string32
    movzx eax, byte [.cyl]
    call print_dec32
    mov al, '/'
    call print_char32
    movzx eax, byte [.head]
    call print_dec32
    mov al, '/'
    call print_char32
    movzx eax, byte [.sect]
    call print_dec32
    call new_line32

    ; === ШАГ 2: Проверка, что мотор включён ===
    mov al, [.drive]
    call fdc_motor_on

    ; === ШАГ 3: Позиционирование головки (Seek) ===
    mov ch, [.cyl]
    mov dh, [.head]
    mov dl, [.drive]
    call fdc_seek
    jc .error_seek

    ; === ШАГ 4: Настройка DMA ===
    call setup_fdc_dma

    ; === ШАГ 5: Отправка команды READ DATA ===
    ; Сбрасываем флаг прерывания
    mov byte [fdd_irq_received], 0

    ; Вычисляем байт привода/головки
    mov al, [.head]
    shl al, 2                  ; head * 4
    and al, 0x04               ; Только бит 2
    mov ah, [.drive]
    and ah, 0x01               ; Только бит 0
    or al, ah                  ; Объединяем

    mov [.drive_head_byte], al

    ; Отправляем 9 байт команды
    mov dx, FLOPPY_FIFO

    ; Байт 0: Команда READ DATA
    mov al, FLOPPY_CMD_READ | FLOPPY_CMD_EXT_MT | FLOPPY_CMD_EXT_MFM | FLOPPY_CMD_EXT_SKIP
    call fdc_send_byte
    jc .error_send

    ; Байт 1: Привод/головка
    mov al, [.drive_head_byte]
    call fdc_send_byte
    jc .error_send

    ; Байт 2: Цилиндр
    mov al, [.cyl]
    call fdc_send_byte
    jc .error_send

    ; Байт 3: Головка
    mov al, [.head]
    call fdc_send_byte
    jc .error_send

    ; Байт 4: Сектор
    mov al, [.sect]
    call fdc_send_byte
    jc .error_send

    ; Байт 5: Размер сектора (2 = 512 байт)
    mov al, 2
    call fdc_send_byte
    jc .error_send

    ; Байт 6: Последний сектор (EOT)
    mov al, FLOPPY_SECTORS_PER_TRACK
    call fdc_send_byte
    jc .error_send

    ; Байт 7: Gap length
    mov al, 0x1B
    call fdc_send_byte
    jc .error_send

    ; Байт 8: DTL (специальный)
    mov al, 0xFF
    call fdc_send_byte
    jc .error_send

    ; === ШАГ 6: Ожидание прерывания ===
    call fdc_wait_irq
    jc .error_timeout

    ; === ШАГ 7: Чтение результатов (7 байт) ===
    mov ecx, 7
.read_results:
    push ecx
    call fdc_read_byte
    pop ecx
    loop .read_results

    ; === ШАГ 8: Sense Interrupt ===
    call fdc_sense_interrupt

    ; === ШАГ 9: Копирование данных из DMA буфера ===
    mov esi, fdc_dma_buffer
    mov edi, [.buf]
    mov ecx, 512
    rep movsb

    ; === УСПЕХ! ===
    mov esi, msg_read_success
    call print_string32
    call new_line32

    popa
    clc
    xor al, al
    ret

.error_params:
    mov esi, msg_error_params
    call print_string32
    popa
    stc
    mov al, 1
    ret

.error_seek:
    mov esi, msg_error_seek
    call print_string32
    popa
    stc
    mov al, 2
    ret

.error_send:
    mov esi, msg_error_send
    call print_string32
    popa
    stc
    mov al, 3
    ret

.error_timeout:
    mov esi, msg_error_timeout
    call print_string32
    popa
    stc
    mov al, 4
    ret

; Локальные переменные
.lba:             dd 0
.buf:             dd 0
.drive:           db 0
.cyl:             db 0
.head:            db 0
.sect:            db 0
.drive_head_byte: db 0
; ============================================================
; СБРОС КОНТРОЛЛЕРА FDC
; ============================================================
fdc_reset:
    push eax
    push edx

    ; Сбрасываем контроллер через DOR
    mov dx, FDC_DOR
    mov al, 0x00               ; Сброс
    out dx, al

    ; Небольшая задержка
    mov ecx, 100
.delay1:
    nop
    loop .delay1

    ; Включаем контроллер с DMA/INT
    mov al, 0x0C               ; Включить, но мотор выключен
    out dx, al

    ; Ждём готовности
    mov ecx, 0xFFFF
.wait_reset:
    mov dx, FDC_MSR
    in al, dx
    test al, 0x80              ; RQM=1?
    jnz .reset_done
    loop .wait_reset

.reset_done:
    ; Посылаем Sense Interrupt 4 раза (по одному на каждый привод)
    mov ecx, 4
.sense_loop:
    push ecx
    call fdc_sense_int
    pop ecx
    loop .sense_loop

    pop edx
    pop eax
    ret
; ============================================================
; УСТАНОВКА ПАРАМЕТРОВ ПРИВОДА (SPECIFY)
; ============================================================
fdc_specify:
    pusha

    mov dx, FLOPPY_FIFO
    mov al, FLOPPY_CMD_SPECIFY  ; 0x03
    out dx, al

    call fdc_wait_write
    mov al, 0xAF                ; Step rate 12ms, head unload 240ms
    out dx, al

    call fdc_wait_write
    mov al, 0x02                ; Head load 4ms, DMA mode
    out dx, al

    popa
    ret
; ============================================================
; РЕКАЛИБРОВКА ПРИВОДА (RECALIBRATE)
; ============================================================
fdc_recalibrate:
    pusha

    ; Отправляем команду
    mov dx, FLOPPY_FIFO
    mov al, FLOPPY_CMD_RECALIBRATE  ; 0x07
    out dx, al

    call fdc_wait_write
    mov al, 0x00                    ; Drive 0
    out dx, al

    ; Ждём прерывания
    call fdc_wait_irq

    ; Sense Interrupt
    call fdc_sense_interrupt

    popa
    ret
; ============================================================
; НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ ТАЙМЕРА ЗАДЕРЖЕК
; ============================================================
delay_timer_callback: dd 0    ; Адрес функции обратного вызова
delay_timer_flag:     db 0    ; Флаг завершения задержки

; ============================================================
; ОБРАБОТЧИК ТАЙМЕРА ДЛЯ ЗАДЕРЖЕК (ПОЛНОСТЬЮ НОВЫЙ)
; ============================================================
timer_delay_handler:
    pusha

    ; Устанавливаем флаг завершения
    mov byte [delay_timer_flag], 1

    ; Вызываем callback если есть
    cmp dword [delay_timer_callback], 0
    je .no_callback

    call [delay_timer_callback]
    mov dword [delay_timer_callback], 0  ; Очищаем после вызова

.no_callback:
    call send_eoi
    popa
    iret

; ============================================================
; ФУНКЦИЯ ЗАДЕРЖКИ (ИСПОЛЬЗУЕТ НОВЫЕ ПЕРЕМЕННЫЕ)
; ============================================================
timer_delay_ms:
    pusha

    ; Сохраняем callback
    mov [delay_timer_callback], ebx
    mov byte [delay_timer_flag], 0

    ; Вычисляем количество тиков
    mov ecx, [cpu_ticks_per_ms]
    mul ecx

    ; Настраиваем LAPIC на одноразовый режим
    mov esi, [lapic_base]
    mov dword [esi + LAPIC_TIMER_INITIAL], eax
    mov dword [esi + LAPIC_TIMER_LVT], 0x20  ; Одноразовый режим

    sti

.wait_loop:
    hlt
    cmp byte [delay_timer_flag], 1
    jne .wait_loop

    ; Сбрасываем флаг
    mov byte [delay_timer_flag], 0

    ; Восстанавливаем периодический режим
    mov esi, [lapic_base]
    mov eax, [cpu_ticks_per_ms]
    mov dword [esi + LAPIC_TIMER_INITIAL], eax
    mov dword [esi + LAPIC_TIMER_LVT], 0x20 | (1 << 17)

    popa
    ret

; ============================================================
; ОБРАБОТЧИК ОДНОРАЗОВОГО ТАЙМЕРА
; ============================================================
timer_oneshot_handler:
    pusha

    ; Устанавливаем флаг завершения
    mov byte [timer_delay_done], 1

    ; Вызываем callback если задан
    cmp dword [timer_delay_callback], 0
    je .no_callback

    call [timer_delay_callback]
    mov dword [timer_delay_callback], 0

.no_callback:
    call send_eoi
    popa
    iret

; ============================================================
; ОПРЕДЕЛЕНИЕ ТИПА ДИСКОВОДА ПО КОДУ
; ============================================================
fdd_type_string:
    cmp al, 0
    je .none
    cmp al, 1
    je .type_360
    cmp al, 2
    je .type_1200
    cmp al, 3
    je .type_720
    cmp al, 4
    je .type_1440
    cmp al, 5
    je .type_2880

    mov esi, msg_unknown_type
    ret

.none:
    mov esi, msg_no_drive
    ret
.type_360:
    mov esi, msg_360kb
    ret
.type_1200:
    mov esi, msg_1200kb
    ret
.type_720:
    mov esi, msg_720kb
    ret
.type_1440:
    mov esi, msg_1440kb
    ret
.type_2880:
    mov esi, msg_2880kb
    ret

; ============================================================
; ДЕТЕКТОР ФЛОППИ-ДИСКОВОДОВ ЧЕРЕЗ CMOS
; ============================================================
detect_floppy_drives:
    pusha

    mov esi, msg_fdd_detect_start
    call print_string32
    call new_line32

    ; Читаем CMOS ячейку 0x10
    mov al, 0x10
    out 0x70, al
    in al, 0x71          ; AL = информация о дисководах

    ; Сохраняем сырое значение для отладки
    mov [cmos_raw_value], al

    ; Выводим сырое значение
    mov esi, msg_cmos_raw
    call print_string32
    movzx eax, byte [cmos_raw_value]
    call print_hex32
    call new_line32

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
    mov esi, msg_primary
    call print_string32

    mov al, [primary_type]
    call fdd_type_string
    call print_string32
    call new_line32

    ; Доп. информация о типе
    cmp byte [primary_type], 4
    jne .check_primary_other

    ; Это 1.44 МБ - стандартный дисковод!
    mov esi, msg_primary_1440_detected
    call print_string32
    call new_line32

    mov byte [fdd_available], 1

.check_primary_other:
    cmp byte [primary_type], 0
    jne .primary_available
    jmp .check_secondary

.primary_available:
    mov byte [fdd_available], 1

    ; === ВЫВОД ИНФОРМАЦИИ О SECONDARY ===
.check_secondary:
    mov esi, msg_secondary
    call print_string32

    mov al, [secondary_type]
    call fdd_type_string
    call print_string32
    call new_line32

    cmp byte [secondary_type], 4
    jne .done

    mov esi, msg_secondary_1440_detected
    call print_string32
    call new_line32

.done:
    ; Итоговая информация
    call new_line32
    mov esi, msg_fdd_summary
    call print_string32
    call new_line32

    cmp byte [fdd_available], 1
    je .fdd_found

    ; Дисководов нет
    mov esi, msg_no_fdd
    call print_string32
    call new_line32
    jmp .exit

.fdd_found:
    mov esi, msg_fdd_detected
    call print_string32
    call new_line32

    ; Выводим параметры дисковода (стандартные для 1.44MB)
    mov esi, msg_fdd_params
    call print_string32
    call new_line32

    mov esi, msg_cylinders
    call print_string32
    mov eax, 80
    call print_dec32
    call new_line32

    mov esi, msg_heads
    call print_string32
    mov eax, 2
    call print_dec32
    call new_line32

    mov esi, msg_sectors
    call print_string32
    mov eax, 18
    call print_dec32
    call new_line32

    mov esi, msg_total_size
    call print_string32
    mov eax, 2880          ; 80*2*18 = 2880 секторов
    call print_dec32
    mov esi, msg_sectors_text
    call print_string32
    call new_line32
    mov eax, 1440          ; 2880 * 512 / 1024 = 1440 КБ
    call print_dec32
    mov esi, msg_kb_text
    call print_string32
    call new_line32

.exit:
    popa
    ret

; ============================================================
; ПЕРЕМЕННЫЕ ДЛЯ ДЕТЕКТОРА
; ============================================================
section .data

cmos_raw_value:   db 0
primary_type:     db 0
secondary_type:   db 0
fdd_available:    db 0

; ============================================================
; СООБЩЕНИЯ ДЛЯ ДЕТЕКТОРА
; ============================================================
msg_fdd_detect_start:        db '=== Floppy Drive Detection ===', 0
msg_cmos_raw:                db 'CMOS Register 0x10: 0x', 0
msg_primary:                 db 'Primary Drive (A:): ', 0
msg_secondary:               db 'Secondary Drive (B:): ', 0

; Типы дисководов
msg_no_drive:                db 'Not installed', 0
msg_360kb:                   db '360KB 5.25"', 0
msg_1200kb:                  db '1.2MB 5.25"', 0
msg_720kb:                   db '720KB 3.5"', 0
msg_1440kb:                  db '1.44MB 3.5"', 0
msg_2880kb:                  db '2.88MB 3.5"', 0
msg_unknown_type:            db 'Unknown type', 0

; Информационные сообщения
msg_primary_1440_detected:   db '  -> Standard 1.44MB drive detected!', 0
msg_secondary_1440_detected: db '  -> Additional 1.44MB drive detected!', 0
msg_fdd_summary:             db '--- Detection Summary ---', 0
msg_no_fdd:                  db 'No floppy drives found!', 0
msg_fdd_detected:            db 'Floppy drive(s) detected and ready!', 0
msg_fdd_params:              db '--- Standard 1.44MB Parameters ---', 0
msg_cylinders:               db 'Cylinders: ', 0
msg_heads:                   db 'Heads: ', 0
msg_sectors:                 db 'Sectors per track: ', 0
msg_total_size:              db 'Total capacity: ', 0
msg_sectors_text:            db ' sectors (', 0
msg_kb_text:                 db ' KB)', 0
; ============================================================
; СООБЩЕНИЯ ДЛЯ HELP
; ============================================================
msg_help_title:  db 'Available commands:', 0
msg_help_help:   db '  help    - Show this help', 0
msg_help_sysi:   db '  sys-i   - System information', 0
msg_help_clear:  db '  clear   - Clear screen', 0
msg_help_meminfo: db '  meminfo - Show memory info', 0
msg_help_crash:  db '  crash   - Test exception handler', 0
msg_help_reboot: db '  reboot  - Reboot system', 0

; ============================================================
; КОМАНДЫ (для сравнения)
; ============================================================
cmd_help:      db 'help', 0
cmd_sys_info:  db 'sys-i', 0
cmd_clear:     db 'clear', 0
cmd_meminfo:   db 'meminfo', 0
cmd_test_div0: db 'crash', 0
cmd_reboot:    db 'reboot', 0

msg_unknown_cmd: db 'Unknown command. Type "help" for list.', 0

; ============================================================
; УЛУЧШЕННОЕ СРАВНЕНИЕ СТРОК (до пробела/Enter/конца)
; ESI = введённая команда, EDI = эталонная команда
; Выход: CF=1 если равны, CF=0 если не равны
; ============================================================
strcmp:
    pusha
    mov ecx, 256           ; Максимальная длина
.loop:
    mov al, [esi]          ; Символ из ввода
    mov bl, [edi]          ; Символ из эталона

    ; Проверяем конец эталонной строки
    test bl, bl
    jz .check_input_end    ; Если эталон закончился - проверяем ввод

    ; Сравниваем символы
    cmp al, bl
    jne .not_equal

    inc esi
    inc edi
    dec ecx
    jz .not_equal
    jmp .loop

.check_input_end:
    ; Эталон закончился. Проверяем что ввод тоже закончился
    ; или следующий символ - пробел/Enter
    cmp al, 0              ; Конец строки?
    je .equal
    cmp al, ' '            ; Пробел?
    je .equal
    cmp al, 0x0D           ; Enter?
    je .equal
    cmp al, 0x0A           ; Перевод строки?
    je .equal

.not_equal:
    popa
    clc                     ; CF=0 - не равны
    ret

.equal:
    popa
    stc                     ; CF=1 - равны
    ret

; ============================================================
; МИНИ-ДРАЙВЕР ВИДЕОКАРТЫ (VGA текстовый режим)
; ============================================================

; Установка позиции курсора
set_cursor:
    pusha
    mov eax, [cursor_pos32]
    shr eax, 1              ; Делим на 2 (каждый символ = 2 байта)

    ; Отправляем в VGA контроллер
    mov edx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc edx
    mov al, bl              ; Младший байт позиции
    out dx, al

    dec edx
    mov al, 0x0E
    out dx, al
    inc edx
    mov al, bh              ; Старший байт позиции
    out dx, al

    popa
    ret

; Получение текущей позиции курсора
get_cursor:
    push edx
    mov edx, 0x3D4
    mov al, 0x0F
    out dx, al
    inc edx
    in al, dx
    mov bl, al

    dec edx
    mov al, 0x0E
    out dx, al
    inc edx
    in al, dx
    mov bh, al

    shl ebx, 1              ; Умножаем на 2
    mov [cursor_pos32], ebx
    pop edx
    ret

; Изменение цвета текста
set_text_color:
    ; AL = цвет (0x0F = белый на чёрном)
    mov [current_color], al
    ret

current_color: db 0x0F


; ============================================================
; СООБЩЕНИЯ
; ============================================================
msg_help:       db 'Available commands:', 0
msg_help_cmds:  db 'help, sys-i, clear, meminfo, crash, reboot', 0
msg_os_name:    db 'NekoOS 32-bit', 0
msg_os_ver:     db 'Version 0.1 Beta', 0
msg_rebooting:  db 'Rebooting...', 0
msg_idt_loaded: db 'IDT loaded and interrupts enabled!', 0

; ============================================================
; ДАННЫЕ
; ============================================================
msg_ioapic_setup: db 'Setting up I/O APIC...', 0
msg_ioapic_id:    db 'I/O APIC ID: ', 0
msg_ioapic_ok:    db 'I/O APIC configured', 0


;LAPIC
apic_id:      db 0
apic_version: db 0

; APIC структуры
lapic_base:     dd 0
ioapic_base:    dd 0
apic_timer_div: dd 0

; Сообщения
msg_apic_init:      db 'Initializing LAPIC...', 0
msg_apic_ok:        db 'LAPIC initialized successfully', 0
msg_apic_base_addr: db 'LAPIC base: 0x', 0
msg_apic_id:        db 'LAPIC ID: ', 0
msg_apic_version:   db 'LAPIC version: ', 0
;pic
msg_pic_disable: db 'Disable Pic',0
; Сообщения
msg_checking_ic:   db 'Checking interrupt controller...', 0
msg_apic_active:   db 'APIC is active and enabled', 0
msg_apic_disabled: db 'APIC supported but disabled', 0
msg_xapic:         db 'Type: xAPIC', 0
msg_x2apic:        db 'Type: x2APIC', 0
msg_8259pic:       db 'Only 8259 PIC available', 0
msg_will_use_pic:  db 'Will use legacy PIC mode', 0
msg_unknown_interput:       db 'Cannot determine (no CPUID)', 0

align 4
gdt_limit_blocks:  dw 0
gdt_address:       dw 0
cursor_pos32:      dd 0

; GDT дескриптор для lgdt
align 4
gdt_descriptor:
    dw 0                     ; Размер GDT - 1
    dd 0                     ; Адрес GDT

; Селекторы (как в твоём коде)
CODE_SEG equ 0x08
DATA_SEG equ 0x10

; Сообщения
msg_protected_mode: db 'Protected Mode (32-bit) Active!', 0
msg_ram_info:       db 'Total RAM: ', 0
msg_equals: db ' = ', 0

; ============================================================
; БУФЕР КЛАВИАТУРЫ И ОБОЛОЧКА
; ============================================================

; Буфер клавиатуры (512 байт)
keyboard_buffer:    times 512 db 0
keyboard_buf_pos:   dd 0
keyboard_buf_size:  equ 512

; Командная строка (после нажатия Enter копируем сюда)
command_buffer32:     times 256 db 0
command_length:     dd 0

; Буфер для вывода (для sprintf и т.д.)
print_buffer:       times 64 db 0

; Переменные оболочки
shell_prompt:       db 'NekoOS> ', 0
shell_running:      db 1

; Сообщения
msg_welcome:        db 'Welcome to NekoOS 32-bit Shell!', 0

; ============================================================
; КОНСТАНТЫ ПАМЯТИ
; ============================================================
PAGE_SIZE           equ 4096        ; 4 КБ
PAGE_TABLE_ENTRIES  equ 1024        ; Записей в таблице страниц
PAGE_DIR_ENTRIES    equ 1024        ; Записей в каталоге страниц
RESERVED_END_KB     equ 20          ; Отступ от конца ОЗУ в КБ

; ============================================================
; СТРУКТУРЫ ДЛЯ МЕНЕДЖЕРА ПАМЯТИ
; ============================================================

align 4096

; Физические адреса
total_memory_bytes:     dd 0        ; Общий объём ОЗУ в байтах
total_memory_kb:        dd 0        ; Общий объём ОЗУ в КБ
total_pages:            dd 0        ; Общее количество страниц
usable_pages:           dd 0        ; Доступно для пользователя

; Границы памяти
kernel_end_page:        dd 0        ; Конец ядра (в страницах)
user_pages_start:       dd 0        ; Начало пользовательских страниц
user_pages_count:       dd 0        ; Количество пользовательских страниц
reserved_pages_start:   dd 0        ; Начало зарезервированных страниц

; Указатели на структуры пейджинга
page_directory:         dd 0        ; Физический адрес каталога страниц
page_table_kernel:      dd 0        ; Таблица страниц ядра
page_table_user:        dd 0        ; Таблица страниц пользователя

; Битовые карты
pages_bitmap:           dd 0        ; Указатель на битовую карту
pages_bitmap_size:      dd 0        ; Размер битовой карты в байтах
; ============================================================
; ПОРТЫ КОНТРОЛЛЕРА FDC
; ============================================================
FDC_DOR         equ 0x3F2    ; Digital Output Register
FDC_MSR         equ 0x3F4    ; Main Status Register (чтение)
FDC_DSR         equ 0x3F4    ; Data Rate Select (запись)
FDC_FIFO        equ 0x3F5    ; Data FIFO
FDC_DIR         equ 0x3F7    ; Digital Input Register
FDC_CCR         equ 0x3F7    ; Configuration Control Register

; Биты статуса MSR
MSR_RQM         equ 0x80     ; Request for Master (FIFO готов)
MSR_DIO         equ 0x40     ; Data Input/Output (направление)
MSR_NDMA        equ 0x20     ; Non-DMA mode
MSR_BUSY        equ 0x10     ; Command in progress
MSR_ACTD        equ 0x08     ; Drive D активен
MSR_ACTC        equ 0x04     ; Drive C активен
MSR_ACTB        equ 0x02     ; Drive B активен
MSR_ACTA        equ 0x01     ; Drive A активен

; Команды FDC
CMD_READ_DATA   equ 0x06     ; Чтение данных (MT=0, MFM=1, SK=0)
CMD_WRITE_DATA  equ 0x05     ; Запись данных (MT=0, MFM=1)
CMD_SENSE_INT   equ 0x08     ; Sense Interrupt Status
CMD_SPECIFY     equ 0x03     ; Specify
CMD_RECALIBRATE equ 0x07     ; Recalibrate (переместить на дорожку 0)

; Параметры диска (стандартный 3.5" 1.44MB)
SECTORS_PER_TRACK equ 18
HEADS_PER_CYL    equ 2
CYLINDERS         equ 80
BYTES_PER_SECTOR  equ 512

; Таймауты
FDC_TIMEOUT      equ 0xFFFF
; ============================================================
; КОНСТАНТЫ FDC
; ============================================================
FDC_CMD_SENSE     equ 0x08   ; Sense Interrupt Status
FDC_CMD_READ      equ 0x06   ; Read Data
FDC_CMD_WRITE     equ 0x05   ; Write Data
FDC_CMD_SEEK      equ 0x0F   ; Seek
FDC_CMD_RECAL     equ 0x07   ; Recalibrate
FDC_CMD_SPECIFY   equ 0x03   ; Specify
;fdc_motor_on:    db 0        ; Флаг включения мотора
fdc_motor_count: db 0        ; Счётчик для авто-выключения
fdc_drive:       db 0        ; Текущий привод (0=A, 1=B)

; Буфер для временного хранения данных сектора
fdc_buffer:      times 512 db 0
; ============================================================
; ПОРТЫ FDC
; ============================================================
FLOPPY_DOR      equ 0x3F2    ; Digital Output Register
FLOPPY_MSR      equ 0x3F4    ; Main Status Register
FLOPPY_FIFO     equ 0x3F5    ; Data FIFO
FLOPPY_CTRL     equ 0x3F7    ; Control Register

; ============================================================
; КОМАНДЫ FDC
; ============================================================
FLOPPY_CMD_READ              equ 0x06    ; Чтение сектора
FLOPPY_CMD_WRITE             equ 0x05    ; Запись сектора
FLOPPY_CMD_SEEK              equ 0x0F    ; Поиск дорожки
FLOPPY_CMD_RECALIBRATE       equ 0x07    ; Рекалибровка
FLOPPY_CMD_SENSE_INTERRUPT   equ 0x08    ; Проверка прерывания
FLOPPY_CMD_SPECIFY           equ 0x03    ; Установка параметров

; Расширенные биты команд
FLOPPY_CMD_EXT_MT      equ 0x80    ; Мультитрековый режим
FLOPPY_CMD_EXT_MFM     equ 0x40    ; MFM режим
FLOPPY_CMD_EXT_SKIP    equ 0x20    ; Пропуск удалённых данных

; ============================================================
; ПАРАМЕТРЫ ДИСКА
; ============================================================
FLOPPY_SECTORS_PER_TRACK equ 18
FLOPPY_HEADS             equ 2
FLOPPY_CYLINDERS         equ 80
FLOPPY_SECTOR_SIZE       equ 512

fdd_irq_received:    db 0    ; Флаг получения IRQ6
fdc_dma_buffer:      times 512 db 0  ; DMA буфер
fdc_dma_buffer_phys: dd 0     ; Физический адрес буфера

; Переменные для FDC операций
fdc_io_byte:    db 0
fdc_st0:        db 0
fdc_st1:        db 0
fdc_st2:        db 0
fdc_cylinder:   db 0
msg_reading_sector:  db '--- Reading Sector ---', 0
msg_lba_addr:        db 'LBA address: ', 0
msg_chs_params:      db 'CHS: ', 0
msg_read_success:    db 'Sector read successfully!', 0
msg_error_params:    db 'Error: Invalid parameters!', 0
msg_error_seek:      db 'Error: Seek failed!', 0
msg_error_send:      db 'Error: Failed to send command!', 0
msg_error_timeout:   db 'Error: IRQ timeout!', 0

; ============================================================
; СООБЩЕНИЯ FDC ДРАЙВЕРА
; ============================================================
msg_fdc_timeout:    db 'FDC timeout!', 0
msg_fdc_busy:       db 'FDC busy!', 0
msg_fdc_read_error: db 'FDC read byte error!', 0
msg_fdc_read_fail:  db 'FDC read sector failed!', 0
msg_fdc_write_fail: db 'FDC write sector failed!', 0


; Указатели для FDC операций
fdc_read_buffer_ptr:  dd 0    ; Куда читаем
fdc_write_source_ptr: dd 0    ; Откуда пишем
; ============================================================
; ПЕРЕМЕННЫЕ ДЛЯ ТАЙМЕРА ЗАДЕРЖЕК
; ============================================================


timer_delay_callback: dd 0
timer_delay_done:     db 0
; ============================================================
; МАРКЕР КОНЦА ЯДРА
; ============================================================
end_of_kernel:
    db 0    ; Просто метка

kernel_end_physical: dd end_of_kernel
