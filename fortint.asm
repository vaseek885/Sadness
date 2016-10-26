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

numvars: dq 0
str3: db 'Стек возврата для colon команд переполнен, слишком большая вложенность команд.', 0
str4: db 'Введенная последовательность символов не является числом или командой', 0
str5: db 'Введенная последовательность символов - не переменная', 0
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
			mov rdi, str4
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
		cmp dil, 1 ; флаг = 1 - immediate
		jz .immediate
		jnz .delayed

		.immediate:

			mov qword[program_stub], rax
			mov pc, program_stub
			jmp next

		.delayed:
			mov [here], rax
			add here, 8

			
			xor rdi, rdi
			mov dil, [rax - 1]
			cmp dil, 2 ; если флаг = 2 то предыдущий оператор - либо branch либо branch0
			jz .br
			jnz .not_br
			.br:
				mov byte[state], 2
				jmp .nextit
			.not_br:
				mov byte[state], 1
			.nextit:
				jmp compiler_loop

	.not_found:
		; может быть [rdi] - это число
		call parse_int
		test rdx, rdx
		jnz .number
		jz .not_number

		.number:

			xor rdi, rdi
			mov dil, [state]
			cmp dil, 2
			mov byte[state], 1
			jnz .else
			jz .than

			.else:

				mov qword[here], xt_lit
				add here, 8
			.than:

			mov qword[here], rax
			add here, 8

		jmp compiler_loop

		.not_number:
			mov rdi, str4
			call print_string
			call print_newline
			jmp compiler_loop


	

section .data


colon 'double', double
    dq xt_dup
    dq xt_plus
    dq xt_exit

colon 'or', log_or
    dq xt_log_not
    dq xt_swap
    dq xt_log_not
    dq xt_log_and
    dq xt_log_not
    dq xt_exit

colon '>', greater
	dq xt_swap
	dq xt_less
    dq xt_exit

section .text


native 'exit', exit
	mov pc, [rstack]
	add rstack, 8
	jmp next

native 'quit', quit
	mov rax, 60
	xor rdi, rdi
	syscall

native 'var', var
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

	mov byte[here], 0x00
	inc here
	mov qword[here], var_exec
	add here, 8
	mov byte[state], 0

	
	mov rdi, [numvars] 
	lea rdx, [bss_buf + rdi]
	add rdi, 8
	mov [numvars], rdi

	pop rdi ; data
	mov [rdx], rdi

	mov [here], rdx

	add here, 8
	
	jmp next

	;;
	; mov rax, [last_word]
	; mov [here], rax

	; mov qword[last_word], here

	; add here, 8

	; call read_word
	; mov rdi, rax
	; mov rsi, here

	; add here, rdx
	; inc here

	; push rdx
	; call string_copy
	; pop rdx

	; mov byte[here], 0x00 ; F
	; inc here
	; mov qword[here], docol
	; add here, 8

	; mov byte[state], 1

	; jmp next
	;;

var_exec:
	add w, 8
	mov w, [w]	
	push qword[w]
	jmp next

	

native '.S', print_stack
	mov rax, [old_rsp]
	cmp rax, rsp 
	jz .exit

	push rax
	mov rdi, '-'
	call print_char
	mov rdi, '>'
	call print_char
	mov rdi, ' '
	call print_char
	pop rax

	.looping:
		sub rax, 8
		mov rdi, [rax]

		push rax
		call print_int
		mov rdi, ' '
		call print_char
		pop rax

		cmp rax, rsp
		jnz .looping

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

native '*', multiplication
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

native '=', equality
	pop rax
	pop rdi

	cmp rax, rdi
	jz .true
	jnz .false

	.true:
		push 1 ; 
		jmp .exit
	.false:
		push 0 ; 
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
		push 0 
		jmp .exit
	.less:
		push 1 
		jmp .exit

	.exit:
		jmp next

native 'and', log_and
	pop rax
	pop rdi

	and rax, rdi
	jnz .true
	jz .false

	.true:
		push 1 
		jmp .exit
	.false:
		push 0 
		jmp .exit

	.exit:
		jmp next

native 'not', log_not
	pop rax
	not rax

	test rax, rax
	jnz .true
	jz .false

	.true:
		push 1 
		jmp .exit
	.false:
		push 0 
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
	push rax 
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

native '!', write_data
	pop rax ; address
	pop rdi ; data
	mov [rax], rdi
	jmp next

native '@', read_data
	pop rax ; address
	push qword[rax]
	jmp next

native ':', start_colon

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

	jmp next

native ';', end_colon, 1 
	mov byte[state], 0
	mov qword[here], xt_exit
	add here, 8
	jmp next

native 'lit', lit, 3 
	push qword[pc]
	add pc, 8
	jmp next

native 'branch', branch, 2
	add pc, [pc]
	jmp next

native 'branch0', branch0, 2 
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
		mov rdi, str3
		call print_string
		call print_newline
		mov rax, 60
		xor rdi, rdi
		syscall


find_word:
	; rax - при успехе вернуть адрес слова, в противном случае 0
	; rdi - указатель на имя искомой процедуры
    

    lea r8, [last_word]

    .iterate:
        ; r8 - текущее слово
        ; [r8] - следующее  слово

        mov rsi, r8
        add rsi, 8

        push rdi
        push r8
        call string_equals
        pop r8
        pop rdi

        test rax, rax
        jz .different
        jnz .same

        .same:
            mov rax, r8
            ret

        .different:
            mov r8, [r8]
            test r8, r8
            jnz .iterate

            mov rax, 0
            ret

cfa:
	add rdi, 8

	push rdi
	call string_length
	pop rdi

	lea rax, [rdi + rax + 2] 

	ret

section .bss
bss_buf resb 65536 ; Пользовательская память
bss_stack resb 2048 ; Стек адресов возврата
bss_dictionary resb 65536 ; Словарь



section .text
_start:
mov [old_rsp], rsp
lea rstack, [bss_stack+2040]
mov here, bss_dictionary

mov byte[state], 0x00
mov qword[last_word], link

mov pc, xt_interpreter
jmp next
