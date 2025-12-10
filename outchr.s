.global outbyte
.equ SYSCALL_NUM_PUTSTRING,   2 |文字列出力(PUTSTRING)|
.section .text
.even

outbyte:
	movem.l %d1-%d3, -(%sp)
outbyteloop:
	move.l #SYSCALL_NUM_PUTSTRING, %d0
	move.l #0, %d1
	move.l %sp, %d2
	addi.l #19, %d2 /*#sp+19-->p*/
	move.l #1, %d3  /*1-->size*/
	trap #0

	cmpi.l #1, %d0
	bne outbyteloop
	movem.l (%sp)+, %d1-%d3
	rts

