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
