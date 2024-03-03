MODULE Elf;  (*Write an ELF file cp 2024*)
  IMPORT SYSTEM, OAB, Files;

  CONST
    b = 10000H;
    
  TYPE

  VAR
    R: Files.Rider; 

  PROCEDURE WR( i: INTEGER );
  BEGIN
    Files.WriteInt( R, i );
  END WR;

  PROCEDURE Header( LCsz, nCMD: INTEGER);
  BEGIN 
    (* CPU type / Magic number     File type / CPU subtype          LCsz 93*8 = 2E8H / # LC          Reserved / Flags  *) 
(*    WR( 0100000CFEEDFACFH ); WR( 200000000H ); WR( LCsz*100000000H + nCMD); WR( 200085H ); *)

    WR( 00010102464C457FH ); (* elf 64-bit little-endian elf-1 sys-v *)
    WR( 0000000000000000H ); (* abi + pad *)
    WR( 0000000100B70002H ); (* executable aarch64 elf-1 *)
    WR( 0000000100003F90H ); (* entrypoint *)
    WR( 0000000000000040H ); (* program header table offset *)
    WR( 0000000000004228H ); (* section header table offset was 4028H *)
    WR( 0038004000000000H ); (* flags this-header-size program-header-table-entry-size *)
    WR( 0005000600400004H ); (* program-header-table-entry-count section-table-header-entry-size section-table-header-entry-count section-names-index *)

    WR( 0000000500000001H ); (* loadable-segment executable+readable *)
    WR( 0000000000000000H ); (* segment file offset *)
    WR( 0000000100000000H ); (* virtual address *)
    WR( 0000000100000000H ); (* physical address if relevent *)
    WR( 0000000000003FC0H ); (* size in file *)
    WR( 0000000000003FC0H ); (* size in memory *)
    WR( 0000000000010000H ); (* alignment *)

    WR( 0000000600000001H ); (* loadable-segment writeable+readable *)
    WR( 0000000000004000H ); (* segment file offset *)
    WR( 0000000100004000H ); (* virtual address *)
    WR( 0000000100003FC0H ); (* physical address if relevent *)
    WR( 0000000000004000H ); (* size in file was EH *)
    WR( 0000000000004000H ); (* size in memory was EH *)
    WR( 0000000000010000H ); (* alignment *)

    WR( 0000000600000001H ); (* loadable-segment writeable+readable *)
    WR( 0000000000008000H ); (* segment file offset *)
    WR( 0000000100008000H ); (* virtual address *)
    WR( 0000000100007FC0H ); (* physical address if relevent *)
    WR( 0000000000004000H ); (* size in file was EH *)
    WR( 0000000000004000H ); (* size in memory was EH *)
    WR( 0000000000010000H ); (* alignment *)

    WR( 0000000500000001H ); (* loadable-segment executable+readable *)
    WR( 000000000000C000H ); (* segment file offset *)
    WR( 000000010000C000H ); (* virtual address *)
    WR( 0000000100000000H ); (* physical address if relevent *)
    WR( 0000000000004000H ); (* size in file *)
    WR( 0000000000004000H ); (* size in memory *)
    WR( 0000000000010000H ); (* alignment *)

  END Header;
 
  PROCEDURE Segment(nsect: INTEGER; nmSEGM: ARRAY OF CHAR; vmaddr, vmsize, foffset, fsize, prot, flag32: INTEGER);
    VAR i,x: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
  END Segment;

  PROCEDURE Section(nmSECT, nmSEGM: ARRAY OF CHAR; saddr, ssize, saddrsoff, nrelrelo, fandt: INTEGER);
    VAR i: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
  END Section;

  PROCEDURE Mysterious(ignorable: BOOLEAN; id, p1, p2: INTEGER);
  BEGIN
  END Mysterious;

  PROCEDURE Symbols(nSYM, symfo, strtabsz, strtabfo: INTEGER);
  BEGIN
  END Symbols;

  PROCEDURE SymbolTableInfo(nLSym, LSymI, nESym, ESymI, nUSym, USymI: INTEGER);
  BEGIN
  END SymbolTableInfo;

  PROCEDURE LoadDylinker();
  BEGIN
  END LoadDylinker;

  PROCEDURE ApplicationUUID(UUIDhi, UUIDlo: INTEGER);
  BEGIN
  END ApplicationUUID;

  PROCEDURE MinimumOS();
  BEGIN
  END MinimumOS;

  PROCEDURE MainEntry(address, stack: INTEGER);
  BEGIN
  END MainEntry;

  PROCEDURE LinkLibSystem();
  BEGIN
  END LinkLibSystem;

  PROCEDURE CodeSignature(p1, p2: INTEGER);
  BEGIN
  END CodeSignature;


  PROCEDURE ExitCode(ProgEntry: INTEGER);
  BEGIN
    WR( 0000000100004080H ); (*MT location*)
    WR( 58FFFFBC44444444H ); (* load MT location into MT register *)
    WR(0D280003094002018H + (ProgEntry DIV 4)); (*  D2800540H *)
    WR( 00000001D4001001H );
    WR( 000000000000001CH );
    WR( 000000000000001CH );
    WR( 000000020000001CH );
    WR( 0000003400003F90H );
    WR( 00003FAD00000034H );
    WR( 0000003400000000H );
    WR( 0001000C00000003H );
    WR( 0000000000010010H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
  END ExitCode;


  PROCEDURE Prepare*(F: Files.File);
    VAR i: INTEGER;
  BEGIN
    Files.Set( R, F, 0 );
(*    i := 0; WHILE i < 8000H DO WR( 0 ); INC(i,8); END *)
  END Prepare;


  PROCEDURE Write*(C: OAB.Mbin; dAt, cAt: INTEGER);
    VAR i,p,v,lim: INTEGER;
  BEGIN                                                 
    (* module data at 8000H *)
(*
    p := SYSTEM.VAL(INTEGER, C) + SYSTEM.SIZE(OAB.MbinDesc) - 4000H;
    i := 0; 
    WHILE i <  4000H DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8); END;
    p:=SYSTEM.VAL(INTEGER,C);
*)
    (* module code *)                                                        
(*
    WHILE i <  8000H DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8); END;
*)
  END Write;

  PROCEDURE Bump(VAR c: CHAR);
  BEGIN
    c:=CHR(ORD(c)+1);
  END Bump;


  PROCEDURE Finish*(VAR F: Files.File; K: OAB.Kbin; N, ProgEntry: INTEGER);
    VAR i,p,v,x: INTEGER;
        c,C,d,D: ARRAY 8 OF CHAR;
  BEGIN
         
    Files.Set( R, F, 0 );

    Header( 380H + ((13H * 8)*2)*N, 19+((N-1)*2) ); (* 1200 or 4B0H *) 

    i:= 0B0H + 70H; WHILE i < 3F90H DO WR( 0 ); INC(i,8) END;

    ExitCode( ProgEntry );

(*
    WR( 580000E1D2800020H );
    WR( 5280080858000102H );
    WR(0D2800000D4000001H );
    WR(0D400000152800BA8H );
    WR( 0000000100004000H );
    WR( 000000000000000EH );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
*)
    WR( 41202C6F6C6C6548H );
    WR( 2E000A2134364D52H );
    WR( 6261747274736873H );
    WR( 2E00747865742E00H );
    WR( 0000000061746164H );

    i:= 0; WHILE i < 200H DO WR( 0 ); INC(i,8); END;

          (* null *)
    WR( 0000000000000000H ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000000H ); (* header-flags *)
    WR( 0000000000000000H ); (* virtual address *)
    WR( 0000000000000000H ); (* offset in file image *)
    WR( 0000000000000000H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000000H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)
          (* program data, ALLOC + EXEC *)
    WR( 000000010000000BH ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000006H ); (* header-flags *)
    WR( 0000000100003F90H ); (* virtual address *)
    WR( 0000000000003F90H ); (* offset in file image *)
    WR( 0000000000000030H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000008H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)
          (* program data, ALLOC + WRITE *)
    WR( 0000000100000011H ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000003H ); (* header-flags *)
    WR( 0000000100004000H ); (* virtual address *)
    WR( 0000000000004000H ); (* offset in file image *)
    WR( 0000000000004000H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000001H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)
          (* program data, ALLOC + WRITE *)
    WR( 0000000100000011H ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000003H ); (* header-flags *)
    WR( 0000000100008000H ); (* virtual address *)
    WR( 0000000000008000H ); (* offset in file image *)
    WR( 0000000000004000H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000001H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)
          (* program data, ALLOC + EXEC *)
    WR( 000000010000000BH ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000006H ); (* header-flags *)
    WR( 000000010000C000H ); (* virtual address *)
    WR( 000000000000C000H ); (* offset in file image *)
    WR( 0000000000004000H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000008H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)
          (* string table, --- *)
    WR( 0000000300000001H ); (* string-table-offset-of-section-name header-type *)
    WR( 0000000000000000H ); (* header-flags *)
    WR( 0000000000000000H ); (* virtual address *)
    WR( 000000000000400EH ); (* offset in file image *)
    WR( 0000000000000017H ); (* size *)
    WR( 0000000000000000H ); (* section-index section-info *)
    WR( 0000000000000001H ); (* alignment *)
    WR( 0000000000000000H ); (* size *)

    i:= 0; WHILE i < (4000H - (28H + 200H + (40H * 6))) DO WR( 0 ); INC(i,8); END;
    i:= 0; WHILE i < 8000H DO WR( 0 ); INC(i,8); END;

(*
    i:= 6210H; WHILE i < 8000H DO WR( 0 ); INC(i,8); END;
*)
(*
    Files.Write( R, 0DDH );    
                        
                                             
    Segment( 0, "__PAGEZERO", 0,           100000000H,         0,          0,         0, 0 ); 
    Segment( 2, "__TEXT",                  100000000H,     4000H,          0,     4000H, 500000005H, 0 );
    Section(    "__text", "__TEXT",        100003F90H,       1CH, 400003F90H,         0,  80000400H    );
    Section(    "__unwind_info", "__TEXT", 100003FACH,       48H, 400003FACH,         0,         0     );
    Segment( 1, "__K000",                  100004000H,     4000H,      4000H,     4000H, 300000003H, 0 );
    Section(    "__k000", "__K000",        100004000H,     4000H, 400004000H,         0,         1     );
    D:="__D000"; d:="__d000";
    C:="__C000"; c:="__c000";
    Segment( 1, D,                         100008000H,     4000H,      8000H,     4000H, 300000003H, 0 );
    Section(    d, D,                      100008000H,     4000H, 400008000H,         0,         1     );
    Segment( 1, C,                         10000C000H,     4000H,     0C000H,     4000H, 500000005H, 0 );
    Section(    c, C,                      10000C000H,     4000H, 40000C000H,         0,  80000400H    );
    i:=1; WHILE i < N DO   x:=8000H*(i); Bump(D[5]); Bump(d[5]); Bump(C[5]); Bump(c[5]);
      Segment( 1, D,                       100008000H + x, 4000H,      8000H + x, 4000H, 300000003H, 0 );
      Section(    d, D,                    100008000H + x, 4000H, 400008000H + x,     0,         0     );
      Segment( 1, C,                       10000C000H + x, 4000H,     0C000H + x, 4000H, 500000005H, 0 );
      Section(    c, C,                    10000C000H + x, 4000H, 40000C000H + x,     0,  80000400H    );
      INC(i)
    END;                 x:=(8000H*(N-1)); 
    Segment( 0, "__LINKEDIT", b + 100000000H + x, 4000H, b+x, 1E1H, 100000001H, 0 );
    Mysterious( TRUE, 34H, 38H, b + x  );              (* dyld_chained_fixups  *)
    Mysterious( TRUE, 33H, 38H, b + 38H + x  );        (* dyld_exports_trie    *)
    Symbols( 3, b + 78H + x, 28H, b + 0A8H + x  );
    SymbolTableInfo( 0, 0, 3, 0, 0, 3 );
    LoadDylinker();
    ApplicationUUID( 0F931B7FDE38F91CCH, 239DEFA4E546FD8AH );
    MinimumOS();
    Mysterious( FALSE, 2AH, 0, 0 );      (* source version used to build binary *)
    MainEntry( 3F9CH, 0 ); (* 3FA0H *)
    LinkLibSystem();
    Mysterious( FALSE, 26H, 8H, b + 70H + x ); (* compressed table of function start addresses *)
    Mysterious( FALSE, 29H, 0, b + 78H + x );  (* table of non-instructions in __text *)
    CodeSignature( 111H, b + 0D0H + x );
*)
    (* post-header padding *)
(*    i := 0; WHILE i < (1937 - 39H ) DO WR( 0000000000000000H ); INC(i) END; *)
(*    Files.Set( R, F, 3F90H );
    ExitCode( ProgEntry );
*)
    (* Kernel data page *)

    (* write kernel / runtime elements at 4000H to 8000H *) 
(*
    p:=SYSTEM.VAL(INTEGER,K);
    i := 0; WHILE i < 4000H DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8) END; 
*)

  END Finish;
 


BEGIN 
END Elf.

