.include "defs.s"
.section .text

.equ SIZEOF_TCB_TYPE, 20
.equ TCB_TYPE_STACK_PTR_OFFSET, 4
.equ TCB_TYPE_NEXT_OFFSET, 16

.global first_task
.even
first_task:
    * 1. TCB 先頭番地の計算：curr_task の TCB のアドレスを見つける
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]

    move.l %sp, SINGLE_SSP

    * 2. USP，SSP の値の回復
    * %SSP = &task_tab[curr_task]->stack_ptr
    move.l TCB_TYPE_STACK_PTR_OFFSET(%A1), %SP
    move.l (%SP)+, %A1
    move.l %A1, %USP

    * 3. 残りの全レジスタの回復
    movem.l (%SP)+, %D0-%D7/%A0-%A6

    * 4. ユーザタスクの起動（SR,PCの復帰）
    rte

BACKTO_SINGLE:
    rts

.data
.even
SINGLE_SSP: .ds.l 1

.section .text
.global swtch
.even
swtch:
    * 1. SR をスタックに積んで，RTE で復帰できるようにする．
    move.w %SR, -(%SP)

    * 2. 実行中のタスクのレジスタの退避
    movem.l %D0-%D7/%A0-%A6, -(%SP)
    move.l %USP, %A1
    move.l %A1, -(%SP)

    * 3. SSPの保存
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]
    move.l %SP, TCB_TYPE_STACK_PTR_OFFSET(%A1)

    * 4. curr_task を変更
    move.l next_task, curr_task

    * 5. 次のタスクの SSP の読み出し
    move.l curr_task, %D1      | %D1.l = curr_task
    muls #SIZEOF_TCB_TYPE, %D1 | %D1.l = curr_task * SIZEOF_TCB_TYPE
    lea.l task_tab, %A1        | %A1.l = task_tab
    add.l %D1, %A1             | %A1.l = &task_tab[curr_task]
    * %SP(SSP) = &task_tab[curr_task]->stack_ptr
    move.l TCB_TYPE_STACK_PTR_OFFSET(%A1), %SP

    * 6. 次のタスクのレジスタの読み出し
    move.l (%SP)+, %A1
    move.l %A1, %USP
    movem.l (%SP)+, %D0-%D7/%A0-%A6

    * 7. タスク切り替え
    rte


* =========================================================
* タイマ関連のサブルーチン
*  - ここを「キューは先頭TASK_IDを管理し、addq(&ready, curr_task)」に統一
* =========================================================
.even
hard_clock:
    movem.l %D1/%A1, -(%SP)

    * addq(&ready, curr_task)
    * C側 addq(TASK_ID_TYPE *head, TASK_ID_TYPE task_id) に合わせる
    move.l curr_task, -(%SP)   | 第2引数: task_id
    move.l #ready, -(%SP)      | 第1引数: &ready
    jsr addq
    addq.l #8, %SP

    jsr sched
    jsr swtch

    movem.l (%SP)+, %D1/%A1
    rts


.global init_timer
.even
init_timer:
    /* タイマのリセット */
    move.l #SYSCALL_NUM_RESET_TIMER, %D0
    trap #0

    /* タイマのセット */
    move.l #SYSCALL_NUM_SET_TIMER, %D0
    move.w #10000, %D1         /* 1秒に設定（環境依存） */
    move.l #hard_clock, %D2     /* hard_clock を呼び出すよう設定 */
    trap #0
    rts


.global skipmt
.even
skipmt:
    move.l #SYSCALL_NUM_SKIPMT, %D0
    trap #0
    rts


* trap#1(P/V/waitP) の実装
.include "semasema.s"


.section .bss
.extern task_tab
.extern curr_task
.extern next_task
.extern ready        * ★追加：hard_clock で #ready を使うため
