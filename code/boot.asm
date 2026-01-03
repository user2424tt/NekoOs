 use16
 section .text
 org 0x7c00
start:
mov [boot_disk],dl
xor ax,ax
mov ss,ax
mov ax,start_stek+256
mov bp,ax
mov sp,bp
xor ax,ax
    xor bh,bh

    cld ; Движемся вперед ФЛАГ D ОЧИЩЕН
    ; Загрузка ядра
    read_kernel:
    mov ah,02h
    mov al,64
    mov ch,0
    mov dl,[boot_disk]
    mov dh,0
    mov cl,2
    push 0000
    pop es
    mov bx,7E00h
    int 13h
    xor bx,bx
    xor dx,dx
    mov dl,[boot_disk]
    jmp 0000:7E00h
start_stek:
times 256 db 0
boot_disk: db 0
finish:
     times 0x1FE-finish+start db 0
     db   0x55, 0xAA  ; сигнатура загрузочного сектора
