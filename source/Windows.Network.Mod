(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Network; (** AUTHOR "pjm, mvt"; PURPOSE "Abstract network device driver"; *)

IMPORT SYSTEM, WSock32, Machine, KernelLog, Plugins, Kernel, Objects, Modules;
	VAR

CONST
	MaxLinkAdrSize* = 8; (** largest link address size in bytes *)
	MaxPacketSize* = 1600; (** maximum amount of data bytes in a link layer frame *)
	MaxNofBuffers = 10000; (* maximum number of buffers allowed within the whole net system *)

	(** Constants for LinkDevice.type *)
	TypePointToPoint* = 0;
	TypeEthernet* = 1;

	(** Constants for LinkDevice.Linked *)
	LinkNotLinked* = 0;
	LinkLinked* = 1;
	LinkUnknown* = 2;

	(** Constants for LinkDevice.calcChecksum and Buffer.calcChecksum *)
	ChecksumIP* = 0;
	ChecksumUDP* = 1;
	ChecksumTCP* = 2;

	(* Number of loopback packets that can be sent per 1-2 ms.
		This protects the upcall buffers from running out. *)
	MaxLoopbackPacketsPerMS = 500;

TYPE
	LinkAdr* = ARRAY MaxLinkAdrSize OF CHAR; (** link layer address *)

	(** Buffer for passing network packets to upper layer protocols *)
	Buffer* = POINTER TO RECORD
		data*: ARRAY MaxPacketSize OF CHAR;
		ofs*: SIGNED32; (** valid data starts at this offset *)
		len*: SIGNED32; (** length of valid data *)
		l3ofs*: SIGNED32; (** the layer 3 header starts at this offset *)
		l4ofs*: SIGNED32; (** the layer 4 header starts at this offset *)
		src*: LinkAdr; (** link layer source address *)
		calcChecksum*: SET; (** these checksums are already verified by the device *)
		int*: SIGNED32; (** used in TCP, UDP and ICMP, but can be used by any upper layer protocol *)
		set*: SET; (** used in TCP, but can be used by any upper layer protocol *)
		next*, prev*: Buffer; (** for queueing the buffer *)
	END;

	ReceiverList = POINTER TO RECORD
		next: ReceiverList;
		type: SIGNED32;
		receiver: Receiver;
	END;

	SendSnifferList = POINTER TO RECORD
		next: SendSnifferList;
		sniffer: SendSniffer;
	END;

	RecvSnifferList = POINTER TO RECORD
		next: RecvSnifferList;
		sniffer: ReceiveSniffer;
	END;

	(** Abstract implementation of a generic network driver object *)

	LinkDevice* = OBJECT (Plugins.Plugin)
		VAR
			(** pubic device properties *)
			type-: SIGNED32; (** LinkType: TypePointToPoint, TypeEthernet *)
			local-: LinkAdr; (** local link address *)
			broadcast-: LinkAdr; (** link address for sending a broadcast *)
			mtu-: SIGNED32; (** largest packet size in bytes *)
			adrSize-: SIGNED32; (** link address size in bytes *)
			sendCount-, recvCount-: SIGNED64; (** number of bytes sent and received *)
			calcChecksum-: SET; (** these checksums are calculated by the device hardware when sending. *)

			recList: ReceiverList; (* receiver list *)
			sendSnifferList: SendSnifferList; (* list for send sniffers *)
			recvSnifferList: RecvSnifferList; (* list for receive sniffers *)

			item: ReceiverList; (* temporary item in receiver list *)
			sniffer: RecvSnifferList; (* temporary item in receive sniffer list *)

			discard: BOOLEAN; (* shall the current packet be discarded? (used in active body) *)
			finalized: BOOLEAN; (* is object already finalized or currently finalizing? *)

			(* queue for buffers waiting for upcall *)
			upBufFirst, upBufLast: Buffer;
			buf: Buffer; (* temporary buffer for active body *)

			(* timer and packet count for loopback bandwidth control *)
			timer: Kernel.MilliTimer;
			packetCount: SIGNED32;

		(** Constructor - Initialize the driver and the device.
			NOTE:
			Is normally overridden by device driver. If so, this constructor has to be called at the beginning
			of the overriding constructor!
		*)
		PROCEDURE &Constr*(type, mtu, adrSize: SIGNED32);
		BEGIN
			ASSERT((mtu >= 0) & (mtu <= MaxPacketSize));
			ASSERT((adrSize >= 0) & (adrSize <= MaxLinkAdrSize));
			IF type = TypeEthernet THEN
				ASSERT(adrSize = 6);
			END;
			SELF.type := type;
			SELF.mtu := mtu;
			SELF.adrSize := adrSize;
			SELF.sendCount := 0;
			SELF.recvCount := 0;
			SELF.calcChecksum := {};

			recList := NIL;
			upBufFirst := NIL;

			Kernel.SetTimer(timer, 2);
			packetCount := 0;

			finalized := FALSE;

			sendSnifferList := NIL;
			recvSnifferList := NIL;
		END Constr;

		(** Destructor - Finalize driver object. If connected = TRUE, device is still connected and has to be deinitialized.
			NOTE:
			Is normally overridden by device driver. If so, this method has to be called at the end
			of the overriding method!
		*)
		PROCEDURE Finalize*(connected: BOOLEAN);
		BEGIN {EXCLUSIVE}
			ASSERT(~finalized);
			finalized := TRUE;
		END Finalize;

		(** Return the link status of the device.
			This function has to be overridden by the device driver in order to provide this information.
		*)
		PROCEDURE Linked*(): SIGNED32;
		BEGIN
			RETURN LinkUnknown;
		END Linked;

		(** Send a packet. Called by its user. Can be called concurrently. *)

		PROCEDURE Send*(dst: LinkAdr; type: SIGNED32; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: SIGNED32; loopback: BOOLEAN);
		VAR
			sniffer: SendSnifferList;
			discard: BOOLEAN; (* shall the packet be discarded? *)
		BEGIN (* can run concurrently with InstallSendSniffer and RemoveSendSniffer *)
			ASSERT(~finalized);
			discard := FALSE;
			sniffer := sendSnifferList;
			WHILE sniffer # NIL DO
				(* call sniffer *)
				discard := discard OR sniffer^.sniffer(SELF, dst, type, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
				sniffer := sniffer^.next;
			END;
			IF ~discard THEN
				(* send the packet *)
				IF loopback THEN
					Loopback(dst, type, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
				ELSE
					DoSend(dst, type, l3hdr, l4hdr, data, h3len, h4len, dofs, dlen);
				END;
				INC(sendCount, dlen + h3len + h4len);
			END;
		END Send;

		(** Do frame send operation. Must be overridden and implemented by device driver! *)
		(** Must be able to handle concurrent calls. e.g. by declaring itself as EXCLUSIVE! *)

		PROCEDURE DoSend*(dst: LinkAdr; type: SIGNED32; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: SIGNED32);
		BEGIN
			HALT(301); (* Abstract! *)
		END DoSend;

		(* Do internal loopback. Send packet directly to the receive queue. *)

		PROCEDURE Loopback(dst: LinkAdr; type: SIGNED32; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; h3len, h4len, dofs, dlen: SIGNED32);
		VAR buf: Buffer;
		BEGIN
			IF packetCount >= MaxLoopbackPacketsPerMS THEN
				WHILE ~Kernel.Expired(timer) DO
					(* no more packets can be sent until timer is expired *)
					Objects.Yield();
				END;
				Kernel.SetTimer(timer, 2);
				packetCount := 0;
			END;

			buf := GetNewBuffer();
			IF buf # NIL THEN
				buf.l3ofs := 0;
				buf.l4ofs := 0;
				buf.ofs := 0;
				buf.len := 0;
				buf.src := dst;
				buf.calcChecksum := {ChecksumIP, ChecksumUDP, ChecksumTCP};

				(* Copy data to receive buffer *)
				Copy(l3hdr, buf.data, 0, buf.len, h3len);
				INC(buf.len, h3len);
				Copy(l4hdr, buf.data, 0, buf.len, h4len);
				INC(buf.len, h4len);
				Copy(data, buf.data, dofs, buf.len, dlen);
				INC(buf.len, dlen);

				(* Queue the receive buffer *)
				QueueBuffer(buf, type);
				Machine.AtomicInc(packetCount)
			ELSE (* packet loss in loopback :o *)

			END
		END Loopback;

		(** Install a receiver for the given type. Only one receiver can be installed per type! *)
		PROCEDURE InstallReceiver*(type: SIGNED32; r: Receiver);
		VAR item: ReceiverList;
		BEGIN {EXCLUSIVE}
			(* can run concurrently with active body *)
			ASSERT(~finalized);
			ASSERT(r # NIL);

			(* test if there is already a receiver installed for this type *)
			item := recList;
			WHILE item # NIL DO
				ASSERT(item^.type # type);
				item := item^.next;
			END;

			(* create new entry *)
			NEW(item);
			item^.type := type;
			item^.receiver := r;
			item^.next := recList;
			recList := item;
		END InstallReceiver;

		(** Remove the currently installed receiver for the given type. *)
		PROCEDURE RemoveReceiver*(type: SIGNED32);
		VAR item: ReceiverList;
		BEGIN {EXCLUSIVE}
			(* can run concurrently with active body *)
			ASSERT(~finalized);

			(* remove receiver *)
			IF recList = NIL THEN
				(* empty list - nothing to remove *)
			ELSIF recList^.type = type THEN
				(* remove first item *)
				recList := recList^.next;
			ELSE
				(* search list *)
				item := recList;
				WHILE (item^.next # NIL) & (item^.next^.type # type) DO
					item := item^.next;
				END;
				IF item^.next # NIL THEN
					item^.next := item^.next^.next;
				ELSE
					(* no receiver found for this type *)
				END;
			END;
		END RemoveReceiver;

		(** Install a sniffer for sent packets *)
		PROCEDURE InstallSendSniffer*(s: SendSniffer);
		VAR item: SendSnifferList;
		BEGIN {EXCLUSIVE}
			ASSERT(~finalized);
			item := sendSnifferList;
			WHILE (item # NIL) & (item^.sniffer # s) DO
				item := item^.next;
			END;
			IF item # NIL THEN
				(* sniffer already registered *)
			ELSE
				NEW(item);
				item^.sniffer := s;
				item^.next := sendSnifferList;
				sendSnifferList := item;
			END;
		END InstallSendSniffer;

		(** Remove a sniffer for sent packets *)
		PROCEDURE RemoveSendSniffer*(s: SendSniffer);
		VAR item: SendSnifferList;
		BEGIN {EXCLUSIVE}
			ASSERT(~finalized);
			IF sendSnifferList = NIL THEN
				(* empty list *)
			ELSIF sendSnifferList^.sniffer = s THEN
				(* remove first item *)
				sendSnifferList := sendSnifferList^.next;
			ELSE
				(* search list *)
				item := sendSnifferList;
				WHILE (item^.next # NIL) & (item^.next^.sniffer # s) DO
					item := item^.next;
				END;
				IF item^.next # NIL THEN
					item^.next := item^.next^.next;
				ELSE
					(* sniffer not found *)
				END;
			END;
		END RemoveSendSniffer;

		(** Install a sniffer for received packets *)
		PROCEDURE InstallReceiveSniffer*(s: ReceiveSniffer);
		VAR item: RecvSnifferList;
		BEGIN {EXCLUSIVE}
			ASSERT(~finalized);
			item := recvSnifferList;
			WHILE (item # NIL) & (item^.sniffer # s) DO
				item := item^.next;
			END;
			IF item # NIL THEN
				(* sniffer already registered *)
			ELSE
				NEW(item);
				item^.sniffer := s;
				item^.next := recvSnifferList;
				recvSnifferList := item;
			END;
		END InstallReceiveSniffer;

		(** Remove a sniffer for received packets *)
		PROCEDURE RemoveReceiveSniffer*(s: ReceiveSniffer);
		VAR item: RecvSnifferList;
		BEGIN {EXCLUSIVE}
			ASSERT(~finalized);
			IF recvSnifferList = NIL THEN
				(* empty list *)
			ELSIF recvSnifferList^.sniffer = s THEN
				(* remove first item *)
				recvSnifferList := recvSnifferList^.next;
			ELSE
				(* search list *)
				item := recvSnifferList;
				WHILE (item^.next # NIL) & (item^.next^.sniffer # s) DO
					item := item^.next;
				END;
				IF item^.next # NIL THEN
					item^.next := item^.next^.next;
				ELSE
					(* sniffer not found *)
				END;
			END;
		END RemoveReceiveSniffer;

		(** Queue buffer for upcall. Called from inside the LinkDevice object, normally from the interrupt handler. *)
		PROCEDURE QueueBuffer*(buf: Buffer; type: SIGNED32);
		BEGIN {EXCLUSIVE}
			ASSERT(buf # NIL);
			buf.int := type; (* use "int" field for type information *)
			buf.next := NIL;
			IF upBufFirst = NIL THEN
				upBufFirst := buf;
			ELSE
				upBufLast.next := buf;
			END;
			upBufLast := buf;
		END QueueBuffer;

	BEGIN {ACTIVE, PRIORITY(Objects.High)}
		(* can run concurrently with SetReceiver, QueueBuffer, InstallReceiverSniffer and RemoveReceiverSniffer *)
		LOOP
			BEGIN {EXCLUSIVE}
				AWAIT((upBufFirst # NIL) OR finalized);
				IF (upBufFirst = NIL) & finalized THEN
					(* terminate process after all buffer upcalls are done *)
					EXIT;
				END;
				buf := upBufFirst;
				upBufFirst := upBufFirst.next;
			END;
			INC(recvCount, buf.len);
			discard := FALSE;
			sniffer := recvSnifferList;
			WHILE sniffer # NIL DO
				(* call sniffer *)
				discard := discard OR sniffer^.sniffer(SELF, buf.int, buf);
				sniffer := sniffer^.next;
			END;
			IF ~discard THEN
				(* search for receiver *)
				item := recList;
				WHILE (item # NIL) & (item^.type # buf.int) DO
					item := item^.next;
				END;
				discard := (item = NIL);
			END;
			IF discard THEN
				(* discard packet and return buffer *)
				ReturnBuffer(buf);
			ELSE
				(* do upcall *)
				item^.receiver(SELF, item^.type, buf);
			END;
		END;
	END LinkDevice;

TYPE
	(** Upcall procedures *)

	(** Packet receiver upcall
		CAUTION:
		After the buffer has been used, it has to be returned by calling Network.ReturnBuffer(buffer)!
		The Receiver can do this by itself or delegate this job to other procedures or processes, wherever the
		buffer is passed to. It has not necessarily to be returned within the receiver upcall.
	*)
	Receiver* = PROCEDURE {DELEGATE} (dev: LinkDevice; type: SIGNED32; buffer: Buffer);

	(* Sniffer for sent packets. May modify type, headers and data. Return TRUE if packet shall be discarded. *)
	(* Must be able to handle concurrent calls. e.g. by declaring itself as EXCLUSIVE. *)
	SendSniffer* = PROCEDURE {DELEGATE} (dev: LinkDevice; VAR dst: LinkAdr; VAR type: SIGNED32; VAR l3hdr, l4hdr, data: ARRAY OF CHAR; VAR h3len, h4len, dofs, dlen: SIGNED32): BOOLEAN;

	(* Sniffer for received packets. May modify type and buffer. Return TRUE if packet shall be discarded. *)
	(* Will never be called concurrenty from the same LinkDevice. *)
	ReceiveSniffer* = PROCEDURE {DELEGATE} (dev: LinkDevice; VAR type: SIGNED32; buffer: Buffer): BOOLEAN;

(** Module variables *)

VAR
	registry*: Plugins.Registry;

	nofBuf: SIGNED32; (* number of buffers existing *)
	nofFreeBuf: SIGNED32; (* number of free buffers *)
	freeBufList: Buffer; (* free buffer list *)

(** Get a new buffer - return NIL if MaxNofBuffers is exceeded *)

PROCEDURE GetNewBuffer*(): Buffer;
VAR item: Buffer;
BEGIN {EXCLUSIVE}
	IF freeBufList # NIL THEN
		(* free buffer is available *)
		item := freeBufList;
		freeBufList := freeBufList.next;
		Machine.AtomicAdd(nofFreeBuf, -1);
	ELSIF nofBuf < MaxNofBuffers THEN
		(* no free buffer available - create new one *)
		NEW(item);
		Machine.AtomicInc(nofBuf);
	ELSE
		(* not allowed to create more buffers *)
		item := NIL;
	END;
	RETURN item;
END GetNewBuffer;

(** Return a buffer to be reused *)

PROCEDURE ReturnBuffer*(buf: Buffer);
BEGIN {EXCLUSIVE}
	ASSERT(buf # NIL);
	buf.next := freeBufList;
	freeBufList := buf;
	Machine.AtomicInc(nofFreeBuf);
END ReturnBuffer;

(* Passed to registry.Enumerate() to Finalize each registered LinkDevice *)

PROCEDURE Finalize(p: Plugins.Plugin);
BEGIN
	p(LinkDevice).Finalize(TRUE);
END Finalize;

(** Test whether the n bytes of buf1 and buf2 starting at ofs1 and ofs2 respectively are equal *)

PROCEDURE Equal*(VAR buf1, buf2: ARRAY OF CHAR; ofs1, ofs2, n: SIGNED32): BOOLEAN;
BEGIN
	WHILE (n > 0) & (buf1[ofs1] = buf2[ofs2]) DO INC(ofs1); INC(ofs2); DEC(n) END;
	RETURN n <= 0
END Equal;

(** Procedures to put and get data from and to arrays. No index checks are done due to performance! *)

(** Put a 32-bit host value into buf[ofs..ofs+3] *)

PROCEDURE Put4*(VAR buf: ARRAY OF CHAR; ofs: SIZE; val: UNSIGNED32);
CODE
#IF I386 THEN
	MOV EAX, [EBP+val]
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV [ECX+EBX], EAX
#ELSIF AMD64 THEN
	MOV EAX, [RBP+val]
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV [RCX+RBX], EAX
#ELSE
	unimplemented
#END
END Put4;

(** Put a 16-bit host value into buf[ofs..ofs+1] *)

PROCEDURE Put2*(VAR buf: ARRAY OF CHAR; ofs: SIZE; val: INTEGER);
CODE
#IF I386 THEN
	MOV EAX, [EBP+val]
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV [ECX+EBX], AX
#ELSIF AMD64 THEN
	MOV EAX, [RBP+val]
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV [RCX+RBX], AX
#ELSE
	unimplemented
#END
END Put2;

(** Get a 32-bit host value from buf[ofs..ofs+3] *)

PROCEDURE Get4*(CONST buf: ARRAY OF CHAR; ofs: SIZE): INTEGER;
CODE
#IF I386 THEN
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV EAX, [ECX+EBX]
#ELSIF AMD64 THEN
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV EAX, [RCX+RBX]
#ELSE
	unimplemented
#END
END Get4;

(** Get a 16-bit host value from buf[ofs..ofs+1] *)

PROCEDURE Get2*(CONST buf: ARRAY OF CHAR; ofs: SIZE): INTEGER;
CODE
#IF I386 THEN
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	XOR EAX, EAX
	MOV AX, [ECX+EBX]
#ELSIF AMD64 THEN
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	XOR EAX, EAX
	MOV AX, [RCX+RBX]
#ELSE
	unimplemented
#END
END Get2;

(** Put a 32-bit host value into buf[ofs..ofs+3] in network byte order *)

PROCEDURE PutNet4*(VAR buf: ARRAY OF CHAR; ofs: SIZE; val: INTEGER);
CODE
#IF I386 THEN
	MOV EAX, [EBP+val]
	XCHG AL, AH
	ROL EAX, 16
	XCHG AL, AH
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV [ECX+EBX], EAX
#ELSIF AMD64 THEN
	MOV EAX, [RBP+val]
	XCHG AL, AH
	ROL EAX, 16
	XCHG AL, AH
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV [RCX+RBX], EAX
#ELSE
	unimplemented
#END
END PutNet4;

(** Put a 16-bit host value into buf[ofs..ofs+1] in network byte order *)

PROCEDURE PutNet2*(VAR buf: ARRAY OF CHAR; ofs: SIZE; val: INTEGER);
CODE
#IF I386 THEN
	MOV EAX, [EBP+val]
	XCHG AL, AH
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV [ECX+EBX], AX
#ELSIF AMD64 THEN
	MOV EAX, [RBP+val]
	XCHG AL, AH
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV [RCX+RBX], AX
#ELSE
	unimplemented
#END
END PutNet2;

(** Get a 32-bit network value from buf[ofs..ofs+3] in host byte order *)

PROCEDURE GetNet4*(CONST buf: ARRAY OF CHAR; ofs: SIZE): INTEGER;
CODE
#IF I386 THEN
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	MOV EAX, [ECX+EBX]
	XCHG AL, AH
	ROL EAX, 16
	XCHG AL, AH
#ELSIF AMD64 THEN
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	MOV EAX, [RCX+RBX]
	XCHG AL, AH
	ROL EAX, 16
	XCHG AL, AH
#ELSE
	unimplemented
#END
END GetNet4;

(** Get a 16-bit network value from buf[ofs..ofs+1] in host byte order *)

PROCEDURE GetNet2*(CONST buf: ARRAY OF CHAR; ofs: SIZE): INTEGER;
CODE
#IF I386 THEN
	MOV EBX, [EBP+ofs]
	MOV ECX, [EBP+buf]
	XOR EAX, EAX
	MOV AX, [ECX+EBX]
	XCHG AL, AH
#ELSIF AMD64 THEN
	MOV RBX, [RBP+ofs]
	MOV RCX, [RBP+buf]
	XOR EAX, EAX
	MOV AX, [RCX+RBX]
	XCHG AL, AH
#ELSE
	unimplemented
#END
END GetNet2;

(** Convert a LinkAdr to a printable string (up to size*3 characters) *)

PROCEDURE LinkAdrToStr*(VAR adr: LinkAdr; size: SIZE; VAR s: ARRAY OF CHAR);
VAR
	i, j: SIZE;
	hex: ARRAY 17 OF CHAR;
BEGIN
	ASSERT(LEN(s) >= size*3); (* enough space for largest result *)
	hex := "0123456789ABCDEF";
	i := 0;
	FOR j := 0 TO size-1 DO
		s[i] := hex[ORD(adr[j]) DIV 10H MOD 10H]; INC(i);
		s[i] := hex[ORD(adr[j]) MOD 10H]; INC(i);
		IF j = size-1 THEN s[i] := 0X ELSE s[i] := ":" END;
		INC(i);
	END;
END LinkAdrToStr;

(** Write a link address *)

PROCEDURE OutLinkAdr*(VAR adr: LinkAdr; size: SIZE);
VAR s: ARRAY MaxLinkAdrSize*3 OF CHAR;
BEGIN
	LinkAdrToStr(adr, size, s);
	KernelLog.String(s);
END OutLinkAdr;

(** Copy data from array to array *)
PROCEDURE Copy*(CONST from: ARRAY OF CHAR; VAR to: ARRAY OF CHAR; fofs, tofs, len: SIZE);
BEGIN
	IF len > 0 THEN
		ASSERT((fofs+len <= LEN(from)) & (tofs+len <= LEN(to)));
		SYSTEM.MOVE(ADDRESSOF(from[fofs]), ADDRESSOF(to[tofs]), len);
	END;
END Copy;

PROCEDURE Cleanup;
BEGIN
	registry.Enumerate(Finalize);
	Plugins.main.Remove(registry);
	WSock32.CleanUp;
END Cleanup;

BEGIN
	nofBuf := 0;
	nofFreeBuf := 0;

	NEW(registry, "Network", "Network interface drivers");
	WSock32.Startup;

	Modules.InstallTermHandler(Cleanup);
END Network.

(*
History:
10.10.2003	mvt	Complete redesign and additional implementation of buffer handling and upcall mechanism
17.10.2003	mvt	Changed the way of initialization and finalization (now only Constr/Finalize)
21.10.2003	mvt	Changed SetReceiver to InstallReceiver and RemoveReceiver
15.11.2003	mvt	Changed buffering to work with EXCLUSIVE sections instead of using locking and a semaphore.
16.11.2003	mvt	Added support for checksum calclulation by the device.
25.11.2003	mvt	Added l3ofs and l4ofs to Buffer type.
17.12.2003	mvt	Changed variable "linked" to method "Linked".
*)

(**
How to use the module:

The module is loaded as soon as it is used first. It needn't to be loaded explicitly at startup. It can also be unloaded an reloaded without reboot.

How to use a driver:

Network driver objects in Bluebottle are extensions of the Network.LinkDevice object. All loaded instances of network driver objects are registered in the registry Network.registry. To obtain access to a network driver, use the Get, Await or GetAll methods of this registry.

Example:
	VAR dev: Network.LinkDevice;
	dev := Network.registry.Get(""); (* if no name is specified, first device (or NIL) is returned *)

The Send method of LinkDevice is used to send a packet. The dst parameter specifies the link destination address (e.g., a 6-byte ethernet MAC address for an ethernet device). The type parameter specifies the link-layer protocol type (e.g. 800H when sending IP over ethernet). The source address of the packet is automatically generated by the device, if necessary.
For reasons of reducing buffer copying between network layers, the method allows 3 buffers to be passed:
The l3hdr, l4hdr, data, h3len, h4len, dofs and dlen fields specify 3 buffers:
One buffer for a layer 3 header, one for a layer 4 header and one for the payload of the packet. The buffers don't have to be filled like this. They are simply concatenated to one frame by the device driver. Therefore, each of them is allowed to be empty.

The layer 3 header is stored in: l3hdr[0..h3len-1]
The layer 4 header is stored in: l4hdr[0..h4len-1]
The payload is stored in data[dofs..dofs+dlen-1]

Example:
	CONST
		Type = 05555H;	(* link-layer protocol type *)
	VAR
		dlen: SIGNED32;
		l3hdr: ARRAY HdrLen OF CHAR;
		data: ARRAY MaxDataLen OF CHAR;

	(* - l3hdr[0..HdrLen-1] contains the layer 3 packet header.
		- data[0..dlen-1] contains the packet data.
		- there is no layer 4 header in this example, i.e. an empty buffer is passed (len=0)
	*)
	dev.Send(dev.broadcast, Type, l3hdr, l3hdr, data, HdrLen, 0, 0, dlen); (* send a broadcast packet *)

Packet receiving is driven by the driver object. A receiver interested in a specific type of packet registers itself using the InstallReceiver method. The type parameter specifies the link-layer protocol type, which must be unique. There can only be one receiver installed per type. When a packet arrives, the driver object looks at the protocol type and calls the specific receiver (if any is installed for this type).

Example:
	PROCEDURE Receiver(dev: Network.LinkDevice; type: SIGNED32; buffer: Network.Buffer);
	BEGIN
		ASSERT(type = Type);
		CheckAdr(buffer.src); (* some link layer source address checks *)
		IF ~(ChecksumForThisProtocol IN buffer.calcChecksum) THEN
			VerifyChecksum(buffer);
		END;
		ExamineLayer3Header(buffer.data, buffer.ofs, Layer3HeaderSize);
		ProcessPayload(buffer.data, buffer.ofs+Layer3HeaderSize, buffer.len-Header3LayerSize);

		(* MANDATORY!!
			Buffer must be returned here! - or at higher layers, if the buffer is passed there! *)
		Network.ReturnBuffer(buffer);
	END Receiver;

	dev.InstallReceiver(Type, Receiver); (* install the receiver *)

When passing the buffer to a higher layer (e.g. layer 4), the field "l3ofs" should be set in order to enable the higher layer protocol to access this layer's header (required by ICMP).
The same is valid for the field "l4ofs" when passing the buffer to a higher layer than 4.

The "type" field of a LinkDevice specifies what kind of device it is. Currently, two options (constants) are available:
- TypePointToPoint: dev is a point-to-point link (device), e.g. PPP
- TypeEthernet: dev is an ethernet device

For point-to-point links, the following rules are met:
In constructor, the "local" and "broadcast" parameters are ignored.
If it is not possible to transmit the layer 3 type of packet, the type is set to 0 for the received packet.
If the field "adrSize" is 0, the dst address parameter in Send() is ignored and the src address parameter in the Receiver is not defined.
If "adrSize" is > 0, the dst address passed in Send() is transmitted and presented as src address for the received packet.

The "local" and "broadcast" fields of the object specify the link-level address of the device, and the broadcast address, respectively. If needed, they have to be set during device initialization.
The mtu field specifies the largest allowed packet size in bytes, excluding layer 2 headers and trailers (e.g. 1500 for ethernet).

The "sendCount" and "recvCount" fields show the number of data bytes sent and received by the device since the driver object was loaded.

How to implement a driver:

IMPORTANT:
- Read first "How to use a driver"!
- Read comments of methods you override!

A network driver object is implemented by extending the LinkDevice object. At least the "DoSend" method has to be overridden with a concrete implementation. Normally, you will also override the constructor, the destructor (method "Finalize") and the method "Linked".

CAUTION:
If you override the constructor or destructor:
- At the beginning of the overriding constructor, the overridden constructor has to be called!
- At the end of the overriding destructor, the overridden destructor has to be called!

NOTE:
The device has to be registered and deregistered as a Plugin in Network.registry by the device driver as follows:
Add the device to the registry after it is ready to send/receive data!
Remove the device from the registry before you begin to deinitialize the device!

Normally, the device driver will have to install an interrupt handler for receiving packets. This handler must be installed in Objects. Interrupts registered in Machine are not allowed! (because they are not allowed to call QueueBuffer due to its EXCLUSIVE section)

If you use interrupts:
- do the minimum operations required for receiving and queueing a packet!
- return immediately after having done the operations!

Receiving and queueing packets is done like this:

When you are notified of an incomming network packet (normally by an interrupt), get a new buffer by calling:
buf := Network.GetNewBuffer();

If buf = NIL, the packet has to be discarded because all buffers are currently in use and the maximum amount of buffers (MaxNofBuffers) is exceeded.
If buf # NIL (the normal case), read the packet data into buf.data and set buf.ofs and buf.len accordingly.
The buffer is not initialized in any way.

If the device supports DMA, you could try to get the buffers earlier and pass their physical addesses to the device. With this you can save one packet copying operation!

In addition to the fields "data", "ofs", "len" of "buffer", it is mandatory to set the fields "src" and "calcChecksum" correctly. "src" is the link layer source address and "calcChecksum" is the set of checksums already verified by the device (normally {}).

As soon as the buffer contains the whole packet data, it is passed to the upper layers by calling:
QueueBuffer(buf, type);
Where "type" is the layer 3 type of the packet.

See TestNet.Mod (SendBroadcast, SendTest and Receiver) and IP.Mod (ARPRequest and ARPInput) for an example of packet sending and receiving. See Ethernet3Com90x.Mod for an example of an ethernet driver object and Loopback.Mod for a simple point-to-point link implementation.

*)
