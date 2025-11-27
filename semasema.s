*****************************
***pv_handler
*****************************
pv_handler:
	movem.l %a0-%a6/%D0-%D7, -(%ssp)
	move.w %SR, %D7
	movem.w %D7, -(%ssp)
	move.w #0x2700, %SR
	movem.l %D1, -(%ssp) /*D1 を引数としてスタックに積む*/
	cmp.l #0, %D0
	bne vb
pb:
	jsr p_body
	movem.l (%ssp)+, %D1
	bra finish
vb:
	jsr v_body
	movem.l (%ssp)+, %D1
finish:
	movem.w (%ssp)+, %D7
	move.w %D7, %SR
	movem.l (%ssp)+, %a0-%a6/%D0-%D7
	rte
*****************************
***P
*****************************
P:
	movem.l %D0-%D1/%a0, -(%sp)/*usp*/
	move.l %sp, %a0
	add.l #19, %a0
	move.l #0, %D0
	move.b (%a0), %D1
	trap #1
	movem.l (%sp)+, %D0-%D1/%a0/*usp*/
	rts
*****************************
***V
*****************************
V:
	movem.l %d0-%d1/%a0, -(%sp) /*usp*/
	move.l %sp, %a0
	add.l #19, %a0
	move.l #0, %d0
	add.l #1, %d0
	move.b (%a0), %d1
	trap #1
	movem.l (%sp)+, %d0-%d1/%a0 /*usp*/
	rts
*****************************
