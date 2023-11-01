MODULE OAL;  (*Link and create binary on ARM64; CP 21.05.2014 2020-2021*)
  IMPORT SYSTEM, Out, Files, OAS, OAB, Macho;

  CONST
    versionkey = 1X;
    MT = 12;
    DescSize = 128;

  TYPE
    Module = POINTER TO ModDesc;
    Command = PROCEDURE;
    ModuleName = ARRAY 32 OF CHAR; (* ModuleName and ModDesc must match Modules.Mod *)

    ModDesc = RECORD (* 128 bytes *)
        name: ModuleName;                                               (* 32 *)
        next: Module;                                                   (*  8 *)
        key, num, size, refcnt: INTEGER;                                (* 32 *)
        data, code, imp, cmd, ent, ptr, unused: INTEGER  (*addresses*)  (* 56 *)
    END ;

    BFOps = RECORD
        Prepare : PROCEDURE (F: Files.File);
        Write : PROCEDURE (I: OAB.Mbin; DataEnd, CodeEnd, ProgEntry: INTEGER);
        Finish : PROCEDURE (VAR F: Files.File; K: OAB.Kbin; C, ProgEntry: INTEGER)
    END;

  VAR
    binroot, cbinroot, M: Module;
    modid: OAS.Ident; 
    MTOrg, MTSpan, binStart, kStart, binAllocPtr, res*: INTEGER;
    importing*, imported*: ModuleName;
    limit: INTEGER;
    MDCache: ARRAY 128 OF ModDesc;
    I: OAB.Mbin;
    K: OAB.Kbin;
    bfo: BFOps;   

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 128 OF CHAR;
  BEGIN ss:=s; Out.String(ss);
  END Emit;

  PROCEDURE EmitLn;
  BEGIN Out.Ln
  END EmitLn;

  PROCEDURE zero( VAR s: ARRAY OF CHAR);
    VAR i : INTEGER;
  BEGIN 
    i:=0; WHILE i < LEN(s) DO s[i]:=0X; INC(i) END
  END zero;

  PROCEDURE error(n: INTEGER; name: ModuleName);
  BEGIN 
    res := n;
    importing := name;
    Emit("!"); 
    Emit(name);
    Out.Int(res,3)
  END error;

  PROCEDURE Check(s: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN 
    ch := s[0]; res := 1; i := 1;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT 
        ch := s[i]; 
        INC(i)
      UNTIL ~((ch >= "0") & (ch <= "9") OR (ch >= "A") & (ch <= "Z")
           OR (ch >= "a") & (ch <= "z") OR (ch = ".")) OR (i = 32);
      IF (i < 32) & (ch = 0X) THEN 
        res := 0
      END
    END
  END Check;

  PROCEDURE LinkOne*(name: ARRAY OF CHAR; VAR newmod: Module;VAR DataEnd, CodeEnd, ProgEntry: INTEGER): BOOLEAN;
    VAR mod, cmod, impmod, xmod: Module;
      i, n, key, impkey, mno, nofimps, size, flen, xlat: INTEGER;
      p, u, v, w: INTEGER;  (*addresses*)
      ch: CHAR;
      b: BYTE;
      body: Command;
      fixorgP, fixorgD, fixorgT: INTEGER;
      disp, adr, imgadr, inst, pno, vno, dest, offset: INTEGER;
      name1, impname: ModuleName;
      fname: OAS.Ident;
      F: Files.File; R: Files.Rider;
      import: ARRAY 16 OF Module;
      ok: BOOLEAN;
  BEGIN 
    ok:=TRUE;
    mod := binroot; res := 0; nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod = NIL THEN 
      OAB.MakeFileName(fname, name, ".a64");
      F := Files.Old(fname); 
      IF F # NIL THEN
        Files.Set(R, F, 0);
        flen := Files.Length(F);
        Files.ReadString(R, name1);
        Files.ReadInt(R, key);
        Files.Read(R, b);
        ch:=CHR(b);
        Files.ReadInt(R, size);
        importing := name1;
        IF ch = versionkey THEN
          Files.ReadString(R, impname);   (*imports*) 
          WHILE (impname[0] # 0X) & (res = 0) DO 
            Files.ReadInt(R, impkey); (* Emit("[");Emit(impname);Emit(":");Out.Hex(impkey);Emit("]"); *)
            ok := LinkOne(impname, impmod, DataEnd, CodeEnd, ProgEntry);
            import[nofimps] := impmod;
            importing := name1;
            IF res = 0 THEN
              IF impmod.key = impkey THEN
                INC(impmod.refcnt);
                INC(nofimps)
              ELSE 
                ok:=FALSE;
                error(3, name1);
                Emit("impmod.key: ");
                Out.Hex(impmod.key);
                Emit(" impkey:");
                Out.Hex(impkey);
                imported := impname
              END
            END ;  
            zero(impname);
            Files.ReadString(R, impname)
          END
        ELSE
          Emit(" version key mismatch"); Out.Int( b, 4 ); Emit(" vs"); Out.Int( ORD(versionkey), 4 ); Emit(" ");
          ok:=FALSE; error(2, name1) 
        END ;
      ELSE  ok:=FALSE; error(1, name1) 
      END ;
      Emit("   +    Loading: ");Emit(fname);EmitLn;
      Emit("   |       Size: ");Out.Int(flen,16);EmitLn;
      Emit("   |       Name: ");Emit(name1);EmitLn;
      Emit("   |        Key: ");Out.Hex(key);EmitLn;
      Emit("   | Versionkey: ");Out.Hex(b);EmitLn;
      Emit("   |    nofimps: ");Out.Int(nofimps,16);EmitLn;
      Emit("   |   CodeSize: ");Out.Int(size,16);EmitLn;
      IF ok THEN 
        INC(size, DescSize);
        IF binAllocPtr + size < limit THEN (*allocate*)
            p:= binAllocPtr; 
            i:=p; WHILE i < 1024*1024*16  DO SYSTEM.PUT( i, 0); INC(i,8) END;
            mod := SYSTEM.VAL(Module, p);       (* module record at beginning of data *)
            cmod := SYSTEM.VAL(Module, SYSTEM.ADR(MDCache[MTSpan]));
            IF binroot # NIL THEN  mod.num := binroot.num + 1; cmod.num := cbinroot.num + 1
            ELSE mod.num := 1; cmod.num := 1
            END;
            mod.size := size; cmod.size := size;
            mod.next := binroot; binroot := mod;
            cmod.next := cbinroot; cbinroot := cmod; INC(MTSpan);
            Emit("   |    ModSize: ");Out.Int(mod.size,16);EmitLn
        ELSE ok:=FALSE; error(7, name1)
        END
      END ; 
      IF ok THEN (*read file*)
        SYSTEM.PUT(kStart ,0FFFFFFFFFFFFFFFFH);
        SYSTEM.PUT(kStart + 8,0FFFFFFFFFFFFFFFFH);
        SYSTEM.PUT(kStart + (4000H-16),0FFFFFFFFFFFFFFFFH);
        SYSTEM.PUT(kStart + (4000H-8),0FFFFFFFFFFFFFFFFH);
        INC(p, DescSize); (*jump over module descriptor*)
        zero(mod.name);   zero(cmod.name);
        mod.name := name; cmod.name := name;
        mod.key := key;   cmod.key := key;
        mod.refcnt := 0;  cmod.refcnt := 0;
        mod.data := p - binStart;  (*data*)
        cmod.data := p - binStart;  (*data*)
        SYSTEM.PUT(mod.num * 8 + MTOrg, p );  (*module table entry*)
        Files.ReadInt(R, n);
        Emit("   |    TDBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.ReadInt(R, w);  SYSTEM.PUT(p, w);  INC(p, 8); DEC(n, 8) END ; (*type descriptors*)
        Files.ReadInt(R, n);
        Emit("   |   VarBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 8); DEC(n, 8) END ;  (*variable space*)
        Files.ReadInt(R, n);
        Emit("   |StringBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.Read(R, b); ch:=CHR(b); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)
        DataEnd:= p - binStart;
        xlat := 10000C000H - DataEnd; (* first module line between data and code *)
        mod.code := 10000C000H + ((mod.num - 1)* 4000H);  (*program*)
        cmod.code := 10000C000H + ((mod.num - 1)* 4000H);  (*program*)
        Emit("   |       xlat: ");Out.Hex(xlat);EmitLn;
        Files.ReadInt(R, n);
        Emit("   |  CodeBytes: ");Out.Int(n*4,16);EmitLn;
        WHILE n > 0 DO
          Files.ReadInt(R, w);
          SYSTEM.PUT(p, w);
          INC(p, 8); DEC(n,2)
        END ;  (*program code*)
        CodeEnd := p - binStart;
        Emit("   |    DataEnd: ");Out.Hex(DataEnd);EmitLn;
        Emit("   |    CodeEnd: ");Out.Hex(CodeEnd);EmitLn;
        mod.imp := p;  (*copy imports*)
        cmod.imp := p;  (*copy imports*)
        i := 0;
        WHILE i < nofimps DO
          xmod:=import[i]; (*should go in SYSTEM.PUT *)
          SYSTEM.PUT(p, 0); INC(p, 8); INC(i)                                                                   
        END ;
        mod.cmd := p; (*commands*) 
        cmod.cmd := p; (*commands*) 
        Files.Read(R, b); ch:=CHR(b);
          Emit("   |    -------- "); EmitLn;
        WHILE ch # 0X DO
          Emit("   |    Command: ");
          b:=ORD(ch); Out.Char(ch); REPEAT SYSTEM.PUT(p, b); INC(p); Files.Read(R, b); ch:=CHR(b) UNTIL ch = 0X;EmitLn;
          REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
          Files.ReadInt(R, n); SYSTEM.PUT(p, n); INC(p, 8); Files.Read(R, b); ch:=CHR(b);
          Emit("   |         At: ");Out.Int(n,16); EmitLn
        END ;
          Emit("   |    ======== ");EmitLn;
        REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
        mod.ent := p - binStart ; (*entries*)
        cmod.ent := p - binStart ; (*entries*)
        Emit("   |     ETable: ");Out.Hex(mod.ent);EmitLn;
        Files.ReadInt(R, n);
        Emit("   |     ECount: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 8); DEC(n) END ;
        mod.ptr := p; (*pointer references*)
        cmod.ptr := p; (*pointer references*)
        Files.ReadInt(R, w);
        Emit("   |      PRefs: ");Out.Int(w,16);EmitLn;
        WHILE (w >= 0) & (~R.eof) DO SYSTEM.PUT(p, mod.data + w - binStart ); INC(p, 8); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 8);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
        Emit("   |    fixorgP: ");Out.Int(fixorgP,16);EmitLn;
        Emit("   |    fixorgD: ");Out.Int(fixorgD,16);EmitLn;
        Emit("   |    fixorgT: ");Out.Int(fixorgT,16);EmitLn;
        Files.ReadInt(R, w); body := SYSTEM.VAL(Command, mod.code + w - binStart );
        Emit("   |       Body: ");Out.Int(w,16);EmitLn;
	ProgEntry := w;
        Files.Read(R, b); ch:=CHR(b);
        Emit("   |        Tag: ");Out.Char(ch);EmitLn;
        IF ch # "O" THEN (*corrupted file*)  mod := NIL; ok:=FALSE; error(4, name1) END
      END ;
      IF res = 0 THEN (*fixup of BL*)
        adr := mod.code + fixorgP*8;
(*
        WHILE adr # mod.code DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 100000H MOD 10H;
          pno := inst DIV 1000H MOD 100H;
          disp := inst MOD 1000H;
          SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
          SYSTEM.GET(impmod.ent + pno*4, dest); dest := dest + impmod.code - binStart;
          offset := (dest - (adr - binStart) - 4) DIV 4;
          SYSTEM.PUT(adr, (offset MOD 1000000H) + 0F7000000H); 
          adr := adr - disp*4
        END ;

        (*fixup of LDR/STR/ADD*)
        adr := mod.code + fixorgD*4;
        WHILE adr # mod.code DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 100000H MOD 10H;
          disp := inst MOD 1000H;
          IF mno = 0 THEN  (*global*)
           SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + mod.num * 4)  
         ELSE (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod); v := impmod.num;
            SYSTEM.PUT(adr, (inst DIV 1000000H * 10H + MT) * 100000H + v*4); 
            SYSTEM.GET(adr+4, inst); vno := inst MOD 100H;
            SYSTEM.GET(impmod.ent + vno*4, offset);
            IF ODD(inst DIV 100H) THEN offset := offset + impmod.code - impmod.data END ;
           SYSTEM.PUT(adr+4, inst DIV 10000H * 10000H + offset  ) 
          END ;
          adr := adr - disp*4
        END ;

        (*fixup of type descriptors*)

        adr := mod.data + fixorgT*4;
        WHILE adr # mod.data DO
          SYSTEM.GET(adr, inst);
          mno := inst DIV 1000000H MOD 10H;
          vno := inst DIV 1000H MOD 1000H;
          disp := inst MOD 1000H;
          IF mno = 0 THEN                                              (*global*)
             inst := mod.data - binStart + vno
          ELSE                                                                 (*import*)
            SYSTEM.GET(mod.imp + (mno-1)*4, impmod);
            SYSTEM.GET(impmod.ent + vno*4, offset);
            inst := impmod.data + offset - binStart
          END ;
          SYSTEM.PUT(adr, inst); adr := adr - disp*4 
    (*      SYSTEM.PUT(adr, 44444444H ); adr := adr - disp*4  *)
        END ;)
        SYSTEM.PUT( binStart, body )            (* module initialization vector *)
*)
      ELSIF res = 3 THEN importing := name;
        WHILE nofimps > 0 DO DEC(nofimps); DEC(import[nofimps].refcnt) END
      END 
    END;
    newmod :=  mod;
    bfo.Write( I, DataEnd, CodeEnd, ProgEntry );
  RETURN TRUE
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
      DataEnd,CodeEnd,ProgEntry: INTEGER;
      Lname : ModuleName;
      fname: OAS.Ident;
      F: Files.File;
      M, p : Module; 
      i,v : INTEGER;
      ok: BOOLEAN;
  BEGIN 
    NEW(K);
    NEW(I);

    SetFormat( format );

    binStart := SYSTEM.VAL(INTEGER,I);
    kStart := SYSTEM.VAL(INTEGER,K);
    MTOrg := kStart + 128; MTSpan := 0; binroot := NIL; cbinroot := NIL; res:= 0;
    limit:= binStart + SYSTEM.SIZE(OAB.MbinDesc); 
    binAllocPtr :=  binStart;
    i:= 0; WHILE i < 4096 DO SYSTEM.PUT(kStart+i, 0 ); INC(i,8) END;   

    OAB.MakeFileName(fname, name, ".bin");
    F := Files.New(fname); 
    bfo.Prepare( F );

    ok := LinkOne( name , M, DataEnd, CodeEnd, ProgEntry );
    IF ok THEN
      SYSTEM.PUT(kStart + 40,SYSTEM.VAL(INTEGER,binroot) - binStart );
(*      SYSTEM.PUT(kStart + 504, 1234567887654321H );    *)       (* A fingerprint *)

      i:=SYSTEM.VAL(INTEGER,I);
      CodeEnd := i - binStart;


      p:=SYSTEM.VAL(Module,binroot);  
      p:= NIL;         
      WHILE p # NIL DO  (* fix up module chain of pointers*)
        Emit( p.name);   Emit( " at "); Out.Hex( p.data );
        Emit( " (");   Out.Hex( p.data - binStart ); Emit( ") " );
        Out.Hex(p.num );  EmitLn;
        M:=p;
        p:=p.next;
(*
        IF M.next # NIL THEN M.next := SYSTEM.VAL(Modules.Module, SYSTEM.VAL(INTEGER, M.next) - binStart) END;
        M.data := M.data - binStart;
        M.code := M.code - binStart;
        i:=M.imp; WHILE i < M.cmd DO SYSTEM.GET(i,v); SYSTEM.PUT(i,v-binStart);  INC(i,4) END;
        M.imp := M.imp - binStart;
        M.cmd := M.cmd - binStart;
        M.ent := M.ent - binStart;
        M.ptr := M.ptr - binStart ; 
        SYSTEM.PUT( binStart + 20H + (4*M.num), M.data ) 
*)


      END;

      ProgEntry := ProgEntry + (8000H*(MTSpan - 1));

      Emit( "   +   Entry at: "); Out.Hex(ProgEntry);EmitLn;
      bfo.Finish( F, K, MTSpan, ProgEntry );

(*
      i := binStart;
      Files.Set(R, F, 0); 

      SYSTEM.PUT(binStart + 16, binAllocPtr - binStart );       (*size of linked binary file *)
      SYSTEM.PUT(binStart + 24, 40000H );   (* limit / heapOrg *) 
      SYSTEM.GET(binStart,v);
      SYSTEM.PUT(binStart, 0E7H * 1000000H + (v DIV 4) -1);      (* Branch to Module start routine *)
      WHILE i < binAllocPtr DO SYSTEM.GET( i, v); Files.WriteInt(R,v); INC(i,4) END;
*)
      Files.Register(F); Files.Close(F);
      Emit( " linked with "); Out.Int(MTSpan,4);Emit(" modules.");EmitLn
    ELSE
      Files.Close(F);
      Emit( " not linked."); EmitLn
    END
  END Link;


BEGIN 
(*  Emit("Silicon Oberon Linker   2023.09.24"); EmitLn *)
END OAL.

