/* csys68k.c */

extern void outbyte0(unsigned char c);  /* 既存 outbyte を outbyte0 にする or ラッパでOK */
extern char inbyte0(void);              /* 既存 inbyte を inbyte0 にする or ラッパでOK */

extern void outbyte1(unsigned char c);  /* 新規：ポート1(UART2)版 */
extern char inbyte1(void);              /* 新規：ポート1(UART2)版 */

/* fd -> port を決める（テキスト例に合わせて fd=4 をポート1にするのが無難） */
static inline int fd_to_port(int fd)
{
  return (fd == 4) ? 1 : 0;  /* 0: UART1(ポート0), 1: UART2(ポート1) */
}

static inline char inbyte_sel(int port)
{
  return (port == 0) ? inbyte0() : inbyte1();
}

static inline void outbyte_sel(int port, unsigned char c)
{
  if (port == 0) outbyte0(c);
  else           outbyte1(c);
}

int read(int fd, char *buf, int nbytes)
{
  char c;
  int  i;
  int  port = fd_to_port(fd);

  for (i = 0; i < nbytes; i++) {
    c = inbyte_sel(port);

    if (c == '\r' || c == '\n'){ /* CR -> CRLF */
      outbyte_sel(port, '\r');
      outbyte_sel(port, '\n');
      buf[i] = '\n';

    } else if (c == '\x7f'){      /* backspace */
      if (i > 0){
        outbyte_sel(port, '\x8'); /* bs  */
        outbyte_sel(port, ' ');   /* spc */
        outbyte_sel(port, '\x8'); /* bs  */
        i--;
      }
      i--;
      continue;

    } else {
      outbyte_sel(port, (unsigned char)c);
      buf[i] = c;
    }

    if (buf[i] == '\n'){
      return (i + 1);
    }
  }
  return i;
}

int write(int fd, char *buf, int nbytes)
{
  int i, j;
  int port = fd_to_port(fd);

  for (i = 0; i < nbytes; i++) {
    if (buf[i] == '\n') {
      outbyte_sel(port, '\r');     /* LF -> CRLF */
    }
    outbyte_sel(port, (unsigned char)buf[i]);
    for (j = 0; j < 300; j++);
  }
  return nbytes;
}
