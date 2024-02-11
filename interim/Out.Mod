MODULE Out;
IMPORT SYSTEM;

  VAR
    NL: INTEGER;
    X: INTEGER;

  PROCEDURE Ln*;
  BEGIN
    SYSTEM.LDREG(1,SYSTEM.ADR(NL)); (* string to print *)
    SYSTEM.LDREG(0,1);		     (* 1 = StdOut *)
    SYSTEM.LDREG(2,1);    	     (* length of our string *)
    SYSTEM.SYSCALL(4);               (* Unix write system call *)
  END Ln;

  PROCEDURE Char*(C: CHAR);
  VAR i: INTEGER;
  BEGIN
    X:=ORD(C);
    SYSTEM.LDREG(1,SYSTEM.ADR(X));
    SYSTEM.LDREG(0,1);		    
    SYSTEM.LDREG(2,1);    	    
    SYSTEM.SYSCALL(4);              

  END Char;

  PROCEDURE String*(S: ARRAY OF CHAR);
    VAR i,c,l: INTEGER;
  BEGIN
(*    l:=LEN(S); c:=0;
    WHILE c < l DO 
      i:=ORD(S[c]);
*)
      SYSTEM.LDREG(1,SYSTEM.ADR(X)+1); 
      SYSTEM.LDREG(0,1);		   
      SYSTEM.LDREG(2,1);       
      SYSTEM.SYSCALL(4);
(*
      INC(c)
    END     
*)        
  END String;

  PROCEDURE Int*(I,C: INTEGER);
    VAR T: INTEGER;
  BEGIN
      T:=I;
      WHILE T > 0 DO
        X:=T MOD 10;
        SYSTEM.LDREG(1,SYSTEM.ADR(X)); 
        SYSTEM.LDREG(0,1);		   
        SYSTEM.LDREG(2,1);       
        SYSTEM.SYSCALL(4);
        T:=T DIV 10;
      END
  END Int;

  PROCEDURE Hex*(i: INTEGER);
  BEGIN
  END Hex;

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
    NL:=0AH;
  END Init;

BEGIN 
END Out.

