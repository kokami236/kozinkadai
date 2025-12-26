#include <stdio.h>
#include <stdint.h>
#include "mtk_c.h"

/* asm側の関数 */
extern void pv_handler(void);
extern void init_timer(void);
extern void first_task(void);
extern void swtch(void);

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

/* =========================
 *  内部プロトタイプ
 * ========================= */
void waitp_body(int ID);

/* =========================
 *  キュー操作（先頭TASK_IDで管理）
 * ========================= */
void addq(TASK_ID_TYPE *head, TASK_ID_TYPE task_id) {
    if (task_id == NULLTASKID) return;

    if (*head == NULLTASKID) {
        *head = task_id;
        task_tab[task_id].next = NULLTASKID;
        return;
    }

    TASK_ID_TYPE cur = *head;
    while (task_tab[cur].next != NULLTASKID) {
        cur = task_tab[cur].next;
    }
    task_tab[cur].next = task_id;
    task_tab[task_id].next = NULLTASKID;
}

TASK_ID_TYPE removeq(TASK_ID_TYPE *head) {
    TASK_ID_TYPE id = *head;
    if (id == NULLTASKID) return NULLTASKID;

    *head = task_tab[id].next;
    task_tab[id].next = NULLTASKID;
    return id;
}

/* =========================
 *  init
 * ========================= */
void init_kernel(void) {
    /* TCB初期化 */
    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        tcb->task_addr = NULL;
        tcb->stack_ptr = NULL;
        tcb->priority  = 0;
        tcb->status    = TASK_UNDEF;
        tcb->next      = NULLTASKID;
    }
    /* task_tab[0]は未使用（NULLTASKID用） */
    task_tab[0].next = NULLTASKID;

    /* readyキュー初期化 */
    ready = NULLTASKID;

    /* TRAP#1に pv_handler を登録 */
    *(int *)(TRAP1_ID * 4) = (int)(uintptr_t)pv_handler;

    /* セマフォ初期化 */
    for (int i = 0; i < NUMSEMAPHORE; i++) {
        semaphore[i].count     = 1;          /* 通常P/Vの初期値（必要に応じて上書き） */
        semaphore[i].nst       = 0;          /* waitP用（使うものだけ設定） */
        semaphore[i].task_list = NULLTASKID; /* 待ち行列先頭 */
    }
}

/* =========================
 *  タスク生成
 * ========================= */
void set_task(void (*task_addr)(void)) {
    TASK_ID_TYPE task_id = NULLTASKID;

    for (int i = 0; i < NUMTASK; i++) {
        TCB_TYPE *tcb = &task_tab[i + 1];
        if (tcb->status == TASK_UNDEF || tcb->status == TASK_FINISHED) {
            task_id = (TASK_ID_TYPE)(i + 1);
            break;
        }
    }
    if (task_id == NULLTASKID) return;

    new_task = task_id;

    TCB_TYPE *tcb = &task_tab[new_task];
    tcb->task_addr = task_addr;
    tcb->status    = TASK_INUSE;
    tcb->stack_ptr = init_stack(new_task);

    /* readyへ投入 */
    addq(&ready, new_task);

    if (!DEBUG) printf("[OK] set_task\n");
}

/* =========================
 *  スタック初期化（あなたの実装踏襲）
 * ========================= */
void *init_stack(TASK_ID_TYPE id) {
    char *ustack_top = &stacks[id - 1].ustack[STKSIZE];
    char *sstack     = stacks[id - 1].sstack;
    int  *ssp        = (int *)(sstack + STKSIZE);

    *(--ssp) = (int)(uintptr_t)task_tab[id].task_addr; /* initial PC */

    short *ssp_s = (short *)ssp;
    *(--ssp_s) = (short)0x0000;                        /* initial SR */
    ssp = (int *)ssp_s;

    ssp -= 15;                                         /* D0-D7,A0-A6 */
    *(--ssp) = (int)(uintptr_t)ustack_top;             /* initial USP */

    return ssp;
}

/* =========================
 *  スケジューラ
 * ========================= */
void sched(void) {
    next_task = removeq(&ready);

    /* readyが空なら待つ（本来はidleタスク等が望ましいが、課題仕様に合わせる） */
    while (next_task == NULLTASKID) {
        /* spin */
    }
}

/* =========================
 *  開始
 * ========================= */
void begin_sch(void) {
    curr_task = removeq(&ready);
    if (DEBUG) printf("[DEBUG] curr_task = %d\n", curr_task);

    init_timer();
    if (!DEBUG) printf("[OK] init_timer\n");

    first_task(); /* ここから戻らない */
}

/* =========================
 *  セマフォ本体（pv_handler から呼ばれる）
 * ========================= */
void p_body(int ID) {
    SEMAPHORE_TYPE *sema = &semaphore[ID];
    sema->count -= 1;

    if (sema->count < 0) {
        sleep(ID);
    }
}

void v_body(int ID) {
    SEMAPHORE_TYPE *sema = &semaphore[ID];
    sema->count += 1;

    if (sema->count <= 0) {
        wakeup(ID);
    }
}

/*
 * waitP本体（syscall ID=2）
 * - semaphore[ID].count は必ず 0 初期化
 * - semaphore[ID].nst   は参加タスク数 N を設定
 */
void waitp_body(int ID) {
    SEMAPHORE_TYPE *sp = &semaphore[ID];

    /* まだ全員そろっていない */
    if (sp->count != -(sp->nst - 1)) {
        p_body(ID);
        return;
    }

    /* 最後の1人：待っている(N-1)人を起こす */
    for (int i = 0; i < sp->nst - 1; i++) {
        v_body(ID);
    }

    /* 自分もreadyに戻して譲る */
    task_tab[curr_task].status = TASK_READY;
    addq(&ready, curr_task);

    sched();
    swtch();
}

/* =========================
 *  sleep / wakeup
 * ========================= */
void sleep(int ch) {
    SEMAPHORE_TYPE *sema = &semaphore[ch];

    addq(&sema->task_list, curr_task);
    task_tab[curr_task].status = TASK_SLEEP;

    sched();
    swtch();
}

void wakeup(int ch) {
    SEMAPHORE_TYPE *sema = &semaphore[ch];

    TASK_ID_TYPE woken = removeq(&sema->task_list);
    if (woken == NULLTASKID) return;  /* v_body連打対策 */

    task_tab[woken].status = TASK_READY;
    addq(&ready, woken);
}
