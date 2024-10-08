MODULE Builtins; (** AUTHOR "fof"; PURPOSE "Built-in functions for the Active Oberon Compiler"; *)
IMPORT SYSTEM;

VAR
	kernelModule-: ARRAY 32 OF ADDRESS;
	modules-: SIGNED32;

PROCEDURE InsertModule*(a: ADDRESS): BOOLEAN;
BEGIN {UNCOOPERATIVE}
	kernelModule[modules] := a;
	INC(modules);
	RETURN TRUE
END InsertModule;


PROCEDURE DivHA(l,r: SIGNED64): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; divides two signed 64-bit numbers and delivers the quotient
	;
	; In: [EBP+l+4]:[EBP+l+0] = dividend (l)
	; [EBP+r+4]:[EBP+r+0] = divisor (r)
	; Out: EDX:EAX = quotient of division
	MOV EDX, [EBP+l+4] 	    ; dividend_hi
	MOV EAX, [EBP+l+0] 		; dividend_lo
	MOV ECX, [EBP+r+4] 	    ; divisor_hi
	MOV EBX, [EBP+r+0] 	    ; divisor_lo
	MOV ESI, ECX 			; divisor_hi
	XOR ESI, EDX 			; divisor_hi ^ dividend_hi
	SAR ESI, 31 				; (quotient < 0) ? -1 : 0
	MOV EDI, EDX 			; dividend_hi
	SAR EDI, 31 				; (dividend < 0) ? -1 : 0
	XOR EAX, EDI 			; If (dividend < 0),
	XOR EDX, EDI 			; compute 1's complement of dividend.
	SUB EAX, EDI 			; If (dividend < 0),
	SBB EDX, EDI 			; compute 2's complement of dividend.
	MOV EDI, ECX 			; divisor_hi
	SAR EDI, 31 				; (divisor < 0) ? -1 : 0
	XOR EBX, EDI 			; If (divisor < 0),
	XOR ECX, EDI 			; compute 1's complement of divisor.
	SUB EBX, EDI 			; If (divisor < 0),
	SBB ECX, EDI 			; compute 2's complement of divisor.
	JNZ BIGDIVISOR 			; divisor > 2^32 - 1
	CMP EDX, EBX 			; Only one division needed (ECX = 0)?
	JAE TWODIVS 			; Need two divisions.
	DIV EBX 				; EAX = quotient_lo
	MOV EDX, ECX 			; EDX = quotient_hi = 0 (quotient in EDX:EAX)
	XOR EAX, ESI 			; If (quotient < 0),
	XOR EDX, ESI 			; compute 1's complement of result.
	SUB EAX, ESI 			; If (quotient < 0),
	SBB EDX, ESI 			; compute 2's complement of result.
	JMP DONE
	TWODIVS:
	MOV ECX, EAX 			; Save dividend_lo in ECX.
	MOV EAX, EDX 			; Get dividend_hi.
	XOR EDX, EDX 			; Zero-extend it into EDX:EAX.
	DIV EBX 				; QUOtient_hi in EAX
	XCHG EAX, ECX 			; ECX = quotient_hi, EAX = dividend_lo
	DIV EBX 				; EAX = quotient_lo
	MOV EDX, ECX 			; EDX = quotient_hi (quotient in EDX:EAX)
	JMP MAKESIGN 		; Make quotient signed.
	BIGDIVISOR:
	SUB ESP, 12 			; Create three local variables.
	MOV [ESP], EAX 		; dividend_lo
	MOV [ESP+4], EBX 		; divisor_lo
	MOV [ESP+8], EDX 		; dividend_hi
	MOV EDI, ECX 			; Save divisor_hi.
	SHR EDX, 1 				; Shift both
	RCR EAX, 1 				; divisor and
	ROR EDI, 1 				; and dividend
	RCR EBX, 1 				; right by 1 bit.
	BSR ECX, ECX 			; ECX = number of remaining shifts
	SHRD EBX, EDI, CL 		; Scale down divisor and
	SHRD EAX, EDX, CL 		; dividend such that divisor is
	SHR EDX, CL 				; less than 2^32 (that is, fits in EBX).
	ROL EDI, 1 				; Restore original divisor_hi.
	DIV EBX 				; COMpute quotient.
	MOV EBX, [ESP] 		; dividend_lo
	MOV ECX, EAX 			; Save quotient.
	IMUL EDI, EAX 			; quotient * divisor high word (low only)
	MUL DWORD [ESP+4] ; quotient * divisor low word
	ADD EDX, EDI 			; EDX:EAX = quotient * divisor
	SUB EBX, EAX 			; dividend_lo - (quot.*divisor)_lo
	MOV EAX, ECX 			; Get quotient.
	MOV ECX, [ESP+8] 		; dividend_hi
	SBB ECX, EDX 			; Subtract (divisor * quot.) from dividend
	SBB EAX, 0 				; Adjust quotient if remainder is negative.
	XOR EDX, EDX 			; Clear high word of quotient.
	ADD ESP, 12 			; Remove local variables.
	MAKESIGN:
	XOR EAX, ESI 			; If (quotient < 0),
	XOR EDX, ESI 			; compute 1's complement of result.
	SUB EAX, ESI 			; If (quotient < 0),
	SBB EDX, ESI 			; compute 2's complement of result.
	DONE:
	POP	ECX
END DivHA;

PROCEDURE DivH*(l,r: SIGNED64): SIGNED64;
VAR result: SIGNED64;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF l > 0 THEN RETURN DivHA(l,r)
	ELSIF l< 0 THEN
		result :=  -DivHA(-l,r);
		IF result * r # l THEN DEC(result) END; (* mathematical definition of DIV and MOD, to be optimized in DivHA *)
		RETURN result
	ELSE RETURN 0
	END;
END DivH;

PROCEDURE MulH*(l,r: SIGNED64): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; computes the low-order half of the product of its
	; arguments, two 64-bit integers.
	;
	; In: [EBP+l+4]:[EBP+l+0] = multiplicand (l)
	; [EBP+r+4]:[EBP+r+0] = multiplier (r)
	; Out: EDX:EAX = (multiplicand * multiplier) % 2^64
	; Destroys: EAX, ECX, EDX, EFlags
	MOV EDX, [EBP+r+4] 		; multiplier_hi
	MOV ECX, [EBP+l+4] 		; multiplicand_hi
	OR EDX,ECX 				; One operand >= 2^32?
	MOV EDX, [EBP+l+0] 		; multiplier_lo
	MOV EAX, [EBP+r+0] 		; multiplicand_lo
	JNZ twomul 				; Yes, need two multiplies.
	MUL EDX 					; multiplicand_lo * multiplier_lo
	JMP done 					; Done, return to caller.
	twomul:
	IMUL EDX, [EBP+r+4]		; p3_lo = multiplicand_hi * multiplier_lo
	IMUL ECX,EAX 			; p2_lo = multiplier_hi * multiplicand_lo
	ADD ECX, EDX 			; p2_lo + p3_lo
	MUL DWORD [EBP+l+0] 	; p1 = multiplicand_lo * multiplier_lo
	ADD EDX,ECX 			; p1 + p2_lo + p3_lo = result in EDX:EAX
	done:
	POP	ECX
END MulH;

PROCEDURE ModHA(l,r: SIGNED64): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	; DIVIDES TWO SIGNED 64-BIT NUMBERS AND RETURNS THE REMAINDER.
	;
	; IN: [EBP+l+4]:[EBP+l+0] = DIVIDEND (l)
	; [EBP+r+4]:[EBP+r+0] = DIVISOR (r)
	;
	; OUT: EDX:EAX = REMAINDER OF DIVISION
	;
	; DESTROYS: EAX, ECX, EDX, EFLAGS
	MOV EDX, [EBP+l+4]           	; DIVIDEND-HI
	MOV EAX, [EBP+l+0]            	; DIVIDEND-LO
	MOV ECX, [EBP+r+4]           	; DIVISOR-HI
	MOV EBX, [EBP+r+0]           	; DIVISOR-LO
	MOV ESI, EDX	                	; SIGN(REMAINDER) == SIGN(DIVIDEND)
	SAR ESI, 31 		               	; (REMAINDER < 0) ? -1 : 0
	MOV EDI, EDX	                	; DIVIDEND-HI
	SAR EDI, 31 	                	; (DIVIDEND < 0) ? -1 : 0
	XOR EAX, EDI	                	; IF (DIVIDEND < 0),
	XOR EDX, EDI	                	; COMPUTE 1'S COMPLEMENT OF DIVIDEND.
	SUB EAX, EDI	                	; IF (DIVIDEND < 0),
	SBB EDX, EDI	                	; COMPUTE 2'S COMPLEMENT OF DIVIDEND.
	MOV EDI, ECX	                	; DIVISOR-HI
	SAR EDI, 31 	                	; (DIVISOR < 0) ? -1 : 0
	XOR EBX, EDI	                	; IF (DIVISOR < 0),
	XOR ECX, EDI	                	; COMPUTE 1'S COMPLEMENT OF DIVISOR.
	SUB EBX, EDI	                	; IF (DIVISOR < 0),
	SBB ECX, EDI	                	; COMPUTE 2'S COMPLEMENT OF DIVISOR.
	JNZ SRBIGDIVISOR          	; DIVISOR > 2^32 - 1
	CMP EDX, EBX				; ONLY ONE DIVISION NEEDED (ECX = 0)?
	JAE SRTWODIVS             		; NO, NEED TWO DIVISIONS.
	DIV EBX      		               	; EAX = QUOTIENT_LO
	MOV EAX, EDX                	; EAX = REMAINDER_LO
	MOV EDX, ECX                	; EDX = REMAINDER_LO = 0
	XOR EAX, ESI                		; IF (REMAINDER < 0),
	XOR EDX, ESI                		; COMPUTE 1'S COMPLEMENT OF RESULT.
	SUB EAX, ESI                		; IF (REMAINDER < 0),
	SBB EDX, ESI                		; COMPUTE 2'S COMPLEMENT OF RESULT.
	JMP done                 			; DONE, RETURN TO CALLER.
	SRTWODIVS:
	MOV ECX, EAX                	; SAVE DIVIDEND_LO IN ECX.
	MOV EAX, EDX                	; GET DIVIDEND_HI.
	XOR EDX, EDX                	; ZERO-EXTEND IT INTO EDX:EAX.
	DIV EBX                     		; EAX = QUOTIENT_HI, EDX = INTERMEDIATE REMAINDER
	MOV EAX, ECX                	; EAX = DIVIDEND_LO
	DIV EBX                     		; EAX = QUOTIENT_LO
	MOV EAX, EDX                	; REMAINDER_LO
	XOR EDX, EDX                	; REMAINDER_HI = 0
	JMP SRMAKESIGN 			;MAKE REMAINDER SIGNED.
	SRBIGDIVISOR:
	SUB ESP, 16 			 	;CREATE THREE LOCAL VARIABLES.
	MOV [ESP], EAX 			; DIVIDEND_LO
	MOV [ESP+4], EBX 			; DIVISOR_LO
	MOV [ESP+8], EDX 			; DIVIDEND_HI
	MOV [ESP+12], ECX 			; DIVISOR_HI
	MOV EDI, ECX 				; SAVE DIVISOR_HI.
	SHR EDX, 1 					; SHIFT BOTH
	RCR EAX, 1 					; DIVISOR AND
	ROR EDI, 1 					; AND DIVIDEND
	RCR EBX, 1 					; RIGHT BY 1 BIT.
	BSR ECX, ECX 				; ECX = NUMBER OF REMAINING SHIFTS
	SHRD EBX, EDI, CL 			; SCALE DOWN DIVISOR AND
	SHRD EAX, EDX, CL 			; DIVIDEND SUCH THAT DIVISOR IS
	SHR EDX, CL 				; LESS THAN 2^32 (THAT IS, FITS IN EBX).
	ROL EDI, 1 					; RESTORE ORIGINAL DIVISOR_HI.
	DIV EBX 					; COMPUTE QUOTIENT.
	MOV EBX, [ESP] 			; DIVIDEND_LO
	MOV ECX, EAX 				; SAVE QUOTIENT.
	IMUL EDI, EAX 				; QUOTIENT * DIVISOR HIGH INTEGER (LOW ONLY)
	MUL DWORD [ESP+4] 		; QUOTIENT * DIVISOR LOW INTEGER
	ADD EDX, EDI 				; EDX:EAX = QUOTIENT * DIVISOR
	SUB EBX, EAX 				; DIVIDEND_LO - (QUOT.*DIVISOR)_LO
	MOV ECX, [ESP+8] 			; DIVIDEND_HI
	SBB ECX, EDX 				; SUBTRACT DIVISOR * QUOT. FROM DIVIDEND.
	SBB EAX, EAX 				; REMAINDER < 0 ? 0XFFFFFFFF : 0
	MOV EDX, [ESP+12] 		; DIVISOR_HI
	AND EDX, EAX 				; REMAINDER < 0 ? DIVISOR_HI : 0
	AND EAX, [ESP+4] 			; REMAINDER < 0 ? DIVISOR_LO : 0
	ADD EAX, EBX 				; REMAINDER_LO
	ADD EDX, ECX 				; REMAINDER_HI
	ADD ESP, 16 				; REMOVE LOCAL VARIABLES.
	SRMAKESIGN:
	XOR EAX, ESI 				; IF (REMAINDER < 0),
	XOR EDX, ESI 				; COMPUTE 1'S COMPLEMENT OF RESULT.
	SUB EAX, ESI 				; IF (REMAINDER < 0),
	SBB EDX, ESI 				; COMPUTE 2'S COMPLEMENT OF RESULT.
	done:
	POP	ECX
END ModHA;

PROCEDURE ModH*(l,r: SIGNED64): SIGNED64;
VAR res: SIGNED64;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	res := ModHA(l,r);
	IF res < 0 THEN INC(res,r) END;
	RETURN res
END ModH;

PROCEDURE DivU64*(l,r: UNSIGNED64): UNSIGNED64;
CODE{SYSTEM.i386}
	; taken from "Software Optimization Guide for AMD64 Processors"
	; divides two unsigned 64-bit integers and returns the quotient.
	;
	; In: [EBP+l+4]:[EBP+l+0] = dividend (l)
	; [EBP+r+4]:[EBP+r+0] = divisor (r)
	; Out: EDX:EAX = quotient of division
	PUSH ECX

	MOV EDX, [EBP+l+4] 	    ; dividend_hi
	MOV EAX, [EBP+l+0] 		; dividend_lo
	MOV ECX, [EBP+r+4] 	    ; divisor_hi
	MOV EBX, [EBP+r+0] 	    ; divisor_lo

	TEST ECX, ECX ; divisor > (2^32 – 1)?
	JNZ BIGDIVISOR ; Yes, divisor > 2^32 – 1.
	CMP EDX, EBX ; Only one division needed (ECX = 0)?
	JAE TWODIVS ; Need two divisions.
	DIV EBX ; EAX = quotient_lo
	MOV EDX, ECX ; EDX = quotient_hi = 0 (quotient in EDX:EAX)
	JMP DONE

TWODIVS:
	MOV ECX, EAX ; Save dividend_lo in ECX.
	MOV EAX, EDX ; Get dividend_hi.
	XOR EDX, EDX ; Zero-extend it into EDX:EAX.
	DIV EBX ; quotient_hi in EAX
	XCHG EAX, ECX ; ECX = quotient_hi, EAX = dividend_lo
	DIV EBX ; EAX = quotient_lo
	MOV EDX, ECX ; EDX = quotient_hi (quotient in EDX:EAX)
	JMP DONE

BIGDIVISOR:
	MOV EDI, ECX ; Save divisor_hi.
	SHR EDX, 1 ; Shift both divisor and dividend right
	RCR EAX, 1 ; by 1 bit.
	ROR EDI, 1
	RCR EBX, 1
	BSR ECX, ECX ; ECX = number of remaining shifts
	SHRD EBX, EDI, CL ; Scale down divisor and dividend
	SHRD EAX, EDX, CL ; such that divisor is less than
	SHR EDX, CL ; 2^32 (that is, it fits in EBX).
	ROL EDI, 1 ; Restore original divisor_hi.
	DIV EBX ; Compute quotient.
	MOV EBX, [EBP+l+0] ; dividend_lo
	MOV ECX, EAX ; Save quotient.
	IMUL EDI, EAX ; quotient * divisor high word (low only)
	MUL [EBP+r+0] ; quotient * divisor low word
	ADD EDX, EDI ; EDX:EAX = quotient * divisor
	SUB EBX, EAX ; dividend_lo – (quot.*divisor)_lo
	MOV EAX, ECX ; Get quotient.
	MOV ECX, [EBP+l+4] ; dividend_hi
	SBB ECX, EDX ; Subtract (divisor * quot.) from dividend.
	SBB EAX, 0 ; Adjust quotient if remainder negative.
	XOR EDX, EDX ; Clear high word of quot. (EAX<=FFFFFFFFh).

DONE:
	POP ECX
END DivU64;

PROCEDURE ModU64*(l, r: UNSIGNED64): UNSIGNED64;
CODE{SYSTEM.i386}
	; taken from "Software Optimization Guide for AMD64 Processors"
	; divides two unsigned 64-bit integers and returns the remainder.
	;
	; In: [EBP+l+4]:[EBP+l+0] = dividend (l)
	; [EBP+r+4]:[EBP+r+0] = divisor (r)
	;
	; Out: EDX:EAX = remainder of division
	;
	PUSH ECX

	MOV EDX, [EBP+l+4]           	; dividend-hi
	MOV EAX, [EBP+l+0]            	; dividend-lo
	MOV ECX, [EBP+r+4]           	; divisor-hi
	MOV EBX, [EBP+r+0]           	; divisor-lo

	TEST ECX, ECX ; divisor > 2^32 - 1?
	JNZ RBIGDIVISOR ; Yes, divisor > 32^32 - 1.
	CMP EDX, EBX ; Only one division needed (ECX = 0)?
	JAE RTWODIVS ; Need two divisions.
	DIV EBX ; EAX = quotient_lo
	MOV EAX, EDX ; EAX = remainder_lo
	MOV EDX, ECX ; EDX = remainder_hi = 0
	JMP DONE

RTWODIVS:
	MOV ECX, EAX ; Save dividend_lo in ECX.
	MOV EAX, EDX ; Get dividend_hi.
	XOR EDX, EDX ; Zero-extend it into EDX:EAX.
	DIV EBX ; EAX = quotient_hi, EDX = intermediate remainder
	MOV EAX, ECX ; EAX = dividend_lo
	DIV EBX ; EAX = quotient_lo
	MOV EAX, EDX ; EAX = remainder_lo
	XOR EDX, EDX ; EDX = remainder_hi = 0
	JMP DONE

RBIGDIVISOR:
	MOV EDI, ECX ; Save divisor_hi.
	SHR EDX, 1 ; Shift both divisor and dividend right
	RCR EAX, 1 ; by 1 bit.
	ROR EDI, 1
	RCR EBX, 1
	BSR ECX, ECX ; ECX = number of remaining shifts
	SHRD EBX, EDI, CL ; Scale down divisor and dividend such
	SHRD EAX, EDX, CL ; that divisor is less than 2^32
	SHR EDX, CL ; (that is, it fits in EBX).
	ROL EDI, 1 ; Restore original divisor (EDI:ESI).
	DIV EBX ; Compute quotient.
	MOV EBX, [EBP+l+0] ; dividend low word
	MOV ECX, EAX ; Save quotient.
	IMUL EDI, EAX ; quotient * divisor high word (low only)
	MUL DWORD [EBP+r+0] ; quotient * divisor low word
	ADD EDX, EDI ; EDX:EAX = quotient * divisor
	SUB EBX, EAX ; dividend_lo – (quot.*divisor)_lo
	MOV ECX, [EBP+l+4] ; dividend_hi
	MOV EAX, [EBP+r+0] ; divisor_lo
	SBB ECX, EDX ; Subtract divisor * quot. from dividend.
	SBB EDX, EDX ; (remainder < 0) ? 0xFFFFFFFF : 0
	AND EAX, EDX ; (remainder < 0) ? divisor_lo : 0
	AND EDX, [EBP+r+4] ; (remainder < 0) ? divisor_hi : 0
	ADD EAX, EBX ; remainder += (remainder < 0) ? divisor : 0

DONE:
	POP	ECX
END ModU64;

PROCEDURE AbsH*(l: SIGNED64): SIGNED64;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	IF l< 0 THEN RETURN -l ELSE RETURN l END;
END AbsH;

PROCEDURE AslH*(l: SIGNED64; r: SIGNED32): SIGNED64; (*! coincides with Logic Shift, remove ? *)
BEGIN {UNCOOPERATIVE, UNCHECKED}
	RETURN LslH(l,r)
END AslH;

PROCEDURE LslH*(l: SIGNED64; r: SIGNED32): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX left, shift count in ECX (count
	; applied modulo 64).
	SHLD EDX,EAX,CL		; First apply shift count.
	SHL EAX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ lshiftdone 			; No, done.
	MOV EDX,EAX			; Left shift EDX:EAX
	XOR EAX,EAX 			; by 32 bits
	lshiftdone:
	POP	ECX
END LslH;

PROCEDURE AsrH*(l: SIGNED64; r: SIGNED32): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	SHRD EAX,EDX,CL		; First apply shift count.
	SAR EDX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ rshiftdone 			; No, done.
	MOV EAX,EDX			; Left shift EDX:EAX
	SAR EDX,31 			; by 32 bits (fill EDX with sign bits)
	rshiftdone:
	POP	ECX
END AsrH;

PROCEDURE LsrH*(l: SIGNED64; r: SIGNED32): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	SHRD EAX,EDX,CL		; First apply shift count.
	SHR EDX,CL 			; mod 32 to EDX:EAX
	TEST ECX,32 			; Need to shift by another 32?
	JZ rshiftdone 			; No, done.
	MOV EAX,EDX			; Left shift EDX:EAX
	XOR EDX,EDX 			; by 32 bits (clear EDX)
	rshiftdone:
	POP	ECX
END LsrH;

PROCEDURE RorH*(l: SIGNED64; r: SIGNED32): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; EBX (initially=EAX) -> EDX -> EAX
	; Shift EDX:EAX right, shift count in ECX (count
	; applied modulo 64).
	TEST ECX,32 			; Need to shift by 32?
	JZ rest					; No.
	XCHG EDX,EAX
rest:
	MOV EBX,EAX
	SHRD EAX,EDX,CL
	SHRD EDX,EBX,CL
	POP	ECX
END RorH;

PROCEDURE RolH*(l: SIGNED64; r: SIGNED32): SIGNED64;
CODE{SYSTEM.i386}
	PUSH	ECX
	; taken from "Software Optimization Guide for AMD64 Processors"
	MOV ECX,[EBP+r+0]
	MOV EAX,[EBP+l+0]
	MOV EDX,[EBP+l+4]
	; EDX <- EAX <- EBX (intially=EDX)
	; Shift EDX:EAX left, shift count in ECX (count
	; applied modulo 64).
	TEST ECX,32				; Need to shift by 32?
	JZ rest					; No.
	XCHG EDX,EAX
rest:
	MOV EBX,EDX
	SHLD EDX,EAX,CL
	SHLD EAX,EBX,CL
	POP	ECX
END RolH;

PROCEDURE CasH*(VAR value: SIGNED64; old, new: SIGNED64): SIGNED64;
CODE{SYSTEM.Pentium}
	PUSH	ECX
	MOV	EAX, [EBP + old + 0]
	MOV	EDX, [EBP + old + 4]
	MOV	EBX, [EBP + new + 0]
	MOV	ECX, [EBP + new + 4]
	MOV	EDI, [EBP + value]
	LOCK CMPXCHG8B [EDI]
	POP	ECX
END CasH;

PROCEDURE EntierXH*(x: FLOAT64): SIGNED64;
CODE
	FLD	QWORD [EBP+x]
	SUB	ESP, 12
	FNSTCW	[ESP]
	FWAIT
	MOV	ESI, [ESP]
	AND	ESI, 0000F3FFH
	OR	ESI, 00000400H
	MOV	[ESP+4], ESI
	FLDCW	[ESP+4]
	FISTP	QWORD [ESP+4]
	FWAIT
	FLDCW	[ESP]
	POP	EDI
	POP	EAX
	POP	EDX
END EntierXH;

PROCEDURE EntierRH*(x: FLOAT32): SIGNED64;
CODE
	FLD DWORD [EBP+x]
	SUB	ESP, 12
	FNSTCW	[ESP]
	FWAIT
	MOV	ESI, [ESP]
	AND	ESI, 0000F3FFH
	OR	ESI, 00000400H
	MOV	[ESP+4], ESI
	FLDCW	[ESP+4]
	FISTP	QWORD [ESP+4]
	FWAIT
	FLDCW	[ESP]
	POP	EDI
	POP	EAX
	POP	EDX
END EntierRH;

(* compare strings,
	returns 0 if strings are equal,
	returns +1 if left is lexicographic greater than right,
	returns -1 if left is lexicographics smaller than right
	traps if src or destination is not 0X terminated and comparison is not finished
*)
PROCEDURE CompareString*(CONST left,right: ARRAY OF CHAR): SIGNED8;
VAR i: SIZE; res: SIGNED8; l, r: CHAR;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	i := 0; res := 0;
	LOOP
		ASSERT (i < LEN (left));
		ASSERT (i < LEN (right));
		l := left[i];
		r := right[i];
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
VAR l1, l2: SIZE;
BEGIN {UNCOOPERATIVE, UNCHECKED}
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
BEGIN {UNCOOPERATIVE, UNCHECKED}
	FOR i := 0 TO size BY 4096 DO
		SYSTEM.GET(ADDRESSOF(i)-i,temp);
	END;
END EnsureAllocatedStack;

BEGIN
	(*! assumed that modules = 0, implicit call of InsertModule *)
END Builtins.


Builtins.Obw
