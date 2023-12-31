MODULE Texts; (*JG 21.11.90 / NW 11.7.90 / 24.12.95 / 22.11.10 / 18.11.2014 / 10.1.2019*)
  IMPORT Files, Fonts;

  CONST (*scanner symbol classes*)
    Inval* = 0;         (*invalid symbol*)
    Name* = 1;          (*name s (length len)*)
    String* = 2;        (*literal string s (length len)*)
    Int* = 3;           (*integer i (decimal or hexadecimal)*)
    Real* = 4;          (*real number x*)
    Char* = 6;          (*special character c*)

    (* TextBlock = TextTag offset run {run} "0" len {AsciiCode}.
      run = fnt [name] col voff len. *)

    TAB = 9X; CR = 0DX; NL = 0AX; 
    TextTag = 0F1X;
    replace* = 0; insert* = 1; delete* = 2; unmark* = 3;  (*op-codes*)

  TYPE 
    Piece = POINTER TO PieceDesc;
    PieceDesc = RECORD
      f: Files.File;
      off, len: INTEGER;
      fnt: Fonts.Font;
      col, voff: INTEGER;
      prev, next: Piece
    END;

    Text* = POINTER TO TextDesc;
    Buffer* = POINTER TO BufDesc;

    Filename* = ARRAY 32 OF CHAR;

    Processor* = PROCEDURE (B: Buffer): Buffer;
    Notifier* = PROCEDURE (T: Text; op: INTEGER; beg, end: INTEGER);

    TextDesc* = RECORD
      len*,sent*,lcap*,bcap*: INTEGER; 
      changed*: BOOLEAN;
      notify*: Notifier;
      aproc*: Processor;
      trailer: Piece;
      pce: Piece;  (*cache*)
      org: INTEGER (*cache*)
    END;

    Reader* = RECORD
      eot*: BOOLEAN;
      fnt*: Fonts.Font;
      col*, voff*: INTEGER;
      ref: Piece;
      org: INTEGER;
      off: INTEGER;
      rider: Files.Rider
    END;

    Scanner* = RECORD (Reader)
      nextCh*: CHAR;
      line*, class*: INTEGER;
      i*: INTEGER;
      x*: REAL;
      y*: REAL;
      codepoint*: INTEGER;
      len*: INTEGER;
      s*: ARRAY 32 OF CHAR
    END;

    BufDesc* = RECORD
      len*: INTEGER;
      header, last: Piece
    END;

    Writer* = RECORD
      buf*: Buffer;
      fnt*: Fonts.Font;
      col*, voff*: INTEGER;
      rider: Files.Rider
    END;

    Stream* = RECORD
      in*: Reader;
      out*: Writer
    END;

  VAR TrailerFile: Files.File; tfn: ARRAY 32 OF CHAR;

  (* -------------------- Filing ------------------------*)

  PROCEDURE Trailer(): Piece;
    VAR Q: Piece;
  BEGIN NEW(Q);
    Q.f := TrailerFile; Q.off := -1; Q.len := 1; Q.fnt := NIL; Q.col := 0; Q.voff := 0; RETURN Q
  END Trailer;

  PROCEDURE Load* (VAR R: Files.Rider; T: Text);
    VAR Q, q, p: Piece;
      b: BYTE;
      off: INTEGER;
      N, fno: INTEGER;
      bt: BYTE;
      f: Files.File;
      FName: ARRAY 32 OF CHAR;
      Dict: ARRAY 32 OF Fonts.Font;
  BEGIN 
    f := Files.Base(R); 
    N := 1; Q := Trailer(); p := Q;
    Files.Read(R, b);
    off := b;
    Files.Read(R, bt);
    fno := bt;
    WHILE fno # 0 DO
      IF fno = N THEN
        Files.ReadString(R, FName);
        Dict[N] := NIL; INC(N)   (*  Fonts.This(FName); INC(N)  *)
      END;
      NEW(q); q.fnt := Dict[fno];
      Files.Read(R, bt); q.col := bt;
      Files.Read(R, bt); q.voff := ASR(LSL(bt, -24), 24);
      Files.Read(R, b);
      q.len:=b;
      Files.Read(R, bt); fno := bt;
      q.f := f; q.off := off; off := off + q.len;
      p.next := q; q.prev := p; p := q
    END;
    p.next := Q; Q.prev := p;
    T.trailer := Q; Files.Read(R, b); (*Files.Set(R, f, Files.Pos(R) + T.len)*)
    T.len:=b;
  END Load;

  PROCEDURE Open* (T: Text; name: Filename );
    VAR f: Files.File; R: Files.Rider; Q, q: Piece;
      tag: CHAR; i, len: INTEGER; b: BYTE; fn: ARRAY 32 OF CHAR;
  BEGIN 
    i:=0; WHILE (i < 31) DO IF i<LEN(name) THEN fn[i]:=name[i] END; INC(i) END; fn[31]:=0X; 
    f := Files.Old(fn);
    IF f # NIL THEN
      Files.Set(R, f, 0); Files.Read(R, b);
      tag:=CHR(b); 
      IF tag = TextTag THEN Load(R, T)
      ELSE (*Ascii file*)
        len := Files.Length(f); Q := Trailer();
        NEW(q); q.fnt := NIL;  (* := Fonts.This("DVSansMono16.Scn.Fnt"); *) (*Fonts.Default*); q.col := 1; q.voff := 0; q.f := f; q.off := 0; q.len := len;
        Q.next := q; q.prev := Q; q.next := Q; Q.prev := q; T.trailer := Q; T.len := len
      END
    ELSE (*create new text*)
      Q := Trailer(); Q.next := Q; Q.prev := Q; T.trailer := Q; T.len := 0
    END ;
    T.changed := FALSE; T.org := -1; T.pce := T.trailer; (*init cache*) T.lcap := -1; T.bcap := -1
  END Open;

  PROCEDURE Store* (VAR W: Files.Rider; T: Text);
    VAR p, q: Piece;
      R: Files.Rider;
      off, rlen, pos, i: INTEGER;
      N, n: INTEGER;
      ch: CHAR; b: BYTE;
      Dict: ARRAY 32, 32 OF CHAR;
  BEGIN pos := Files.Pos(W); Files.WriteInt(W, 0); (*place holder*)
    N := 1; p := T.trailer.next;
    WHILE p # T.trailer DO
      rlen := p.len; q := p.next;
      WHILE (q # T.trailer) & (q.fnt = p.fnt) & (q.col = p.col) & (q.voff = p.voff) DO
        rlen := rlen + q.len; q := q.next
      END;
      i:=0; WHILE (i<32) DO Dict[n][i]:=p.fnt.name[i]; INC(i)  END; (*Dict[N] := p.fnt.name;*)
      n := 1;
      WHILE Dict[n] # p.fnt.name DO INC(n) END;
      Files.Write(W, n);
      IF n = N THEN Files.WriteString(W, p.fnt.name); INC(N) END;
      Files.Write(W, p.col); Files.Write(W, p.voff); Files.WriteInt(W, rlen);
      p := q
    END;
    Files.Write(W, 0); Files.WriteInt(W, T.len);
    off := Files.Pos(W); p := T.trailer.next;
    WHILE p # T.trailer DO
      rlen := p.len; Files.Set(R, p.f, p.off);
      WHILE rlen > 0 DO Files.Read(R, b); Files.Write(W, b); DEC(rlen) END ;
      p := p.next
    END ;
    Files.Set(W, Files.Base(W), pos); Files.WriteInt(W, off); (*fixup*)
    T.changed := FALSE;
    IF T.notify # NIL THEN T.notify(T, unmark, 0, 0) END
  END Store;

  PROCEDURE Close*(T: Text; name: ARRAY OF CHAR);
    VAR f: Files.File; w: Files.Rider; i: INTEGER; fn: ARRAY 32 OF CHAR;
  BEGIN
    i:=0; WHILE (i < 31) DO IF i<LEN(name) THEN fn[i]:=name[i] END; INC(i) END; fn[31]:=0X; 
    f := Files.New(fn); 
    Files.Set(w, f, 0);
    Files.Write(w, ORD(TextTag)); Store(w, T); Files.Register(f)
  END Close;

  (* -------------------- Editing ----------------------- *)

  PROCEDURE OpenBuf* (B: Buffer);
  BEGIN NEW(B.header); (*null piece*)
    B.last := B.header; B.len := 0
  END OpenBuf;

  PROCEDURE FindPiece (T: Text; pos: INTEGER; VAR org: INTEGER; VAR pce: Piece);
    VAR p: Piece; porg: INTEGER;
  BEGIN p := T.pce; porg := T.org;
    IF pos >= porg THEN
      WHILE pos >= porg + p.len DO INC(porg, p.len); p := p.next END
    ELSE p := p.prev; DEC(porg, p.len);
      WHILE pos < porg DO p := p.prev; DEC(porg, p.len) END
    END ;
    T.pce := p; T.org := porg;  (*update cache*)
    pce := p; org := porg
  END FindPiece;

  PROCEDURE SplitPiece (p: Piece; off: INTEGER; VAR pr: Piece);
    VAR q: Piece;
  BEGIN
    IF off > 0 THEN NEW(q);
      q.fnt := p.fnt; q.col := p.col; q.voff := p.voff;
      q.len := p.len - off;
      q.f := p.f; q.off := p.off + off;
      p.len := off;
      q.next := p.next; p.next := q;
      q.prev := p; q.next.prev := q;
      pr := q
    ELSE pr := p
    END
  END SplitPiece;

  PROCEDURE Save* (T: Text; beg, end: INTEGER; B: Buffer);
    VAR p, q, qb, qe: Piece; org: INTEGER;
  BEGIN
    IF end > T.len THEN end := T.len END;
    FindPiece(T, beg, org, p);
    NEW(qb); qb^ := p^;
    qb.len := qb.len - (beg - org);
    qb.off := qb.off + (beg - org);
    qe := qb;
    WHILE end > org + p.len DO 
      org := org + p.len; p := p.next;
      NEW(q); q^ := p^; qe.next := q; q.prev := qe; qe := q
    END;
    qe.next := NIL; qe.len := qe.len - (org + p.len - end);
    B.last.next := qb; qb.prev := B.last; B.last := qe;
    B.len := B.len + (end - beg)
  END Save;

  PROCEDURE Copy* (SB, DB: Buffer);
    VAR Q, q, p: Piece;
  BEGIN p := SB.header; Q := DB.last;
    WHILE p # SB.last DO p := p.next;
      NEW(q); q^ := p^; Q.next := q; q.prev := Q; Q := q
    END;
    DB.last := Q; DB.len := DB.len + SB.len
  END Copy;

  PROCEDURE Insert* (T: Text; pos: INTEGER; B: Buffer);
    VAR pl, pr, p, qb, qe: Piece; org, end: INTEGER;
  BEGIN
    FindPiece(T, pos, org, p); SplitPiece(p, pos - org, pr);
    IF T.org >= org THEN T.org := org - p.prev.len; T.pce := p.prev END ;
    pl := pr.prev; qb := B.header.next;
    IF (qb # NIL) & (qb.f = pl.f) & (qb.off = pl.off + pl.len)
        & (qb.fnt = pl.fnt) & (qb.col = pl.col) & (qb.voff = pl.voff) THEN
      pl.len := pl.len + qb.len; qb := qb.next
    END;
    IF qb # NIL THEN qe := B.last;
      qb.prev := pl; pl.next := qb; qe.next := pr; pr.prev := qe
    END;
    T.len := T.len + B.len; end := pos + B.len;
    B.last := B.header; B.last.next := NIL; B.len := 0;
    T.changed := TRUE;
    IF T.notify # NIL THEN  T.notify(T, insert, pos, end) END
  END Insert;

  PROCEDURE FromBuffer* (T: Text; B: Buffer);
    VAR (* f: Files.File; R: Files.Rider; *) Q, q: Piece; 
      (* tag: CHAR; len: INTEGER; *)
  BEGIN (* f := NIL *)
    (*create new text*)
    Q := Trailer(); Q.next := Q; Q.prev := Q; T.trailer := Q; T.len := 0;
    T.changed := FALSE; T.org := -1; T.pce := T.trailer; (*init cache*) T.lcap := -1; T.bcap := -1;
    Insert(T,0,B)
  END FromBuffer;

  PROCEDURE Append* (T: Text; B: Buffer);
  BEGIN
    IF T.aproc # NIL THEN 
      Insert(T, T.len, T.aproc(B)) 
    ELSE 
      Insert(T, T.len, B)
    END
  END Append;

  PROCEDURE Delete* (T: Text; beg, end: INTEGER; B: Buffer);
    VAR pb, pe, pbr, per: Piece; orgb, orge: INTEGER;
  BEGIN
    IF end > T.len THEN end := T.len END;
    FindPiece(T, beg, orgb, pb); SplitPiece(pb, beg - orgb, pbr);
    FindPiece(T, end, orge, pe);
    SplitPiece(pe, end - orge, per);
    IF T.org >= orgb THEN (*adjust cache*)
      T.org := orgb - pb.prev.len; T.pce := pb.prev
    END;
    B.header.next := pbr; B.last := per.prev;
    B.last.next := NIL; B.len := end - beg;
    per.prev := pbr.prev; pbr.prev.next := per;
    T.len := T.len - B.len;
    T.changed := TRUE;
    IF T.notify # NIL THEN T.notify(T, delete, beg, end) END
  END Delete;

  PROCEDURE ChangeLooks* (T: Text; beg, end: INTEGER; sel: SET; fnt: Fonts.Font; col, voff: INTEGER);
    VAR pb, pe, p: Piece; org: INTEGER;
  BEGIN
    IF end > T.len THEN end := T.len END;
    FindPiece(T, beg, org, p); SplitPiece(p, beg - org, pb);
    FindPiece(T, end, org, p); SplitPiece(p, end - org, pe);
    p := pb;
    REPEAT
      IF 0 IN sel THEN p.fnt := fnt END;
      IF 1 IN sel THEN p.col := col END;
      IF 2 IN sel THEN p.voff := voff END;
      p := p.next
    UNTIL p = pe;
    T.changed := TRUE;
    IF T.notify # NIL THEN T.notify(T, replace, beg, end) END
  END ChangeLooks;

  PROCEDURE Attributes*(T: Text; pos: INTEGER; VAR fnt: Fonts.Font; VAR col, voff: INTEGER);
    VAR p: Piece; org: INTEGER;
  BEGIN FindPiece(T, pos, org, p); fnt := p.fnt; col := p.col; voff := p.voff
  END Attributes;

  (* ------------------ Access: Readers ------------------------- *)

  PROCEDURE OpenReader* (VAR R: Reader; T: Text; pos: INTEGER);
    VAR p: Piece; org: INTEGER;
  BEGIN FindPiece(T, pos, org, p);
    R.ref := p; R.org := org; R.off := pos - org;
    Files.Set(R.rider, p.f, p.off + R.off); R.eot := FALSE
  END OpenReader;

  PROCEDURE Read* (VAR R: Reader; VAR ch: CHAR);
    VAR b: BYTE;
  BEGIN Files.Read(R.rider, b); ch:=CHR(b);
    R.fnt := R.ref.fnt; R.col := R.ref.col; R.voff := R.ref.voff;
    INC(R.off);
    IF R.off = R.ref.len THEN
      IF R.ref.f = TrailerFile THEN R.eot := TRUE END;
      R.ref := R.ref.next; R.org := R.org + R.off; R.off := 0;
      Files.Set(R.rider, R.ref.f, R.ref.off)
    END
  END Read;

  PROCEDURE UnicodeWidth* (codepoint: INTEGER): INTEGER;
  VAR result: INTEGER;
  BEGIN
    IF codepoint < 80H THEN result := 1
    ELSIF codepoint < 800H THEN result := 2
    ELSIF codepoint < 10000H THEN result := 3
    ELSE result := 4 END;
  RETURN result
  END UnicodeWidth;

  PROCEDURE ReadUnicodeRest(VAR R: Reader; ch: CHAR; VAR codepoint: INTEGER);
  VAR i, more: INTEGER;
  BEGIN
    IF ORD(ch) < 80H THEN
      codepoint := ORD(ch); more := 0;
    ELSIF ORD(ch) < 0C0H THEN
      codepoint := 0FFFDH; more := 0;
    ELSIF ORD(ch) < 0E0H THEN
      codepoint := ORD(ch) MOD 20H; more := 1;
    ELSIF ORD(ch) < 0F0H THEN
      codepoint := ORD(ch) MOD 10H; more := 2;
    ELSIF ORD(ch) < 0F8H THEN
      codepoint := ORD(ch) MOD 08H; more := 3;
    ELSE
      codepoint := 0FFFDH; more := 0;
    END;
    FOR i := 1 TO more DO
      IF ~R.eot THEN Read(R, ch) END;
      codepoint := codepoint * 40H + (ORD(ch) MOD 40H)
    END;
    IF R.eot & (more > 0) THEN codepoint := 0FFFDH END;
  END ReadUnicodeRest;

  PROCEDURE ReadUnicode* (VAR R: Reader; VAR codepoint: INTEGER);
  VAR ch: CHAR;
  BEGIN Read(R, ch); ReadUnicodeRest(R, ch, codepoint)
  END ReadUnicode;


  PROCEDURE Pos* (VAR R: Reader): INTEGER;
  BEGIN RETURN R.org + R.off
  END Pos;  



  (* ------------------ Access: Scanners (NW) ------------------------- *)

  PROCEDURE OpenScanner* (VAR S: Scanner; T: Text; pos: INTEGER);
  BEGIN OpenReader(S, T, pos); S.line := 0; S.nextCh := " "
  END OpenScanner;

  PROCEDURE ScannerFromReader* (VAR S: Scanner; R: Reader);
  BEGIN 
    S.ref := R.ref; S.org := R.org; S.off := R.off; 
    Files.Set(S.rider, S.ref.f, S.ref.off + S.off); S.eot := FALSE;
    S.line := 0; S.nextCh := " "
  END ScannerFromReader;

  (*floating point formats:
    x = 1.m * 2^(e-127)   bit 0: sign, bits 1- 8: e, bits  9-31: m
    x = 1.m * 2^(e-1023)  bit 0: sign, bits 1-11: e, bits 12-63: m *)

  PROCEDURE Ten(n: INTEGER): REAL;
    VAR t, p: REAL;
  BEGIN t := 1.0; p := 10.0;   (*compute 10^n *)
    WHILE n > 0 DO
      IF ODD(n) THEN t := p * t END ;
      p := p*p; n := n DIV 2
    END ;
    RETURN t
  END Ten;

  PROCEDURE Scan* (VAR S: Scanner);
    CONST maxExp = 38; maxM = 16777216; (*2^24*)
    VAR ch: CHAR;
      neg, negE, hex: BOOLEAN;
      i, j, h, d, e, n, s: INTEGER;
      x: REAL;
  BEGIN ch := S.nextCh; i := 0;
    WHILE (ch = " ") OR (ch = TAB) OR (ch = NL) OR (ch = CR) DO
      IF (ch = CR) OR (ch = NL) THEN INC(S.line) END ;
      Read(S, ch)
    END ;
    IF ("A" <= ch) & (ch <= "Z") OR ("a" <= ch) & (ch <= "z") THEN (*name*)
      REPEAT S.s[i] := ch; INC(i); Read(S, ch)
      UNTIL ((ch < "0") & (ch # ".") OR ("9" < ch) & (ch < "A") OR ("Z" < ch) & (ch < "a") OR ("z" < ch)) OR (i = 31);
      S.s[i] := 0X; S.len := i; S.class := Name
    ELSIF ch = 22X THEN (*string*)
      Read(S, ch);
      WHILE (ch # 22X) & (ch >= " ") & (i # 31) DO S.s[i] := ch; INC(i); Read(S, ch) END;
      S.s[i] := 0X; S.len := i+1; Read(S, ch); S.class := String
    ELSE hex := FALSE;
      IF ch = "-" THEN neg := TRUE; Read(S, ch) ELSE neg := FALSE END ;
      IF ("0" <= ch) & (ch <= "9") THEN (*number*)
        n := ORD(ch) - 30H; h := n; Read(S, ch);
        WHILE ("0" <= ch) & (ch <= "9") OR ("A" <= ch) & (ch <= "F") DO
          IF ch <= "9" THEN d := ORD(ch) - 30H ELSE d := ORD(ch) - 37H; hex := TRUE END ;
          n := 10*n + d; h := 10H*h + d; Read(S, ch)
        END ;
        IF ch = "H" THEN (*hex integer*) Read(S, ch); S.i := h; S.class := Int  (*neg?*)
        ELSIF ch = "." THEN (*real number*)
          Read(S, ch); x := 0.0; e := 0; j := 0;
          WHILE ("0" <= ch) & (ch <= "9") DO  (*fraction*)
            h := 10*n + (ORD(ch) - 30H);
            IF h < maxM THEN n := h; INC(j) END ;
            Read(S, ch)
          END ;
          IF ch = "E" THEN (*scale factor*)
            s := 0; Read(S, ch);
            IF ch = "-" THEN negE := TRUE; Read(S, ch)
            ELSE negE := FALSE;
              IF ch = "+" THEN Read(S, ch) END
            END ;
            WHILE ("0" <= ch) & (ch <= "9") DO
              s := s*10 + ORD(ch) - 30H; Read(S, ch)
            END ;
            IF negE THEN DEC(e, s) ELSE INC(e, s) END ;
          END ;
          x := FLT(n); DEC(e, j);
          IF e < 0 THEN
            IF e >= -maxExp THEN x := x / Ten(-e) ELSE x := 0.0 END
          ELSIF e > 0 THEN
            IF e <= maxExp THEN x := Ten(e) * x ELSE x := 0.0 END
          END ;
          IF neg THEN S.x := -x ELSE S.x := x END ;
          IF hex THEN S.class := 0 ELSE S.class := Real END
        ELSE (*decimal integer*)
          IF neg THEN S.i := -n ELSE S.i := n END;
          IF hex THEN S.class := Inval ELSE S.class := Int END
        END
      ELSE (*spectal character*) S.class := Char;
        IF neg THEN S.codepoint := ORD("-") ELSE ReadUnicodeRest(S, ch, S.codepoint); Read(S, ch) END
      END
    END ;
    S.nextCh := ch
  END Scan;

  (* --------------- Access: Writers (NW) ------------------ *)

  PROCEDURE OpenWriter* (VAR W: Writer);
    VAR fn: ARRAY 32 OF CHAR;
  BEGIN NEW(W.buf);
    OpenBuf(W.buf); W.fnt := Fonts.Default; W.col := 15; W.voff := 0;
    fn[0]:=0X;
    Files.Set(W.rider, Files.New(fn), 0)
  END OpenWriter;

  PROCEDURE SetFont* (VAR W: Writer; fnt: Fonts.Font);
  BEGIN W.fnt := fnt
  END SetFont;

  PROCEDURE SetColor* (VAR W: Writer; col: INTEGER);
  BEGIN W.col := col
  END SetColor;

  PROCEDURE SetOffset* (VAR W: Writer; voff: INTEGER);
  BEGIN W.voff := voff
  END SetOffset;

  PROCEDURE Write* (VAR W: Writer; ch: CHAR);
    VAR p: Piece; b: BYTE;
  BEGIN
    IF (W.buf.last.fnt # W.fnt) OR (W.buf.last.col # W.col) OR (W.buf.last.voff # W.voff) THEN
      NEW(p); p.f := Files.Base(W.rider); p.off := Files.Pos(W.rider); p.len := 0;
      p.fnt := W.fnt; p.col := W.col; p.voff:= W.voff;
      p.next := NIL; W.buf.last.next := p;
      p.prev := W.buf.last; W.buf.last := p
    END;
    b:=ORD(ch);
    Files.Write(W.rider, b);
    INC(W.buf.last.len); INC(W.buf.len)
  END Write;

  PROCEDURE WriteUnicode* (VAR W: Writer; codepoint: INTEGER);
  BEGIN
    IF codepoint < 80H THEN
      Write(W, CHR(codepoint))
    ELSIF codepoint < 800H THEN
      Write(W, CHR(0C0H + (codepoint DIV 40H MOD 20H)));
      Write(W, CHR(080H + (codepoint MOD 40H)))
    ELSIF codepoint < 10000H THEN
      Write(W, CHR(0E0H + (codepoint DIV 1000H MOD 10H)));
      Write(W, CHR(080H + (codepoint DIV 40H MOD 40H)));
      Write(W, CHR(080H + (codepoint MOD 40H)))
    ELSE
      Write(W, CHR(0F0H + (codepoint DIV 40000H MOD 08H)));
      Write(W, CHR(080H + (codepoint DIV 1000H MOD 40H)));
      Write(W, CHR(080H + (codepoint DIV 40H MOD 40H)));
      Write(W, CHR(080H + (codepoint MOD 40H)))
    END
  END WriteUnicode;


  PROCEDURE WriteLn* (VAR W: Writer);
  BEGIN Write(W, NL)
  END WriteLn;

  PROCEDURE WriteString* (VAR W: Writer; s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE s[i] >= " " DO Write(W, s[i]); INC(i) END
  END WriteString;

  PROCEDURE WriteInt* (VAR W: Writer; x, n: INTEGER);
    VAR i: INTEGER; x0: INTEGER;
      a: ARRAY 10 OF CHAR;
  BEGIN
    IF ROR(x, 31) = 1 THEN WriteString(W, " -2147483648")
    ELSE i := 0;
      IF x < 0 THEN DEC(n); x0 := -x ELSE x0 := x END;
      REPEAT
        a[i] := CHR(x0 MOD 10 + 30H); x0 := x0 DIV 10; INC(i)
      UNTIL x0 = 0;
      WHILE n > i DO Write(W, " "); DEC(n) END;
      IF x < 0 THEN Write(W, "-") END;
      REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
    END
  END WriteInt;

  PROCEDURE WriteHex* (VAR W: Writer; x: INTEGER);
    VAR i: INTEGER; y: INTEGER;
      a: ARRAY 10 OF CHAR;
  BEGIN i := 0; Write(W, " ");
    REPEAT y := x MOD 10H;
      IF y < 10 THEN a[i] := CHR(y + 30H) ELSE a[i] := CHR(y + 37H) END;
      x := x DIV 10H; INC(i)
    UNTIL i = 8;
    REPEAT DEC(i); Write(W, a[i]) UNTIL i = 0
  END WriteHex;


  PROCEDURE WritePair(VAR W: Writer; ch: CHAR; x: INTEGER);
  BEGIN Write(W, ch);
    Write(W, CHR(x DIV 10 + 30H)); Write(W, CHR(x MOD 10 + 30H))
  END WritePair;

  PROCEDURE WriteClock* (VAR W: Writer; d: INTEGER);
  BEGIN
    WritePair(W, " ", d DIV 20000H MOD 20H);   (*day*)
    WritePair(W, ".", d DIV 400000H MOD 10H); (*month*)
    WritePair(W, ".", d DIV 4000000H MOD 40H);   (*year*)
    WritePair(W, " ", d DIV 1000H MOD 20H);   (*hour*)
    WritePair(W, ":", d DIV 40H MOD 40H);  (*min*)
    WritePair(W, ":", d MOD 40H)  (*sec*)
  END WriteClock;

  PROCEDURE Pipe*(VAR I: Text; VAR O: Text; P: Processor );
  BEGIN
  END Pipe;

  PROCEDURE OpenStream* (VAR S: Stream; T: Text; pos: INTEGER);
  BEGIN
    OpenReader(S.in,T,pos);
    OpenWriter(S.out)
  END OpenStream;

  PROCEDURE UpdateStream* (VAR S: Stream);
  BEGIN
    
    
  END UpdateStream;


BEGIN tfn[0]:=0X; TrailerFile := Files.New(tfn)
END Texts.


