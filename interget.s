.section .text

***************************
** %d1.l = ch
** %d2.b = 受信データ  data
** 戻り値  なし
***************************
INTERGET:
	cmpi.l #0, %d1    /* ch != 0 なら終了 */                    
	bne INTERGET_END 
	move.b %d2, %d1   /* %d1 = data */
	moveq.l #0, %d0   /* キュー番号を 0 に設定 */          
	jsr INQ           /* INQ(0, data) */

INTERGET_END:
	rts
	
**********************************************
** %d1.l = ch
** %d2.l = 書き込み先の先頭アドレス p
** %d3.l = 取り出すデータ数  size
** 戻り値  %d0.l = 実際に取り出したデータ数  sz 
**********************************************
GETSTRING:
	movem.l %d4/%a0, -(%sp)
	cmp.l #0, %d1            /* ch != 0 なら終了 */                  
	bne GETSTRING_END      
	moveq.l #0, %d4          /* %d4 = 0 , %d4は%d0(=sz)の一時保存レジスタ */                    
	movea.l %d2, %a0         /* %a0 = p */       

GETSTRING_STEP1:
	cmp.l %d4, %d3           /* %d4 = size なら STEP2 へ */               
	beq GETSTRING_STEP2
	moveq.l #0, %d0          /* %d0 = 0, キュー番号を0に */
	jsr OUTQ                 /* OUTQ(0,data) */      
	cmpi.l #0, %d0           /* 復帰値 %d0 が 0 なら STEP2 へ */           
	beq GETSTRING_STEP2      
	move.b %d1, (%a0)+       /* %a0 番地へ data をコピー, %a0++ */                               
	addq.l #1, %d4           /* %d4++ */      
	bra GETSTRING_STEP1      

GETSTRING_STEP2:
	move.l %d4, %d0          /* %d0 = %d4 */  

GETSTRING_END:
	movem.l (%sp)+, %d4/%a0
	rts
