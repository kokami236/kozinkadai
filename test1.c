#include <stdio.h>

/* アセンブリ関数の宣言inkeyテスト */
extern int inkey(int ch);

int main() {
    int c;       /* -1 を判定するため int 型にする */
    int count = 0;

    printf("Start inkey test (channel 0).\n");
    printf("Press any key...\n");

    while(1) {
        /* チャンネル0を確認 */
        c = inkey(0);

        if (c != -1) {
            /* ■ 入力があった場合 (0x00 - 0xFF) */
            /* 戻り値は int なので char にキャストして表示 */
            printf("\nInput: %c\n", (char)c);
            
            /* もし前のコードにあった特定のメモリへの書き込みが必要ならここで行う */
            /* *(char *)0x00d00039 = (char)c; */
        } 
        else {
            /* ■ 入力がない場合 (-1) */
            /* 処理が止まっていないことを可視化するためにドットを表示 */
            printf("."); 
            
            /* 表示が速すぎて見づらい場合は、空ループで少し遅らせても良い */
            /* for(volatile int i=0; i<10000; i++); */
        }
    }

    return 0;
}
/*inbyteテスト
#include <stdio.h>
extern void outbyte (unsigned char c);
extern char inbyte();
int main(){
  char c;
  while(1)
    {
      scanf("%c",&c);
      printf("%c",c);
    }
  return 0;
}
*/
      
