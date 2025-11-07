.section .bss
task_p:	.ds.b 4 /*タイマ割り込みで実行するプログラムの先頭アドレスを格納*/

.section .text
/*タイマルーチン*/
RESET_TIMER:
	move.w #0x0004, TCTL1
	rts

SET_TIMER:
	move.l %D2, task_p
	move.w #206, TPRER1 /*カウンタ周波数を10000にする-> 周期0.1msec*/
	move.w %D1, TCMP1
	move.w #0x0015, TCTL1 /*比較割り込み許可, 1/16周期, タイマ許可*/
	rts

CALL_RP:
	movea.l task_p, %A0
	jsr  (%A0)
	rts
