MODULE OAG; (* N.Wirth, 16.4.2016 / 4.4.2017 / 31.5.2019, CP 2023  Oberon compiler; code generator for Arm 64-bit*)
  IMPORT SYSTEM, Out, Files, OAS, OAB;
  (*Code generator for Oberon compiler for Arm processor.
     Procedural interface to Parser OAP; result in array "code".
     Procedure Close writes code-files*)

  CONST WordSize* = 8;
    StkOrg0 = -64; VarOrg0 = 0;  (*for RISC-0 only*)
    NTR = 26; MT = 28; FP = 29; LNK = 30; SP = 31; (*MT = 12, SP = 14, LNK = 15;*)   (*dedicated registers*)
    maxCode = 480000; maxStrx = 2400; maxTD = 640; C24 = 1000000H;
    Reg = 10; RegI = 11; Cond = 12;  (*internal item modes*)

  (*frequently used opcodes*)  U = 2000H; V = 1000H;
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3; And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Fad = 12; Fsb = 13; Fml = 14; Fdv = 15;
    Ldr = 8; Str = 10; Ldp = 16; Stp = 18;
    BR = 0; BLR = 1; BC = 2; BL = 3;
    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14;

    TYPE Item* = RECORD
      mode*: INTEGER;
      type*: OAB.Type;
      a*, b*, r: INTEGER;
      rdo*: BOOLEAN  (*read only*)
    END ;

  (* Item forms and meaning of fields:
    mode    r      a       b
    --------------------------------
    Const   -     value (proc adr)  (immediate value)
    Var     base   off     -               (direct adr)
    Par      -     off0     off1         (indirect adr)
    Reg    regno
    RegI   regno   off     -
    Cond  cond   Fchain  Tchain  *)

  VAR 
    pc*, varsize: INTEGER;   (*program counter, data index*)
    tdx, strx: INTEGER;
    entry: INTEGER;   (*main entry point*)
    RH: INTEGER;  (*available registers R[0] ... R[H-1]*)
    frame: INTEGER;  (*frame offset changed in SaveRegs and RestoreRegs*)
    fixorgP, fixorgD, fixorgT: INTEGER;   (*origins of lists of locations to be fixed up by loader*)
    check: BOOLEAN;  (*emit run-time checks*)
    version: INTEGER;  (* 0 = RISC-0, 1 = RISC-5, 2 = AARCH64 *)
    verbose: BOOLEAN;
    
    relmap: ARRAY 6 OF INTEGER;  (*condition codes for relations*)
    code: ARRAY maxCode OF BYTE;
    data: ARRAY maxTD OF BYTE;  (*type descriptors*)
    str: ARRAY maxStrx OF CHAR;

  (* debug output and code array operations *)

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 128 OF CHAR;
  BEGIN ss:=s; Out.String(ss);
  END Emit;

  PROCEDURE EmitLn;
  BEGIN Out.Ln
  END EmitLn;

  PROCEDURE Put32(VAR a: ARRAY OF BYTE; loc, i: INTEGER);
    VAR I,x: INTEGER;
  BEGIN x:=loc*4;
    IF x <= LEN(a) THEN
      SYSTEM.GET(SYSTEM.ADR(a[x]),I);
      I:=I DIV 100000000H; I:=I * 100000000H + (i MOD 100000000H) ;
      SYSTEM.PUT(SYSTEM.ADR(a[x]),I);
    ELSE OAS.Mark("bin array overflow")
    END
  END Put32;

  PROCEDURE Get32(VAR a: ARRAY OF BYTE; loc: INTEGER):INTEGER;
    VAR I,x: INTEGER;
  BEGIN I:=0;x:=loc*4;
    IF x <= LEN(a) THEN
      SYSTEM.GET(SYSTEM.ADR(a[x]),I);
    ELSE OAS.Mark("Get32 overflow")
    END;
    RETURN (I MOD 100000000H)
  END Get32;

  PROCEDURE Put64(VAR a: ARRAY OF BYTE; loc, i: INTEGER);
    VAR x:INTEGER;
  BEGIN x:=loc*4;
    IF x <= LEN(a) THEN
      SYSTEM.PUT(SYSTEM.ADR(a[x]),i);
    ELSE OAS.Mark("Put64 overflow")
    END
  END Put64;

  PROCEDURE Get64(VAR a: ARRAY OF BYTE; loc: INTEGER):INTEGER;
    VAR I,x: INTEGER;
  BEGIN I:=0;x:=loc*4;
    IF x <= LEN(a) THEN
      SYSTEM.GET(SYSTEM.ADR(a[x]),I);
    ELSE OAS.Mark("Get64 overflow")
    END;
    RETURN I
  END Get64;

  (*instruction assemblers according to formats*)

(*
  PROCEDURE Put0(op, a, b, c: INTEGER);
    VAR i: INTEGER;
  BEGIN (*emit format-0 instruction*)
    Put32( code, pc, ((a*10H + b) * 10H + op) * 10000H + c);
    INC(pc)
  END Put0

op + U=2000H 
     V=1000H (im ones extend)

;
*)

  PROCEDURE APut0(op, a, b, c: INTEGER); (*dst reg - src1 reg - src2 reg*)
    VAR v: INTEGER; inv: BOOLEAN;
  BEGIN (*emit format-0 instruction*)
    v:= 0BBBBBBBBH; inv := FALSE;
    IF op = Mov THEN
     IF op < 2000H THEN
      IF (( a # SP ) & ( c # SP )) THEN
        v:=0AAH + c*10H + 3 * 10000H + (0E0H+a)*1000000H;
      END;
      IF (( a = SP ) & ( c # SP )) THEN
        v:=091H + (1FH+(a*2))*1000000H;
      END;
      IF (( a # SP ) & ( c = SP )) THEN
        v:=091H + 3*10000H + (0E0H+a)*1000000H;
      END;
     ELSE (* has U flag *)
          (* V=0: R.A:=H *)
          (* V=1: R.A:=[N,Z,C,V] *)
     END
    ELSE  
      IF op = Lsl THEN v:= 09AC02000H END; (* negative immediate, positive is lsr *)
      IF op = Asr THEN v:= 09AC02800H END; 
      IF op = Ror THEN v:= 09AC02C00H END; 
      IF op = Ann THEN v:= 0EA000000H; inv := TRUE END;
      IF op = And THEN v:= 0EA000000H END;
      IF op = Ior THEN v:= 0AA000000H END; 
      IF op = Xor THEN v:= 0CA1F0000H END;
      IF op = Add THEN (* u=1: with carry *)
        v:= 08B000000H
      END;
      IF op = Sub THEN (* u=1: with carry *)
        v:= 0CB000000H
      END;
      IF op = Mul THEN (* u=1: unsigned *)
        v:= 09B007C00H
      END;
      IF op = Div THEN
        v:= 09AC00800H
      END;


      v:=v + (c*10000H) + (b*20H) + a;
    END;
    Put32(code, pc, v );
    INC(pc);
    IF inv THEN
      v:= 0CA1F0000H + a*20H + a; Put32(code, pc, v ); INC(pc)
    END
  END APut0;

(*
  PROCEDURE Put1(op, a, b, im: INTEGER);
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)
    IF im < 0 THEN INC(op, V) END ;
    Put32(code, pc, (((a+40H) * 10H + b) * 10H + op) * 10000H + (im MOD 10000H));
    INC(pc)
  END Put1;


0 MOV a, n R.a := n
1 LSL a, b, n R.a := R.b ← n (shift left by n bits)
2 ASR a, b, n R.a := R.b → n (shift right by n bits with sign extension)
3 ROR a, b, n R.a := R.b rot n (rotate right by n bits)
4 AND a, b, n R.a := R.b & n logical operations
5 ANN a, b, n R.a := R.b & ~n
6 IOR a, b, n R.a := R.b or n
7 XOR a, b, n R.a := R.b xor n
8 ADD a, b, n R.a := R.b + n integer arithmetic
9 SUB a, b, n R.a := R.b – n
10 MUL a, b, n R.a := R.a х n
11 DIV a, b, n R.a := R.b div n

*)

  PROCEDURE APut1(op, a, b, im: INTEGER);
    VAR v: INTEGER;
  BEGIN (*emit format-1 instruction,  -10000H <= im < 10000H*)
    v:= 0EEEEEEEEH;
    IF op = Mov THEN
     IF a = SP THEN
      OAS.Mark("no constant to stack pointer")
     ELSE 
       IF op < 2000H THEN
         v:= 0D2800000H + (im * 20H) + a  ;
       ELSE
         OAS.Mark("can't shift left")
       END
     END
    ELSE (* not Mov *)  
      IF op = Lsl THEN v:= 0D37FF400H + ((0 - im) MOD 40H)*10000H + b*20H + a END; (* negative immediate, positive is lsr *)
      IF op = Asr THEN v:= 09340FC00H + im*10000H + b*20H + a END; 
      IF op = Ror THEN v:= 093C00000H + im*10000H + b*20H + a END; 
      IF op = Ann THEN v:= 022222222H END;
      IF op = And THEN v:= 0F2000000H END; (*ugly*)
      IF op = Ior THEN v:= 0B2000000H END; (*ugly*)
      IF op = Xor THEN v:= 0D2000000H END; (*ugly*)
      IF op = Add THEN (* u=1: with carry *)
        v:= 091000000H; v:=v + (im*400H) + (b*20H) + a
      END;
      IF op = Sub THEN (* u=1: with carry *)
        v:= 0D1000000H; v:=v + (im*400H) + (b*20H) + a
      END;
      IF op = Mul THEN (* u=1: unsigned *)
        v:= 99999999H; v:=v + (im*400H) + (b*20H) + a
      END;
      IF op = Div THEN v:= 0AAAAAAAAH END;
(*      v:=v + (im*400H) + (b*20H) + a; *)
    END;
    Put32(code, pc, v );
    INC(pc)
  END APut1;

(*
  PROCEDURE Put1a(op, a, b, im: INTEGER);
  BEGIN (*same as Put1, but with range test  -10000H <= im < 10000H*)
    IF (im >= -10000H) & (im <= 0FFFFH) THEN Put1(op, a, b, im)
    ELSE Put1(Mov+U, RH, 0, im DIV 10000H);
      IF im MOD 10000H # 0 THEN APut1(Ior, RH, RH, im MOD 10000H) END ;
      Put0(op, a, b, RH)
    END
  END Put1a;
*)

  PROCEDURE APut1a(op, a, b, im: INTEGER);
  BEGIN (*same as Put1, but with range test  -10000H <= im < 10000H*)
    APut1(op, a, b, im)
  END APut1a;

(*
  PROCEDURE Put2(op, a, b, off: INTEGER);
  BEGIN (*emit load/store instruction*)
    Put32(code, pc, ((op * 10H + a) * 10H + b) * 100000H + (off MOD 100000H));
    INC(pc)
  END Put2;
*)

  PROCEDURE APut2(op, a, b, off: INTEGER);
    VAR v: INTEGER;
  BEGIN (*emit load/store instruction*)
    v := 077777777H;
    IF op = Stp THEN v:= 0A9BF7BFDH  END; (* x29, x30, [sp, #-16]! *)
    IF op = Ldp THEN v:= 0A8C17BFDH  END; (* x29, x30, [sp], #16   *)
    IF op = Str THEN
      IF off < 0 THEN
        v:= 0F81F8000H + (off DIV 4 * 400H) + (b*20H) + a;
      ELSE
        v:= 0F9000000H + (off DIV 4 * 400H) + (b*20H) + a;
      END
    END;
    IF op = Ldr THEN
      IF off < 0 THEN
        v:= 0F85F8000H + (off DIV 4 * 400H) + (b*20H) + a;
      ELSE
        v:= 0F9400000H + (off DIV 4 * 400H) + (b*20H) + a
      END
    END;
    Put32(code, pc, v );
    INC(pc)
  END APut2;

  PROCEDURE APutFixP(xr, xa, off: INTEGER);
    VAR t,v: INTEGER;
  BEGIN (* 16384 modules, 256 procedures/module, 64k 16k skip length *)
  (*  Put32(code, pc, xr*1000H + xa*100H + off ); *)
    Put32(code, pc, xr*100000H + xa*1000H + off );
    INC(pc)
  END APutFixP;

  PROCEDURE APutFixD(op, rh, m, off: INTEGER);
    VAR t,v: INTEGER;
  BEGIN
    t:=4;
    IF op = Ldr THEN t:= 0 END;
    IF op = Str THEN t:= 1 END;
(*
    IF op = Ldb THEN t:= 2 END;
    IF op = Stb THEN t:= 3 END;
*)
    Put32(code, pc, ((t * 20000000H) + (rh * 1000000H) + (m * 100000H) + (off MOD 100000H)));
    INC(pc)
  END APutFixD;

(*
  PROCEDURE Put3(op, cond, off: INTEGER);
  BEGIN (*emit branch instruction*)
    Put32(code, pc, ((op+12) * 10H + cond) * 1000000H + (off MOD 1000000H)); INC(pc)
  END Put3;
*)

(*

MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14;

n negative
z zero
c carry
v overflow

*)

  PROCEDURE APut3(op, cond, off: INTEGER);
    VAR v: INTEGER;
       ok: BOOLEAN;
  BEGIN (*emit branch instruction*)
    ok:= FALSE;
    IF ((op = BR) & (cond = 7)) THEN (* off (register) =30 is return from procedure 11 is from oberon interrupt *)
      Put32(code, pc, 0D65F0000H + (off *20H )); ok:= TRUE; INC(pc)
    END;
    IF op = BLR THEN Put32(code, pc, 0D63F0000H); ok:= TRUE; INC(pc) END;
    IF op = BC  THEN 
      IF cond =  7 THEN v:=  54000000H END;
      IF cond = EQ THEN v:= 054000080H END;
      IF cond = NE THEN v:=  54000000H END;
      IF cond = LT THEN v:= 05400006BH END;
      IF cond = GE THEN v:=  54000000H END;
      IF cond = LE THEN v:=  54000000H END;
      IF cond = GT THEN v:= 0540000ACH END;
      IF cond = MI THEN v:=  54000000H END;
      IF cond = PL THEN v:=  54000000H END;
      Put32(code, pc, v + (off MOD 80000)*20 );
      ok:= TRUE;
      INC(pc)
    END;
    IF op = BL  THEN
      IF off <= 0 THEN
        Put32(code, pc, 97FFFFFFH + (off + 2 )); ok:= TRUE; INC(pc)
      ELSE
        Put32(code, pc, 94000000H + (off  )); ok:= TRUE; INC(pc)
      END
    END;

    IF ok = FALSE THEN
      Put32(code, pc, 77777777H); INC(pc)
    END
  END APut3;

(*
  b <offset>    -- relative forward/back branch
  br <Xn>       -- absolute branch to address in register Xn
  -- branch & link, store return address in X30 (LR)
  bl <offset>   -- relative forward/back branch
  blr <Xn>      -- absolute branch to address in register Xn
*)



  PROCEDURE incR;
  BEGIN
    IF RH < MT-1 THEN INC(RH) ELSE OAS.Mark("register stack overflow") END
  END incR;

  PROCEDURE CheckRegs*;
  BEGIN
    IF RH # 0 THEN OAS.Mark("Reg Stack"); RH := 0 END ;
    IF pc >= maxCode - 40 THEN OAS.Mark("program too long") END ;
    IF frame # 0 THEN OAS.Mark("frame error"); frame := 0 END
  END CheckRegs;

  PROCEDURE SetCC(VAR x: Item; n: INTEGER);
  BEGIN x.mode := Cond; x.a := 0; x.b := 0; x.r := n
  END SetCC;

  PROCEDURE Trap(cond, num: INTEGER);
  BEGIN APut3(BLR, cond, OAS.Pos()*100H + num*10H + MT)
  END Trap;

  (*handling of forward reference, fixups of branch addresses and constant tables*)

  PROCEDURE negated(cond: INTEGER): INTEGER;
  BEGIN
    IF cond < 8 THEN cond := cond+8 ELSE cond := cond-8 END ;
    RETURN cond
  END negated;

  PROCEDURE fix(at, with: INTEGER);
    VAR t,f: INTEGER;
  BEGIN
(*
    t:= Get32(code,at);
    Put32(code, at, t DIV C24 * C24 + ((with MOD 80000H)*20H));
*)
  END fix;

  PROCEDURE FixOne*(at: INTEGER);
  BEGIN fix(at, pc - at - 1)
  END FixOne;

  PROCEDURE FixLink*(L: INTEGER); (* conditional branch offset *)
    VAR L1,op: INTEGER;
  BEGIN
(*
    WHILE L # 0 DO
        L1 := Get32(code,L) DIV 20H MOD 80000H;
        fix(L, pc - L - 1);
        L := L1
    END
*)
  END FixLink;

  PROCEDURE FixBCLink*(L: INTEGER); (* conditional branch offset *)
    VAR L1,op: INTEGER;
  BEGIN
    WHILE L # 0 DO
        L1 := Get32(code,L) DIV 20H MOD 80000H;
        fix(L, pc - L - 1);
        L := L1
    END
  END FixBCLink;

  PROCEDURE FixLinkWith(L0, dst: INTEGER);
    VAR L1: INTEGER;
  BEGIN
(*
    WHILE L0 # 0 DO
      L1 := Get32(code,L0) MOD C24;
      Put32(code, L0, Get32(code,L0) DIV C24 * C24 + ((dst - L0 - 1) MOD C24)); L0 := L1
    END
*)
  END FixLinkWith;

  PROCEDURE merged(L0, L1: INTEGER): INTEGER;
    VAR L2, L3: INTEGER;
  BEGIN 
(*
    IF L0 # 0 THEN L3 := L0;
      REPEAT L2 := L3; L3 := Get32(code,L2) MOD 40000H UNTIL L3 = 0;
      Put32(code, L2, Get32(code,L2) + L1); L1 := L0
    END ;
*)
    RETURN L1
  END merged;

  (* loading of operands and addresses into registers *)

  PROCEDURE GetSB(base: INTEGER);
  BEGIN
    APutFixD(Ldr, RH, -base, pc-fixorgD); fixorgD := pc-1
  END GetSB;

  PROCEDURE NilCheck;
  BEGIN IF check THEN Trap(EQ, 4) END
  END NilCheck;

  PROCEDURE load(VAR x: Item);
    VAR op: INTEGER;
  BEGIN
    IF x.type.size = 1 THEN op := Ldr+1 ELSE op := Ldr END ;
    IF x.mode # Reg THEN
      IF x.mode = OAB.Const THEN
        IF x.type.form = OAB.Proc THEN
          IF x.r > 0 THEN OAS.Mark("not allowed")
          ELSIF x.r = 0 THEN APut3(BL, 7, 0); APut1a(Sub, RH, LNK, pc*4 - x.a)
          ELSE GetSB(x.r); APut1(Add, RH, RH, x.a + 100H) (*mark as progbase-relative*)
          END
        ELSIF (x.a <= 0FFFFH) & (x.a >= -10000H) THEN APut1(Mov, RH, 0, x.a)
        ELSE APut1(Mov+U, RH, 0, x.a DIV 10000H MOD 10000H);
          IF x.a MOD 10000H # 0 THEN APut1(Ior, RH, RH, x.a MOD 10000H) END
        END ;
        x.r := RH; incR
      ELSIF x.mode = OAB.Var THEN
        IF x.r > 0 THEN (*local*) APut2(op, RH, SP, x.a + frame)
        ELSE GetSB(x.r); APut2(op, RH, RH, x.a) 
        END ;
        x.r := RH; incR
      ELSIF x.mode = OAB.Par THEN APut2(Ldr, RH, SP, x.a + frame); APut2(op, RH, RH, x.b); x.r := RH; incR
      ELSIF x.mode = RegI THEN APut2(op, x.r, x.r, x.a)
      ELSIF x.mode = Cond THEN
        APut3(BC, negated(x.r), 2);
        FixLink(x.b); APut1(Mov, RH, 0, 1); APut3(BC, 7, 1);
        FixLink(x.a); APut1(Mov, RH, 0, 0); x.r := RH; incR
      END ;
      x.mode := Reg
    END
  END load;

  PROCEDURE loadAdr(VAR x: Item);
  BEGIN
    IF x.mode = OAB.Var THEN
      IF x.r > 0 THEN (*local*) APut1a(Add, RH, SP, x.a + frame)
      ELSE GetSB(x.r); APut1a(Add, RH, RH, x.a)
      END ;
      x.r := RH; incR
    ELSIF x.mode = OAB.Par THEN APut2(Ldr, RH, SP, x.a + frame);
      IF x.b # 0 THEN APut1a(Add, RH, RH, x.b) END ;
      x.r := RH; incR
    ELSIF x.mode = RegI THEN
      IF x.a # 0 THEN APut1a(Add, x.r, x.r, x.a) END
    ELSE OAS.Mark("address error")
    END ;
    x.mode := Reg
  END loadAdr;

  PROCEDURE loadCond(VAR x: Item);
  BEGIN
    IF x.type.form = OAB.Bool THEN
      IF x.mode = OAB.Const THEN x.r := 15 - x.a*8
      ELSE load(x);
        (*IF Get32(code,pc-4) DIV 40000000H # -2 THEN *) APut1(Cmp, x.r, x.r, 0) (*END*) ;
        x.r := NE; DEC(RH)
      END ;
      x.mode := Cond; x.a := 0; x.b := 0
    ELSE OAS.Mark("not Boolean?")
    END
  END loadCond;

  PROCEDURE loadTypTagAdr(T: OAB.Type);
    VAR x: Item;
  BEGIN x.mode := OAB.Var; x.a := T.len; x.r := -T.mno; loadAdr(x)
  END loadTypTagAdr;

  PROCEDURE loadStringAdr(VAR x: Item);
  BEGIN GetSB(0); APut1a(Add, RH, RH, varsize+x.a); x.mode := Reg; x.r := RH; incR
  END loadStringAdr;

  (* Items: Conversion from constants or from Objects on the Heap to Items on the Stack*)

  PROCEDURE MakeConstItem*(VAR x: Item; typ: OAB.Type; val: INTEGER);
  BEGIN x.mode := OAB.Const; x.type := typ; x.a := val
  END MakeConstItem;

  PROCEDURE MakeRealItem*(VAR x: Item; val: REAL);
  BEGIN x.mode := OAB.Const; x.type := OAB.realType; x.a := SYSTEM.VAL(INTEGER, val)
  END MakeRealItem;

  PROCEDURE MakeStringItem*(VAR x: Item; len: INTEGER); (*copies string from ORS-buffer to ORG-string array*)
    VAR i: INTEGER;
  BEGIN x.mode := OAB.Const; x.type := OAB.strType; x.a := strx; x.b := len; i := 0;
    IF strx + len + 4 < maxStrx THEN
      WHILE len > 0 DO str[strx] := OAS.str[i]; INC(strx); INC(i); DEC(len) END ;
      WHILE strx MOD 4 # 0 DO str[strx] := 0X; INC(strx) END
    ELSE OAS.Mark("too many strings")
    END
  END MakeStringItem;

  PROCEDURE MakeItem*(VAR x: Item; y: OAB.Object; curlev: INTEGER);
  BEGIN x.mode := y.class; x.type := y.type; x.a := y.val; x.rdo := y.rdo;
    IF y.class = OAB.Par THEN x.b := 0
    ELSIF (y.class = OAB.Const) & (y.type.form = OAB.String) THEN x.b := y.lev  (*len*) ;
    ELSE x.r := y.lev
    END ;
    IF (y.lev > 0) & (y.lev # curlev) & (y.class # OAB.Const) THEN OAS.Mark("not accessible ") END
  END MakeItem;

  (* Code generation for Selectors, Variables, Constants *)

  PROCEDURE Field*(VAR x: Item; y: OAB.Object);   (* x := x.y *)
  BEGIN;
    IF x.mode = OAB.Var THEN
      IF x.r >= 0 THEN x.a := x.a + y.val
      ELSE loadAdr(x); x.mode := RegI; x.a := y.val
      END
    ELSIF x.mode = RegI THEN x.a := x.a + y.val
    ELSIF x.mode = OAB.Par THEN x.b := x.b + y.val
    END
  END Field;

  PROCEDURE Index*(VAR x, y: Item);   (* x := x[y] *)
    VAR s, lim: INTEGER;
  BEGIN s := x.type.base.size; lim := x.type.len;
    IF (y.mode = OAB.Const) & (lim >= 0) THEN
      IF (y.a < 0) OR (y.a >= lim) THEN OAS.Mark("bad index") END ;
      IF x.mode IN {OAB.Var, RegI} THEN x.a := y.a * s + x.a
      ELSIF x.mode = OAB.Par THEN x.b := y.a * s + x.b
      END
    ELSE load(y);
      IF check THEN  (*check array bounds*)
        IF lim >= 0 THEN APut1a(Cmp, RH, y.r, lim)
        ELSE (*open array*)
          IF x.mode IN {OAB.Var, OAB.Par} THEN APut2(Ldr, RH, SP, x.a+4+frame); APut0(Cmp, RH, y.r, RH)
          ELSE OAS.Mark("error in Index")
          END
        END ;
        Trap(10, 1)  (*BCC*)
      END ;
      IF s = 4 THEN APut1(Lsl, y.r, y.r, 2) ELSIF s > 1 THEN APut1a(Mul, y.r, y.r, s) END ;
      IF x.mode = OAB.Var THEN
        IF x.r > 0 THEN APut0(Add, y.r, SP, y.r); INC(x.a, frame)
        ELSE GetSB(x.r);
          IF x.r = 0 THEN APut0(Add, y.r, RH, y.r)
          ELSE APut1a(Add, RH, RH, x.a); APut0(Add, y.r, RH, y.r); x.a := 0
          END
        END ;
        x.r := y.r; x.mode := RegI
      ELSIF x.mode = OAB.Par THEN
        APut2(Ldr, RH, SP, x.a + frame);
        APut0(Add, y.r, RH, y.r); x.mode := RegI; x.r := y.r; x.a := x.b
      ELSIF x.mode = RegI THEN APut0(Add, x.r, x.r, y.r); DEC(RH)
      END
    END
  END Index;

  PROCEDURE DeRef*(VAR x: Item);
  BEGIN
    IF x.mode = OAB.Var THEN
      IF x.r > 0 THEN (*local*) APut2(Ldr, RH, SP, x.a + frame) ELSE GetSB(x.r); APut2(Ldr, RH, RH, x.a) END ;
      NilCheck; x.r := RH; incR
    ELSIF x.mode = OAB.Par THEN
      APut2(Ldr, RH, SP, x.a + frame); APut2(Ldr, RH, RH, x.b); NilCheck; x.r := RH; incR
    ELSIF x.mode = RegI THEN APut2(Ldr, x.r, x.r, x.a); NilCheck
    ELSIF x.mode # Reg THEN OAS.Mark("bad mode in DeRef")
    END ;
    x.mode := RegI; x.a := 0; x.b := 0
  END DeRef;

  PROCEDURE Q(T: OAB.Type; VAR dcw: INTEGER);
  BEGIN (*one entry of type descriptor extension table*)
    IF T.base # NIL THEN
      Q(T.base, dcw); Put64(data, dcw, (T.mno*1000H + T.len) * 1000H + dcw - fixorgT);
      fixorgT := dcw; INC(dcw,2)
    END
  END Q;

  PROCEDURE FindPtrFlds(typ: OAB.Type; off: INTEGER; VAR dcw: INTEGER);
    VAR fld: OAB.Object; i, s: INTEGER;
  BEGIN
    IF (typ.form = OAB.Pointer) OR (typ.form = OAB.NilTyp) THEN Put32(data, dcw, off); INC(dcw)
    ELSIF typ.form = OAB.Record THEN
      fld := typ.dsc;
      WHILE fld # NIL DO FindPtrFlds(fld.type, fld.val + off, dcw); fld := fld.next END
    ELSIF typ.form = OAB.Array THEN
      s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindPtrFlds(typ.base, i*s + off, dcw) END
    END
  END FindPtrFlds;

  PROCEDURE BuildTD*(T: OAB.Type; VAR dc: INTEGER);
    VAR dcw, k, s: INTEGER;  (*dcw = word address*)
  BEGIN dcw := dc DIV 4; s := T.size; (*convert size for heap allocation*)
    IF s <= 24 THEN s := 32 ELSIF s <= 56 THEN s := 64 ELSIF s <= 120 THEN s := 128
    ELSE s := (s+263) DIV 256 * 256
    END ;
    T.len := dc; Put64(data, dcw, s); INC(dcw,2);  (*len used as address*)
    k := T.nofpar;   (*extension level!*)
    IF k > 3 THEN OAS.Mark("ext level too large")
    ELSE Q(T, dcw);
      WHILE k < 3 DO Put64(data, dcw, -1); INC(dcw,2); INC(k) END
    END ;
    FindPtrFlds(T, 0, dcw); Put64(data, dcw, -1); INC(dcw,2); tdx := dcw; dc := dcw*4;
    IF tdx >= maxTD THEN OAS.Mark("too many record types"); tdx := 0 END
  END BuildTD;

  PROCEDURE TypeTest*(VAR x: Item; T: OAB.Type; varpar, isguard: BOOLEAN);
    VAR pc0: INTEGER;
  BEGIN
    IF T = NIL THEN
      IF x.mode >= Reg THEN DEC(RH) END ;
      SetCC(x, 7)
    ELSE (*fetch tag into RH*)
      IF varpar THEN APut2(Ldr, RH, SP, x.a+4+frame)
      ELSE load(x);
        pc0 := pc; APut3(BC, EQ, 0);  (*NIL belongs to every pointer type*)
        APut2(Ldr, RH, x.r, -8)
      END ;
      APut2(Ldr, RH, RH, T.nofpar*4); incR;
      loadTypTagAdr(T);  (*tag of T*)
      APut0(Cmp, RH-1, RH-1, RH-2); DEC(RH, 2);
      IF ~varpar THEN fix(pc0, pc - pc0 - 1) END ;
      IF isguard THEN
        IF check THEN Trap(NE, 2) END
      ELSE SetCC(x, EQ);
        IF ~varpar THEN DEC(RH) END
      END
    END
  END TypeTest;

  (* Code generation for Boolean operators *)

  PROCEDURE Not*(VAR x: Item);   (* x := ~x *)
    VAR t: INTEGER;
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    x.r := negated(x.r); t := x.a; x.a := x.b; x.b := t
  END Not;

  PROCEDURE And1*(VAR x: Item);   (* x := x & *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    APut3(BC, negated(x.r), x.a); x.a := pc-1; FixLink(x.b); x.b := 0
  END And1;

  PROCEDURE And2*(VAR x, y: Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := merged(y.a, x.a); x.b := y.b; x.r := y.r
  END And2;

  PROCEDURE Or1*(VAR x: Item);   (* x := x OR *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    APut3(BC, x.r, x.b);  x.b := pc-1; FixLink(x.a); x.a := 0
  END Or1;

  PROCEDURE Or2*(VAR x, y: Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := y.a; x.b := merged(y.b, x.b); x.r := y.r
  END Or2;

  (* Code generation for arithmetic operators *)

  PROCEDURE Neg*(VAR x: Item);   (* x := -x *)
  BEGIN
    IF x.type.form = OAB.Int THEN
      IF x.mode = OAB.Const THEN x.a := -x.a
      ELSE load(x); APut1(Mov, RH, 0, 0); APut0(Sub, x.r, RH, x.r)
      END
    ELSIF x.type.form = OAB.Real THEN
      IF x.mode = OAB.Const THEN x.a := x.a + 7FFFFFFFH + 1
      ELSE load(x); APut1(Mov, RH, 0, 0); APut0(Fsb, x.r, RH, x.r)
      END
    ELSE (*form = Set*)
      IF x.mode = OAB.Const THEN x.a := -x.a-1 
      ELSE load(x); APut1(Xor, x.r, x.r, -1)
      END
    END
  END Neg;

  PROCEDURE AddOp*(op: INTEGER; VAR x, y: Item);   (* x := x +- y *)
  BEGIN
    IF op = OAS.plus THEN
      IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN x.a := x.a + y.a
      ELSIF y.mode = OAB.Const THEN load(x);
        IF y.a # 0 THEN APut1a(Add, x.r, x.r, y.a) END
      ELSE load(x); load(y); APut0(Add, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = OAS.minus*)
      IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN x.a := x.a - y.a
      ELSIF y.mode = OAB.Const THEN load(x);
        IF y.a # 0 THEN APut1a(Sub, x.r, x.r, y.a) END
      ELSE load(x); load(y); APut0(Sub, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    END
  END AddOp;

  PROCEDURE log2(m: INTEGER; VAR e: INTEGER): INTEGER;
  BEGIN e := 0;
    WHILE ~ODD(m) DO m := m DIV 2; INC(e) END ;
    RETURN m
  END log2;
  
  PROCEDURE MulOp*(VAR x, y: Item);   (* x := x * y *)
    VAR e: INTEGER;
  BEGIN
    IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN x.a := x.a * y.a
    ELSIF (y.mode = OAB.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); APut1(Lsl, x.r, x.r, e)
    ELSIF y.mode = OAB.Const THEN load(x); APut1a(Mul, x.r, x.r, y.a)
    ELSIF (x.mode = OAB.Const) & (x.a >= 2) & (log2(x.a, e) = 1) THEN load(y); APut1(Lsl, y.r, y.r, e); x.mode := Reg; x.r := y.r
    ELSIF x.mode = OAB.Const THEN load(y); APut1a(Mul, y.r, y.r, x.a); x.mode := Reg; x.r := y.r
    ELSE load(x); load(y); APut0(Mul, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
    END
  END MulOp;

  PROCEDURE DivOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
    VAR e: INTEGER;
  BEGIN
    IF op = OAS.div THEN
      IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN
        IF y.a > 0 THEN x.a := x.a DIV y.a ELSE OAS.Mark("bad divisor") END
      ELSIF (y.mode = OAB.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x); APut1(Asr, x.r, x.r, e)
      ELSIF y.mode = OAB.Const THEN
        IF y.a > 0 THEN load(x); APut1a(Div, x.r, x.r, y.a) ELSE OAS.Mark("bad divisor") END
      ELSE load(y);
        IF check THEN Trap(LE, 6) END ;
        load(x); APut0(Div, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = OAS.mod*)
      IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN
        IF y.a > 0 THEN x.a := x.a MOD y.a ELSE OAS.Mark("bad modulus") END
      ELSIF (y.mode = OAB.Const) & (y.a >= 2) & (log2(y.a, e) = 1) THEN load(x);
        IF e <= 16 THEN APut1(And, x.r, x.r, y.a-1) ELSE APut1(Lsl, x.r, x.r, 32-e); APut1(Ror, x.r, x.r, 32-e) END
      ELSIF y.mode = OAB.Const THEN
        IF y.a > 0 THEN load(x); APut1a(Div, x.r, x.r, y.a); APut0(Mov+U, x.r, 0, 0) ELSE OAS.Mark("bad modulus") END
      ELSE load(y);
        IF check THEN Trap(LE, 6) END ;
        load(x); APut0(Div, RH-2, x.r, y.r); APut0(Mov+U, RH-2, 0, 0); DEC(RH); x.r := RH-1
      END
    END
  END DivOp;

  (* Code generation for REAL operators *)

  PROCEDURE RealOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
  BEGIN load(x); load(y);
    IF op = OAS.plus THEN APut0(Fad, RH-2, x.r, y.r)
    ELSIF op = OAS.minus THEN APut0(Fsb, RH-2, x.r, y.r)
    ELSIF op = OAS.times THEN APut0(Fml, RH-2, x.r, y.r)
    ELSIF op = OAS.rdiv THEN APut0(Fdv, RH-2, x.r, y.r)
    END ;
    DEC(RH); x.r := RH-1
  END RealOp;

  (* Code generation for set operators *)

  PROCEDURE Singleton*(VAR x: Item);  (* x := {x} *)
  BEGIN
    IF x.mode = OAB.Const THEN x.a := LSL(1, x.a) 
    ELSE load(x); APut1(Mov, RH, 0, 1); APut0(Lsl, x.r, RH,  x.r)
    END
  END Singleton;

  PROCEDURE Set*(VAR x, y: Item);   (* x := {x .. y} *)
  BEGIN
    IF (x.mode = OAB.Const) & ( y.mode = OAB.Const) THEN
      IF x.a <= y.a THEN x.a := LSL(2, y.a) - LSL(1, x.a) ELSE x.a := 0 END
    ELSE
      IF (x.mode = OAB.Const) & (x.a <= 16) THEN x.a := LSL(-1, x.a)
      ELSE load(x); APut1(Mov, RH, 0, -1); APut0(Lsl, x.r, RH, x.r)
      END ;
      IF (y.mode = OAB.Const) & (y.a < 16) THEN APut1(Mov, RH, 0, LSL(-2, y.a)); y.mode := Reg; y.r := RH; incR
      ELSE load(y); APut1(Mov, RH, 0, -2); APut0(Lsl, y.r, RH, y.r)
      END ;
      IF x.mode = OAB.Const THEN
        IF x.a # 0 THEN APut1(Xor, y.r, y.r, -1); APut1a(And, RH-1, y.r, x.a) END ;
        x.mode := Reg; x.r := RH-1
      ELSE DEC(RH); APut0(Ann, RH-1, x.r, y.r)
      END
    END
  END Set;

  PROCEDURE In*(VAR x, y: Item);  (* x := x IN y *)
  BEGIN load(y);
    IF x.mode = OAB.Const THEN APut1(Ror, y.r, y.r, (x.a + 1) MOD 20H); DEC(RH)
    ELSE load(x); APut1(Add, x.r, x.r, 1); APut0(Ror, y.r, y.r, x.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END In;

  PROCEDURE SetOp*(op: INTEGER; VAR x, y: Item);   (* x := x op y *)
    VAR xset, yset: SET; (*x.type.form = Set*)
  BEGIN
    IF (x.mode = OAB.Const) & (y.mode = OAB.Const) THEN
      xset := SYSTEM.VAL(SET, x.a); yset := SYSTEM.VAL(SET, y.a);
      IF op = OAS.plus THEN xset := xset + yset
      ELSIF op = OAS.minus THEN xset := xset - yset
      ELSIF op = OAS.times THEN xset := xset * yset
      ELSIF op = OAS.rdiv THEN xset := xset / yset
      END ;
      x.a := SYSTEM.VAL(INTEGER, xset)
    ELSIF y.mode = OAB.Const THEN
      load(x);
      IF op = OAS.plus THEN APut1a(Ior, x.r, x.r, y.a)
      ELSIF op = OAS.minus THEN APut1a(Ann, x.r, x.r, y.a)
      ELSIF op = OAS.times THEN APut1a(And, x.r, x.r, y.a)
      ELSIF op = OAS.rdiv THEN APut1a(Xor, x.r, x.r, y.a)
      END ;
    ELSE load(x); load(y);
      IF op = OAS.plus THEN APut0(Ior, RH-2, x.r, y.r)
      ELSIF op = OAS.minus THEN APut0(Ann, RH-2, x.r, y.r)
      ELSIF op = OAS.times THEN APut0(And, RH-2, x.r, y.r)
      ELSIF op = OAS.rdiv THEN APut0(Xor, RH-2, x.r, y.r)
      END ;
      DEC(RH); x.r := RH-1
    END 
  END SetOp;

  (* Code generation for relations *)

  PROCEDURE IntRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
  BEGIN
    IF (y.mode = OAB.Const) & (y.type.form # OAB.Proc) THEN
      load(x);
      IF (y.a # 0) OR ~(op IN {OAS.eql, OAS.neq}) OR (Get32(code,pc-1) DIV 40000000H # -2) THEN APut1a(Cmp, x.r, x.r, y.a) END ;
      DEC(RH)
    ELSE
      IF (x.mode = Cond) OR (y.mode = Cond) THEN OAS.Mark("not implemented") END ;
      load(x); load(y); APut0(Cmp, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - OAS.eql])
  END IntRelation;

  PROCEDURE RealRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
  BEGIN load(x);
    IF (y.mode = OAB.Const) & (y.a = 0) THEN DEC(RH)
    ELSE load(y); APut0(Fsb, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - OAS.eql])
  END RealRelation;

  PROCEDURE StringRelation*(op: INTEGER; VAR x, y: Item);   (* x := x < y *)
    (*x, y are char arrays or strings*)
  BEGIN
    IF x.type.form = OAB.String THEN loadStringAdr(x) ELSE loadAdr(x) END ;
    IF y.type.form = OAB.String THEN loadStringAdr(y) ELSE loadAdr(y) END ;
    APut2(Ldr+1, RH, x.r, 0); APut1(Add, x.r, x.r, 1);
    APut2(Ldr+1, RH+1, y.r, 0); APut1(Add, y.r, y.r, 1);
    APut0(Cmp, RH+2, RH, RH+1); APut3(BC, NE, 2);
    APut1(Cmp, RH+2, RH, 0); APut3(BC, NE, -8);
    DEC(RH, 2); SetCC(x, relmap[op - OAS.eql])
  END StringRelation;

  (* Code generation of Assignments *)

  PROCEDURE StrToChar*(VAR x: Item);
  BEGIN x.type := OAB.charType; DEC(strx, 4); x.a := ORD(str[x.a])
  END StrToChar;

  PROCEDURE Store*(VAR x, y: Item); (* x := y *)
    VAR op: INTEGER;
  BEGIN  load(y);
    IF x.type.size = 1 THEN op := Str+1 ELSE op := Str END ;
    IF x.mode = OAB.Var THEN
      IF x.r > 0 THEN (*local*) APut2(op, y.r, SP, x.a + frame)
      ELSE GetSB(x.r); APut2(op, y.r, RH, x.a)
      END
    ELSIF x.mode = OAB.Par THEN APut2(Ldr, RH, SP, x.a + frame); APut2(op, y.r, RH, x.b);
    ELSIF x.mode = RegI THEN APut2(op, y.r, x.r, x.a); DEC(RH);
    ELSE OAS.Mark("bad mode in Store")
    END ;
    DEC(RH)
  END Store;

  PROCEDURE StoreStruct*(VAR x, y: Item); (* x := y, frame = 0 *)
    VAR s, pc0: INTEGER;
  BEGIN
    IF y.type.size # 0 THEN
      loadAdr(x); loadAdr(y);
      IF (x.type.form = OAB.Array) &  (x.type.len > 0) THEN
        IF y.type.len >= 0 THEN 
          IF x.type.size = y.type.size THEN APut1a(Mov, RH, 0, (y.type.size+3) DIV 4)
          ELSE OAS.Mark("different length/size, not implemented")
          END
        ELSE (*y  open array*) APut2(Ldr, RH, SP, y.a+4); s := y.type.base.size;  (*element size*)
          pc0 := pc; APut3(BC, EQ, 0);
          IF s = 1 THEN APut1(Add, RH, RH, 3); APut1(Asr, RH, RH, 2)
          ELSIF s # 4 THEN APut1a(Mul, RH, RH, s DIV 4)
          END ;
          IF check THEN
            APut1a(Mov, RH+1, 0, (x.type.size+3) DIV 4); APut0(Cmp, RH+1, RH, RH+1); Trap(GT, 3)
          END ;
          fix(pc0, pc + 5 - pc0)
        END
      ELSIF x.type.form = OAB.Record THEN APut1a(Mov, RH, 0, x.type.size DIV 4)
      ELSE OAS.Mark("inadmissible assignment")
      END ;
      APut2(Ldr, RH+1, y.r, 0); APut1(Add, y.r, y.r, 4);
      APut2(Str, RH+1, x.r, 0); APut1(Add, x.r, x.r, 4);
      APut1(Sub, RH, RH, 1); APut3(BC, NE, -6)
    END ;
    RH := 0
  END StoreStruct;

  PROCEDURE CopyString*(VAR x, y: Item);  (* x := y *) 
     VAR len: INTEGER;
   BEGIN loadAdr(x); len := x.type.len;
    IF len >= 0 THEN
      IF len <  y.b THEN OAS.Mark("string too long") END
    ELSIF check THEN APut2(Ldr, RH, SP, x.a+4);  (*open array len, frame = 0*)
      APut1(Cmp,RH, RH, y.b); Trap(LT, 3)
    END ;
    loadStringAdr(y);
    APut2(Ldr, RH, y.r, 0); APut1(Add, y.r, y.r, 4);
    APut2(Str, RH, x.r, 0); APut1(Add, x.r, x.r, 4);
    APut1(Asr, RH, RH, 24); APut3(BC, NE,  -6);  RH := 0
   END CopyString;
  
  (* Code generation for parameters *)
  
  PROCEDURE OpenArrayParam*(VAR x: Item);
  BEGIN loadAdr(x);
    IF x.type.len >= 0 THEN APut1a(Mov, RH, 0, x.type.len) ELSE APut2(Ldr, RH, SP, x.a+4+frame) END ;
    incR
  END OpenArrayParam;

  PROCEDURE VarParam*(VAR x: Item; ftype: OAB.Type);
    VAR xmd: INTEGER;
  BEGIN xmd := x.mode; loadAdr(x);
    IF (ftype.form = OAB.Array) & (ftype.len < 0) THEN (*open array*)
      IF x.type.len >= 0 THEN APut1a(Mov, RH, 0, x.type.len) ELSE  APut2(Ldr, RH, SP, x.a+4+frame) END ;
      incR
    ELSIF ftype.form = OAB.Record THEN
      IF xmd = OAB.Par THEN APut2(Ldr, RH, SP, x.a+4+frame); incR ELSE loadTypTagAdr(x.type) END
    END
  END VarParam;

  PROCEDURE ValueParam*(VAR x: Item);
  BEGIN load(x)
  END ValueParam;

  PROCEDURE StringParam*(VAR x: Item);
  BEGIN loadStringAdr(x); APut1(Mov, RH, 0, x.b); incR  (*len*)
  END StringParam;

  (*For Statements*)

  PROCEDURE For0*(VAR x, y: Item);
  BEGIN load(y)
  END For0;

  PROCEDURE For1*(VAR x, y, z, w: Item; VAR L: INTEGER);
  BEGIN 
    IF z.mode = OAB.Const THEN APut1a(Cmp, RH, y.r, z.a)
    ELSE load(z); APut0(Cmp, RH-1, y.r, z.r); DEC(RH)
    END ;
    L := pc;
    IF w.a > 0 THEN APut3(BC, GT, 0)
    ELSIF w.a < 0 THEN APut3(BC, LT, 0)
    ELSE OAS.Mark("zero increment"); APut3(BC, MI, 0)
    END ;
    Store(x, y)
  END For1;

  PROCEDURE For2*(VAR x, y, w: Item);
  BEGIN load(x); DEC(RH); APut1a(Add, x.r, x.r, w.a)
  END For2;

  (* Branches, procedure calls, procedure prolog and epilog *)

  PROCEDURE Here*(): INTEGER;
  BEGIN RETURN pc DIV 4
  END Here;

  PROCEDURE FJump*(VAR L: INTEGER);
  BEGIN APut3(BC, 7, L); L := (pc DIV 4)-1
  END FJump;

  PROCEDURE CFJump*(VAR x: Item);
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    APut3(BC, negated(x.r), x.a); FixLink(x.b); x.a := (pc DIV 4)-1
  END CFJump;

  PROCEDURE BJump*(L: INTEGER);
  BEGIN APut3(BC, 7, L-(pc DIV 4)-1)
  END BJump;

  PROCEDURE CBJump*(VAR x: Item; L: INTEGER);
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    APut3(BC, negated(x.r), L-(pc DIV 4)-1); FixLink(x.b); FixLinkWith(x.a, L)
  END CBJump;

  PROCEDURE Fixup*(VAR x: Item);
  BEGIN FixLink(x.a)
  END Fixup;

  PROCEDURE SaveRegs(r: INTEGER);  (* R[0 .. r-1]*)
    VAR r0: INTEGER;
  BEGIN (*r > 0*) r0 := 0;
    APut1(Sub, SP, SP, r*4); INC(frame, 4*r);
    REPEAT APut2(Str, r0, SP, (r-r0-1)*4); INC(r0) UNTIL r0 = r
  END SaveRegs;

  PROCEDURE RestoreRegs(r: INTEGER); (*R[0 .. r-1]*)
    VAR r0: INTEGER;
  BEGIN (*r > 0*) r0 := r;
    REPEAT DEC(r0); APut2(Ldr, r0, SP, (r-r0-1)*4) UNTIL r0 = 0;
    APut1(Add, SP, SP, r*4); DEC(frame, 4*r)
  END RestoreRegs;

  PROCEDURE PrepCall*(VAR x: Item; VAR r: INTEGER);
  BEGIN (*x.type.form = OAB.Proc*)
    IF x.mode > OAB.Par THEN load(x) END ;
    r := RH;
    IF RH > 0 THEN SaveRegs(RH); RH := 0 END
  END PrepCall;

  PROCEDURE Call*(VAR x: Item; r: INTEGER);
  BEGIN (*x.type.form = OAB.Proc*)
    IF x.mode = OAB.Const THEN
      IF x.r >= 0 THEN APut3(BL, 7, (x.a (*DIV 4*) )-pc-1)
      ELSE (*imported*)
        IF pc - fixorgP < 1000H THEN
          APutFixP( -x.r, x.a, pc-fixorgP ); fixorgP := pc-1 
(*          APut3(BL, 7, ((-x.r) * 100H + x.a) * 1000H + pc-fixorgP); fixorgP := pc-1 *)
        ELSE OAS.Mark("fixup impossible")
        END
      END
    ELSE
      IF x.mode <= OAB.Par THEN load(x); DEC(RH)
      ELSE APut2(Ldr, RH, SP, 0); APut1(Add, SP, SP, 4); DEC(r); DEC(frame, 4)
      END ;
      IF check THEN Trap(EQ, 5) END ;
      APut3(BLR, 7, RH)
    END ;
    IF x.type.base.form = OAB.NoTyp THEN (*procedure*) RH := 0
    ELSE (*function*)
      IF r > 0 THEN APut0(Mov, r, 0, 0); RestoreRegs(r) END ;
      x.mode := Reg; x.r := r; RH := r+1
    END
  END Call;

(*  procedure call prologue / epilogue
 ff 43 00 d1 	sub	sp, sp, #16     -- APut1 Sub SP SP 16
 fd 7b 00 a9 	stp	x29, x30, [sp]  -- APut2 Stp R29 SP (29 & 30)
 fd 03 00 91 	mov	x29, sp         -- APut1 Mov R29 SP

 fd 7b 40 a9 	ldp	x29, x30, [sp]  -- APut2 Ldp R29 SP (29 & 30)
 ff 43 00 91 	add	sp, sp, #16     -- APut1 Add SP SP 16
 c0 03 5f d6 	ret                     -- APut3 BR  7 LNK  (unconditional)
*)

(*
 fd 7b bf a9 	stp	x29, x30, [sp, #-16]!
 fd 03 00 91 	mov	x29, sp
 ff 03 01 d1 	sub	sp, sp, #64
 ff 03 01 91 	add	sp, sp, #64
 fd 7b c1 a8 	ldp	x29, x30, [sp], #16
 c0 03 5f d6 	ret
*)  



  PROCEDURE Enter*(parblksize, locblksize: INTEGER; int: BOOLEAN);
    VAR a, r: INTEGER;
  BEGIN frame := 0;
    IF ~int THEN (*procedure prolog*)
      IF locblksize >= 10000H THEN OAS.Mark("too many locals") END ;
      a:=locblksize MOD 16;
      IF a # 0 THEN INC(locblksize,16-a) END;
      a := 8; r := 0;
      APut1(Sub, SP, SP, 16); APut2(Stp, FP, SP, -16); APut1(Mov, FP, SP, 0); APut1(Sub, SP, SP, locblksize); 
      WHILE a < parblksize DO APut2(Str, r, SP, a); INC(r); INC(a, 8) END
    ELSE (*interrupt procedure*)
      APut1(Sub, SP, SP, locblksize); APut2(Stp, 0, SP, 0); APut2(Stp, 2, SP, 16)
      (*R0, R1, R2, R3 saved on stack*)
    END
  END Enter;

  PROCEDURE Return*(form: INTEGER; VAR x: Item; size: INTEGER; int: BOOLEAN);
    VAR a: INTEGER;
  BEGIN
    IF form # OAB.NoTyp THEN load(x) END ;
    a:=size MOD 16;
    IF a # 0 THEN INC(size,16-a) END;
    IF ~int THEN (*procedure epilog*) 
      APut1(Add, SP, SP, size);    
      APut2(Ldp, FP, SP, 16);
      APut1(Add, SP, SP, 16);    
      APut3(BR, 7, LNK)
    ELSE (*interrupt return, restore R2, R1, R0*)
      APut2(Ldr, 2, SP, 8); APut2(Ldr, 1, SP, 4); APut2(Ldr, 0, SP, 0); APut1(Add, SP, SP, size);
      APut3(BR, 7, NTR) (*RTI*)
    END ;
    RH := 0
  END Return;

  (* In-line code procedures*)

  PROCEDURE Increment*(upordown: INTEGER; VAR x, y: Item);
    VAR op, zr, v: INTEGER;
  BEGIN (*frame = 0*)
    IF upordown = 0 THEN op := Add ELSE op := Sub END ;
    IF x.type = OAB.byteType THEN v := 1 ELSE v := 0 END ;
    IF y.type.form = OAB.NoTyp THEN y.mode := OAB.Const; y.a := 1 END ;
    IF (x.mode = OAB.Var) & (x.r > 0) THEN
      zr := RH; APut2(Ldr+v, zr, SP, x.a); incR;
      IF y.mode = OAB.Const THEN APut1a(op, zr, zr, y.a) ELSE load(y); APut0(op, zr, zr, y.r); DEC(RH) END ;
      APut2(Str+v, zr, SP, x.a); DEC(RH)
    ELSE loadAdr(x); zr := RH; APut2(Ldr+v, RH, x.r, 0); incR;
      IF y.mode = OAB.Const THEN APut1a(op, zr, zr, y.a) ELSE load(y); APut0(op, zr, zr, y.r); DEC(RH) END ;
      APut2(Str+v, zr, x.r, 0); DEC(RH, 2)
    END
  END Increment;

  PROCEDURE Include*(inorex: INTEGER; VAR x, y: Item);
    VAR op, zr: INTEGER;
  BEGIN loadAdr(x); zr := RH; APut2(Ldr, RH, x.r, 0); incR;
    IF inorex = 0 THEN op := Ior ELSE op := Ann END ;
    IF y.mode = OAB.Const THEN APut1a(op, zr, zr, LSL(1, y.a))
    ELSE load(y); APut1(Mov, RH, 0, 1); APut0(Lsl, y.r, RH, y.r); APut0(op, zr, zr, y.r); DEC(RH)
    END ;
    APut2(Str, zr, x.r, 0); DEC(RH, 2)
  END Include;

  PROCEDURE Assert*(VAR x: Item);
    VAR cond: INTEGER;
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    IF x.a = 0 THEN cond := negated(x.r)
    ELSE APut3(BC, x.r, x.b); FixLink(x.a); x.b := pc-1; cond := 7
    END ;
    Trap(cond, 7); FixLink(x.b)
  END Assert; 

  PROCEDURE New*(VAR x: Item);
  BEGIN loadAdr(x); loadTypTagAdr(x.type.base); Trap(7, 0); RH := 0
  END New;

  PROCEDURE Pack*(VAR x, y: Item);
    VAR z: Item;
  BEGIN z := x; load(x); load(y);
    APut1(Lsl, y.r, y.r, 23); APut0(Add, x.r, x.r, y.r); DEC(RH); Store(z, x)
  END Pack;

  PROCEDURE Unpk*(VAR x, y: Item);
    VAR z, e0: Item;
  BEGIN  z := x; load(x); e0.mode := Reg; e0.r := RH; e0.type := OAB.intType;
    APut1(Asr, RH, x.r, 23); APut1(Sub, RH, RH, 127); Store(y, e0); incR;
    APut1(Lsl, RH, RH, 23); APut0(Sub, x.r, x.r, RH); Store(z, x)
  END Unpk;

  PROCEDURE Led*(VAR x: Item);
  BEGIN load(x); APut1(Mov, RH, 0, -60); APut2(Str, x.r, RH, 0); DEC(RH)
  END Led;

  PROCEDURE Get*(VAR x, y: Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(y, x)
  END Get;

  PROCEDURE Put*(VAR x, y: Item);
  BEGIN load(x); x.type := y.type; x.mode := RegI; x.a := 0; Store(x, y)
  END Put;

  PROCEDURE Copy*(VAR x, y, z: Item);
  BEGIN load(x); load(y);
    IF z.mode = OAB.Const THEN
      IF z.a > 0 THEN load(z) ELSE OAS.Mark("bad count") END
    ELSE load(z);
      IF check THEN Trap(LT, 3) END ;
      APut3(BC, EQ, 6)
    END ;
    APut2(Ldr, RH, x.r, 0); APut1(Add, x.r, x.r, 4);
    APut2(Str, RH, y.r, 0); APut1(Add, y.r, y.r, 4);
    APut1(Sub, z.r, z.r, 1); APut3(BC, NE, -6); DEC(RH, 3)
  END Copy;

  PROCEDURE LDPSR*(VAR x: Item);
  BEGIN (*x.mode = Const*) APut3(0, 15, x.a + 20H)
  END LDPSR;

  PROCEDURE LDREG*(VAR x, y: Item);
  BEGIN
    IF y.mode = OAB.Const THEN APut1a(Mov, x.a, 0, y.a)
    ELSE load(y); APut0(Mov, x.a, 0, y.r); DEC(RH)
    END
  END LDREG;

  (*In-line code functions*)

  PROCEDURE Abs*(VAR x: Item);
  BEGIN
    IF x.mode = OAB.Const THEN x.a := ABS(x.a)
    ELSE load(x);
      IF x.type.form = OAB.Real THEN APut1(Lsl, x.r, x.r, 1); APut1(Ror, x.r, x.r, 1)
      ELSE APut1(Cmp, x.r, x.r, 0); APut3(BC, GE, 2); APut1(Mov, RH, 0, 0); APut0(Sub, x.r, RH, x.r)
      END
    END
  END Abs;

  PROCEDURE Odd*(VAR x: Item);
  BEGIN load(x); APut1(And, x.r, x.r, 1); SetCC(x, NE); DEC(RH)
  END Odd;

  PROCEDURE Floor*(VAR x: Item);
  BEGIN load(x); APut1(Mov+U, RH, 0, 4B00H); APut0(Fad+V, x.r, x.r, RH)
  END Floor;

  PROCEDURE Float*(VAR x: Item);
  BEGIN load(x); APut1(Mov+U, RH, 0, 4B00H);  APut0(Fad+U, x.r, x.r, RH)
  END Float;

  PROCEDURE Ord*(VAR x: Item);
  BEGIN
    IF x.mode IN {OAB.Var, OAB.Par, RegI, Cond} THEN load(x) END
  END Ord;

  PROCEDURE Len*(VAR x: Item);
  BEGIN
    IF x.type.len >= 0 THEN
      IF x.mode = RegI THEN DEC(RH) END ;
      x.mode := OAB.Const; x.a := x.type.len
    ELSE (*open array*) APut2(Ldr, RH, SP, x.a + 4 + frame); x.mode := Reg; x.r := RH; incR
    END 
  END Len;

  PROCEDURE Shift*(fct: INTEGER; VAR x, y: Item);
    VAR op: INTEGER;
  BEGIN load(x);
    IF fct = 0 THEN op := Lsl ELSIF fct = 1 THEN op := Asr ELSE op := Ror END ;
    IF y.mode = OAB.Const THEN APut1(op, x.r, x.r, y.a MOD 20H)
    ELSE load(y); APut0(op, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
    END
  END Shift;

  PROCEDURE ADC*(VAR x, y: Item);
  BEGIN load(x); load(y); APut0(Add+2000H, x.r, x.r, y.r); DEC(RH)
  END ADC;

  PROCEDURE SBC*(VAR x, y: Item);
  BEGIN load(x); load(y); APut0(Sub+2000H, x.r, x.r, y.r); DEC(RH)
  END SBC;

  PROCEDURE UML*(VAR x, y: Item);
  BEGIN load(x); load(y); APut0(Mul+2000H, x.r, x.r, y.r); DEC(RH)
  END UML;

  PROCEDURE Bit*(VAR x, y: Item);
  BEGIN load(x); APut2(Ldr, x.r, x.r, 0);
    IF y.mode = OAB.Const THEN APut1(Ror, x.r, x.r, y.a+1); DEC(RH)
    ELSE load(y); APut1(Add, y.r, y.r, 1); APut0(Ror, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, MI)
  END Bit;

  PROCEDURE Register*(VAR x: Item);
  BEGIN (*x.mode = Const*)
    APut0(Mov, RH, 0, x.a MOD 10H); x.mode := Reg; x.r := RH; incR
  END Register;

  PROCEDURE H*(VAR x: Item);
  BEGIN (*x.mode = Const*)
    APut0(Mov + U + x.a MOD 2 * V, RH, 0, 0); x.mode := Reg; x.r := RH; incR
  END H;

  PROCEDURE Adr*(VAR x: Item);
  BEGIN 
    IF x.mode IN {OAB.Var, OAB.Par, RegI} THEN loadAdr(x)
    ELSIF (x.mode = OAB.Const) & (x.type.form = OAB.Proc) THEN load(x)
    ELSIF (x.mode = OAB.Const) & (x.type.form = OAB.String) THEN loadStringAdr(x)
    ELSE OAS.Mark("not addressable")
    END
  END Adr;

  PROCEDURE Condition*(VAR x: Item);
  BEGIN (*x.mode = Const*) SetCC(x, x.a)
  END Condition;

  PROCEDURE Open*(v: INTEGER; vb: BOOLEAN);
  BEGIN pc := 0; tdx := 0; strx := 0; RH := 0; fixorgP := 0; fixorgD := 0; fixorgT := 0; check := v # 0; version := v; verbose := vb;
    IF v = 0 THEN pc := 1;
      REPEAT Put32(code, pc, 0); INC(pc) UNTIL pc = 8
    END
  END Open;

  PROCEDURE SetDataSize*(dc: INTEGER);
  BEGIN varsize := dc
  END SetDataSize;

  PROCEDURE Header*;
  BEGIN entry := pc*4;
    IF version = 0 THEN Put32(code, 0, 0E7000000H-1 + pc);  APut1a(Mov, SP, 0, StkOrg0)  (*RISC-0*)
    ELSE APut1(Sub, SP, SP, 16); APut2(Stp, FP, SP, 0); APut1(Mov, FP, SP, 0)
    END
  END Header;

  PROCEDURE NofPtrs(typ: OAB.Type): INTEGER;
    VAR fld: OAB.Object; n: INTEGER;
  BEGIN
    IF (typ.form = OAB.Pointer) OR (typ.form = OAB.NilTyp) THEN n := 1
    ELSIF typ.form = OAB.Record THEN
      fld := typ.dsc; n := 0;
      WHILE fld # NIL DO n := NofPtrs(fld.type) + n; fld := fld.next END
    ELSIF typ.form = OAB.Array THEN n := NofPtrs(typ.base) * typ.len
    ELSE n := 0
    END ;
    RETURN n
  END NofPtrs;

  PROCEDURE FindPtrs(VAR R: Files.Rider; typ: OAB.Type; adr: INTEGER);
    VAR fld: OAB.Object; i, s: INTEGER;
  BEGIN
    IF (typ.form = OAB.Pointer) OR (typ.form = OAB.NilTyp) THEN Files.WriteInt(R, adr)
    ELSIF typ.form = OAB.Record THEN
      fld := typ.dsc;
      WHILE fld # NIL DO FindPtrs(R, fld.type, fld.val + adr); fld := fld.next END
    ELSIF typ.form = OAB.Array THEN
      s := typ.base.size;
      FOR i := 0 TO typ.len-1 DO FindPtrs(R, typ.base, i*s + adr) END
    END
  END FindPtrs;


  PROCEDURE Close*(VAR modid: OAS.Ident; key, nofent: INTEGER);
    VAR obj: OAB.Object;
      i, c, comsize, nofimps, nofptrs, dsize, csize: INTEGER;
(*    b: BYTE; *)
      name: OAS.Ident;
      F: Files.File; R: Files.Rider;
  BEGIN  (*exit code*)
    IF verbose THEN EmitLn; Emit("Writing object file"); EmitLn; END;
    IF version = 0 THEN APut1(Mov, 0, 0, 0); APut3(BR, 7, 0)  (*RISC-0*)
    ELSE APut2(Ldp, FP, SP, 0); APut1(Add, SP, SP, 16); APut3(BR, 7, LNK) (* Ldp = FP + LNK *)
    END ;
    IF pc MOD 2 # 0 THEN INC( pc ) END;
    obj := OAB.topScope.next; nofimps := 0; comsize := 8; nofptrs := 0;
    WHILE obj # NIL DO
      IF (obj.class = OAB.Mod) & (obj.dsc # OAB.system) THEN INC(nofimps) (*count imports*)

      ELSIF (obj.exno # 0) & (obj.class = OAB.Const) & (obj.type.form = OAB.Proc)
          & (obj.type.nofpar = 0) & (obj.type.base = OAB.noType) THEN i := 0; (*count commands*)
        WHILE obj.name[i] # 0X DO INC(i) END ;
        i := (i+8) DIV 8 * 8; INC(comsize, i+8)

      ELSIF obj.class = OAB.Var THEN INC(nofptrs, NofPtrs(obj.type))  (*count pointers*)
      END ;
      obj := obj.next
    END ;
    dsize := varsize + strx; (*varsize + strx + comsize;*)  (*varsize includes type descriptors*)
(*    dsize := (dsize + 15) DIV 16 * 16; *)
    csize := (pc + nofimps + nofent + nofptrs + 1)*8; 

    OAB.MakeFileName(name, modid, ".a64"); (*write code file*)
    F := Files.New(name); Files.Set(R, F, 0); Files.WriteString(R, modid); Files.WriteInt(R, key); Files.Write(R, version);
    Files.WriteInt(R, dsize);
    Files.WriteInt(R, csize);
    obj := OAB.topScope.next;
    IF verbose THEN Emit("Writing imports"); EmitLn; END;
    WHILE (obj # NIL) & (obj.class = OAB.Mod) DO  (*imports*)
      IF obj.dsc # OAB.system THEN Files.WriteString(R, obj(OAB.Module).orgname); Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.Write(R, 0);

    Files.WriteInt(R, tdx DIV 2); 

    i := 0;
    IF verbose THEN Emit("Writing type descriptors"); EmitLn; END;

    WHILE i < tdx DIV 2 DO c:=Get64(data,i); Files.WriteInt(R, c); INC(i) END ; (*type descriptors*)
(*
    Files.WriteInt(R, varsize - tdx*8);  (*data*)
*)
    Files.WriteInt(R, strx);
    IF verbose THEN Emit("Writing strings"); EmitLn; END;
    FOR i := 0 TO strx-1 DO Files.Write(R, ORD(str[i])) END ;  (*strings*)

    Files.WriteInt(R, pc);  (*code len*)
    IF verbose THEN Emit("Writing program code"); EmitLn; END;
    i:=0; WHILE i < pc DO 
      Files.Write( R, code[i*4] );
      Files.Write( R, code[(i*4)+1] );
      Files.Write( R, code[(i*4)+2] );
      Files.Write( R, code[(i*4)+3] );
      INC(i)
    END ;  (*program*)

    obj := OAB.topScope.next;
    IF verbose THEN Emit("Writing command entries"); EmitLn; END;
    WHILE obj # NIL DO  (*commands*)
      IF (obj.exno # 0) & (obj.class = OAB.Const) & (obj.type.form = OAB.Proc) &
          (obj.type.nofpar = 0) & (obj.type.base = OAB.noType) THEN
        Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val)
      END ;
      obj := obj.next
    END ;
    Files.Write(R, 0);

    Files.WriteInt(R, nofent); Files.WriteInt(R, entry);

    obj := OAB.topScope.next;
    IF verbose THEN Emit("Writing module entries"); EmitLn; END;
    WHILE obj # NIL DO  (*entries*)
      IF obj.exno # 0 THEN
        IF (obj.class = OAB.Const) & (obj.type.form = OAB.Proc) OR (obj.class = OAB.Var) THEN
          Files.WriteInt(R, obj.val);
        ELSIF obj.class = OAB.Typ THEN
          IF obj.type.form = OAB.Record THEN Files.WriteInt(R,  obj.type.len MOD 10000H)
          ELSIF (obj.type.form = OAB.Pointer) & ((obj.type.base.typobj = NIL) OR (obj.type.base.typobj.exno = 0)) THEN
            Files.WriteInt(R,  obj.type.base.len MOD 10000H)
          END
        END
      END ;
      obj := obj.next
    END ;

    obj := OAB.topScope.next;
    WHILE obj # NIL DO  (*pointer variables*)
      IF obj.class = OAB.Var THEN FindPtrs(R, obj.type, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteInt(R, -1);

    IF verbose THEN Emit("Writing heads of fixup lists"); EmitLn; END;
    Files.WriteInt(R, fixorgP); Files.WriteInt(R, fixorgD); Files.WriteInt(R, fixorgT); Files.WriteInt(R, entry);
    Files.Write(R, ORD("O")); Files.Register(F); Files.Close(F);
    IF verbose THEN Emit("Closing object file"); EmitLn; END
  END Close;

BEGIN relmap[0] := 1; relmap[1] := 9; relmap[2] := 5; relmap[3] := 6; relmap[4] := 14; relmap[5] := 13;
END OAG.

