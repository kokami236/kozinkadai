extern void outbyte (unsigned char c);
extern char inbyte();
int main(){
  char c;
  while(1)
    {
      /*c=inbyte();
       *(char *)0x00d00039 =c;*/
      scanf("%c",&c);
      printf("%c",c);
    }
  return 0;
}

      
