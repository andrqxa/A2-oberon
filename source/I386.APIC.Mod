(* Runtime support for APIC *)
(* Copyright (C) Florian Negele *)

(** Represents all logical processors of the system. *)
MODULE APIC;

IMPORT SYSTEM, CPU;

CONST Processors* = 32;
CONST ReservedArea* = Processors * CPU.StackSize;

CONST NMI* = {10}; INIT* = {8, 10}; STARTUP* = {9, 10};
CONST Assert* = {14}; AllExcludingSelf* = {18, 19};

VAR baseAddress := NIL: ADDRESS;

PROCEDURE AwaitInterrupt-;
CODE
	HLT;
END AwaitInterrupt;

PROCEDURE SendInterrupt- (low, high: SET);
CONST ICRL = 300H; ICRH = 310H; Status = 12;
CODE
	MOV	EDX, baseAddress
	MOV	EAX, [EBP + high]
	MOV	[EDX + ICRH], EAX
	MOV	EAX, [EBP + low]
	MOV	[EDX + ICRL], EAX
wait:
	PAUSE
	BT		DWORD [EDX + ICRL], Status
	JC		wait
END SendInterrupt;

PROCEDURE CopyBootCode- (start: PROCEDURE {NORETURN});
CONST ID = 20H;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (baseAddress # NIL);
(*
	SYSTEM.ASM ("
		; copy bootstrap code
		push	ecx
		mov	edi, 0
		mov	esi, dword @APIC.BootCode
		mov	ecx, bootcode_size / 4
		cld
		rep movsd
		pop	ecx

		; patch start procedure
		mov	eax, [ebp + start]
		sub	eax, dword patch - bootcode_begin
		mov	[patch - bootcode_begin - 4], eax

		; skip application processor code
		jmp	dword bootcode_end

		.pad	4
	bootcode_begin:
		.bitmode	16
		.alias	APIC.BootCode

		; enter protected mode
		cli
		lgdt	[gdt32 - bootcode_begin]
		mov	eax, cr0
		or	eax, 1
		mov	cr0, eax

		; prepare segment registers
		mov	bx, (data32 - gdt32_begin) / 8 << 3
		mov	ds, bx
		mov	es, bx
		mov	fs, bx
		mov	gs, bx
		mov	ss, bx

		; activate protected mode
		jmpfar	(code32 - gdt32_begin) / 8 << 3, dword protected - bootcode_begin

	protected:
		.bitmode	32

		; create unique stack pointer
		mov	eax, [baseAddress]
		mov	eax, [eax + ID]
		shr	eax, 24
		inc	eax
		mov	ebx, (ReservedArea - bootcode_size) / Processors / 4 * 4
		mul	ebx
		mov	esp, eax
		add	esp, dword bootcode_size
		lidt	[@CPU.idt]

		; jump to start procedure
		jmp	dword 0
	patch:

	gdt32:
		.dbyte	gdt32_end - gdt32_begin
		.qbyte	gdt32_begin - bootcode_begin

	gdt32_begin:
		.qbyte	0, 0
		code32:	.byte	11111111b, 11111111b, 00h, 00h, 00h, 10011110b, 11001111b, 0h
		data32:	.byte	11111111b, 11111111b, 00h, 00h, 00h, 10010010b, 11001111b, 0h
	gdt32_end:
		.pad	4
	bootcode_end:
	bootcode_size:	.equals	bootcode_end - bootcode_begin
		.assert	bootcode_size % 4 == 0
	");
*)
END CopyBootCode;

PROCEDURE Initialize-;
CODE
	; check APIC availability
	PUSH	ECX
	MOV	EAX, 0
	CPUID
	CMP	EAX, 1
	JL		skip
	MOV	EAX, 1
	CPUID
	BT		EDX, 9
	JNC	skip

	; get APIC base address
	MOV	ECX, 0000001BH
	RDMSR
	AND	EAX, 0FFFFF000H
	MOV	EDX, EAX
	MOV	baseAddress, EDX
skip:
	POP	ECX
END Initialize;

END APIC.
