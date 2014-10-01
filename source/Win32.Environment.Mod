(* Runtime environment for Windows *)
(* Copyright (C) Florian Negele *)

MODULE Environment;

IMPORT Activities, Kernel32, Trace;

CONST DefaultConfigFile = "aos.ini";
CONST UserConfigFile = "myaos.ini";

VAR status* := 0: WORD;
VAR heap: Kernel32.HANDLE;
VAR stdin, stdout: Kernel32.HANDLE;
VAR defaultConfigFile, userConfigFile, traceName: ARRAY Kernel32.MaxPath OF CHAR;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Activities.TerminateCurrentActivity;
END Abort;

PROCEDURE {NORETURN} Exit- (status: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RemoveTraceFile;
	Kernel32.ExitProcess (status);
END Exit;

PROCEDURE Clock- (): LONGINT;
BEGIN RETURN Kernel32.GetTickCount ();
END Clock;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN Kernel32.HeapAlloc(heap, Kernel32.HeapZeroMemory, size);
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.HeapFree(heap, 0, address) # 0);
END Deallocate;

PROCEDURE GetString- (CONST name: ARRAY OF CHAR; VAR result: ARRAY OF CHAR);
CONST ConfigKey = "Configuration";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF Kernel32.GetPrivateProfileString (ConfigKey, name, "", result, LEN (result), userConfigFile) # 0 THEN
	ELSIF Kernel32.GetPrivateProfileString (ConfigKey, name, "", result, LEN (result), defaultConfigFile) # 0 THEN
	ELSE result[0] := 0X;
	END;
END GetString;

PROCEDURE WriteChar (char: CHAR);
VAR written: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.WriteFile (stdout, char ,1, written, NIL) # 0);
END WriteChar;

PROCEDURE SetConsoleColor (color: SHORTINT);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.SetConsoleTextAttribute (stdout, color) # 0);
END SetConsoleColor;

PROCEDURE OutputChar (char: CHAR);
VAR trace: ARRAY 2 OF CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	trace[0] := char; Kernel32.OutputString (trace);
END OutputChar;

PROCEDURE SetupTraceName(VAR traceName: ARRAY OF CHAR);
VAR
	ext: ARRAY 256 OF CHAR;
	extPos,i,j: LONGINT;
	systemTime: Kernel32.SystemTime;
	ch: CHAR;

	PROCEDURE AppendDecimals(int: LONGINT; from, to: LONGINT);
	VAR ten: LONGINT;
	BEGIN {UNCOOPERATIVE, UNCHECKED}
		WHILE to >= from DO
			traceName[i] := CHR(ORD("0")+ int DIV to MOD 10); INC(i);
			to := to DIV 10;
		END;
	END AppendDecimals;

BEGIN {UNCOOPERATIVE, UNCHECKED}
	Kernel32.GetLocalTime(systemTime);

	extPos := 0;
	REPEAT
		ch := traceName[i];

		IF ch = "." THEN j := 0; extPos := i END;

		ext[j] := ch;
		INC(j); INC(i);
	UNTIL ch = 0X;

	IF extPos > 0 THEN i := extPos END;
	ext[j] := 0X;

	AppendDecimals(systemTime.wYear,1,1000);
	AppendDecimals(systemTime.wMonth,1,10);
	AppendDecimals(systemTime.wDay,1,10);
	traceName[i] := "_"; INC(i);
	AppendDecimals(systemTime.wHour,1,10);
	AppendDecimals(systemTime.wMinute,1,10);
	AppendDecimals(systemTime.wSecond,1,10);
	traceName[i] := "_"; INC(i);
	AppendDecimals(systemTime.wMilliseconds,10,100);
	j := 0;
	REPEAT
		ch := ext[j];
		traceName[i] := ch;
		INC(i); INC(j);
	UNTIL ch = 0X;

END SetupTraceName;

PROCEDURE RemoveTraceFile;
VAR res: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF traceName[0] # 0X THEN
		Trace.String("removing "); Trace.String(traceName); Trace.Ln;
		Trace.Char := OutputChar;
		res := Kernel32.CloseHandle(stdout);
		IF res = 0 THEN
			res := Kernel32.GetLastError();
			Trace.String("could not close "); Trace.String("; res = "); Trace.Int(res,1); Trace.Ln;
		END;
		res := Kernel32.DeleteFile(traceName);
		IF res = 0 THEN
			res := Kernel32.GetLastError();
			Trace.String("could not delete "); Trace.String(traceName); Trace.String("; res = "); Trace.Int(res,1); Trace.Ln;
		END;

	END;
END RemoveTraceFile;

PROCEDURE ToExecutablePath(CONST name: ARRAY OF CHAR; VAR fullName: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Kernel32.GetModuleFileName (Kernel32.hInstance, fullName, LEN (fullName));
	j := -1; i := 0;
	WHILE fullName[i] # 0X DO
		IF fullName[i] = '\' THEN j := i END;
		INC( i )
	END;
	i := 0; INC(j);
	WHILE name[i] # 0X DO
		fullName[j] := name[i]; INC(i); INC(j);
	END;
	fullName[j] := 0X;
END ToExecutablePath;

PROCEDURE Initialize-;
VAR trace: ARRAY 32 OF CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	heap := Kernel32.GetProcessHeap();
	stdout := Kernel32.GetStdHandle(Kernel32.STDOutput);

	ToExecutablePath(DefaultConfigFile, defaultConfigFile);
	ToExecutablePath(UserConfigFile, userConfigFile);

	Trace.Init;
	traceName[0] := 0X;
	Trace.Char := OutputChar;
	GetString("Trace",trace);
	IF trace = "File" THEN
		traceName := "SystemTrace.txt";
		SetupTraceName(traceName);
		Trace.String("trace -> file "); Trace.String(traceName); Trace.Ln;
		stdout := Kernel32.CreateFile(traceName, {Kernel32.GenericWrite}, {Kernel32.FileShareRead}, NIL, Kernel32.CreateAlways, {Kernel32.FileAttributeNormal}, Kernel32.NULL);
		Kernel32.GetFullPathName(traceName, LEN(traceName), traceName, NIL);
		Trace.Char := WriteChar;
	ELSIF trace = "Console" THEN
		Trace.String("trace -> console"); Trace.Ln;
		Kernel32.AllocConsole ();
		stdin:= Kernel32.GetStdHandle (Kernel32.STDInput);
		stdout := Kernel32.GetStdHandle (Kernel32.STDOutput);
		Trace.Char := WriteChar; Trace.Color := SetConsoleColor;
	END;
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

END Environment.
