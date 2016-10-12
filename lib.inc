section .text

string_length:
    xor rax, rax ; длина строки
    xor rdx, rdx
    .cycle:
        mov dl, [rdi + rax]
        test dl, dl ; 
        jz .exit
        inc rax
        jmp .cycle
    .exit:
    ret

print_string:

    ;push rdx

    push rdi
    call string_length
    pop rdi

    ;pop rdx

    mov rsi, rdi ; адрес строки
    mov rdi, 1 ; дескриптор
    mov rdx, rax ; сколько байт записываем
    
     
     
    mov rax, 1 ; системный вызов write
    syscall
    ret

print_char:
    push di ; 
    mov rdx, 1 ; количество байт для записи
    mov rdi, 1 ; дескриптор stdout
    mov rax, 1 ; номер системного вызова write
    mov rsi, rsp ; адрес строки
    syscall
    pop di
    ret

print_newline:
    mov rdi, 0xA
    call print_char
    ret

print_uint:
    mov r10, 10 ; основа десятичной системы счисления
    mov rax, rdi
    mov r8, rsp
    sub rsp, 21 ; 21 - максимально необходимый размер буфера
    ; признак конца строки
    dec r8
    mov byte[r8], 0x00
    
    .cycle: 
        xor rdx, rdx
        div r10 ; rax - делимое
        add rdx, '0'
        dec r8
        mov byte[r8], dl
        test rax, rax
        jnz .cycle

    mov rdi, r8
    call print_string
    
    add rsp, 21 ; 
    ret

print_int:
    test rdi, rdi
    js .negative ; отрицательное число

    call print_uint
    ret
    .negative:
        push rdi
        mov rdi, '-'
        call print_char
        pop rdi

        not rdi
        inc rdi

        call print_uint
    ret

string_equals:
    xor rax, rax
    .cycle:
        mov r8b, [rdi]
        mov r9b, [rsi]
        inc rdi
        inc rsi

        cmp r8b, r9b
        je .eq
        mov rax, 0
        ret

        .eq:
            test r8b, r9b
            jz .exit

        jmp .cycle
    .exit:
        mov rax, 1
    ret

read_char:
    xor ax, ax ; 
    push ax ; буфер 2 байта
    
    mov rax, 0 ; read
    mov rdi, 0 ;  stdin
    mov rsi, rsp ; буфер
    mov rdx, 1 ; количество байт 
    syscall

    pop ax
    ret

section .data ; 
word_buffer times 256 db 0

section .text

read_word:
    xor rdx, rdx ; длина строки

    .next:
        push rdx
        call read_char
        pop rdx

        cmp al, 0x20
        jz .skip
        cmp al, 0x09
        jz .skip
        cmp al, 0x0A
        jz .skip

        test al, al
        jz .exit

        mov byte[word_buffer + rdx], al
        inc rdx

        jmp .next

    .skip:
        test rdx, rdx
        jz .next

    .exit:
        mov byte[word_buffer + rdx], 0x00
        mov rax, word_buffer
    ret

; rdi points to a string
; returns rax: number, rdx : length
parse_uint:
    mov r10, 10 ; основа десятичной системы счисления
    xor rax, rax ;  число
    xor r9, r9 ; длина числа
    .cycle:
        mov r8b, [rdi + r9]

        cmp r8b, '0'
        jl .exit
        cmp r8b, '9'
        jg .exit
        mul r10   
        sub r8b, '0'
        add rax, r8
        inc r9
        jmp .cycle

    .exit:
        mov rdx, r9
    ret

; rdi points to a string
; returns rax: number, rdx : length
parse_int:
    mov r8b, [rdi]
    cmp r8b, '-'
    jnz .plus
    inc rdi
    call parse_uint
    not rax
    inc rax
    inc rdx
    ret
    .plus:
        call parse_uint
    ret

string_copy:
    xor rax, rax

    .cycle:
        mov al, [rdi]

        test al, al
        jz .exit

        mov byte[rsi], al

        inc rdi
        inc rsi

        jmp .cycle

    .exit:
        mov byte[rsi], 0
    ret




;число прочитать в фаил, если простое - вывод 1, иначе 0