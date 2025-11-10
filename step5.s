		***************************************************************
		**各種レジスタ定義
		***************************************************************

		***************
		** レジスタ群の先頭
		***************
		.equ REGBASE,   0xFFF000          | DMAPを使用．
		.equ IOBASE,    0x00d00000

		***************
		** 割り込み関係のレジスタ
		***************
		.equ IVR,       REGBASE+0x300     |割り込みベクタレジスタ
		.equ IMR,       REGBASE+0x304     |割り込みマスクレジスタ
		.equ ISR,       REGBASE+0x30c     |割り込みステータスレジスタ
		.equ IPR,       REGBASE+0x310     |割り込みペンディングレジスタ

		***************
		** タイマ関係のレジスタ
		***************
		.equ TCTL1,     REGBASE+0x600     |タイマ１コントロールレジスタ
		.equ TPRER1,    REGBASE+0x602     |タイマ１プリスケーラレジスタ
		.equ TCMP1,     REGBASE+0x604     |タイマ１コンペアレジスタ
		.equ TCN1,      REGBASE+0x608     |タイマ１カウンタレジスタ
		.equ TSTAT1,    REGBASE+0x60a     |タイマ１ステータスレジスタ

		***************
		** UART1（送受信）関係のレジスタ
		***************
		.equ USTCNT1,   REGBASE+0x900     | UART1ステータス/コントロールレジスタ
		.equ UBAUD1,    REGBASE+0x902     | UART1ボーコントロールレジスタ
		.equ URX1,      REGBASE+0x904     | UART1受信レジスタ
		.equ UTX1,      REGBASE+0x906     | UART1送信レジスタ

		***************
		** LED
		***************
		.equ LED7,      IOBASE+0x000002f  |ボード搭載のLED用レジスタ
		.equ LED6,      IOBASE+0x000002d  |使用法については付録A.4.3.1
		.equ LED5,      IOBASE+0x000002b
		.equ LED4,      IOBASE+0x0000029
		.equ LED3,      IOBASE+0x000003f
		.equ LED2,      IOBASE+0x000003d
		.equ LED1,      IOBASE+0x000003b
		.equ LED0,      IOBASE+0x0000039

		***************************************************************
		** スタック領域の確保
		***************************************************************
		.section .bss
		.even
SYS_STK:
		.ds.b   0x4000  |システムスタック領域
		.even
SYS_STK_TOP:            |システムスタック領域の最後尾

		***************************************************************
		** 初期化
		** 内部デバイスレジスタには特定の値が設定されている．
		** その理由を知るには，付録Bにある各レジスタの仕様を参照すること．
		***************************************************************


.section .data
	TDATA1: .ascii "0123456789ABCDEF"
	TDATA2: .ascii "klmnopqrstuvwxyz"


		

.section .text
		.even
boot:
		* スーパーバイザ&各種設定を行っている最中の割込禁止
		move.w #0x2700,%SR
		lea.l  SYS_STK_TOP, %SP | Set SSP

		****************
		**割り込みコントローラの初期化
		****************
		move.b #0x40, IVR       |ユーザ割り込みベクタ番号を| 0x40+levelに設定．
		move.l #0x00ffffff,IMR  |全割り込みマスク /* STEP2.3 */

		****************
		** 送受信(UART1)関係の初期化(割り込みレベルは4に固定されている)
		****************
		move.w #0x0000, USTCNT1 |リセット
		move.w #0xe100, USTCNT1 |送受信可能,パリティなし, 1 stop, 8 bit,|送受割り込み禁止
		move.w #0x0038, UBAUD1  |baud rate = 230400 bps

		****************
		** タイマ関係の初期化(割り込みレベルは6に固定されている)
		*****************
		move.w #0x0004, TCTL1   | restart,割り込み不可,|システムクロックの1/16を単位として計時，|タイマ使用停止

		***************************************************************
		** STEP2の処理
		***************************************************************
		/* 初期化処理をメインルーチンからこちらへ移動 */
		*lea.l uart1_interrupt, %a0
		*move.l %a0, 0x110 /* STEP2.1 level 4, (64+4)*4 割り込み処理ルーチンの開始アドレスをレベル4割り込みベクタに設定 */
		move.l #uart1_interrupt, 0x110

		move.w #0xe100, USTCNT1 |送受信割り込みマスク
		move.l #0x00ff3ffb,IMR  |UART1許可
		move.w #0x2700, %SR    /* 走行レベル7 */
		

		bra MAIN

		***************************************************************
		** 現段階での初期化ルーチンの正常動作を確認するため，最後に’a’を
		** 送信レジスタUTX1に書き込む．'a'が出力されれば，OK.
		***************************************************************
		.section .text
		.even




	
MAIN:
		jsr Init_Q
		move.b #'1', LED7
		*move.w #0xe108,USTCNT1
		move.w #0x2000, %SR    /* 走行レベル0 */


PS_TEST1:
		/* jsr PUTSTRING(0, #TDATA1, 16)*/
		move.b	#0x00, %d1
		move.l	#TDATA1, %d2
		move.l	#0x10, %d3
		jsr PUTSTRING
		
	
		move.b #'2', LED6
		move.l	#0x0fffff, %d4
	
		
LOOP:
		subq.l #1,%d4
		beq PS_TEST2
		move.b #'5', LED3
		
		bra LOOP

PS_TEST2:
		move.b #'6', LED2
		move.b	#0x00, %d1
		move.l	#TDATA2, %d2
		move.l	#0x10, %d3
		jsr PUTSTRING
		bra PS_TEST2

/*以下テスト*/
TEST_READY:
		*movem.l %d1-%d5, -(%sp)
	
		move.w #16, %d4
		move.w #16, %d5
		move.b #0x61, %d1
		bra TEST_LOOP

TEST_LOOP2:

		addq #1, %d1
		move.w #16, %d4

TEST_LOOP:
		moveq #1, %d0
		*move.w #0x1000, %d0
		jsr INQ
		*jsr OUTQ
		subq #1, %d4
		bne TEST_LOOP
		subq #1, %d5
		beq TEST_END
		bra TEST_LOOP2

TEST_END:
		*movem.l (%sp)+, %d1-%d5
		rts
/*以上テスト*/

uart1_interrupt:
		move.b #'3', LED5
		movem.l %d0, -(%sp)

		*move.b #'a', %d0 /* URX1の下位8ビットのデータを転送 */
		*addi.w #0x0800, %d0 /* 即値をレジスタd0に加算 */
		*move.w %d0, UTX1 /* 16ビットのデータをUTX1に転送 */


		move.w UTX1, %d0	/*step4:UTX1のコピー*/
		
		move.b #0, %d1	/*chの選択*/

		cmp #0x8000,%d0
		bcs uart1_END

		jsr INTERPUT

uart1_END:	
		movem.l (%sp)+, %d0
		
		rte


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

*************************************************************
**PUTSTRING
**入力
**d1:チャネル
**d2:データ読み込み先の先頭アドレス
**d3:送信するデータ数size
**戻り値
**d0:実際に送信したデータ数
*************************************************************
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

		*rte 			/*?*/
		/* bus error出たので変更した*/

		***
		move.b #'4', LED4
		***
		rts

******************************************************************************:

******
******以降QUEUE
******

.section .data
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

/* 初期化*/
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

*****************************************************************
**d0:キューの選択
**d1:書き込むデータ
**d1:返り値、成功or失敗
*****************************************************************
INQ:
movem.l %d3, -(%sp)
move.w %SR, %d3
move.w #0x2700, %SR
jsr SELECT_QUEUE
jsr PUT_BUF
move.w %d3, %SR
movem.l (%sp)+, %d3
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

********************************************
**d0:キューの選択
**d1:戻り値、取り出したデータ
********************************************
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









