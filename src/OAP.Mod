MODULE OAP; (*N. Wirth 1.7.97 / 8.3.2020, CP 2023 Oberon compiler for Arm 64-bit in Oberon-07*)
  IMPORT Out, Texts, OAS, OAB, OAL, OAG;
  (*Author: Niklaus Wirth, 2014.
    Parser of Oberon compiler. Uses Scanner OAS to obtain symbols (tokens),
    OAB for definition of data structures and for handling import and export, and
    OAG to produce binary code. OAP performs type checking and data allocation.
    Parser is target-independent, except for part of the handling of allocations.*)

  TYPE PtrBase = POINTER TO PtrBaseDesc;
    PtrBaseDesc = RECORD  (*list of names of pointer base types*)
      name: OAS.Ident; type: OAB.Type; next: PtrBase
    END ;
    FileName* = ARRAY 32 OF CHAR;
    Options* = ARRAY 8 OF CHAR;
 
  VAR sym: INTEGER;   (*last symbol read*)
    dc: INTEGER;    (*data counter*)
    level, exno, version: INTEGER;
    newSF: BOOLEAN;  (*option flag*)
    verbose: BOOLEAN;  (*option flag*)
    ccFMT, ccWordsize, ccStackalign: INTEGER;
    expression: PROCEDURE (VAR x: OAG.Item);  (*to avoid forward reference*)
    Type: PROCEDURE (VAR type: OAB.Type);
    FormalType: PROCEDURE (VAR typ: OAB.Type; dim: INTEGER);
    modid: OAS.Ident;
    pbsList: PtrBase;   (*list of names of pointer base types*)
    dummy: OAB.Object;

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 128 OF CHAR; 
  BEGIN ss:=s; Out.String(ss);
  END Emit;

  PROCEDURE EmitLn;
  BEGIN Out.Ln
  END EmitLn;

  PROCEDURE Check(s: INTEGER; msg: ARRAY OF CHAR);
  BEGIN
    IF sym = s THEN OAS.Get(sym) ELSE OAS.Mark(msg) END
  END Check;

  PROCEDURE qualident(VAR obj: OAB.Object);
  BEGIN obj := OAB.thisObj(); OAS.Get(sym);
    IF obj = NIL THEN OAS.Mark("undef"); obj := dummy END ;
    IF (sym = OAS.period) & (obj.class = OAB.Mod) THEN
      OAS.Get(sym);
      IF sym = OAS.ident THEN obj := OAB.thisimport(obj); OAS.Get(sym);
        IF obj = NIL THEN OAS.Mark("undef"); obj := dummy END
      ELSE OAS.Mark("identifier expected"); obj := dummy
      END
    END
  END qualident;

  PROCEDURE CheckBool(VAR x: OAG.Item);
  BEGIN
    IF x.type.form # OAB.Bool THEN OAS.Mark("not Boolean"); x.type := OAB.boolType END
  END CheckBool;

  PROCEDURE CheckInt(VAR x: OAG.Item);
  BEGIN
    IF x.type.form # OAB.Int THEN OAS.Mark("not Integer"); x.type := OAB.intType END
  END CheckInt;

  PROCEDURE CheckReal(VAR x: OAG.Item);
  BEGIN
    IF x.type.form # OAB.Real THEN OAS.Mark("not Real"); x.type := OAB.realType END
  END CheckReal;

  PROCEDURE CheckSet(VAR x: OAG.Item);
  BEGIN
    IF x.type.form # OAB.Set THEN OAS.Mark("not Set"); x.type := OAB.setType END 
  END CheckSet;

  PROCEDURE CheckSetVal(VAR x: OAG.Item);
  BEGIN
    IF x.type.form # OAB.Int THEN OAS.Mark("not Int"); x.type := OAB.setType
    ELSIF x.mode = OAB.Const THEN
      IF (x.a < 0) OR (x.a >= 32) THEN OAS.Mark("invalid set") END
    END 
  END CheckSetVal;

  PROCEDURE CheckConst(VAR x: OAG.Item);
  BEGIN
    IF x.mode # OAB.Const THEN OAS.Mark("not a constant"); x.mode := OAB.Const END
  END CheckConst;

  PROCEDURE CheckReadOnly(VAR x: OAG.Item);
  BEGIN
    IF x.rdo THEN OAS.Mark("read-only") END
  END CheckReadOnly;

  PROCEDURE CheckExport(VAR expo: BOOLEAN);
  BEGIN
    IF sym = OAS.times THEN
      expo := TRUE; OAS.Get(sym);
      IF level # 0 THEN OAS.Mark("remove asterisk") END
    ELSE expo := FALSE
    END
  END CheckExport;

  PROCEDURE IsExtension(t0, t1: OAB.Type): BOOLEAN;
  BEGIN (*t1 is an extension of t0*)
    RETURN (t0 = t1) OR (t1 # NIL) & IsExtension(t0, t1.base)
  END IsExtension;

  (* expressions *)

  PROCEDURE TypeTest(VAR x: OAG.Item; T: OAB.Type; guard: BOOLEAN);
    VAR xt: OAB.Type;
  BEGIN xt := x.type;
    IF (T.form = xt.form ) & ((T.form = OAB.Pointer) OR (T.form = OAB.Record) & (x.mode = OAB.Par)) THEN
      WHILE (xt # T) & (xt # NIL) DO xt := xt.base END ;
      IF xt # T THEN xt := x.type;
        IF xt.form = OAB.Pointer THEN
          IF IsExtension(xt.base, T.base) THEN OAG.TypeTest(x, T.base, FALSE, guard); x.type := T
          ELSE OAS.Mark("not an extension")
          END
        ELSIF (xt.form = OAB.Record) & (x.mode = OAB.Par) THEN
          IF IsExtension(xt, T) THEN  OAG.TypeTest(x, T, TRUE, guard); x.type := T
          ELSE OAS.Mark("not an extension")
          END
        ELSE OAS.Mark("incompatible types")
        END
      ELSIF ~guard THEN OAG.TypeTest(x, NIL, FALSE, FALSE)
      END
    ELSE OAS.Mark("type mismatch")
    END ;
    IF ~guard THEN x.type := OAB.boolType END
  END TypeTest;

  PROCEDURE selector(VAR x: OAG.Item);
    VAR y: OAG.Item; obj: OAB.Object;
  BEGIN
    WHILE (sym = OAS.lbrak) OR (sym = OAS.period) OR (sym = OAS.arrow)
        OR (sym = OAS.lparen) & (x.type.form IN {OAB.Record, OAB.Pointer}) DO
      IF sym = OAS.lbrak THEN
        REPEAT OAS.Get(sym); expression(y);
          IF x.type.form = OAB.Array THEN
            CheckInt(y); OAG.Index(x, y); x.type := x.type.base
          ELSE OAS.Mark("not an array")
          END
        UNTIL sym # OAS.comma;
        Check(OAS.rbrak, "no ]")
      ELSIF sym = OAS.period THEN OAS.Get(sym);
        IF sym = OAS.ident THEN
          IF x.type.form = OAB.Pointer THEN OAG.DeRef(x); x.type := x.type.base END ;
          IF x.type.form = OAB.Record THEN
            obj := OAB.thisfield(x.type); OAS.Get(sym);
            IF obj # NIL THEN OAG.Field(x, obj); x.type := obj.type
            ELSE OAS.Mark("undef")
            END
          ELSE OAS.Mark("not a record")
          END
        ELSE OAS.Mark("ident?")
        END
      ELSIF sym = OAS.arrow THEN
        OAS.Get(sym);
        IF x.type.form = OAB.Pointer THEN OAG.DeRef(x); x.type := x.type.base
        ELSE OAS.Mark("not a pointer")
        END
      ELSIF (sym = OAS.lparen) & (x.type.form IN {OAB.Record, OAB.Pointer}) THEN (*type guard*)
        OAS.Get(sym);
        IF sym = OAS.ident THEN
          qualident(obj);
          IF obj.class = OAB.Typ THEN TypeTest(x, obj.type, TRUE)
          ELSE OAS.Mark("guard type expected")
          END
        ELSE OAS.Mark("not an identifier")
        END ;
        Check(OAS.rparen, " ) missing")
      END
    END
  END selector;

  PROCEDURE EqualSignatures(t0, t1: OAB.Type): BOOLEAN;
    VAR p0, p1: OAB.Object; com: BOOLEAN;
  BEGIN com := TRUE;
    IF (t0.base = t1.base) & (t0.nofpar = t1.nofpar) THEN
      p0 := t0.dsc; p1 := t1.dsc;
      WHILE p0 # NIL DO
        IF (p0.class = p1.class) &  (p0.rdo = p1.rdo) &
          ((p0.type = p1.type) OR
          (p0.type.form = OAB.Array) & (p1.type.form = OAB.Array) & (p0.type.len = p1.type.len) & (p0.type.base = p1.type.base) OR
          (p0.type.form = OAB.Proc) & (p1.type.form = OAB.Proc) & EqualSignatures(p0.type, p1.type))
        THEN p0 := p0.next; p1 := p1.next
        ELSE p0 := NIL; com := FALSE
        END
      END
    ELSE com := FALSE
    END ;
    RETURN com
  END EqualSignatures;

  PROCEDURE CompTypes(t0, t1: OAB.Type; varpar: BOOLEAN): BOOLEAN;
  BEGIN (*check for assignment compatibility*)
    RETURN (t0 = t1)    (*openarray assignment disallowed in ORG*)
      OR (t0.form = OAB.Array) & (t1.form = OAB.Array) & (t0.base =  t1.base) & (t0.len = t1.len)
      OR (t0.form = OAB.Record) & (t1.form = OAB.Record)  & IsExtension(t0, t1)
      OR ~varpar &
        ((t0.form = OAB.Pointer) & (t1.form = OAB.Pointer)  & IsExtension(t0.base, t1.base)
        OR (t0.form = OAB.Proc) & (t1.form = OAB.Proc) & EqualSignatures(t0, t1)
        OR (t0.form IN {OAB.Pointer, OAB.Proc}) & (t1.form = OAB.NilTyp))
  END CompTypes;

  PROCEDURE Parameter(par: OAB.Object);
    VAR x: OAG.Item; varpar: BOOLEAN;
  BEGIN expression(x);
    IF par # NIL THEN
      varpar := par.class = OAB.Par;
      IF CompTypes(par.type, x.type, varpar) THEN
        IF ~varpar THEN OAG.ValueParam(x)
        ELSE (*par.class = Par*)
          IF ~par.rdo THEN CheckReadOnly(x) END ;
          OAG.VarParam(x, par.type)
        END
      ELSIF (x.type.form = OAB.Array) & (par.type.form = OAB.Array) &
          (x.type.base = par.type.base) & (par.type.len < 0) THEN
        IF ~par.rdo THEN CheckReadOnly(x) END ;
        OAG.OpenArrayParam(x)
      ELSIF (x.type.form = OAB.String) & varpar & par.rdo & (par.type.form = OAB.Array) & 
          (par.type.base.form = OAB.Char) & (par.type.len < 0) THEN OAG.StringParam(x)
      ELSIF ~varpar & (par.type.form = OAB.Int) & (x.type.form = OAB.Int) THEN OAG.ValueParam(x)  (*BYTE*)
      ELSIF (x.type.form = OAB.String) & (x.b = 2) & (par.class = OAB.Var) & (par.type.form = OAB.Char) THEN
        OAG.StrToChar(x); OAG.ValueParam(x)
      ELSIF (par.type.form = OAB.Array) & (par.type.base = OAB.byteType) & 
          (par.type.len >= 0) & (par.type.size = x.type.size) THEN
        OAG.VarParam(x, par.type)
      ELSE OAS.Mark("incompatible parameters")
      END
    END
  END Parameter;

  PROCEDURE ParamList(VAR x: OAG.Item);
    VAR n: INTEGER; par: OAB.Object;
  BEGIN par := x.type.dsc; n := 0;
    IF sym # OAS.rparen THEN
      Parameter(par); n := 1;
      WHILE sym <= OAS.comma DO
        Check(OAS.comma, "comma?");
        IF par # NIL THEN par := par.next END ;
        INC(n); Parameter(par)
      END ;
      Check(OAS.rparen, ") missing")
    ELSE OAS.Get(sym);
    END ;
    IF n < x.type.nofpar THEN OAS.Mark("too few params")
    ELSIF n > x.type.nofpar THEN OAS.Mark("too many params")
    END
  END ParamList;

  PROCEDURE StandFunc(VAR x: OAG.Item; fct: INTEGER; restyp: OAB.Type);
    VAR y: OAG.Item; n, npar: INTEGER;
  BEGIN Check(OAS.lparen, "no (");
    npar := fct MOD 10; fct := fct DIV 10; expression(x); n := 1;
    WHILE sym = OAS.comma DO OAS.Get(sym); expression(y); INC(n) END ;
    Check(OAS.rparen, "no )");
    IF n = npar THEN
      IF fct = 0 THEN (*ABS*)
        IF x.type.form IN {OAB.Int, OAB.Real} THEN OAG.Abs(x); restyp := x.type ELSE OAS.Mark("bad type") END
      ELSIF fct = 1 THEN (*ODD*) CheckInt(x); OAG.Odd(x)
      ELSIF fct = 2 THEN (*FLOOR*) CheckReal(x); OAG.Floor(x)
      ELSIF fct = 3 THEN (*FLT*) CheckInt(x); OAG.Float(x)
      ELSIF fct = 4 THEN (*ORD*)
        IF x.type.form <= OAB.Proc THEN OAG.Ord(x)
        ELSIF (x.type.form = OAB.String) & (x.b = 2) THEN OAG.StrToChar(x)
        ELSE OAS.Mark("bad type")
        END
      ELSIF fct = 5 THEN (*CHR*) CheckInt(x); OAG.Ord(x)
      ELSIF fct = 6 THEN (*LEN*)
          IF x.type.form = OAB.Array THEN OAG.Len(x) ELSE OAS.Mark("not an array") END
      ELSIF fct IN {7, 8, 9} THEN (*LSL, ASR, ROR*) CheckInt(y);
        IF x.type.form IN {OAB.Int, OAB.Set} THEN OAG.Shift(fct-7, x, y); restyp := x.type ELSE OAS.Mark("bad type") END
      ELSIF fct = 11 THEN (*ADC*) OAG.ADC(x, y)
      ELSIF fct = 12 THEN (*SBC*) OAG.SBC(x, y)
      ELSIF fct = 13 THEN (*UML*) OAG.UML(x, y)
      ELSIF fct = 14 THEN (*BIT*) CheckInt(x); CheckInt(y); OAG.Bit(x, y)
      ELSIF fct = 15 THEN (*REG*) CheckConst(x); CheckInt(x); OAG.Register(x)
      ELSIF fct = 16 THEN (*VAL*)
        IF (x.mode= OAB.Typ) & (x.type.size <= y.type.size) THEN restyp := x.type; x := y
        ELSE OAS.Mark("casting not allowed")
        END
      ELSIF fct = 17 THEN (*ADR*) OAG.Adr(x)
      ELSIF fct = 18 THEN (*SIZE*)
        IF x.mode = OAB.Typ THEN OAG.MakeConstItem(x, OAB.intType, x.type.size)
        ELSE OAS.Mark("must be a type")
        END
      ELSIF fct = 19 THEN (*COND*) CheckConst(x); CheckInt(x); OAG.Condition(x)
      ELSIF fct = 20 THEN (*H*) CheckConst(x); CheckInt(x); OAG.H(x)
      END ;
      x.type := restyp
    ELSE OAS.Mark("wrong nof params")
    END
  END StandFunc;

  PROCEDURE element(VAR x: OAG.Item);
    VAR y: OAG.Item;
  BEGIN expression(x); CheckSetVal(x);
    IF sym = OAS.upto THEN OAS.Get(sym); expression(y); CheckSetVal(y); OAG.Set(x, y)
    ELSE OAG.Singleton(x)
    END ;
    x.type := OAB.setType
  END element;
  
  PROCEDURE set(VAR x: OAG.Item);
    VAR y: OAG.Item;
  BEGIN
    IF sym >= OAS.if THEN
      IF sym # OAS.rbrace THEN OAS.Mark(" } missing") END ;
      OAG.MakeConstItem(x, OAB.setType, 0) (*empty set*)
    ELSE element(x);
      WHILE (sym < OAS.rparen) OR (sym > OAS.rbrace) DO
        IF sym = OAS.comma THEN OAS.Get(sym)
        ELSIF sym # OAS.rbrace THEN OAS.Mark("missing comma")
        END ;
        element(y); OAG.SetOp(OAS.plus, x, y)
      END
    END
  END set; 

  PROCEDURE factor(VAR x: OAG.Item);
    VAR obj: OAB.Object; rx: INTEGER;
  BEGIN (*sync*)
    IF (sym < OAS.char) OR (sym > OAS.ident) THEN OAS.Mark("expression expected");
      REPEAT OAS.Get(sym) UNTIL (sym >= OAS.char) & (sym <= OAS.for) OR (sym >= OAS.then)
    END ;
    IF sym = OAS.ident THEN
      qualident(obj);  
      IF obj.class = OAB.SFunc THEN StandFunc(x, obj.val, obj.type)
      ELSE OAG.MakeItem(x, obj, level); selector(x);
        IF sym = OAS.lparen THEN
          OAS.Get(sym);
          IF (x.type.form = OAB.Proc) & (x.type.base.form # OAB.NoTyp) THEN
            OAG.PrepCall(x, rx); ParamList(x); OAG.Call(x, rx); x.type := x.type.base
          ELSE OAS.Mark("not a function"); ParamList(x)
          END
        END
      END
    ELSIF sym = OAS.int THEN OAG.MakeConstItem(x, OAB.intType, OAS.ival); OAS.Get(sym)
    ELSIF sym = OAS.real THEN OAG.MakeRealItem(x, OAS.rval); OAS.Get(sym)
    ELSIF sym = OAS.char THEN OAG.MakeConstItem(x, OAB.charType, OAS.ival); OAS.Get(sym)
    ELSIF sym = OAS.nil THEN OAS.Get(sym); OAG.MakeConstItem(x, OAB.nilType, 0)
    ELSIF sym = OAS.string THEN OAG.MakeStringItem(x, OAS.slen); OAS.Get(sym)
    ELSIF sym = OAS.lparen THEN OAS.Get(sym); expression(x); Check(OAS.rparen, "no )")
    ELSIF sym = OAS.lbrace THEN OAS.Get(sym); set(x); Check(OAS.rbrace, "no }")
    ELSIF sym = OAS.not THEN OAS.Get(sym); factor(x); CheckBool(x); OAG.Not(x)
    ELSIF sym = OAS.false THEN OAS.Get(sym); OAG.MakeConstItem(x, OAB.boolType, 0)
    ELSIF sym = OAS.true THEN OAS.Get(sym); OAG.MakeConstItem(x, OAB.boolType, 1)
    ELSE OAS.Mark("not a factor"); OAG.MakeConstItem(x, OAB.intType, 0)
    END
  END factor;

  PROCEDURE term(VAR x: OAG.Item);
    VAR y: OAG.Item; op, f: INTEGER;
  BEGIN factor(x); f := x.type.form;
    WHILE (sym >= OAS.times) & (sym <= OAS.and) DO
      op := sym; OAS.Get(sym);
      IF op = OAS.times THEN
        IF f = OAB.Int THEN factor(y); CheckInt(y); OAG.MulOp(x, y)
        ELSIF f = OAB.Real THEN factor(y); CheckReal(y); OAG.RealOp(op, x, y)
        ELSIF f = OAB.Set THEN factor(y); CheckSet(y); OAG.SetOp(op, x, y)
        ELSE OAS.Mark("bad type")
        END
      ELSIF (op = OAS.div) OR (op = OAS.mod) THEN
        CheckInt(x); factor(y); CheckInt(y); OAG.DivOp(op, x, y)
      ELSIF op = OAS.rdiv THEN
        IF f = OAB.Real THEN factor(y); CheckReal(y); OAG.RealOp(op, x, y)
        ELSIF f = OAB.Set THEN factor(y); CheckSet(y); OAG.SetOp(op, x, y)
        ELSE OAS.Mark("bad type")
        END
      ELSE (*op = and*) CheckBool(x); OAG.And1(x); factor(y); CheckBool(y); OAG.And2(x, y)
      END
    END
  END term;

  PROCEDURE SimpleExpression(VAR x: OAG.Item);
    VAR y: OAG.Item; op: INTEGER;
  BEGIN
    IF sym = OAS.minus THEN OAS.Get(sym); term(x);
      IF x.type.form IN {OAB.Int, OAB.Real, OAB.Set} THEN OAG.Neg(x) ELSE CheckInt(x) END
    ELSIF sym = OAS.plus THEN OAS.Get(sym); term(x);
    ELSE term(x)
    END ;
    WHILE (sym >= OAS.plus) & (sym <= OAS.or) DO
      op := sym; OAS.Get(sym);
      IF op = OAS.or THEN OAG.Or1(x); CheckBool(x); term(y); CheckBool(y); OAG.Or2(x, y)
      ELSIF x.type.form = OAB.Int THEN term(y); CheckInt(y); OAG.AddOp(op, x, y)
      ELSIF x.type.form = OAB.Real THEN term(y); CheckReal(y); OAG.RealOp(op, x, y)
      ELSE CheckSet(x); term(y); CheckSet(y); OAG.SetOp(op, x, y)
      END
    END
  END SimpleExpression;

  PROCEDURE expression0(VAR x: OAG.Item);
    VAR y: OAG.Item; obj: OAB.Object; rel, xf, yf: INTEGER;
  BEGIN SimpleExpression(x);
    IF (sym >= OAS.eql) & (sym <= OAS.geq) THEN
      rel := sym; OAS.Get(sym); SimpleExpression(y); xf := x.type.form; yf := y.type.form;
      IF x.type = y.type THEN
        IF (xf IN {OAB.Char, OAB.Int}) THEN OAG.IntRelation(rel, x, y)
        ELSIF xf = OAB.Real THEN OAG.RealRelation(rel, x, y)
        ELSIF (xf IN {OAB.Set, OAB.Pointer, OAB.Proc, OAB.NilTyp, OAB.Bool}) THEN
          IF rel <= OAS.neq THEN OAG.IntRelation(rel, x, y) ELSE OAS.Mark("only = or #") END
        ELSIF (xf = OAB.Array) & (x.type.base.form = OAB.Char) OR (xf = OAB.String) THEN
          OAG.StringRelation(rel, x, y)
        ELSE OAS.Mark("illegal comparison")
        END
      ELSIF (xf IN {OAB.Pointer, OAB.Proc}) & (yf = OAB.NilTyp)
          OR (yf IN {OAB.Pointer, OAB.Proc}) & (xf = OAB.NilTyp) THEN
        IF rel <= OAS.neq THEN OAG.IntRelation(rel, x,  y) ELSE OAS.Mark("only = or #") END
      ELSIF (xf = OAB.Pointer) & (yf = OAB.Pointer) &
          (IsExtension(x.type.base, y.type.base) OR IsExtension(y.type.base, x.type.base))
          OR (xf = OAB.Proc) & (yf = OAB.Proc) & EqualSignatures(x.type, y.type) THEN
        IF rel <= OAS.neq THEN OAG.IntRelation(rel,  x, y) ELSE OAS.Mark("only = or #") END
      ELSIF (xf = OAB.Array) & (x.type.base.form = OAB.Char) &
            ((yf = OAB.String) OR (yf = OAB.Array) & (y.type.base.form = OAB.Char))
          OR (yf = OAB.Array) & (y.type.base.form = OAB.Char) & (xf = OAB.String) THEN
        OAG.StringRelation(rel, x, y)
      ELSIF (xf = OAB.Char) & (yf = OAB.String) & (y.b = 2) THEN
        OAG.StrToChar(y); OAG.IntRelation(rel, x, y)
      ELSIF (yf = OAB.Char) & (xf = OAB.String) & (x.b = 2) THEN
        OAG.StrToChar(x); OAG.IntRelation(rel, x, y)
      ELSIF (xf = OAB.Int) & (yf = OAB.Int) THEN OAG.IntRelation(rel,  x, y)  (*BYTE*)
      ELSE OAS.Mark("illegal comparison")
      END ;
      x.type := OAB.boolType
    ELSIF sym = OAS.in THEN
      OAS.Get(sym); CheckInt(x); SimpleExpression(y); CheckSet(y); OAG.In(x, y) ;
      x.type := OAB.boolType
    ELSIF sym = OAS.is THEN
      OAS.Get(sym); qualident(obj); TypeTest(x, obj.type, FALSE) ;
      x.type := OAB.boolType
    END
  END expression0;

  (* statements *)

  PROCEDURE StandProc(pno: INTEGER);
    VAR nap, npar: INTEGER; (*nof actual/formal parameters*)
      x, y, z: OAG.Item;
  BEGIN Check(OAS.lparen, "no (");
    npar := pno MOD 10; pno := pno DIV 10; expression(x); nap := 1;
    IF sym = OAS.comma THEN
      OAS.Get(sym); expression(y); nap := 2; z.type := OAB.noType;
      WHILE sym = OAS.comma DO OAS.Get(sym); expression(z); INC(nap) END
    ELSE y.type := OAB.noType
    END ;
    Check(OAS.rparen, "no )");
    IF (npar = nap) OR (pno IN {0, 1}) THEN 
      IF pno IN {0, 1} THEN (*INC, DEC*)
        CheckInt(x); CheckReadOnly(x);
        IF y.type # OAB.noType THEN CheckInt(y) END ;
        OAG.Increment(pno, x, y)
      ELSIF pno IN {2, 3} THEN (*INCL, EXCL*)
        CheckSet(x); CheckReadOnly(x); CheckInt(y); OAG.Include(pno-2, x, y)
      ELSIF pno = 4 THEN CheckBool(x); OAG.Assert(x)
      ELSIF pno = 5 THEN(*NEW*) CheckReadOnly(x);
         IF (x.type.form = OAB.Pointer) & (x.type.base.form = OAB.Record) THEN OAG.New(x)
         ELSE OAS.Mark("not a pointer to record")
         END
      ELSIF pno = 6 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); OAG.Pack(x, y)
      ELSIF pno = 7 THEN CheckReal(x); CheckInt(y); CheckReadOnly(x); OAG.Unpk(x, y)
      ELSIF pno = 8 THEN
        IF x.type.form <= OAB.Set THEN OAG.Led(x) ELSE OAS.Mark("bad type") END
      ELSIF pno = 10 THEN CheckInt(x); OAG.Get(x, y)
      ELSIF pno = 11 THEN CheckInt(x); OAG.Put(x, y)
      ELSIF pno = 12 THEN CheckInt(x); CheckInt(y); CheckInt(z); OAG.Copy(x, y, z)
      ELSIF pno = 13 THEN CheckConst(x); CheckInt(x); OAG.LDPSR(x)
      ELSIF pno = 14 THEN CheckInt(x); OAG.LDREG(x, y)
      END
    ELSE OAS.Mark("wrong nof parameters")
    END
  END StandProc;

  PROCEDURE StatSequence;
    VAR obj: OAB.Object;
      orgtype: OAB.Type; (*original type of case var*)
      x, y, z, w: OAG.Item;
      L0, L1, rx: INTEGER;

    PROCEDURE TypeCase(obj: OAB.Object; VAR x: OAG.Item);
      VAR typobj: OAB.Object;
    BEGIN
      IF sym = OAS.ident THEN
        qualident(typobj); OAG.MakeItem(x, obj, level);
        IF typobj.class # OAB.Typ THEN OAS.Mark("not a type") END ;
        TypeTest(x, typobj.type, FALSE); obj.type := typobj.type;
        OAG.CFJump(x); Check(OAS.colon, ": expected"); StatSequence
      ELSE OAG.CFJump(x); OAS.Mark("type id expected")
      END
     END TypeCase;

    PROCEDURE SkipCase;
    BEGIN 
      WHILE sym # OAS.colon DO OAS.Get(sym) END ;
      OAS.Get(sym); StatSequence
    END SkipCase;

  BEGIN (* StatSequence *)
    REPEAT (*sync*) obj := NIL;
      IF ~((sym >= OAS.ident)  & (sym <= OAS.for) OR (sym >= OAS.semicolon)) THEN
        OAS.Mark("statement expected");
        REPEAT OAS.Get(sym) UNTIL (sym >= OAS.ident)
      END ;
      IF sym = OAS.ident THEN
        qualident(obj); OAG.MakeItem(x, obj, level);
        IF x.mode = OAB.SProc THEN StandProc(obj.val)
        ELSE selector(x);
          IF sym = OAS.becomes THEN (*assignment*)
            OAS.Get(sym); CheckReadOnly(x); expression(y);
            IF CompTypes(x.type, y.type, FALSE) THEN
              IF (x.type.form <= OAB.Pointer) OR (x.type.form = OAB.Proc) THEN OAG.Store(x, y)
              ELSE OAG.StoreStruct(x, y)
              END
            ELSIF (x.type.form = OAB.Array) & (y.type.form = OAB.Array) & (x.type.base = y.type.base) & (y.type.len < 0) THEN
              OAG.StoreStruct(x, y)
            ELSIF (x.type.form = OAB.Array) & (x.type.base.form = OAB.Char) & (y.type.form = OAB.String) THEN
              OAG.CopyString(x, y)
            ELSIF (x.type.form = OAB.Int) & (y.type.form = OAB.Int) THEN OAG.Store(x, y)  (*BYTE*)
            ELSIF (x.type.form = OAB.Char) & (y.type.form = OAB.String) & (y.b = 2) THEN
              OAG.StrToChar(y); OAG.Store(x, y)
            ELSE OAS.Mark("illegal assignment")
            END
          ELSIF sym = OAS.eql THEN OAS.Mark("should be :="); OAS.Get(sym); expression(y)
          ELSIF sym = OAS.lparen THEN (*procedure call*)
            OAS.Get(sym);
            IF (x.type.form = OAB.Proc) & (x.type.base.form = OAB.NoTyp) THEN
              OAG.PrepCall(x, rx); ParamList(x); OAG.Call(x, rx)
            ELSE OAS.Mark("not a procedure"); ParamList(x)
            END
          ELSIF x.type.form = OAB.Proc THEN (*procedure call without parameters*)
            IF x.type.nofpar > 0 THEN OAS.Mark("missing parameters") END ;
            IF x.type.base.form = OAB.NoTyp THEN OAG.PrepCall(x, rx); OAG.Call(x, rx) ELSE OAS.Mark("not a procedure") END
          ELSIF x.mode = OAB.Typ THEN OAS.Mark("illegal assignment")
          ELSE OAS.Mark("not a procedure")
          END
        END
      ELSIF sym = OAS.if THEN
        OAS.Get(sym); expression(x); CheckBool(x); OAG.CFJump(x);
        Check(OAS.then, "no THEN");
        StatSequence; L0 := 0;
        WHILE sym = OAS.elsif DO
          OAS.Get(sym); OAG.FJump(L0); OAG.Fixup(x); expression(x); CheckBool(x);
          OAG.CFJump(x); Check(OAS.then, "no THEN"); StatSequence
        END ;
        IF sym = OAS.else THEN OAS.Get(sym); OAG.FJump(L0); OAG.Fixup(x); StatSequence
        ELSE OAG.Fixup(x)
        END ;
        OAG.FixLink(L0); Check(OAS.end, "no END")
      ELSIF sym = OAS.while THEN
        OAS.Get(sym); L0 := OAG.Here(); expression(x); CheckBool(x); OAG.CFJump(x);
        Check(OAS.do, "no DO"); StatSequence; OAG.BJump(L0);
        WHILE sym = OAS.elsif DO
          OAS.Get(sym); OAG.Fixup(x); expression(x); CheckBool(x); OAG.CFJump(x);
          Check(OAS.do, "no DO"); StatSequence; OAG.BJump(L0)
        END ;
        OAG.Fixup(x); Check(OAS.end, "no END")
      ELSIF sym = OAS.repeat THEN
        OAS.Get(sym); L0 := OAG.Here(); StatSequence;
        IF sym = OAS.until THEN
          OAS.Get(sym); expression(x); CheckBool(x); OAG.CBJump(x, L0)
        ELSE OAS.Mark("missing UNTIL")
        END
      ELSIF sym = OAS.for THEN
        OAS.Get(sym);
        IF sym = OAS.ident THEN
          qualident(obj); OAG.MakeItem(x, obj, level); CheckInt(x); CheckReadOnly(x);
          IF sym = OAS.becomes THEN
            OAS.Get(sym); expression(y); CheckInt(y); OAG.For0(x, y); L0 := OAG.Here();
            Check(OAS.to, "no TO"); expression(z); CheckInt(z); obj.rdo := TRUE;
            IF sym = OAS.by THEN OAS.Get(sym); expression(w); CheckConst(w); CheckInt(w)
            ELSE OAG.MakeConstItem(w, OAB.intType, 1)
            END ;
            Check(OAS.do, "no DO"); OAG.For1(x, y, z, w, L1);
            StatSequence; Check(OAS.end, "no END");
            OAG.For2(x, y, w); OAG.BJump(L0); OAG.FixLink(L1); obj.rdo := FALSE
          ELSE OAS.Mark(":= expected")
          END
        ELSE OAS.Mark("identifier expected")
        END
      ELSIF sym = OAS.case THEN
        OAS.Get(sym);
        IF sym = OAS.ident THEN
          qualident(obj); orgtype := obj.type;
          IF (orgtype.form = OAB.Pointer) OR (orgtype.form = OAB.Record) & (obj.class = OAB.Par) THEN
            Check(OAS.of, "OF expected"); TypeCase(obj, x); L0 := 0;
            WHILE sym = OAS.bar DO
              OAS.Get(sym); OAG.FJump(L0); OAG.Fixup(x); obj.type := orgtype; TypeCase(obj, x)
            END ;
            OAG.Fixup(x); OAG.FixLink(L0); obj.type := orgtype
          ELSE OAS.Mark("numeric case not implemented");
            Check(OAS.of, "OF expected"); SkipCase;
            WHILE sym = OAS.bar DO SkipCase END
          END
        ELSE OAS.Mark("ident expected")
        END ;
        Check(OAS.end, "no END")
      END ;
      OAG.CheckRegs;
      IF sym = OAS.semicolon THEN OAS.Get(sym)
      ELSIF sym < OAS.semicolon THEN OAS.Mark("missing semicolon?")
      END
    UNTIL sym > OAS.semicolon
  END StatSequence;

  (* Types and declarations *)

  PROCEDURE IdentList(class: INTEGER; VAR first: OAB.Object);
    VAR obj: OAB.Object;
  BEGIN
    IF sym = OAS.ident THEN
      OAB.NewObj(first, OAS.id, class); OAS.Get(sym); CheckExport(first.expo);
      WHILE sym = OAS.comma DO
        OAS.Get(sym);
        IF sym = OAS.ident THEN OAB.NewObj(obj, OAS.id, class); OAS.Get(sym); CheckExport(obj.expo)
        ELSE OAS.Mark("ident?")
        END
      END;
      IF sym = OAS.colon THEN OAS.Get(sym) ELSE OAS.Mark(":?") END
    ELSE first := NIL
    END
  END IdentList;
  
  PROCEDURE ArrayType(VAR type: OAB.Type);
    VAR x: OAG.Item; typ: OAB.Type; len: INTEGER;
  BEGIN NEW(typ); typ.form := OAB.NoTyp;
    expression(x);
    IF (x.mode = OAB.Const) & (x.type.form = OAB.Int) & (x.a >= 0) THEN len := x.a
    ELSE len := 1; OAS.Mark("not a valid length")
    END ;
    IF sym = OAS.of THEN OAS.Get(sym); Type(typ.base);
      IF (typ.base.form = OAB.Array) & (typ.base.len < 0) THEN OAS.Mark("dyn array not allowed") END
    ELSIF sym = OAS.comma THEN OAS.Get(sym); ArrayType(typ.base)
    ELSE OAS.Mark("missing OF"); typ.base := OAB.intType
    END ;
    typ.size := (len * typ.base.size + 3) DIV 4 * 4;
    typ.form := OAB.Array; typ.len := len; type := typ
  END ArrayType;

  PROCEDURE RecordType(VAR type: OAB.Type);
    VAR obj, obj0, new, bot, base: OAB.Object;
      typ, tp: OAB.Type;
      offset, off, n: INTEGER;
  BEGIN NEW(typ); typ.form := OAB.NoTyp; typ.base := NIL; typ.mno := -level; typ.nofpar := 0; offset := 0; bot := NIL;
    IF sym = OAS.lparen THEN
      OAS.Get(sym); (*record extension*)
      IF level # 0 THEN OAS.Mark("extension of local types not implemented") END ;
      IF sym = OAS.ident THEN
        qualident(base);
        IF base.class = OAB.Typ THEN
          IF base.type.form = OAB.Record THEN typ.base := base.type
          ELSE typ.base := OAB.intType; OAS.Mark("invalid extension")
          END ;
          typ.nofpar := typ.base.nofpar + 1; (*"nofpar" here abused for extension level*)
          bot := typ.base.dsc; offset := typ.base.size
        ELSE OAS.Mark("type expected")
        END
      ELSE OAS.Mark("ident expected")
      END ;
      Check(OAS.rparen, "no )")
    END ;
    WHILE sym = OAS.ident DO  (*fields*)
      n := 0; obj := bot;
      WHILE sym = OAS.ident DO
        obj0 := obj;
        WHILE (obj0 # NIL) & (obj0.name # OAS.id) DO obj0 := obj0.next END ;
        IF obj0 # NIL THEN OAS.Mark("mult def") END ;
        NEW(new); OAS.CopyId(new.name); new.class := OAB.Fld; new.next := obj; obj := new; INC(n);
        OAS.Get(sym); CheckExport(new.expo);
        IF (sym # OAS.comma) & (sym # OAS.colon) THEN OAS.Mark("comma expected")
        ELSIF sym = OAS.comma THEN OAS.Get(sym)
        END
      END ;
      Check(OAS.colon, "colon expected"); Type(tp);
      IF (tp.form = OAB.Array) & (tp.len < 0) THEN OAS.Mark("dyn array not allowed") END ;
      IF tp.size > 1 THEN offset := (offset+3) DIV 4 * 4 END ;
      offset := offset + n * tp.size; off := offset; obj0 := obj;
      WHILE obj0 # bot DO obj0.type := tp; obj0.lev := 0; off := off - tp.size; obj0.val := off; obj0 := obj0.next END ;
      bot := obj;
      IF sym = OAS.semicolon THEN OAS.Get(sym) ELSIF sym # OAS.end THEN OAS.Mark(" ; or END") END
    END ;
    typ.form := OAB.Record; typ.dsc := bot; typ.size := (offset + 3) DIV 4 * 4; type := typ
  END RecordType;

  PROCEDURE FPSection(VAR adr: INTEGER; VAR nofpar: INTEGER);
    VAR obj, first: OAB.Object; tp: OAB.Type;
      parsize: INTEGER; cl: INTEGER; rdo: BOOLEAN;
  BEGIN
    IF sym = OAS.var THEN OAS.Get(sym); cl := OAB.Par ELSE cl := OAB.Var END ;
    IdentList(cl, first); FormalType(tp, 0); rdo := FALSE;
    IF (cl = OAB.Var) & (tp.form >= OAB.Array) THEN cl := OAB.Par; rdo := TRUE END ;
    IF (tp.form = OAB.Array) & (tp.len < 0) OR (tp.form = OAB.Record) THEN
      parsize := 2*OAG.WordSize  (*open array or record, needs second word for length or type tag*)
    ELSE parsize := OAG.WordSize
    END ;
    obj := first;
    WHILE obj # NIL DO
      INC(nofpar); obj.class := cl; obj.type := tp; obj.rdo := rdo; obj.lev := level; obj.val := adr;
      adr := adr + parsize; obj := obj.next
    END ;
    IF adr >= 104 THEN OAS.Mark("too many parameters") END (* count in bytes of parameter register space... 13 registers *)
  END FPSection;

  PROCEDURE ProcedureType(ptype: OAB.Type; VAR parblksize: INTEGER);
    VAR obj: OAB.Object; size: INTEGER; nofpar: INTEGER;
  BEGIN ptype.base := OAB.noType; size := parblksize; nofpar := 0; ptype.dsc := NIL;
    IF sym = OAS.lparen THEN
      OAS.Get(sym);
      IF sym = OAS.rparen THEN OAS.Get(sym)
      ELSE FPSection(size, nofpar);
        WHILE sym = OAS.semicolon DO OAS.Get(sym); FPSection(size, nofpar) END ;
        Check(OAS.rparen, "no )")
      END ;
      IF sym = OAS.colon THEN  (*function*)
        OAS.Get(sym);
        IF sym = OAS.ident THEN
          qualident(obj); ptype.base := obj.type;
          IF ~((obj.class = OAB.Typ) & (obj.type.form IN {OAB.Byte .. OAB.Pointer, OAB.Proc})) THEN
            OAS.Mark("illegal function type")
          END
        ELSE OAS.Mark("type identifier expected")
        END
      END
    END ;
    ptype.nofpar := nofpar; parblksize := size
  END ProcedureType;

  PROCEDURE FormalType0(VAR typ: OAB.Type; dim: INTEGER);
    VAR obj: OAB.Object; dmy: INTEGER;
  BEGIN
    IF sym = OAS.ident THEN
      qualident(obj);
      IF obj.class = OAB.Typ THEN typ := obj.type ELSE OAS.Mark("not a type"); typ := OAB.intType END
    ELSIF sym = OAS.array THEN
      OAS.Get(sym); Check(OAS.of, "OF ?");
      IF dim >= 1 THEN OAS.Mark("multi-dimensional open arrays not implemented") END ;
      NEW(typ); typ.form := OAB.Array; typ.len := -1; typ.size := 2*OAG.WordSize; 
      FormalType(typ.base, dim+1)
    ELSIF sym = OAS.procedure THEN
      OAS.Get(sym); OAB.OpenScope;
      NEW(typ); typ.form := OAB.Proc; typ.size := OAG.WordSize; dmy := 0; ProcedureType(typ, dmy);
      typ.dsc := OAB.topScope.next; OAB.CloseScope
    ELSE OAS.Mark("identifier expected"); typ := OAB.noType
    END
  END FormalType0;

  PROCEDURE CheckRecLevel(lev: INTEGER);
  BEGIN
    IF lev # 0 THEN OAS.Mark("ptr base must be global") END
  END CheckRecLevel;

  PROCEDURE Type0(VAR type: OAB.Type);
    VAR dmy: INTEGER; obj: OAB.Object; ptbase: PtrBase;
  BEGIN type := OAB.intType; (*sync*)
    IF (sym # OAS.ident) & (sym < OAS.array) THEN OAS.Mark("not a type");
      REPEAT OAS.Get(sym) UNTIL (sym = OAS.ident) OR (sym >= OAS.array)
    END ;
    IF sym = OAS.ident THEN
      qualident(obj);
      IF obj.class = OAB.Typ THEN
        IF (obj.type # NIL) & (obj.type.form # OAB.NoTyp) THEN type := obj.type END
      ELSE OAS.Mark("not a type or undefined")
      END
    ELSIF sym = OAS.array THEN OAS.Get(sym); ArrayType(type)
    ELSIF sym = OAS.record THEN
      OAS.Get(sym); RecordType(type); Check(OAS.end, "no END")
    ELSIF sym = OAS.pointer THEN
      OAS.Get(sym); Check(OAS.to, "no TO");
      NEW(type);  type.form := OAB.Pointer; type.size := OAG.WordSize; type.base := OAB.intType;
      IF sym = OAS.ident THEN
        obj := OAB.thisObj();
        IF obj # NIL THEN
          IF (obj.class = OAB.Typ) & (obj.type.form IN {OAB.Record, OAB.NoTyp}) THEN
            CheckRecLevel(obj.lev); type.base := obj.type
          ELSIF obj.class = OAB.Mod THEN OAS.Mark("external base type not implemented")
          ELSE OAS.Mark("no valid base type")
          END
        ELSE CheckRecLevel(level); (*enter into list of forward references to be fixed in Declarations*)
          NEW(ptbase); OAS.CopyId(ptbase.name); ptbase.type := type; ptbase.next := pbsList; pbsList := ptbase
        END ;
        OAS.Get(sym)
      ELSE Type(type.base);
        IF (type.base.form # OAB.Record) OR (type.base.typobj = NIL) THEN OAS.Mark("must point to named record") END ;
        CheckRecLevel(level)
      END
    ELSIF sym = OAS.procedure THEN
      OAS.Get(sym); OAB.OpenScope;
      NEW(type); type.form := OAB.Proc; type.size := OAG.WordSize; dmy := 0;
      ProcedureType(type, dmy); type.dsc := OAB.topScope.next; OAB.CloseScope
    ELSE OAS.Mark("illegal type")
    END
  END Type0;

  PROCEDURE Declarations(VAR varsize: INTEGER);
    VAR obj, first: OAB.Object;
      x: OAG.Item; tp: OAB.Type; ptbase: PtrBase;
      expo: BOOLEAN; id: OAS.Ident;
  BEGIN (*sync*) pbsList := NIL;
    IF (sym < OAS.const) & (sym # OAS.end) & (sym # OAS.return) THEN OAS.Mark("declaration?");
      REPEAT OAS.Get(sym) UNTIL (sym >= OAS.const) OR (sym = OAS.end) OR (sym = OAS.return)
    END ;
    IF sym = OAS.const THEN
      OAS.Get(sym);
      WHILE sym = OAS.ident DO
        OAS.CopyId(id); OAS.Get(sym); CheckExport(expo);
        IF sym = OAS.eql THEN OAS.Get(sym) ELSE OAS.Mark("= ?") END;
        expression(x);
        IF (x.type.form = OAB.String) & (x.b = 2) THEN OAG.StrToChar(x) END ;
        OAB.NewObj(obj, id, OAB.Const); obj.expo := expo;
        IF x.mode = OAB.Const THEN obj.val := x.a; obj.lev := x.b; obj.type := x.type
        ELSE OAS.Mark("expression not constant"); obj.type := OAB.intType
        END;
        Check(OAS.semicolon, "; missing")
      END
    END ;
    IF sym = OAS.type THEN
      OAS.Get(sym);
      WHILE sym = OAS.ident DO
        OAS.CopyId(id); OAS.Get(sym); CheckExport(expo);
        IF sym = OAS.eql THEN OAS.Get(sym) ELSE OAS.Mark("=?") END ;
        Type(tp);
        OAB.NewObj(obj, id, OAB.Typ); obj.type := tp; obj.expo := expo; obj.lev := level;
        IF tp.typobj = NIL THEN tp.typobj := obj END ;
        IF expo & (obj.type.form = OAB.Record) THEN obj.exno := exno; INC(exno) ELSE obj.exno := 0 END ;
        IF tp.form = OAB.Record THEN
          ptbase := pbsList;  (*check whether this is base of a pointer type; search and fixup*)
          WHILE ptbase # NIL DO
            IF obj.name = ptbase.name THEN ptbase.type.base := obj.type END ;
            ptbase := ptbase.next
          END ;
          IF level = 0 THEN OAG.BuildTD(tp, dc) END    (*type descriptor; len used as its address*)
        END ;
        Check(OAS.semicolon, "; missing")
      END
    END ;
    IF sym = OAS.var THEN
      OAS.Get(sym);
      WHILE sym = OAS.ident DO
        IdentList(OAB.Var, first); Type(tp);
        obj := first;
        WHILE obj # NIL DO
          obj.type := tp; obj.lev := level;
          IF tp.size > 1 THEN varsize := (varsize + 3) DIV 4 * 4 (*align*) END ;
          obj.val := varsize; varsize := varsize + obj.type.size;
          IF obj.expo THEN obj.exno := exno; INC(exno) END ;
          obj := obj.next
        END ;
        Check(OAS.semicolon, "; missing")
      END
    END ;
    varsize := (varsize + 3) DIV 4 * 4;
    ptbase := pbsList;
    WHILE ptbase # NIL DO
      IF ptbase.type.base.form = OAB.Int THEN OAS.Mark("undefined pointer base of") END ;
      ptbase := ptbase.next
    END ;
    IF (sym >= OAS.const) & (sym <= OAS.var) THEN OAS.Mark("declaration in bad order") END
  END Declarations;

  PROCEDURE ProcedureDecl;
    VAR proc: OAB.Object;
      type: OAB.Type;
      procid: OAS.Ident;
      x: OAG.Item;
      locblksize, parblksize, L: INTEGER;
      int: BOOLEAN;
  BEGIN (* ProcedureDecl *) int := FALSE; OAS.Get(sym); 
    IF sym = OAS.times THEN OAS.Get(sym); int := TRUE END ;
    IF sym = OAS.ident THEN
      OAS.CopyId(procid); OAS.Get(sym);
      OAB.NewObj(proc, OAS.id, OAB.Const);
      IF int THEN parblksize := 12 ELSE parblksize := 4 END ;
      NEW(type); type.form := OAB.Proc; type.size := OAG.WordSize;
      proc.type := type; proc.val := -1; proc.lev := level; 
      CheckExport(proc.expo);
      IF proc.expo THEN proc.exno := exno; INC(exno) END ;
      OAB.OpenScope; INC(level); type.base := OAB.noType;
      ProcedureType(type, parblksize);  (*formal parameter list*)
      Check(OAS.semicolon, "no ;"); locblksize := parblksize;
      Declarations(locblksize);
      proc.val := OAG.Here() * 4; proc.type.dsc := OAB.topScope.next;
      IF sym = OAS.procedure THEN
        L := 0; OAG.FJump(L);
        REPEAT ProcedureDecl; Check(OAS.semicolon, "no ;") UNTIL sym # OAS.procedure;
        OAG.FixOne(L); proc.val := OAG.Here() * 4; proc.type.dsc := OAB.topScope.next
      END ;
      OAG.Enter(parblksize, locblksize, int);
      IF sym = OAS.begin THEN OAS.Get(sym); StatSequence END ;
      IF sym = OAS.return THEN
        OAS.Get(sym); expression(x);
        IF type.base = OAB.noType THEN OAS.Mark("this is not a function")
        ELSIF ~CompTypes(type.base, x.type, FALSE) THEN OAS.Mark("wrong result type")
        END
      ELSIF type.base.form # OAB.NoTyp THEN
        OAS.Mark("function without result"); type.base := OAB.noType
      END ;
      OAG.Return(type.base.form, x, locblksize, int);
      OAB.CloseScope; DEC(level); Check(OAS.end, "no END");
      IF sym = OAS.ident THEN
        IF OAS.id # procid THEN OAS.Mark("no match") END ;
        OAS.Get(sym)
      ELSE OAS.Mark("no proc id")
      END
    ELSE OAS.Mark("proc id expected")
    END
  END ProcedureDecl;

  PROCEDURE Import;
    VAR impid, impid1: OAS.Ident;
  BEGIN
    IF sym = OAS.ident THEN
      OAS.CopyId(impid); OAS.Get(sym);
      IF sym = OAS.becomes THEN
        OAS.Get(sym);
        IF sym = OAS.ident THEN OAS.CopyId(impid1); OAS.Get(sym)
        ELSE OAS.Mark("id expected"); impid1 := impid
        END
      ELSE impid1 := impid
      END ;
      OAB.Import(impid, impid1)
    ELSE OAS.Mark("id expected")
    END
  END Import;

  PROCEDURE Module;
    VAR key: INTEGER;
  BEGIN Emit("  compiling "); OAS.Get(sym);
    IF sym = OAS.module THEN
      OAS.Get(sym);
      IF sym = OAS.times THEN version := 0; dc := 8; Emit("*"); OAS.Get(sym) ELSE dc := 0; version := 1 END ;
      OAB.Init; OAB.OpenScope;
      IF sym = OAS.ident THEN
        OAS.CopyId(modid); OAS.Get(sym);
        Emit(modid); Emit(": ");
      ELSE OAS.Mark("identifier expected")
      END ;
      Check(OAS.semicolon, "no ;"); level := 0; exno := 1; key := 0;
      IF sym = OAS.import THEN                                                       (* IMPORTS *)
        OAS.Get(sym); Import;
        WHILE sym = OAS.comma DO OAS.Get(sym); Import END ;
        Check(OAS.semicolon, "; missing")
      END ;
      OAG.Open(version, verbose); Declarations(dc); OAG.SetDataSize((dc + 3) DIV 4 * 4);      (* TYPES and VARS *)
      WHILE sym = OAS.procedure DO ProcedureDecl; Check(OAS.semicolon, "no ;") END ; (* PROCEDURES *)
      OAG.Header;                                                                    
      IF sym = OAS.begin THEN OAS.Get(sym); StatSequence END ;                       (* BEGIN *)
      Check(OAS.end, "no END");
      IF sym = OAS.ident THEN
        IF OAS.id # modid THEN OAS.Mark("no match") END ;
        OAS.Get(sym)
      ELSE OAS.Mark("identifier missing")
      END ;
      IF sym # OAS.period THEN OAS.Mark("period missing") END ;
      IF (OAS.errcnt = 0) & (version # 0) THEN
        OAB.Export(modid, newSF, key);
        IF newSF THEN Emit(" new symbol file") END
      END ;
      IF OAS.errcnt = 0 THEN
        OAG.Close(modid, key, exno);                                                 (* write the binary *)
(*        Texts.WriteInt(W, OAG.pc, 6); Texts.WriteInt(W, dc, 6); Texts.WriteHex(W, key) *)
      ELSE EmitLn; Emit("compilation FAILED")
      END ;
      EmitLn;
      OAB.CloseScope; pbsList := NIL
    ELSE OAS.Mark("must start with MODULE")
    END
  END Module;

  PROCEDURE Link;
    VAR key: INTEGER;
  BEGIN 
    IF verbose THEN Emit(" linking "); Emit(modid); EmitLn; END;
    OAL.Link(modid,ccFMT)
  END Link;


  PROCEDURE Option(o: Options);
    VAR i: INTEGER;
  BEGIN
    newSF := FALSE;
    verbose := FALSE;
    ccFMT := 0; (* no linking *)
    ccWordsize := 4;
    ccStackalign := 4;

    i:=0; WHILE o[i] > 0X DO 
      IF o[i] = "s" THEN newSF := TRUE END;
      IF o[i] = "v" THEN verbose := TRUE END;
      IF o[i] = "b" THEN ccFMT :=  OAB.BIN     END;  (* raw binary *)
      IF o[i] = "r" THEN ccFMT :=  OAB.RSC64   END;  (* rsc64  *)
      IF o[i] = "e" THEN ccFMT :=  OAB.ELF64   END;  (* elf64  *)
      IF o[i] = "m" THEN ccFMT :=  OAB.MACHO   END;  (* macho  *)
      IF o[i] = "p" THEN ccFMT :=  OAB.PE64    END;  (* pe64   *)
      INC(i)
    END
  END Option;


  PROCEDURE Compile*( f: ARRAY OF CHAR; o: ARRAY OF CHAR );
    VAR beg, end, time: INTEGER;
      T: Texts.Text;
      S: Texts.Scanner;
      ff: Texts.Filename;
      oo: Options;
  BEGIN
    Emit("Compiling "); Emit( f ); EmitLn;
    ff:= f; oo:=o;
    NEW(T);
    Texts.Open(T, ff);
    IF T.len > 0 THEN
      Option(oo);  
      OAS.Init(T, 0);
      Module;
      IF ccFMT > 0 THEN
        Emit("Preparing "); Emit( f ); EmitLn;
        Link;  
      END ;
    ELSE Emit( f ); Emit(" not found"); EmitLn
    END ;
  END Compile;

BEGIN (* Emit("Silicon Oberon Compiler 2023.09.24");
  EmitLn; *)
  NEW(dummy); dummy.class := OAB.Var; dummy.type := OAB.intType;
  expression := expression0; Type := Type0; FormalType := FormalType0
END OAP.

