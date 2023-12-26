; exit.asm
.global _data
.global _main
.align 4
_data:
.word    0x00004200
.word    0x00000001
.word    0x33333333
	ldr x28, _data
_main:
        bl (.+0x8070)
        mov x16, #1     ; syscall number for exit
        svc #0x80       ; do the syscall

