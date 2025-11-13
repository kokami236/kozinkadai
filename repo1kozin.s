***************************************************************
**各種レジスタ定義
***************************************************************
***************
**レジスタ群の先頭
***************
.equ REGBASE,   0xFFF000	 
.equ IOBASE,    0x00d00000
***************
**割り込み関係のレジスタ
***************
.equ IVR,       REGBASE+0x300     
.equ IMR,       REGBASE+0x304     
.equ ISR,       REGBASE+0x30c     
.equ IPR,       REGBASE+0x310    
***************
**タイマ関係のレジスタ
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
.equ LED6,      IOBASE+0x000002d  |使用法については付録
.equ LED5,      IOBASE+0x000002b
.equ LED4,      IOBASE+0x0000029
.equ LED3,      IOBASE+0x000003f
.equ LED2,      IOBASE+0x000003d
.equ LED1,      IOBASE+0x000003b
.equ LED0,      IOBASE+0x0000039

*************************
**システムコール番号
*************************
.equ SYSCALL_NUM_GETSTRING,	1
.equ SYSCALL_NUM_PUTSTRING, 	2
.equ SYSCALL_NUM_RESET_TIMER, 	3
.equ SYSCALL_NUM_SET_TIMER, 	4
.equ SYSCALL_NUM_READ_TIMER, 	5
    
***************************************************************
**スタック領域の確保
***************************************************************
.section .bss
.even
SYS_STK:
	.ds.b   0x4000  	|システムスタック領域定義|
	.even
SYS_STK_TOP:	                |システムスタック領域の最後尾|

task_p:
    	.ds.l 1

BUF:
	.ds.b 256    	|受信キューと送信キューのバッファ|
	.even

USR_STK:
	.ds.b 0x4000
	.even
USR_STK_TOP:
    
***************************************************************
**初期化
**内部デバイスレジスタには特定の値が設定されている．
**その理由を知るには，付録Bにある各レジスタの仕様を参照すること．
***************************************************************
.section .text
.even
boot:
	**スーパーバイザ&各種設定のときの割込禁止
	move.w #0x2700,%SR
	lea.l  SYS_STK_TOP, %SP | Set SSP
 **割り込みコントローラの初期化
	move.b #0x40, IVR       |ユーザ割り込みベクタ番号を0x40+levelに設定|
	move.l #0x00ffffff, IMR |全割り込みマスク|
 **送受信(UART1)関係の初期化(割り込みレベルは4に固定されている)
	move.w #0x0000, USTCNT1 |リセット
	move.w #0xE10C, USTCNT1 |送受信可能,パリティなし, 1 stop, 8 bit,送受信割り込み禁止|
	move.w #0x0038, UBAUD1  | baud rate = 230400 bps
 **割り込み処理ルーチンの初期化
	move.l #interrupt, 0x110 /* level 4, (64+4)*4 */
	move.l #compare_interrupt, 0x118 /* level 6, (64+6)*4 */
	move.l #SYSTEM_CALL, 0x080
 **タイマ関係の初期化(割り込みレベルは6に固定)
	move.w #0x0004, TCTL1   | restart,割り込み不可,システムクロックの1/16が単位，タイマ使用停止|

 ****************
 **キューの初期化
 *****************
	jsr	Init_Q
	move.l  #0x00FF3FF9, IMR |送受信(UART1)とタイマのマスク解除|
	bra	MAIN

***************************************************************
**MAINルーチン
***************************************************************
.section .text
.even
MAIN:

	move.b	#' ', LED0
	move.b	#' ', LED1
	move.b	#' ', LED2
	move.b	#' ', LED3
	move.b	#' ', LED4
	move.b	#' ', LED5
	move.b	#' ', LED6
	move.b	#' ', LED7

	move.w	#0x0000, %SR			|ユーザモード, レベル0
	lea.l  	USR_STK_TOP, %SP		|ユーザスタック

	move.l 	#SYSCALL_NUM_RESET_TIMER, %D0
	trap    #0				|RESET_TIMER

**repo1kozin関係の初期化
	move.w	#0, score		|スコアカウンタのリセット|
	move.l	#0, %d4			|入力文字数カウンタのリセット|
	move.w	#0x0000, timeover_flg	|タイムオーバフラグのリセット|
	move.l	#0, %a0			|問題アドレスのリセット|
	move.l	#0, %a1			|問題サイズアドレスのリセット|

	lea.l	QUEST1, %a0		|a0 = QUEST1|
	move.l	%a0, %a2		|a2 = QUEST1|
	lea.l	quest_size, %a1		|a1 = 問題1size-adress|
LOOP1:	|問題表示|
	move.l 	#6, %d3		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0     |P
	move.l 	#0, %d1	 		|ch
	move.l 	#RETURN_Q, %d2	   		|p
	trap 	#0				|"\n\n\rQ: "の表示|

	move.b 	(%a1), %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	%a0, %d2	   		|p
	trap 	#0				|問題表示|

	move.l 	#5, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#RETURN_IN, %d2	   		|p
	trap 	#0				|"\n\r>> "の表示|


	move.b	(%a1), %d1
	mulu	#5000, %d1			|制限時間は文字数の0.5倍秒|

	move.l 	#SYSCALL_NUM_SET_TIMER, %D0
	move.l 	#TT, %D2			|p
	trap    #0				|制限時間セット|
LOOP0:
	move.b	#'8', LED0
	move.b	#'1', LED0
	move.w	timeover_flg, %d0
	cmpi.w	#0xffff, %d0			|timeoverがあったかどうかの確認|
	beq	TIMEOVER			|時間切れ|

	move.l	#SYSCALL_NUM_GETSTRING, %d0
	move.l 	#0,   %d1			| ch = 0
	move.l 	#BUF, %d2 			| p = #BUF
	move.l 	#1, %d3				|size = 1
	trap	#0				|1文字だけ入力受付

	cmpi	#0, %d0				|szが0. つまり入力があったか|
	beq	LOOP0				|入力なし, 戻る|

	addi.w	#1, miss
	move.b	BUF, %d5
	cmp.b	(%a0), %d5			|入力BUFと問題Qの文字は同じか|
	bne	LOOP0				|入力ミス, 戻る|

	
	addi.w	#1, correct			|correct++|
	subi.w	#1, miss
	adda.l	#1, %a0				|次の文字|

	addi	#1, %d4				|カウンタ++

	move.b	%d4, LED1

	move.l 	%d0, %d3	 		| size = 1
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0,  %d1	 		| ch = 0
	move.l 	#BUF,%d2	 		| p = #BUF
	trap 	#0				|入力が正解だったので画面表示

	cmp.b	(%a1), %d4			|最後の文字か
	beq	CLEAR				|!! 1問クリア !!|

	bra 	LOOP0				|入力途中, 戻る|

CLEAR:		|1問クリア処理|
	addi.w	#1, score  |クリア問題数をカウントアップ|

	move.l 	#SYSCALL_NUM_READ_TIMER, %d0
	trap	#0				|タイマ読み|

	divu	#1000, %d0			|1000で割る|
	and.l	#0x0000ffff, %d0

	add.w	%d0, all_time			|合計所要時間に加算

	move.b	%d0, LED7

	bra 	NEXT_Quest

TIMEOVER:	|時間切れ|
	move.w	#0x0000, timeover_flg		|タイムオーバフラグ→リセット|

	move.b	(%a1), %d0			|当該問題の文字数
	mulu	#5000, %d0			|制限時間は文字数の0.5倍秒
	and.l	#0x0000ffff, %d0
	divu	#1000, %d0			|1000で割る|
	and.l	#0x0000ffff, %d0

	add.w	%d0, all_time			|合計所要時間に加算
	move.b	%d0, LED7

	bra 	NEXT_Quest

NEXT_Quest:	|次の問題への準備|
	move.l 	#SYSCALL_NUM_RESET_TIMER, %d0
	trap 	#0				|タイマストップ|

	move.l	#0, %d4				|入力文字数カウンタのリセット|

	addi.w	#1, Q_no			|Q_no++, 出題済み問題数|

	cmp.w	#ALL_Q, Q_no
	beq	FINISH

	adda.l	#1, %a1				|次の問題サイズのアドレス|
	adda.l	#16, %a2			|次の問題アドレス|
	movea.l	%a2, %a0			|次の問題アドレスコピー保存用へ|
	bra 	LOOP1

FINISH:
	move.l 	#N_MS1, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS1, %d2	   		|p
	trap 	#0				|MS1"\n\n\r-----Finish!-----\n\rcorrect: "の表示|

	lea.l	score, %a6
	jsr	DISPLAY_D_ASKII			|scoreの表示|
	move.l 	#N_MS2, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS2, %d2	   		|p
	trap 	#0				|MS2"/"の表示|

	lea.l	Q_no, %a6
	jsr	DISPLAY_D_ASKII			|すべての問題数の表示|


	move.l 	#N_MS3, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS3, %d2	   		|p
	trap 	#0				|MS3"\n\rcorrect types: "の表示|

	lea.l	correct, %a6
	jsr	DISPLAY_D_ASKII			|correctの表示|

	move.l 	#N_MS4, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS4, %d2	   		|p
	trap 	#0				|MS4"\n\rmiss types: "の表示|

	lea.l	miss, %a6
	jsr	DISPLAY_D_ASKII			|missの表示|

	move.l 	#N_MS5, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS5, %d2	   		|p
	trap 	#0				|MS5"\n\rtypes per sec: "の表示|
	
	**打/秒の計算
	move.w	correct, %d0		        |correctは正解打数|
	mulu	#10, %d0			|割る数が0.1sec単位なので正解打数を10倍|
	move.w	all_time, %d1			|all_timeまでに過ぎた時間|
	andi.l	#0x0000ffff, %d1		|念の為マスク|
	divu	%d1, %d0			|正解打数÷経過時間|
	move.l	%d0, %d2			|結果のコピー|
	addi.l	#0x30, %d2
	move.b	%d2, FLOAT_DISPLAY1

	LSR.l	#8, %d0			
	LSR.l	#8, %d0				
	mulu	#10, %d0			|余りを10倍|
	andi.l	#0x0000ffff, %d0
	divu	%d1, %d0			|余り÷正解打数|
	addi.l	#0x30, %d0			|askii変換|
	move.b	%d0, FLOAT_DISPLAY01		|.w商のみを格納→少数第1位で1桁|
	move.l 	#1, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#FLOAT_DISPLAY1, %d2	   	|p
	trap 	#0				|打/分の少数部分の表示|

	move.l 	#N_MS6, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS6, %d2	   		|p
	trap 	#0				|MS6"."の表示|

	move.l 	#1, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#FLOAT_DISPLAY01, %d2	   	|p
	trap 	#0				|打/分の少数部分の表示|


	move.l 	#N_MS7, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#MS7, %d2	   		|p
	trap 	#0				|MS7"\n\rtotal time(0.1s): "の表示|

	move.l	#all_time, %a6
	jsr	DISPLAY_D_ASKII
LOOP2:
	bra	LOOP2
	

***************************************
**タイマ作動時
**TT	
***************************************	
TT:
	movem.l %d0-%d7/%a0-%a6, -(%sp)

	move.w	#0xffff, timeover_flg		|タイムオーバフラグ→立てる|

	movem.l (%sp)+, %d0-%d7/%a0-%a6
	rts

***************************************
**2桁のみASKII表示用のサブルーチン(関数)
**入力:	2桁の数字のアドレス.w → %a6
**出力:	なし
***************************************	
DISPLAY_D2_ASKII:

	movem.l %d0-%d7/%a0-%a6, -(%sp)

	move.w	(%a6), %d0			|a6は入力, 対象のアドレス|
	divu.w	#10, %d0			|10で割る|
	andi.l	#0x0000000f, %d0		|マスクして商のみにする→10の位|
	addi.l	#0x30, %d0			|ASKII用の0x30を足す|
	move.b	%d0, ASKII_DISPLAY10		|左ビットに格納|
	
	move.w	(%a6), %d1			|a6は入力, 対象のアドレス|
	divu.w	#10, %d1			|10で割る|
	andi.l	#0x000f0000, %d1		|マスクしてあまりのみにする→1の位|
	LSR.l	#8, %d1				|4桁右シフト|
	LSR.l	#8, %d1
	addi.l	#0x30, %d1			|ASKII用の0x30を足す|
	move.b	%d1, ASKII_DISPLAY1		|右ビットに格納|

	move.l 	#2, %d3	 			|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 			|ch
	move.l 	#ASKII_DISPLAY10, %d2	   	|p
	trap 	#0				|表示|

	movem.l (%sp)+, %d0-%d7/%a0-%a6

	rts
***************************************
**任意の桁の数字をASKII表示するサブルーチン(関数)
**入力:	数字のアドレス.w → %a6
**出力:	なし
***************************************	
DISPLAY_D_ASKII:

	movem.l %d0-%d7/%a0-%a6, -(%sp)

	lea.l	ASKII_DISPLAY1, %a0
	move.w	(%a6), %d0			|a6は入力, 対象のアドレス|
	move.l	#0, %d3

DISPLAY_D_ASKII_LOOP:
	divu	#10, %d0			|10で割る|
	
	move.l	%d0, %d1			|余りを取り出すようにコピー|
	LSR.l	#8, %d1				|4桁右シフト|
	LSR.l	#8, %d1
	addi	#0x30, %d1			|ASKII用|
	move.b	%d1, (%a0)			|あまりを1の位メモリに格納|
	suba.l	#1, %a0				|書き込み先アドレスを1つ退行|
	
	andi.l	#0x0000ffff, %d0		|マスクして商のみにする|

	addi.l	#1, %d3				|桁数のカウント|

	cmp	#0, %d0				|商=0なので数字の処理終わり|
	bne	DISPLAY_D_ASKII_LOOP

	adda.l	#1, %a0				|無駄に退行した分を戻す|

**      move.l 	#1, %d3	 			|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 			|ch
	move.l 	%a0, %d2		   	|p
	trap 	#0				|表示|

	move.b	#0, ASKII_DISPLAY1
	move.b	#0, ASKII_DISPLAY10
	move.b	#0, ASKII_DISPLAY100
	move.b	#0, ASKII_DISPLAY1000

	movem.l (%sp)+, %d0-%d7/%a0-%a6

	rts

***************************************
**メモリ表示用のサブルーチン(関数)
**入力:	アドレスの先頭 → %a6, メモリ数 → %d0
**出力:	なし
***************************************	

**デバッグ用の関数

DISPLAY_H_MEMORY:
	movem.l %d0-%d7/%a0-%a6, -(%sp)

	move.l	%d0, %d4

DISPLAY_H_MEMORY_LOOP:

	move.b	(%a6), %d1			|a6は入力, 対象のアドレス|
	divu.w	#16, %d1			|16で割る|
	addi.l	#0x00300030, %d1		|ASKII用の0x30を足す|
	move.b	%d1, ASKII_DISPLAY10		|左ビットに格納|

	LSR.l	#8, %d1				|4桁右シフト|
	LSR.l	#8, %d1
	move.b	%d1, ASKII_DISPLAY1		|右ビットに格納|

	move.l 	#2, %d3	 		|size		
	move.l 	#SYSCALL_NUM_PUTSTRING, %D0
	move.l 	#0, %d1	 		|ch
	move.l 	#ASKII_DISPLAY10, %d2	   	|p
	trap 	#0				|表示|

	subi.l	#1, %d4
	adda.l	#1, %a6
	
	cmpi.l	#0, %d4
	bne	DISPLAY_H_MEMORY_LOOP

	movem.l (%sp)+, %d0-%d7/%a0-%a6

	move.b	#'M', LED5
	rts

*****************************
**タイプ用文字列↓↓
*****************************
.section .data
.even

	.equ	ALL_Q, 7


timeover_flg:	.ds.w	1
score:		.ds.w	1
Q_no:		.ds.w	1
miss:	        .ds.w	1
correct:	.ds.w	1
all_time:	.ds.w	1

RETURN_Q:
	.ascii "\n\n\rQ: "			
	.even	

RETURN_IN:
	.ascii "\n\r>> "			
	.even		
***************************
**問題を追加するとき！
	**以下にコピペで追加し，全問題数ALL_Qと配列quest_sizeを更新する。最大13文字
*************************
QUEST1:
	.ascii "kokami"
	.ds.b	16-6		
QUEST2:	|1234567890123456
	.ascii "tarou"			
	.ds.b	16-5
QUEST3:	|1234567890123456
	.ascii "shunta"			
	.ds.b	16-6	
QUEST4:	|1234567890123456
	.ascii "denjo"			
	.ds.b	16-5	
QUEST5:	|1234567890123456
	.ascii "kougakuka"			
	.ds.b	16-9	
QUEST6:	|1234567890123456
	.ascii "good"			
	.ds.b	16-4
QUEST7:	|1234567890123456
	.ascii "softzikken"			
	.ds.b	16-10
	
quest_size:			
	.dc.b	6
	.dc.b	5
	.dc.b	6
	.dc.b	5
	.dc.b	9
	.dc.b	4
	.dc.b	10
	.even

MS1:	   |123456789012345678901234567890
	.ascii "\n\n\r-----OTUKARE!-----\n\rclear: "
	.even	

	.equ	N_MS1, 29

MS2:	   |123456789012345678901234567890
	.ascii "/"
	.even	

	.equ	N_MS2, 1

MS3:	   |123456789012345678901234567890
	.ascii "\n\rcorrect      : "
	.even	

	.equ	N_MS3, 17

MS4:	   |123456789012345678901234567890
	.ascii "\n\rmiss      : "
	.even	

	.equ	N_MS4, 14

MS5:	   |123456789012345678901234567890
	.ascii "\n\rtypes per sec: "
	.even	

	.equ	N_MS5, 17

MS6:	   |123456789012345678901234567890
	.ascii "."
	.even	

	.equ	N_MS6, 1

MS7:	   |123456789012345678901234567890
	.ascii "\n\rtotal time(0.1second): "
	.even	

	.equ	N_MS7, 24

ASKII_DISPLAY1000:
	.ds.b	1
ASKII_DISPLAY100:
	.ds.b	1
ASKII_DISPLAY10:
	.ds.b	1
ASKII_DISPLAY1:
	.ds.b	1

FLOAT_DISPLAY1:
	.ds.b	1
FLOAT_DISPLAY01:
	.ds.b	1
	.even
****************************
**以下OSの必要な部分、改良版
****************************

.section .text
.even
***********
**READ_TIMER
**入力: なし
**出力: d0
***********
READ_TIMER:
	move.w	TCN1, %d0	|タイマカウンタの値を取得
	rts

***********
**RESET_TIMER
***********
RESET_TIMER:
	move.w #0x0004, TCTL1 	|TCTL1を設定|
	rts
SET_TIMER:
	move.l	%d2, task_p 	|task_p <- %d2|
	move.w 	#206, TPRER1 	|TPRER1 <- #206|
	move.w 	%d1, TCMP1 	|TCMP1 <- %d1|
	move.w 	#0x0015, TCTL1 	|TCTL1を割り込み許可|
	rts

***********
**CALL_RP
***********
CALL_RP:
	movem.l %a0, -(%sp)
	movea.l task_p, %a0 	|%a0 <- task_p|
	jsr 	(%a0) 		|task_pが示す番地へジャンプ|
	movem.l (%sp)+, %a0 
	rts

***********
**compare_interrupt
***********

compare_interrupt:
	movem.l	%d0, -(%sp)
	move.w 	TSTAT1, %d0		| %d0 <- TSTAT1|
	andi.l  #0x00000001, %d0 	| TSTAT1の第0ビットが1かどうか|
	cmp.l	#0x00000001, %d0
	beq	compare_interrupt_step1 |1なら次のステップへ|
	movem.l	(%sp)+, %d0
	rte
    
compare_interrupt_step1:
	move.w 	#0x0000, TSTAT1 	|TSTAT1を0クリア|
	jsr 	CALL_RP
	movem.l (%sp)+, %d0
	rte


**************************************
**SYSTEM_CALL
**GETSTRING   = 1
**PUTSTRING   = 2
**RESET_TIMER = 3
**SET_TIMER   = 4
**READ_TIMER  = 5
**************************************

SYSTEM_CALL:
	movem.l	%a0, -(%sp)

	cmpi.l 	#1, %d0			|システムコール番号による分岐|
	beq 	SYSTEM_CALL_STEP1
	cmpi.l 	#2, %d0
	beq 	SYSTEM_CALL_STEP2
	cmpi.l 	#3, %d0
	beq 	SYSTEM_CALL_STEP3
	cmpi.l 	#4, %d0
	beq 	SYSTEM_CALL_STEP4
	cmpi.l 	#5, %d0
	beq 	SYSTEM_CALL_STEP5

SYSTEM_CALL_STEP1:			|各関数へジャンプ|
	lea.l 	GETSTRING, %a0
	move.l 	%a0, %d0
	bra 	SYSTEM_CALL_JUMP
SYSTEM_CALL_STEP2:
	lea.l 	PUTSTRING, %a0
	move.l 	%a0, %d0
	bra 	SYSTEM_CALL_JUMP
SYSTEM_CALL_STEP3:
	lea.l 	RESET_TIMER, %a0
	move.l 	%a0, %d0
	bra 	SYSTEM_CALL_JUMP
SYSTEM_CALL_STEP4:
	lea.l 	SET_TIMER, %a0
	move.l 	%a0, %d0
	bra 	SYSTEM_CALL_JUMP
SYSTEM_CALL_STEP5:
	lea.l 	READ_TIMER, %a0
	move.l 	%a0, %d0
	bra 	SYSTEM_CALL_JUMP

SYSTEM_CALL_JUMP:			|終了点return|
	jsr	(%a0) 
	movem.l	(%sp)+, %a0
	rte


**********************************************************
**送信割り込み用インターフェース
**interruptを作る
**********************************************************
interrupt: 
	movem.l	%D0-%D7/%A0-%A6,-(%SP) 	|使用するレジスタをスタックに保存|
	move.w 	UTX1, %d0       	|d0にUTX1を入れる|
	and.l	#0x00008000, %d0	|UTX1の15ビット目を確認|
	cmp.l 	#0x00008000, %d0	|UTX1の15ビット目の比較|
	beq 	send_interrupt    	|UTX1の15ビット目1なら送信割り込みへ|
	bra 	next_branch_interrupt	/*送信割り込みではなかった
					ので受信の方を調べに行く*/

send_interrupt:
    	move.l	#0, %d1 		|d1(ch)に0を入れる|
    	jsr	INTERPUT      		|INTERPUTに飛ぶ|

next_branch_interrupt:
	move.w	URX1, %d3		|%d3 <- URX1|
	move.b	%d3, %d2		|%d2 <- %d3の下位8ビット|
	and.l	#0x00002000, %d3	|URX1の15ビット目を確認(マスク)|
	cmp.l 	#0x00002000, %d3	|URX1の15ビット目の比較|
	beq 	recv_interrupt    	|URX1の15ビット目1なら送信割り込みへ|
	bra 	end_interrupt		|受信割り込みではなかったので(そんなわけないが)終わり|

recv_interrupt:
    	move.l	#0, %d1 		/*d1(ch)に0を入れる, INTERGETの引数, 
					もう１つの引数はd2で上で代入済み*/
    	jsr	INTERGET      		|INTERGETに飛ぶ|

end_interrupt:
	movem.l	(%SP)+, %D0-%D7/%A0-%A6 |スタックからレジスタの値を復帰．|
	rte 				|割り込み処理終了|


**********************************************************
**INTERPUT(ch)
**入力: ch(チャネル->%d1.l), 出力: なし
**********************************************************
INTERPUT:
	movem.l	%D0-%D7/%A0-%A6,-(%SP)	|使用するレジスタをスタックに保存|
	move.w 	#0x2700, %SR    	|割り込み禁止|

    	cmp.l	#0, %d1	
    	bne	END_INTERPUT		|D1=0ならば終了|

    	move.l 	#1, %d0    		|OUTQの引数(no)…キューの番号|
    	jsr    	OUTQ       		|OUTQ(no=%d0=1, data=&d1)を実行|

    	cmp.l 	#0, %d0 |OUTQの失敗確認|
    	beq  	MASK_INTERPUT    |失敗時送信割り込みをマスク(禁止)|
    
    	and.l 	#0x000000ff, %d1	|d1の上位24bitをマスク|
	add.w	#0x0800, %d1    	|上位８ビットを拡張！！！|
      	move.w 	%d1, UTX1		|送信レジスタに16bitを格納|
	bra	END_INTERPUT
    
MASK_INTERPUT:
	move.w	#0xE108, USTCNT1 	|送信割込不可,受信可能,パリティなし, 1 stop, 8 bit|


END_INTERPUT:
	movem.l	(%SP)+, %D0-%D7/%A0-%A6 /*スタックからレジスタの値を復帰．*/
	rts  


**********************************************************
**INTERGET(ch)抜粋
**入力: ch(チャネル->%d1.l), data(受信データ->%d2), 
**出力: なし
**********************************************************
INTERGET:
	movem.l	%D0-%D7/%A0-%A6,-(%SP)	|使用するレジスタをスタックに保存|

    	cmp.l	#0, %d1	
    	bne	END_INTERGET	|D1=0ならば終了|

    	move.l 	#0, %d0    	|INQの引数(no)…キューの番号|
	move.l	%d2, %d1	|INQの引数(data)…キューに入れるデータ|
    	jsr    	INQ       	|INQ(no=%d0=1, data=&d1)を実行|


END_INTERGET:
	movem.l	(%SP)+, %D0-%D7/%A0-%A6 /*スタックからレジスタの値を復帰．*/
	rts 
  

**********************************************************
**PUTSTRING抜粋
**入力: ch(チャネル->%d1), 
**	p(データ読み込み先の先頭アドレス->%d2), 
**      size(送信するデータ数->%d3)
**出力: sz(実際に送信したデータ数 -> %d0)
** %d4…	szの一時保存用, ループカウンタ
** %a0…	i, pの動的な番地p[i]
**********************************************************
PUTSTRING:
    	movem.l	%D1-%D7/%A0-%A6,-(%SP)	|使用するレジスタをスタックに保存|
    	cmp.l 	#0, %d1    		|ch ≠ 0ならば強制終了|
	bne   	END_PUTSTRING

   	move.l	#0, %d4    		|sz <- 0|
    	move.l 	%d2, %a0    		|i <- p|

    	cmp.l 	#0, %d3    		|size = 0ならばszを出力して強制終了|
    	beq  	REPORT_PUTSTRING

LOOP_PUTSTRING:
    	cmp.l	%d3, %d4    		|sz = sizeになればループ終了|
    	beq	UNMASK_PUTSTRING

    	move.l 	#1, %d0    		|キューの番号を送信キューのやつに指定|
    	move.b  (%a0), %d1    		|i番地のデータをINQの入力dataに入れる+|
    	jsr 	INQ

    	cmp.l 	#0, %d0    		|INQの結果が失敗0ならば強制終了|
    	beq	UNMASK_PUTSTRING

    	addq.l 	#1, %d4    		|sz++|
	addq.l 	#1, %a0    		|i++|
    	bra 	LOOP_PUTSTRING

UNMASK_PUTSTRING:
     	move.w	#0xE10C, USTCNT1     	|送受信可能,パリティなし, 1 stop, 8 bit|
    
REPORT_PUTSTRING:
	move.l	%d4,%d0			|d0 <- sz|
		
END_PUTSTRING:
    	movem.l	(%SP)+, %D1-%D7/%A0-%A6 |スタックからレジスタの値を復帰|
	rts


**********************************************************
**GETSTRINGの改良
**入力: ch(チャネル->%d1), 
**	p(データ読み込み先の先頭アドレス->%d2), 
**      size(送信するデータ数->%d3)
**出力: sz(実際に送信したデータ数 -> %d0)
**********************************************************
GETSTRING:
    	movem.l	%D1-%D7/%A0-%A6,-(%SP)	|使用するレジスタをスタックに保存|
    	cmp.l 	#0, %d1    		|ch ≠ 0ならば強制終了|
	bne   	END_GETSTRING

   	move.l	#0, %d4    		|sz <- 0|
    	move.l 	%d2, %a0    		|i <- p|

LOOP_GETSTRING:
    	cmp.l	%d3, %d4    		|sz = sizeになればループ終了|
    	beq	REPORT_GETSTRING

    	move.l 	#0, %d0    		|キューの番号を受信キューのやつに指定|
    	jsr 	OUTQ

    	cmp.l 	#0, %d0    		|OUTQの結果が失敗0ならば強制終了|
    	beq	REPORT_GETSTRING

	move.b  %d1, (%a0)+    		|キューから取り出したデータをメモリに保存 (i++)|

    	addq.l 	#1, %d4    		|sz++|
    	bra 	LOOP_GETSTRING
    
REPORT_GETSTRING:
	move.l	%d4,%d0			|d0 <- sz|
	
END_GETSTRING:
    	movem.l	(%SP)+, %D1-%D7/%A0-%A6 |スタックからレジスタの値を復帰|
	rts

********************** 
** キューの初期化処理
********************** 
Init_Q:
	movem.l	%d0/%a0-%a4, -(%sp)

	move.l	#2, %d0			|d0はループカウンタ|

	lea.l 	top, %a0
	lea.l	in, %a1
	lea.l	out, %a2
	lea.l	PUT_FLG, %a3
	lea.l	GET_FLG, %a4
	lea.l	s, %a5

Loop_Init:	
	move.l 	%a0, (%a1)+		|a0はtop, topのアドレスをin(putポインタ)へ代入|
	move.l 	%a0, (%a2)+		|topのアドレスをout(getポインタ)へ代入|
	move.b 	#0x01, (%a3)+		|01(フラグon)をputフラグへ代入|
	move.b 	#0x00, (%a4)+		|00(フラグoff)をgetフラグへ代入|
	move.b 	#0, (%a5)+

	adda.l	#B_SIZE, %a0		|topのアドレスを次のキュー領域へ更新|

	subq.l	#1, %d0
	bhi	Loop_Init

	movem.l	(%sp)+, %d0/%a0-%a4
	rts
*********************************** 
** INQ キューへのデータ書き込み
** a0: 書き込むデータのアドレス 
** (入力)d0: 書き込むキューの番号0~1		
** (出力)d0: 結果(00:失敗, 01:成功) 
***********************************
INQ:
	movem.l	%d1-%d6/%a0-%a6, -(%sp)		
	move.w	%SR, -(%sp)			|現走行レベルの退避|
	move.w	#0x2700, %SR			|割り込み禁止|
		
	move.l	%d0, %d3			|キュー番号の保存|

	lea.l	PUT_FLG, %a4			|a4はキュー番号0のPUT_FLGのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するPUT_FLGを選択|
	move.b	(%a4), PUT_FLG_ptr		|PUT_FLG_ptrはa4アドレスに格納している値|

	lea.l	GET_FLG, %a4			|a4はキュー番号0のGET_FLGのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するGET_FLGを選択|
	move.b	(%a4), GET_FLG_ptr		|GET_FLG_ptrはa4アドレスに格納している値|

	mulu	#4, %d0				|これ以降はサイズがbからlに変化しているため、d0=d0*4|
	lea.l	in, %a4				|a4はキュー番号0のinのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するinを選択|
	move.l	(%a4), in_ptr			|in_ptrはa4アドレスに格納している値|

	lea.l	out, %a4			|a4はキュー番号0のoutのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するoutを選択|
	move.l	(%a4), out_ptr			|out_ptrはa4アドレスに格納している値|

	lea.l	s, %a4				|a4はキュー番号0のsのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するsを選択|
	move.l	(%a4), s_ptr			|s_ptrはa4アドレスに格納している値|

	mulu	#64, %d0			|これ以降はサイズが256Bのため、d0=d0*64(上ですでに4倍しているため)|
	lea.l 	top, %a4			|a4はキュー番号0の先頭アドレス|
	add.l	%d0, %a4			|キュー番号0のとき、a4はtopのままであり、1のときa4はtopに256を加算した値|
	move.l	%a4, top_ptr			|top_ptrはa4アドレスの値|

	move.l	#256, %d2			|d2=256|
	sub.l	%d0, %d2			|キュー番号0のとき、d2=256-0=256。1のとき、d2=256-256=0|
	move.l	#0, %d0				|d0初期化|	
	lea.l	bottom, %a4			|a4はキュー番号1の最後尾のアドレス|
	sub.l	%d2, %a4			|キュー番号0のとき、a4はbottomから256を引き、1のときはa4はbottomのまま|
	move.l	%a4, bottom_ptr			|bottom_ptrはa4アドレスの値|

	jsr 	PUT_BUF 			|キューへの書き込み|

	lea.l	PUT_FLG, %a4			|a4はキュー番号0のPUT_FLGのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するPUT_FLGを選択|
	move.b 	PUT_FLG_ptr,(%a4)		|PUT_FLG_ptrを元のPUT_FLGに更新|

	lea.l	GET_FLG, %a4			|a4はキュー番号0のGET_FLGのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するGET_FLGを選択|
	move.b 	GET_FLG_ptr,(%a4)		|GET_FLG_ptrを元のGET_FLGに更新|

	mulu	#4, %d3
	lea.l 	in, %a4				|a4はキュー番号0のinのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するinを選択|
	move.l	in_ptr, (%a4)			|in_ptrを元のinに更新|

	lea.l	out, %a4			|a4はキュー番号0のoutのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するoutを選択|
	move.l	out_ptr, (%a4)			|out_ptrを元のoutに更新|

	lea.l	s, %a4				|a4はキュー番号0のsのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するsを選択|
	move.l	s_ptr, (%a4)			|s_ptrを元のsに更新|

	move.w	(%sp)+, %SR			|旧走行レベルの回復|
	movem.l	(%sp)+, %d1-%d6/%a0-%a6		
	rts
**************************************** 
** PUT_BUF
** a0: 書き込むデータのアドレス
** d0: 結果(00:失敗, 00以外:成功) 
** d1: 書き込む8bitデータ
**************************************** 
PUT_BUF:
	movem.l	%a1-%a3, -(%sp)
	move.b	PUT_FLG_ptr, %d0

	cmp.b	#0x00, %d0		| PUT不可能(失敗) |
	beq	PUT_BUF_Finish

	movea.l	in_ptr, %a1		| キューにデータを挿入 |
	move.b	%d1, (%a1)+

	addi.l	#1, s_ptr		| キュー内のデータ数:+1 |

	move.l	bottom_ptr, %a3		| a3はキュー末尾 |
	cmpa.l	%a3, %a1		| PUTポインタが末尾を超えた |
	bls	PUT_BUF_STEP1	

	move.l	top_ptr, %a2		| PUTポインタを先頭に戻す |
	movea.l	%a2, %a1

PUT_BUF_STEP1:
	move.l	%a1, in_ptr

	cmpa.l	out_ptr, %a1		| PUTポインタがGETポインタに追いついた |
	bne	PUT_BUF_STEP2

	move.b	#0x00, PUT_FLG_ptr	| 満タンなのでPUT不可能(フラグ) |

PUT_BUF_STEP2:
	move.b	#0x01, GET_FLG_ptr

PUT_BUF_Finish:
	movem.l	(%sp)+, %a1-%a3
	rts
*********************************** 
** OUTQ キューからの読み出し
** a2: 読み出し先アドレス
** d0(入力):キュー番号
** d0(出力): 結果(00:失敗, 01:成功) 
** d1: 取り出した8bitデータ
***********************************
OUTQ:
	movem.l	%d2-%d6/%a0-%a6, -(%sp)
	move.w	%SR, -(%sp)			|現走行レベルの退避|
	move.w	#0x2700, %SR			|割り込み禁止|

	move.l	%d0, %d3			|キュー番号の保存|

	lea.l	PUT_FLG, %a4			|a4はキュー番号0のPUT_FLGのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するPUT_FLGを選択|
	move.b	(%a4), PUT_FLG_ptr		|PUT_FLG_ptrはa4アドレスに格納している値|

	lea.l	GET_FLG, %a4			|a4はキュー番号0のGET_FLGのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するGET_FLGを選択|
	move.b	(%a4), GET_FLG_ptr		|GET_FLG_ptrはa4アドレスに格納している値|

	mulu	#4, %d0				|これ以降はサイズがbからlに変化しているため、d0=d0*4|
	lea.l	in, %a4				|a4はキュー番号0のinのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するinを選択|
	move.l	(%a4), in_ptr			|in_ptrはa4アドレスに格納している値|

	lea.l	out, %a4			|a4はキュー番号0のoutのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するoutを選択|
	move.l	(%a4), out_ptr			|out_ptrはa4アドレスに格納している値|

	lea.l	s, %a4				|a4はキュー番号0のsのアドレス|
	add.l	%d0, %a4			|選択したキューにより、使用するsを選択|
	move.l	(%a4), s_ptr			|s_ptrはa4アドレスに格納している値|

	mulu	#64, %d0			|これ以降はサイズが256Bのため、d0=d0*64(上ですでに4倍しているため)|
	lea.l 	top, %a4			|a4はキュー番号0の先頭アドレス|
	add.l	%d0, %a4			|キュー番号0のとき、a4はtopのままであり、1のときa4はtopに256を加算した値|
	move.l	%a4, top_ptr			|top_ptrはa4アドレスの値|

	move.l	#256, %d2			|d2=256|
	sub.l	%d0, %d2			|キュー番号0のとき、d2=256-0=256。1のとき、d2=256-256=0|
	move.l	#0, %d0				|d0初期化|	
	lea.l	bottom, %a4			|a4はキュー番号1の最後尾のアドレス|
	sub.l	%d2, %a4			|キュー番号0のとき、a4はbottomから256を引き、1のときはa4はbottomのまま|
	move.l	%a4, bottom_ptr			|bottom_ptrはa4アドレスの値|

	jsr 	GET_BUF 			|キューからの読み出し|

	lea.l	PUT_FLG, %a4			|a4はキュー番号0のPUT_FLGのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するPUT_FLGを選択|
	move.b 	PUT_FLG_ptr,(%a4)		|PUT_FLG_ptrを元のPUT_FLGに更新|

	lea.l	GET_FLG, %a4			|a4はキュー番号0のGET_FLGのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するGET_FLGを選択|
	move.b 	GET_FLG_ptr,(%a4)		|GET_FLG_ptrを元のGET_FLGに更新|


	mulu	#4, %d3				
	lea.l 	in, %a4				|a4はキュー番号0のinのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するinを選択|
	move.l	in_ptr, (%a4)			|in_ptrを元のinに更新|

	lea.l	out, %a4			|a4はキュー番号0のoutのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するoutを選択|
	move.l	out_ptr, (%a4)			|out_ptrを元のoutに更新|

	lea.l	s, %a4				|a4はキュー番号0のsのアドレス|
	add.l	%d3, %a4			|選択したキューにより、更新するsを選択|
	move.l	s_ptr, (%a4)			|s_ptrを元のsに更新|

	move.w	(%sp)+, %SR			|旧走行レベルの回復|
	movem.l	(%sp)+, %d2-%d6/%a0-%a6
	rts
*********************************** 
** OUTQ キューからの読み出し↑↑
***********************************


**************************************** 
** GET_BUF↓↓
** a2: 読み出し先アドレス
** d0: 結果(00:失敗, 00以外:成功) 
** d1: 取り出した8bitデータ
**************************************** 
GET_BUF:
	movem.l	%a1/%a3-%a4, -(%sp)
	move.b	GET_FLG_ptr, %d0

	cmp.b	#0x00, %d0	| GET不可能(失敗) |
	beq	GET_BUF_Finish

	movea.l	out_ptr, %a1	| キューからデータを読み出す |
	move.b	(%a1)+, %d1	| 取り出したデータ |


	subi.l	#1, s_ptr	| キュー内のデータ数:-1 |

	move.l	bottom_ptr, %a3	| a3はキュー末尾 |
	cmpa.l	%a3, %a1	| GETポインタが末尾を超えた |
	bls	GET_BUF_STEP1	

	move.l	top_ptr, %a4	| GETポインタを先頭に戻す |
	movea.l	%a4, %a1

GET_BUF_STEP1:
	move.l	%a1, out_ptr

	cmpa.l	in_ptr, %a1	| GETポインタがPUTポインタに追いついた |
	bne	GET_BUF_STEP2

	move.b	#0x00, GET_FLG_ptr	| データがないのでGET不可能(フラグ) |

GET_BUF_STEP2:
	move.b	#0x01, PUT_FLG_ptr

GET_BUF_Finish:
	movem.l	(%sp)+, %a1/%a3-%a4
	rts


.section .data 
****************************** 
** キュー用のメモリ領域確保
******************************
	.equ	B_SIZE, 256
	.equ	ALL_B_SIZE, B_SIZE + B_SIZE 	|受信と送信で１本ずつ|

top:		.ds.b	ALL_B_SIZE-1		|キューのデータ領域|
bottom:		.ds.b	1
in:		.ds.l	2			|キューの各種ポインタ↓|
out:		.ds.l	2
PUT_FLG:	.ds.b	2
GET_FLG:	.ds.b	2
s:		.ds.l	2			

top_ptr:	.ds.l	1			|実行時用一時保存領域↓|
bottom_ptr:	.ds.l	1
in_ptr:		.ds.l	1
out_ptr:	.ds.l	1
PUT_FLG_ptr:	.ds.b	1
GET_FLG_ptr:	.ds.b	1			
s_ptr:		.ds.l	1

	.even
**********************************************************
**データ領域
**********************************************************
TMSG:
	.ascii "******\r\n"			| \r: 行頭へ(キャリッジリターン)
	.even					| \n: 次の行へ(ラインフィード)

TTC:
	.dc.w 0
	.even
    
