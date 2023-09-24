MODULE Fonts;

  TYPE Font* = POINTER TO FontDesc;
    FontDesc* = RECORD
      name*: ARRAY 32 OF CHAR;
      height*, minX*, maxX*, minY*, maxY*: INTEGER;
      next*: Font;
      T: ARRAY 128 OF INTEGER;
      raster: ARRAY 2360 OF BYTE
    END ;

  VAR Default*, root*: Font;

BEGIN 
END Fonts.

