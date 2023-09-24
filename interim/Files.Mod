MODULE Files;

  TYPE  DiskAdr = INTEGER;
      File*    = POINTER TO FileDesc;
      Buffer  = POINTER TO BufferRecord;
      Index   = POINTER TO IndexRecord;

    Rider* =
      RECORD eof*: BOOLEAN;
        res*: INTEGER;
        file: File;
        apos, bpos: INTEGER;
        buf: Buffer
      END ;

    FileDesc =
      RECORD next: INTEGER; (*list of files invisible to the GC*)
(*
        nofbufs, aleng, bleng: INTEGER;
        modH, registered: BOOLEAN;
        firstbuf: Buffer;
        sechint: DiskAdr;
        name: FileDir.FileName;
        date: INTEGER;
        ext:  ARRAY FileDir.ExTabSize OF Index;
        sec: FileDir.SectorTable
*)
      END ;

    BufferRecord =
      RECORD apos, lim: INTEGER;
        mod: BOOLEAN;
        next: Buffer;
(*
        data: FileDir.DataSector
*)
      END ;

    IndexRecord =
      RECORD adr: DiskAdr;
        mod: BOOLEAN;
(*  
        sec: FileDir.IndexSector
*)
      END ;

  PROCEDURE Old*(name: ARRAY OF CHAR): File;
    VAR 
      f: File;
  BEGIN f := NIL; 
    RETURN f
  END Old;

  PROCEDURE New*(name: ARRAY OF CHAR): File;
    VAR 
      f: File;
  BEGIN f := NIL; 
    RETURN f
  END New;

  PROCEDURE Register*(f: File);
  BEGIN
  END Register;

  PROCEDURE Length*(f: File): INTEGER;
  BEGIN RETURN 0
  END Length;

  PROCEDURE Set*(VAR r: Rider; f: File; pos: INTEGER);
  BEGIN
  END Set;

  PROCEDURE Pos*(VAR r: Rider): INTEGER;
  BEGIN RETURN 0 
  END Pos;

  PROCEDURE Base*(VAR r: Rider): File;
  BEGIN RETURN r.file
  END Base;

  PROCEDURE Read*(VAR r: Rider; VAR x: BYTE);
  BEGIN
  END Read;

  PROCEDURE ReadInt*(VAR R: Rider; VAR x: INTEGER);
    VAR x0, x1, x2, x3: BYTE;
  BEGIN Read(R, x0); Read(R, x1); Read(R, x2); Read(R, x3);
    x := ((x3 * 100H + x2) * 100H + x1) * 100H + x0
  END ReadInt;

  PROCEDURE ReadString*(VAR R: Rider; VAR x: ARRAY OF CHAR);
  BEGIN
    x[0] := 0X
  END ReadString;

  PROCEDURE ReadNum*(VAR R: Rider; VAR x: INTEGER);
    VAR n, y: INTEGER; b: BYTE;
  BEGIN n := 32; y := 0; Read(R, b);
    WHILE b >= 80H DO y := ROR(y + b-80H, 7); DEC(n, 7); Read(R, b) END ;
    IF n <= 4 THEN x := ROR(y + b MOD 10H, 4) ELSE x := ASR(ROR(y + b, 7), n-7) END
  END ReadNum;

  PROCEDURE Write*(VAR r: Rider; x: BYTE);
  BEGIN
  END Write;

  PROCEDURE WriteChar*(VAR r: Rider; ch: CHAR);
  BEGIN (*same as WriteByte*)
  END WriteChar;

  PROCEDURE WriteString*(VAR R: Rider; x: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN i := 0;
    REPEAT ch := x[i]; WriteChar(R, ch); INC(i) UNTIL ch = 0X
  END WriteString;

  PROCEDURE WriteInt*(VAR R: Rider; x: INTEGER);
  BEGIN Write(R, x MOD 100H);
    Write(R, x DIV 100H MOD 100H);
    Write(R, x DIV 10000H MOD 100H);
    Write(R, x DIV 1000000H MOD 100H)
  END WriteInt;

  PROCEDURE WriteNum*(VAR R: Rider; x: INTEGER);
  BEGIN
    WHILE (x < -40H) OR (x >= 40H) DO Write(R, x MOD 80H + 80H); x := ASR(x, 7) END ;
    Write(R, x MOD 80H)
  END WriteNum;

BEGIN 
END Files.

