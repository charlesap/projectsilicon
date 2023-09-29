    MODULE oac;
      IMPORT OAP;

      VAR 
        f: OAP.FileName;
        o: OAP.Options;

    BEGIN
        o:="-rs";
        f:="M.Mod";
	OAP.Compile(f,"-rs");
    END oac.

