.global inbyte
.global inkey
.equ SYSCALL_NUM_GETSTRING, 1   /* ここで定義すれば defs.s は不要 */

.section .text
.even
inbyte:
    link.w  %a6, #-4
    movem.l %d1-%d3, -(%sp)

inbyte_loop1:
    move.l  #SYSCALL_NUM_GETSTRING, %d0
    move.l  #0, %d1
    
    /* バッファアドレスの計算: FP(%a6) - 4 */
    move.l  %a6, %d2
    subi.l  #4, %d2
    
    move.l  #1, %d3
    trap    #0

    cmpi.l  #1, %d0
    bne     inbyte_loop1

    clr.l   %d0
    /* 受信データの取得 */
    move.b  -4(%a6), %d0
    
    movem.l (%sp)+, %d1-%d3
	unlk    %a6
	rts


.section .text
.even

inkey:
    /* (1) スタックフレーム作成
       linkを使うことで、ローカル変数(バッファ)領域を確保します。
       #-4 で4バイト分の領域をスタックに確保します。
    */
    link    %a6, #-4

    /* (2) レジスタ退避
       outbyteと同様に、使うものだけ保存します。
       a0はアドレス計算に使うので追加で保存します。
    */
    movem.l %d1-%d3/%a0, -(%sp)

    /* (3) 引数の取得
       linkを使ったので、第一引数(ch)は必ず 8(%a6) にあります。
    */
    move.l  8(%a6), %d1

    /* (4) システムコール呼び出し */
    move.l  #SYSCALL_NUM_GETSTRING, %d0
    
    /* バッファのアドレス指定
       確保したスタック領域(-1(%a6))のアドレスを計算して d2 に入れます。
    */
    lea     -1(%a6), %a0
    move.l  %a0, %d2
    
    move.l  #1, %d3             /* 1文字入力 */
    trap    #0

    /* (5) 結果判定 */
    cmpi.l  #1, %d0             /* 1文字取れた？ */
    beq     inkey_success

    /* 入力なしの場合 */
    moveq   #-1, %d0            /* 戻り値を -1 (0xFFFFFFFF) に */
    bra     inkey_end

inkey_success:
    /* 入力ありの場合 */
    moveq   #0, %d0             /* 上位ビットをクリア */
    move.b  -1(%a6), %d0        /* スタック上のバッファから文字を取得 */

inkey_end:
    /* (6) 終了処理 */
    movem.l (%sp)+, %d1-%d3/%a0 /* 退避したレジスタだけ戻す */
    unlk    %a6                 /* スタックフレーム破棄 */
    rts
