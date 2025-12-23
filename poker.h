#ifndef POKER_H
#define POKER_H
#include <stdio.h>
#include "mtk_c.h"

#define HAND_SIZE 5

/* トランプカードの構造体 */
typedef struct {
    int mark;   /* 1-4: マーク (1:SP, 2:HE, 3:DI, 4:CL) */
    int number; /* 1-13: 数字 (1:A, 11:J, 12:Q, 13:K) */
} CARD;

/* --- 共有資源の宣言 --- */
extern CARD hand[2][HAND_SIZE];
extern volatile int phase[2]; /* 0:交換中, 1:確定 */
extern volatile int is_finish;
extern int winner;

/* 表示用文字列の共有宣言（test3.cで実体を定義） */
extern char *poker_role_str[];
extern char *mark_str[];
extern char *number_str[];

/* --- 関数プロトタイプ宣言 --- */
// 初期化・基本動作系
void sleeptime(int msec); /* 追加: 警告を消すため */
void init_game();
void init_card();
void shuffle_card();
void fill_card(int ch, int num);

// 表示・判定系
void disp_field(int ch, FILE *cha);
void disp_field_with_selection(int ch, FILE *cha, int *selected); // ←ここを追加
long evaluate_hand(int player_id); // intからlongへ

// タスク系
void start_game();
void player0();
void player1();

#endif
