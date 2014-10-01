(* Generic runtime support *)
(* Copyright (C) Florian Negele *)

MODULE Runtime;

IMPORT SYSTEM, Trace;

(* compare strings,
	returns 0 if strings are equal,
	returns +1 if left is lexicographic greater than right,
	returns -1 if left is lexicographics smaller than right
	traps if src or destination is not 0X terminated and comparison is not finished
*)
PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SHORTINT;
VAR i: LONGINT; res: SHORTINT; l,r: CHAR;
BEGIN {UNCOOPERATIVE}
	i := 0; res := 0;
	LOOP
		l := left[i]; 		(* index check included *)
		r := right[i];		(* index check included *)
		IF (res = 0) THEN
			IF (l > r) THEN
				res := 1; EXIT
			ELSIF (l<r) THEN
				res := -1; EXIT
			ELSIF l=0X THEN
				EXIT
			END;
		END;
		INC(i);
	END;
	RETURN res
END CompareString;

(* copy string from src to dest, emits trap if not 0X terminated or destination too short *)
PROCEDURE CopyString*(VAR dest: ARRAY OF CHAR; CONST src: ARRAY OF CHAR);
VAR i: LONGINT; ch :CHAR; l1,l2: LONGINT;
BEGIN {UNCOOPERATIVE}
	(*
	i := 0;
	REPEAT
		ch := src[i];		(* index check included *)
		dest[i] := ch;	(* index check included *)
		INC(i);
	UNTIL ch=0X;
	*)

	(*! currently implemented: old PACO semantics *)
	l1 := LEN(dest);
	l2 := LEN(src);
	IF l2 < l1 THEN l1 := l2 END;
	SYSTEM.MOVE(ADDRESSOF(src[0]),ADDRESSOF(dest[0]),l1);
	dest[l1-1] := 0X; (* this implies that COPY assumes a string *)
END CopyString;

PROCEDURE EnsureAllocatedStack*(size: SIZE);
VAR i: ADDRESS; temp: ADDRESS;
BEGIN {UNCOOPERATIVE}
	FOR i := 0 TO size BY 4096 DO
		SYSTEM.GET(ADDRESSOF(i)-i,temp);
		(*
		SYSTEM.PUT(ADDRESSOF(val)-i,0);
		*)
	END;
(*
CODE{SYSTEM.i386}
	MOV EAX, [EBP+size]
	SHR EAX,12 ; divide by 4096
	MOV ECX,-4
start:
	MOV EDX,[EBP+ECX]
	SUB ECX,4096
	TST EAX
	DEC EAX
	JNZ start
*)
END EnsureAllocatedStack;

(** This procedure aborts the program and prints the number of the trap that caused the program to fail. *)
(** The compiler calls this procedure for HALT statements or for unsatisfied ASSERT statements. *)
PROCEDURE {NORETURN} Trap- (number: SIZE);
PROCEDURE Abort EXTERN "Environment.Abort";
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Trace.String ("trap "); Trace.Int (number, 0); Trace.Ln;
	Abort;
END Trap;

(** This procedure acquires memory and returns the address to the first byte or NIL if the allocation fails. *)
(** The compiler implements all NEW statements with a call to this procedure. *)
PROCEDURE New- (size: SIZE): ADDRESS;
PROCEDURE Allocate EXTERN "Environment.Allocate" (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN Allocate (size);
END New;

(** This procedure releases memory that was previously acquired by a call to the [[Runtime.New]] procedure. *)
(** The compiler implements DISPOSE statements on types marked as disposable with a call to this procedure. *)
PROCEDURE Dispose- (VAR pointer {UNTRACED}: OBJECT);
PROCEDURE Deallocate EXTERN "Environment.Deallocate" (address: ADDRESS);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (pointer # NIL);
(*
	Deallocate (pointer);
*)
	pointer := NIL;
END Dispose;

BEGIN
	(*! assumed that modules = 0, implicit call of InsertModule *)
END Runtime.

Runtime.Obw