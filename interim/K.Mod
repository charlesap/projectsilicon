MODULE K;
IMPORT SYSTEM;

VAR X,RFD,WFD,EFD: INTEGER;
    TV: ARRAY 2 OF INTEGER;
    BUF: ARRAY 1024 OF BYTE;

  PROCEDURE OutCh*(C: CHAR);
  VAR i: INTEGER;
  BEGIN
    SYSTEM.PUT(SYSTEM.ADR(X),C);
    SYSTEM.LDREG(1,SYSTEM.ADR(X));
    SYSTEM.LDREG(0,1);
    SYSTEM.LDREG(2,1);
    SYSTEM.SYSCALL(4);
  END OutCh;

  PROCEDURE InCh*():CHAR;
  VAR i: INTEGER; C: CHAR;
  BEGIN
    SYSTEM.LDREG(1,SYSTEM.ADR(X));
    SYSTEM.LDREG(0,0);
    SYSTEM.LDREG(2,1);
    SYSTEM.SYSCALL(3);
    SYSTEM.GET(SYSTEM.ADR(X),i);
    SYSTEM.PUT(SYSTEM.ADR(C),X);
  RETURN C
  END InCh;

  PROCEDURE OutBuf*(S: ARRAY OF CHAR);
  VAR i: INTEGER;
  BEGIN
    
    SYSTEM.LDREG(1,SYSTEM.ADR(BUF));
    SYSTEM.LDREG(0,1);
    SYSTEM.LDREG(2,1);
    SYSTEM.SYSCALL(4);
  END OutBuf;

  PROCEDURE InBuf*(VAR S: ARRAY OF CHAR);
  VAR i: INTEGER; C: CHAR;
  BEGIN
    SYSTEM.LDREG(1,SYSTEM.ADR(BUF));
    SYSTEM.LDREG(0,0);
    SYSTEM.LDREG(2,1);
    SYSTEM.SYSCALL(3);
    SYSTEM.GET(SYSTEM.ADR(X),i);
    SYSTEM.PUT(SYSTEM.ADR(C),X);
  END InBuf;


  PROCEDURE select():INTEGER;
  VAR n: INTEGER;
  BEGIN
    SYSTEM.PUT(SYSTEM.ADR(RFD),0);
    SYSTEM.PUT(SYSTEM.ADR(WFD),1);
    SYSTEM.PUT(SYSTEM.ADR(EFD),2);
    SYSTEM.PUT(SYSTEM.ADR(TV[0]),0);
    SYSTEM.PUT(SYSTEM.ADR(TV[1]),0);
    SYSTEM.LDREG(4,SYSTEM.ADR(TV));
    SYSTEM.LDREG(3,SYSTEM.ADR(EFD));
    SYSTEM.LDREG(2,SYSTEM.ADR(WFD));
    SYSTEM.LDREG(1,SYSTEM.ADR(RFD));
    SYSTEM.LDREG(0,1); (*nfds*)
    SYSTEM.SYSCALL(93);
    n:=SYSTEM.REG(0);
  RETURN n
  END select;

  PROCEDURE Init*;
    VAR e,f,g,h,i,j:INTEGER;
  BEGIN
    e:=SYSTEM.ATE(0);
    f:=SYSTEM.ATB(0);
    g:=(e-(f+10000C000H))+12;
    h:=g + 100004080H;
    SYSTEM.LDREG(28,h);
    SYSTEM.GET(h,i);
    WHILE i > 0 DO
      h:=h+8;
      SYSTEM.GET(h,j);
      j:=j+g;
      SYSTEM.PUT(h,j);
      DEC(i)
    END;
  END Init;

BEGIN
  Init;
  OutCh(0AX);
  OutCh(">");
  OutCh(InCh());
  OutCh(0AX);
END K.

