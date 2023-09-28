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
  BEGIN
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
        ELSE
          Emit(" version key mismatch"); Out.Int( b, 4 ); Emit(" vs"); Out.Int( ORD(versionkey), 4 ); Emit(" ");
          error(2, name1) 
        END ;
        Emit(" "); Emit(name1);
      ELSE  error(1, name1) 
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

  PROCEDURE BinPrefix;
  BEGIN
  END BinPrefix;
 
  PROCEDURE RscPrefix; 
  BEGIN
  END RscPrefix;
 
  PROCEDURE ElfPrefix; 
  BEGIN
  END ElfPrefix;
 
  PROCEDURE MacPrefix(VAR R: Files.Rider);
    VAR i: INTEGER;
  BEGIN                                     (* High Word / Low Word    *)
    Files.WriteInt( R, 0100000CFEEDFACFH ); (* CPU type / Magic number *)
    Files.WriteInt( R, 0000000200000000H ); (* File type / CPU subtype *)
    Files.WriteInt( R, 000002E800000010H ); (* Size of LC 93*8 = 744 = 2E8H / # of LC *)
    Files.WriteInt( R, 0000000000200085H ); (* Reserved    / Flags     *)

    (* 1: __PAGEZERO *) 
    Files.WriteInt( R, 0000004800000019H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 455A454741505F5FH ); (* segname first half      *)
    Files.WriteInt( R, 0000000000004F52H ); (* segname second half     *)
    Files.WriteInt( R, 0000000000000000H ); (* vmaddr                  *)
    Files.WriteInt( R, 0000000100000000H ); (* vmsize                  *)
    Files.WriteInt( R, 0000000000000000H ); (* file offset             *)
    Files.WriteInt( R, 0000000000000000H ); (* size in file            *)
    Files.WriteInt( R, 0000000000000000H ); (* initprot / maxprot      *)
    Files.WriteInt( R, 0000000000000000H ); (* flag32 / n of sections  *)

    (* 2: __TEXT *)
    Files.WriteInt( R, 000000E800000019H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000545845545F5FH ); (* segname first half      *)
    Files.WriteInt( R, 0000000000000000H ); (* segname second half     *)
    Files.WriteInt( R, 0000000100000000H ); (* vmaddr                  *)
    Files.WriteInt( R, 0000000000004000H ); (* vmsize                  *)
    Files.WriteInt( R, 0000000000000000H ); (* file offset             *)
    Files.WriteInt( R, 0000000000004000H ); (* size in file            *)
    Files.WriteInt( R, 0000000500000005H ); (* initprot / maxprot      *)
    Files.WriteInt( R, 0000000000000002H ); (* flag32 / n of sections  *)
    (* 2a: __text section *)
    Files.WriteInt( R, 0000747865745F5FH ); (* section name first half *)
    Files.WriteInt( R, 0000000000000000H ); (* section name second half*)
    Files.WriteInt( R, 0000545845545F5FH ); (* segment name first half *)
    Files.WriteInt( R, 0000000000000000H ); (* segment name second half*)
    Files.WriteInt( R, 0000000100003F90H ); (* section Address         *)
    Files.WriteInt( R, 000000000000001CH ); (* section size            *)
    Files.WriteInt( R, 0000000400003F90H ); (* Alignment / Sect File Offset *)
    Files.WriteInt( R, 0000000000000000H ); (* num reloc / reloc file offset *)
    Files.WriteInt( R, 0000000080000400H ); (* res1      / Flag & Type *)
    Files.WriteInt( R, 0000000000000000H ); (* res3      / res2        *)      
    (* 2b: __unwind_info section *)
    Files.WriteInt( R, 646E69776E755F5FH );  (* section name first half *)
    Files.WriteInt( R, 0000006F666E695FH );  (* section name second half*)
    Files.WriteInt( R, 0000545845545F5FH );  (* segment name first half *)
    Files.WriteInt( R, 0000000000000000H );  (* segment name second half*)
    Files.WriteInt( R, 0000000100003FACH );  (* section Address         *)
    Files.WriteInt( R, 0000000000000048H );  (* section size            *)
    Files.WriteInt( R, 0000000200003FACH );  (* Alignment / Sect File Offset *)
    Files.WriteInt( R, 0000000000000000H );  (* num reloc / reloc file offset *)
    Files.WriteInt( R, 0000000000000000H );  (* res1      / Flag & Type *)
    Files.WriteInt( R, 0000000000000000H );  (* res3      / res2        *)      

    (* 3: __LINKEDIT *)
    Files.WriteInt( R, 0000004800000019H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 44454B4E494C5F5FH ); (* segname first half      *)
    Files.WriteInt( R, 0000000000005449H ); (* segname second half     *)
    Files.WriteInt( R, 0000000100004000H ); (* vmaddr                  *)
    Files.WriteInt( R, 0000000000004000H ); (* vmsize                  *)
    Files.WriteInt( R, 0000000000004000H ); (* file offset             *)
    Files.WriteInt( R, 00000000000001E1H ); (* size in file            *)
    Files.WriteInt( R, 0000000100000001H ); (* initprot / maxprot      *)
    Files.WriteInt( R, 0000000000000000H ); (* flag32 / n of sections  *)

    (* 4: CMD 34H ?? *)
    Files.WriteInt( R, 0000001080000034H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000003800004000H ); (*                         *)

    (* 5: CMD 33H ?? *)
    Files.WriteInt( R, 0000001080000033H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000003800004038H ); (*                         *)

    (* 6: SYMBOL TABLE *)
    Files.WriteInt( R, 0000001800000002H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000300004078H ); (* num symbols / symbols file offset *)
    Files.WriteInt( R, 00000028000040A8H ); (* string table size / string table file offset *)

    (* 7: SYMBOL TABLE INFO *)
    Files.WriteInt( R, 000000500000000BH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000000000000H ); (* #LSym / LSymIndex       *)
    Files.WriteInt( R, 0000000300000000H ); (* #ESym / ESymIndex       *)
    Files.WriteInt( R, 0000000000000003H ); (* #USym / USymINdex       *)
    Files.WriteInt( R, 0000000000000000H ); (* #CTabEntries / CTabOfst *)
    Files.WriteInt( R, 0000000000000000H ); (*  *)
    Files.WriteInt( R, 0000000000000000H ); (*  *)
    Files.WriteInt( R, 0000000000000000H ); (*  *)
    Files.WriteInt( R, 0000000000000000H ); (*  *)
    Files.WriteInt( R, 0000000000000000H ); (*  *)

    (* 8: CMD 0EH ?? /usr/lib/dyld *)
    Files.WriteInt( R, 000000200000000EH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 7273752F0000000CH ); (*                         *)
    Files.WriteInt( R, 6C79642F62696C2FH ); (*                         *)
    Files.WriteInt( R, 0000000000000064H ); (*                         *)

    (* 9: Application UUID number *)
    Files.WriteInt( R, 000000180000001BH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R,0F931B7FDE38F91CCH ); (*  128-bit UUID pt 1      *)
    Files.WriteInt( R, 239DEFA4E546FD8AH ); (*  128-bit UUID pt 2      *)

    (* 10: CMD Minimum OS version *)
    Files.WriteInt( R, 0000002000000032H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 000D000000000001H ); (*                         *)
    Files.WriteInt( R, 00000001000A1200H ); (*                         *)
    Files.WriteInt( R, 0359010000000003H ); (*                         *)

    (* 11: CMD 2A ?? *)
    Files.WriteInt( R, 000000100000002AH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000000000000H ); (*                         *)

    (* 12: Main entry point *)
    Files.WriteInt( R, 0000001880000028H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000000003FA0H ); (*  Address location       *)
    Files.WriteInt( R, 0000000000000000H ); (*  Stack memory size      *)

    (* 13: Link Library /usr/lib/libSystem.B.dyl *)
    Files.WriteInt( R, 000000380000000CH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000200000018H ); (*                         *)
    Files.WriteInt( R, 0001000005276403H ); (*                         *)
    Files.WriteInt( R, 62696C2F7273752FH ); (*                         *)
    Files.WriteInt( R, 7473795362696C2FH ); (*                         *)
    Files.WriteInt( R, 6C79642E422E6D65H ); (*                         *)
    Files.WriteInt( R, 0000000000006269H ); (*                         *)

    (* 14: CMD 26 ?? *)
    Files.WriteInt( R, 0000001000000026H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000800004070H ); (*                         *)

    (* 15: CMD 29 ?? *)
    Files.WriteInt( R, 0000001000000029H ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 0000000000004078H ); (*                         *)

    (* 16: CMD 1D ?? *)
    Files.WriteInt( R, 000000100000001DH ); (* cmdsize    / cmd        *)
    Files.WriteInt( R, 00000111000040D0H ); (*                         *)

    (* PADDING *)
    i:=0; WHILE i < 1937 DO
    Files.WriteInt( R, 0000000000000000H ); (* padding                 *)
    INC(i);
    END;

(*

00003f90  11 11 11 11 22 22 22 22  33 33 33 33 44 44 44 44  |....""""3333DDDD|

*)

    (* PROGRAM *)
    Files.WriteInt( R, 2222222211111111H );
    Files.WriteInt( R, 4444444433333333H );
    Files.WriteInt( R,0D2800030D2800540H );
    Files.WriteInt( R, 00000001D4001001H );
    Files.WriteInt( R, 000000000000001CH );
    Files.WriteInt( R, 000000000000001CH );
    Files.WriteInt( R, 000000020000001CH );
    Files.WriteInt( R, 0000003400003F90H );
    Files.WriteInt( R, 00003FAD00000034H );
    Files.WriteInt( R, 0000003400000000H );
    Files.WriteInt( R, 0001000C00000003H );
    Files.WriteInt( R, 0000000000010010H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000002000000000H );
    Files.WriteInt( R, 0000003000000030H );
    Files.WriteInt( R, 0000000100000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000003H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 00000209005F0100H );
    Files.WriteInt( R, 655F686D5F030000H );
    Files.WriteInt( R, 685F657475636578H );
    Files.WriteInt( R, 6405007265646165H );
    Files.WriteInt( R, 69616D2B00617461H );
    Files.WriteInt( R, 007F90000330006EH );
    Files.WriteInt( R, 000000007FA00003H );
    Files.WriteInt( R, 0000000000107F90H );
    Files.WriteInt( R, 0010010F00000002H );
    Files.WriteInt( R, 0000000100000000H );
    Files.WriteInt( R, 0000010F00000016H );
    Files.WriteInt( R, 0000000100003F90H );
    Files.WriteInt( R, 0000010F0000001CH );
    Files.WriteInt( R, 0000000100003FA0H );
    Files.WriteInt( R, 655F686D5F5F0020H );
    Files.WriteInt( R, 685F657475636578H );
    Files.WriteInt( R, 645F007265646165H );
    Files.WriteInt( R, 69616D5F00617461H );
    Files.WriteInt( R, 000000000000006EH );
    Files.WriteInt( R, 11010000C00CDEFAH );
    Files.WriteInt( R, 0000000001000000H );
    Files.WriteInt( R, 020CDEFA14000000H );
    Files.WriteInt( R, 00040200FD000000H );
    Files.WriteInt( R, 5D00000002000200H );
    Files.WriteInt( R, 0000000058000000H );
    Files.WriteInt( R,0D040000005000000H );
    Files.WriteInt( R, 000000000C000220H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000000000H );
    Files.WriteInt( R, 0000000000400000H );
    Files.WriteInt( R, 7469786501000000H );
    Files.WriteInt( R,0E44ED3E1DFC4A100H );
    Files.WriteInt( R, 1E42D7D51C8BCABDH );
    Files.WriteInt( R, 27ED0494BF1E607EH );
    Files.WriteInt( R,0CF8C3007AF6DF0EAH );
    Files.WriteInt( R,0C66F58B2AC7FADDBH );
    Files.WriteInt( R, 6BD1D1D704C066E9H );
    Files.WriteInt( R, 7CB47CFF05584F02H );
    Files.WriteInt( R, 2C89488BBDDA857AH );
    Files.WriteInt( R,0C66F58B2AC7FADA7H );
    Files.WriteInt( R, 6BD1D1D704C066E9H );
    Files.WriteInt( R, 7CB47CFF05584F02H );
    Files.WriteInt( R, 2C89488BBDDA857AH );
    Files.WriteInt( R, 4F71619F59E5D3A7H );
    Files.WriteInt( R,0AF0F3CF18BA3B5B9H );
    Files.WriteInt( R, 856800CC336928C8H );
    Files.WriteInt( R,0D974C511725ECD2AH );
    Files.WriteInt( R, 1AB8F5E7290BFBF8H );
    Files.WriteInt( R,0D1DD033EB3E09DE0H );
    Files.WriteInt( R, 97350ADD9EE6EBF5H );
    Files.WriteInt( R,0E6B960A1A0A512BDH );
    Files.Write( R, 0DDH );

    Emit(" MACHO ");
  END MacPrefix;
 
  PROCEDURE PePrefix;  
  BEGIN
  END PePrefix;
 

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

    binStart := SYSTEM.VAL(INTEGER,image); binMTOrg := binStart + 64; binroot := NIL; res:= 0;
    limit:= binStart + 1073741824; 
    binAllocPtr :=  binStart+ 512;
    i:= 0; WHILE i < 512+128 DO SYSTEM.PUT(binStart+i, 0 ); INC(i,8) END;   
(*        OAB.MakeFileName(fname, name, ".a64");
        F := Files.Old(fname); 
        IF F # NIL THEN (* LinkOne this module *)
          Files.Close(F);
*)
          LinkOne( name , M );
          SYSTEM.PUT(binStart + 40,SYSTEM.VAL(INTEGER,binroot) - binStart );
          SYSTEM.PUT(binStart + 504, 1234567887654321H );           (* A fingerprint *)
(*
          p:=SYSTEM.VAL(Modules.Module,binroot);
*)
          OAB.MakeFileName(fname, name, ".bin");
          F := Files.New(fname); 
          Files.Set(R, F, 0);

          IF format = OAB.BIN   THEN BinPrefix END;
          IF format = OAB.RSC64 THEN RscPrefix END;
          IF format = OAB.ELF64 THEN ElfPrefix END;
          IF format = OAB.MACHO THEN MacPrefix( R ) END;
          IF format = OAB.PE64  THEN PePrefix  END;

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
          Emit( " linked"); EmitLn
(*
        ELSE Emit(" (not found)"); EmitLn
        END 
*)
(*   END *)
  END Link;


BEGIN 
(*  Emit("Silicon Oberon Linker   2023.09.24"); EmitLn *)
END OAL.

