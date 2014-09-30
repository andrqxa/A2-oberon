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

(* input / output ports *)
PROCEDURE OutChar- (port: SIZE; value: CHAR);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutChar;

PROCEDURE OutByte- (port: SIZE; value: SIZE);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutByte;

PROCEDURE OutSet- (port: SIZE; value: SET);
CODE
	MOV	AL, [EBP + value]
	MOV	DX, [EBP + port]
	OUT	DX, AL
END OutSet;

PROCEDURE InChar- (port: SIZE): CHAR;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
END InChar;

PROCEDURE InByte- (port: SIZE): SIZE;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
END InByte;

PROCEDURE InSet- (port: SIZE): SET;
CODE
	MOV	DX, [EBP + port]
	IN		AL, DX
	MOVZX	EAX, AL
END InSet;

END CPU.