(**
	AUTHOR: "Alexey Morozov";
	PURPOSE: "ActiveCells AXI-4 Stream input/output interface for Xilinx Zynq platform";
*)
MODULE Channels;

IMPORT
	SYSTEM;

#IF UNIX THEN
	IMPORT Unix, Modules;
#END

CONST
	MasterAxiGp0Base = 07F000000H; (* base address for Master AXI General Purpose interface 0 *)
	MasterAxiGp1Base = 0BF000000H; (* base address for Master AXI General Purpose interface 1 *)

	MaxNumChannels = 1024;

	ChanAddrRange  = 256*4; (* ActiveCells AXI4 Stream channel address range in bytes *)
(*
	OutDataOffset = 0;
	OutReadyOffset = SIZEOF(SIGNED32);

	InpAvailableOffset = 0;
	InpDataOffset = 2*SIZEOF(SIGNED32);
*)

TYPE
	(* AXI4 Stream logical port descriptor *)
	PortDesc = RECORD
		lockAddr: ADDRESS; (* address of the associated spin lock *)
		portAddr: ADDRESS; (* address of the logical channel port *)
	END;
	PortDescPtr = POINTER TO PortDesc;

	Output* = PORT OUT; (** AXI4 Stream output port *)
	Input* = PORT IN; (** AXI4 Stream input port *)

VAR
	inputs: ARRAY 2 OF ARRAY MaxNumChannels OF PortDescPtr;
	outputs: ARRAY 2 OF ARRAY MaxNumChannels OF PortDescPtr;

	locks: ARRAY 2 OF SIGNED32; (* locks for each physical channel *)

(*
	Writing/reading to/from a port can be described by the following high-level code:

	PROCEDURE WriteToPort(out: Output; data: SIGNED32);
	VAR
		portDesc: PortDescPtr;
		outDesc: OutputDesc;
	BEGIN
		portDesc := SYSTEM.VAL(PortDescPtr,out);
		outDesc := portDesc.portAddr;
		outDesc.data := data;
	END WriteToPort;

	PROCEDURE ReadFromPort(inp: Input; VAR data: SIGNED32);
	VAR
		portDesc: PortDescPtr;
		inpDesc: InputDesc;
	BEGIN
		portDesc := SYSTEM.VAL(PortDescPtr,inp);
		inpDesc := portDesc.portAddr;
		data := inpDesc.data;
	END ReadFromPort;

	where OutputDesc and InputDesc are defined as follows:

	(** AXI4 Stream output port descriptor *)
	OutputDesc* = POINTER{UNSAFE,UNTRACED} TO RECORD
		data: SIGNED32; (** output data, write only *)
		ready: UNSIGNED8; (** non-zero when output is available for sending data *)
		padding: ARRAY 3 OF CHAR;
	END;

	(** AXI4 Stream input port descriptor *)
	InputDesc* = POINTER{UNSAFE,UNTRACED} TO RECORD
		available: UNSIGNED8; (** non-zero when input data is available *)
		padding: ARRAY 7 OF CHAR;
		data: SIGNED32; (** input data, read only *)
	END;
*)

	(**
		Get AXI4 Stream input port

		physicalPortNum: physical port number
		logicalPortNum: logical port number
	*)
	PROCEDURE GetInput*(physicalPortNum, logicalPortNum: SIGNED32; VAR port: Input): BOOLEAN;
	VAR
		portAddr: ADDRESS;
	BEGIN
		ASSERT(logicalPortNum < MaxNumChannels);
		CASE physicalPortNum OF
			|0: portAddr := masterAxiGp0Base + logicalPortNum*ChanAddrRange;
			|1: portAddr := masterAxiGp1Base + logicalPortNum*ChanAddrRange;
		ELSE
			RETURN FALSE;
		END;

		VAR portDesc := inputs[physicalPortNum,logicalPortNum];
		IF portDesc = NIL THEN
			NEW(portDesc); inputs[physicalPortNum,logicalPortNum] := portDesc;
		END;
		portDesc.portAddr := portAddr;
		portDesc.lockAddr := ADDRESSOF(locks[physicalPortNum]);
		port := SYSTEM.VAL(Input,portDesc);

		RETURN TRUE;
	END GetInput;

	(**
		Get AXI4 Stream output port

		physicalPortNum: physical port number
		logicalPortNum: logical port number
	*)
	PROCEDURE GetOutput*(physicalPortNum, logicalPortNum: SIGNED32; VAR port: Output): BOOLEAN;
	VAR
		portAddr: ADDRESS;
	BEGIN
		ASSERT(logicalPortNum < MaxNumChannels);
		CASE physicalPortNum OF
			|0: portAddr := masterAxiGp0Base + logicalPortNum*ChanAddrRange;
			|1: portAddr := masterAxiGp1Base + logicalPortNum*ChanAddrRange;
		ELSE
			RETURN FALSE;
		END;

		VAR portDesc := outputs[physicalPortNum,logicalPortNum];
		IF portDesc = NIL THEN
			NEW(portDesc); outputs[physicalPortNum,logicalPortNum] := portDesc;
		END;
		portDesc.portAddr := portAddr;
		portDesc.lockAddr := ADDRESSOF(locks[physicalPortNum]);
		port := SYSTEM.VAL(Output,portDesc);

		RETURN TRUE;
	END GetOutput;

	PROCEDURE GetOutputDataAddr*(out: Output): ADDRESS;
	BEGIN
		RETURN SYSTEM.VAL(PortDesc,out).portAddr;
	END GetOutputDataAddr;

	PROCEDURE GetInputDataAddr*(inp: Input): ADDRESS;
	BEGIN
		RETURN SYSTEM.VAL(PortDesc,inp).portAddr+8;
	END GetInputDataAddr;

	(*
		Acquire exclusive access to a resource

		R1: lock address

		R0, R5 are used in addition

		Based on the code presented in "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009,
	*)
	PROCEDURE {PLAIN} -AcquireResource;
	CODE
		MOV R0, #1
	Loop:
		LDREX R5, R1 ; read lock
		CMP R5, #0 ; check if 0
		WFENE ; sleep if the lock is held

		STREXEQ R5, R0, R1 ; attempt to store new value
		CMPEQ R5, #0 ; test if store suceeded
		BNE Loop ; retry if not

		DMB ; ensures that all subsequent accesses are observed after the gaining of the lock is observed

		; loads and stores in the critical region can now be performed
	END AcquireResource;

	(*
		Release exclusive access to a resource

		R1: lock address

		R0 is used in addition

		Based on the code presented in "Barrier Litmus Tests and Cookbook" by Richard Grisenthwaite, ARM, 26.11.2009,
	*)
	PROCEDURE {PLAIN} -ReleaseResource;
	CODE
		MOV R0, #0
		DMB ; ensure all previous accesses are observed before the lock is cleared
		STR R0, [R1, #0]
		; clear the lock.
		DSB ; ensure completion of the store that cleared the lock before sending the event
		SEV
	END ReleaseResource;

	(*
	PROCEDURE AcquireObject(lockAddr: ADDRESS);
	BEGIN
		CODE
			LDR R1, [FP, #lockAddr] ; R1 := address of lock
		END;
		AcquireResource;
	END AcquireObject;

	PROCEDURE ReleaseObject(lockAddr: ADDRESS);
	BEGIN
		CODE
			LDR R1, [FP, #lockAddr] ; R1 := address of lock
		END;
		ReleaseResource
	END ReleaseObject;
	*)

	(**
		Returns TRUE if the given output port is ready to accept new data
	*)
	PROCEDURE Ready*(out: Output): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #4] ; R4 := out.Ready
			STRB R4, [FP, #b] ; b := R4
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,out);
		TRACE(p.portAddr, p.lockAddr);
		AcquireObject(p.lockAddr);
		b := SYSTEM.GET32(p.portAddr+OutReadyOffset) # 0;
		ReleaseObject(p.lockAddr);
		*)
		RETURN b;
	END Ready;

	(** Returns number of data elements available to read from an input port *)
	PROCEDURE Available*(inp: Input): SIGNED32;
	VAR available: SIGNED32;
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #0] ; R4 := inp.Available
			STR R4, [FP, #available] ; available := R4
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,inp);
		AcquireObject(p.lockAddr);
		available := SYSTEM.GET32(p.portAddr+InpAvailableOffset);
		ReleaseObject(p.lockAddr);
		*)
		RETURN available;
	END Available;

	(** Send data to an output port (blocking version) *)
	PROCEDURE Send*(out: Output; x: SIGNED32);
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			STR R2, [R3, #0] ; out.Data := R2
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,out);
		AcquireObject(p.lockAddr);
		SYSTEM.PUT32(p.portAddr+OutDataOffset,x);
		ReleaseObject(p.lockAddr);
		*)
	END Send;

	(** Send data to an output port (non-blocking version) *)
	PROCEDURE SendNonBlocking*(out: Output; x: SIGNED32): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		CODE
			LDR R3, [FP, #out] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #4] ; R4 := out.Ready
			STRB R4, [FP, #b] ; b := R4

			CMP R4, #0
			BEQ Exit

			STR R2, [R3, #0] ; out.Data := R2
		Exit:
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,out);
		AcquireObject(p.lockAddr);
		b := SYSTEM.GET32(p.portAddr+OutReadyOffset) # 0;
		IF b THEN SYSTEM.PUT32(p.portAddr+OutDataOffset,x); END;
		ReleaseObject(p.lockAddr);
		*)
		RETURN b;
	END SendNonBlocking;

	OPERATOR "<<"*(out: Output; x: SIGNED32);
	BEGIN
		Send(out,x);
	END "<<";

	OPERATOR ">>"*(x: SIGNED32; out: Output);
	BEGIN
		Send(out,x);
	END ">>";

	OPERATOR "<<?"*(out: Output; x: SIGNED32): BOOLEAN;
	BEGIN
		RETURN SendNonBlocking(out,x);
	END "<<?";

	OPERATOR ">>?"*(x: SIGNED32; out: Output): BOOLEAN;
	BEGIN
		RETURN SendNonBlocking(out,x);
	END ">>?";

	(** Receive data from an input port (blocking version) *)
	PROCEDURE Receive*(inp: Input; VAR x: SIGNED32);
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R2, [FP, #x] ; R2 := address of x
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #8] ; R4 := inp.Data
			STR R4, [R2, #0] ; x := R4
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,inp);
		AcquireObject(p.lockAddr);
		x := SYSTEM.GET32(p.portAddr+InpDataOffset);
		ReleaseObject(p.lockAddr);
		*)
	END Receive;

	(** Receive data from an input port (non-blocking version) *)
	PROCEDURE ReceiveNonBlocking*(inp: Input; VAR x: SIGNED32): BOOLEAN;
	VAR b: BOOLEAN;
	BEGIN
		CODE
			LDR R3, [FP, #inp] ; R3 := address of PortDesc.lockAddr
			LDR R1, [R3, #0] ; R1 := PortDesc.lockAddr
		END;
		AcquireResource;
		CODE
			LDR R3, [R3, #4] ; R3 := PortDesc.portAddr
			LDR R4, [R3, #0] ; R4 := inp.Available
			STRB R4, [FP, #b] ; b := R4

			CMP R4, #0
			BEQ Exit

			LDR R2, [FP, #x] ; R2 := address of x
			LDR R4, [R3, #8] ; R4 := inp.Data
			STR R4, [R2, #0] ; x := R4
		Exit:
		END;
		ReleaseResource;
		(*
		VAR p := SYSTEM.VAL(PortDescPtr,inp);
		AcquireObject(p.lockAddr);
		b := SYSTEM.GET32(p.portAddr+InpAvailableOffset) # 0;
		IF b THEN x := SYSTEM.GET32(p.portAddr+InpDataOffset); END;
		ReleaseObject(p.lockAddr);
		*)
		RETURN b;
	END ReceiveNonBlocking;

	OPERATOR ">>"*(inp: Input; VAR x: SIGNED32);
	BEGIN
		Receive(inp,x);
	END ">>";

	OPERATOR "<<"*(VAR x: SIGNED32; inp: Input);
	BEGIN
		Receive(inp,x);
	END "<<";

	OPERATOR ">>?"*(inp: Input; VAR x: SIGNED32): BOOLEAN;
	BEGIN
		RETURN ReceiveNonBlocking(inp,x);
	END ">>?";

	OPERATOR "<<?"*(VAR x: SIGNED32; inp: Input): BOOLEAN;
	BEGIN
		RETURN ReceiveNonBlocking(inp,x);
	END "<<?";

	(*
	PROCEDURE SendMultiple(portAddr, dataAddr: ADDRESS; numElements: SIGNED32);
	CODE
		LDR R0, [FP,#portAddr]
		LDR R1, [FP,#dataAddr]
		LDR R2, [FP,#numElements]

		CMP R2, #8
		BLT CheckLoop4

	Loop8: ; numElements >= 8, coalescing of 8 transfers
		LDR R3, [R1,#0]
		LDR R4, [R1,#4]
		LDR R5, [R1,#8]
		LDR R6, [R1,#12]
		LDR R7, [R1,#16]
		LDR R8, [R1,#20]
		LDR R9, [R1,#24]
		LDR R10, [R1,#28]

		STR R3, [R0,#0]
		STR R4, [R0,#0]
		STR R5, [R0,#0]
		STR R6, [R0,#0]
		STR R7, [R0,#0]
		STR R8, [R0,#0]
		STR R9, [R0,#0]
		STR R10, [R0,#0]

		ADD R1, R1, #32
		SUBS R2, R2, #8
		BGT Loop8

	CheckLoop4:
		CMP R2, #4
		BLT CheckLoop1

	Loop4: ; numElements >= 4, coalescing of 4 transfers
		LDR R3, [R1,#0]
		LDR R4, [R1,#4]
		LDR R5, [R1,#8]
		LDR R6, [R1,#12]

		STR R3, [R0,#0]
		STR R4, [R0,#0]
		STR R5, [R0,#0]
		STR R6, [R0,#0]

		ADD R1, R1, #16
		SUBS R2, R2, #4
		BGT Loop4

	CheckLoop1:
		CMP R2, #1
		BLT Exit

	Loop1: ; numElements >= 1, transfer element by element
		LDR R3, [R1,#0]
		STR R3, [R0,#0]

		ADD R1, R1, #4
		SUBS R2, R2, #1
		BGT Loop1

	Exit:

	END SendMultiple;

	PROCEDURE ReceiveMultiple(portAddr, dataAddr: ADDRESS; numElements: SIGNED32);
	CODE
		LDR R0, [FP,#portAddr]
		ADD R0, R0, #8
		LDR R1, [FP,#dataAddr]
		LDR R2, [FP,#numElements]

		CMP R2, #8
		BLT CheckLoop4

	Loop8: ; numElements >= 8, coalescing of 8 transfers
		LDR R3, [R0,#0]
		LDR R4, [R0,#0]
		LDR R5, [R0,#0]
		LDR R6, [R0,#0]
		LDR R7, [R0,#0]
		LDR R8, [R0,#0]
		LDR R9, [R0,#0]
		LDR R10, [R0,#0]

		STR R3, [R1,#0]
		STR R4, [R1,#4]
		STR R5, [R1,#8]
		STR R6, [R1,#12]
		STR R7, [R1,#16]
		STR R8, [R1,#20]
		STR R9, [R1,#24]
		STR R10, [R1,#28]

		ADD R1, R1, #32
		SUBS R2, R2, #8
		BGT Loop8

	CheckLoop4:
		CMP R2, #4
		BLT CheckLoop1

	Loop4: ; numElements >= 4, coalescing of 4 transfers
		LDR R3, [R0,#0]
		LDR R4, [R0,#0]
		LDR R5, [R0,#0]
		LDR R6, [R0,#0]

		STR R3, [R1,#0]
		STR R4, [R1,#4]
		STR R5, [R1,#8]
		STR R6, [R1,#12]

		ADD R1, R1, #16
		SUBS R2, R2, #4
		BGT Loop4

	CheckLoop1:
		CMP R2, #1
		BLT Exit

	Loop1: ; numElements >= 1, transfer element by element
		LDR R3, [R0,#0]
		STR R3, [R1,#0]

		ADD R1, R1, #4
		SUBS R2, R2, #1
		BGT Loop1

	Exit:

	END ReceiveMultiple;
	*)

	OPERATOR "<<"*(port: Output; x: SET32); BEGIN Send(port,SYSTEM.VAL(SIGNED32,x)); END "<<";
	OPERATOR ">>"*(x: SET32; port: Output); BEGIN Send(port,SYSTEM.VAL(SIGNED32,x)); END ">>";
	OPERATOR "<<?"*(port: Output; x: SET32): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END "<<?";
	OPERATOR ">>?"*(x: SET32; port: Output): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END ">>?";
	OPERATOR ">>"*(port: Input; VAR x: SET32); BEGIN Receive(port,SYSTEM.VAL(SIGNED32,x)); END ">>";
	OPERATOR "<<"*(VAR x: SET32; port: Input); BEGIN Receive(port,SYSTEM.VAL(SIGNED32,x)); END "<<";
	OPERATOR ">>?"*(port: Input; VAR x: SET32): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END ">>?";
	OPERATOR "<<?"*(VAR x: SET32; port: Input): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END "<<?";

	OPERATOR "<<"*(port: Output; x: FLOAT32); BEGIN Send(port,SYSTEM.VAL(SIGNED32,x)); END "<<";
	OPERATOR ">>"*(x: FLOAT32; port: Output); BEGIN Send(port,SYSTEM.VAL(SIGNED32,x)); END ">>";
	OPERATOR "<<?"*(port: Output; x: FLOAT32): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END "<<?";
	OPERATOR ">>?"*(x: FLOAT32; port: Output): BOOLEAN; BEGIN RETURN SendNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END ">>?";
	OPERATOR ">>"*(port: Input; VAR x: FLOAT32); BEGIN Receive(port,SYSTEM.VAL(SIGNED32,x)); END ">>";
	OPERATOR "<<"*(VAR x: FLOAT32; port: Input); BEGIN Receive(port,SYSTEM.VAL(SIGNED32,x)); END "<<";
	OPERATOR ">>?"*(port: Input; VAR x: FLOAT32): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END ">>?";
	OPERATOR "<<?"*(VAR x: FLOAT32; port: Input): BOOLEAN; BEGIN RETURN ReceiveNonBlocking(port,SYSTEM.VAL(SIGNED32,x)); END "<<?";


VAR
	masterAxiGp0Base: ADDRESS;
	masterAxiGp1Base: ADDRESS;

#IF UNIX THEN

CONST
	ChannelsAddrSpace = MaxNumChannels * ChanAddrRange;

	PROCEDURE InitMod;
	BEGIN
		VAR memDev := Unix.open(ADDRESSOF("/dev/mem"), INTEGERSET(Unix.O_RDWR+Unix.O_SYNC), 0);
		ASSERT(memDev >= 0);

		masterAxiGp0Base := Unix.mmap(NIL, ChannelsAddrSpace, Unix.PROT_READ+Unix.PROT_WRITE, Unix.MAP_SHARED, memDev, Unix.off_t(MasterAxiGp0Base));
		ASSERT(masterAxiGp0Base # NIL);
		masterAxiGp1Base := Unix.mmap(NIL, ChannelsAddrSpace, Unix.PROT_READ+Unix.PROT_WRITE, Unix.MAP_SHARED, memDev, Unix.off_t(MasterAxiGp1Base));
		ASSERT(masterAxiGp1Base # NIL);

		IGNORE Unix.close(memDev);
		Modules.InstallTermHandler(TerminateMod);
		RETURN;
	FINALLY
		IF memDev >= 0 THEN
			IGNORE Unix.close(memDev);
			TerminateMod;
		END;
	END InitMod;

	PROCEDURE TerminateMod;
	BEGIN
		IF masterAxiGp0Base # NIL THEN IGNORE Unix.munmap(masterAxiGp0Base, ChannelsAddrSpace); END;
		IF masterAxiGp1Base # NIL THEN IGNORE Unix.munmap(masterAxiGp1Base, ChannelsAddrSpace); END;
	END TerminateMod;

#END

BEGIN

#IF ~UNIX THEN
	masterAxiGp0Base := MasterAxiGp0Base;
	masterAxiGp1Base := MasterAxiGp1Base;
#ELSE
	InitMod;
#END

END Channels.

