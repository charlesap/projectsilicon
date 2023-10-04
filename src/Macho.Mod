MODULE Macho;  (*Write a MACHO file cp 2023*)
  IMPORT SYSTEM, OAB, Files;

  CONST
    
  TYPE

  VAR 

  PROCEDURE WR( VAR R: Files.Rider; i: INTEGER );
  BEGIN
    Files.WriteInt( R, i );
  END WR;

  PROCEDURE Header(VAR R: Files.Rider; LCsz, nCMD: INTEGER);
  BEGIN 
    (* CPU type / Magic number     File type / CPU subtype          LCsz 93*8 = 2E8H / # LC          Reserved / Flags  *) 
    WR( R, 0100000CFEEDFACFH ); WR( R, 200000000H ); WR( R, LCsz*100000000H + nCMD); WR( R, 200085H ); 
  END Header;
 
  PROCEDURE Segment(VAR R: Files.Rider; nsect: INTEGER; nmSEGM: ARRAY OF CHAR; vmaddr, vmsize, foffset, fsize, prot, flag32: INTEGER);
    VAR i,x: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
    x := 48H + (50H * nsect);
    WR( R, 19H + 100000000H * x );
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSEGM;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( R, nmlo );  WR( R, nmhi ); 
    WR( R, vmaddr );  WR( R, vmsize ); 
    WR( R, foffset );  WR( R, fsize ); (* file offset ; size in file *)
    WR( R, prot );  WR( R, flag32*100000000 + nsect ); (* initprot / maxprot ;  flag32 / n of sections *) 
  END Segment;

  PROCEDURE Section(VAR R: Files.Rider; nmSECT, nmSEGM: ARRAY OF CHAR; saddr, ssize, saddrsoff, nrelrelo, fandt: INTEGER);
    VAR i: INTEGER; 
        nmlo, nmhi: INTEGER;
        nmbuf: ARRAY 16 OF CHAR;
  BEGIN
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSECT;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( R, nmlo );  WR( R, nmhi );
    i:=0; WHILE i < 16 DO nmbuf[i] := 0X; INC(i) END;
    nmbuf := nmSEGM;
    SYSTEM.GET(SYSTEM.ADR(nmbuf),nmlo);
    SYSTEM.GET(SYSTEM.ADR(nmbuf)+8,nmhi); 
    WR( R, nmlo );  WR( R, nmhi );
 
    WR( R, saddr );  WR( R, ssize );        (* section address, size *)
    WR( R, saddrsoff );  WR( R, nrelrelo ); (* Alignment / file offset, #reloc / reloc file offset *)
    WR( R, fandt );                         (* Reserved / Flag & Type *)
    WR( R, 0 );                             (* Reserved / Reserved *)
  END Section;

  PROCEDURE Mysterious(VAR R: Files.Rider; ignorable: BOOLEAN; id, p1, p2: INTEGER);
  BEGIN
    IF ignorable THEN 
      WR( R, id + 1080000000H )
    ELSE
      WR( R, id + 1000000000H )
    END;
    WR( R, p1*100000000H + p2 );
  END Mysterious;

  PROCEDURE Symbols(VAR R: Files.Rider; nSYM, symfo, strtabsz, strtabfo: INTEGER);
  BEGIN
    WR( R, 1800000002H ); 
    WR( R, nSYM*100000000H + symfo ); 
    WR( R, strtabsz*100000000H + strtabfo ); 
  END Symbols;

  PROCEDURE SymbolTableInfo(VAR R: Files.Rider; nLSym, LSymI, nESym, ESymI, nUSym, USymI: INTEGER);
  BEGIN
    WR( R, 500000000BH ); 
    WR( R, nLSym * 100000000H + LSymI );
    WR( R, nESym * 100000000H + ESymI ); 
    WR( R, nUSym * 100000000H + USymI ); 
    WR( R, 0 ); 
    WR( R, 0 ); 
    WR( R, 0 ); 
    WR( R, 0 ); 
    WR( R, 0 ); 
    WR( R, 0 ); 
  END SymbolTableInfo;

  PROCEDURE LoadDylinker(VAR R: Files.Rider);
  BEGIN
    WR( R, 000000200000000EH );
    WR( R, 7273752F0000000CH );
    WR( R, 6C79642F62696C2FH );
    WR( R, 0000000000000064H );
  END LoadDylinker;

  PROCEDURE ApplicationUUID(VAR R: Files.Rider; UUIDhi, UUIDlo: INTEGER);
  BEGIN
    WR( R, 000000180000001BH );
    WR( R, UUIDhi );
    WR( R, UUIDlo );
  END ApplicationUUID;

  PROCEDURE MinimumOS(VAR R: Files.Rider);
  BEGIN
    WR( R, 0000002000000032H );
    WR( R, 000D000000000001H );
    WR( R, 00000001000A1200H );
    WR( R, 0359010000000003H );
  END MinimumOS;

  PROCEDURE MainEntry(VAR R: Files.Rider; address, stack: INTEGER);
  BEGIN
    WR( R, 1880000028H ); 
    WR( R, address ); 
    WR( R, stack ); 
  END MainEntry;

  PROCEDURE LinkLibSystem(VAR R: Files.Rider);
  BEGIN
    WR( R, 000000380000000CH ); 
    WR( R, 0000000200000018H );
    WR( R, 0001000005276403H );
    WR( R, 62696C2F7273752FH );
    WR( R, 7473795362696C2FH );
    WR( R, 6C79642E422E6D65H );
    WR( R, 0000000000006269H );
  END LinkLibSystem;

  PROCEDURE CodeSignature(VAR R: Files.Rider; p1, p2: INTEGER);
  BEGIN
    WR( R, 100000001DH );
    WR( R, p1 * 100000000H + p2 );
  END CodeSignature;


  PROCEDURE ExitCode(VAR R: Files.Rider);
  BEGIN
          WR( R, 2222222211111111H );
          WR( R, 4444444433333333H );
          WR( R,0D2800030D2800540H );
          WR( R, 00000001D4001001H );
          WR( R, 000000000000001CH );
          WR( R, 000000000000001CH );
          WR( R, 000000020000001CH );
          WR( R, 0000003400003F90H );
          WR( R, 00003FAD00000034H );
          WR( R, 0000003400000000H );
          WR( R, 0001000C00000003H );
          WR( R, 0000000000010010H );
          WR( R, 0000000000000000H );
          WR( R, 0000000000000000H );
  END ExitCode;

  PROCEDURE Write*(VAR R: Files.Rider; Code, Data: OAB.Bin; CodeLimit, DataLimit, ProgramEntry: INTEGER);
    VAR i,v,x,b: INTEGER;
  BEGIN


    b:=0C000H;


    Header( R , 380H + (13H * 8), 18 ); 
    Segment( R, 0, "__PAGEZERO", 0,           100000000H,     0,          0,     0, 0 ); 
    Segment( R, 2, "__TEXT",                  100000000H, 4000H,          0, 4000H, 500000005H, 0 );
    Section( R,    "__text", "__TEXT",        100003F90H,   1CH, 400003F90H,     0,  80000400H    );
    Section( R,    "__unwind_info", "__TEXT", 100003FACH,   48H, 200003FACH,     0,         0     );
    Segment( R, 1, "__D000",                  100004000H, 4000H,      4000H, 4000H, 300000003H, 0 );
    Section( R,    "__d000", "__D000",        100004000H, 4000H,      4000H,     0,         0     );
    Segment( R, 1, "__C000",                  100008000H, 4000H,      8000H, 4000H, 500000005H, 0 );
    Section( R,    "__c000", "__C000",        100008000H, 4000H, 400008000H,     0,  80000400H    );

    Segment( R, 0, "__LINKEDIT", b + 100000000H, 4000H, b, 1E1H, 100000001H, 0 );
    Mysterious( R, TRUE, 34H, 38H, b );              (* dyld_chained_fixups  *)
    Mysterious( R, TRUE, 33H, 38H, b + 38H );        (* dyld_exports_trie    *)
    Symbols( R, 3, b + 78H, 28H, b + 0A8H );
    SymbolTableInfo( R, 0, 0, 3, 0, 0, 3 );
    LoadDylinker( R );
    ApplicationUUID( R, 0F931B7FDE38F91CCH, 239DEFA4E546FD8AH );
    MinimumOS( R );
    Mysterious( R, FALSE, 2AH, 0, 0 );      (* source version used to build binary *)
    MainEntry( R, 3FA0H, 0 );
    LinkLibSystem( R );
    Mysterious( R, FALSE, 26H, 8H, b + 70H ); (* compressed table of function start addresses *)
    Mysterious( R, FALSE, 29H, 0, b + 78H );  (* table of non-instructions in __text *)
    CodeSignature( R, 111H, b + 0D0H );



                                                                                    
    (* PADDING *)                                                        
    i:=0; WHILE i < (1937 - (13H * 2))  DO                                              
    WR( R, 0000000000000000H ); (* padding                 *)
    INC(i);                                                              
    END;                                                                 
                                
    ExitCode( R );

(*
    i:=0;   
    x:=SYSTEM.VAL(INTEGER,Code);
    WHILE i < CodeLimit DO SYSTEM.GET(x+i,v); WR( R, v ); INC(i,8) END; 
*)
                                      
    (* PADDING *)                                                        
    i:=0; WHILE i < (8000H DIV 8)  DO                                              
    WR( R, 0000000000000000H ); (* padding                 *)
    INC(i);                                                              
    END;                                                                 
                                
    (* misc bookkeeping to satisfy the loader *)

    WR( R, 0000002000000000H );
    WR( R, 0000003000000030H );
    WR( R, 0000000100000000H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000000003H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000000000H );
    WR( R, 00000209005F0100H );
    WR( R, 655F686D5F030000H );
    WR( R, 685F657475636578H );
    WR( R, 6405007265646165H );
    WR( R, 69616D2B00617461H );
    WR( R, 007F90000330006EH );
    WR( R, 000000007FA00003H );
    WR( R, 0000000000107F90H );
    WR( R, 0010010F00000002H );
    WR( R, 0000000100000000H );
    WR( R, 0000010F00000016H );
    WR( R, 0000000100003F90H );
    WR( R, 0000010F0000001CH );
    WR( R, 0000000100003FA0H );
    WR( R, 655F686D5F5F0020H );
    WR( R, 685F657475636578H );
    WR( R, 645F007265646165H );
    WR( R, 69616D5F00617461H );
    WR( R, 000000000000006EH );
    WR( R, 11010000C00CDEFAH );
    WR( R, 0000000001000000H );
    WR( R, 020CDEFA14000000H );
    WR( R, 00040200FD000000H );
    WR( R, 5D00000002000200H );
    WR( R, 0000000058000000H );
    WR( R,0D040000005000000H );
    WR( R, 000000000C000220H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000000000H );
    WR( R, 0000000000400000H );
    WR( R, 7469786501000000H );
    WR( R,0E44ED3E1DFC4A100H );
    WR( R, 1E42D7D51C8BCABDH );
    WR( R, 27ED0494BF1E607EH );
    WR( R,0CF8C3007AF6DF0EAH );
    WR( R,0C66F58B2AC7FADDBH );
    WR( R, 6BD1D1D704C066E9H );
    WR( R, 7CB47CFF05584F02H );
    WR( R, 2C89488BBDDA857AH );
    WR( R,0C66F58B2AC7FADA7H );
    WR( R, 6BD1D1D704C066E9H );
    WR( R, 7CB47CFF05584F02H );
    WR( R, 2C89488BBDDA857AH );
    WR( R, 4F71619F59E5D3A7H );
    WR( R,0AF0F3CF18BA3B5B9H );
    WR( R, 856800CC336928C8H );
    WR( R,0D974C511725ECD2AH );
    WR( R, 1AB8F5E7290BFBF8H );
    WR( R,0D1DD033EB3E09DE0H );
    WR( R, 97350ADD9EE6EBF5H );
    WR( R,0E6B960A1A0A512BDH );
    Files.Write( R, 0DDH );    
                               
  END Write;
 


BEGIN 
END Macho.

