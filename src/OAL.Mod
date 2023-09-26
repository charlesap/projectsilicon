MODULE OAL;  (*Link and create binary on Arm; NW 20.10.2013 CP 21.05.2014 2020-2021*)
  IMPORT SYSTEM, Out, Files, OAS, OAB;

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

    RawBin = POINTER TO RawBinDesc;
    RawBinDesc = RECORD
        bytes: ARRAY 1024*1024*16 OF BYTE
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

(*
  PROCEDURE ThisBinFile(name: ARRAY OF CHAR): Files.File;
    VAR i: INTEGER;
      filename: ModuleName;
  BEGIN
    i := 0;
    WHILE name[i] # 0X DO filename[i] := name[i]; INC(i) END ;
    filename[i] := "."; filename[i+1] := "b"; filename[i+2] := "i"; filename[i+3] := "n"; filename[i+4] := 0X;
    RETURN Files.New(filename)
  END ThisBinFile;
*)

  PROCEDURE error(n: INTEGER; name: ModuleName);
  BEGIN 
    res := n; importing := name; Emit("!"); 
    IF res < 0 THEN Emit("x") END ;
    IF res = 0 THEN Emit("0") END ;
    IF res = 1 THEN Emit("1") END ;
    IF res = 2 THEN Emit("2") END ;
    IF res = 3 THEN Emit("3") END ;
    IF res = 4 THEN Emit("4") END ;
    IF res = 5 THEN Emit("5") END ;
    IF res = 6 THEN Emit("6") END ;
    IF res = 7 THEN Emit("7") END ;
    IF res > 7 THEN Emit("z") END ;
    Emit(name)
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
(*      Texts.WriteInt(W, i,4 ); *)
    ELSE Emit(" BAD "); 
(*
      Texts.WriteInt(W, i,4 );
      Texts.WriteString(W, " ");
      Texts.WriteHex(W, t ) 
*)
    END;
    EmitLn;  
  END ck;


  PROCEDURE LinkOne*(name: ARRAY OF CHAR; VAR newmod: Module);
    VAR mod, impmod, xmod: Module;
      i, n, key, impkey, mno, nofimps, size: INTEGER;
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
  BEGIN
    Emit("Linking "); Emit( name );
    mod := binroot; res := 0; nofimps := 0;
    WHILE (mod # NIL) & (name # mod.name) DO mod := mod.next END ;
    IF mod = NIL THEN 
      OAB.MakeFileName(fname, name, ".a64");
      F := Files.Old(fname); 
      IF F # NIL THEN
        Emit(" [ ");
        Files.Set(R, F, 0); 
        zero(name1);
        Files.ReadString(R, name1); Files.ReadInt(R, key); Files.Read(R, b); ch:=CHR(b); Files.ReadInt(R, size); 
        zero(importing);
        importing := name1;
        IF ch = versionkey THEN
          zero(impname);
          Files.ReadString(R, impname);   (*imports*)
          WHILE (impname[0] # 0X) & (res = 0) DO
            Files.ReadInt(R, impkey);
            LinkOne(impname, impmod);
            import[nofimps] := impmod;
            importing := name1;
            IF res = 0 THEN
              IF impmod.key = impkey THEN INC(impmod.refcnt); INC(nofimps)
              ELSE error(3, name1); imported := impname
              END
            END ;  
            zero(impname);
            Files.ReadString(R, impname)
          END
        ELSE  error(2, name1) 
        END ;
        Emit(" ] "); EmitLn
      ELSE (* error(1, name) *)
      END ;
      IF res = 0 THEN 
        INC(size, DescSize);
        IF binAllocPtr + size < limit THEN (*allocate*)
            p:= binAllocPtr;
            i:=p; WHILE i < ((p + size + 100H) DIV 20H * 20H)  DO SYSTEM.PUT( i, 0); INC(i,4) END;
            mod := SYSTEM.VAL(Module, p);
            SYSTEM.PUT( SYSTEM.ADR(binAllocPtr), (p + size + 100H) DIV 20H * 20H); 
            mod.size := binAllocPtr - p; 
            IF binroot # NIL THEN  mod.num := binroot.num + 1
            ELSE mod.num := 1
            END;
            mod.next := binroot; binroot := mod
        ELSE error(7, name1)
        END
      END ; 
      IF res = 0 THEN (*read file*)
        INC(p, DescSize); (*allocate descriptor*)
        zero(mod.name);
        mod.name := name; 
        mod.key := key; mod.refcnt := 0;
        mod.data := p;  (*data*)
        SYSTEM.PUT(mod.num * 4 + binMTOrg, p );  (*module table entry*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w);  SYSTEM.PUT(p, w);  INC(p, 4); DEC(n, 4) END ; (*type descriptors*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO SYSTEM.PUT(p, 0); INC(p, 4); DEC(n, 4) END ;  (*variable space*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.Read(R, b); ch:=CHR(b); SYSTEM.PUT(p, ch); INC(p); DEC(n) END ;   (*strings*)
        mod.code := p;  (*program*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n) END ;  (*program code*)
        mod.imp := p;  (*copy imports*)
        i := 0;
        WHILE i < nofimps DO
          xmod:=import[i]; (*should go in SYSTEM.PUT *)
          SYSTEM.PUT(p, 0); INC(p, 4); INC(i)                                                                   
        END ;
        mod.cmd := p;  (*commands*) 
        Files.Read(R, b); ch:=CHR(b);
        WHILE ch # 0X DO
          b:=ORD(ch);REPEAT SYSTEM.PUT(p, b); INC(p); Files.Read(R, b); ch:=CHR(b) UNTIL ch = 0X;
          REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0;
          Files.ReadInt(R, n); SYSTEM.PUT(p, n); INC(p, 4); Files.Read(R, b); ch:=CHR(b)
        END ;
        REPEAT SYSTEM.PUT(p, 0X); INC(p) UNTIL p MOD 4 = 0;
        mod.ent := p; (*entries*)
        Files.ReadInt(R, n);
        WHILE n > 0 DO Files.ReadInt(R, w); SYSTEM.PUT(p, w); INC(p, 4); DEC(n) END ;
        mod.ptr := p; (*pointer references*)
        Files.ReadInt(R, w);
        WHILE (w >= 0) & (~R.eof) DO SYSTEM.PUT(p, mod.data + w - binStart ); INC(p, 4); Files.ReadInt(R, w) END ;
        SYSTEM.PUT(p, 0); INC(p, 4);
        Files.ReadInt(R, fixorgP); Files.ReadInt(R, fixorgD); Files.ReadInt(R, fixorgT);
        Files.ReadInt(R, w); body := SYSTEM.VAL(Command, mod.code + w - binStart );
        Files.Read(R, b); ch:=CHR(b);
        IF ch # "O" THEN (*corrupted file*)  mod := NIL (* ; error(4, name) *) END
      END ;
      IF res = 0 THEN (*fixup of BL*)
        adr := mod.code + fixorgP*4;
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
  END LinkOne;

  PROCEDURE Load*;
  BEGIN
  END Load;

  PROCEDURE Strip*;
(*
    VAR
      class, i, n, key, size, fix, adr, data, len: INTEGER;
      ch: CHAR;
      name: ARRAY 32 OF CHAR;
      T: Texts.Text;
      S: Texts.Scanner;
      F,G: Files.File;  R,B: Files.Rider;
*)
  BEGIN
(*
    Texts.OpenWriter(W); Texts.WriteString(W, "Stripping "); 
    Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos);
    Texts.Scan(S);
    IF S.class = Texts.Name THEN
        NEW(T); Texts.Open(T, S.s);
        Texts.WriteString(W, S.s); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
        F:= ThisFile( S.s );
        IF F # NIL THEN 
          G:=ThisBinFile(S.s);
          IF G # NIL THEN 
            Files.Set(R, F, 0); 
            Files.Set(B, G, 0); 
            Files.ReadString(R, name);
            Files.ReadInt(R, key); Files.Read(R, ch);
            Files.ReadInt(R, size); Texts.WriteString(W, "Size: "); Texts.WriteInt(W, size, 8); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
            Files.ReadString(R, name);
            WHILE name[0] # 0X DO (* shouldn't be other than 0x *)
              Files.ReadInt(R, key); 
              Texts.WriteString(W, "Imports:");
              Files.ReadString(R, name);
              Texts.WriteString(W,name); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
            END ;
            
            Files.ReadInt(R, n); n := n DIV 4; i := 0; 
            WHILE i < n DO 
              Files.ReadInt(R, data);
              INC(i)
            END ; 
            Files.ReadInt(R, data);            
            Files.ReadInt(R, n); i := 0;
            WHILE i < n DO Files.Read(R, ch); INC(i) END ;
            
            Files.ReadInt(R, n); i := 0;
            WHILE i < n DO
              Files.ReadInt(R, data); Files.WriteInt(B, data);
              INC(i)
            END ;
            Files.Register(G);
          END
        END
    END
*)
  END Strip;

  PROCEDURE Link*(name: ARRAY OF CHAR; format: INTEGER);

    VAR
      image: RawBin;
      Lname : ModuleName;
      fname: OAS.Ident;
(*
      T: Texts.Text;
      S: Texts.Scanner;
*)
      F: Files.File;  R: Files.Rider;
      M, p : Module; 
      i,v : INTEGER;
  BEGIN 
    NEW(image);

    binStart := SYSTEM.VAL(INTEGER,image); binMTOrg := binStart + 32; binroot := NIL; res:= 0;
    limit:= binStart + 1073741824; 
    binAllocPtr :=  binStart+ 512;
    i:= 0; WHILE i < 512+128 DO SYSTEM.PUT(binStart+i, 0 ); INC(i,8) END;   
        OAB.MakeFileName(fname, name, ".a64");
        F := Files.Old(fname); 
        IF F # NIL THEN (* LinkOne this module *)
          LinkOne( name , M );
          SYSTEM.PUT(binStart + 40,SYSTEM.VAL(INTEGER,binroot) - binStart );
          SYSTEM.PUT(binStart + 504, 1234567887654321H );           (* A fingerprint *)
(*
          p:=SYSTEM.VAL(Modules.Module,binroot);
*)
          OAB.MakeFileName(fname, name, ".bin");
          F := Files.New(fname); 
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
          Files.Register(F);
          Emit( "Binary Written"); EmitLn
        ELSE Emit(" (not found)"); EmitLn
        END 
(*   END *)
  END Link;


BEGIN 
(*  Emit("Silicon Oberon Linker   2023.09.24"); EmitLn *)
END OAL.

