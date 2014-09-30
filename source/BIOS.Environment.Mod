(* Runtime environment for BIOS *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT CPU, Activities;

CONST Running = 0; ShuttingDown = 1; Rebooting = 2;

VAR status* := 0: WORD;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Activities.TerminateCurrentActivity;
END Abort;

PROCEDURE {NORETURN} Exit- (status: WORD);
VAR index: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF status = Rebooting THEN CPU.Reset ELSE CPU.Halt END;
END Exit;

PROCEDURE Clock- (): LONGINT;
END Clock;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN 0;
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	HALT (1234);
END Deallocate;

PROCEDURE GetConfig- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	result[0] := 0X;
END GetConfig;

PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

END Environment.

