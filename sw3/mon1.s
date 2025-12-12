.include "defs.s"

/* スタック */
.section .bss
.even
SYS_STK:.ds.b 0x4000
.even
SYS_STK_TOP: | システムスタック領域の最後尾

/* 初期化 */
.section .text
.even
.extern start
.global monitor_begin
/*変更！sw3*/
monitor_begin:
boot:
    move.w #0x2700, %SR
    lea.l SYS_STK_TOP, %SP

    move.b #0x40, IVR
    move.l #0x00ffffff, IMR

    move.l #syscall_handler, 0x080
    move.l #uart1_interrupt, 0x110
    move.l #uart2_interrupt, 0x114      | ★追加：UART2 (level5)
    move.l #tmr1_interrupt, 0x118

    /* UART1 init */
    move.w #0x0000, USTCNT1
    move.w #0xe108, USTCNT1
    move.w #0x0038, UBAUD1

    /* UART2 init ★追加 */
    move.w #0x0000, USTCNT2
    move.w #0xe108, USTCNT2
    move.w #0x0038, UBAUD2

    /* timer init */
    move.w #0x0004, TCTL1

    jsr Init_Q

    /* UART1 + UART2 + TIMER を許可（想定）★変更 */
    move.l #0xff2ff9, IMR

    move.w #0x2000, %SR
    jmp start
/* ---- begin include main.s ---- */
****************************************************************
*** プログラム領域
****************************************************************
.section .text
.even
MAIN:
    ** 走行モードとレベルの設定 (「ユーザモード」への移行処理)
    move.w #0x0000, %SR   | USER MODE, LEVEL 0
    lea.l USR_STK_TOP,%SP | user stack の設定

    ** システムコールによる RESET_TIMER の起動
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0

    ** システムコールによる SET_TIMER の起動
    move.l #SYSCALL_NUM_SET_TIMER, %D0
    move.w #50000, %D1
    move.l #TT, %D2
    trap #0

******************************
* sys_GETSTRING, sys_PUTSTRING のテスト
* ターミナルの入力をエコーバックする
******************************
LOOP:
    move.l #SYSCALL_NUM_GETSTRING, %D0
    move.l #0, %D1   | ch = 0
    move.l #BUF, %D2 | p = #BUF
    move.l #256, %D3 | size = 256
    trap #0

    move.l %D0, %D3 | size = %D0 (length of given string)
    move.l #SYSCALL_NUM_PUTSTRING, %D0
    move.l #0, %D1  | ch = 0
    move.l #BUF,%D2 | p = #BUF
    trap #0
    bra LOOP

******************************
* タイマのテスト
* ’******’ を表示し改行する．
* ５回実行すると，RESET_TIMER をする．
******************************
TT:
    movem.l %D0-%D7/%A0-%A6,-(%SP)
    cmpi.w #5,TTC  | TTC カウンタで 5 回実行したかどうか数える
    beq TTKILL     | 5 回実行したら，タイマを止める
    move.l #SYSCALL_NUM_PUTSTRING,%D0
    move.l #0, %D1    | ch = 0
    move.l #TMSG, %D2 | p = #TMSG
    move.l #8, %D3    | size = 8
    trap #0

    addi.w #1,TTC | TTC カウンタを 1 つ増やして
    bra TTEND     | そのまま戻る
TTKILL:
    move.l #SYSCALL_NUM_RESET_TIMER,%D0
    trap #0
TTEND:
    movem.l (%SP)+,%D0-%D7/%A0-%A6
    rts

****************************************************************
*** 初期値のあるデータ領域
****************************************************************
.section .data
TMSG:
    .ascii "******\r\n"
    .even
TTC:
    .dc.w 0
    .even

****************************************************************
*** 初期値の無いデータ領域
****************************************************************
.section .bss
BUF:
    .ds.b 256 | BUF[256]
    .even
USR_STK:
    .ds.b 0x4000 | ユーザスタック領域
    .even
USR_STK_TOP:     | ユーザスタック領域の最後尾
/*; ---- end include main.s ----*/


/* 割り込みハンドラ */
/* ---- begin include syscall.s ---- */

.section .text
/*D0の値で呼び出すサブルーチンを決めている。ここでは何を呼び出しているかを分かりやすくするためにシンボルに数値を定義している(室原)*/
.equ SYSCALL_NUM_GETSTRING,   1 |文字列入力（GETSTRING）（ここからコメント鴻上）|
.equ SYSCALL_NUM_PUTSTRING,   2 |文字列出力(PUTSTRING)|
.equ SYSCALL_NUM_RESET_TIMER, 3 |タイマリセット|
.equ SYSCALL_NUM_SET_TIMER,   4 |タイマセット|
/*
 * syscall_handler
 * %d0: syscall number
 * %dx: syscall argument
	*/
******************************************
**syscall_handlerはTRAP #0により呼びだされるシステムコール共通ハンドラ（鴻上）
**D0レジスタの値によってどのサブルーチンをよぶかを分岐する
**入力D0.l :システムコール番号（上記定義のいづれか）
**D1~D7/A0~A6:各システムコールに応じた引数
**出力
**必要に応じてD0に戻り値を格納（鴻上）
*****************************************	
	
syscall_handler:
	movem.l %D1-%D7/%A0-%A6, -(%SP)
	cmpi.l #SYSCALL_NUM_GETSTRING, %D0   |D0==1?（鴻上）|
	beq CALL_GETSTRING                   |→GETSTRING処理へ|

	cmpi.l #SYSCALL_NUM_PUTSTRING, %D0   |D0==2?|
	beq CALL_PUTSTRING                   |→PUTSTRING処理へ|
	cmpi.l #SYSCALL_NUM_RESET_TIMER, %D0 |D0==3?|
	beq CALL_RESET_TIMER                 |RESET_TIMER処理へ|
	cmpi.l #SYSCALL_NUM_SET_TIMER, %D0   |D0==4?|
	beq CALL_SET_TIMER                   |CALL_SET_TIMER処理へ|
**********************
** いずれのシステムコール番号にも該当しない
**********************	
END_SYSCALL_HNDR:
    movem.l (%SP)+, %D1-%D7/%A0-%A6
	rte
**********
**各システムコール処理の分岐先
*********	
/*各サブルーチンを呼び出すための場所、サブルーチン呼出し後はシステムコールハンドラーの終了処理に移る(室原)*/	
CALL_GETSTRING:
	jsr GETSTRING
	bra END_SYSCALL_HNDR

CALL_PUTSTRING:
	jsr PUTSTRING
	bra END_SYSCALL_HNDR
	
CALL_RESET_TIMER:
	jsr RESET_TIMER
	bra END_SYSCALL_HNDR
CALL_SET_TIMER:
	jsr SET_TIMER
	bra END_SYSCALL_HNDR
/*; ---- end include syscall.s ----*/

/* ---- begin include queue.s ---- */
.section .text

** ここからデータ領域までのコメント：河野
*****************キューの初期化処理*******************************************************************
Init_Q:
	movem.l %d0-%d4/%a0-%a3,-(%sp)
	moveq 	#0, %d0			/* d0: キュー番号かつカウンタ */
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */

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
	move.l	%a3,	IN_OFS(%a0)	/* TOP=OUT=IN=キューの先頭 */
	
	adda.l	#B_SIZE_MINUS,	%a3	/* a3=255 */
	move.l	%a3,	BOTTOM_OFS(%a0) /* BOTTOM=キューの末尾 */
	move.l	#0,	S_OFS(%a0)	/* S = 0(キューの要素は最初０ */

	addq	#1,	%d0		/* Q1にも同様の操作 */
	cmp #4, %d0
        bne LOOP_Init
	
end_Init:	
	movem.l (%sp)+, %d0-%d4/%a0-%a3
	rts
****************************************************************************************************


******INTERPUT*************************************************************************************
** 入力：d1.l（チャンネル）
** チャネル ch の送信キューからデータを一つ取り出し，実際に送信	
INTERPUT:
    movem.l %d0-%d2, -(%sp)
    move.w  #0x2700, %sr

    /* ch -> txq */
    cmpi.l  #0, %d1
    beq     IP_CH0
    cmpi.l  #1, %d1
    beq     IP_CH1
    bra     IP_END

IP_CH0:
    moveq   #1, %d0          /* txq=1 */
    jsr     OUTQ
    cmpi    #0, %d0
    beq     IP_MASK0
    ori     #0x0800, %d1
    move.w  %d1, UTX1
    bra     IP_END

IP_MASK0:
    move.w  USTCNT1, %d2
    andi.w  #0xFFFB, %d2
    move.w  %d2, USTCNT1
    bra     IP_END

IP_CH1:
    moveq   #3, %d0          /* txq=3 */
    jsr     OUTQ
    cmpi    #0, %d0
    beq     IP_MASK1
    ori     #0x0800, %d1
    move.w  %d1, UTX2
    bra     IP_END

IP_MASK1:
    move.w  USTCNT2, %d2
    andi.w  #0xFFFB, %d2
    move.w  %d2, USTCNT2

IP_END:
    movem.l (%sp)+, %d0-%d2
    rts

	
******************************************************************************************************	

*********PUTSTRING************************************************************************************
** データを送信キューに格納し，送信割り込みを開始	
** 入力１：チャネル ch → %D1.L
** 入力２：データ読み込み先の先頭アドレス p → %D2.L　変更後！！
** 入力３：送信するデータ数 size → %D3.L
** 出力  ：実際に送信したデータ数 sz → %D0.L
	
PUTSTRING:
    movem.l %d1-%d6/%a0, -(%sp)

    /* ch -> txq と USTCNT を決める */
    cmpi.l  #0, %d1
    beq     PS_CH0
    cmpi.l  #1, %d1
    beq     PS_CH1
    moveq.l #0, %d0
    bra     PS_END

PS_CH0:
    moveq.l #1, %d5          /* txq=1 */
    bra     PS_START
PS_CH1:
    moveq.l #3, %d5          /* txq=3 */

PS_START:
    moveq   #0, %d4
    movea.l %d2, %a0
    cmpi.l  #0, %d3
    beq     PS_ENABLE_TX

PS_LOOP:
    cmp     %d3, %d4
    beq     PS_ENABLE_TX

    move.l  %d5, %d0         /* queue = txq */
    move.b  (%a0), %d1        /* data */
    jsr     INQ
    cmpi.l  #0, %d0
    beq     PS_ENABLE_TX

    addq    #1, %d4
    addq    #1, %a0
    bra     PS_LOOP

PS_ENABLE_TX:
    /* TX割り込み許可（UARTごとに切替） */
    cmpi.l  #1, %d5
    beq     PS_EN0

    /* ch=1 -> UART2 */
    move.w  USTCNT2, %d6
    ori.w   #0x0004, %d6
    move.w  %d6, USTCNT2
    bra     PS_RET

PS_EN0:
    /* ch=0 -> UART1 */
    move.w  USTCNT1, %d6
    ori.w   #0x0004, %d6
    move.w  %d6, USTCNT1

PS_RET:
    move.l  %d4, %d0

PS_END:
    movem.l (%sp)+, %d1-%d6/%a0
    rts
******************************************************************************************************

	
**********INQ**********************************************************************
** 入力１：d0（キュー番号）
** 入力２：d1（8bitデータ）
** 出力　：d0(失敗 0/ 成功 1 )
INQ:
	/* (1) */
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp)

	/* (2) */
	move.w #0x2700,%sr

	** キューd0について、キュー情報の先頭・キューの先頭のアドレスをそれぞれ取得
	******************************************************************************************
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */
	
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */
	******************************************************************************************

	/* (3) */
	move.l	S_OFS(%a0), %d4
	cmpi.l	#256, %d4		| s==256?（満杯のキューに入れようとしているか？）
	beq	INQ_Failure	
	bra	INQ_Step1
INQ_Failure:
	moveq	#0, %d0
	bra	END_INQ			| 0（失敗）を出力し、終了
INQ_Step1:
	/* (4) */
	move.l	IN_OFS(%a0), %a4	| a4:キュー中、データを入れるべき番地
	move.b	%d1, (%a4)		| m[in] = data

	/* (5) */ ** inがキューの終端に来たら、循環させる
	movea.l	IN_OFS(%a0), %a4	| a4 = in
	movea.l	BOTTOM_OFS(%a0), %a5	| a5 = bottom
	cmpa.l	%a4, %a5		| in == bottom?
	beq	BACK_IN			
	movea.l	IN_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, IN_OFS(%a0)	| in++
	bra	INQ_Step2
BACK_IN:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, IN_OFS(%a0)	| in = top
INQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4
	addq.l	#1, %d4			
	move.l	%d4, S_OFS(%a0)		| s++
	moveq	#1, %d0			| d0 = 1（成功）
	
END_INQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts

***********************************************************************************


**********OUTQ**********************************************************************
** 入力　：d0（キュー番号）
** 出力１：d0(失敗 0/ 成功 1 )
** 出力２：d1（取り出した8bitデータ）

OUTQ:
	/* (1) */
	move.w %sr, -(%sp)
	movem.l %d2-%d7/%a0-%a6,-(%sp) 

	/* (2) */
	move.w #0x2700,%sr

	** キューd0について、キュー情報の先頭・キューの先頭のアドレスをそれぞれ取得
	******************************************************************************************
	lea.l	Q_INFO, %a1		/* a1: Q_INFOの開始地点 */
	lea.l	Q0_START, %a2 		/* a2: Q0の先頭番地 */
	move.w	#B_SIZE, %d2		/* d2: 256 */
	move.w	#Q_INFO_SIZE, %d3	/* d3: 20 (キュー１個分の情報量) */
	
	move.l	%d0,	%d4
	mulu	%d3,	%d4		/* d4 = d0 * Q_INFO_SIZE */
	move.l	%d4,	%a0
	add.l	%a1,	%a0		/* a0 = Q_INFO + d0 * Q_INFO_SIZE(各キュー情報の先頭) */
	
	move.l	%d0,	%d4			
	mulu	%d2,	%d4		/* d4 = d0 * B_SIZE */
	move.l	%d4,	%a3
	add.l	%a2,	%a3		/* a3 = Q0_START + d0 * B_SIZE(各キューの先頭) */
	******************************************************************************************

	/* (3) */
	move.l	S_OFS(%a0), %d4
	cmpi.l	#0, %d4
	beq	OUTQ_Failure		| s == 0?（空のキューから取り出そうとしている？）
	bra	OUTQ_Step1
OUTQ_Failure:
	moveq	#0, %d0
	bra	END_OUTQ
OUTQ_Step1:
	/* (4) */
	move.l	OUT_OFS(%a0), %a4	| a4 = out
	move.b	(%a4), %d1		| d1 = m[out]

	/* (5) */
	movea.l	OUT_OFS(%a0), %a4	| a4 = out
	movea.l	BOTTOM_OFS(%a0), %a5	| a5 = bottom
	cmpa.l	%a4, %a5		| out == bottom?（取り出し場所のポインタが、キューの末尾に到達？）
	beq	BACK_OUT
	movea.l	OUT_OFS(%a0), %a4
	addq	#1, %a4
	move.l	%a4, OUT_OFS(%a0)	| out++
	bra	OUTQ_Step2
BACK_OUT:
	movea.l	TOP_OFS(%a0), %a4
	move.l	%a4, OUT_OFS(%a0)	| out = top
OUTQ_Step2:
	/* (6) */
	move.l	S_OFS(%a0), %d4		
	subq.l	#1, %d4
	move.l	%d4, S_OFS(%a0)		| s--
	moveq	#1, %d0			| d0 = 1（成功）
	
END_OUTQ:	
	/* (7) */
	movem.l (%sp)+, %d2-%d7/%a0-%a6
	move.w (%sp)+, %sr
	rts

***********************************************************************************


	
.section .data
***********************************
** キュー用のメモリ領域確保と定数定義Q4個に増やした！変更
***********************************
	.equ	B_SIZE, 	256
	.equ	B_SIZE_MINUS,	255
	.equ	Q_NUM,		4
	
	.equ	TOP_OFS,	0
	.equ	OUT_OFS,	4
	.equ	IN_OFS,		8
	.equ	BOTTOM_OFS,	12
	.equ	S_OFS,		16
	.equ	Q_INFO_SIZE,	20

	
.even
Q0_START:    .ds.b B_SIZE   | RX0 (UART1受信)
Q1_START:    .ds.b B_SIZE   | TX0 (UART1送信)
Q2_START:    .ds.b B_SIZE   | RX1 (UART2受信)
Q3_START:    .ds.b B_SIZE   | TX1 (UART2送信)
.even
Q_INFO:
    .ds.b Q_INFO_SIZE * Q_NUM
	.ds.b	Q_INFO_SIZE * Q_NUM
/*; ---- end include queue.s ----*/

/* ---- begin include interget.s ---- */
.section .text

***************************
** %d1.l = ch
** %d2.b = 受信データ  data
** 戻り値  なし　変更後！！！
***************************
INTERGET:
    movem.l %d0-%d1, -(%sp)

    /* ch=0 or 1 だけ許可。それ以外は捨てる */
    cmpi.l  #0, %d1
    beq     IG_CH0
    cmpi.l  #1, %d1
    beq     IG_CH1
    bra     IG_END

IG_CH0:
    move.b  %d2, %d1         /* d1 = data */
    moveq.l #0, %d0          /* RX0 = queue 0 */
    jsr     INQ
    bra     IG_END

IG_CH1:
    move.b  %d2, %d1         /* d1 = data */
    moveq.l #2, %d0          /* RX1 = queue 2 */
    jsr     INQ

IG_END:
    movem.l (%sp)+, %d0-%d1
    rts

	
**********************************************
** %d1.l = ch
** %d2.l = 書き込み先の先頭アドレス p
** %d3.l = 取り出すデータ数  size
** 戻り値  %d0.l = 実際に取り出したデータ数  変更後
**********************************************
GETSTRING:
    movem.l %d4-%d6/%a0, -(%sp)

    /* ch -> rxq を決める：ch=0 -> 0, ch=1 -> 2 */
    cmpi.l  #0, %d1
    beq     GS_CH0
    cmpi.l  #1, %d1
    beq     GS_CH1
    moveq.l #0, %d0          /* 不正chは0文字 */
    bra     GS_END

GS_CH0:
    moveq.l #0, %d6          /* d6 = rxq */
    bra     GS_START
GS_CH1:
    moveq.l #2, %d6          /* d6 = rxq */

GS_START:
    moveq.l #0, %d4          /* sz = 0 */
    movea.l %d2, %a0         /* p */

GS_LOOP:
    cmp.l   %d4, %d3
    beq     GS_DONE

    move.l  %d6, %d0         /* queue = rxq */
    jsr     OUTQ
    cmpi.l  #0, %d0
    beq     GS_DONE

    move.b  %d1, (%a0)+
    addq.l  #1, %d4
    bra     GS_LOOP

GS_DONE:
    move.l  %d4, %d0

GS_END:
    movem.l (%sp)+, %d4-%d6/%a0
    rts

/*; ---- end include interget.s ----*/

/* ---- begin include timer.s ---- */
.section .bss
task_p:	.ds.b 4 /*タイマ割り込みで実行するプログラムの先頭アドレスを格納*/

/*タイマルーチン*/

.section .text

/*
タイマ1コントロールレジスタ
TCTL1 
    bit 4  : Interrupt Request Enable（比較割り込み） 0=disable, 1=enable
    bit 3-1: Clock Source 001 = 入力は SYSCLK．010 = 入力は SYSCLK/16．011 = 入力は TIN．1xx = 入力は CLK32．
    bit 0  : Timer Enable. 0=disable. 1=enable
（楠田・鴻上）
*/


/* RESET_TIMER
 *   タイマ割り込みを不可に。タイマを停止。（楠田・鴻上）
 */
RESET_TIMER:
	move.w #0x0004, TCTL1 | TCTL1=0b0_010_0
	rts

/* SET_TIMER:
 *   タイマ割り込み時に起動するサブルーチンを設定
 *   t * 0.1 msec 秒毎に割り込みが発生するように設定
 * 
 * %D1.W: タイマ割り込み発生周期 t
 * %D2.L: 割り込み時に起動するルーチンの先頭アドレス p
 * （楠田・鴻上）
 */
SET_TIMER:
	move.l %D2, task_p  /* 割り込み時に呼び出すサブルーチンのアドレスをtask_pにセット（楠田・鴻上） */
	move.w #206, TPRER1 /*カウンタ周波数を10000にする-> 周期0.1msec*/
	move.w %D1, TCMP1   /* TCMP1 = t （楠田・鴻上） */
	move.w #0x0015, TCTL1 /*比較割り込み許可, 1/16周期, タイマ許可*/
                          /* TCTL1 = 0b1_010_1 （楠田・鴻上）*/
	rts

/* CALL_RP:
 *   タイマ割り込み時に処理すべきルーチンを呼び出す
 * （楠田・鴻上）
 */
CALL_RP:
	movea.l task_p, %A0 /*task_pを使ってジャンプできないためA0レジスタにアドレスを入れてサブルーチンにジャンプさせる*/
	jsr  (%A0)  /* 割り込み時に起動するルーチンに遷移（楠田・鴻上） */
	rts
/*; ---- end include timer.s ----*/


uart1_interrupt:
/*送信割り込みベクタと受信割り込みベクタが同じであるため受信レジスタ、送信レジスタの値で送受信割り込みを区別する(室原)*/
    movem.l %D0-%D7/%A0-%A6, -(%SP) | 使用するレジスタをスタックに保存
    move.w UTX1, %D0                | UTX1をD0レジスタにコピーし保存しておく
    move.w %D0, %D1                 | 計算用にD1レジスタにコピー
    lsr.w #8, %D1
    lsr.w #7, %D1                   | 15回右シフト（上位ビットは0埋め）
    cmpi.w #1, %D1                  | 0=FIFOが空ではない, 1=空である（割り込み発生）
    bne UART1_INTR_SKIP_PUT         | 送信割り込みでないならスキップ 受信割り込みの処理に入る(室原)
    move.l #0, %D1                  | ch=%D1.L=0
    jsr INTERPUT
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
    /*TASTAT1の第0ビットが0のときはコンペアイベントが起きていないためタイマ割り込みは起きてない, よって終了処理に移る->今回のタイマはコンペアイベントのみしか使わないため第0ビットだけ調べればよい(室原)*/
    clr.w TSTAT1                    | TSTAT1 を 0 クリア
    jsr CALL_RP /*タイマ割り込みが発生した時に処理すべきルーチンに移動するためにCALL_RPを呼び出す(室原)*/
TMR1_END:
    movem.l (%SP)+, %D0-%D7/%A0-%A6 | レジスタを復帰
    rte

.end
uart2_interrupt:
    movem.l %D0-%D7/%A0-%A6, -(%SP)

    /* 送信割り込み判定（UTX2） */
    move.w UTX2, %D0
    move.w %D0, %D1
    lsr.w #8, %D1
    lsr.w #7, %D1
    cmpi.w #1, %D1
    bne UART2_INTR_SKIP_PUT
    move.l #1, %D1           /* ch=1 */
    jsr INTERPUT

UART2_INTR_SKIP_PUT:
    /* 受信割り込み判定（URX2） */
    move.w URX2, %D3
    move.b %D3, %D2
    lsr.w #8, %D3
    lsr.w #5, %D3
    and.w #0x1, %D3
    cmpi.w #1, %D3
    bne UART2_INTR_SKIP_GET
    move.l #1, %D1           /* ch=1 */
    jsr INTERGET

UART2_INTR_SKIP_GET:
    movem.l (%SP)+, %D0-%D7/%A0-%A6
    rte
