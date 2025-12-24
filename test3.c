#include <stdio.h>
#include <stdlib.h>
#include "poker.h"

/* --- 外部関数の宣言 --- */
extern int inkey(int ch); 

/* --- 共有資源 --- */
CARD hand[2][HAND_SIZE];
volatile int phase[2] = {0, 0}; // 0:交換中, 2:完了
volatile int is_finish = 0;     // 0:継続, 2:自爆負け, 3:時間切れ判定
volatile int loser_id = -1;
/* --- 共有資源セクション --- */
volatile int time_limit[2] = {30, 30}; // 各プレイヤーの持ち時間（秒）を追加
volatile int opp_discards[2] = {0, 0};  // 
#define MOVE_CURSOR(out, y, x) fprintf(out, "\033[%d;%dH", y, x) // 座標指定マクロ
unsigned int seed = 0;
CARD deck[52];
int deck_top = 0;

/* 表示用文字列 */
char *poker_role_str[] = {"ブタ", "ワンペア", "ツーペア", "三枚", "順子", "同色", "家", "四枚", "同色順"};
char *mark_str[] = {"", "SP", "HE", "DI", "CL"};
char *number_str[] = {"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"};

/* --- 補助・描画関数 --- */

void sleeptime(int msec) {
    volatile int i, j;
    for(i = 0; i < msec; i++) {
        for(j = 0; j < 1000; j++) { asm("nop"); }
    }
}
void update_realtime_info(int id, FILE *out) {
    int opp = 1 - id;
    
    // 【残り時間】 2行目
    MOVE_CURSOR(out, 2, 13); 
    fprintf(out, "%2d 秒", time_limit[id]);

    // 【山札残り】 9行目 12文字目
    MOVE_CURSOR(out, 9, 12);
    fprintf(out, "%2d", 52 - deck_top);

    // 【相手の状態】 9行目 26文字目
    MOVE_CURSOR(out, 9, 26);
    if (phase[opp] == 2) {
        fprintf(out, "完了！      ");
    } else if (opp_discards[opp] > 0) {
        fprintf(out, "%d枚交換！  ", opp_discards[opp]);
    } else {
        fprintf(out, "考え中...   ");
    }

    // ★重要：カーソルを操作説明の邪魔にならない場所（12行目）へ逃がす
    MOVE_CURSOR(out, 12, 1);
    fflush(out);
}
void disp_base_field(int ch, FILE *out) {
    fprintf(out, "\033[2J\033[H"); // 画面クリア
    fprintf(out, "=== MULTI-TASK SURVIVAL POKER ===\n");
    fprintf(out, " 【残り時間:   秒】\n"); // 最初はダミー
    fprintf(out, "----------------------------------\n");
    fprintf(out, "Player%d (自分): ", ch);
    for (int i = 0; i < HAND_SIZE; i++) {
        fprintf(out, "[%s%s] ", mark_str[hand[ch][i].mark], number_str[hand[ch][i].number]);
    }
    fprintf(out, "\n番号:         (0)   (1)   (2)   (3)   (4)\n");
    fprintf(out, "----------------------------------\n");
    fprintf(out, "選択状況:     ( )   ( )   ( )   ( )   ( )  \n");
    fprintf(out, "                                     \n");
    fprintf(out, "[山札残り:   枚] [相手: 準備中       ]\n");
    fprintf(out, "操作: (0-4)選択, (9)交換実行, (8)勝負！\n");
    
    // 描画直後に最新の値を上書きさせる
    MOVE_CURSOR(out, 12, 1);
    update_realtime_info(ch, out);
}
void update_status_line(int id, FILE *out) {
    int opp = 1 - id;
    char *st = (phase[opp] == 2) ? "完了！" : "考え中...";
    fprintf(out, "\033[2A\r\033[K[山札残り: %2d枚] [相手: %-10s]\n\n", 52 - deck_top, st);
    fflush(out);
}


void update_selection_line_absolute(int id, int *selected, FILE *out) {
    // 選択状況を表示する行（9行目と仮定。disp_base_fieldのレイアウトに合わせて調整）
    MOVE_CURSOR(out, 8, 15); 
    for (int i = 0; i < 5; i++) {
        fprintf(out, selected[i] ? "(X)   " : "( )   ");
    }
    MOVE_CURSOR(out, 12, 1);
    fflush(out);
}
void show_result(int me, long s_me, long s_opp) {
    FILE *out = (me == 0) ? com0out : com1out;
    int opp = (me == 0) ? 1 : 0;
    fprintf(out, "\n【結果発表】\n相手の手札: ");
    for(int i=0; i<HAND_SIZE; i++) 
        fprintf(out, "[%s%s] ", mark_str[hand[opp][i].mark], number_str[hand[opp][i].number]);
    
    fprintf(out, "\nあなたの役: %s / 相手の役: %s\n", 
            poker_role_str[s_me / 100000000L], poker_role_str[s_opp / 100000000L]);
    
    if (s_me > s_opp)      fprintf(out, ">>> YOU WIN! <<<\n");
    else if (s_me < s_opp) fprintf(out, ">>> YOU LOSE... <<<\n");
    else                   fprintf(out, ">>> DRAW <<<\n");
}

/* --- カード・タスクロジック --- */

void fill_card(int ch, int num) {
    P(2);
    if (deck_top < 51) {
        hand[ch][num] = deck[deck_top++];
    } else if (deck_top == 51) {
        hand[ch][num] = deck[deck_top++];
        is_finish = 2; // 自爆
        loser_id = ch;
    }
    V(2);
}


void player_task_logic(int id, FILE *in, FILE *out) {
    int c, last_time = -1, last_top = -1, last_opp_phase = -1;
    int selected[5];

    while (1) {
        P(id);
        for(int i=0; i<5; i++) selected[i] = 0;
        disp_base_field(id, out);

        while (!is_finish && phase[id] < 2) {
            // 値が変わった時だけ部分更新
            if (time_limit[id] != last_time || deck_top != last_top || phase[1-id] != last_opp_phase) {
                update_realtime_info(id, out);
                last_time = time_limit[id];
                last_top = deck_top;
                last_opp_phase = phase[1-id];
            }

            c = inkey(id);
            if (c != -1) {
                if (c >= '0' && c <= '4') {
                    selected[c - '0'] = !selected[c - '0'];
                    update_selection_line_absolute(id, selected, out); // 絶対座標版
                }
                if (c == '9') {
                    // --- 追加：捨てた枚数を数えて共有変数に保存 ---
                    int count = 0;
                    for (int i = 0; i < 5; i++) {
                        if (selected[i]) {
                            fill_card(id, i);
                            count++;
                        }
                    }
                    opp_discards[id] = count; // 相手の画面に表示される
                    // ------------------------------------------

                    if (is_finish) break;
                    for (int i = 0; i < 5; i++) selected[i] = 0;
                    disp_base_field(id, out); // カードが変わるので全体再描画
                }
                if (c == '8') { 
                    phase[id] = 2; 
                }
            }
            sleeptime(10); 
        }
        // 自分が完了した後の待機中もリアルタイム更新を続ける
        while (phase[0] < 2 || phase[1] < 2) { 
            if (is_finish) break; 
            update_realtime_info(id, out); 
            sleeptime(10); 
        }
    }
}
/* --- 死神タスク --- */
void seed_task() {
    int tick = 0;
    int tick_for_deck = 0;
    while (1) {
        seed++;
        if (!is_finish) {
            tick++;
            if (tick >= 500) { // 1秒ごとに実行
                for (int i = 0; i < 2; i++) {
                    if (phase[i] == 0 && time_limit[i] > 0) {
                        time_limit[i]--;
                        if (time_limit[i] <= 0) phase[i] = 2; // 時間切れ
                    }
                }
                tick = 0;
            }
            // 山札減少ロジック
            tick_for_deck++;
            if (tick_for_deck > 250) {
                P(2);
                if (deck_top < 51) deck_top++;
                else if (deck_top == 51) { deck_top++; is_finish = 3; }
                V(2);
                tick_for_deck = 0;
            }
        }
        sleeptime(1);
    }
}

/* --- 管理タスク --- */
void manager_task() {
    srand(seed);
    while (1) {
        init_game();
        is_finish = 0; phase[0] = 0; phase[1] = 0;
	time_limit[0] = 30; // 時間をリセット
        time_limit[1] = 30; // 時間をリセット
	opp_discards[0] = 0; // ★リセットを追加
        opp_discards[1] = 0; // ★リセットを追加
        V(0); V(1);

        while (!is_finish && (phase[0] < 2 || phase[1] < 2)) { sleeptime(100); }

        sleeptime(1000);
        if (is_finish == 2) {
            fprintf(com0out, "\n【自爆】Player%dが最後を引きました！\n", loser_id);
            fprintf(com1out, "\n【自爆】Player%dが最後を引きました！\n", loser_id);
        } else {
            long s0 = evaluate_hand(0); long s1 = evaluate_hand(1);
            show_result(0, s0, s1); show_result(1, s1, s0);
        }
        sleeptime(5000);
    }
}

/* --- 基本ロジック実装 --- */

void init_card() {
    int i, j, k = 0;
    for (i = 1; i <= 4; i++) {
        for (j = 1; j <= 13; j++) {
            deck[k].mark = i; deck[k].number = j; k++;
        }
    }
}

void shuffle_card() {
    int i, r; CARD tmp;
    for (i = 51; i > 0; i--) {
        r = rand() % (i + 1);
        tmp = deck[i]; deck[i] = deck[r]; deck[r] = tmp;
    }
}

void init_game() {
    P(2);
    deck_top = 0;
    init_card();
    shuffle_card();
    for (int p = 0; p < 2; p++) {
        for (int i = 0; i < HAND_SIZE; i++) {
            hand[p][i] = deck[deck_top++];
        }
    }
    V(2);
}

#define CARD_VAL(n) ((n) == 1 ? 14 : (n))
long evaluate_hand(int ch) {
    int counts[15] = {0}, marks[5] = {0}, sorted[HAND_SIZE];
    int pairs = 0, three = 0, four = 0, flush = 0, straight = 0;
    int pair_val = 0, second_pair_val = 0;

    for (int i = 0; i < HAND_SIZE; i++) {
        int v = CARD_VAL(hand[ch][i].number);
        counts[v]++; marks[hand[ch][i].mark]++; sorted[i] = v;
    }
    for (int i = 0; i < 4; i++) 
        for (int j = i + 1; j < 5; j++) 
            if (sorted[i] > sorted[j]) { int t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t; }

    for (int i = 14; i >= 2; i--) {
        if (counts[i] == 4) { four = 1; pair_val = i; }
        else if (counts[i] == 3) { three = 1; pair_val = i; }
        else if (counts[i] == 2) { pairs++; if(pair_val == 0) pair_val = i; else second_pair_val = i; }
    }
    if (sorted[0] == 2 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5 && sorted[4] == 14) {
        straight = 1; sorted[4] = 5;
    } else if (sorted[4] - sorted[0] == 4 && pairs == 0 && three == 0) straight = 1;
    for (int i = 1; i <= 4; i++) if (marks[i] == HAND_SIZE) flush = 1;

    long kicker = (long)sorted[4]*65536 + (long)sorted[3]*4096 + (long)sorted[2]*256 + (long)sorted[1]*16 + (long)sorted[0];
    if (straight && flush) return 800000000L + sorted[4];
    if (four)              return 700000000L + (pair_val * 100) + kicker;
    if (three && pairs)    return 600000000L + (pair_val * 100) + kicker;
    if (flush)             return 500000000L + kicker;
    if (straight)          return 400000000L + sorted[4];
    if (three)             return 300000000L + (pair_val * 100) + kicker;
    if (pairs == 2)        return 200000000L + (pair_val * 1000) + (second_pair_val * 100) + kicker;
    if (pairs == 1)        return 100000000L + (pair_val * 1000) + kicker;
    return kicker;
}

/* --- エントリポイント --- */
void player1_task() { player_task_logic(0, com0in, com0out); }
void player2_task() { player_task_logic(1, com1in, com1out); }

int main() {
    fd_mapping();
    init_kernel();
    semaphore[0].count = 0;
    semaphore[1].count = 0;
    semaphore[2].count = 1; 

    printf("PUSH ANY KEY TO START POKER\n");
    while(inkey(0) == -1) { seed++; sleeptime(1); }
    srand(seed);

    set_task(seed_task);
    set_task(player1_task);
    set_task(player2_task);
    set_task(manager_task);

    begin_sch();
    return 0;
}
