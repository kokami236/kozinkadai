***************************************************************
** 各種レジスタ定義 
***************************************************************

***************
** レジスタ群の先頭 
***************
.equ REGBASE,	0xFFF000 	| DMAP を使用．
.equ IOBASE,	0x00d00000

***************
** 割り込み関係のレジスタ 
***************
.equ IVR, 	REGBASE+0x300 	| 割り込みベクタレジスタ
.equ IMR, 	REGBASE+0x304 	| 割り込みマスクレジスタ
.equ ISR, 	REGBASE+0x30c 	| 割り込みステータスレジスタ
.equ IPR,	REGBASE+0x310 	| 割り込みペンディングレジスタ

***************
** タイマ関係のレジスタ 
***************
.equ TCTL1,	REGBASE+0x600 	| タイマ１コントロールレジスタ
.equ TPRER1, 	REGBASE+0x602 	| タイマ１プリスケーラレジスタ
.equ TCMP1, 	REGBASE+0x604 	| タイマ１コンペアレジスタ
.equ TCN1, 	REGBASE+0x608 	| タイマ１カウンタレジスタ
.equ TSTAT1, 	REGBASE+0x60a 	| タイマ１ステータスレジスタ

***************
** UART1（送受信）関係のレジスタ 
***************
.equ USTCNT1, 	REGBASE+0x900 	| UART1 ステータス/コントロールレジスタ
.equ UBAUD1, 	REGBASE+0x902 	| UART1 ボーコントロールレジスタ
.equ URX1, 	REGBASE+0x904 	| UART1 受信レジスタ
.equ UTX1, 	REGBASE+0x906 	| UART1 送信レジスタ

***************
** LED
***************
.equ LED7, 	IOBASE+0x000002f | ボード搭載の LED 用レジスタ
.equ LED6, 	IOBASE+0x000002d | 使用法については付録 A.4.3.1
.equ LED5, 	IOBASE+0x000002b
.equ LED4, 	IOBASE+0x0000029
.equ LED3, 	IOBASE+0x000003f
.equ LED2, 	IOBASE+0x000003d
.equ LED1, 	IOBASE+0x000003b
.equ LED0, 	IOBASE+0x0000039

***************
**システムコール番号
***************
.equ	SYSCALL_NUM_GETSTRING,     1
.equ	SYSCALL_NUM_PUTSTRING,     2
.equ	SYSCALL_NUM_RESET_TIMER,   3
.equ	SYSCALL_NUM_SET_TIMER,     4

***************************************************************
** スタック領域の確保 
***************************************************************
.section .bss
.even
SYS_STK:
	.ds.b 	0x4000 	| システムスタック領域 
	.even 
SYS_STK_TOP: 		| システムスタック領域の最後尾

task_p: .ds.l 	1	| あらかじめtask_pをbssセクションで定義しておく

******************************
** キュー用のメモリ領域確保
******************************
.equ	B_SIZE, 256

TOP:	.ds.b	B_SIZE-1
BOTTOM: .ds.b	1
IN:	.ds.l	1
OUT:	.ds.l	1
S:	.ds.l	1

TOP1:	.ds.b	B_SIZE-1
BOTTOM1: .ds.b	1
IN1:	.ds.l	1
OUT1:	.ds.l	1
S1:	.ds.l	1


***************************************************************
** 初期化 
** 内部デバイスレジスタには特定の値が設定されている． 
** その理由を知るには，付録 B にある各レジスタの仕様を参照すること．
***************************************************************
.section .text
.even
boot: 
	** スーパーバイザ & 各種設定を行っている最中の割込禁止
	move.w 	#0x2700,%SR
	lea.l 	SYS_STK_TOP, %SP 	| Set SSP

	****************
	** 割り込みコントローラの初期化 
	****************
	move.b 	#0x40, IVR 		| ユーザ割り込みベクタ番号を
					| 0x40+level に設定．
	move.l 	#0x00ffffff,IMR 	| 全割り込みマスク


	****************
	** 送受信 (UART1) 関係の初期化 (割り込みレベルは 4 に固定されている)
	****************
	move.w 	#0x0000, USTCNT1 	| リセット
	move.w 	#0xe100, USTCNT1 	| 送受信可能, パリティなし, 1 stop, 8 bit,
					| 送受割り込み禁止
	move.w 	#0x0038, UBAUD1 	| baud rate = 230400 bps


	****************
	** タイマ関係の初期化 (割り込みレベルは 6 に固定されている) 
	*****************
	move.w 	#0x0004, TCTL1 		| restart, 割り込み不可, 
					| システムクロックの 1/16 を単位として計時，
					| タイマ使用停止

	*****************
	**割り込みベクタの初期化
	***************
	**trap#0命令の際にジャンプすべきルーチンの先頭アドレスをtrap#0割り込みのベクタに設定
	move.l	#systemcall, 0x080

	**送受信割り込みの際にジャンプすべきルーチンの先頭アドレスを，送受信割り込みのベクタに設定
	move.l 	#uart1_interrupt, 0x110 	| level 4, (64+4)*4 

	**タイマ割り込みの際にジャンプすべきルーチンの先頭アドレスを，タイマ割り込みのベクタに設定
	move.l 	#timer_interrupt, 0x118 	| level 6, (64+4)*4 
	
	*****************
	**本実験では使用しない割り込みベクタの初期化
	move.l	#LV1, 0x104
	move.l	#LV2, 0x108
	move.l	#LV3, 0x10c
	move.l	#LV5, 0x114
	move.l	#LV7, 0x11c


	**割り込みマスクレジスタ設定
	move.l	#0xff3ff9, IMR			| UART1割り込み,Timer1割り込みを許可
	**マスクの設定
	move.w	#0xe108, USTCNT1		| 受信を許可 送信を禁止

	jsr INIT_Q				| キューの初期化

	
	/*初期化が全て終わったら割り込みを許可する*/
	**走行レベルを0にする
	move.w	#0x2000,%SR    			| 割り込み許可．(スーパーバイザモードの場合)

	bra 	MAIN

**初期化終了
***************************************************************




***************************************************************
**送受信用HW割り込みインタフェース
***************************************************************
uart1_interrupt:
	movem.l %d1-%d3,-(%SP)

**送信用HW割り込みインターフェース
	move.w	UTX1,%d2		| d2にUTX1をコピー
	cmp	#0x8000,%d2		| d2の15ビット目が1かどうか判別
	bcs	Interface_get		| d2の15ビット目が0ならInterface_getへ

	/* 15bitが1なら送信割り込みを行う */
	moveq.l	#0,%d1			| ch=%D1.L=0としてINTERPUTを呼び出す
	jsr	INTERPUT		| INTERPUTサブルーチンに処理を渡す


**受信用HW割り込みインタフェース
Interface_get:
	move.w	URX1,%d3		| 受信レジスタURX1を%D3.Wにコピー
	move.b	%d3,%d2			| D3.Wの下位8bit(データ部分)を%D2.Bにコピー
	cmp	#0x2000,%d3		| d3の13ビット目を判別
	bcs	uart1_interrupt_end	| 13bitが0ならばuart1_interrupt_endへ

	/* 13bitが1なら受信割り込みを行う */
	moveq.l	#0,%d1			| チャンネルch = %D1.L =0としてINTERGETを呼び出す
	jsr	INTERGET		| dataの値は%d2.b	


uart1_interrupt_end:
	movem.l (%SP)+, %d1-%d3
	move.w #0x2000,%SR
	rte				| 割り込み終了

******************************************************************
**タイマ用HW割り込みインタフェース
******************************************************************
timer_interrupt:
	movem.l %d1/%a0,-(%SP)
	move	%SR,-(%SP)

	move.w	TSTAT1,%d1
	cmpi	#0x0002, %d1		| TSTAT1の1ビット目が1か判別
	beq	timer_interrupt_end	| 1ならtimer_interrupt_end

	cmpi	#0x0000, %d1		| TASTA1の0ビット目が1か判別
	beq	timer_interrupt_end	| 0ならtimer_interrupt_end

	/* 0ビット目が1のとき */
	move.w	#0x0000,TSTAT1		| TSTAT1を0クリア
	jsr	CALL_RP			| CALL_RP

timer_interrupt_end:
	move	(%SP)+,%SR
	movem.l (%SP)+, %d1/%a0
	rte

******************************************************************
**システムコールインタフェース
******************************************************************
systemcall:
	cmp	#1,%d0
	beq	GO_GETSTRING
	cmp	#2,%d0
	beq	GO_PUTSTRING
	cmp	#3,%d0
	beq	GO_RESET_TIMER
	cmp	#4,%d0
	beq	GO_SET_TIMER
	bra	systemcall_end

GO_GETSTRING:
	jsr	GETSTRING
	bra	systemcall_end
GO_PUTSTRING:
	jsr	PUTSTRING
	bra	systemcall_end
GO_RESET_TIMER:
	jsr	RESET_TIMER
	bra	systemcall_end
GO_SET_TIMER:
	jsr	SET_TIMER
	bra	systemcall_end

systemcall_end:
	rte


****************************
**使用しない割り込みルーチン
****************************
LV1:
	rte
LV2:
	rte
LV3:
	rte
LV5:
	rte
LV7:
	rte



******************************************************************
**サブルーチン
******************************************************************

**********************
** キューの初期化処理
**********************
INIT_Q:
	lea.l	TOP,%a2		|キュー１の初期化
	move.l	%a2,IN
	move.l	%a2,OUT
	move.l	#0x00,S
	add	#0x10c,%a2	|キュー２の初期化
	move.l	%a2,IN1
	move.l	%a2,OUT1
	move.l	#0x00,S1
	rts

********************
** InQ キューへのデータ書き込み
** a0:書き込むデータのアドレス
** d0:結果(00:失敗, 01:成功)
***********************************
INQ:
	jsr	PUT_BUF		| キューへの書き込み
	rts

***************************************
** PUT_BUF
** d0:成功失敗の出力、キュー番号の入力
** d1:書き込むバイトデータを格納
****************************************
PUT_BUF:
	movem.l	%a1-%a5/%d2-%d5,-(%sp)	| レジスタ退避 
	move	%SR,-(%sp)

	move.w	#0x2700,%SR		| 割り込みの禁止 
	move.l  %d0,%d5			| d0のコピー
	mulu	#0x010c, %d5		| オフセットの計算
	lea.l   S,%a4
	move.b  #0x00,%d0		| 出力を０（失敗に）する
	cmp.l   #0x0100, (%d5,%a4)	| キューが一杯なら終了
	beq	PUT_BUF_Finish
	lea.l   IN,%a5
	movea.l (%d5,%a5),%a1		| INのアドレスをa1に転送 
	move.b  %d1,(%a1)+		| d1をa1に転送して、アドレスを１バイト分ずらす 
	lea.l   BOTTOM,%a3		| キューの末尾のアドレスをa3に転送 
	add	%d5,%a3
	cmpa.l  %a3,%a1  		| INが末尾を超えていたら先頭に戻す 
	bls	PUT_BUF_STEP1
	lea.l   TOP,%a2
	add	%d5,%a2
	movea.l %a2,%a1

PUT_BUF_STEP1:
	move.l  %a1,(%d5,%a5)		| １バイト分ずらしたアドレスをINに転送 

PUT_BUF_STEP2:
	move.b	#0x01,%d0		| 出力を01(成功)にする 
	addq.l	#1,(%d5,%a4)

PUT_BUF_Finish:
	move	(%sp)+,%SR		| 走行レベルの回復
 	movem.l (%sp)+,%a1-%a5/%d2-%d5	| レジスタの回復 
	rts

***********************************
** OUTQ キューへのデータ書き込み
***********************************
OUTQ:
	jsr	GET_BUF			| キューへの書き込み 
	rts

***************************************
** GET_BUF
** 機能：番号noのキューからデータを一つ取り出す
** 入力：キュー番号no →  %D0.L
** 出力：失敗0/成功1 →  %D0.L, 取り出した8bitデータ →  %D1.B
** d0:成功失敗の出力、キュー番号の入力
** d1:読み出したデータの格納場所
****************************************
GET_BUF:
	movem.l	%a1-%a5/%d2-%d5,-(%sp)	| レジスタ退避 
	move	%SR,-(%sp)		| 現走行レベルの退避 

 	move.w  #0x2700,%SR		| 割り込みの禁止 
	move.l  %d0,%d5			| d0のコピー
	mulu	#0x010c, %d5		| オフセットの計算
	lea.l   S,%a4			| a4にSの先頭アドレスを入れる（Sはキュー内のデータ数） 
	move.b  #0x00,%d0		| 出力を０（失敗）にする
	cmp.l   #0x000, (%d5,%a4)	| キューが空なら終了
	beq	GET_BUF_Finish
	lea.l   OUT,%a5
 	movea.l (%d5,%a5),%a1		| OUTのアドレスをa1に転送 
  	move.b  (%a1)+,%d1		| a1の値ををd1に転送して、アドレスを１バイト分ずらす 
   	lea.l   BOTTOM,%a3		| キューの末尾のアドレスをa3に転送 
   	add	%d5,%a3
   	cmpa.l  %a3,%a1			| OUTが末尾を超えていたら先頭に戻す 
  	bls	GET_BUF_STEP1
   	lea.l   TOP,%a2
   	add	%d5,%a2
   	movea.l %a2,%a1

GET_BUF_STEP1:
   	move.l  %a1,(%d5,%a5) 		|１バイト分ずらしたアドレスをOUTに転送 

GET_BUF_STEP2:
   	move.b	#0x01,%d0		|出力を１（成功）にする
   	subq.l	#1,(%d5,%a4)

GET_BUF_Finish:
   	move	(%sp)+,%SR		| 走行レベルの回復
	movem.l (%sp)+,%a1-%a5/%d2-%d5 	| レジスタの回復 
	rts

***************************************************************
INTERPUT:
	move.w	#0x2700,%SR		| 割り込みの禁止 
	cmp.l	#0x00,%d1
	bne	INTERPUT_FINISH
	move.l	#1,%d0
	jsr	OUTQ
	cmp	#0x00,%d0
	beq	INTERPUT_MASK
	add	#0x0800, %d1  		| 代入処理 
	move.w	%d1, UTX1		|ヘッダ付与したd1をUTX1に代入
	bra	INTERPUT_FINISH
INTERPUT_MASK:
	move.w	#0xE108, USTCNT1  	| マスク処理 

INTERPUT_FINISH:
	rts

*************************************************************
**INTERGET
**チャネルch→%d1.L
**受信データdata→%d2.B
*************************************************************
INTERGET:
	movem.l %d0-%d1,-(%sp)  	| レジスタ退避   d2の退避を消した  
	cmp.l   #0,%d1          	| チャネルの判定
	bne     INTERGET_FIN
	
	move.b	(%a6),%d1		| 指定文字列を格納

	cmp.b   %d1,%d2			| 受信したデータが指定文字列と一致しなければ終了
	bne	INTERGET_FIN	
	
	move.l  #0,%d0          	| キューの選択
	move.b  %d2,%d1         
        jsr     INQ
	add	#1,%a6          	| 文字列参照を1バイトずらす
	addi.l	#1,COUNTER  		| 入力できた文字数カウント
        
INTERGET_FIN:
	movem.l (%sp)+,%d0-%d1  	| レジスタ回復
	rts



******************************************************
**PUTSTRING
**入力　チャンネルー＞d1
**　　　　データ読み込み先の先頭アドレス(p)ー＞d2
**　　　送信するデータサイズ(size)ー＞d3
**出力　実際に送信したデータ数(sz)ー＞d0
**
******************************************************
PUTSTRING:
	movem.l	%a0/%d4,-(%sp)		| レジスタ退避
	cmp.l	#0x00,%d1		| CHが0か判別
        bne	PUTST_FIN2
	move.l	#0x00,%d4		| d0(sz)=0
	movea.l	%d2, %a0		| a0＝p
	cmp	#0x00,%d3 		| size=0なら終了
	beq	PUTST_FIN1	
PUTLOOP1:
	cmp.l	%d4,%d3			| sz=sizeなら終了
	beq	PUT_UNMASK
        move.l	#0x01,%d0		| INQの引数の設定
        move.b	(%a0),%d1 
	jsr	INQ
	cmp	#0x00,%d0		| 復帰値が0ならマスク処理
	beq	PUT_UNMASK
	add	#0x01,%d4		| sz++
	add	#0x01,%a0		| i++
	bra	PUTLOOP1
PUT_UNMASK:
	move.w	#0xE10E,USTCNT1
PUTST_FIN1:
	move.l	%d4,%d0 		| d0=sz
PUTST_FIN2:
	movem.l	(%sp)+,%a0/%d4
        rts

****************************************************
**GETSTRING
**チャネルch→%d1.L
**データ書き込み先の先頭アドレス→%d2.L
**取り出すデータ数 size→%d3.L
**(戻り値)実際に取り出したデータ数sz→%d0.L
****************************************************
GETSTRING:
	movem.l	%a0/%d4,-(%sp)		| レジスタ退避
	cmp.l	#0,%d1 			| チャネルの判定
	bne	GETST_FIN2

	move.l	#0,%d4		 	| sz=0
	movea.l	%d2,%a0            	| %a0に書き込み先の先頭アドレスを代入
GETST_LOOP:
	cmp.l	%d4,%d3            	| if sz=size →　FIN
	beq	GETST_FIN1

	move.l	#0,%d0             	| 受信キューを選択
	jsr	OUTQ
	cmp.l	#0,%d0     		| OUTQ失敗ならFIN
	beq	GETST_FIN1

	move.b	%d1,(%a0)		| i番地にデータのコピー
	add	#1,%d4   		| sz++
	add	#1,%a0   		| i++
	bra	GETST_LOOP
GETST_FIN1:
	move.l	%d4,%d0           	| sz→%d0
GETST_FIN2:

	movem.l	(%sp)+,%a0/%d4		| レジスタ回復

	rts


******************************************************************
**タイマサブルーチン
******************************************************************
RESET_TIMER:
	move.w #0x0004, TCTL1	| restart, 割り込み不可
				| システムクロックの 1/16 を単位として計時
				| タイマ使用停止
	rts

***************
SET_TIMER:
	move.l %d2, task_p 	| 割り込み時に起動するルーチン先頭アドレスpを%d2.lに格納
				| 大域変数task_pに代入する
	move.w #0x00ce, TPRER1	| TPRER1 を設定し, 0.1 msec 進むとカウンタが1増えるようにする
				| 資料20ページから206(CE)で割る*/
	move.w %d1, TCMP1 	| タイマ割り込み発生周期tを,TCMP1に代入する.
	move.w #0x0015, TCTL1 	| restart, 割り込み許可*/
				| システムクロックの 1/16 を単位として計時
				| タイマ使用許可*/
	rts
***************
CALL_RP:
	move.l	(task_p),%a0	| 一時レジスタa0にtask_pが指すアドレスを格納
	jsr (%a0) 		| 大域変数 task_p の指すアドレスへジャンプする
	rts







******************************************************************
**MAIN関数
******************************************************************
.section .text
.even
MAIN:
** 走行モードとレベルの設定(「ユーザモード」への移行処理)
	move.w	#0x0000, %SR		| ユーザーモード, レベル 0
	lea.l	USR_STK_TOP,%SP		| ユーザースタックの設定

** システムコールによるRESET_TIMERの起動
	move.l	#SYSCALL_NUM_RESET_TIMER,%D0
	trap	#0
** システムコールによるSET_TIMERの起動
	move.l	#SYSCALL_NUM_SET_TIMER, %D0
	move.w  #2000, %D1
	move.l	#TT,    %D2
	trap	#0

******************************
** sys_GETSTRING, sys_PUTSTRINGのテスト
** ターミナルの入力をエコーバックする
******************************
LOOP:
	move.l	#SYSCALL_NUM_GETSTRING, %D0
	move.l	#0,   %D1        	| ch    = 0
	move.l	#BUF, %D2        	| p    = #BUF
	move.l	#256, %D3        	| size = 256
	trap	#0

	move.l	%D0, %D3        	| size = %D0 (length of given string)
	move.l	#SYSCALL_NUM_PUTSTRING, %D0
	move.l	#0,  %D1         	| ch = 0
	move.l	#BUF,%D2         	| p  = #BUF
	trap	#0

	bra	LOOP


**********************************************************
**　タイプ練習処理ルーチン
**　ユーザーは表示された文字と同じ文字列を制限時間以内に打ち込み、成功及び失敗した文字列の個数を出力する。違う文字を入力した際はその文字は出力されない。また制限時間は文字列の長さによって違う。
**　COUNTER:　入力できた文字数のカウント
**　LEN_STR:　　表示する文字列のながさ
**　TTC_BRA:　　TTCカウンタの値によって表示する文字列を変更する。
** RWD1~RWD5: 表示文字列の長さ、表示時間などの初期化
**　TTCPLUS:　　PUTSTRINGの実行、TTCカウンタの更新
*********************************************************
TT:
	movem.l	%D0-%D7/%A0-%A5,-(%SP)	
	cmpi.l	#0, LEN_STR     	| スタートはじめはスルー
	beq	TTC_BRA
	lea.l	COUNTER,%a4
	lea.l	LEN_STR,%a5
	move.l	(%a4),%d4
	move.l	(%a5),%d5
	cmp.l	%d4,%d5         	| LEN_STR - COUNTER
	beq     CORRECT_PLUS		| 最後まで入力できたら成功
	bra	MISS_PLUS            	| 入力が間に合わなければ失敗
TTC_BRA:
	cmpi.w	#9,TTC            	| TTCカウンタで9回実行したかどうか数える
	beq	TTKILL               	| 9回実行したら，タイマを止める
	move.l  #0, COUNTER          	| カウンターの初期化
	move.l	#SYSCALL_NUM_PUTSTRING,%D0
	move.l	#0,    %D1        	| ch = 0
	cmpi.w	#0,TTC                  | TTC == 0 ⇒ 1行目の文字列表示
	beq	RWD1
	cmpi.w	#1,TTC
	beq	RWD2
	cmpi.w	#2,TTC
	beq	RWD3
	cmpi.w	#3,TTC
	beq	RWD4
	cmpi.w	#4,TTC
	beq	RWD5
	cmpi.w	#5,TTC
	beq	CORRECT_OUT      	 | correct:　の表示ルーチンに移動
	cmpi.w	#6,TTC
	beq	CORRECT_NUM      	 | CORRECTの数値の表示ルーチンに移動
	cmpi.w	#7,TTC
	beq	MISS_OUT            	 | miss:　の表示ルーチンに移動
	cmpi.w	#8,TTC
	beq	MISS_NUM           	 | MISSの数値の表示ルーチンに移動

RWD1:
	move.l	#WD1, %D2        	 | p  = #WD1
	move.l	#WD1, %a6
	move.l	#0x11,   %D3        	 | size = 17
	move.l  #13, LEN_STR
	move.w  #50000, TCMP1 
	bra	TTCPLUS
RWD2:
	move.l	#WD2, %D2        	 | p  = #WD2
	move.l	#WD2, %a6 
	move.l	#0x1a,    %D3        	 | size = 26
	move.l  #22, LEN_STR
	move.w  #60000, TCMP1 
	bra	TTCPLUS
RWD3:
	move.l	#WD3, %D2        	 | p  = #WD3
	move.l	#WD3, %a6
	move.l	#0x09,    %D3        	 | size = 9
	move.l  #5, LEN_STR
	move.w  #30000, TCMP1 
	bra	TTCPLUS
RWD4:
	move.l	#WD4, %D2        	 | p  = #WD4
	move.l	#WD4, %a6
	move.l	#0x17, %D3        	 | size = 23
	move.l  #19, LEN_STR
	move.w  #45000, TCMP1 
	bra	TTCPLUS
RWD5:
	move.l	#WD5, %D2        	 | p  = #WD5
	move.l	#WD5, %a6
	move.l	#0x0f, %D3      	 | size = 15
	move.l  #11, LEN_STR
	move.w  #35000, TCMP1 
	bra	TTCPLUS

CORRECT_OUT:
	move.l	#COMMENT1, %D2  	 | p  = #COMMENT1
	move.l	#0x0c,    %D3            |size = 12
	move.w  #1000, TCMP1             |TCMP = 1000
	bra	TTCPLUS

MISS_OUT:
	move.l	#COMMENT2, %D2        	 | p  = #COMMENT2
	move.l	#0x0c, %D3 
	move.w  #1000, TCMP1        	
	bra	TTCPLUS

CORRECT_NUM:
	move.l	#CORRECT, %D2        	 | p  = #CORRECT_NUM
	move.l	#0x01,    %D3    
	move.w  #1000, TCMP1     
	bra	TTCPLUS


MISS_NUM:
	move.l	#MISS, %D2        	 | p  = #CORRECT
	move.l	#0x01,    %D3    
	move.w  #1000, TCMP1     
	bra	TTCPLUS

TTCPLUS:
	add	#2,%a6			 |\r\nを飛ばす
	trap	#0			 |PUTSTRING実行

	addi.w	#1,TTC            	 | TTCカウンタを1つ増やして
	bra	TTEND                	 |そのまま戻る

CORRECT_PLUS:
	addi.b	#1,CORRECT               | CORRCT += 1
	bra	TTC_BRA

MISS_PLUS:
	addi.b	#1,MISS                  | MISS+= 1
	bra	TTC_BRA


TTKILL:
	move.l	#SYSCALL_NUM_RESET_TIMER,%D0
	trap	#0

TTEND:
	movem.l	(%SP)+,%D0-%D7/%A0-%A5
	rts

****************************************************************
**初期値のあるデータ領域
****************************************************************
.section .data
TMSG:
	.ascii	"******\r\n"      	 | \r:行頭へ(キャリッジリターン)
	.even	                  	 | \n:次の行へ(ラインフィード)
TTC:
	.dc.w	0
	.even
COUNTER:  				 |文字数カウント
	.dc.l   0
	.even
LEN_STR:  				 |文字数格納
	.dc.l   0
	.even
CORRECT:				 |正解数
	.dc.b	48
	.even
MISS:					 |誤り数
	.dc.b   45
	.even
WD1:
	.ascii	"\r\nkyushudaigaku\r\n"  		| 九州大学
	.even    
WD2:
	.ascii	"\r\ndennkijyouhoukougakuka\r\n"	| 電気情報工学科
	.even      	
WD3:
	.ascii	"\r\nhyodo\r\n"				| 兵頭
	.even      	
WD4:
	.ascii	"\r\neko-baggupuroguramu\r\n"  		| エコーバッグプログラム
	.even    	
WD5:
	.ascii	"\r\nfukuokakenn\r\n"  			| 福岡県
	.even    		 	

COMMENT1: .ascii "\r\n correct: "
	  .even
COMMENT2: .ascii "\r\n    miss: "
	  .even
****************************************************************
**初期値の無いデータ領域
****************************************************************
.section .bss
BUF:
	.ds.b	256           		| BUF[256]
	.even

USR_STK:
	.ds.b	0x4000            	|ユーザスタック領域
	.even
USR_STK_TOP:			      	|ユーザスタック領域の最後尾





