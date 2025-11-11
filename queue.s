.section .data
.even	
.equ IN_COUNT, 257
.equ OUT_COUNT, 257
.equ queue_number, 1
.equ OFFSET_1, 0x100
.equ END_0, 0xff
.equ END_1, 0x1ff
top: .ds.b 0x200
bottom: .ds.l 1
in: .ds.l 1
in_0: .ds.l 1
in_1: .ds.l 1
out: .ds.l 1
out_0: .ds.l 1
out_1: .ds.l 1
s: .ds.l 1
s0: .ds.l 1
s1: .ds.l 1
START_LABEL: .ds.l 1


*****************キューの初期化処理*******************************************************************
/*Init_Q:
	movem.l %d0-%d4/%a0-%a3,-(%sp)
	moveq 	#0, %d0
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 
	move.w	#B_SIZE, %d2		/* d2: 256 
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */
.section .text
.even	
Init_Q:
	movem.l %a2-%a6, -(%sp) /* 応急処置*/
	lea.l top, %a2
	move.l %a2, in_0
	move.l %a2, out_0
	lea.l OFFSET_1(%a2), %a3
	move.l %a3, in_1
	move.l %a3, out_1
	lea.l s, %a4
	lea.l s0, %a5
	lea.l s1, %a6
	move.l #0,(%a4)
	move.l #0,(%a5)
	move.l #0,(%a6)
	movem.l (%sp)+, %a2-%a6 /* 応急処置*/
	rts


LOOP_Init:				/* d4: 計算用 */
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */

	move.l	%a3,	TOP_OFS(%a0)	
	move.l	%a3,	OUT_OFS(%a0)
	move.l	%a3,	IN_OFS(%a0)
	
	adda.l	#B_SIZE_MINUS,	%a3
	move.l	%a3,	BOTTOM_OFS(%a0)
	move.l	#0,	S_OFS(%a0)

	addq	#1,	%d0
	cmp	#2,	%d0
	bne	LOOP_Init		/* キュー2つ分繰返し */
	
end_Init:	
	movem.l (%sp)+, %d0-%d4/%a0-%a3
	rts


******INTERPUT*************************************************************************************
	** 入力：d1.l（チャンネル）
/*
INTERPUT:
	movem.l %d0-%d2,-(%sp)
	move.w  #0x2700, %sr
	cmpi #0, %d1
	bne	End_INTERPUT
	moveq	#1, %d0
	jsr	OUTQ
	*出力１：d0(失敗 0/ 成功 1 )
	*出力２：d1（取り出した8bitデータ）
	cmpi #0, %d0
	beq	INTERPUT_MASK
	ori #0x0800, %D1                | ヘッダを代入
	move.w %D1, UTX1                | 送信
	bra	End_INTERPUT
INTERPUT_MASK:
	move.w	USTCNT1, %d2
	andi.w	#0xFFFB, %d2	
	move.w	%d2,	USTCNT1 
	bra End_INTERPUT
End_INTERPUT:
	movem.l (%sp)+, %d0-%d2
	rts*/
INTERPUT:
	movem.l %d0-%d2, -(%sp)
	move.w #0x2700, %SR	/*step4.1:走行レベル7*/
	cmp.b #0x0, %d1		/*step4.2:ch!=0で分岐*/
	bne INTERPUT_END
	move.b #1, %d0
	jsr OUTQ		/*step4.3:OUTQの実行*/
	cmp.w #0, %d0		/*step4.4:戻り値が0で分岐*/
	beq INTERPUT_MASK
	move.b %d1, %d2
	addi.w #0x0800, %d2
	move.w %d2, UTX1	/*step4.5:ヘッダ付与*/

INTERPUT_END:
	movem.l (%sp)+, %d0-%d2
	rts

INTERPUT_MASK:
	move.w #0xe100, USTCNT1	/*step4.4:送信割り込みのマスク*/
		/* ↑ 何故かコメントアウトされていたので、修正 */

	bra INTERPUT_END
	
******************************************************************************************************	

*********PUTSTRING************************************************************************************
** 入力１： チャネル ch → %D1.L
** 入力２：データ読み込み先の先頭アドレス p → %D2.L
** 入力３：送信するデータ数 size → %D3.L
** 出力  ：実際に送信したデータ数 sz → %D0.L
	
/*PUTSTRING:
	movem.l %d1-%d6/%a0,-(%sp)
	cmpi #0, %d1
	bne	End_PUTSTRING
	moveq	#0, %d4  /* d4 = sz = 0 
	movea.l	%d2, %a0 /* a0 = i = p 
	cmpi #0, %d3
	beq	PUTSTRING_10
LOOP_PUTSTRING:	
	cmp	%d3, %d4
	beq	PUTSTRING_9
	moveq	#1, %d0
	move.b	(%a0), %d1
	jsr	INQ
	*d0 :キュー番号
	*d1 :8bitデータ
	*出力：d0(失敗 0/ 成功 1 )
	cmpi #0, %d0
	beq	PUTSTRING_9
	addq	#1, %d4
	addq	#1, %a0
	bra LOOP_PUTSTRING	
PUTSTRING_9:
	move.w	USTCNT1, %d6
	ori.w	#0x0004, %d6
	move.w	%d6,	USTCNT1 
PUTSTRING_10:
	move.l	%d4, %d0
End_PUTSTRING:
	movem.l (%sp)+, %d1-%d6/%a0
	rts*/
PUTSTRING:
		movem.l %a0-%a6/%d4-%d7, -(%SP)

		cmp.b #0x00, %d1		/*ch!=0で分岐*/
		bne PUTSTRING_END
		/* rv: バイトサイズの比較。０ではないときに終了する*/

		move.l #0x0000,%d4 		/*%d4=sz:送信したデータ数を格納*/
		/* rv: データ数(sz)の初期化*/

		move.l %d2,%a1 		/*%d5:データの読み込み先アドレス/
		/* rv: 読み込み先の先頭アドレスをa1に格納する*/	

		cmp.l #0x0000,%d3		/*size=0で分岐*/
		beq PUTSTRING_END
		/* rv: d3(size)が0ならば終了する*/


LOOP_STEP5:
		cmp.l %d4,%d3		/*sz=sizeで分岐*/
		beq PUTSTRING_MASK
		/* d3 と d4 size = sz ならばマスクへ移動*/

		move.b #0x01,%d0 		/*キュー番号の設定*/
		/* rv:  INQがバイトサイズで比較するのでｂに設定*/
		move.b (%a1)+,%d1	/*データをINQの入力d1に格納*/
		/* rv: 先頭アドレスから順に格納する*/

		jsr INQ

		cmp.w #0x00,%d0		/*成功or失敗判定*/
		beq PUTSTRING_MASK
		/*rv : 失敗ならばマスクへ移動する*/

		addq.l #0x01,%d4		/*sz++*/
		bra LOOP_STEP5

PUTSTRING_MASK:
		move.b #'7', LED1

		move.w #0xe10c, USTCNT1	/*送信割り込み許可*/
		bra PUTSTRING_END

PUTSTRING_END:
	move.l %d4,%d0		/*戻り値d0に実際に送信したデータ数を格納*/
	movem.l (%SP)+, %a0-%a6/%d4-%d7
	move.b #'4', LED4
	/*rte*/ 			/*?*/
	/* bus error出たので変更した*/
	***

	***
	rts
******************************************************************************************************

	
**********INQ**********************************************************************
*d0 :キュー番号
*d1 :8bitデータ
	*出力：d0(失敗 0/ 成功 1 )
/*
INQ:	
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp) 
	move.w #0x2700,%sr
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 
	move.w	#B_SIZE, %d2		/* d2: 256 
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) 
	
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE 
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) 
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE 
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) 
	******************************************************************************************
	move.l	S_OFS(%a0), %d4
	cmpi.l	#256, %d4
	beq	INQ_Failure
	bra	INQ_Step1*/
INQ:
	movem.l %d3, -(%sp)
	move.w %SR, %d3
	move.w #0x2700, %SR
	jsr SELECT_QUEUE
	jsr PUT_BUF
	move.w %d3, %SR
	movem.l (%sp)+, %d3
	rts
INQ_Failure:
	moveq	#0, %d0
	bra	END_INQ
INQ_Step1:
	/* (4) */
	move.l	IN_OFS(%a0), %a4
	move.b	%d1, (%a4)

	/* (5) */
	movea.l	IN_OFS(%a0), %a4
	movea.l	BOTTOM_OFS(%a0), %a5
	cmpa.l	%a4, %a5
	beq	BACK_IN
	movea.l	IN_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, IN_OFS(%a0)
	bra	INQ_Step2
BACK_IN:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, IN_OFS(%a0)
INQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4
	addq.l	#1, %d4
	move.l	%d4, S_OFS(%a0)
	moveq	#1, %d0
	
END_INQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts
SELECT_QUEUE:
	cmp.b #0, %d0
	beq SET_0
	cmp.b #1, %d0
	beq SET_1
	rts

SET_0:
	movem.l %a2-%a3, -(%sp)
	move.l in_0, in
	move.l out_0, out
	lea.l top, %a2
	move.l %a2, START_LABEL
	lea.l END_0(%a2), %a3
	move.l %a3, bottom
	move.l s0,s
	movem.l (%sp)+, %a2-%a3
	rts

SET_1:
	movem.l %a2-%a3, -(%sp)
	move.l in_1, in
	move.l out_1, out
	lea.l top, %a2
	lea.l OFFSET_1(%a2), %a3
	move.l %a3, START_LABEL
	lea.l END_1(%a2), %a3
	move.l %a3, bottom
	move.l s1,s
	movem.l (%sp)+, %a2-%a3
	rts
PUT_BUF:
	movem.l %a1-%a6/%d1, -(%sp)
	move.l s,%d2
	cmp.l #0x100,%d2
	beq PUT_FAIL
	lea.l s,%a4
	addq.l #1,(%a4)
	move.b #1,%d2 /*成功*/
	movea.l in, %a1
	move.b %d1, (%a1)+
	move.l bottom, %a3
	cmpa.l %a3, %a1
	bls PUT_BUF_STEP1
	move.l START_LABEL, %a2
	movea.l %a2, %a1

PUT_BUF_STEP1:
	move.l %a1, in
	cmpa.l out, %a1
	bne PUT_BUF_STEP2

PUT_BUF_STEP2:
	jsr UPDATE
	bra PUT_BUF_Finish

PUT_FAIL:
	move.w #0,%d2 /*失敗*/
	jsr UPDATE

PUT_BUF_Finish:
	movem.l (%sp)+, %a1-%a6/%d1
	rts

UPDATE:
	cmp.b #0, %d0
	beq QUEUE_0
	cmp.b #1, %d0
	beq QUEUE_1
	rts

QUEUE_0:
	move.l %a1, in_0
	move.l out, out_0
	move.l s,s0
	move.w %d2,%d0 /*成功or失敗の返り値*/
	rts
QUEUE_1:
	move.l %a1, in_1
	move.l out, out_1
	move.l s,s1
	move.w %d2,%d0 /*成功or失敗の返り値*/
	rts
***********************************************************************************


**********OUTQ**********************************************************************
*d0 :キュー番号
*出力１：d0(失敗 0/ 成功 1 )
*出力２：d1（取り出した8bitデータ）
/*
OUTQ:
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp) 
	move.w #0x2700,%sr
	*/
OUTQ:
	*move.w #0x0800+'a', UTX1
	movem.l %d3, -(%sp)
	move.w %SR, %d3
	move.w #0x2700, %SR
	jsr SELECT_QUEUE
	jsr GET_BUF
	move.w %d3, %SR
	movem.l (%sp)+, %d3
	rts
******************************************************************************************
******************************************************************************************
OUTQ_Failure:
	moveq	#0, %d0
	bra	END_OUTQ
OUTQ_Step1:
	/* (4) */
	move.l	OUT_OFS(%a0), %a4
	move.b	(%a4), %d1

	/* (5) */
	movea.l	OUT_OFS(%a0), %a4
	movea.l	BOTTOM_OFS(%a0), %a5
	cmpa.l	%a4, %a5
	beq	BACK_OUT
	movea.l	OUT_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, OUT_OFS(%a0)
	bra	OUTQ_Step2
BACK_OUT:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, OUT_OFS(%a0)
OUTQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4
	subq.l	#1, %d4
	move.l	%d4, S_OFS(%a0)
	moveq	#1, %d0
	
END_OUTQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts
GET_BUF:
	movem.l %a1-%a6, -(%sp)
	move.l s,%d2
	cmp.l #0x00,%d2
	beq GET_FAIL
	
	move.b #1,%d2 /*成功*/
	lea.l s,%a4
	subq.l #1,(%a4)
	movea.l out, %a1
	move.b (%a1)+, %d1
	move.l bottom, %a3
	cmpa.l %a3, %a1
	bls GET_BUF_STEP1
	move.l START_LABEL, %a2
	movea.l %a2, %a1

GET_BUF_STEP1:
	move.l %a1, out
	cmpa.l in, %a1
	bne GET_BUF_STEP2

GET_BUF_STEP2:
	jsr UPDATE
	bra GET_BUF_Finish

GET_FAIL:
	move.w #0,%d2 /*失敗*/
	jsr UPDATE
*move.w #0x0800+'e', UTX1

GET_BUF_Finish:
	movem.l (%sp)+, %a1-%a6
	rts

	
.section .data
******************************
** キュー用のメモリ領域確保と定数定義
******************************
.equ	B_SIZE, 	256
.equ	B_SIZE_MINUS,	255
.equ	Q_NUM,		2
.equ	TOP_OFS,	0
.equ	OUT_OFS,	4
.equ	IN_OFS,		8
.equ	BOTTOM_OFS,	12
.equ	S_OFS,		16
.equ	Q_INFO_SIZE,	20
.even
Q0_START: 	.ds.b	B_SIZE
Q1_START: 	.ds.b	B_SIZE
.even
Q_INFO:
	.ds.b	Q_INFO_SIZE * Q_NUM	
******************************
** 書き込むデータ（サンプル）
******************************
Data_to_Que: 	.ascii	"abcdef"		/* 読み書きテスト用に1バイト確保 */

INQ_Result: .ds.l   300
OUTQ_Data:  .ds.b   300
OUTQ_Result:.ds.l   300
