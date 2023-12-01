MODULE I;

  CONST s = "This is a string.";

    TYPE Item* = RECORD
      r*: INTEGER;
      s*: REAL;
    END ;

  VAR x,y: INTEGER;

BEGIN
  x:=7;
  IF x = 12 THEN
    y := 3
  ELSE
    y := 4
  END
END I.

