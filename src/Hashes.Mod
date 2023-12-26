MODULE Hashes;
IMPORT SYSTEM;

CONST P = 0C24A33059215H;

PROCEDURE H48* (VAR ptr:INTEGER; len:INTEGER):INTEGER;
VAR
  h,i,v:INTEGER;
BEGIN
    h := 0;
    i := 0;
    WHILE i + 7 < len DO
        SYSTEM.GET(ptr+i,v);
        h := h * P + v;
        INC(i,8)
    END;
    IF i + 3 < len THEN
        SYSTEM.GET(ptr+i,v);
        h := h * P + (v MOD 100000000H);
        INC(i,4)
    END;
    v := v DIV 100000000H;
    WHILE i < len DO
      h := h * P + (v MOD 100H); 
      v := v DIV 100H;
      INC(i)
    END;
    h := h * P;
    RETURN h * 10000H DIV 10000H
END H48;

END Hashes.


