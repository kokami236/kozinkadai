#include <stdio.h>
#include <stdlib.h>
#include "poker.h"

/* --- 外部関数の宣言 --- */
extern int inkey(int ch); 

/* --- 共有資源の実体 --- */
CARD hand[2][HAND_SIZE];
volatile int phase[2] = {0, 0};
volatile int is_finish = 0;
unsigned int seed = 0;

/* 表示用文字列（役の強さ順：0=ブタ ... 8=ストフラ） */
char *poker_role_str[] = {
    "ブタ", "ワンペア", "ツーペア", "スリーカード", 
    "ストレート", "フラッシュ", "フルハウス", "フォーカード", "ストレートフラッシュ"
};
char *mark_str[] = {"", "SP", "HE", "DI", "CL"};
char *number_str[] = {"", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"};

/* --- 補助関数 --- */

void sleeptime(int msec) {
    volatile int i, j;
    for(i = 0; i < msec; i++) {
        for(j = 0; j < 1000; j++) { asm("nop"); }
    }
}

void disp_field(int ch, FILE *cha) {
    int opp = (ch == 0) ? 1 : 0;
    fprintf(cha, "\n----------------------------------\n");
    fprintf(cha, "Player%d (相手): [???] [???] [???] [???] [???]\n\n", opp); 
    fprintf(cha, "Player%d (自分): ", ch);
    for (int i = 0; i < HAND_SIZE; i++) {
        fprintf(cha, "[%s%s] ", mark_str[hand[ch][i].mark], number_str[hand[ch][i].number]);
    }
    fprintf(cha, "\n        (0)   (1)   (2)   (3)   (4)\n");
    fprintf(cha, "----------------------------------\n");
}
/* --- [追加] 選択状態を表示する補助関数 --- */
void disp_field_with_selection(int ch, FILE *cha, int *selected) {
    int opp = (ch == 0) ? 1 : 0;
    fprintf(cha, "\n----------------------------------\n");
    fprintf(cha, "Player%d (相手): [???] [???] [???] [???] [???]\n\n", opp); 
    fprintf(cha, "Player%d (自分): ", ch);
    for (int i = 0; i < HAND_SIZE; i++) {
        fprintf(cha, "[%s%s] ", mark_str[hand[ch][i].mark], number_str[hand[ch][i].number]);
    }
    // 選択されているカードの下にマークを表示
    fprintf(cha, "\n交換選択:    ");
    for (int i = 0; i < HAND_SIZE; i++) {
        if (selected[i]) fprintf(cha, " (X)  "); // 交換対象
        else             fprintf(cha, "      ");
    }
    fprintf(cha, "\n番号:        (0)   (1)   (2)   (3)   (4)\n");
    fprintf(cha, "----------------------------------\n");
}

/* --- [書き換え] プレイヤー共通ロジック --- */
void player_task_logic(int id, FILE *in, FILE *out) {
    int c;
    int selected[5]; // 各カードの選択状態を管理

    while (1) {
        P(id); 
        phase[id] = 0;
        // 選択状態をリセット
        for(int i = 0; i < 5; i++) selected[i] = 0;

        while (1) {
            disp_field_with_selection(id, out, selected);
            fprintf(out, "交換する番号(0-4)を選択、[9]で交換実行: ");

            // キー入力待ち
            while (1) {
                c = inkey(id);
                if (c != -1) break;
                sleeptime(1);
            }

            if (c == '9') {
                fputc(c, out);
                fprintf(out, "\n交換を確定します。\n");
                break; 
            }
            
            if (c >= '0' && c <= '4') {
                int idx = c - '0';
                selected[idx] = !selected[idx]; // 選択/解除を反転
            }
        }

        // 選択されたカードを一括で交換
        int exchange_count = 0;
        for (int i = 0; i < 5; i++) {
            if (selected[i]) {
                fill_card(id, i);
                exchange_count++;
            }
        }
        
        if(exchange_count > 0) {
            fprintf(out, "%d枚のカードを交換しました。\n", exchange_count);
            disp_field(id, out); 
        } else {
            fprintf(out, "交換せずに勝負します。\n");
        }

        phase[id] = 1; 
        fprintf(out, "\n確定しました。相手を待っています...\n");
        while (phase[id] == 1 && !is_finish) { sleeptime(10); }
    }
}

/* --- 各タスクの入り口 --- */
void seed_task() { while (1) { seed++; sleeptime(1); } }
void player1_task() { player_task_logic(0, com0in, com0out); }
void player2_task() { player_task_logic(1, com1in, com1out); }

/* --- 管理タスク --- */
void manager_task() {
    srand(seed); // ループの外に移動
    while (1) {
        // srand(seed); <-- ここにあったのを削除
        init_game(); 
        is_finish = 0;
        phase[0] = 0; phase[1] = 0;

        fprintf(com0out, "\n=== GAME START ===\n");
        fprintf(com1out, "\n=== GAME START ===\n");
        sleeptime(100); 

        V(0); V(1); 

        while (phase[0] == 0 || phase[1] == 0) { sleeptime(10); }

        fprintf(com0out, "\n判定中...\n");
        fprintf(com1out, "\n判定中...\n");
        sleeptime(1500);

        // intをlongに変更（スコアが大きくなるため）
        long s0 = (long)evaluate_hand(0);
        long s1 = (long)evaluate_hand(1);

        // show_result関数の内部もlongを受け取れるように修正
        void show_result(int me, long s_me, long s_opp) {
            FILE *out = (me == 0) ? com0out : com1out;
            int opp = (me == 0) ? 1 : 0;
            fprintf(out, "\n【結果発表】\n相手の手札: ");
            for(int i=0; i<HAND_SIZE; i++) 
                fprintf(out, "[%s%s] ", mark_str[hand[opp][i].mark], number_str[hand[opp][i].number]);
            
            // 役の判定。100,000,000で割る形に調整
            fprintf(out, "\nあなたの役: %s / 相手の役: %s\n", 
                    poker_role_str[s_me / 100000000], poker_role_str[s_opp / 100000000]);
            
            if (s_me > s_opp)      fprintf(out, ">>> YOU WIN! <<<\n");
            else if (s_me < s_opp) fprintf(out, ">>> YOU LOSE... <<<\n");
            else                   fprintf(out, ">>> DRAW <<<\n");
        }

        show_result(0, s0, s1);
        show_result(1, s1, s0);

        is_finish = 1;
        sleeptime(5000); 
    }
}
/* --- ポーカー基本ロジック --- */

CARD deck[52];
int deck_top = 0;

void init_card() {
    int i, j, k = 0;
    for (i = 1; i <= 4; i++) {
        for (j = 1; j <= 13; j++) {
            deck[k].mark = i; deck[k].number = j; k++;
        }
    }
}

void shuffle_card() {
    int i, r;
    CARD tmp;
    for (i = 51; i > 0; i--) {
        r = rand() % (i + 1);
        tmp = deck[i]; deck[i] = deck[r]; deck[r] = tmp;
    }
}

void fill_card(int ch, int num) {
    P(2);
    if (deck_top < 52) {
        hand[ch][num] = deck[deck_top++];
    }
    V(2);
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
    int counts[15] = {0}, marks[5] = {0};
    int pairs = 0, three = 0, four = 0, flush = 0, straight = 0;
    int pair_val = 0, second_pair_val = 0;
    int sorted[HAND_SIZE];

    for (int i = 0; i < HAND_SIZE; i++) {
        int v = CARD_VAL(hand[ch][i].number);
        counts[v]++;
        marks[hand[ch][i].mark]++;
        sorted[i] = v;
    }

    // ソート（昇順：2, 3, ..., 14）
    for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 5; j++) {
            if (sorted[i] > sorted[j]) {
                int t = sorted[i]; sorted[i] = sorted[j]; sorted[j] = t;
            }
        }
    }

    // 役判定
    for (int i = 14; i >= 2; i--) {
        if (counts[i] == 4) { four = 1; pair_val = i; }
        else if (counts[i] == 3) { three = 1; pair_val = i; }
        else if (counts[i] == 2) { 
            pairs++; 
            if(pair_val == 0) pair_val = i; 
            else second_pair_val = i; 
        }
    }
    
    // A,2,3,4,5ストレートの対応
    if (sorted[0] == 2 && sorted[1] == 3 && sorted[2] == 4 && sorted[3] == 5 && sorted[4] == 14) {
        straight = 1; sorted[4] = 5; // Aを5として扱う
    } else if (sorted[4] - sorted[0] == 4 && pairs == 0 && three == 0) {
        straight = 1;
    }
    for (int i = 1; i <= 4; i++) if (marks[i] == 5) flush = 1;

    // --- 厳密なキッカー計算 ---
    // 16倍ずつ離すことで、上位カードの1の差が下位カードすべてを足したものより強くなります
    long kicker = (long)sorted[4] * 65536 + 
                  (long)sorted[3] * 4096 + 
                  (long)sorted[2] * 256 + 
                  (long)sorted[1] * 16 + 
                  (long)sorted[0];

    // スコア返却（1億単位で役を分離）
    if (straight && flush) return 800000000L + sorted[4];
    if (four)              return 700000000L + (pair_val * 100) + kicker;
    if (three && pairs)    return 600000000L + (pair_val * 100) + kicker; // フルハウス
    if (flush)             return 500000000L + kicker;
    if (straight)          return 400000000L + sorted[4];
    if (three)             return 300000000L + (pair_val * 100) + kicker;
    if (pairs == 2)        return 200000000L + (pair_val * 1000) + (second_pair_val * 100) + kicker;
    if (pairs == 1)        return 100000000L + (pair_val * 1000) + kicker;
    
    return kicker; // ブタ
}
/* --- メイン --- */

/* --- メイン --- */
int main() {
    fd_mapping();
    init_kernel();
    
    semaphore[0].count = 0;
    semaphore[1].count = 0;
    semaphore[2].count = 1; 

    // 【追加箇所】ここでユーザーがキーを押すまで待機し、seedを稼ぐ
    printf("PUSH ANY KEY TO START POKER\n");
    while(inkey(0) == -1) { 
        seed++;     // 高速にカウントアップ
        sleeptime(1); 
    }
    srand(seed); // ここで乱数の基準を確定させる

    set_task(seed_task);
    set_task(player1_task);
    set_task(player2_task);
    set_task(manager_task);

    begin_sch();
    return 0;
}
