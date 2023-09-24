; exit.asm
.global _data
.global _main
.align 4
_data:
.word    0x11111111
.word    0x22222222
.word    0x33333333
.word    0x44444444
_main:
        mov x0, #42     ; exit code
        mov x16, #1     ; syscall number for exit
        svc #0x80       ; do the syscall!
