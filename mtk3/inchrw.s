.global inbyte
.global inkey
.equ SYSCALL_NUM_GETSTRING, 1   /* ここで定義すれば defs.s は不要 */

.section .text
.even
inbyte:
    link.w  %a6, #-4
    movem.l %d1-%d3, -(%sp)

inbyte_loop1:
    move.l  #SYSCALL_NUM_GETSTRING, %d0
    move.l  #0, %d1
    
    /* バッファアドレスの計算: FP(%a6) - 4 */
    move.l  %a6, %d2
    subi.l  #4, %d2
    
    move.l  #1, %d3
    trap    #0

    cmpi.l  #1, %d0
    bne     inbyte_loop1

    clr.l   %d0
    /* 受信データの取得 */
    move.b  -4(%a6), %d0    
    movem.l (%sp)+, %d1-%d3
	unlk    %a6
	rts


