<?xml version="1.0" encoding="UTF-8"?>
<?bluebottle format version="0.1" ?>
<?xml-stylesheet type="text/xsl" href="http://bluebottle.ethz.ch/bluebottle.xsl" ?>
<Text>
<Span style="Normal"><![CDATA[MODULE AosTypeFinder; (** AUTHOR "Roger Keller"; PURPOSE "Locate a type given its tag."; *)

IMPORT SYSTEM, AosOut, AosModules, AosCommands, WMDialogs, Utilities;

PROCEDURE FindByTag*(p: PTR): PTR;
VAR buf: ARRAY 32 OF CHAR; tag, res: LONGINT;
BEGIN
	IF WMDialogs.QueryString("Enter type tag address (hex).", buf) # WMDialogs.ResOk THEN RETURN NIL END;
	
	Utilities.HexStrToInt(buf, tag, res);
	IF res # Utilities.Ok THEN RETURN NIL END;
	Find(tag);
	
	RETURN NIL
END FindByTag;

PROCEDURE FindByTagAtAddress*(p: PTR): PTR;
VAR buf: ARRAY 32 OF CHAR; tag, res: LONGINT;
BEGIN
	IF WMDialogs.QueryString("Enter address (hex) where pointer to type tag is located.", buf) # WMDialogs.ResOk THEN RETURN NIL END;
	
	Utilities.HexStrToInt(buf, tag, res);
	IF res # Utilities.Ok THEN RETURN NIL END;
	FindByAdr(tag);
	
	RETURN NIL
END FindByTagAtAddress;

PROCEDURE Find(tag: LONGINT);
VAR m: AosModules.Module; td: AosModules.TypeDesc;
BEGIN
	AosModules.ThisTypeByAdr(tag, m, td);
	
	AosOut.String("Type tag ");
	AosOut.Hex(tag, 8); AosOut.String("H ");
	IF m # NIL THEN
		AosOut.String("belongs to ");
		AosOut.String(m.name);
		IF td # NIL THEN
			AosOut.Char(".");
			AosOut.String(td.name)
		ELSE
			AosOut.String(".*Unknown*");
		END
	ELSE
		AosOut.String("could not be resolved.")
	END;
END Find;

PROCEDURE FindByAdr(adr: LONGINT);
VAR m: AosModules.Module; td: AosModules.TypeDesc; tag: LONGINT;
BEGIN
	SYSTEM.GET(adr, tag);
	Find(tag)
END FindByAdr;

END AosTypeFinder.]]></Span>

</Text>
