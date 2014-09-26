(* Runtime support for CPU internals *)

MODULE CPU;

CONST StackSize* = 2048;
CONST Quantum* = 1000000;
CONST CacheLineSize* = 64;
CONST StackDisplacement* = 0;

PROCEDURE Backoff-;
CODE
	MOV	EBX, 80000H
loop:
	DEC	EBX
	JNZ		loop
END Backoff;

END CPU.