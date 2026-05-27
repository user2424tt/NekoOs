; ------------------------------------------------------------
; ЗАГРУЗЧИК FAT12 - ЗАГРУЖАЕТ KERNEL.BIN И ЗАПУСКАЕТ
; ------------------------------------------------------------
org 0x7C00
bits 16
; ------------------------------------------------------------------------------
; BIOS PARAMETER BLOCK (BPB) для FAT12 - ровно 62 байта
; ------------------------------------------------------------------------------
    jmp short start        ; 2 байта: EB 3C (прыжок на 0x3E)
    nop                    ; 1 байт: 90

; Смещение 0x03 (3)
bpbOEM:            db 'MSDOS5.0'     ; 8 байт
bpbBytesPerSec:    dw 512            ; 2 байта (0x0B)
bpbSecPerClus:     db 1              ; 1 байт  (0x0D)
bpbRsvdSecCnt:     dw 1              ; 2 байта (0x0E)
bpbNumFATs:        db 2              ; 1 байт  (0x10)
bpbRootEntCnt:     dw 224            ; 2 байта (0x11)
bpbTotSec16:       dw 2880           ; 2 байта (0x13)
bpbMedia:          db 0xF0           ; 1 байт  (0x15)
bpbFATsz16:        dw 9              ; 2 байта (0x16)
bpbSecPerTrk:      dw 18             ; 2 байта (0x18)
bpbNumHeads:       dw 2              ; 2 байта (0x1A)
bpbHiddSec:        dd 0              ; 4 байта (0x1C)
bpbTotSec32:       dd 0              ; 4 байта (0x20)

; Расширенный BPB для FAT12 (смещение 0x24)
bsDrvNum:          db 0              ; 1 байт  (0x24)
bsReserved1:       db 0              ; 1 байт  (0x25)
bsBootSig:         db 29h            ; 1 байт  (0x26) - СИГНАТУРА 0x29
bsVolID:           dd 0x12345678     ; 4 байта (0x27)
bsVolLab:          db 'BOOT FLOPPY'  ; 11 байт (0x2B)
bsFilSysType:      db 'FAT12   '     ; 8 байт  (0x36)
; Конец BPB на смещении 0x3D (61 байт от начала)
; ------------------------------------------------------------------------------

; Здесь начинается ТВОЙ КОД (смещение 0x3E)
start:
    xor ax, ax
    mov ds, ax
    ; ... и так далее
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    mov [drive_num], dl

    ; Читаем Root Dir
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

    ; Ищем KERNEL  BIN
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

    ; Проверяем имя
    push di
    mov si, kernel_name
    mov cx, 11
    repe cmpsb
    pop di
    je .found

.next:
    add di, 32
    loop .search

.not_found:
    mov si, msg_not_found
    call print_string
    jmp $

.found:
    ; Получаем первый кластер
    mov ax, [es:di+26]      ; Смещение 26 = первый кластер
    mov [cluster], ax

    ; Читаем FAT
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

    ; Грузим ядро
    xor ax,ax
    mov es, ax
    mov bx, 0x7E00

.load_loop:
    mov ax, [cluster]
    cmp ax, 0xFF8
    jae .jump_to_kernel

    ; Кластер -> сектор
    sub ax, 2
    add ax, 33
    call read_sector

    add bx, 512

    ; Следующий кластер из FAT
    mov ax, [cluster]
    mov si, ax
    shr ax, 1
    add si, ax              ; SI = cluster * 1.5

    push ds
    mov ax, 0x1000
    mov ds, ax
    mov ax, [si]            ; Читаем слово из FAT
    pop ds

    test word [cluster], 1
    jz .even
    shr ax, 4
    jmp .next_cluster
.even:
    and ax, 0x0FFF
.next_cluster:
    mov [cluster], ax
    jmp .load_loop

.jump_to_kernel:
    mov si, msg_ok
    call print_string

    mov dl, [drive_num]     ; Передаём номер диска
    jmp 0x0000:0x7E00       ; ПОЕХАЛИ!

; ------------------------------------------------------------
; ПОДПРОГРАММЫ
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
    mov dl, [drive_num]
    mov ax, 0x0201
    int 0x13
    popa
    ret

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

; ------------------------------------------------------------
; ДАННЫЕ
; ------------------------------------------------------------
drive_num:      db 0
cluster:        dw 0
kernel_name:    db 'KERNEL  BIN'  ; 11 байт, БЕЗ ТОЧКИ!
msg_not_found:  db 'KERNEL.BIN not found!', 13, 10, 0
msg_ok:         db 'Loading kernel...', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55
