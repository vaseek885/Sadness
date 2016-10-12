out:
	git add *
	git commit -m Another
	git push
run:	
	nasm -felf64 fortint.asm
	ld fortint.o
	./a.out
