(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE FileDir IN Oberon;	(* pjm *)
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos file directory"; *)

IMPORT Files IN A2;

TYPE
	FileName* = Files.FileName;

	EntryHandler* = PROCEDURE (name: ARRAY OF CHAR; time, date, size: SIGNED32; VAR continue: BOOLEAN);

VAR
	PathChar*: CHAR;

PROCEDURE Enumerate*(mask: ARRAY OF CHAR; detail: BOOLEAN; proc: EntryHandler);
VAR enum: Files.Enumerator; time, date: SIGNED32; size: Files.Size; continue: BOOLEAN; name: FileName; flags: SET;
	fname, pname: FileName;
BEGIN
	NEW(enum);
	IF detail THEN enum.Open(mask, {Files.EnumSize, Files.EnumTime})
	ELSE enum.Open(mask, {})
	END;
	continue := TRUE;
	WHILE continue & enum.GetEntry(name, flags, time, date, size) DO
		Files.SplitPath(name,pname,fname);
		proc(fname, time, date, size(SIGNED32), continue)
	END;
	enum.Close
END Enumerate;

BEGIN
	PathChar := "/"
END FileDir.
