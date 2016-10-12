global _start

%include "lib.inc"

%define pc r12
%define w r13
%define rstack r14
%define here r15

%define link 0 

%macro native 3

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

w_%2:
    dq link ; Указатель на предыдущее слово
    %define link w_%2
    db %1, 0 ; Имя слова
    db %3 ; Флаги

    dq docol 
%endmacro

%macro colon 2
colon %1, %2, 0
%endmacro

section .data


res3: db 'Стек возврата для colon команд переполнен, слишком большая вложенность команд.', 0
res4: db 'Введенная последовательность символов не является числом или командой', 0
old_rsp: dq 0
state: db 0 ; состояние (компиляция / интерпретация)
last_word: dq 0 ; Адрес последнего определенного слова

program_stub: dq 0
xt_interpreter: dq .interpreter
.interpreter: dq interpreter_loop

section .text

interpreter_loop:

	xor rax, rax
	mov al, [state]
	test al, al
	jnz compiler_loop


	call read_word


	mov rdi, rax
	push rdi
	call find_word
	pop rdi

	test rax, rax
	jnz .found
	jz .not_found

	.found:
		mov rdi, rax
		call cfa
		mov [program_stub], rax
		mov pc, program_stub

		jmp next 

	.not_found:

		call parse_int
		test rdx, rdx
		jnz .number
		jz .not_number

		.number:
			push rax


		jmp interpreter_loop

		.not_number:
			mov rdi, res4
			call print_string
			call print_newline
			jmp interpreter_loop

	

compiler_loop:
	call read_word


	mov rdi, rax
	push rdi
	call find_word
	pop rdi

	test rax, rax
	jnz .found
	jz .not_found

	.found:
		mov rdi, rax
		call cfa

		xor rdi, rdi
		mov dil, [rax - 1]
		cmp dil, 1 ; F == 1 => immediate
		jz .immediate
		jnz .not_immediate

		.immediate:
			; only ( ; )
			mov qword[program_stub], rax
			mov pc, program_stub
			jmp next

		.not_immediate:
			mov [here], rax
			add here, 8

			; if [rax-1] == [branch] ... (проверяем флаги)
			xor rdi, rdi
			mov dil, [rax - 1]
			cmp dil, 2 ; F == 2 => branch || branch0
			jz .br
			jnz .not_br
			.br:
				mov byte[state], 2
				jmp .next_iter
			.not_br:
				mov byte[state], 1

			.next_iter:
			jmp compiler_loop

	.not_found:
		; if [rdi] - это число
		call parse_int
		test rdx, rdx
		jnz .number
		jz .not_number

		.number:
			; if пред. слово было [branch]

			xor rdi, rdi
			mov dil, [state]
			cmp dil, 2
			mov byte[state], 1
			jnz .then
			jz .true

			.then:

				mov qword[here], xt_lit
				add here, 8
			.true:

			mov qword[here], rax
			add here, 8

		jmp compiler_loop

		.not_number:
			mov rdi, res4
			call print_string
			call print_newline
			jmp compiler_loop


	

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

native 'quit', quit
	mov rax, 60
	xor rdi, rdi
	syscall
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

	xor r8, r8 
	call parse_int

	push rax
	jmp next

native 'mem', mem
	push bss_buf
	jmp next

native '!', write_date
	pop rax ; address
	pop rdi ; data
	mov qword[rax], rdi
	jmp next

native '@', read_date
	pop rax ; address
	push qword[rax]
	jmp next

native ':', start_colon
	; Прочитаем следующее слово из stdin
	mov rax, [last_word]
	mov [here], rax

	mov qword[last_word], here

	add here, 8

	call read_word
	mov rdi, rax
	mov rsi, here

	add here, rdx
	inc here

	push rdx
	call string_copy
	pop rdx

	mov byte[here], 0x00 ; F
	inc here
	mov qword[here], docol
	add here, 8

	mov byte[state], 1

	;debug
		mov rax, [last_word]
		add rax, 8
		mov rdi, rax


		call print_string
		call print_newline
	jmp next

native ';', end_colon, 1 ; F = 1 - Immediate
	mov byte[state], 0
	mov qword[here], xt_exit
	add here, 8
	jmp next

native 'lit', lit, 3 ; F = 3
	push qword[pc]
	add pc, 8
	jmp next

native 'branch', branch, 2 ; F = 2
	add pc, [pc]
	jmp next

native 'branch0', branch0, 2 ; F = 2
	mov rax, [rsp]
	test rax, rax
	jnz .exit
	add pc, [pc]
	.exit:
	jmp next

next:
	mov w, pc
	add pc, 8
	mov w, [w]
	jmp [w]

; Для colon-слов:
docol:
	sub rstack, 8
	mov rax, bss_stack
	cmp rax, rstack
	jz .error
	mov [rstack], pc
	add w, 8
	mov pc, w
	jmp next
	.error:
	mov rdi, res3
	call print_string
	call print_newline
	mov rax, 60
	xor rdi, rdi
	syscall

; Дополнительные процедуры:
find_word:
	; rdi - указатель на имя искомой процедуры
    ; rax - вернуть адрес слова, либо 0
	; Начать проверять с link

    ; mov byte[string_buf], rdi
    ; mov rdi, string_buf

    lea r8, [last_word]

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
            mov rax, r8
            ret

        .not_good:
            mov r8, [r8]
            test r8, r8
            jnz .iterate

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



section .text
_start:
mov [old_rsp], rsp
lea rstack, [bss_stack+2040]
mov here, bss_vocabulary

mov byte[state], 0x00
mov qword[last_word], link

mov pc, xt_interpreter
jmp next
