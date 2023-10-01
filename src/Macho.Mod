MODULE Macho;  (*Write a MACHO file cp 2023*)
  IMPORT Files;

  CONST
    REQDYLD     =   80000000H;
    SEGMENT            =   1H;
    SYMTAB             =   2H;
    SYMSEG             =   3H;
    THREAD             =   4H;
    UNIXTHREAD         =   5H;
    LOADFVMLIB         =   6H;
    IDFVMLIB           =   7H;
    IDENT              =   8H;
    FVMFILE            =   9H;
    PREPAGE            =  0AH;
    DYSYMTAB           =  0BH;
    LOADDYLIB          =  0CH;
    IDDYLIB            =  0DH;
    LOADDYLINKER       =  0EH;
    IDDYLINKER         =  0FH;
    PREBOUNDDYLIB     =   10H;
    ROUTINES          =   11H;
    SUBFRAMEWORK      =   12H;
    SUBUMBRELLA       =   13H;
    SUBCLIENT         =   14H;
    SUBLIBRARY        =   15H;
    TWOLEVELHINTS     =   16H;
    PREBINDCKSUM      =   17H;
    LOADWEAKDYLIB     =   18H;
    SEGMENT64         =   19H;
    ROUTINES64        =   1AH;
    UUID              =   1BH;
    RPATH             =   1CH + REQDYLD;
    CODESIGNATURE     =   1DH;
    SEGMENTSPLITINFO  =   1EH;
    REEXPORTDYLIB     =   1FH + REQDYLD;
    LAZYLOADDYLIB     =   20H;
    ENCRYPTIONINFO    =   21H;
    DYLDINFO          =   22H;
    DYLDINFOONLY      =   22H + REQDYLD; 

  TYPE

  VAR 

  PROCEDURE Header(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0100000CFEEDFACFH ); (* CPU type / Magic number   0100000CFEEDFACF *)
    Files.WriteInt( R, 0000000200000000H ); (* File type / CPU subtype   0000000200000000 *)
    Files.WriteInt( R, 000002E800000010H ); (* LCsz 93*8 = 2E8H / # LC   0000038000000011 *)
    Files.WriteInt( R, 0000000000200085H ); (* Reserved    / Flags       0000000000200085 *)
  END Header;
 
  PROCEDURE PageZero(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000004800000019H ); (* cmdsize    / cmd          0000004800000019 *)
    Files.WriteInt( R, 455A454741505F5FH ); (* segname first half        455A454741505F5F *)
    Files.WriteInt( R, 0000000000004F52H ); (* segname second half       0000000000004F52 *)
    Files.WriteInt( R, 0000000000000000H ); (* vmaddr                    0000000000000000 *)
    Files.WriteInt( R, 0000000100000000H ); (* vmsize                    0000000100000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* file offset               0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* size in file              0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* initprot / maxprot        0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* flag32 / n of sections    0000000000000000 *)
  END PageZero;

  PROCEDURE Text(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000E800000019H ); (* cmdsize    / cmd          000000E800000019 *)
    Files.WriteInt( R, 0000545845545F5FH ); (* segname first half        0000545845545F5F *)
    Files.WriteInt( R, 0000000000000000H ); (* segname second half       0000000000000000 *)
    Files.WriteInt( R, 0000000100000000H ); (* vmaddr                    0000000100000000 *)
    Files.WriteInt( R, 0000000000004000H ); (* vmsize                    0000000000004000 *)
    Files.WriteInt( R, 0000000000000000H ); (* file offset               0000000000000000 *)
    Files.WriteInt( R, 0000000000004000H ); (* size in file              0000000000004000 *)
    Files.WriteInt( R, 0000000500000005H ); (* initprot / maxprot        0000000500000005 *)
    Files.WriteInt( R, 0000000000000002H ); (* flag32 / n of sections    0000000000000002 *)
    (* 2a: __text section *)                                                                
    Files.WriteInt( R, 0000747865745F5FH ); (* section name first half   0000747865745F5F *)
    Files.WriteInt( R, 0000000000000000H ); (* section name second half  0000000000000000 *)
    Files.WriteInt( R, 0000545845545F5FH ); (* segment name first half   0000545845545F5F *)
    Files.WriteInt( R, 0000000000000000H ); (* segment name second half  0000000000000000 *)
    Files.WriteInt( R, 0000000100003F90H ); (* section Address           0000000100003F80 *)
    Files.WriteInt( R, 000000000000001CH ); (* section size              0000000000000038 *)
    Files.WriteInt( R, 0000000400003F90H ); (* Align / Sect File Offset  0000000200003F80 *)
    Files.WriteInt( R, 0000000000000000H ); (* #reloc/reloc file offset  0000000000000000 *)
    Files.WriteInt( R, 0000000080000400H ); (* res1      / Flag & Type   0000000080000400 *)
    Files.WriteInt( R, 0000000000000000H ); (* res3      / res2          0000000000000000 *)       
    (* 2b: __unwind_info section *)                                                         
    Files.WriteInt( R, 646E69776E755F5FH ); (* section name first half   646E69776E755F5F *)
    Files.WriteInt( R, 0000006F666E695FH ); (* section name second half  0000006F666E695F *)
    Files.WriteInt( R, 0000545845545F5FH ); (* segment name first half   0000545845545F5F *)
    Files.WriteInt( R, 0000000000000000H ); (* segment name second half  0000000000000000 *)
    Files.WriteInt( R, 0000000100003FACH ); (* section Address           0000000100003FB8 *)
    Files.WriteInt( R, 0000000000000048H ); (* section size              0000000000000048 *)
    Files.WriteInt( R, 0000000200003FACH ); (* Align / Sect File Offset  0000000200003FB8 *)
    Files.WriteInt( R, 0000000000000000H ); (* #reloc/reloc file offset  0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* res1      / Flag & Type   0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (* res3      / res2          0000000000000000 *)      
  END Text;

  PROCEDURE Data(VAR R: Files.Rider);
  BEGIN
                                            (* cmdsize    / cmd          0000009800000019 *)
                                            (* segname first half        0000415441445F5F *)
                                            (* segname second half       0000000000000000 *)
                                            (* vmaddr                    0000000100004000 *)
                                            (* vmsize                    0000000000004000 *)
                                            (* file offset               0000000000000000 *)
                                            (* size in file              0000000000000000 *)
                                            (* initprot / maxprot        0000000300000003 *)
                                            (* flag32 / n of sections    0000000000000001 *)
    (* Xa: __data section *)                                                               
                                            (* section name first half   0000617461645F5F *)
                                            (* section name second half  0000000000000000 *)
                                            (* segment name first half   0000415441445F5F *)
                                            (* segment name second half  0000000000000000 *)
                                            (* section Address           0000000100004000 *)
                                            (* section size              0000000000000028 *)
                                            (* Align / Sect File Offset  0000000000004000 *)
                                            (* #reloc/reloc file offset  0000000000000000 *)
                                            (* res1      / Flag & Type   0000000000000000 *)
                                            (* res3      / res2          0000000000000000 *)                                                               
  END Data;

  PROCEDURE LinkEdit(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000004800000019H ); (* cmdsize    / cmd          0000004800000019 *)
    Files.WriteInt( R, 44454B4E494C5F5FH ); (* segname first half        44454B4E494C5F5F *)
    Files.WriteInt( R, 0000000000005449H ); (* segname second half       0000000000005449 *)
    Files.WriteInt( R, 0000000100004000H ); (* vmaddr                    0000000100008000 *)
    Files.WriteInt( R, 0000000000004000H ); (* vmsize                    0000000000004000 *)
    Files.WriteInt( R, 0000000000004000H ); (* file offset               0000000000008000 *)
    Files.WriteInt( R, 00000000000001E1H ); (* size in file              0000000000000282 *)
    Files.WriteInt( R, 0000000100000001H ); (* initprot / maxprot        0000000100000001 *)
    Files.WriteInt( R, 0000000000000000H ); (* flag32 / n of sections    0000000000000000 *)
  END LinkEdit;

  PROCEDURE CMD34H(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001080000034H ); (* cmdsize    / cmd          0000001080000034 *)
    Files.WriteInt( R, 0000003800004000H ); (*                           0000003800008000 *)
  END CMD34H;

  PROCEDURE CMD33H(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001080000033H ); (* cmdsize    / cmd          0000001080000033 *)
    Files.WriteInt( R, 0000003800004038H ); (*                           0000003000008038 *)
  END CMD33H;

  PROCEDURE SymbolTable(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001800000002H ); (* cmdsize    / cmd          0000001800000002 *)
    Files.WriteInt( R, 0000000300004078H ); (* #sym / sym file offset    0000000500008070 *)
    Files.WriteInt( R, 00000028000040A8H ); (* StrTabSz/StrTabFileOffst  00000030000080C0 *)
  END SymbolTable;

  PROCEDURE SymbolTableInfo(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000500000000BH ); (* cmdsize    / cmd          000000500000000B *)
    Files.WriteInt( R, 0000000000000000H ); (* #LSym / LSymIndex         0000000300000000 *)
    Files.WriteInt( R, 0000000300000000H ); (* #ESym / ESymIndex         0000000200000003 *)
    Files.WriteInt( R, 0000000000000003H ); (* #USym / USymINdex         0000000000000005 *)
    Files.WriteInt( R, 0000000000000000H ); (* #CTabEntries / CTabOfst   0000000000000000 *)
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)                      
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)                     
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)                    
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)                   
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)                  
  END SymbolTableInfo;

  PROCEDURE LoadDylinker(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000200000000EH ); (* cmdsize    / cmd          000000200000000E *)
    Files.WriteInt( R, 7273752F0000000CH ); (*                           7273752F0000000C *)
    Files.WriteInt( R, 6C79642F62696C2FH ); (*                           6C79642F62696C2F *)
    Files.WriteInt( R, 0000000000000064H ); (*                           0000000000000064 *)
  END LoadDylinker;

  PROCEDURE ApplicationUUID(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000180000001BH ); (* cmdsize    / cmd          000000180000001B *)
    Files.WriteInt( R,0F931B7FDE38F91CCH ); (*  128-bit UUID pt 1        A23F6185A0BB867A *)
    Files.WriteInt( R, 239DEFA4E546FD8AH ); (*  128-bit UUID pt 2        FDECD0CFFC341DAA *)
  END ApplicationUUID;

  PROCEDURE MinimumOS(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000002000000032H ); (* cmdsize    / cmd          0000002000000032 *)
    Files.WriteInt( R, 000D000000000001H ); (*                           000D000000000001 *)
    Files.WriteInt( R, 00000001000A1200H ); (*                           00000001000A1200 *)
    Files.WriteInt( R, 0359010000000003H ); (*                           0359010000000003 *)
  END MinimumOS;

  PROCEDURE CMD2AH(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000100000002AH ); (* cmdsize    / cmd          000000100000002A *)
    Files.WriteInt( R, 0000000000000000H ); (*                           0000000000000000 *)
  END CMD2AH;

  PROCEDURE MainEntry(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001880000028H ); (* cmdsize    / cmd          0000001880000028 *)
    Files.WriteInt( R, 0000000000003FA0H ); (*  Address location         0000000000003F80 *)
    Files.WriteInt( R, 0000000000000000H ); (*  Stack memory size        0000000000000000 *)
  END MainEntry;

  PROCEDURE LinkLibSystem(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000380000000CH ); (* cmdsize    / cmd          000000380000000C *)
    Files.WriteInt( R, 0000000200000018H ); (*                           0000000200000018 *)
    Files.WriteInt( R, 0001000005276403H ); (*                           0001000005276403 *)
    Files.WriteInt( R, 62696C2F7273752FH ); (*                           62696C2F7273752F *)
    Files.WriteInt( R, 7473795362696C2FH ); (*                           7473795362696C2F *)
    Files.WriteInt( R, 6C79642E422E6D65H ); (*                           6C79642E422E6D65 *)
    Files.WriteInt( R, 0000000000006269H ); (*                           0000000000006269 *)
  END LinkLibSystem;

  PROCEDURE CMD26H(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001000000026H ); (* cmdsize    / cmd          0000001000000026 *)
    Files.WriteInt( R, 0000000800004070H ); (*                           0000000800008068 *)
  END CMD26H;

  PROCEDURE CMD29H(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 0000001000000029H ); (* cmdsize    / cmd          0000001000000029 *)
    Files.WriteInt( R, 0000000000004078H ); (*                           0000000000008070 *)
  END CMD29H;

  PROCEDURE CodeSignature(VAR R: Files.Rider);
  BEGIN
    Files.WriteInt( R, 000000100000001DH ); (* cmdsize    / cmd          000000100000001D *)
    Files.WriteInt( R, 00000111000040D0H ); (*                           00000192000080F0 *)
  END CodeSignature;

  PROCEDURE MacPrefix*(VAR R: Files.Rider);
    VAR i: INTEGER;
  BEGIN              (*     exit                High Word / Low Word        inout         *)
  
    Header( R );
    PageZero( R );
    Text( R );                                                                         
    Data( R );
    LinkEdit( R );
    CMD34H( R );
    CMD33H( R ); 
    SymbolTable( R );
    SymbolTableInfo( R );
    LoadDylinker( R );
    ApplicationUUID( R );
    MinimumOS( R );
    CMD2AH( R );                                                                                   
    MainEntry( R );
    LinkLibSystem( R );
    CMD26H( R );
    CMD29H( R ); 
    CodeSignature( R );
                                                                                    
                                                                         
    (* PADDING *)                                                        
    i:=0; WHILE i < 1937 DO                                              
    Files.WriteInt( R, 0000000000000000H ); (* padding                 *)
    INC(i);                                                              
    END;                                                                 
                                                                         
    (* PROGRAM *)                                                       
    Files.WriteInt( R, 2222222211111111H );         (*                   D2800000D2800070 *) 
    Files.WriteInt( R, 4444444433333333H );         (*                   B0000001D2800282 *)  
    Files.WriteInt( R,0D2800030D2800540H );         (*                   D400000191000021 *)  
    Files.WriteInt( R, 00000001D4001001H );         (*                   D2800020D2800090 *)  
    Files.WriteInt( R, 000000000000001CH );         (*                   91000021B0000001 *)  
    Files.WriteInt( R, 000000000000001CH );         (*                   D2800000D4000001 *)  
    Files.WriteInt( R, 000000020000001CH );         (*                   D4000001D2800030 *)  
    Files.WriteInt( R, 0000003400003F90H );         (*                   0000001C00000001 *)  
    Files.WriteInt( R, 00003FAD00000034H );         (*                   0000001C00000000 *)  
    Files.WriteInt( R, 0000003400000000H );         (*                  *                 *) 
    Files.WriteInt( R, 0001000C00000003H );         (*                   00003F8000000002 *) 
    Files.WriteInt( R, 0000000000010010H );         (*                   0000003400000034 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000000000003FB9 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000000300000034 *) 
    Files.WriteInt( R, 0000002000000000H );         (*                   000100100001000C *) 
    Files.WriteInt( R, 0000003000000030H );         (*                   0000000000000000 *) 
    Files.WriteInt( R, 0000000100000000H );         (*                  *                 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000002000000000 *) 
    Files.WriteInt( R, 0000000000000003H );         (*                   0000003400000034 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000000100000000 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000000000000000 *) 
    Files.WriteInt( R, 00000209005F0100H );         (*                   0000000000000004 *) 
    Files.WriteInt( R, 655F686D5F030000H );         (*                   0000000000000000 *) 
    Files.WriteInt( R, 685F657475636578H );         (*                  *                 *) 
    Files.WriteInt( R, 6405007265646165H );         (*                   00000209005F0100 *) 
    Files.WriteInt( R, 69616D2B00617461H );         (*                   655F686D5F020000 *) 
    Files.WriteInt( R, 007F90000330006EH );         (*                   685F657475636578 *) 
    Files.WriteInt( R, 000000007FA00003H );         (*                   7305007265646165 *) 
    Files.WriteInt( R, 0000000000107F90H );         (*                   0003260074726174 *) 
    Files.WriteInt( R, 0010010F00000002H );         (*                   0000000000007F80 *) 
    Files.WriteInt( R, 0000000100000000H );         (*                   0000000014187F80 *) 
    Files.WriteInt( R, 0000010F00000016H );         (*                   0000010E0000001D *) 
    Files.WriteInt( R, 0000000100003F90H );         (*                   0000000100003F98 *) 
    Files.WriteInt( R, 0000010F0000001CH );         (*                   0000010E00000024 *) 
    Files.WriteInt( R, 0000000100003FA0H );         (*                   0000000100003FAC *) 
    Files.WriteInt( R, 655F686D5F5F0020H );         (*                   0000030E00000029 *) 
    Files.WriteInt( R, 685F657475636578H );         (*                   0000000100004000 *) 
    Files.WriteInt( R, 645F007265646165H );         (*                   0010010F00000002 *) 
    Files.WriteInt( R, 69616D5F00617461H );         (*                   0000000100000000 *) 
    Files.WriteInt( R, 000000000000006EH );         (*                   0000010F00000016 *) 
    Files.WriteInt( R, 11010000C00CDEFAH );         (*                   0000000100003F80 *) 
    Files.WriteInt( R, 0000000001000000H );         (*                   655F686D5F5F0020 *) 
    Files.WriteInt( R, 020CDEFA14000000H );         (*                   685F657475636578 *) 
    Files.WriteInt( R, 00040200FD000000H );         (*                   735F007265646165 *) 
    Files.WriteInt( R, 5D00000002000200H );         (*                   72775F0074726174 *) 
    Files.WriteInt( R, 0000000058000000H );         (*                   646E655F00657469 *) 
    Files.WriteInt( R,0D040000005000000H );         (*                   0000000067736D00 *) 
    Files.WriteInt( R, 000000000C000220H );         (*                   92010000C00CDEFA *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   0000000001000000 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   020CDEFA14000000 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   000402007E010000 *) 
    Files.WriteInt( R, 0000000000000000H );         (*                   5E00000002000200 *) 
    Files.WriteInt( R, 0000000000400000H );         (*                   0000000058000000 *) 
    Files.WriteInt( R, 7469786501000000H );         (*                   F080000009000000 *) 
    Files.WriteInt( R,0E44ED3E1DFC4A100H );         (*                   000000000C000220 *) 
    Files.WriteInt( R, 1E42D7D51C8BCABDH );         (*                   0000000000000000 *) 
    Files.WriteInt( R, 27ED0494BF1E607EH );         (*                  *                 *) 
    Files.WriteInt( R,0CF8C3007AF6DF0EAH );         (*                   0000000000400000 *) 
    Files.WriteInt( R,0C66F58B2AC7FADDBH );         (*                   756F6E6901000000 *) 
    Files.WriteInt( R, 6BD1D1D704C066E9H );         (*                   7A8DCA0D30250074 *)
    Files.WriteInt( R, 7CB47CFF05584F02H );         (*                   28224F373E4D6C93 *)
    Files.WriteInt( R, 2C89488BBDDA857AH );         (*                   97BB757A0B49192E *)
    Files.WriteInt( R,0C66F58B2AC7FADA7H );         (*                   BD5B96E17C12B559 *)
    Files.WriteInt( R, 6BD1D1D704C066E9H );         (*                   6F58B2AC7FADB827 *)
    Files.WriteInt( R, 7CB47CFF05584F02H );         (*                   D1D1D704C066E9C6 *)
    Files.WriteInt( R, 2C89488BBDDA857AH );         (*                   B47CFF05584F026B *)
    Files.WriteInt( R, 4F71619F59E5D3A7H );         (*                   89488BBDDA857A7C *)
    Files.WriteInt( R,0AF0F3CF18BA3B5B9H );         (*                   6F58B2AC7FADA72C *)
    Files.WriteInt( R, 856800CC336928C8H );         (*                   D1D1D704C066E9C6 *)
    Files.WriteInt( R,0D974C511725ECD2AH );         (*                   B47CFF05584F026B *)
    Files.WriteInt( R, 1AB8F5E7290BFBF8H );         (*                   89488BBDDA857A7C *)
    Files.WriteInt( R,0D1DD033EB3E09DE0H );         (*                   108C61B5FFC2A72C *)
    Files.WriteInt( R, 97350ADD9EE6EBF5H );         (*                   3F7929C5FA570DBD *)
    Files.WriteInt( R,0E6B960A1A0A512BDH );         (*                   C24D67B6D10C076A *)
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

