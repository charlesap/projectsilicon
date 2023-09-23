    MODULE oac;
      IMPORT OXP;

      VAR 
        f: OXP.FileName;
        o: OXP.Options;

    BEGIN
        o:="-rs";
        f:="M.Mod";
	OXP.Compile(f,"-rs");
    END oac.
