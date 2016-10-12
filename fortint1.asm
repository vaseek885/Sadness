global _start

%include "lib.inc"

%define pc r12
%define w r13
%define rstack r14
%define here r15

%define link 0 ; Указатель на предыдущее слово отсутствует

%macro native 3
; %1 %2 %3
section .data

w_%2:
    dq link ; Указатель на предыдущее слово
    %define link w_%2
    db %1, 0 ; Имя слова
    db %3 ; Флаги
xt_%2:
    dq %2_impl

section .text
    %2_impl:
%endmacro

%macro native 2
native %1, %2, 0
%endmacro

%macro colon 3
; %1 %2 %3
w_%2:
    dq link ; Указатель на предыдущее слово
    %define link w_%2
    db %1, 0 ; Имя слова
    db %3 ; Флаги

    dq docol ; Адрес docol - 1 уровень косвенности
%endmacro

%macro colon 2
colon %1, %2, 0
%endmacro

section .data
res1: db 'Good', 0
res2: db 'Not good', 0
res3: db 'Fuck', 0
res4: db 'Введенная последовательность символов не является числом или командой', 0
old_rsp: dq 0
state: dq 0 ; Режим (компиляция / интерпретация)
last_word: dq 0 ; Адрес последнего определенного слова !!!

program_stub: dq 0
xt_interpreter: dq .interpreter
.interpreter: dq interpreter_loop

section .text
_start:
mov qword[old_rsp], rsp
mov rstack, bss_stack
mov here, bss_vocabulary


mov pc, xt_interpreter
jmp next

interpreter_loop:
	;debug
	call read_word

	test rdx, rdx
	jz .exit

	mov rdi, rax
	push rdi

	call find_word
	pop rdi

	; debug
	push rax
	push rdi
	mov rdi, res1
	call print_string
	mov rdi, res1
	call print_string
	mov rdi, res1
	call print_string
	call print_newline
	pop rdi
	pop rax


	test rax, rax
	jnz .found
	jz .not_found




	.found:
		mov rdi, rax
		call cfa
		mov qword[program_stub], rax
		mov pc, program_stub

		; debug
		push rdi
		mov rdi, res3
		call print_string
		mov rdi, res3
		call print_string
		mov rdi, res3
		call print_string
		call print_newline
		pop rdi

		jmp next ; +

	.not_found:
		; if [rdi] - это число

		;debug
		push rdi
		mov rdi, res2
		call print_string
		mov rdi, res3
		call print_string
		mov rdi, res3
		call print_string
		call print_newline
		pop rdi

		call parse_int
		test rdx, rdx
		jnz .number
		jz .not_number

		.number:
		push rax
		push rdi
		mov rdi, res1
		call print_string
		mov rdi, res2
		call print_string
		mov rdi, res2
		call print_string
		call print_newline
		pop rdi
		pop rax

		push rax

		; debug
		;mov rdi, res1
		;call print_string
		;call print_newline

		jmp interpreter_loop

		.not_number:
		mov rdi, res4
		call print_string
		call print_newline
		jmp interpreter_loop	

	.exit:
		mov rax, 60
		xor rdi, rdi
		syscall

section .data
; colon-слова:

colon 'double', double
    dq xt_dup
    dq xt_plus
    dq xt_exit

colon 'or', logical_or
    dq xt_logical_not
    dq xt_swap
    dq xt_logical_not
    dq xt_logical_and
    dq xt_logical_not
    dq xt_exit


colon '>', greater
	dq xt_swap
	dq xt_less
    dq xt_exit

section .text

; Реализации:

native 'exit', exit
	mov pc, [rstack]
	add rstack, 8
	jmp next

native '.S', print_stack
	mov rax, [old_rsp]
	cmp rax, rsp ; Stack is empty ?
	jz .exit

	push rax
	mov rdi, '='
	call print_char
	mov rdi, '>'
	call print_char
	mov rdi, ' '
	call print_char
	pop rax

	.iterate:
		sub rax, 8
		mov rdi, [rax]

		push rax
		call print_int
		mov rdi, ' '
		call print_char
		pop rax

		cmp rax, rsp
		jnz .iterate

	call print_newline

	.exit:
	jmp next

native '+', plus
    pop rax
    add rax, [rsp]
    mov [rsp], rax
    jmp next

native '-', minus
	pop rax
	pop rdi
	sub rdi, rax
	push rdi
	jmp next

native '*', multi
	pop rax
	pop rdi
	mul rdi
	push rax

	jmp next

native '/', division
	pop rdi
	pop rax

	xor rdx, rdx
	test rax, rax
	jns .more ; rax > 0 ?
		not rdx
	.more:
	idiv rdi
	push rax

	jmp next

native '=', equals
	pop rax
	pop rdi

	cmp rax, rdi
	jz .true
	jnz .false

	.true:
		push 1 ; 8 Byte
		jmp .exit
	.false:
		push 0 ; 8 Byte
		jmp .exit

	.exit:
	jmp next

native '<', less
	pop rax
	pop rdi

	cmp rdi, rax
	jg .greater
	jl .less

	.greater:
		push 0 ; 8 Byte
		jmp .exit
	.less:
		push 1 ; 8 Byte
		jmp .exit

	.exit:
	jmp next

native 'and', logical_and
	pop rax
	pop rdi

	and rax, rdi
	jnz .true
	jz .false

	.true:
		push 1 ; 8 Byte
		jmp .exit
	.false:
		push 0 ; 8 Byte
		jmp .exit

	.exit:
	jmp next

native 'not', logical_not
	pop rax
	not rax

	test rax, rax
	jnz .true
	jz .false

	.true:
		push 1 ; 8 Byte
		jmp .exit
	.false:
		push 0 ; 8 Byte
		jmp .exit

	.exit:
	jmp next

native 'rot', rotation
	pop rdi ; c
	pop rax ; b
	pop rdx ; a

	push rax
	push rdi
	push rdx
	jmp next

native 'swap', swap
	pop rax ; b
	pop rdx ; a

	push rax
	push rdx
	jmp next

native 'dup', dup
    push qword[rsp]
    jmp next

native 'drop', drop
    add rsp, 8
    jmp next

native '.', dot
	pop rdi
	call print_int
	call print_newline
	jmp next

native 'key', key
	call read_char
	push rax ; ax - 2 Bytes for char: [.... char]
	jmp next

native 'emit', emit
	pop rdi
	call print_char
	call print_newline
	jmp next

native 'number', number
	call read_word
	mov rdi, rax

	xor r8, r8 ; Костыль для библиотеки (потом переделать parse_int)
	call parse_int

	push rax
	jmp next

native 'mem', mem ;?
	push bss_buf
	jmp next

native '!', write_date ;?
	pop rax ; address
	pop rdi ; data
	mov qword[rax], rdi
	jmp next

native '@', read_date ;?
	pop rax ; address
	push qword[rax]
	jmp next

next:
	mov w, pc
	add pc, 8
	mov w, [w]
	jmp [w]

; Для colon-слов:
docol:
	sub rstack, 8
	mov [rstack], pc
	add w, 8
	mov pc, w
	jmp next

; Дополнительные процедуры:
find_word:
	; rdi - указатель на имя искомой процедуры
    ; rax - вернуть адрес слова, либо 0
	; Начать проверять с link

    ; mov byte[string_buf], rdi
    ; mov rdi, string_buf

    lea r8, [link]

    .iterate:
        ; r8 - текущее проверяемое слово
        ; [r8] - следующее проверяемое слово

        
        mov rsi, r8
        add rsi, 8

        push rdi
        push r8
        call string_equals
        pop r8
        pop rdi

        

        test rax, rax
        jz .not_good
        jnz .good

        .good:
        	
        	;debug
        	push rdi;dbg
        	mov rdi, res1;dbg
        	call print_string;dbg
        	call print_newline;dbg
        	pop rdi;dbg

            mov rax, r8
            ret

        .not_good:
        	;debug
        	push rdi;dbg
        	mov rdi, res2;dbg
        	call print_string;dbg
        	call print_newline;dbg
        	pop rdi;dbg

            mov r8, [r8]

            test r8, r8
            
            jnz .iterate

            push rdi;dbg
            mov rdi, res1;dbg
            call print_string;dbg
            mov rdi, res1;dbg
            call print_string;dbg
            call print_newline;dbg
            pop rdi;dbg

            mov rax, 0
            ret

cfa:
	; rdi - адрес w_...
	; rax - будет xt_...

	add rdi, 8

	push rdi
	call string_length
	pop rdi

	lea rax, [rdi + rax + 2] ;!? Ok?!

	ret

section .bss
bss_buf resb 65536 ; Пользовательская память
bss_stack resb 2048 ; Стек адресов возврата
bss_vocabulary resb 65536 ; Словарь
	