    MODULE oac;
      IMPORT OAP;

      VAR 
        f: OAP.FileName;
        o: OAP.Options;

    BEGIN
        o:="-rso";
        f:="M.Mod";
	OAP.Compile(f,"-rso");
    END oac.
