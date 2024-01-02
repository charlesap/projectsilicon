MODULE Out;
IMPORT SYSTEM;

  VAR
    MT: ARRAY 32 OF INTEGER; 
    NL: INTEGER;

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

  PROCEDURE String*(s: ARRAY OF CHAR);
  BEGIN
    SYSTEM.LDREG(0,1);		   
    SYSTEM.LDREG(1,SYSTEM.ADR("Hello!")); 
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
    VAR e,f,g:INTEGER;
  BEGIN
    e:=SYSTEM.ATE(0);
    f:=SYSTEM.ATB(0);
    g:=(e-(f+10000C000H))+12;
    SYSTEM.EXIT(0);
    SYSTEM.LDREG(28,SYSTEM.ADR(MT));
    (* SYSTEM.LDREG(28,100004080H); *)
    NL:=0AH;
  END Init;

BEGIN 
END Out.

