(* Automatic memory management *)

(** The {{{GarbageCollector}}} module provides an automatic memory management for pointers allocated using the {{{NEW}}} statement. *)
(** It implements a concurrent and interruptible mark and sweep garbage collection. *)
MODULE GarbageCollector;

(** Performs a complete garbage collection cycle by marking the object graph and disposing all unreachable objects. *)
(** Garbage can be collected concurrently if necessary. *)
PROCEDURE Collect*;
END Collect;

(** Initializes the module and its resources. *)
PROCEDURE Initialize-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Initialize;

(** Terminates the module and disposes its resources and all remaining pointers that have been registered using the {{{[[GarbageCollector.Watch]]}}} procedure. *)
PROCEDURE Terminate-;
BEGIN {UNCOOPERATIVE, UNCHECKED}
END Terminate;

END GarbageCollector.
