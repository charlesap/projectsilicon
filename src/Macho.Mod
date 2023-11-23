MODULE Macho;  (*Write a MACHO file cp 2023*)
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
    WR( 0100000CFEEDFACFH ); WR( 200000000H ); WR( LCsz*100000000H + nCMD); WR( 200085H ); 
  END Header;
 
  PROCEDURE Segment(nsect: INTEGER; nmSEGM: ARRAY OF CHAR; vmaddr, vmsize, foffset, fsize, prot, flag32: INTEGER);
    VAR i,x: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
    x := 48H + (50H * nsect);
    WR( 19H + 100000000H * x );
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSEGM;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( nmlo );  WR( nmhi ); 
    WR( vmaddr );  WR( vmsize ); 
    WR( foffset );  WR( fsize ); (* file offset ; size in file *)
    WR( prot );  WR( flag32*100000000 + nsect ); (* initprot / maxprot ;  flag32 / n of sections *) 
  END Segment;

  PROCEDURE Section(nmSECT, nmSEGM: ARRAY OF CHAR; saddr, ssize, saddrsoff, nrelrelo, fandt: INTEGER);
    VAR i: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSECT;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( nmlo );  WR( nmhi );
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSEGM;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( nmlo );  WR( nmhi );
 
    WR( saddr );  WR( ssize );        (* section address, size *)
    WR( saddrsoff );  WR( nrelrelo ); (* Alignment / file offset, #reloc / reloc file offset *)
    WR( fandt );                         (* Reserved / Flag & Type *)
    WR( 0 );                             (* Reserved / Reserved *)
  END Section;

  PROCEDURE Mysterious(ignorable: BOOLEAN; id, p1, p2: INTEGER);
  BEGIN
    IF ignorable THEN 
      WR( id + 1080000000H )
    ELSE
      WR( id + 1000000000H )
    END;
    WR( p1*100000000H + p2 );
  END Mysterious;

  PROCEDURE Symbols(nSYM, symfo, strtabsz, strtabfo: INTEGER);
  BEGIN
    WR( 1800000002H ); 
    WR( nSYM*100000000H + symfo ); 
    WR( strtabsz*100000000H + strtabfo ); 
  END Symbols;

  PROCEDURE SymbolTableInfo(nLSym, LSymI, nESym, ESymI, nUSym, USymI: INTEGER);
  BEGIN
    WR( 500000000BH ); 
    WR( nLSym * 100000000H + LSymI );
    WR( nESym * 100000000H + ESymI ); 
    WR( nUSym * 100000000H + USymI ); 
    WR( 0 ); 
    WR( 0 ); 
    WR( 0 ); 
    WR( 0 ); 
    WR( 0 ); 
    WR( 0 ); 
  END SymbolTableInfo;

  PROCEDURE LoadDylinker();
  BEGIN
    WR( 000000200000000EH );
    WR( 7273752F0000000CH );
    WR( 6C79642F62696C2FH );
    WR( 0000000000000064H );
  END LoadDylinker;

  PROCEDURE ApplicationUUID(UUIDhi, UUIDlo: INTEGER);
  BEGIN
    WR( 000000180000001BH );
    WR( UUIDhi );
    WR( UUIDlo );
  END ApplicationUUID;

  PROCEDURE MinimumOS();
  BEGIN
    WR( 0000002000000032H );
    WR( 000D000000000001H );
    WR( 00000001000A1200H );
    WR( 0359010000000003H );
  END MinimumOS;

  PROCEDURE MainEntry(address, stack: INTEGER);
  BEGIN
    WR( 1880000028H ); 
    WR( address ); 
    WR( stack ); 
  END MainEntry;

  PROCEDURE LinkLibSystem();
  BEGIN
    WR( 000000380000000CH ); 
    WR( 0000000200000018H );
    WR( 0001000005276403H );
    WR( 62696C2F7273752FH );
    WR( 7473795362696C2FH );
    WR( 6C79642E422E6D65H );
    WR( 0000000000006269H );
  END LinkLibSystem;

  PROCEDURE CodeSignature(p1, p2: INTEGER);
  BEGIN
    WR( 100000001DH );
    WR( p1 * 100000000H + p2 );
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
    i := 0; WHILE i < 8000H DO WR( 0 ); INC(i,8); END
  END Prepare;


  PROCEDURE Write*(D, C: OAB.Mbin; dsz, csz: INTEGER);
    VAR i,p,v,lim: INTEGER;
  BEGIN

                                                     
    (* module data at 8000H *)
    i:=0; WHILE i <  (4000H - dsz) -8 DO WR( 0 ); INC(i,8); END; (* pad so data ends at 0C000H *)
    lim:=SYSTEM.VAL(INTEGER,D) + SYSTEM.SIZE(OAB.Mbin);
    p:= lim - dsz;
    WHILE p < lim DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8); END;
    p:=SYSTEM.VAL(INTEGER,C);
    (* module code *)                                                        
    WHILE i <  8000H DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8); END;

  END Write;

  PROCEDURE Bump(VAR c: CHAR);
  BEGIN
    c:=CHR(ORD(c)+1);
  END Bump;


  PROCEDURE Finish*(VAR F: Files.File; K: OAB.Kbin; N, ProgEntry: INTEGER);
    VAR i,p,v,x: INTEGER;
        c,C,d,D: ARRAY 8 OF CHAR;
  BEGIN
                         
    (* misc bookkeeping to satisfy the loader *)

    WR( 0000002000000000H );
    WR( 0000003000000030H );
    WR( 0000000100000000H );
    WR( 0000000000000000H );
    WR( 0000000000000003H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 00000209005F0100H );
    WR( 655F686D5F030000H );
    WR( 685F657475636578H );
    WR( 6405007265646165H );
    WR( 69616D2B00617461H );
    WR( 007F90000330006EH );
    WR( 000000007FA00003H );
    WR( 0000000000107F90H );
    WR( 0010010F00000002H );
    WR( 0000000100000000H );
    WR( 0000010F00000016H );
    WR( 0000000100003F90H );
    WR( 0000010F0000001CH );
    WR( 0000000100003FA0H );
    WR( 655F686D5F5F0020H );
    WR( 685F657475636578H );
    WR( 645F007265646165H );
    WR( 69616D5F00617461H );
    WR( 000000000000006EH );
    WR( 11010000C00CDEFAH );
    WR( 0000000001000000H );
    WR( 020CDEFA14000000H );
    WR( 00040200FD000000H );
    WR( 5D00000002000200H );
    WR( 0000000058000000H );
    WR(0D040000005000000H );
    WR( 000000000C000220H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000000000H );
    WR( 0000000000400000H );
    WR( 7469786501000000H );
    WR(0E44ED3E1DFC4A100H );
    WR( 1E42D7D51C8BCABDH );
    WR( 27ED0494BF1E607EH );
    WR(0CF8C3007AF6DF0EAH );
    WR(0C66F58B2AC7FADDBH );
    WR( 6BD1D1D704C066E9H );
    WR( 7CB47CFF05584F02H );
    WR( 2C89488BBDDA857AH );
    WR(0C66F58B2AC7FADA7H );
    WR( 6BD1D1D704C066E9H );
    WR( 7CB47CFF05584F02H );
    WR( 2C89488BBDDA857AH );
    WR( 4F71619F59E5D3A7H );
    WR(0AF0F3CF18BA3B5B9H );
    WR( 856800CC336928C8H );
    WR(0D974C511725ECD2AH );
    WR( 1AB8F5E7290BFBF8H );
    WR(0D1DD033EB3E09DE0H );
    WR( 97350ADD9EE6EBF5H );
    WR(0E6B960A1A0A512BDH );
    Files.Write( R, 0DDH );    

    Files.Set( R, F, 0 );

    Header( 380H + ((13H * 8)*2)*N, 19+((N-1)*2) ); (* 1200 or 4B0H *) 
    Segment( 0, "__PAGEZERO", 0,           100000000H,         0,          0,         0, 0 ); 
    Segment( 2, "__TEXT",                  100000000H,     4000H,          0,     4000H, 500000005H, 0 );
    Section(    "__text", "__TEXT",        100003F90H,       1CH, 400003F90H,         0,  80000400H    );
    Section(    "__unwind_info", "__TEXT", 100003FACH,       48H, 400003FACH,         0,         0     );
    Segment( 1, "__K000",                  100004000H,     4000H,      4000H,     4000H, 300000003H, 0 );
    Section(    "__k000", "__K000",        100004000H,     4000H, 400004000H,         0,         0     );
    D:="__D000"; d:="__d000";
    C:="__C000"; c:="__c000";
    Segment( 1, D,                         100008000H,     4000H,      8000H,     4000H, 300000003H, 0 );
    Section(    d, D,                      100008000H,     4000H, 400008000H,         0,         0     );
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

    (* post-header padding *)
(*    i := 0; WHILE i < (1937 - 39H ) DO WR( 0000000000000000H ); INC(i) END; *)
    Files.Set( R, F, 3F90H );
    ExitCode( ProgEntry );

    (* Kernel data page *)

    (* write kernel / runtime elements at 4000H to 8000H *) 
    p:=SYSTEM.VAL(INTEGER,K);
    i := 0; WHILE i < 4000H DO SYSTEM.GET(p,v); WR( v ); INC(p,8); INC(i,8) END; 


  END Finish;
 


BEGIN 
END Macho.

