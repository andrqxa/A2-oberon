<?xml version="1.0" encoding="UTF-8"?>
<?bluebottle format version="0.1" ?>
<?xml-stylesheet type="text/xsl" href="http://bluebottle.ethz.ch/bluebottle.xsl" ?>
<Text>
<Span style="Normal"><![CDATA[MODULE ShellTools;]]></Span><Span style="AdHoc Oberon 14 0 0 000000FF 00000000"><![CDATA[	]]></Span><Span style="Comment"><![CDATA[(** AUTHOR "boenhofph"; PURPOSE "Developping and updating BimboShell on QBIC"; Revision: "2006-08-16	1.0.1" *]]></Span><Span style="AdHoc Oberon 14 0 0 808080FF 00000000"><![CDATA[)]]></Span><Span style="AdHoc Oberon 10 2 0 808080FF 00000000"><![CDATA[

]]></Span><Span style="Normal"><![CDATA[IMPORT AosOut, AosModules, AosCommands, AosIO, AosFS;]]></Span><Span style="AdHoc Oberon 10 2 0 808080FF 00000000"><![CDATA[

]]></Span><Span style="Normal"><![CDATA[VAR error: ARRAY 64 OF CHAR;

TYPE
	]]></Span><Span style="Comment"><![CDATA[(* object which calls the passed Command 'cmd'  with parameters 'par' in a separate process/thread *)]]></Span><Span style="Normal"><![CDATA[
	]]></Span><Span style="Bold"><![CDATA[BackCmd* = OBJECT]]></Span><Span style="Normal"><![CDATA[
	VAR cmd: AosModules.CommandParProc; par: PTR;

		]]></Span><Span style="Bold"><![CDATA[PROCEDURE &Init(cmd: AosModules.CommandParProc; par: PTR);]]></Span><Span style="Normal"><![CDATA[
		BEGIN
			SELF.cmd := cmd; SELF.par := par
		END Init;

	BEGIN {]]></Span><Span style="Lock"><![CDATA[ACTIVE]]></Span><Span style="Normal"><![CDATA[}
		par := cmd(par)
	END BackCmd;

]]></Span><Span style="Comment"><![CDATA[(* default result: zero *)]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE ReadInt* (par : PTR) : LONGINT;
]]></Span><Span style="Normal"><![CDATA[VAR
	parameters : AosCommands.Parameters;
	reader : AosIO.StringReader;
	res : LONGINT;
BEGIN
	parameters := par (AosCommands.Parameters);
	NEW(reader, LEN(parameters.str^)); reader.Set(parameters.str^); 
	reader.SkipWhitespace;
	reader.Int(res, FALSE);
	RETURN res;
END ReadInt;

]]></Span><Span style="Comment"><![CDATA[(* default result: zero *)]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE ReadNthInt* (par : PTR; n : LONGINT) : LONGINT;
]]></Span><Span style="Normal"><![CDATA[VAR
	parameters : AosCommands.Parameters;
	reader : AosIO.StringReader;
	res, i: LONGINT;
BEGIN
	parameters := par (AosCommands.Parameters);
	NEW(reader, LEN(parameters.str^)); reader.Set(parameters.str^);
	FOR i := 1 TO n DO
		reader.SkipWhitespace;
		reader.Int(res, FALSE);
	END;
	RETURN res;
END ReadNthInt;

]]></Span><Span style="Comment"><![CDATA[(*
 *	1. Unloads all modules which rely on BimboShell
 *	2. Restarts the BimboShell (currently with QBIC.Shell)
 *	]]></Span><Span style="Stupid"><![CDATA[must not be run in the same thread as the shell]]></Span><Span style="Comment"><![CDATA[
 *
 *	usage: UpdateShell [V24Off][ pars]
 *	V24Off : integer, V24Off>=0 -> AosOut.V24Off is called and at the end AosOut.V24On
 *	ignores any further commandline arguments (pars)
 *
 *	]]></Span><Span style="Stupid"><![CDATA[IMPORTANT: To run successfully "QBIC.Oba" and "BimboShell.Oba" must be present in RAM]]></Span><Span style="Comment"><![CDATA[
 *	]]></Span><Span style="Stupid"><![CDATA[A check to prevent errors on load because of missing Modules is not yet implemented]]></Span><Span style="Comment"><![CDATA[
 *)]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE UpdateShell (par : PTR): PTR;]]></Span><Span style="Normal"><![CDATA[
VAR mod: AosModules.Module; res: LONGINT;
BEGIN
	IF ReadInt(par)>=0 THEN
		AosOut.V24Off;
	END;
	
]]></Span><Span style="Comment"><![CDATA[	(* unload module QBIC *)]]></Span><Span style="Normal"><![CDATA[
	res := UnloadMod("QBIC");
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[IF res # 0 THEN
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[	IF ReadInt(par)>=0 THEN
			AosOut.V24On;
		END;
]]></Span><Span style="Debug"><![CDATA[		]]></Span><Span style="Normal"><![CDATA[RETURN NIL;
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[END;
]]></Span><Span style="Comment"><![CDATA[
	(* unload module BimboShell *)]]></Span><Span style="Normal"><![CDATA[
	res := UnloadMod("BimboShell");
	IF res # 0 THEN
		]]></Span><Span style="Debug"><![CDATA[ AosOut.String("Unable to unload BimboShell module, restarting the shell ..."); AosOut.Ln;
	]]></Span><Span style="Normal"><![CDATA[END;
	
	]]></Span><Span style="Comment"><![CDATA[(* reload module QBIC *)]]></Span><Span style="Normal"><![CDATA[
	res := LoadMod("QBIC");
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[IF (res # 0) OR (error # "") THEN
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[	RETURN NIL
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[ELSE
]]></Span><Span style="Debug"><![CDATA[		AosOut.String("[Test]UpdateShell: AosCommands.Activate('QBIC.Shell', NIL, {AosCommands.Wait}, res, error) ... "); AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
		AosCommands.Activate("]]></Span><Span style="Bold"><![CDATA[QBIC.Shell]]></Span><Span style="Normal"><![CDATA[", NIL, {AosCommands.Wait}, res, error);
		]]></Span><Span style="Debug"><![CDATA[AosOut.String("[Test] Activate(QBIC.Shell) res="); AosOut.Int(res, 0); 	AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Debug"><![CDATA[IF error # "" THEN AosOut.String(error); AosOut.Ln; END;]]></Span><Span style="Normal"><![CDATA[
		IF ReadInt(par)>=0 THEN
			AosOut.V24On; ]]></Span><Span style="Comment"><![CDATA[(* print output to shell and not only to log *)]]></Span><Span style="Normal"><![CDATA[
		END;
	END;
	
	RETURN NIL
END UpdateShell;
]]></Span><Span style="Bold"><![CDATA[
]]></Span><Span style="Comment"><![CDATA[(***** update the shell *****************
 * 	usage: RunUpdate [V24Off [blocking]]
 *	 V24Off : integer see UpdateShell
 *	 blocking : integer, blocking # 0 -> blocks until UpdateShell returns, blocking = 0 -> returns immediately
 *)]]></Span><Span style="Bold"><![CDATA[
PROCEDURE RunUpdate* (par: PTR): PTR;]]></Span><Span style="Normal"><![CDATA[
VAR back: BackCmd;
BEGIN
	IF ReadNthInt(par, 2) # 0 THEN
		]]></Span><Span style="Comment"><![CDATA[(* calls UpdateShell and blocks until it returns *)]]></Span><Span style="Normal"><![CDATA[
		par := UpdateShell(par);
	ELSE
		]]></Span><Span style="Comment"><![CDATA[(* calls UpdateShell as a separate process/thread and returns immediately *)]]></Span><Span style="Normal"><![CDATA[
		NEW(back, UpdateShell, par);
	END;
	
	RETURN NIL
END RunUpdate;

]]></Span><Span style="Comment"><![CDATA[(** Load the specified module *)
]]></Span><Span style="Bold"><![CDATA[PROCEDURE LoadMod (name: ARRAY OF CHAR): LONGINT;]]></Span><Span style="Normal"><![CDATA[ ]]></Span><Span style="Comment"><![CDATA[(** modulename ~ *)]]></Span><Span style="Normal"><![CDATA[
VAR mod: AosModules.Module; res: LONGINT;
BEGIN
	]]></Span><Span style="Debug"><![CDATA[AosOut.String("Load module "); AosOut.String(name); AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
	mod := AosModules.ThisModule(name, res, error);
	IF res = 0 THEN
	]]></Span><Span style="Debug"><![CDATA[	AosOut.String(" Module "); AosOut.String(name); AosOut.String(" loaded.");]]></Span><Span style="Normal"><![CDATA[
	ELSE
		]]></Span><Span style="Debug"><![CDATA[AosOut.String(" failed to load module "); AosOut.String(name); AosOut.String(" ("); AosOut.String(error); AosOut.Char(")");
]]></Span><Span style="Normal"><![CDATA[	END;
	]]></Span><Span style="Debug"><![CDATA[AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
	RETURN res;
END LoadMod;

]]></Span><Span style="Comment"><![CDATA[(** Unload the specified module *)]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE UnloadMod (name: ARRAY OF CHAR): LONGINT; ]]></Span><Span style="Comment"><![CDATA[(** modulename ~ *)]]></Span><Span style="Bold"><![CDATA[
]]></Span><Span style="Normal"><![CDATA[VAR  res: LONGINT;
BEGIN
	]]></Span><Span style="Debug"><![CDATA[AosOut.String("Free module "); AosOut.String(name); AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
	AosModules.FreeModule(name, res, error);
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[IF res = 0 THEN]]></Span><Span style="Debug"><![CDATA[
		AosOut.String(" Module "); AosOut.String(name); AosOut.String(" freed.");
	]]></Span><Span style="Normal"><![CDATA[ELSE	]]></Span><Span style="Debug"><![CDATA[
		AosOut.String(" failed to free module "); AosOut.String(name); AosOut.String(" ("); AosOut.String(error); AosOut.Char(")");
]]></Span><Span style="Normal"><![CDATA[	END;
]]></Span><Span style="Debug"><![CDATA[	AosOut.Ln;
]]></Span><Span style="Normal"><![CDATA[	RETURN res;
END UnloadMod;

]]></Span><Span style="Comment"><![CDATA[(** Load the specified module *) (* copied from QBIC.QBIC.Mod *)
]]></Span><Span style="Bold"><![CDATA[PROCEDURE ThisMod*(par: PTR): PTR;]]></Span><Span style="Normal"><![CDATA[ ]]></Span><Span style="Comment"><![CDATA[(** modulename ~ *)]]></Span><Span style="Normal"><![CDATA[
VAR mod: AosModules.Module; name: AosFS.FileName; res: LONGINT;
BEGIN
	GetName(par, name);
	]]></Span><Span style="Debug"><![CDATA[AosOut.String("Load module "); AosOut.String(name);]]></Span><Span style="Normal"><![CDATA[
	mod := AosModules.ThisModule(name, res, error);
	IF res = 0 THEN
	]]></Span><Span style="Debug"><![CDATA[	AosOut.String(" Module "); AosOut.String(name); AosOut.String(" loaded.");]]></Span><Span style="Normal"><![CDATA[
	ELSE
		]]></Span><Span style="Debug"><![CDATA[AosOut.String(" failed to load module ") ;AosOut.String(name); AosOut.String(" ("); AosOut.String(error); AosOut.Char(")");
]]></Span><Span style="Normal"><![CDATA[	END;
	]]></Span><Span style="Debug"><![CDATA[AosOut.Ln;]]></Span><Span style="Normal"><![CDATA[
	RETURN NIL
END ThisMod;

]]></Span><Span style="Comment"><![CDATA[(** Unload the specified module *) (* copied from QBIC.QBIC.Mod *)]]></Span><Span style="Normal"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE FreeMod*(par: PTR): PTR; ]]></Span><Span style="Comment"><![CDATA[(** modulename ~ *)]]></Span><Span style="Bold"><![CDATA[
]]></Span><Span style="Normal"><![CDATA[VAR name: AosFS.FileName; res: LONGINT;
BEGIN
	GetName(par, name);
	]]></Span><Span style="Debug"><![CDATA[AosOut.String("Free module "); AosOut.String(name);]]></Span><Span style="Normal"><![CDATA[
	AosModules.FreeModule(name, res, error);
]]></Span><Span style="Debug"><![CDATA[	]]></Span><Span style="Normal"><![CDATA[IF res = 0 THEN]]></Span><Span style="Debug"><![CDATA[
		AosOut.String(" Module "); AosOut.String(name); AosOut.String(" freed.");
	]]></Span><Span style="Normal"><![CDATA[ELSE	]]></Span><Span style="Debug"><![CDATA[
		AosOut.String(" failed to free module ") ;AosOut.String(name); AosOut.String(" ("); AosOut.String(error); AosOut.Char(")");
]]></Span><Span style="Normal"><![CDATA[	END;
]]></Span><Span style="Debug"><![CDATA[	AosOut.Ln;
]]></Span><Span style="Normal"><![CDATA[	RETURN NIL
END FreeMod;

]]></Span><Span style="Comment"><![CDATA[(* copied from QBIC.QBIC.Mod, needed for FreeMod and ThisModd *)]]></Span><Span style="AdHoc Oberon 12 0 0 000000FF 00000000"><![CDATA[
]]></Span><Span style="Bold"><![CDATA[PROCEDURE GetName(par: PTR; VAR name: ARRAY OF CHAR);]]></Span><Span style="Normal"><![CDATA[
VAR p: AosCommands.Parameters; R: AosIO.StringReader;
BEGIN
	p := par(AosCommands.Parameters);
	NEW(R, LEN(p.str)); R.Set(p.str^);
	R.SkipWhitespace(); R.String(name)
END GetName;

END ShellTools.]]></Span>

</Text>
