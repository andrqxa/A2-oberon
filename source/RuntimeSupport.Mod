(* Generic runtime support *)
(* Copyright (C) Florian Negele *)

MODULE RuntimeSupport;

IMPORT Environment, Trace;

(** This procedure aborts the program and prints the number of the trap that caused the program to fail. *)
(** The compiler calls this procedure for HALT statements or for unsatisfied ASSERT statements. *)
PROCEDURE {NORETURN} Trap-(number: SIZE);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	Trace.String ("trap: "); Trace.Int (number, 0); Trace.Ln;
	Environment.Abort;
END Trap;

(** This procedure acquires memory and returns the address to the first byte or NIL if the allocation fails. *)
(** The compiler implements all NEW statements with a call to this procedure. *)
PROCEDURE New- (size: SIZE): ADDRESS;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN Environment.Allocate (size);
END New;

(** This procedure releases memory that was previously acquired by a call to the [[Runtime.New]] procedure. *)
(** The compiler implements DISPOSE statements on types marked as disposable with a call to this procedure. *)
PROCEDURE Dispose- (VAR pointer {UNTRACED}: OBJECT);
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (pointer # NIL);
(*
	Environment.Deallocate (pointer);
*)
	pointer := NIL;
END Dispose;

END RuntimeSupport.