/* レジスタ定義 */
.equ REGBASE, 0xfff000 | DMAP を使用．
.equ IOBASE, 0x00d00000

/* 割り込み関係のレジスタ*/
.equ IVR, REGBASE+0x300 | 割り込みベクタレジスタ
.equ IMR, REGBASE+0x304 | 割り込みマスクレジスタ
.equ ISR, REGBASE+0x30c | 割り込みステータスレジスタ
.equ IPR, REGBASE+0x310 | 割り込みペンディングレジスタ

/* タイマ関係のレジスタ */
.equ TCTL1, REGBASE+0x600  | タイマ１コントロールレジスタ
.equ TPRER1, REGBASE+0x602 | タイマ１プリスケーラレジスタ
.equ TCMP1, REGBASE+0x604  | タイマ１コンペアレジスタ
.equ TCN1, REGBASE+0x608   | タイマ１カウンタレジスタ
.equ TSTAT1, REGBASE+0x60a | タイマ１ステータスレジスタ

/* UART1（送受信）関係のレジスタ */
.equ USTCNT1, REGBASE+0x900 | UART1 ステータス/コントロールレジスタ
.equ UBAUD1, REGBASE+0x902  | UART1 ボーコントロールレジスタ
.equ URX1, REGBASE+0x904    | UART1 受信レジスタ
.equ UTX1, REGBASE+0x906    | UART1 送信レジスタ

/* LED */
.equ LED7, IOBASE+0x000002f | ボード搭載の LED 用レジスタ
.equ LED6, IOBASE+0x000002d | 使用法については付録 A.4.3.1
.equ LED5, IOBASE+0x000002b
.equ LED4, IOBASE+0x0000029
.equ LED3, IOBASE+0x000003f
.equ LED2, IOBASE+0x000003d
.equ LED1, IOBASE+0x000003b
.equ LED0, IOBASE+0x0000039

	/* スタック */
.section .bss
.even
SYS_STK:	.ds.b   0x4000  |システムスタック領域
.even
SYS_STK_TOP:            |システムスタック領域の最後尾

/* 初期化 */
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

/* 割り込みハンドラ */


	
/*uart1_interrupt:
    movem.l %D0-%D7/%A0-%A6, -(%SP) | 使用するレジスタをスタックに保存
    move.w UTX1, %D0                | UTX1をD0レジスタにコピーし保存しておく
    move.w %D0, %D1                 | 計算用にD1レジスタにコピー
    lsr.w #8, %D1
    lsr.w #7, %D1                   | 15回右シフト（上位ビットは0埋め）
    cmpi.w #1, %D1                  | 0=FIFOが空ではない, 1=空である（割り込み発生）
    bne UART1_INTR_SKIP_PUT         | 送信割り込みでないならスキップ
    move.l #0, %D1                  | ch=%D1.L=0
    jsr INTERPUT
	*/
.section .text
.even
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
UART1_INTR_SKIP_PUT:
    move.w URX1, %D3                | 受信レジスタ URX1 を %D3.W にコピー
    move.b %D3, %D2                 | %D3.W の下位 8bit(データ部分) を %D2.B にコピー
    lsr.w #8, %D3
    lsr.w #5, %D3                   | 13回右シフト（上位ビットは0埋め）
    and.w #0x1, %D3                 | 0bit目以外を0に
    cmpi.w #1, %D3                  | 0 = 受信 FIFO にデータがない．1 = データがある
    bne UART1_INTR_SKIP_GET
    clr.l %D1                       | ch = %D1.L = 0, (data = %D2.Bは代入済)
    jsr INTERGET
UART1_INTR_SKIP_GET:
    movem.l (%SP)+, %D0-%D7/%A0-%A6 | レジスタを復帰
    rte

tmr1_interrupt:
    movem.l %D0-%D7/%A0-%A6,-(%SP)  | 使用するレジスタをスタックに保存
    move.w TSTAT1, %D0              | %D0=TSTAT1
    and.w #0x1, %D0                 | 0bit目以外を0に
    cmp.w #0, %D0
    beq TMR1_END                    | TSTAT1 の第 0 ビットが 1 となっているかどうかをチェックする．0 ならば rte で復帰
    clr.w TSTAT1                    | TSTAT1 を 0 クリア
    jsr CALL_RP
TMR1_END:
	movem.l (%SP)+, %D0-%D7/%A0-%A6 | レジスタを復帰
	rte
.include "syscall.s"
.include "queue.s"
.include "interget.s"
.include "timer.s"
.include "typeren2.s"
.end
