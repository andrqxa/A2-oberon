MODULE CRC; (** AUTHOR "prk/TF"; PURPOSE "CRC utilities"; *)
(**
 * History:
 *
 *	28.09.2000	added CRC32 support -- TF
 *	08.01.2007	added SetCRC procedures to enable other initial values (staubesv)
 *)

IMPORT
	SYSTEM, Streams;

CONST
	Init16 = -1;	(* initial CRC16 value *)
	Init32 = SIGNED32(0FFFFFFFFH)  ;  (* initial CRC32 value *)

TYPE
	CRC16Stream* = OBJECT(Streams.Writer)
	VAR
		crc* : SIGNED16;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := Init16;
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: WORD);
			VAR fcs, idx: SET; i: SIZE;
		BEGIN
			fcs := SYSTEM.VAL( SET, crc ) * SYSTEM.VAL( SET, 0FFFFH );
			FOR i := ofs TO ofs + len - 1 DO
				idx := SYSTEM.VAL( SET, SYSTEM.VAL( SIGNED32, fcs ) DIV 256 ) / SYSTEM.VAL( SET, LONG( ORD( buf[i] ) ) );
				fcs := CRC16Table[SYSTEM.VAL( SIGNED32, idx) MOD 256] / SYSTEM.VAL( SET, SYSTEM.VAL( SIGNED32, fcs ) * 256 )
			END;
			crc := SHORT( SYSTEM.VAL( SIGNED32, fcs * SYSTEM.VAL( SET, 0FFFFH ) ) );
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : SIGNED16);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*(): SIGNED16;
		BEGIN
			Update();
			RETURN crc
		END GetCRC;

	END CRC16Stream;

	CRC32Stream* = OBJECT(Streams.Writer)
	VAR
		crc : SIGNED32;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := Init32;
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Reset*;
		BEGIN
			Update();
			crc := Init32
		END Reset;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: WORD);
		VAR idx: SIGNED32;
		BEGIN
			WHILE len > 0 DO
				idx := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, crc) / SYSTEM.VAL(SET, LONG(ORD(buf[ofs])))) MOD 100H;
				crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
				DEC(len); INC(ofs)
			END;
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : SIGNED32);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*():SIGNED32;
		BEGIN
			Update();
			RETURN SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, crc)/{0..31})
		END GetCRC;

		PROCEDURE GetUninvertedCRC*():SIGNED32;
		BEGIN
			Update();
			RETURN crc
		END GetUninvertedCRC;
	END CRC32Stream;


TYPE CRC32*= OBJECT
	VAR crc : SIGNED32;

		PROCEDURE  &Init*;
		BEGIN
			crc := SIGNED32(0FFFFFFFFH);
		END Init;

		(* standard use: one character at a time *)
		PROCEDURE Char*(c: CHAR);
		VAR idx: SIGNED32;
		BEGIN
			idx := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, crc) / SYSTEM.VAL(SET, LONG(ORD(c)))) MOD 100H;
			crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
		END Char;

		(* nonstandard use - add a SIGNED32; LSB *)
		PROCEDURE Add*(i: SIGNED32);
		VAR idx: SIGNED32;
		BEGIN
			i:= SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, crc) / SYSTEM.VAL(SET, i));
			idx := i MOD 100H;
			crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
			idx := i DIV 100H MOD 100H;
			crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
			idx := i DIV 10000H MOD 100H;
			crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
			idx := i DIV 1000000H MOD 100H;
			crc := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, CRC32Table[idx])/SYSTEM.VAL(SET, LSH(crc, -8)));
		END Add;

		PROCEDURE Get*():SIGNED32;
		BEGIN
			RETURN SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, crc)/{0..31})
		END Get;

	END CRC32;

VAR
	CRC16Table, CRC32Table: ARRAY 256 OF SET;

	PROCEDURE InitTable16;
	VAR fcs, t: SET;  d, i, k: SIGNED32;
	BEGIN
		FOR i := 0 TO 255 DO
			fcs := { };  d := i*256;
			FOR k := 0 TO 7 DO
				t := fcs;  fcs := SYSTEM.VAL( SET, SYSTEM.VAL( SIGNED32, fcs ) * 2 );
				IF (t / SYSTEM.VAL( SET, d )) * SYSTEM.VAL( SET, 8000H ) # {} THEN  fcs := fcs / SYSTEM.VAL( SET, 1021H ) END;
				d := d * 2
			END;
			CRC16Table[i] := fcs * SYSTEM.VAL( SET, 0FFFFH )
		END
	END InitTable16;

	PROCEDURE InitTable32;
	CONST poly = SIGNED32(0EDB88320H);
	VAR n, c, k: SIGNED32;
	BEGIN
		FOR n := 0 TO 255 DO
			c := n;
			FOR k := 0 TO 7 DO
				IF ODD(c) THEN c := SYSTEM.VAL(SIGNED32, SYSTEM.VAL(SET, poly) / SYSTEM.VAL(SET, LSH(c, -1)))
				ELSE c := LSH(c, -1)
				END
			END;
			CRC32Table[n] := SYSTEM.VAL(SET, c)
		END
	END InitTable32;

BEGIN
	InitTable16;
	InitTable32
END CRC.

System.Free CRC ~
