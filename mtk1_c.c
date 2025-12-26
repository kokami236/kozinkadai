#include <stdio.h>
#include <stdint.h>
#include "mtk_c.h"

/*
 *  注意：
 *  - P/V/waitP は semasema.s から trap#1 → pv_handler → p_body/v_body/waitp_body を呼びます
 *  - この mtk_c.c は「あなたが貼ってくれた現状の設計（removeqがTCBポインタを受ける）」に合わせてあります
 *  - 安定化のため wakeup に NULL ガードを追加しています（v_body連打で重要）
 */

/* =========================
 *  グローバル
 * ========================= */
TASK_ID_TYPE curr_task;
TASK_ID_TYPE new_task;
TASK_ID_TYPE next_task;
TASK_ID_TYPE ready;

TCB_TYPE task_tab[NUMTASK + 1];
STACK_TYPE stacks[NUMTASK];
SEMAPHORE_TYPE semaphore[NUMSEMAPHORE];

/* asm側にある関数（ヘッダに無ければここで宣言） */
extern void pv_handler(void);
extern void init_timer(void);
extern void first_task(void);
extern void swtch(void);

/* =========================
 *  kernel init
 * ========================= */
void init_kernel(void) {
    /* TCB配列を初期化する */
    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        tcb->task_addr = NULL;
        tcb->stack_ptr = NULL;
        tcb->priority  = 0;
        tcb->status    = TASK_UNDEF;
        tcb->next      = NULLTASKID;
    }

    /* readyキューを初期化する */
    ready = NULLTASKID;

    /* pv_handlerをTRAP #1の割り込みベクタに登録 */
    *(int *)(TRAP1_ID * 4) = (int)(uintptr_t)pv_handler;

    /* セマフォの値を初期化する */
    for (int i = 0; i < NUMSEMAPHORE; i++) {
        SEMAPHORE_TYPE *sema = &semaphore[i];
        sema->count     = 1;          /* 1: 利用可能, <1: 待ちタスクがある（通常のP/V用の初期値） */
        sema->nst       = 0;          /* waitPで使う同期参加数N（必要なものだけ後で設定） */
        sema->task_list = NULLTASKID; /* 待ち行列 */
    }
}

/* =========================
 *  task create / start
 * ========================= */
void set_task(void (*task_addr)(void)) {
    /* タスクIDの決定 */
    TASK_ID_TYPE task_id = NULLTASKID;
    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        if (tcb->status == TASK_UNDEF || tcb->status == TASK_FINISHED) {
            task_id = (TASK_ID_TYPE)(i + 1);
            break;
        }
    }
    if (task_id == NULLTASKID) return; /* 空きがない */

    new_task = task_id;

    TCB_TYPE *tcb = &task_tab[new_task];
    tcb->task_addr = task_addr;
    tcb->status    = TASK_INUSE;
    tcb->stack_ptr = init_stack(new_task);

    addq(&ready, new_task);
    printf("[OK] set_task\n");
}

void begin_sch(void) {
    /* 最初のタスクの決定：ready先頭を取り出す */
    curr_task = removeq(&task_tab[ready]);
    if (DEBUG) printf("[DEBUG] curr_task = %d\n", curr_task);

    init_timer();
    printf("[OK] init_timer\n");

    first_task(); /* 最初のタスクへ遷移（戻らない） */
}

/* =========================
 *  stack init
 * ========================= */
void *init_stack(TASK_ID_TYPE id) {
    char  *ustack_top = &stacks[id - 1].ustack[STKSIZE];
    char  *sstack     = stacks[id - 1].sstack;
    int   *ssp        = (int *)(sstack + STKSIZE);

    *(--ssp) = (int)(uintptr_t)task_tab[id].task_addr; /* initial PC */

    short *ssp_s = (short *)ssp;
    *(--ssp_s) = (short)0x0000;                        /* initial SR */
    ssp = (int *)ssp_s;

    ssp -= 15;                                         /* 15x4 bytes for registers */
    *(--ssp) = (int)(uintptr_t)ustack_top;             /* initial USP */

    return ssp;
}

/* =========================
 *  queue ops
 * ========================= */
void addq(TASK_ID_TYPE *q, TASK_ID_TYPE task_id) {
    if (DEBUG) printf("[DEBUG] addq: added task_id = %d\n", task_id);

    /* キューが空 */
    if (*q == NULLTASKID) {
        *q = task_id;
    } else {
        TASK_ID_TYPE cur = *q;
        while (task_tab[cur].next != NULLTASKID) cur = task_tab[cur].next;
        task_tab[cur].next = task_id;
    }
    task_tab[task_id].next = NULLTASKID;
}

TASK_ID_TYPE removeq(TCB_TYPE *q_ptr) {
    TASK_ID_TYPE task_id;

    /* semaphore キューの場合（現状の作りに合わせる） */
    for (int i = 0; i < NUMSEMAPHORE; i++) {
        if (q_ptr == &task_tab[semaphore[i].task_list]) {
            task_id = semaphore[i].task_list;
            if (task_id == NULLTASKID) return NULLTASKID;

            semaphore[i].task_list = (*q_ptr).next;
            if (DEBUG) printf("[DEBUG] removeq returns %d (semaphore queue)\n", task_id);
            return task_id;
        }
    }

    /* ready キューの場合 */
    if (q_ptr == &task_tab[ready]) {
        task_id = ready;
        if (task_id == NULLTASKID) return NULLTASKID;

        ready = (*q_ptr).next;
        if (DEBUG) printf("[DEBUG] removeq returns %d (ready queue)\n", task_id);
        return task_id;
    }

    return NULLTASKID;
}

/* =========================
 *  scheduler
 * ========================= */
void sched(void) {
    if (DEBUG) printf("[DEBUG] sched()\n");

    next_task = removeq(&task_tab[ready]);
    if (DEBUG) printf("[DEBUG] sched: next_task = %d\n", next_task);

    while (next_task == NULLTASKID) {
        /* readyが空なら待つ（本来はアイドル等が望ましいが現状仕様に合わせる） */
    }
}

/* =========================
 *  semaphore bodies (called from pv_handler)
 * ========================= */
void p_body(int ID) {
    if (DEBUG) printf("[DEBUG] p_body(%d)\n", ID);

    SEMAPHORE_TYPE *sema = &semaphore[ID];
    sema->count -= 1;

    if (sema->count < 0) {
        sleep(ID);
    }
}

void v_body(int ID) {
    if (DEBUG) printf("[DEBUG] v_body(%d)\n", ID);

    SEMAPHORE_TYPE *sema = &semaphore[ID];
    sema->count += 1;

    if (sema->count <= 0) {
        wakeup(ID);
    }
}

/*
 * waitP（バリア同期）本体：syscall ID=2 で pv_handler から呼ばれる
 *  - semaphore[ID].count は必ず 0 初期化
 *  - semaphore[ID].nst   は同期参加タスク数 N を設定
 */
void waitp_body(int ID) {
    if (DEBUG) printf("[DEBUG] waitp_body(%d)\n", ID);

    SEMAPHORE_TYPE *sp = &semaphore[ID];

    /* まだ全員揃っていない：通常のPと同じ（必要ならsleepへ） */
    if (sp->count != -(sp->nst - 1)) {
        p_body(ID);
        return;
    }

    /* 最後の1人：待っている(N-1)個をまとめて起こす */
    for (int i = 0; i < sp->nst - 1; i++) {
        v_body(ID);
    }

    /* 最後に来た自分も ready に戻して譲る */
    task_tab[curr_task].status = TASK_READY;
    addq(&ready, curr_task);
    sched();
    swtch();
}

/* =========================
 *  sleep / wakeup
 * ========================= */
void sleep(int ch) {
    if (DEBUG) printf("[DEBUG] sleep(%d)\n", ch);

    SEMAPHORE_TYPE *sema = &semaphore[ch];
    addq(&sema->task_list, curr_task);
    task_tab[curr_task].status = TASK_SLEEP;

    sched();
    swtch();
}

void wakeup(int ch) {
    if (DEBUG) printf("[DEBUG] wakeup(%d)\n", ch);

    SEMAPHORE_TYPE *sema = &semaphore[ch];
    TASK_ID_TYPE woken_task_id = removeq(&task_tab[sema->task_list]);

    if (woken_task_id == NULLTASKID) return; /* ★重要：空なら何もしない */

    addq(&ready, woken_task_id);
    task_tab[woken_task_id].status = TASK_READY;
}
