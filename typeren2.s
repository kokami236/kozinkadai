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
* スタック領域の確保
***************************************************************
***************************************************************
** 初期化
** 内部デバイスレジスタには特定の値が設定されている．
** その理由を知るには，付録Bにある各レジスタの仕様を参照すること．
***************************************************************
.section .data
	TDATA1: .ascii "0123456789ABCDEF"
	TDATA2: .ascii "klmnopqrstuvwxyz"
***************************************************************
** 現段階での初期化ルーチンの正常動作を確認するため，最後に’a’を
** 送信レジスタUTX1に書き込む．'a'が出力されれば，OK.
***************************************************************
.section .text
.even
MAIN:
		jsr Init_Q
		move.b #'1', LED7
		move.w #0xe108,USTCNT1/**/
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
	rts
/*bra PS_TEST2*/
/*以下テスト*/
/*TEST_READY:
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
	*/
/*以上テスト*/
