MODULE Out;
IMPORT SYSTEM;

  PROCEDURE Ln*;
  BEGIN
  END Ln;

  PROCEDURE Char*(c: CHAR);
  BEGIN
    SYSTEM.LDREG(1,SYSTEM.ADR("!")); (* string to print *)
    SYSTEM.LDREG(0,1);		   (* 1 = StdOut *)
(*
    SYSTEM.LDREG(2, 1);    	   (* length of our string *)
    SYSTEM.SYSCALL(4);             (* Unix write system call *)

*)  END Char;

  PROCEDURE String*(s: ARRAY OF CHAR);
  BEGIN
(*
    SYSTEM.LDREG(0,1);		   
    SYSTEM.LDREG(1,SYSTEM.ADR("Hello!")); 
    SYSTEM.LDREG(2, 6);       
    SYSTEM.SYSCALL(4);             
*)
  END String;

  PROCEDURE Int*(i,c: INTEGER);
  BEGIN
  END Int;

  PROCEDURE Hex*(i: INTEGER);
  BEGIN
  END Hex;

BEGIN 
END Out.

