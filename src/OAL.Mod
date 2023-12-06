MODULE OAL;  (*Link and create binary on ARM64; CP 21.05.2014 2020-2021*)
  IMPORT SYSTEM, Out, Files, OAS, OAB, Macho;

  CONST
    MT = 28;
    DescSize = 128;
    fcOrg = 10000C000H;

  TYPE
    Module = POINTER TO ModDesc;
    ModuleName = ARRAY 32 OF CHAR; (* ModuleName and ModDesc must match Modules.Mod *)
    Imps = POINTER TO ImpDesc;
    ImpDesc = RECORD
       m: ARRAY 16 OF INTEGER
    END ;

    ModDesc = RECORD (* 128 bytes *)
        next: Module;                                                   (*  8 *)
        key, num, dsize, csize, refcnt: INTEGER;                        (* 40 *)
        data, code, imp, cmd, ent, ptr: INTEGER;         (*addresses*)  (* 48 *)
        name: ModuleName                                                (* 32 *)
    END ;

    BFOps = RECORD
        Prepare : PROCEDURE (F: Files.File);
        Write : PROCEDURE (C: OAB.Mbin; dAt, cAt: INTEGER);
        Finish : PROCEDURE (VAR F: Files.File; K: OAB.Kbin; C, ProgEntry: INTEGER)
    END;

  VAR
    cOrg, kOrg, cAt, dAt, kAt, cLim, kLim: INTEGER;
    MTOrg, MTSpan, todboc: INTEGER;
    D,C: OAB.Mbin;
    K: OAB.Kbin;
    MRoot, M: Module;
    importing*, imported*: ModuleName;
    bfo: BFOps;   
    FLinkOne : PROCEDURE (mname: ARRAY OF CHAR; VAR newmod: Module;VAR ProgEntry: INTEGER): BOOLEAN;

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 256 OF CHAR;
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

  PROCEDURE Prepare(VAR R: Files.Rider; VAR key, dsize, csize, nofimps: INTEGER; import: Imps): BOOLEAN;
    VAR
      ok: BOOLEAN;
      size, impkey, ignore: INTEGER;
      b: BYTE;
      impname: ModuleName;
      impmod: Module;
      name1: ModuleName;
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
                import.m[nofimps] := SYSTEM.VAL(INTEGER,impmod);
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
      q, p, n, i, v: INTEGER;
      ch: CHAR;
      b: BYTE;
  BEGIN
    ok := TRUE;
    q:= dAt;
    DEC(dAt, dsize);
    IF dAt < cAt THEN
      ok:=FALSE; 
      Emit(" data extent exceeded")
    ELSE (* allocate space in data extent *)
      p:= dAt; WHILE p < q DO SYSTEM.PUT(p,1111111111111111H); INC(p,8) END;
      p:= dAt;
      DEC(dAt, DescSize);
      mod := SYSTEM.VAL(Module, dAt);       (* module record at beginning of data *)
      IF MRoot # NIL THEN  mod.num := MRoot.num + 1 ELSE mod.num := 1 END;
      mod.dsize := dsize; mod.next := MRoot; MRoot := mod;
      INC(MTSpan);
      mod.data := p - cLim + fcOrg;  (*to be adjusted at binary finalization*)
      SYSTEM.PUT(mod.num * 8 + MTOrg, p - cLim + fcOrg );


      Files.ReadInt(R, n);

      Emit("(");Out.Int(n,5);Emit(")");

      i:=0;
      WHILE i < n DO Files.ReadInt(R, v); SYSTEM.PUT(p + i*8, v); INC(i) END ; (*type descriptors*)

      Files.ReadInt(R, n);
      p := dAt + dsize + DescSize - n;
      WHILE n > 0 DO Files.Read(R, b); ch:=CHR(b); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)

      Out.Int(q - p,7);

      IF (q - p < 0) THEN
        ok:=FALSE; 
        Emit(" data overwrite of reserved space")
      END
    END
    RETURN ok
  END LoadData;


  PROCEDURE LoadCode(VAR R: Files.Rider; VAR mod: Module; VAR body, fixorgP, fixorgD, fixorgT: INTEGER; nofimps: INTEGER; VAR import: Imps): BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, n, i, md: INTEGER;
      ch: CHAR;
      b: BYTE;
  BEGIN
    ok := TRUE;
    q:= cAt;
    p:= cAt;
    mod.code := p - cOrg + fcOrg;
    Files.ReadInt(R, n);

    Out.Int(n*4,7);

    WHILE n > 0 DO (* deposit code *)
      Files.ReadInt(R, i);
      SYSTEM.PUT(p, i);
      INC(p, 8); DEC(n,2)
    END ; 

    Out.Hex(p - cAt);

    mod.imp := p - cOrg + fcOrg;
    i := 0;          (*deposit imports*)
    WHILE i < nofimps DO
      n := import.m[i] - cLim + fcOrg;
      SYSTEM.PUT(p, n); INC(p, 8); INC(i) (* also adjust at fin *)                                                                  
    END ;

    mod.cmd := p - cOrg + fcOrg;
    Files.Read(R, b); ch:=CHR(b); i:=0;
    WHILE ch # 0X DO
      b:=ORD(ch); REPEAT SYSTEM.PUT(p, b); INC(p); Files.Read(R, b); ch:=CHR(b) UNTIL ch = 0X;
      REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
      Files.ReadInt(R, n); SYSTEM.PUT(p, n); (*to be adjusted... *) INC(p, 8); Files.Read(R, b); ch:=CHR(b); INC(i);
    END ;
    REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;

    Out.Int(i,7);

    mod.ent := p - cOrg + fcOrg;
    Files.ReadInt(R, n);

    Out.Int(n,7);

    WHILE n > 0 DO Files.ReadInt(R, i); SYSTEM.PUT(p, i); INC(p, 8); DEC(n) END ;

    mod.ptr := p - cOrg + fcOrg; (*pointer references*)
    Files.ReadInt(R, i);

    Out.Int(i,7);

    WHILE (i >= 0) & (~R.eof) DO SYSTEM.PUT(p, mod.data + i (*- binStart*) ); INC(p, 8); Files.ReadInt(R, i) END ;
    SYSTEM.PUT(p, 0); INC(p, 8);
    Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
    Files.ReadInt(R, i); (*body := SYSTEM.VAL(Command, mod.code + i - binStart );*)
    body := i + q-cOrg;

    Out.Hex(body); (* body *)

    Files.Read(R, b); ch:=CHR(b);

    Emit("  ");Out.Char(ch);

    cAt := p;

    IF ch # "O" THEN (*corrupted file*)  mod := NIL; ok:=FALSE END
    RETURN ok
  END LoadCode;


  PROCEDURE FixBranches(VAR mod: Module; fixorgP: INTEGER):BOOLEAN;
    VAR
      ok: BOOLEAN;
      q, p, inst, mno, pno, disp, dest, offset, h, m, mil: INTEGER;
      im: Module;
  BEGIN
    ok := TRUE;
    q := mod.code - fcOrg + cOrg;
    p := q + fixorgP*4;
    mil := mod.imp - fcOrg + cOrg;
    WHILE p # q DO (* WHILE adr # mod.code DO *)
      SYSTEM.GET(p, inst);
      mno := inst DIV 100000H MOD 1000H;
      pno := inst DIV 1000H MOD 100H;
      disp := inst MOD 1000H;
      h:= inst DIV 100000000H * 100000000H;
      SYSTEM.GET(mil + (mno-1)*8, m); 
      im := SYSTEM.VAL(Module, m - fcOrg + cLim);
      SYSTEM.GET(im.ent - fcOrg + cOrg  + pno*8, dest);
      offset := (((dest DIV 4) + (im.code DIV 4)) - ((p - cOrg + fcOrg) DIV 4)) + 1;  
      SYSTEM.PUT(p, h + 97FFFFFFH + offset); 
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

   Out.Hex(fixorgD*4);



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
    EmitLn; Emit("   |    ");


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
    q := mod.data - fcOrg + cLim;
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


  PROCEDURE FixModuleOffsets(VAR mod: Module):BOOLEAN;
    VAR ok: BOOLEAN;
  BEGIN
    ok := TRUE;
  RETURN ok
  END FixModuleOffsets;


  PROCEDURE LinkOne*(mname: ARRAY OF CHAR; VAR newmod: Module;VAR ProgEntry: INTEGER): BOOLEAN;
    VAR
      ok: BOOLEAN;
      mod: Module;
      F: Files.File; R: Files.Rider;
      nofimps, key, dsize, csize, size : INTEGER;
      body, fixorgP, fixorgD, fixorgT: INTEGER;
      fname: OAS.Ident;
      import: Imps;
  BEGIN
    ok := FALSE; mod := MRoot; nofimps := 0; NEW(import);
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
        ok := Prepare( R, key, dsize, csize, nofimps, import );
        size := dsize + csize;

        EmitSz(fname,16);
        Out.Hex(dAt - cOrg );
        Out.Int(nofimps,7);

        IF ok THEN
          ok := LoadData( R, mod, dsize );
          zero(mod.name);
          mod.name := mname;
          mod.key := key;
          mod.refcnt := 0;
        END;

        IF ok THEN ok := LoadCode( R, mod, body, fixorgP, fixorgD, fixorgT, nofimps, import ) END;

        IF ok THEN ok := FixBranches(mod, fixorgP) END;

        IF ok THEN ok := FixLoadStores( mod, fixorgD) END;
(*
        IF ok THEN ok := FixTypeDescriptors(mod, fixorgT) END;
*)
        IF ok THEN ok := FixModuleOffsets(mod) END;


      END
    END;
    newmod :=  mod;
    IF mod # NIL THEN  ProgEntry := body ELSE ProgEntry := 0 END
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
    NEW(C); cOrg := SYSTEM.VAL(INTEGER,C); cLim:= cOrg + SYSTEM.SIZE(OAB.MbinDesc); cAt:= cOrg; dAt:=cLim;
    i:= kOrg; WHILE i < kLim DO SYSTEM.PUT(i, 0 ); INC(i,8) END;   
    i:= cOrg; WHILE i < cLim DO SYSTEM.PUT(i, 0 ); INC(i,8) END;   

    MTOrg := kOrg + 128; MTSpan := 0; MRoot := NIL;
    OAB.MakeFileName(fname, name, ".bin");
    F := Files.New(fname); 
    SetFormat( format );
    bfo.Prepare( F );

    Emit("   +  Loading          dAt      #imps    #td    q-p     cb               ce   #cmd  #entr  PRefs             Body  T        PHead ");
    EmitLn; Emit("   |    ");

    ok := LinkOne( name , M, ProgEntry );

    bfo.Write( C, dAt, cAt);

    IF ok THEN
      Emit(" Data:"); Out.Hex(cLim - dAt); Emit(" At:"); Out.Hex(10000C000H-(cLim-dAt)); Emit(" Code:"); Out.Hex(cAt - cOrg); Emit( " Entry at: "); Out.Hex(ProgEntry);EmitLn;
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

