(* Generic runtime environment *)

MODULE Environment;

IMPORT Activities, Kernel32;

VAR status* := 0: WORD;
VAR heap: Kernel32.HANDLE;
VAR stdout: Kernel32.HANDLE;

PROCEDURE {NORETURN} Abort-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Kernel32.ExitProcess (1);
END Abort;

PROCEDURE {NORETURN} Exit- (status: WORD);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Kernel32.ExitProcess (status);
END Exit;

PROCEDURE Allocate- (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN Kernel32.HeapAlloc(heap, Kernel32.HeapZeroMemory, size);
END Allocate;

PROCEDURE Deallocate- (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.HeapFree(heap, 0, address) # 0);
END Deallocate;

PROCEDURE Write- (character: CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (Kernel32.WriteFile (stdout, ADDRESS OF character, 1, NIL, NIL) # 0);
END Write;

PROCEDURE Initialize-;
VAR trace EXTERN "Trace.Char": PROCEDURE (character: CHAR);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	heap := Kernel32.GetProcessHeap();
	stdout := Kernel32.GetStdHandle(Kernel32.STDOutput);
	trace := Write;
END Initialize;

PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

END Environment.
