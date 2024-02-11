MODULE I;
IMPORT SYSTEM;

VAR d: INTEGER;

  PROCEDURE P(a,b:INTEGER);
  VAR
    c: INTEGER;
  BEGIN
    IF a = b THEN
      c := 3; d := 4
    ELSE
      c := 5; d := 6
    END
  END P;

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
 P(1,2)
END I.

