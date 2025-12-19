#include <stdio.h>
#include <stdlib.h>
#include "mtk_c.h"
extern char inbyte(int ch);
extern char outbyte(int ch);
// 盤面の行列数
int row = 3;
int col = 3;

// 乱数シード
unsigned int seed;

typedef struct {
    int x;
    int y;
} indicator;

// 共有資源 0 (変更基準の座標)
indicator ch_p;

// 共有資源 1 (盤面)
int matrix[3][3] = {
    {1, 0, 1},
    {0, 1, 0},
    {1, 0, 1}
};

// 共有資源 2 (ゲーム終了フラグ)
int win_flag = 0;

// プレイヤーごとの入力保持用
char input_buf[2];

// カーソルの位置をリセット
void reset_cur(int move) {
    // 枠線の左端にカーソルを戻すエスケープシーケンス
    fprintf(com0out, "\033[%dA", move);
    fprintf(com1out, "\033[%dA", move);
}

// 盤面のリセット
void reset_matrix() {
    // 乱数シードの設定
    srand(seed);
    for (int i = 0; i < row; i++) {
        for (int j = 0; j < col; j++) {
            matrix[i][j] = rand() % 2;
        }
    }
}

// 盤面の描画
void draw_board() {
    // 上枠
    for (int i = 0; i < row + 2; i++) {
        fprintf(com0out, "-");
        fprintf(com1out, "-");
    }
    fprintf(com0out, "\n");
    fprintf(com1out, "\n");

    // 中身
    for (int i = 0; i < row; i++) {
        fprintf(com0out, "|");
        fprintf(com1out, "|");
        for (int j = 0; j < col; j++) {
            fprintf(com0out, "%d", matrix[i][j]);
            fprintf(com1out, "%d", matrix[i][j]);
        }
        fprintf(com0out, "|\n");
        fprintf(com1out, "|\n");
    }

    // 下枠
    for (int i = 0; i < col + 2; i++) {
        fprintf(com0out, "-");
        fprintf(com1out, "-");
    }
    fprintf(com0out, "\n");
    fprintf(com1out, "\n");

    // 描画後、カーソルを盤面の高さ分(5行)戻す
    reset_cur(5);
}

// 指定キーが押されたか判定
int inkey(int ch) {
    char c;
    c = inbyte(ch);

    // 同一キーの連続入力を無視（チャタリング・押しっぱなし防止）
    if (c == input_buf[ch]) {
        return 0;
    }

    // 対応キーの判定
    if (c == '1' || c == '2' || c == '3' ||
        c == 'q' || c == 'w' || c == 'e' ||
        c == 'a' || c == 's' || c == 'd') {
        input_buf[ch] = c;
        return 1; // true
    } else {
        return 0; // false
    }
}

// ゲーム終了条件を判定（全て0、または全て1でクリア）
int check_board() {
    int cnt = 0;
    for (int i = 0; i < row; i++) {
        for (int j = 0; j < col; j++) {
            if (matrix[i][j] == 0) {
                cnt++;
            }
        }
    }
    // 盤面が全て 0 か 1 かを判定
    if (cnt == 0 || cnt == row * col) {
        return 1; // true
    } else {
        return 0; // false
    }
}

// 指定座標の値を反転 (0->1, 1->0)
void rev_matrix(int x, int y) {
    if (matrix[x][y] == 0) {
        matrix[x][y] = 1;
    } else if (matrix[x][y] == 1) {
        matrix[x][y] = 0;
    }
}

// 入力値に従った盤面の変更
void change_board(int ch) {
    char c = input_buf[ch];

    // 入力キーによる座標変換
    switch (c) {
        case '1': ch_p.x = 0; ch_p.y = 0; break;
        case '2': ch_p.x = 0; ch_p.y = 1; break;
        case '3': ch_p.x = 0; ch_p.y = 2; break;
        case 'q': ch_p.x = 1; ch_p.y = 0; break;
        case 'w': ch_p.x = 1; ch_p.y = 1; break;
        case 'e': ch_p.x = 1; ch_p.y = 2; break;
        case 'a': ch_p.x = 2; ch_p.y = 0; break;
        case 's': ch_p.x = 2; ch_p.y = 1; break;
        case 'd': ch_p.x = 2; ch_p.y = 2; break;
        default: return;
    }

    int x = ch_p.x;
    int y = ch_p.y;

    // 中心と上下左右を反転
    rev_matrix(x, y);
    if (x - 1 >= 0) rev_matrix(x - 1, y);
    if (y - 1 >= 0) rev_matrix(x, y - 1);
    if (x + 1 < 3)  rev_matrix(x + 1, y);
    if (y + 1 < 3)  rev_matrix(x, y + 1);

    // 盤面の再描画
    draw_board();

    // 終了判定
    if (check_board()) {
        win_flag = 1;
    }
}

// 乱数シード更新用タスク
void seed_task() {
    while (1) {
        seed = rand();
    }
}

// プレイヤー1の処理
void player1_task() {
    while (1) {
        int ch = 0;
        if (inkey(ch)) {
            P(0); // 変更座標の確保
            P(1); // 盤面の確保
            P(2); // ゲーム終了フラグの確保
            
            change_board(ch);
            
            V(0); // 変更座標の解放
            V(1); // 盤面の解放
            
            if (win_flag) {
                fprintf(com0out, "YOU WIN\n");
                fprintf(com1out, "YOU LOSE\n");
                reset_matrix();
                draw_board();
                win_flag = 0;
            }
            V(2); // ゲーム終了フラグの解放
        }
    }
}

// プレイヤー2の処理
void player2_task() {
    while (1) {
        int ch = 1;
        if (inkey(ch)) {
            P(0); // 変更座標の確保
            P(1); // 盤面確保
            P(2); // ゲーム終了フラグの確保
            
            change_board(ch);
            
            V(0); // 変更座標の解放
            V(1); // 盤面の解放
            
            if (win_flag) {
                fprintf(com0out, "YOU LOSE\n");
                fprintf(com1out, "YOU WIN\n");
                reset_matrix();
                draw_board();
                win_flag = 0;
            }
            V(2); // ゲーム終了フラグの解放
        }
    }
}

int main() {
  fd_mapping();
  // 変更座標の初期化
  ch_p.x = -1;
  ch_p.y = -1;
  init_kernel();
  // 初期盤面の描画
  draw_board();
  // タスクの登録とスケジューリング開始
  set_task(seed_task);
  set_task(player1_task);
  set_task(player2_task);
  begin_sch();
  return 0;
}
