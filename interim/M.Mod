MODULE M;
 VAR a, b: INTEGER;
 PROCEDURE F(x, y: INTEGER): INTEGER;
 VAR z: INTEGER;
 BEGIN
 IF x > y THEN z := F(x-y, y)
 ELSIF y > x THEN z := F(y-x, x)
 ELSE z := x
 END ;
 RETURN z
 END F;
 PROCEDURE Q(VAR x, y: INTEGER);
 VAR z: INTEGER;
 BEGIN z := x; x := y; y := z
 END Q;
 PROCEDURE C*;
 BEGIN
   INC(a,1)
 END C;
BEGIN a := F(35, 21); Q(a, b); C
END M.
 
