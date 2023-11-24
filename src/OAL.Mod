MODULE OAL;  (*Link and create binary on ARM64; CP 21.05.2014 2020-2021*)
  IMPORT SYSTEM, Out, Files, OAS, OAB, Macho;

  CONST
    MT = 28;
    DescSize = 128;

  TYPE
    Module = POINTER TO ModDesc;
    ModuleName = ARRAY 32 OF CHAR; (* ModuleName and ModDesc must match Modules.Mod *)

    ModDesc = RECORD (* 128 bytes *)
        name: ModuleName;                                               (* 32 *)
        next: Module;                                                   (*  8 *)
        key, num, dsize, csize, refcnt: INTEGER;                        (* 40 *)
        data, code, imp, cmd, ent, ptr: INTEGER          (*addresses*)  (* 48 *)
    END ;

    BFOps = RECORD
        Prepare : PROCEDURE (F: Files.File);
        Write : PROCEDURE (D, C: OAB.Mbin; dsz, csz: INTEGER);
        Finish : PROCEDURE (VAR F: Files.File; K: OAB.Kbin; C, ProgEntry: INTEGER)
    END;

  VAR
    cOrg, dOrg, kOrg, cAt, dAt, kAt, cLim, dLim, kLim: INTEGER;
    MTOrg, MTSpan, todboc: INTEGER;
    D,C: OAB.Mbin;
    K: OAB.Kbin;
    MRoot, M: Module;
    importing*, imported*: ModuleName;
    bfo: BFOps;   
    FLinkOne : PROCEDURE (mname: ARRAY OF CHAR; VAR newmod: Module;VAR ProgEntry: INTEGER): BOOLEAN;

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 128 OF CHAR;
  BEGIN ss:=s; Out.String(ss);
  END Emit;

  PROCEDURE EmitSz(s: ARRAY OF CHAR;x:INTEGER);
    VAR ss: ARRAY 128 OF CHAR;
         i: INTEGER;
  BEGIN i := x - LEN(s); ss:=s;
        WHILE i > 0 DO Out.String(" "); DEC(i) END;
        Out.String(ss)
  END EmitSz;

  PROCEDURE EmitLn;
  BEGIN Out.Ln
  END EmitLn;

  PROCEDURE zero( VAR s: ARRAY OF CHAR);
    VAR i : INTEGER;
  BEGIN 
    i:=0; WHILE i < LEN(s) DO s[i]:=0X; INC(i) END
  END zero;

  PROCEDURE Prepare(VAR R: Files.Rider; VAR name1: ModuleName; VAR key, dsize, csize, nofimps: INTEGER): BOOLEAN;
    VAR
      ok: BOOLEAN;
      size, impkey, ignore: INTEGER;
      b: BYTE;
      impname: ModuleName;
      impmod: Module;
  BEGIN
    ok := TRUE;

        Files.ReadString(R, name1);
        Files.ReadInt(R, key);
        Files.Read(R, b);
        Files.ReadInt(R, dsize);
        Files.ReadInt(R, csize);
        size := dsize + csize;
        IF b # 2 THEN
          ok := FALSE;
          Emit(" version key mismatch")
        ELSE
          Files.ReadString(R, impname);   (*imports*) 
          WHILE (impname[0] # 0X) & ok DO 
            Files.ReadInt(R, impkey);
            ok := FLinkOne(impname, impmod, ignore);
            IF ok THEN
              IF impmod.key = impkey THEN
                INC(impmod.refcnt);
                INC(nofimps)
              ELSE 
                ok:=FALSE;
                Emit(" import key mismatch")
              END
            END ;  
            zero(impname);
            Files.ReadString(R, impname)
          END
        END
    RETURN ok
  END Prepare;

  PROCEDURE LoadData(VAR R: Files.Rider; VAR mod: Module; dsize: INTEGER): BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, n, i: INTEGER;
      ch: CHAR;
      b: BYTE;
  BEGIN
    ok := TRUE;
    q:= dAt;
    DEC(dAt, dsize + DescSize);
    IF dAt < dOrg THEN
      ok:=FALSE; 
      Emit(" data extent exceeded")
    ELSE (* allocate space in data extent *)
      p:= dAt;
      mod := SYSTEM.VAL(Module, p);       (* module record at beginning of data *)
      IF MRoot # NIL THEN  mod.num := MRoot.num + 1 ELSE mod.num := 1 END;
      mod.dsize := dsize; mod.next := MRoot; MRoot := mod;
      INC(MTSpan);
      INC(p, DescSize); (*jump over module descriptor*)
      mod.data := p;  (*to be adjusted at binary finalization*)
      SYSTEM.PUT(mod.num * 8 + MTOrg, p );  (*to be adjusted at binary finalization*)
      Files.ReadInt(R, n);
      WHILE n > 0 DO Files.ReadInt(R, i);  SYSTEM.PUT(p, i);  INC(p, 8); DEC(n, 8) END ; (*type descriptors*)
      Files.ReadInt(R, n);
      WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 8); DEC(n, 8) END ;  (*variable space*)
      Files.ReadInt(R, n);
      WHILE n > 0 DO Files.Read(R, b); ch:=CHR(b); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)

      Out.Int(q - p,7);

      IF (q - p < 0) THEN
        ok:=FALSE; 
        Emit(" data overwrite of reserved space")
      END
    END
    RETURN ok
  END LoadData;


  PROCEDURE LoadCode(VAR R: Files.Rider; VAR mod: Module; VAR fixorgP, fixorgD, fixorgT: INTEGER; nofimps: INTEGER): BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, n, i: INTEGER;
      ch: CHAR;
      b: BYTE;
  BEGIN
    ok := TRUE;
    q:= cAt;
    p:= cAt;
    Files.ReadInt(R, n);

    Out.Int(n*4,7);

    WHILE n > 0 DO
      Files.ReadInt(R, i);
      SYSTEM.PUT(p, i);
      INC(p, 8); DEC(n,2)
    END ; 

    Out.Hex(p - cAt);

    mod.imp := p;  (*copy imports*)
    i := 0;
    WHILE i < nofimps DO
(*      xmod:=import[i]; *) (*should go in SYSTEM.PUT *)
      SYSTEM.PUT(p, 0); INC(p, 8); INC(i)                                                                   
    END ;
    mod.cmd := p; (*commands*) (*to be adjusted at binary finalization*)
    Files.Read(R, b); ch:=CHR(b); i:=0;
    WHILE ch # 0X DO
      b:=ORD(ch); REPEAT SYSTEM.PUT(p, b); INC(p); Files.Read(R, b); ch:=CHR(b) UNTIL ch = 0X;
      REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
      Files.ReadInt(R, n); SYSTEM.PUT(p, n); (*to be adjusted... *) INC(p, 8); Files.Read(R, b); ch:=CHR(b); INC(i);
    END ;

    Out.Int(i,7);

    REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
    mod.ent := p; (*entries*) (*to be adjusted at binary finalization*)
    Files.ReadInt(R, n);

    Out.Int(n,7);

    WHILE n > 0 DO Files.ReadInt(R, i); SYSTEM.PUT(p, i); INC(p, 8); DEC(n) END ;
    mod.ptr := p; (*pointer references*) (*to be adjusted at binary finalization*)
    Files.ReadInt(R, i);

    Out.Int(i,7);

    WHILE (i >= 0) & (~R.eof) DO SYSTEM.PUT(p, mod.data + i (*- binStart*) ); INC(p, 8); Files.ReadInt(R, i) END ;
    SYSTEM.PUT(p, 0); INC(p, 8);
    Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
    Files.ReadInt(R, i); (*body := SYSTEM.VAL(Command, mod.code + i - binStart );*)

    Out.Hex(i);

    mod.ent := i + q-cOrg;
    Files.Read(R, b); ch:=CHR(b);

    Emit("  ");Out.Char(ch); EmitLn; Emit("   |    ");

    cAt := p;
    IF ch # "O" THEN (*corrupted file*)  mod := NIL; ok:=FALSE END
    RETURN ok
  END LoadCode;


  PROCEDURE p2v(a:INTEGER):INTEGER;
  BEGIN
    RETURN( a - cOrg + 10000C000H)
  END p2v;


  PROCEDURE FixBranches(fixorgP: INTEGER):BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, inst, mno, pno, disp: INTEGER;
  BEGIN
    ok := TRUE;
    (*fixup of BL*)
    (*adr := mod.code + fixorgP*4; *)
    p := q + fixorgP*4;
    Emit("   >    fixorgP: ");Out.Hex(p2v(q));Out.Int(p-q,8);Out.Hex(p2v(p));EmitLn;
    WHILE p # q DO (* WHILE adr # mod.code DO *)
      SYSTEM.GET(p, inst);
      mno := inst DIV 100000H MOD 10H;
      pno := inst DIV 1000H MOD 100H;
      disp := inst MOD 1000H;
      Emit("   >        Fix: ");Out.Hex(p2v(p));Out.Int(disp,8);EmitLn;
(*  
      SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
      SYSTEM.GET(impmod.ent + pno*4, dest); dest := dest + impmod.code - binStart;
      offset := (dest - (adr - binStart) - 4) DIV 4;
      SYSTEM.PUT(adr, (offset MOD 1000000H) + 0F7000000H); 
*)  
      p := p - disp*4;
      IF p < q THEN
        p := q; ok:= FALSE;
        Emit(" broken fixorgP chain ")
      END
    END ;
    RETURN ok
  END FixBranches;


  PROCEDURE FixLoadStores(VAR mod: Module; fixorgD: INTEGER):BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, a, v, i, inst, mno, disp: INTEGER;
  BEGIN
    ok := TRUE;

   (*fixup of LDR/STR/ADD*)
   (* adr := mod.code + fixorgD*4; *)
   p := q + fixorgD*4;
   WHILE p # q DO (*WHILE adr # mod.code DO *)
     SYSTEM.GET(p, inst);
     mno := inst DIV 100000H MOD 10H;
     disp := inst MOD 1000H;
     a:=inst DIV 1000000H MOD 20H;
     v:=inst DIV 20000000H MOD 8;
     Out.Char(CHR(ORD("0")+a));
     IF v = 0 THEN (* Ldr *) v:=0F9400000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 1 THEN (* Str *) v:=0F9000000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 2 THEN (* Ldr *) v:=0F9400000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 3 THEN (* Str *) v:=0F9000000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 4 THEN (* Ldr *) v:=0F9400000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 5 THEN (* Str *) v:=0F9000000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 6 THEN (* Ldr *) v:=0F9400000H + (mod.num * 400H) + (MT*20H) + a END;
     IF v = 7 THEN (* Str *) v:=0F9000000H + (mod.num * 400H) + (MT*20H) + a END;
   
   
     IF mno = 0 THEN  (*global*)
      SYSTEM.GET(p, i); i:=(i DIV 100000000H)*100000000H + v;
      SYSTEM.PUT(p, i)  
      (*SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + mod.num * 4) *) 
     ELSE (*import*)
(* 
       SYSTEM.GET(mod.imp + (mno-1)*4, impmod); v := impmod.num;
       SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + v*4); 
       SYSTEM.GET(adr+4, inst); vno := inst MOD 100H;
       SYSTEM.GET(impmod.ent + vno*4, offset);
       IF ODD(inst DIV 100H) THEN offset := offset + impmod.code - impmod.data END ;
      SYSTEM.PUT(adr+4, inst DIV 10000H * 10000H + offset  ) 
*) 
      SYSTEM.PUT(p,55555555H);
     END ;
   
     p := p - disp*4
   END ;


    RETURN ok
  END FixLoadStores;


  PROCEDURE FixTypeDescriptors(VAR mod: Module; fixorgT: INTEGER):BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, inst, mno, vno, disp: INTEGER;
  BEGIN
    ok := TRUE;

    (*fixup of type descriptors*)
    
    (* adr := mod.data + fixorgT*4;*)
    p := q + fixorgT*4;
    WHILE p # q  DO (*WHILE adr # mod.data DO*)
      SYSTEM.GET(p, inst);
      mno := inst DIV 1000000H MOD 10H;
      vno := inst DIV 1000H MOD 1000H;
      disp := inst MOD 1000H;
      Emit("/");
(*  
      IF mno = 0 THEN                                              (*global*)
         inst := mod.data - binStart + vno
      ELSE                                                                 (*import*)
        SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
        SYSTEM.GET(impmod.ent + vno*4, offset);
        inst := impmod.data + offset - binStart
      END ;
      SYSTEM.PUT(adr, inst); 
*)  
      p := p - disp*4 
    END ;
    EmitLn;

    RETURN ok
  END FixTypeDescriptors;


  PROCEDURE LinkOne*(mname: ARRAY OF CHAR; VAR newmod: Module;VAR ProgEntry: INTEGER): BOOLEAN;
    VAR
      ok: BOOLEAN;
      mod: Module;
      F: Files.File; R: Files.Rider;
      nofimps, key, dsize, csize, size : INTEGER;
      fixorgP, fixorgD, fixorgT: INTEGER;
      fname: OAS.Ident;
      name1: ModuleName;
  BEGIN
    ok := FALSE; mod := MRoot; nofimps := 0;
    WHILE (mod # NIL) & (mname # mod.name) DO mod := mod.next END ;
    IF mod # NIL THEN 
      ok := TRUE (* module already linked *)
    ELSE
      OAB.MakeFileName(fname, mname, ".a64");
      F := Files.Old(fname); 
      IF F = NIL THEN
          Emit(" module file not found")
      ELSE
        Files.Set(R, F, 0);
        ok := Prepare( R, name1, key, dsize, csize, nofimps );
        size := dsize + csize;

        EmitSz(fname,16);
        Out.Int(nofimps,7);

        IF ok THEN
          ok := LoadData( R, mod, dsize );
          mod.name := mname;
          mod.key := key;
          mod.refcnt := 0;
        END;

        IF ok THEN ok := LoadCode( R, mod, fixorgP, fixorgD, fixorgT, nofimps ) END;
(*
        IF ok THEN ok := FixBranches(fixorgP) END;

        IF ok THEN ok := FixLoadStores(mod, fixorgD) END;

        IF ok THEN ok := FixTypeDescriptors(mod, fixorgT) END;
*)
      END
    END;
    newmod :=  mod;
    IF mod # NIL THEN  ProgEntry := mod.ent ELSE ProgEntry := 0 END
    RETURN ok
  END LinkOne;

  PROCEDURE SetFormat( format: INTEGER);
  BEGIN
      IF format = OAB.BIN   THEN bfo.Prepare:=NIL; bfo.Write:=NIL; bfo.Finish:=NIL END;
      IF format = OAB.RSC64 THEN bfo.Prepare:=NIL; bfo.Write:=NIL; bfo.Finish:=NIL END;
      IF format = OAB.ELF64 THEN bfo.Prepare:=NIL; bfo.Write:=NIL; bfo.Finish:=NIL END;
      IF format = OAB.MACHO THEN
        bfo.Prepare := Macho.Prepare;
        bfo.Write := Macho.Write;
        bfo.Finish := Macho.Finish;
      END;
      IF format = OAB.PE64  THEN bfo.Prepare:=NIL; bfo.Write:=NIL; bfo.Finish:=NIL END;
  END SetFormat;


  PROCEDURE Link*(name: ARRAY OF CHAR; format: INTEGER);

    VAR
      ProgEntry: INTEGER;
(*      Lname : ModuleName; *)
      fname: OAS.Ident;
      F: Files.File;
(*      M, p : Module;  *)
      i : INTEGER;
      ok: BOOLEAN;
  BEGIN
    todboc := 10000C000H; (* 100100000H 4G + 1M *) 
    NEW(K); kOrg := SYSTEM.VAL(INTEGER,K); kLim:= kOrg + SYSTEM.SIZE(OAB.KbinDesc); kAt:= kOrg;
    NEW(D); dOrg := SYSTEM.VAL(INTEGER,D); dLim:= dOrg + SYSTEM.SIZE(OAB.MbinDesc); dAt:= dLim; (* grows down *)
    NEW(C); cOrg := SYSTEM.VAL(INTEGER,C); cLim:= cOrg + SYSTEM.SIZE(OAB.MbinDesc); cAt:= cOrg;
    i:= kOrg; WHILE i < kLim DO SYSTEM.PUT(i, 0 ); INC(i,8) END;   
    i:= dOrg; WHILE i < dLim DO SYSTEM.PUT(i, 0 ); INC(i,8) END;   
    i:= cOrg; WHILE i < cLim DO SYSTEM.PUT(i, 0 ); INC(i,8) END;   

    MTOrg := kOrg + 128; MTSpan := 0; MRoot := NIL;
    OAB.MakeFileName(fname, name, ".bin");
    F := Files.New(fname); 
    SetFormat( format );
    bfo.Prepare( F );

    Emit("   +  Loading  #imps    q-p     cb               ce   #cmd  #entr  PRefs             Body  T "); EmitLn; Emit("   |    ");

    ok := LinkOne( name , M, ProgEntry );

    bfo.Write( D, C, dLim - dAt, cAt - cOrg );

    IF ok THEN
      Emit( "                                                      Entry at: "); Out.Hex(ProgEntry);EmitLn;
      bfo.Finish( F, K, 1, ProgEntry );
      Files.Register(F); Files.Close(F);
      Emit( " linked with "); Out.Int(MTSpan,4);Emit(" modules.");EmitLn
    ELSE
      Files.Close(F);
      Emit( " not linked."); EmitLn
    END
  END Link;


BEGIN FLinkOne := LinkOne;
(*  Emit("Silicon Oberon Linker   2023.09.24"); EmitLn *)
END OAL.

