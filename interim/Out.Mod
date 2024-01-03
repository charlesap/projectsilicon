MODULE Out;
IMPORT SYSTEM;

  VAR
    NL: INTEGER;
    s: ARRAY 32 OF CHAR;

  PROCEDURE Ln*;
  BEGIN
    SYSTEM.LDREG(1,SYSTEM.ADR(NL)); (* string to print *)
    SYSTEM.LDREG(0,1);		     (* 1 = StdOut *)
    SYSTEM.LDREG(2,1);    	     (* length of our string *)
    SYSTEM.SYSCALL(4);               (* Unix write system call *)
  END Ln;

  PROCEDURE Char*(C: CHAR);
  VAR c: INTEGER;
  BEGIN
    c:=ORD(C);
    SYSTEM.LDREG(1,SYSTEM.ADR(c));
    SYSTEM.LDREG(0,1);		    
    SYSTEM.LDREG(2, 1);    	    
    SYSTEM.SYSCALL(4);              

  END Char;

  PROCEDURE String*(S: ARRAY OF CHAR);
  BEGIN
(*
    s[0]:=S[0];s[1]:=S[1];s[2]:=S[2];s[3]:=S[3];s[4]:=S[4];s[5]:=S[5];s[6]:=S[6];
*)
    SYSTEM.LDREG(1,SYSTEM.ADR("Hello!")); 
    SYSTEM.LDREG(0,1);		   
    SYSTEM.LDREG(2, 6);       
    SYSTEM.SYSCALL(4);             
  END String;

  PROCEDURE Int*(i,c: INTEGER);
  BEGIN
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
    h:=100004080H + g;
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

