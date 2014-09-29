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
BEGIN {UNCOOPERATIVE, UNCHECKED}
	CODE HLT END;
END AwaitInterrupt;

PROCEDURE SendInterrupt- (low, high: SET);
CONST ICRL = 300H; ICRH = 310H; DS = 12;
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (baseAddress # NIL);
(*
	SYSTEM.ASM ("
		mov	edx, [baseAddress]
		mov	eax, [ebp + high]
		mov	[edx + ICRH], eax
		mov	eax, [ebp + low]
		mov	[edx + ICRL], eax
	wait:	pause
		bt	dword [edx + ICRL], DS
		jc	wait
	");
*)
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
BEGIN {UNCOOPERATIVE, UNCHECKED}
	ASSERT (baseAddress = NIL);
(*
	SYSTEM.ASM ("
		; check APIC availability
		push	ecx
		mov	eax, 0
		cpuid
		cmp	eax, 1
		jl	skip
		mov	eax, 1
		cpuid
		bt	edx, 9
		jnc	skip

		; get APIC base address
		mov	ecx, 0000001Bh
		rdmsr
		and	eax, 0xfffff000
		mov	edx, eax
		mov	[baseAddress], edx
	skip:	pop	ecx
	");
*)
	ASSERT (baseAddress # NIL);
END Initialize;

END APIC.
