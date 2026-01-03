use16

section .text
org 0x7e00
;----------------------------------initialization virtual terminal----------
BEGIN:
mov [boot_disk],dl
call paint_vt1
call paint_vt2
call paint_vt3
call paint_vt4
call paint_vt5
call paint_vt6
call paint_vt7
call paint_vt8
jmp start_sys
paint_vt1:
xor ax,ax
mov ah,0x5

int 0x10
;call clear_screen
mov si,msg_vt1
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt2:

mov ah,0x5
mov al,1
int 0x10
;call clear_screen
mov si,msg_vt2
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt3:

mov ah,0x5
mov al,2
int 0x10
;call clear_screen
mov si,msg_vt3
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt4:

mov ah,0x5
mov al,3
int 0x10
;call clear_screen
mov si,msg_vt4
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt5:

mov ah,0x5
mov al,4
int 0x10
;call clear_screen
mov si,msg_vt5
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt6:

mov ah,0x5
mov al,5
int 0x10
;call clear_screen
mov si,msg_vt6
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt7:

mov ah,0x5
mov al,6
int 0x10
;call clear_screen
mov si,msg_vt7
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret
paint_vt8:

mov ah,0x5
mov al,7
int 0x10
;call clear_screen
mov si,msg_vt8
call print_message
mov ah,0x0E
mov al,'>'
int 10h
mov ah,0x0E
mov al,'>'
int 10h
ret

msg_vt1: db 'page1',0
msg_vt2: db 'page2',0
msg_vt3: db 'page3',0
msg_vt4: db 'page4',0
msg_vt5: db 'page5',0
msg_vt6: db 'page6',0
msg_vt7: db 'page7',0
msg_vt8: db 'page8',0
start_sys:
xor ax,ax
mov ah,0x5
int 0x10
init_sound_blaster:
mov dx,220h
add dx,6
mov ax,1
out dx,ax
mov cx,3000

call rep_timer
mov cx,3000
call rep_timer
mov cx,3000
mov dx,220h
add dx,6
xor ax,ax
out dx,ax
call rep_timer
mov cx,3000
call rep_timer

mov dx,220h
add dx,0Ah
in ax,dx
cmp ax,0AAh
jnz sound_blast_220_false
mov si,mesg_sound_true
call print_message
call new_label
volume_mixer:
mov al,04h
mov ah,20h
call mixer_reg
mov al,05h
mov ah,20h
call mixer_reg
call play_beep
jmp phantom
rep_timer:
dec cx
cmp cx,1
jnz rep_timer
ret
sound_blast_220_false:
mov dx,240h
add dx,6
mov ax,1
out dx,ax
mov cx,3000
call rep_timer
mov cx,3000
call rep_timer
mov dx,240h
add dx,6
xor ax,ax
out dx,ax

mov cx,3000
call rep_timer
mov cx,3000
call rep_timer
mov dx,240h
add dx,0Ah
in ax,dx
cmp ax,0AAh
jnz sound_blast_240_false
mov si,mesg_sound_true
call print_message
call new_label

jmp phantom
sound_blast_240_false:
mov si,mesg_sound_blast
call print_message
call new_label

jmp phantom
mesg_sound_blast: db 'Sound blast no detect',0
mesg_sound_true: db 'sound detect',0

mixer_reg:
mov dx,224h
out dx,al
mov dx,225h
mov al,ah
out dx,al
ret
play_beep:
beep_loop:
    push cx
    mov si, msg_beep
    call print_message
    call new_label
    ; Проигрываем один бип через DMA
    call play_single_beep

    ; Пауза между бипами
    mov cx, 0FFFFh
    delay: loop delay

    pop cx
    loop beep_loop

    mov si, msg_done_beep
    call print_message
    call new_label
    jmp done

error:
    mov si, msg_error_bep
    call print_message

done:
    ret
    msg_error_bep:  db 'Eror beep',0
    msg_beep:   db 'Beep! ', 0
msg_done_beep:   db 'Done!',0
; ==============================================
; Проигрывает один бип через DMA
; ==============================================
play_single_beep:
    ; 1. Подготавливаем DMA
    call setup_dma_for_beep

    ; 2. Настраиваем Sound Blaster
    mov dx, 22Ch           ; SB_WRITE_CMD

    ; Устанавливаем режим однократного воспроизведения
    mov al, 48h            ; Установить размер блока
    out dx, al
    call wait_dsp

    ; Размер блока = длина бип данных - 1
    mov ax, beep_data_length
    dec ax
    mov al, ah             ; Старший байт
    out dx, al
    call wait_dsp
    mov al, al             ; Младший байт
    out dx, al
    call wait_dsp

    ; Запускаем воспроизведение
    mov al, 1Ch            ; 8-бит PCM воспроизведение
    out dx, al
    call wait_dsp

    ; 3. Ждем завершения DMA
    call wait_for_dma

    ret

; ==============================================
; Настройка DMA для бип данных
; ==============================================
setup_dma_for_beep:
    ; 1. Отключаем канал DMA 1
    mov al, 05h            ; Канал 1 + бит маски (04h)
    out 0Ah, al

    ; 2. Сбрасываем флип-флоп
    mov al, 0
    out 0Ch, al

    ; 3. Устанавливаем режим передачи
    mov al, 48h            ; Режим чтения, одиночная передача, канал 1
    out 0Bh, al

    ; 4. Устанавливаем адрес (beep_data находится по адресу 0x1000)
    mov ax, ds
    mov cl, 12
    shr ax, cl             ; AX = страница (биты 16-19)
    mov al, 01h            ; Страница 0x01 (для адреса 0x1000)
    out 83h, al            ; Порт страницы для канала 1

    ; 5. Устанавливаем младшие биты адреса
    mov ax, beep_data      ; Смещение beep_data в сегменте
    out 02h, al            ; Младший байт
    mov al, ah
    out 02h, al            ; Старший байт

    ; 6. Устанавливаем длину (длина - 1)
    mov ax, beep_data_length
    dec ax
    out 03h, al            ; Младший байт длины
    mov al, ah
    out 03h, al            ; Старший байт

    ; 7. Включаем канал DMA
    mov al, 01h            ; Канал 1
    out 0Ah, al
ret
wait_dsp:
mov dx,22eh
mov cx,1000
.wait:
in al,dx
test al,80h
jz .ready
loop .wait
.ready:
ret
wait_for_dma:
    ; Простая задержка вместо проверки статуса DMA
    mov cx, 5
.delay:
    push cx
    mov cx, 0FFFFh
    .wait: loop .wait
    pop cx
    loop .delay
    ret
; ==============================================
; Данные для бипа (простой тон 1000 Гц)
; ==============================================
beep_data:
    ; Генерируем простой синусоидальный тон
    db 128, 140, 152, 164, 176, 188, 200, 212, 224, 236, 248, 255
    db 248, 236, 224, 212, 200, 188, 176, 164, 152, 140, 128, 116
    db 104, 92, 80, 68, 56, 44, 32, 20, 8, 0, 8, 20, 32, 44, 56, 68, 80, 92, 104, 116
beep_data_length: equ $ - beep_data
phantom:
xor cx,cx
xor ax,ax
mov al,[curent_display]
cmp al,0
jz phantom1
cmp al,1
jz phantom2
cmp al,2
jz phantom3
cmp al,3
jz phantom4
cmp al,4
jz phantom5
cmp al,5
jz phantom6
cmp al,6
jz phantom7
cmp al,7
jz phantom8
jmp phantom1
phantom1:
call paint_vt1
mov di,comand1

phantom1_kernel:
call v_board
inc cx
mov [length_comand1],cx
stosb
cmp al,13
jz comands1
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom1_kernel
comands1:
mov si,comand1
mov di,comand
mov cx,80
xor ax,ax
mov [curent_display],ax
comands1_rep:
lodsb
stosb
loop comands1_rep
jmp comands

phantom2:
call paint_vt2
mov di,comand2
phantom2_kernel:
call v_board
inc cx
mov [length_comand2],cx
stosb
cmp al,13
jz comands2
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print

jmp phantom2_kernel
comands2:
mov si,comand2
mov di,comand
mov cx,80
xor ax,ax
mov ax,1
mov [curent_display],ax
comands2_rep:
lodsb
stosb
loop comands2_rep
jmp comands
phantom3:
call paint_vt3
mov di,comand3
phantom3_kernel:
call v_board
inc cx
mov [length_comand3],cx
stosb
cmp al,13
jz comands3
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom3_kernel
comands3:
mov si,comand3
mov di,comand
mov cx,80
xor ax,ax
mov ax,2
mov [curent_display],ax
comands3_rep:
lodsb
stosb
loop comands3_rep
jmp comands
phantom4:
call paint_vt4
mov di,comand4
phantom4_kernel:
call v_board
inc cx
mov [length_comand4],cx
stosb
cmp al,13
jz comands4
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom4_kernel
comands4:
mov si,comand3
mov di,comand
mov cx,80
xor ax,ax
mov ax,3
mov [curent_display],ax
comands4_rep:
lodsb
stosb
loop comands4_rep
jmp comands
phantom5:
call paint_vt5
mov di,comand5
phantom5_kernel:
call v_board
inc cx
mov [length_comand5],cx
stosb
cmp al,13
jz comands5
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom5_kernel
comands5:
mov si,comand5
mov di,comand
mov cx,80
xor ax,ax
mov ax,4
mov [curent_display],ax
comands5_rep:
lodsb
stosb
loop comands5_rep
jmp comands
phantom6:
call paint_vt6
mov di,comand6
phantom6_kernel:
call v_board
inc cx
mov [length_comand6],cx
stosb
cmp al,13
jz comands6
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom6_kernel
comands6:
mov si,comand6
mov di,comand
mov cx,80
xor ax,ax
mov ax,5
mov [curent_display],ax
comands6_rep:
lodsb
stosb
loop comands6_rep
jmp comands
phantom7:
call paint_vt7
mov di,comand7
phantom7_kernel:
call v_board
inc cx
mov [length_comand7],cx
stosb
cmp al,13
jz comands7
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom7_kernel
comands7:
mov si,comand7
mov di,comand
mov cx,80
xor ax,ax
mov ax,6
mov [curent_display],ax
comands7_rep:
lodsb
stosb
loop comands7_rep
jmp comands
phantom8:
call paint_vt8
mov di,comand8
phantom8_kernel:
call v_board
inc cx
mov [length_comand8],cx
stosb
cmp al,13
jz comands8
cmp ah,59
jz f1_page
cmp ah,60
jz f2_page
cmp ah,61
jz f3_page
cmp ah,62
jz f4_page
cmp ah,63
jz f5_page
cmp ah,64
jz f6_page
cmp ah,65
jz f7_page
cmp ah,66
jz f8_page
call v_print
jmp phantom8_kernel
comands8:
mov si,comand8
mov di,comand
mov cx,80
xor ax,ax
mov ax,7
mov [curent_display],ax
comands8_rep:
lodsb
stosb
loop comands8_rep
jmp comands
f1_page:
mov di,comand1
xor ax,ax
mov ah,0x5
int 0x10
mov [curent_display],al
jmp phantom1_kernel
f2_page:
mov di,comand2
mov ah,0x5
mov al,1
int 0x10
mov [curent_display],al
jmp phantom2_kernel
f3_page:
mov di,comand3
mov ah,0x5
mov al,2
int 0x10
mov [curent_display],al
jmp phantom3_kernel
f4_page:
mov di,comand4
mov ah,0x5
mov al,3
int 0x10
mov [curent_display],al
jmp phantom4_kernel
f5_page:
mov di,comand5
mov ah,0x5
mov al,4
int 0x10
mov [curent_display],al
jmp phantom5_kernel
f6_page:
mov di,comand6
mov ah,0x5
mov al,5
int 0x10
mov [curent_display],al
jmp phantom6_kernel
f7_page:
mov di,comand7
mov ah,0x5
mov al,6
int 0x10
mov [curent_display],al
jmp phantom7_kernel
f8_page:
mov di,comand8
mov ah,0x5
mov al,7
int 0x10
mov [curent_display],al
jmp phantom8_kernel



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
jnz com_install_os ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz clear_screen
jmp rep_clear_screen
com_install_os:
mov di,comand
mov si,install_com
rep_install_os:
cmpsb
jnz com_fmp ;Важный участок прыгаем либо в ядро либо к следующей команде
mov al,[si]
test al,al
jz start_intall_os
jmp rep_install_os
com_fmp:
mov di,comand
mov si,fmp_com
rep_fmp:
cmpsb
jnz com_fmp_install
mov al,[si]
test al,al
jz fmp_help;The FMP HELL
jmp rep_fmp
com_fmp_install:
mov di,comand
mov si,fmp_install_flopy2
rep_install_fmp:
cmpsb
jnz com_adress
mov al,[si]
test al,al
jz install_app
jmp rep_install_fmp
com_adress:
mov di,comand
mov si,adres_com
rep_adres:
cmpsb
jnz com_mmm
mov al,[si]
test al,al
jz print_adres
jmp rep_adres
com_mmm:
mov di,comand
mov si,com_mmm_call
rep_mmm:
cmpsb
jnz com_pm_mod
mov al,[si]
test al,al
jz start_app
jmp rep_mmm
com_pm_mod:
mov di,comand
mov si,no_limit_com
rep_pm:
cmpsb
jnz go_kernel
mov al,[si]
test al,al
jz Protected_mod
jmp rep_pm

go_kernel:
jmp phantom



;-------------------data display----------------------
curent_display: db 0
comand1: times 80 db 0
comand2: times 80 db 0
comand3: times 80 db 0
comand4: times 80 db 0
comand5: times 80 db 0
comand6: times 80 db 0
comand7: times 80 db 0
comand8: times 80 db 0
length_comand1: dw 0
length_comand2: dw 0
length_comand3: dw 0
length_comand4: dw 0
length_comand5: dw 0
length_comand6: dw 0
length_comand7: dw 0
length_comand8: dw 0
;-----------------------------command------------------
comand: times 80 db 0
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
no_limit_com: db 'no limit',0
;----------------------------mesg---------------------
mesage: db 'programm start',0
message1: db   'start kernel sucssec!', 0
message2: db   'Hello Welcom to neko.',0
message3: db   'for to help menu write command help',0
help_message: db    'welcom to help menu',0
help_message1: db   'command1 help open help menu',0
help_message2: db 'command2 prog1 open programm1',0ah,0dh,'command3 disk-i-s print disk sector inform',0ah,0dh,'command4 sys-i print system information',0ah,0dh,'command5 clear is clear screen',0ah,0dh,'command6 install os is command instalation Operation system',0ah,0dh,'command7 no limit is start Protection mod',0
system_mesg: db 'Operation system neko',0ah,0dh,'version 17.0.0',0ah,0dh,'cod name Zombi',0
fmp_help_msg: db 'File Memory Protocol',0ah,0dh,'Main command',0ah,0dh,'1. fmp help is list comand fmp',0ah,0dh,'2. fmp create (name file) is create file on hdd',0ah,0dh,'3. fmp ls is scan file on hdd',0
no_comand_msg: db 'no comand',0ah,0dh,0
msg_y: db 'do you want continu pm mod press y',0
;-----------------------------------BOOT DISK---------------------------------------------------
boot_disk: db 0
;------------------------FUncion----------------------
v_board:
xor ax,ax
mov ah,0x00
int 0x16
ret
v_print:
mov ah, 0x0e; Устанавливаем значение AH для вывода символа
mov bh,[curent_display]; Страница
int  0x10
ret
;------------------------print message----------------
print_message:
    mov ah, 0x0e; Устанавливаем значение AH для вывода символа
    mov bh,[curent_display]; Страница
    puts_loop:
        lodsb            ; загружаем очередной символ в al
        test al, al      ; нулевой символ означает конец строки
        jz   puts_loop_exit
        int  0x10        ; вызываем функцию BIOS
        jmp  puts_loop
    puts_loop_exit:
    ret
new_label:
mov ah,0x0E
mov bh,[curent_display]; Страница
mov al,0Ah
int 10h
mov ah,0x0E
mov bh,[curent_display]; Страница
mov al,0Dh
int 10h
ret
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
mov cx,80*25
mov ah,0x0E
mov al,' '
clear_loop:
int 0x10
loop clear_loop
popa
mov ah,0x02
mov bh,[curent_display]
mov dh,0x00
mov dl,0x00
int 0x10
jmp go_kernel
start_intall_os:
;--------------------------------Scan Disk-------------------------------
mov dl, 0x80       ; DL = номер диска (0x80 = первый HDD)
    mov ah, 0x08       ; Функция GET DRIVE PARAMETERS
    mov di, 0x0000     ; ES:DI = буфер (необязательно)
    int 0x13
    jc error_disk      ; Если CF=1 - ошибка
;начинаем установку ос

write_booth:
    mov ah,03h
    mov al,1
    mov ch,0
    mov dl,80h
    mov dh,0
    mov cl,1
    mov bx,07c00h
    int 13h
write_kernel:
    mov ah,03h
    mov al,3
    mov ch,0
    mov dl,80h
    mov dh,0
    mov cl,2
    mov bx,07e00h
    int 13h
mov si,mesg_succes_install
call print_message
call new_label
    jmp go_kernel
message_eror_disk: db 'error disk',0
mesg_succes_install: db 'os installed',0
mesg_pizdec: db 'Os DEAD PIZDEC айцукенг',0
;----------------------------------EROR and KERNEL PANIC---------------------------------
shiza_kernel: ;-----------------Использовать только в случаи если ос пиздец----------------------------
;---------------------------------------Последний способ вылечить шизофрению ядра если он не сработал то ссылаемся на лецинзионное соглашение что пользователь сам виноват ЭТО ЗНАЧИТ ДИСК МЕРТВ или поврежден в будующем тут будет прыжок в раздел восстановления--------------------------------
mov si,mesg_pizdec
print_pizdec:
    mov ah, 0x0e; Устанавливаем значение AH для вывода символа
    mov bh,0x00; Страница
    puts_pizdec:
        lodsb            ; загружаем очередной символ в al
        test al, al      ; нулевой символ означает конец строки
        jz   puts_pizdec_exit
        int  0x10        ; вызываем функцию BIOS
        jmp  puts_pizdec
    puts_pizdec_exit:
jmp 0000:0x7c00;----------------------------- Последний рубеж ПЕРЕЗАГРУЗИТЬ ОС ЧЕРЕЗ ЗАГРУЗЧИК-------------------------------
error_disk:
mov si,message_eror_disk
call print_message
call new_label
jmp go_kernel
start_app:
call 0x100
mov si,end_app_mesg
call print_message
call new_label
jmp go_kernel
end_app_mesg: db 'end aplication',0
;--------------------------------adres-----------------
print_adres:
mov ax,MMM
call print_hex_word
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
    call print_hex_word
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

; Функция вывода строки
print_string:
    mov ah, 0x0E
.print_loop:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .print_loop
.done:
    ret

; Функция вывода HEX числа (AX)
print_hex_word:
    push ax
    mov al, ah
    call print_hex_byte
    pop ax
    call print_hex_byte
    ret

print_hex_byte:
    push ax
    shr al, 4
    call .print_digit
    pop ax
    and al, 0x0F
    call .print_digit
    ret
.print_digit:
    cmp al, 10
    jb .decimal
    add al, 'A' - 10
    jmp .print
.decimal:
    add al, '0'
.print:
    mov ah, 0x0E
    int 0x10
    ret
;-----------------------------fmp HELL---------------------------------------------
fmp_hell:
fmp_help:
mov si,flopy_fmp_com
call print_message
call new_label
jmp go_kernel
fmp_flopy:
; В работе
install_app:
; Загрузка aplication
mov si,inst_mesg
call print_message
call new_label
    read_flopy:
    mov ah,02h
    mov al,1
    mov ch,0
    mov dl,1 ;грузимся со второй дискетыe
    mov dh,0
    mov cl,1 ; Сектор который загружаем
    push 0000
    pop es
    mov bx,0x100
    int 13h
    xor bx,bx
    xor dx,dx
    jmp go_kernel
error_fmp_unknow: db 'unknow_command',0
inst_mesg: db 'install app',0
unknow_command:
mov si,error_fmp_unknow
call print_message
call new_label
jmp go_kernel
;-----------------------------fmp scan disk------------------------------------
mesg_process_ls: db 'start process ls',0
process_fmp_ls:
call new_label
mov si,mesg_process_ls
call print_message

mov dl,[boot_disk]       ; DL = номер диска (0x80 = первый HDD)
    mov ah, 0x08       ; Функция GET DRIVE PARAMETERS
    mov di, 0x0000     ; ES:DI = буфер (необязательно)
    int 0x13
    jc error_disk      ; Если CF=1 - ошибка
jmp go_kernel
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
db 'MMM',0
program_adr: dd 0x100
db 0
Protected_mod: ;start Protection Mod
xor ax,ax
mov ah,88h ;Total memory
int 15h
call print_hex_word
call new_label
mov si,msg_y
call print_message
call new_label
loop_pm_tf:
mov ah,0x00
int 0x16
cmp al,'y'
jz pm_march
jmp go_kernel


pm_march:
xor ax,ax
mov ah,0x5
int 0x10 ;video page 0
cli ;Игнорируем прерывания что бы не отвлекали
;Открыть линию А20
in al,92h
or al,02h
out 92h,al
xor al,al
lgdt[GDT_descript]
mov eax,cr0
    or al,1
    mov cr0,eax
    jmp COD_SEG:pmode
GDT:
gdt_null:
dd 0x0
dd 0x0
;cod segment
gdt_code:
dw 0xFFFF
dw 0x0
db 0x0
db 10011010b
db 11001111b
db 0x0
;data segment
gdt_data:
dw 0xFFFF
dw 0x0
db 0x0
db 10010010b
db 11001111b
db 0x0
GDT_END:
GDT_descript:
     dw GDT_END-GDT-1
     dd GDT
COD_SEG equ gdt_code-GDT
DATA_SEG equ gdt_data-GDT
    pmode:
    use32
    ; здесь настроим сегментные регистры
    mov ax, DATA_SEG
    ; data segment
    mov ds, ax
    ; stack segment
    mov ss, ax
    mov es,ax
    mov fs,ax
    mov gs,ax
    mov esp,top_pm_stek ;position stek
    xor esi,esi
    xor edi,edi
    jmp obsidian_kernel
pm_stek:
times 256 db 0
top_pm_stek:
video_mem: dd 0xB8000
        ; Финиш
        jmp obsidian_kernel
test_asm:
    pusha
    mov edx,[video_mem]
    mov al,'O'
    mov ah,0x0F
    mov [edx],ax
    add edx,2
    mov al,'k'
    mov ah,0x0F
    mov [edx],ax
    add edx,2
    add dword [video_mem],160
    popa
    ret
clear_screen32:
    pusha
    mov eax,0xB8000
    mov [video_mem],eax
    mov ecx,80*25
    xor eax,eax
    mov edx,[video_mem]
    loop_clear:
    mov [edx],ax
    inc edx
    mov [edx],ax
    inc edx
    loop loop_clear
    mov eax,0xB8000
    mov [video_mem],eax
    popa
    ret
obsidian_kernel:
call clear_screen32
call test_asm
cpu_id_test:
xor eax,eax
xor ebx,eax
xor ecx,ecx
xor edx,edx

pushfd
pop eax
mov ebx,eax
xor eax,200000h
push eax
popfd
pushfd
pop eax
xor eax,ebx
je no_cpuid


aida_kill:
xor eax,eax
mov eax,0x00000000
cpuid
mov [str_cpu_vendor],ebx
mov [str_cpu_vendor+4],edx
mov [str_cpu_vendor+8],ecx
mov esi,str_cpu_vendor
call printf_str
cmp eax,0x0000000B
jb .try_amd_topology
xor ecx,ecx
.get_intel_topology
mov eax,0x00000000
cpuid
cmp eax,4
jb .old_kernel_intel ;ВСЕГО ОДНО ядро это процессоры эпохи пня4
xor ecx,ecx
xor eax,eax
xor ebx,ebx
xor edx,edx
mov eax,0xB ;ПОТОКИ
cpuid
mov [thread],ebx

call threadings

mov esi,str_thread
call printf_str
mov esi,str_num
call printf_str
mov ecx,1
mov eax,0xB
cpuid
mov [core],ebx
cmp ebx,1
jz one_cor
cmp ebx,2
jz duo_cor
jmp True_kernel

.try_amd_topology
mov eax,0x8000001E
cpuid
mov esi,str_amd
call printf_str
jmp True_kernel
.old_kernel_intel
mov eax,1
cpuid
test edx,(1<<28)
jz .one_kernel_intel
mov esi,str_old_cor2
call printf_str
jmp True_kernel
.one_kernel_intel
mov esi,str_one_kernel
call printf_str

jmp True_kernel

printf_str:
pusha
mov edx,[video_mem]
xor eax,eax
lop_str:
lodsb
test al,al
jz exit_str
mov ah,0x0F
mov [edx],ax
add edx,2
jmp lop_str
exit_str:
add dword [video_mem],160
popa
ret
;---------------------------------------------------Data-------------------------------------
thread: db 0
core: db 0

;---------------------------------------------------String-----------------------------------
str_one_kernel: db 'One kernel you processor HUINYA',0
str_thread: db 'thread ',0
str_intel: db 'intel topology',0
str_old_cor2: db 'old cor',0
str_phys_core: db 'physical core ',0
str_amd: db 'amd topology',0
str_no_cpuid: db 'no cpuid, no inform processor',0
str_num: db '1',0
str_cpu_vendor: times 13 db 0
;---------------------------------------------------True neko----------------------------------
no_cpuid:
mov esi,str_no_cpuid
call printf_str
jmp True_kernel
one_cor:
mov si,str_phys_core
call printf_str

xor eax,eax
mov eax,'1'
mov [str_num],eax

mov si,str_num
call printf_str
jmp True_kernel
duo_cor:
xor eax,eax
mov eax,'2'
mov [str_num],eax
mov si,str_phys_core
call printf_str
mov si,str_num
call printf_str
jmp True_kernel
threadings:
pusha
mov eax,[thread]
cmp eax,1
jnz duo_thread
mov eax,'1'
mov [str_num],eax
jmp end_threadings
duo_thread:
cmp eax,2
jnz four_thread
mov eax,'2'
mov [str_num],eax
jmp end_threadings
four_thread:
cmp eax,4
jnz end_threadings
mov eax,'4'
mov [str_num],eax
jmp end_threadings
end_threadings:
popa
ret
mesg_wai: db 'waiting key a',0
debug32:
pusha
mov esi,mesg_wai
call printf_str
xor edx,edx
xor eax,eax
xor ebx,ebx
.waiting_key:
mov edx,0x60
xor eax,eax
xor ebx,ebx
in ax,dx
mov ebx,0x1E
and bx,ax
cmp bx,0x1E
jz .true_key

jmp .waiting_key
.true_key:
popa
ret
True_kernel:
cli
;call disable_apic
;Насинаем подготовку к переходу в IA-32e

mov eax,cr4
or eax,1 << 5
mov cr4,eax
xor eax,eax
mov eax,pml4_table
mov cr3,eax
xor ecx,ecx
mov ecx,0xC0000080
rdmsr
or eax,1 << 8
wrmsr
lgdt[gdt64_desc]
mov eax,cr0

or eax,1 << 31

mov cr0,eax

jmp gdt64_cod_seg:True_long

align 4096
pml4_table:
dq pdp_table + 0x03
times 511 dq 0

pdp_table:

dq 0x000000000000000083
dq 0x000000004000000083
dq 0x000000008000000083
dq 0x00000000C000000083
times 508 dq 0

gdt64:
;gdt64_null
dq 0x00000000000000000
gdt_code64:
dw 0xFFFF
dw 0x0000
db 0x00
db 0x9A
db 0x20
db 0x00
gdt_data64:
dw 0xFFFF
dw 0x0000
db 0x00
db 0x92
db 0x00
db 0x00
gdt64_end:
gdt64_desc:
dw gdt64_end-gdt64-1
dd gdt64
gdt64_cod_seg: equ gdt_code64-gdt64
gdt64_data_seg: equ gdt_data64-gdt64
;Создаем страницы

;pml4_table:
;dd pdp_table & 0xFFFFFFFF
;db 0x03
;db (pdp_table >> 32) & 0xFF
;dw (pdp_table >> 40) & 0xFFFF
;times (512-1)*8 db 0
;pdp_table:
;dd 0x00000000
;db 0x83
;db 0x00
;dw 0x0000
;
;dd 0x40000000
;db 0x83
;db 0x00
;dw 0x0000
;
;dd 0x80000000
;db 0x83
;db 0x00
;dw 0x0000
;
;dd 0xC0000000
;db 0x83
;db 0x00
;dw 0x0000
;
;times (512-4) * 8 db 0

bits 64
True_long:
mov ax,gdt64_data_seg
mov ds,ax
mov es,ax
mov fs,ax
mov gs,ax
mov ss,ax


the_kernel:
mov rsp,0x1000000
push 0x10000000
pop r8
cmp r8,0x10000000
jz the_true_neko

jmp hltt
;-----------------------------------------------True IA-32e Kernel-----------------------------------------------
the_true_neko:
call new_label64
call new_label64
call new_label64
call new_label64
call new_label64
call new_label64
call print_satrt_long_mod
call ok_64
mov r9,0x16
mov rsi,mesg_tets_64
call printf_str64
jmp zombi_mod
align 16
%macro idt_entry 2
dw (%1 & 0xFFFF)
dw 0x08
db 0
db %2
dw ((%1) >> 16) & 0xFFFF
dd ((%1) >> 32) & 0xFFFFFFFF
dd 0
%endmacro
idt64:
idt_entry divide_zero, 0x8E ;0
idt_entry plug_idt, 0x8E ;1
idt_entry plug_idt, 0x8E ;2
idt_entry plug_idt, 0x8E ;3
idt_entry plug_idt, 0x8E ;4
idt_entry plug_idt, 0x8E ;5
idt_entry plug_idt, 0x8E ;6
idt_entry plug_idt, 0x8E ;7
idt_entry plug_idt, 0x8E ;8
idt_entry plug_idt, 0x8E ;9
idt_entry plug_idt, 0x8E ;10
idt_entry plug_idt, 0x8E ;11
idt_entry plug_idt, 0x8E ;12
idt_entry plug_idt, 0x8E ;13
idt_entry plug_idt, 0x8E ;14
idt_entry plug_idt, 0x8E ;15
idt_entry plug_idt, 0x8E ;16
idt_entry plug_idt, 0x8E ;17
idt_entry plug_idt, 0x8E ;18
idt_entry plug_idt, 0x8E ;19
idt_entry plug_idt, 0x8E ;20
idt_entry plug_idt, 0x8E ;21
idt_entry plug_idt, 0x8E ;22
idt_entry plug_idt, 0x8E ;23
idt_entry plug_idt, 0x8E ;24
idt_entry plug_idt, 0x8E ;25
idt_entry plug_idt, 0x8E ;26
idt_entry plug_idt, 0x8E ;27
idt_entry plug_idt, 0x8E ;28
idt_entry plug_idt, 0x8E ;29
idt_entry plug_idt, 0x8E ;30
idt_entry plug_idt, 0x8E ;31
idt_entry plug_idt, 0x8E ;32
idt_entry plug_idt, 0x8E ;33
idt_entry plug_idt, 0x8E ;34
idt_entry plug_idt, 0x8E ;35
idt_entry plug_idt, 0x8E ;36
idt_entry plug_idt, 0x8E ;37
idt_entry plug_idt, 0x8E ;38
idt_entry plug_idt, 0x8E ;39
idt_entry plug_idt, 0x8E ;40
idt_entry plug_idt, 0x8E ;41
idt_entry plug_idt, 0x8E ;42
idt_entry plug_idt, 0x8E ;43
idt_entry plug_idt, 0x8E ;44
idt_entry plug_idt, 0x8E ;45
idt_entry plug_idt, 0x8E ;46
idt_entry plug_idt, 0x8E ;47
idt_entry plug_idt, 0x8E ;48
idt_entry plug_idt, 0x8E ;49
idt_entry plug_idt, 0x8E ;50
idt_entry plug_idt, 0x8E ;51
idt_entry plug_idt, 0x8E ;52
idt_entry plug_idt, 0x8E ;53
idt_entry plug_idt, 0x8E ;54
idt_entry plug_idt, 0x8E ;55
idt_entry plug_idt,0x8E ;56
idt_entry plug_idt,0x8E ;57
idt_entry plug_idt,0x8E ;58
idt_entry plug_idt,0x8E ;59
idt_entry plug_idt,0x8E ;60
idt_entry plug_idt,0x8E ;61
idt_entry plug_idt,0x8E ;62
idt_entry plug_idt,0x8E ;63
idt_entry plug_idt,0x8E ;64
idt_entry plug_idt,0x8E ;65
idt_entry plug_idt,0x8E ;66
idt_entry plug_idt,0x8E ;67
idt_entry plug_idt,0x8E ;68
idt_entry plug_idt,0x8E ;69
idt_entry plug_idt,0x8E ;70
idt_entry plug_idt,0x8E ;71
idt_entry plug_idt,0x8E ;72
idt_entry plug_idt,0x8E ;73
idt_entry plug_idt,0x8E ;74
idt_entry plug_idt,0x8E ;75
idt_entry plug_idt,0x8E ;76
idt_entry plug_idt,0x8E ;77
idt_entry plug_idt,0x8E ;78
idt_entry plug_idt,0x8E ;79
idt_entry plug_idt,0x8E ;80
idt_entry plug_idt,0x8E ;81
idt_entry plug_idt,0x8E ;82
idt_entry plug_idt,0x8E ;83
idt_entry plug_idt,0x8E ;84
idt_entry plug_idt,0x8E ;85
idt_entry plug_idt,0x8E ;86
idt_entry plug_idt,0x8E ;87
idt_entry plug_idt,0x8E ;88
idt_entry plug_idt,0x8E ;89
idt_entry plug_idt,0x8E ;90
idt_entry plug_idt,0x8E ;91
idt_entry plug_idt,0x8E ;92
idt_entry plug_idt,0x8E ;93
idt_entry plug_idt,0x8E ;94
idt_entry plug_idt,0x8E ;95
idt_entry plug_idt,0x8E ;96
idt_entry plug_idt,0x8E ;97
idt_entry plug_idt,0x8E ;98
idt_entry plug_idt,0x8E ;99
idt_entry plug_idt,0x8E ;100
idt_entry plug_idt,0x8E ;101
idt_entry plug_idt,0x8E ;102
idt_entry plug_idt,0x8E ;103
idt_entry plug_idt,0x8E ;104
idt_entry plug_idt,0x8E ;105
idt_entry plug_idt,0x8E ;106
idt_entry plug_idt,0x8E ;107
idt_entry plug_idt,0x8E ;108
idt_entry plug_idt,0x8E ;109
idt_entry plug_idt,0x8E ;110
idt_entry plug_idt,0x8E ;111
idt_entry plug_idt,0x8E ;112
idt_entry plug_idt,0x8E ;113
idt_entry plug_idt,0x8E ;114
idt_entry plug_idt,0x8E ;115
idt_entry plug_idt,0x8E ;116
idt_entry plug_idt,0x8E ;117
idt_entry plug_idt,0x8E ;118
idt_entry plug_idt,0x8E ;119
idt_entry plug_idt,0x8E ;120
idt_entry plug_idt,0x8E ;121
idt_entry plug_idt,0x8E ;0
idt_entry plug_idt,0x8E ;1
idt_entry plug_idt,0x8E ;2
idt_entry plug_idt,0x8E ;3
idt_entry plug_idt,0x8E ;4
idt_entry plug_idt,0x8E ;5
idt_entry plug_idt,0x8E ;6
idt_entry plug_idt,0x8E ;7
idt_entry plug_idt,0x8E ;8
idt_entry plug_idt,0x8E ;9
idt_entry plug_idt,0x8E ;10
idt_entry plug_idt,0x8E ;11
idt_entry plug_idt,0x8E ;12
idt_entry plug_idt,0x8E ;13
idt_entry plug_idt,0x8E ;14
idt_entry plug_idt,0x8E ;15
idt_entry plug_idt,0x8E ;16
idt_entry plug_idt,0x8E ;17
idt_entry plug_idt,0x8E ;18
idt_entry plug_idt,0x8E ;19
idt_entry plug_idt,0x8E ;20
idt_entry plug_idt,0x8E ;21
idt_entry plug_idt,0x8E ;22
idt_entry plug_idt,0x8E ;23
idt_entry plug_idt,0x8E ;24
idt_entry plug_idt,0x8E ;25
idt_entry plug_idt,0x8E ;26
idt_entry plug_idt,0x8E ;27
idt_entry plug_idt,0x8E ;28
idt_entry plug_idt,0x8E ;29
idt_entry plug_idt,0x8E ;30
idt_entry plug_idt,0x8E ;31
idt_entry plug_idt,0x8E ;32
idt_entry plug_idt,0x8E ;33
idt_entry plug_idt,0x8E ;34
idt_entry plug_idt,0x8E ;35
idt_entry plug_idt,0x8E ;36
idt_entry plug_idt,0x8E ;37
idt_entry plug_idt,0x8E ;38
idt_entry plug_idt,0x8E ;39
idt_entry plug_idt,0x8E ;40
idt_entry plug_idt,0x8E ;41
idt_entry plug_idt,0x8E ;42
idt_entry plug_idt,0x8E ;43
idt_entry plug_idt,0x8E ;44
idt_entry plug_idt,0x8E ;45
idt_entry plug_idt,0x8E ;46
idt_entry plug_idt,0x8E ;47
idt_entry plug_idt,0x8E ;48
idt_entry plug_idt,0x8E ;49
idt_entry plug_idt,0x8E ;50
idt_entry plug_idt,0x8E ;51
idt_entry plug_idt,0x8E ;52
idt_entry plug_idt,0x8E ;53
idt_entry plug_idt,0x8E ;54
idt_entry plug_idt,0x8E ;55
idt_entry plug_idt,0x8E ;56
idt_entry plug_idt,0x8E ;57
idt_entry plug_idt,0x8E ;58
idt_entry plug_idt,0x8E ;59
idt_entry plug_idt,0x8E ;60
idt_entry plug_idt,0x8E ;0
idt_entry plug_idt,0x8E ;1
idt_entry plug_idt,0x8E ;2
idt_entry plug_idt,0x8E ;3
idt_entry plug_idt,0x8E ;4
idt_entry plug_idt,0x8E ;5
idt_entry plug_idt,0x8E ;6
idt_entry plug_idt,0x8E ;7
idt_entry plug_idt,0x8E ;8
idt_entry plug_idt,0x8E ;9
idt_entry plug_idt,0x8E ;10
idt_entry plug_idt,0x8E ;11
idt_entry plug_idt,0x8E ;12
idt_entry plug_idt,0x8E ;13
idt_entry plug_idt,0x8E ;14
idt_entry plug_idt,0x8E ;15
idt_entry plug_idt,0x8E ;16
idt_entry plug_idt,0x8E ;17
idt_entry plug_idt,0x8E ;18
idt_entry plug_idt,0x8E ;19
idt_entry plug_idt,0x8E ;20
idt_entry plug_idt,0x8E ;21
idt_entry plug_idt,0x8E ;22
idt_entry plug_idt,0x8E ;23
idt_entry plug_idt,0x8E ;24
idt_entry plug_idt,0x8E ;25
idt_entry plug_idt,0x8E ;26
idt_entry plug_idt,0x8E ;27
idt_entry plug_idt,0x8E ;28
idt_entry plug_idt,0x8E ;29
idt_entry plug_idt,0x8E ;30
idt_entry plug_idt,0x8E ;31
idt_entry plug_idt,0x8E ;32
idt_entry plug_idt,0x8E ;33
idt_entry plug_idt,0x8E ;34
idt_entry plug_idt,0x8E ;35
idt_entry plug_idt,0x8E ;36
idt_entry plug_idt,0x8E ;37
idt_entry plug_idt,0x8E ;38
idt_entry plug_idt,0x8E ;39
idt_entry plug_idt,0x8E ;40
idt_entry plug_idt,0x8E ;41
idt_entry plug_idt,0x8E ;42
idt_entry plug_idt,0x8E ;43
idt_entry plug_idt,0x8E ;44
idt_entry plug_idt,0x8E ;45
idt_entry plug_idt,0x8E ;46
idt_entry plug_idt,0x8E ;47
idt_entry plug_idt,0x8E ;48
idt_entry plug_idt,0x8E ;49
idt_entry plug_idt,0x8E ;50
idt_entry plug_idt,0x8E ;51
idt_entry plug_idt,0x8E ;52
idt_entry plug_idt,0x8E ;53
idt_entry plug_idt,0x8E ;54
idt_entry plug_idt,0x8E ;55
idt_entry plug_idt,0x8E ;56
idt_entry plug_idt,0x8E ;57
idt_entry plug_idt,0x8E ;58
idt_entry plug_idt,0x8E ;59
idt_entry plug_idt,0x8E ;60
idt_entry plug_idt,0x8E ;0
idt_entry plug_idt,0x8E ;1
idt_entry plug_idt,0x8E ;2
idt_entry plug_idt,0x8E ;3
idt_entry plug_idt,0x8E ;4
idt_entry plug_idt,0x8E ;5
idt_entry plug_idt,0x8E ;6
idt_entry plug_idt,0x8E ;7
idt_entry plug_idt,0x8E ;8
idt_entry plug_idt,0x8E ;9
idt_entry plug_idt,0x8E ;10
idt_entry plug_idt,0x8E ;11
idt64_end:
idt64_descript:
dw idt64_end-idt64-1
dq idt64
;The IDT

divide_zero:
add qword [rsp],2
mov rsi,error_0
call printf_str64
jmp end_error_0
error_0: db 'code 0',0
end_error_0:
;sti
mov r8,0x10
iretq
plug_idt:
mov rsi,error_plug
call printf_str64
call ok_64
jmp end_plug
error_plug: db 'Plug error',0
end_plug:
;sti

iretq



zombi_mod:
lidt [idt64_descript]
mov rax,1
xor rcx,rcx
div rcx
call ok_64
cmp r8,0x10
jz true_zombi_kernel
jmp hltt
true_zombi_kernel:
mov rsi,mesg_zombi
call printf_str64

hltt:
hlt
jmp hltt
;--------------------------------------data64---------------------------
mesg_zombi: db 'Zombi kernel',0
;----------------------------------Long function------------------------

printf_str64:
mov rax,[video_mem64]
loop_str64:
mov r8,[rsi]
test r8,r8
jz end_printf64
mov [rax],r8
inc rax
inc rsi
mov [rax],r9
inc rax

jmp loop_str64
end_printf64:
mov rax,[video_mem64]
add rax , 160
mov [video_mem64],rax
ret
ok_64:
mov rax,[video_mem64]
mov r8,'O'
mov [rax],r8
inc rax
mov R10,0x16
mov [rax],r10
inc rax
mov r8,'k'
mov [rax],r8
inc rax
mov [rax],r10
mov rax,[video_mem64]
add rax,160
mov [video_mem64],rax
ret
print_satrt_long_mod:
mov rbx,[video_mem64]
mov rax,'l'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'o'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'n'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'g'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,' '
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'m'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'o'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov rax,'d'
mov [rbx],rax
inc rbx
mov rax,0x05
mov [rbx],rax
inc rbx
mov r8,rbx
mov R9,' '
mov [r8],r9
inc r8
mov r10,0x5
mov [r8],r10
inc r8
mov R9,'6'
mov [r8],r9
inc r8
mov r10,0x16
mov [r8],r10
inc r8
mov r9,'4'
mov [r8],r9
inc r8
mov r10,0x16
mov [r8],r10
inc r8
mov r9,' '
mov [r8],r9
inc r8
mov [r8],r10
inc r8
mov r9,'b'
mov [r8],r9
inc r8
mov [r8],r10
inc r8
mov r9,'i'
mov [r8],r9
inc r8
mov [r8],r10
inc r8
mov r9,'t'
mov [r8],r9
inc r8
mov [r8],r10
inc r8
mov r9,'s'
mov [r8],r9
inc r8
mov [r8],r10
inc r8
mov r11,r8
mov r9,' '
mov [r11],r9
inc r11
mov r9,'Y'
mov [r11],r10
inc r11
mov [r11],r9
inc r11
mov [r11],r10
mov rax,[video_mem64]
add rax,160
mov r11,video_mem64
mov [r11],rax
ret
new_label64:
mov rax,[video_mem64]
add rax,160
mov [video_mem64],rax
ret
;--------------------------------data64---------------------------------
video_mem64: dq 0xB8000
mesg_tets_64: db 'mesg test',0
