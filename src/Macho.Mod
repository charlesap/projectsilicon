MODULE Macho;  (*Write a MACHO file cp 2023*)
  IMPORT SYSTEM, Files;

  CONST
    REQDYLD = 80000000H; SEGMENT = 1H; SYMTAB = 2H; SYMSEG = 3H; THREAD = 4H; UNIXTHREAD = 5H;
    LOADFVMLIB = 6H; IDFVMLIB = 7H; IDENT = 8H; FVMFILE = 9H; PREPAGE = 0AH; DYSYMTAB = 0BH; LOADDYLIB = 0CH;
    IDDYLIB = 0DH; LOADDYLINKER = 0EH; IDDYLINKER = 0FH; PREBOUNDDYLIB = 10H; ROUTINES = 11H; SUBFRAMEWORK = 12H;
    SUBUMBRELLA = 13H; SUBCLIENT = 14H; SUBLIBRARY = 15H; TWOLEVELHINTS = 16H; PREBINDCKSUM = 17H; LOADWEAKDYLIB = 18H;
    SEGMENT64 = 19H; ROUTINES64 = 1AH; UUID = 1BH; RPATH = 1CH + REQDYLD; CODESIGNATURE = 1DH; SEGMENTSPLITINFO = 1EH;
    REEXPORTDYLIB = 1FH + REQDYLD; LAZYLOADDYLIB = 20H; ENCRYPTIONINFO = 21H; DYLDINFO = 22H; DYLDINFOONLY = 22H + REQDYLD; 

  TYPE

  VAR 

  PROCEDURE WR( VAR R: Files.Rider; i: INTEGER );
  BEGIN
    Files.WriteInt( R, i );
  END WR;

  PROCEDURE Header(VAR R: Files.Rider; nCMD: INTEGER);
  BEGIN 
    (* CPU type / Magic number     File type / CPU subtype          LCsz 93*8 = 2E8H / # LC          Reserved / Flags  *) 
    WR( R, 0100000CFEEDFACFH ); WR( R, 0000000200000000H ); WR( R, 000002E800000000H + nCMD); WR( R, 0000000000200085H ); 
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
    WR( R, 000000200000000EH ); (* cmdsize    / cmd          000000200000000E *)
    WR( R, 7273752F0000000CH ); (*                           7273752F0000000C *)
    WR( R, 6C79642F62696C2FH ); (*                           6C79642F62696C2F *)
    WR( R, 0000000000000064H ); (*                           0000000000000064 *)
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

  PROCEDURE MacPrefix*(VAR R: Files.Rider);
    VAR i: INTEGER;
  BEGIN              (*     exit                High Word / Low Word        inout         *)
  
    Header( R , 16 );                                                         (* 17 *)
    Segment( R, 0, "__PAGEZERO", 0, 100000000H, 0, 0, 0, 0 ); 
    Segment( R, 2, "__TEXT", 100000000H, 4000H, 0, 4000H, 500000005H, 0 ); 
    Section( R, "__text", "__TEXT",100003F90H,1CH,400003F90H,0,80000400H);    (* 100003F80H, 38H, 200003F80H, 0, 80000400H *)
    Section( R, "__unwind_info", "__TEXT", 100003FACH, 48H, 200003FACH, 0, 0);(* 100003FB8H, 48H, 200003FB8H, 0, 0 *)
(*  Segment( R, 1, "__DATA", 100004000H, 4000H, 0, 0, 300000003H, 1 ); 
    Section( R, "__data", "__DATA", 100004000H, 28H, 400H, 0, 0);  *) 
    Segment( R, 0, "__LINKEDIT", 100004000H, 4000H, 4000H, 1E1H, 100000001H, 0 ); (* 100008000H, 4000H, 8000H, 282H, 100000001H, 0 *)
    Mysterious( R, TRUE, 34H, 38H, 4000H );        (* dyld_chained_fixups        38H, 8000H *)
    Mysterious( R, TRUE, 33H, 38H, 4038H );        (* dyld_exports_trie          30H, 8038H *)
    Symbols( R, 3, 4078H, 28H, 40A8H );                                       (* 5, 8070H, 30H, 80C0H *)
    SymbolTableInfo( R, 0, 0, 3, 0, 0, 3 );                                   (* 3, 0, 2, 3, 0, 5 *)
    LoadDylinker( R );
    ApplicationUUID( R, 0F931B7FDE38F91CCH, 239DEFA4E546FD8AH );              (* 0A23F6185A0BB867AH, 0FDECD0CFFC341DAAH *)
    MinimumOS( R );
    Mysterious( R, FALSE, 2AH, 0, 0 );      (* source version used to build binary 0, 0 *)
    MainEntry( R, 3FA0H, 0 );                                                 (* 3F80H, 0 *)
    LinkLibSystem( R );
    Mysterious( R, FALSE, 26H, 8H, 4070H ); (* compressed table of function start addresses 8H, 8068H *)
    Mysterious( R, FALSE, 29H, 0, 4078H );  (* table of non-instructions in __text 0, 8070H *)
    CodeSignature( R, 111H, 40D0H );                                          (* 192H, 80F0H *)



                                                                                    
    (* PADDING *)                                                        
    i:=0; WHILE i < 1937 DO                                              
    WR( R, 0000000000000000H ); (* padding                 *)
    INC(i);                                                              
    END;                                                                 
                                                                         
    (* PROGRAM *)                                                       
    WR( R, 2222222211111111H );         (*                   D2800000D2800070 *) 
    WR( R, 4444444433333333H );         (*                   B0000001D2800282 *)  
    WR( R,0D2800030D2800540H );         (*                   D400000191000021 *)  
    WR( R, 00000001D4001001H );         (*                   D2800020D2800090 *)  
    WR( R, 000000000000001CH );         (*                   91000021B0000001 *)  
    WR( R, 000000000000001CH );         (*                   D2800000D4000001 *)  
    WR( R, 000000020000001CH );         (*                   D4000001D2800030 *)  
    WR( R, 0000003400003F90H );         (*                   0000001C00000001 *)  
    WR( R, 00003FAD00000034H );         (*                   0000001C00000000 *)  
    WR( R, 0000003400000000H );         (*                  *                 *) 
    WR( R, 0001000C00000003H );         (*                   00003F8000000002 *) 
    WR( R, 0000000000010010H );         (*                   0000003400000034 *) 
    WR( R, 0000000000000000H );         (*                   0000000000003FB9 *) 
    WR( R, 0000000000000000H );         (*                   0000000300000034 *) 
    WR( R, 0000002000000000H );         (*                   000100100001000C *) 
    WR( R, 0000003000000030H );         (*                   0000000000000000 *) 
    WR( R, 0000000100000000H );         (*                  *                 *) 
    WR( R, 0000000000000000H );         (*                   0000002000000000 *) 
    WR( R, 0000000000000003H );         (*                   0000003400000034 *) 
    WR( R, 0000000000000000H );         (*                   0000000100000000 *) 
    WR( R, 0000000000000000H );         (*                   0000000000000000 *) 
    WR( R, 00000209005F0100H );         (*                   0000000000000004 *) 
    WR( R, 655F686D5F030000H );         (*                   0000000000000000 *) 
    WR( R, 685F657475636578H );         (*                  *                 *) 
    WR( R, 6405007265646165H );         (*                   00000209005F0100 *) 
    WR( R, 69616D2B00617461H );         (*                   655F686D5F020000 *) 
    WR( R, 007F90000330006EH );         (*                   685F657475636578 *) 
    WR( R, 000000007FA00003H );         (*                   7305007265646165 *) 
    WR( R, 0000000000107F90H );         (*                   0003260074726174 *) 
    WR( R, 0010010F00000002H );         (*                   0000000000007F80 *) 
    WR( R, 0000000100000000H );         (*                   0000000014187F80 *) 
    WR( R, 0000010F00000016H );         (*                   0000010E0000001D *) 
    WR( R, 0000000100003F90H );         (*                   0000000100003F98 *) 
    WR( R, 0000010F0000001CH );         (*                   0000010E00000024 *) 
    WR( R, 0000000100003FA0H );         (*                   0000000100003FAC *) 
    WR( R, 655F686D5F5F0020H );         (*                   0000030E00000029 *) 
    WR( R, 685F657475636578H );         (*                   0000000100004000 *) 
    WR( R, 645F007265646165H );         (*                   0010010F00000002 *) 
    WR( R, 69616D5F00617461H );         (*                   0000000100000000 *) 
    WR( R, 000000000000006EH );         (*                   0000010F00000016 *) 
    WR( R, 11010000C00CDEFAH );         (*                   0000000100003F80 *) 
    WR( R, 0000000001000000H );         (*                   655F686D5F5F0020 *) 
    WR( R, 020CDEFA14000000H );         (*                   685F657475636578 *) 
    WR( R, 00040200FD000000H );         (*                   735F007265646165 *) 
    WR( R, 5D00000002000200H );         (*                   72775F0074726174 *) 
    WR( R, 0000000058000000H );         (*                   646E655F00657469 *) 
    WR( R,0D040000005000000H );         (*                   0000000067736D00 *) 
    WR( R, 000000000C000220H );         (*                   92010000C00CDEFA *) 
    WR( R, 0000000000000000H );         (*                   0000000001000000 *) 
    WR( R, 0000000000000000H );         (*                   020CDEFA14000000 *) 
    WR( R, 0000000000000000H );         (*                   000402007E010000 *) 
    WR( R, 0000000000000000H );         (*                   5E00000002000200 *) 
    WR( R, 0000000000400000H );         (*                   0000000058000000 *) 
    WR( R, 7469786501000000H );         (*                   F080000009000000 *) 
    WR( R,0E44ED3E1DFC4A100H );         (*                   000000000C000220 *) 
    WR( R, 1E42D7D51C8BCABDH );         (*                   0000000000000000 *) 
    WR( R, 27ED0494BF1E607EH );         (*                  *                 *) 
    WR( R,0CF8C3007AF6DF0EAH );         (*                   0000000000400000 *) 
    WR( R,0C66F58B2AC7FADDBH );         (*                   756F6E6901000000 *) 
    WR( R, 6BD1D1D704C066E9H );         (*                   7A8DCA0D30250074 *)
    WR( R, 7CB47CFF05584F02H );         (*                   28224F373E4D6C93 *)
    WR( R, 2C89488BBDDA857AH );         (*                   97BB757A0B49192E *)
    WR( R,0C66F58B2AC7FADA7H );         (*                   BD5B96E17C12B559 *)
    WR( R, 6BD1D1D704C066E9H );         (*                   6F58B2AC7FADB827 *)
    WR( R, 7CB47CFF05584F02H );         (*                   D1D1D704C066E9C6 *)
    WR( R, 2C89488BBDDA857AH );         (*                   B47CFF05584F026B *)
    WR( R, 4F71619F59E5D3A7H );         (*                   89488BBDDA857A7C *)
    WR( R,0AF0F3CF18BA3B5B9H );         (*                   6F58B2AC7FADA72C *)
    WR( R, 856800CC336928C8H );         (*                   D1D1D704C066E9C6 *)
    WR( R,0D974C511725ECD2AH );         (*                   B47CFF05584F026B *)
    WR( R, 1AB8F5E7290BFBF8H );         (*                   89488BBDDA857A7C *)
    WR( R,0D1DD033EB3E09DE0H );         (*                   108C61B5FFC2A72C *)
    WR( R, 97350ADD9EE6EBF5H );         (*                   3F7929C5FA570DBD *)
    WR( R,0E6B960A1A0A512BDH );         (*                   C24D67B6D10C076A *)
    Files.Write( R, 0DDH );                         (*                   666F1825BA72E918 *)
                                                    (*                   6F58B2AC7FADB2AB *)
                                                    (*                   D1D1D704C066E9C6 *)
                                                    (*                   B47CFF05584F026B *)
                                                    (*                   89488BBDDA857A7C *)
                                                    (*                   6F58B2AC7FADA72C *)
                                                    (*                   D1D1D704C066E9C6 *)
                                                    (*                   B47CFF05584F026B *)
                                                    (*                   89488BBDDA857A7C *)
                                                    (*                   6F58B2AC7FADA72C *)
                                                    (*                   D1D1D704C066E9C6 *)
                                                    (*                   B47CFF05584F026B *)
                                                    (*                   89488BBDDA857A7C *)
                                                    (*                   6F58B2AC7FADA72C *)
                                                    (*                   D1D1D704C066E9C6 *)
                                                    (*                   B47CFF05584F026B *)
                                                    (*                   89488BBDDA857A7C *)
                                                    (*                   97F09ADDC8D3A72C *)
                                                    (*                   FE3B9F09B741C0F3 *)
                                                    (*                   696F9C29358E8669 *)
                                                    (*                   95822BE6CE4F59D4 *)
                                                    (*                   000000000000084D *)
                                                                                          
                                                                                          
                                                                                          
                                                    




  END MacPrefix;
 


BEGIN 
END Macho.

