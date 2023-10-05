MODULE OAL;  (*Link and create binary on Arm; NW 20.10.2013 CP 21.05.2014 2020-2021*)
  IMPORT SYSTEM, Out, Files, OAS, OAB, Macho;

  CONST
 
     versionkey = 1X; MT = 12; DescSize = 128;

  TYPE
    Module = POINTER TO ModDesc;
    Command = PROCEDURE;
    ModuleName = ARRAY 32 OF CHAR; (* ModuleName and ModDesc must match Modules.Mod *)

    ModDesc = RECORD (* was 80 bytes, now 128 *)
        name: ModuleName;                                               (* 32 *)
        next: Module;                                                   (*  8 *)
        key, num, size, refcnt: INTEGER;                                (* 32 *)
        data, code, imp, cmd, ent, ptr, unused: INTEGER  (*addresses*)  (* 56 *)
      END ;

  VAR 

    binroot, M: Module;

    modid: OAS.Ident; 
    binMTOrg, binStart, binAllocPtr, res*: INTEGER;
    importing*, imported*: ModuleName;
    limit: INTEGER;
    Mlist: ARRAY 16 OF ModuleName;
   

  PROCEDURE Emit(s: ARRAY OF CHAR);
    VAR ss: ARRAY 128 OF CHAR;
  BEGIN ss:=s; Out.String(ss);
  END Emit;

  PROCEDURE EmitLn;
  BEGIN Out.Ln
  END EmitLn;

  PROCEDURE zero( VAR s: ARRAY OF CHAR);
    VAR i : INTEGER;
  BEGIN i:=0;
    WHILE i < LEN(s) DO s[i]:=0X; INC(i) END
  END zero;

  PROCEDURE error(n: INTEGER; name: ModuleName);
  BEGIN 
    res := n; importing := name; Emit("!"); 
    Emit(name);Out.Int(res,3)
  END error;

  PROCEDURE Check(s: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN ch := s[0]; res := 1; i := 1;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT ch := s[i]; INC(i)
      UNTIL ~((ch >= "0") & (ch <= "9") OR (ch >= "A") & (ch <= "Z")
        OR (ch >= "a") & (ch <= "z") OR (ch = ".")) OR (i = 32);
      IF (i < 32) & (ch = 0X) THEN res := 0 END
    END
  END Check;

  PROCEDURE ck( i : INTEGER );
   VAR  t : INTEGER;
  BEGIN
    SYSTEM.GET( binStart + 0100H + 12 , t );
    IF t = 0 THEN Emit( " OK ");
      Out.Int( i,4 ); 
    ELSE Emit(" BAD "); 
      Out.Int( i,4 );
      Emit( " ");
      Out.Hex( t ) 
    END;
    EmitLn;  
  END ck;

  PROCEDURE LinkOne*(name: ARRAY OF CHAR; VAR newmod: Module;VAR Image: OAB.Bin;VAR  DataStart, DataEnd, CodeEnd, ProgEntry: INTEGER): BOOLEAN;
    VAR mod, impmod, xmod: Module;
      i, n, key, impkey, mno, nofimps, size, flen: INTEGER;
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
        Files.ReadInt(R, key); Files.Read(R, b); ch:=CHR(b); Files.ReadInt(R, size);
        importing := name1;
        IF ch = versionkey THEN
          Files.ReadString(R, impname);   (*imports*)
          WHILE (impname[0] # 0X) & (res = 0) DO
            Files.ReadInt(R, impkey);
            ok := LinkOne(impname, impmod, Image, DataStart, DataEnd, CodeEnd, ProgEntry);
            import[nofimps] := impmod;
            importing := name1;
            IF res = 0 THEN
              IF impmod.key = impkey THEN INC(impmod.refcnt); INC(nofimps)
              ELSE ok:=FALSE; error(3, name1); imported := impname
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
      Emit("   |    Loading: ");Emit(fname);EmitLn;
      Emit("   |       Size: ");Out.Int(flen,16);EmitLn;
      Emit("   |       Name: ");Emit(name1);EmitLn;
      Emit("   |        Key: ");Out.Int(key,16);EmitLn;
      Emit("   | Versionkey: ");Out.Int(b,16);EmitLn;
      Emit("   |   CodeSize: ");Out.Int(size,16);EmitLn;
      IF ok THEN 
        INC(size, DescSize);
        IF binAllocPtr + size < limit THEN (*allocate*)
            p:= binAllocPtr; 
            i:=p; WHILE i < ((p + size + 200H) DIV 20H * 20H)  DO SYSTEM.PUT( i, 0); INC(i,8) END;
            mod := SYSTEM.VAL(Module, p);
            SYSTEM.PUT( SYSTEM.ADR(binAllocPtr), (p + size + 200H) DIV 20H * 20H); (* for the next module *)
            mod.size := binAllocPtr - p; 
            IF binroot # NIL THEN  mod.num := binroot.num + 1
            ELSE mod.num := 1
            END;
            mod.next := binroot; binroot := mod;
            Emit("   |    ModSize: ");Out.Int(mod.size,16);EmitLn
        ELSE ok:=FALSE; error(7, name1)
        END
      END ; 
      IF ok THEN (*read file*)
        INC(p, DescSize); (*jump over module descriptor*)
        zero(mod.name);
        mod.name := name; 
        mod.key := key; mod.refcnt := 0;
        mod.data := p;  (*data*)
        SYSTEM.PUT(mod.num * 8 + binMTOrg, p );  (*module table entry*)
        Files.ReadInt(R, n);
        Emit("   |    TDBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.ReadInt(R, w);  SYSTEM.PUT(p, w);  INC(p, 8); DEC(n, 8) END ; (*type descriptors*)
        Files.ReadInt(R, n);
        Emit("   |   VarBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 8); DEC(n, 8) END ;  (*variable space*)
        Files.ReadInt(R, n);
        Emit("   |StringBytes: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.Read(R, b); ch:=CHR(b); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)
        mod.code := p;  (*program*)
        Files.ReadInt(R, n);
        Emit("   |  CodeWords: ");Out.Int(n,16);EmitLn;
        DataEnd := p - SYSTEM.VAL(INTEGER,Image);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 8); DEC(n) END ;  (*program code*)
        CodeEnd := p - SYSTEM.VAL(INTEGER,Image);
        Emit("   |    DataEnd: ");Out.Int(DataEnd,16);EmitLn;
        Emit("   |    CodeEnd: ");Out.Int(CodeEnd,16);EmitLn;
        mod.imp := p;  (*copy imports*)
        i := 0;
        WHILE i < nofimps DO
          xmod:=import[i]; (*should go in SYSTEM.PUT *)
          SYSTEM.PUT(p, 0); INC(p, 8); INC(i)                                                                   
        END ;
        mod.cmd := p;  (*commands*) 
        Files.Read(R, b); ch:=CHR(b);
        WHILE ch # 0X DO
          Emit("   |    Command: ");
          b:=ORD(ch); Out.Char(ch); REPEAT SYSTEM.PUT(p, b); INC(p); Files.Read(R, b); ch:=CHR(b) UNTIL ch = 0X;EmitLn;
          REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
          Files.ReadInt(R, n); SYSTEM.PUT(p, n); INC(p, 8); Files.Read(R, b); ch:=CHR(b);
          Emit("   |         At: ");Out.Int(n,16);EmitLn
        END ;
        REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 8 = 0;
        mod.ent := p; (*entries*)
        Files.ReadInt(R, n);
        Emit("   |    Entries: ");Out.Int(n,16);EmitLn;
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 8); DEC(n) END ;
        mod.ptr := p; (*pointer references*)
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
        Files.Read(R, b); ch:=CHR(b);
        Emit("   |        Tag: ");Out.Char(ch);EmitLn;
        IF ch # "O" THEN (*corrupted file*)  mod := NIL (* ; ok:=FALSE; error(4, name) *) END
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
  RETURN TRUE
  END LinkOne;


  PROCEDURE Link*(name: ARRAY OF CHAR; format: INTEGER);

    VAR
      Image: OAB.Bin;
      DataStart,DataEnd,CodeEnd,ProgEntry: INTEGER;
      Lname : ModuleName;
      fname: OAS.Ident;
      F: Files.File;  R: Files.Rider;
      M, p : Module; 
      i,v : INTEGER;
      ok: BOOLEAN;
  BEGIN 
    NEW(Image);

    binStart := SYSTEM.VAL(INTEGER,Image); binMTOrg := binStart + 128; binroot := NIL; res:= 0;
    limit:= binStart + SYSTEM.SIZE(OAB.BinDesc); 
    binAllocPtr :=  binStart+ 512;
    i:= 0; WHILE i < 4096 DO SYSTEM.PUT(binStart+i, 0 ); INC(i,8) END;   
    ok := LinkOne( name , M, Image, DataStart, DataEnd, CodeEnd, ProgEntry );
    IF ok THEN
      SYSTEM.PUT(binStart + 40,SYSTEM.VAL(INTEGER,binroot) - binStart );
      SYSTEM.PUT(binStart + 504, 1234567887654321H );           (* A fingerprint *)
(*
      p:=SYSTEM.VAL(Modules.Module,binroot);
*)
      OAB.MakeFileName(fname, name, ".bin");
      F := Files.New(fname); 
      Files.Set(R, F, 0);

      i:=SYSTEM.VAL(INTEGER,Image);
      CodeEnd := i - binStart;


      IF format = OAB.BIN   THEN  END;
      IF format = OAB.RSC64 THEN  END;
      IF format = OAB.ELF64 THEN  END;
      IF format = OAB.MACHO THEN Macho.Write( R , Image, DataStart, DataEnd, CodeEnd, ProgEntry ) END;
      IF format = OAB.PE64  THEN  END;

(*

      WHILE p # NIL DO  (* fix up module chain of pointers*)
        Texts.WriteString(W, p.name);   Texts.WriteString(W, " at "); Texts.WriteHex(W, p.data );
        Texts.WriteString(W, " (");   Texts.WriteHex(W, p.data - binStart ); Texts.WriteString(W, ") " );
        Texts.WriteHex(W, p.num );  Texts.WriteLn(W);
        M:=p;
        p:=p.next;
        IF M.next # NIL THEN M.next := SYSTEM.VAL(Modules.Module, SYSTEM.VAL(INTEGER, M.next) - binStart) END;
        M.data := M.data - binStart;
        M.code := M.code - binStart;
        i:=M.imp; WHILE i < M.cmd DO SYSTEM.GET(i,v); SYSTEM.PUT(i,v-binStart);  INC(i,4) END;
        M.imp := M.imp - binStart;
        M.cmd := M.cmd - binStart;
        M.ent := M.ent - binStart;
        M.ptr := M.ptr - binStart ; 
        SYSTEM.PUT( binStart + 20H + (4*M.num), M.data ) 
      END;

      i := binStart;
      Files.Set(R, F, 0); 

      SYSTEM.PUT(binStart + 16, binAllocPtr - binStart );       (*size of linked binary file *)
      SYSTEM.PUT(binStart + 24, 40000H );   (* limit / heapOrg *) 
      SYSTEM.GET(binStart,v);
      SYSTEM.PUT(binStart, 0E7H * 1000000H + (v DIV 4) -1);      (* Branch to Module start routine *)
      WHILE i < binAllocPtr DO SYSTEM.GET( i, v); Files.WriteInt(R,v); INC(i,4) END;
*)
      Files.Register(F); Files.Close(F);
      Emit( " linked."); EmitLn
    ELSE
      Emit( " not linked."); EmitLn
    END
  END Link;


BEGIN 
(*  Emit("Silicon Oberon Linker   2023.09.24"); EmitLn *)
END OAL.

















































































































































































































