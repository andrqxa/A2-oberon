(* Runtime support for CPU internals *)
(* Copyright (C) Florian Negele *)

MODULE CPU;

CONST StackSize* = 8192;
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

(* cpu control *)
PROCEDURE {NORETURN} Reset-;
CODE
	CLI
	PUSH	0
	PUSH	0
	LIDT	[ESP]
	INT3
END Reset;

PROCEDURE {NORETURN} Halt-;
CODE
	CLI
end:
	HLT
	JMP	end
END Halt;

END CPU.