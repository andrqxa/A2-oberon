MODULE DynamicStrings;	(** Stefan Walthert  *)
(** AUTHOR "swalthert"; PURPOSE "Dynamic strings"; *)

IMPORT
	Streams, Strings;

CONST
	CR* = 0DX; (** the Oberon end of line character *)
	Tab* = 09X; (** the horizontal tab character *)
	LF* = 0AX; (** the UNIX end of line character *)

	InitialSize = 256;
	HashTableSize = 256;
	InitialStringArraySize = 8;

	(* Gather statistics of string pool operations *)
	Statistics = TRUE;

TYPE
	String* = Strings.String;

	DynamicString* = OBJECT
	VAR
		buffer: String; (* { (buffer # NIL) & (LEN(buffer) = bufferSize) } *)
		bufferSize: SIZE; (* {bufferSize >= InitialSize} *)

		length : SIZE; (* current length of string excluding 0X *)

		PROCEDURE &Init*;
		BEGIN
			bufferSize := InitialSize;
			NEW(buffer, bufferSize);
			Clear;
		END Init;

		(* Set string to empty string without changing bufferSize *)
		PROCEDURE Clear*;
		BEGIN
			buffer[0] := 0X;
			length := 0;
		END Clear;

		PROCEDURE AdjustBufferSize(minSize: SIZE);
		VAR newBuffer : String;
		BEGIN
			IF minSize >= bufferSize THEN
				REPEAT bufferSize := 2 * bufferSize; UNTIL (bufferSize > minSize);
				NEW(newBuffer, bufferSize);
				COPY(buffer^, newBuffer^);
				buffer := newBuffer;
			END;
		END AdjustBufferSize;

		PROCEDURE Put*(ch: CHAR; at: SIZE);
		BEGIN
			IF (at + 1 >= bufferSize) THEN AdjustBufferSize(at + 1); END;
			buffer[at] := ch;
			length := StringLength(buffer^); (* not optimized *)
		END Put;

		PROCEDURE Get*(at: SIZE): CHAR;
		BEGIN
			IF at + 1 > bufferSize THEN
				RETURN 0X;
			ELSE
				RETURN buffer[at];
			END;
		END Get;

		PROCEDURE AppendCharacter*(ch : CHAR);
		BEGIN
			IF (ch # 0X) THEN
				IF (length + 1 + 1 >= bufferSize) THEN AdjustBufferSize(length + 1 + 1); END;
				buffer[length] := ch;
				buffer[length + 1] := 0X;
				INC(length);
			END;
		END AppendCharacter;

		PROCEDURE Append*(CONST this: ARRAY OF CHAR);
		VAR thisLength : SIZE;
		BEGIN
			thisLength := StringLength(this);
			IF (length + thisLength + 1 >= bufferSize) THEN AdjustBufferSize(length + thisLength + 1); END;
			Strings.Append(buffer^, this);
			length := length + thisLength;
		END Append;

		PROCEDURE Extract*(offset, len: SIZE): String;
		VAR s: String; i: SIZE;
		BEGIN
			IF offset < length THEN
				IF offset + len > length THEN len := length - offset END;
				NEW(s, len + 1);
				FOR i := 0 TO len - 1 DO
					s[i] := buffer[i + offset]
				END;
				s[len] := 0X;
			ELSE
				NEW(s, 1); s[0] := 0X;
			END;
			RETURN s
		END Extract;

		PROCEDURE Length*(): SIZE;
		BEGIN
			RETURN length;
		END Length;

		PROCEDURE ToArrOfChar*(): String;
		VAR string: String;
		BEGIN
			NEW(string, length + 1);
			COPY(buffer^, string^);
			RETURN string;
		END ToArrOfChar;

		PROCEDURE FromArrOfChar*(s: String);
		BEGIN
			length := StringLength(s^);
			NEW(buffer, length + 1);
			COPY(s^, buffer^);
		END FromArrOfChar;

		(** Copy <len> characters starting at <offset> from string <ds> into this dynamic string*)
		PROCEDURE CopyFrom*(ds : DynamicString; offset, len : SIZE);
		VAR i : SIZE;
		BEGIN
			ASSERT((ds # NIL) & (offset >= 0) & (len >= 0));
			IF (offset < length) THEN
				IF (offset + len > length) THEN len := length - offset; END;
				AdjustBufferSize(len + 1);
				FOR i := 0 TO len - 1 DO
					buffer[i] := ds.buffer[i + offset];
				END;
				buffer[len] := 0X;
				length := len;
			ELSE
				buffer[0] := 0X;
				length := 0;
			END;
		END CopyFrom;

		PROCEDURE EqualsTo*(CONST string : ARRAY OF CHAR; ignoreCase : BOOLEAN) : BOOLEAN;
		VAR len : SIZE; result : BOOLEAN; i : SIZE;
		BEGIN
			len := StringLength(string);
			result := (len = length);
			IF result THEN
				i := 0;
				IF ignoreCase THEN
					WHILE result & (i < length) DO
						result := Strings.UP(string[i]) = Strings.UP(buffer[i]);
						INC(i);
					END;
				ELSE
					WHILE result & (i < length) DO
						result := string[i] = buffer[i];
						INC(i);
					END;
				END;
			END;
			RETURN result;
		END EqualsTo;

	END DynamicString;

TYPE

	StringEntry = RECORD
		value : String;
		length : SIZE;
	END;

	StringEntryArray = POINTER TO ARRAY OF StringEntry;

	HashTableEntry = RECORD
		strings : StringEntryArray; (* {strings # NIL} *)
		nofStrings : SIZE; (* { (0 <= nofStrings) & (nofStrings < LEN(strings)) } *)
	END;

	Pool* = OBJECT
	VAR
		hashtable : ARRAY HashTableSize OF HashTableEntry;

		PROCEDURE &Init*;
		VAR i : SIZE;
		BEGIN
			FOR i := 0 TO LEN(hashtable) - 1 DO
				NEW(hashtable[i].strings, InitialStringArraySize);
			END;
			Clear;
		END Init;

		PROCEDURE Clear*;
		VAR i, j : SIZE;
		BEGIN
			FOR i := 0 TO LEN(hashtable) - 1 DO
				FOR j := 0 TO LEN(hashtable[i].strings) - 1 DO
					hashtable[i].strings[j].value := NIL;
					hashtable[i].strings[j].length := 0;
				END;
				hashtable[i].nofStrings := 0;
			END;
		END Clear;

		(* Compute index into hashtable (copied from StringPool.Mod) *)
		PROCEDURE Hash(ds : DynamicString) : SIZE;
		VAR index, i : SIZE; ch : CHAR;
		BEGIN
			ASSERT(ds # NIL);
			index := 0;
			i := 0; ch := ds.buffer[0]; index := 0;
			WHILE (ch # 0X) DO
				index := SIZE(SET(ROT(index, 7)) / SET(ORD(ch)));
				INC(i); ch := ds.buffer[i]
			END;
			index := index MOD HashTableSize;
			ASSERT((0 <= index) & (index < HashTableSize));
			RETURN index;
		END Hash;

		PROCEDURE Find(ds : DynamicString) : Strings.String;
		VAR string : String; entry : HashTableEntry; i : SIZE;
		BEGIN
			ASSERT(ds # NIL);
			string := NIL;
			entry := hashtable[Hash(ds)];
			(* skip entries that are shorter and/or lexically smaller *)
			i := 0; WHILE (i < entry.nofStrings) & LessThan(ds, entry.strings[i]) DO INC(i); END;
			(* compare candidates *)
			WHILE (string = NIL) & (i < entry.nofStrings) & ~GreaterThan(ds, entry.strings[i]) DO
				IF (ds.length = entry.strings[i].length) & Equals(ds, entry.strings[i]) THEN
					string := entry.strings[i].value;
				END;
				INC(i);
			END;
			RETURN string;
		END Find;

		(* Double the size of the StringEntryArray within <entry> *)
		PROCEDURE Grow(VAR strings : StringEntryArray);
		VAR newStrings : StringEntryArray; i : SIZE;
		BEGIN
			NEW(newStrings, 2 * LEN(strings));
			FOR i := 0 TO LEN(strings) - 1 DO
				newStrings[i] := strings[i];
			END;
			strings := newStrings;
		END Grow;

		PROCEDURE Add(ds : DynamicString; index : SIZE; VAR string : String);
		VAR (*entry : HashTableEntry;*)  i, j : SIZE; (*! careful: entry is a record, not a pointer *)
		BEGIN (* assumption: ds is not yet contained in pool! *)
			ASSERT(ds # NIL);
			ASSERT((0 <= index) & (index < HashTableSize));
			(*
			entry := hashtable[index];
			*)
			IF (hashtable[index].nofStrings >= LEN(hashtable[index].strings)) THEN Grow(hashtable[index].strings); END;
			(* skip entries that are lexically less than *)
			i := 0; WHILE (i < hashtable[index].nofStrings) & LessThan(ds, hashtable[index].strings[i]) DO INC(i); END;
			(* move strings to the right to make place for new string at index i *)
			j := hashtable[index].nofStrings - 1;
			WHILE (j >= i) DO
				hashtable[index].strings[j + 1] := hashtable[index].strings[j];
				DEC(j);
			END;
			(* insert new string *)
			string := ds.ToArrOfChar();
			hashtable[index].strings[i].value := string;
			hashtable[index].strings[i].length := ds.length;
			INC(hashtable[index].nofStrings);
			ASSERT(string # NIL);
		END Add;

		(** Get string from pool. If the string is not contained in the pool, a copy of it is added to the pool *)
		PROCEDURE Get*(ds : DynamicString) : Strings.String;
		VAR string : String;
		BEGIN
			ASSERT(ds # NIL);
			IF Statistics THEN INC(NnofRequests); END;
			string := Find(ds);
			IF (string = NIL) THEN
				IF Statistics THEN INC(NnofAdded); END;
				Add(ds, Hash(ds), string);
			ELSIF Statistics THEN
				INC(NnofHits);
			END;
			ASSERT(string # NIL);
			RETURN string;
		END Get;

		PROCEDURE Dump*(out : Streams.Writer);
		VAR index, entry : SIZE;
		BEGIN
			ASSERT(out # NIL);
			out.String("String pool dump:");
			FOR index := 0 TO LEN(hashtable) - 1 DO
				IF (hashtable[index].nofStrings # 0) THEN
					out.Int(hashtable[index].nofStrings, 0); out.String(" entries at index ");
					out.Int(index, 0); out.String(": "); out.Ln;
					FOR entry := 0 TO hashtable[index].nofStrings - 1 DO
						out.String("    "); out.String(hashtable[index].strings[entry].value^);
						out.String(", length = "); out.Int(hashtable[index].strings[entry].length, 0);
						out.Ln;
					END;
				END;
			END;
			out.Ln;
		END Dump;

	END Pool;

VAR
	(* Statistics, not multi-instance capable *)
	NnofRequests, NnofHits, NnofAdded : SIZE;

(* Returns TRUE if the string ds.buffer is shorter or lexically smaller than entry.value *)
PROCEDURE LessThan(ds : DynamicString; CONST entry : StringEntry) : BOOLEAN;
VAR lessThan : BOOLEAN; i : SIZE;
BEGIN
	i := 0;
	lessThan := (ds.length < entry.length);
	WHILE ~lessThan & (i < entry.length) DO
		lessThan := (ds.buffer[i] < entry.value[i]);
		INC(i);
	END;
	RETURN lessThan;
END LessThan;

(* Returns TRUE if the string ds.buffer is larger or lexically greater than entry.value *)
PROCEDURE GreaterThan(ds : DynamicString; CONST entry : StringEntry) : BOOLEAN;
VAR greaterThan : BOOLEAN; i : SIZE;
BEGIN
	i := 0;
	greaterThan := (ds.length > entry.length);
	WHILE ~greaterThan & (i < ds.length) DO
		greaterThan := (ds.buffer[i] > entry.value[i]);
		INC(i);
	END;
	RETURN greaterThan;
END GreaterThan;

(* Return TRUE if the string ds.buffer has same length and content as entry.value *)
PROCEDURE Equals(ds : DynamicString; CONST entry : StringEntry) : BOOLEAN;
VAR equals : BOOLEAN; i : SIZE;
BEGIN
	i := 0;
	equals := (ds.length = entry.length);
	WHILE equals & (i < ds.length) DO
		equals := (ds.buffer[i] = entry.value[i]);
		INC(i);
	END;
	RETURN equals;
END Equals;

PROCEDURE StringLength*(CONST str: ARRAY OF CHAR): SIZE;
	VAR i, l: SIZE;
BEGIN
	l := LEN(str); i := 0;
	WHILE (i < l) & (str[i] # 0X) DO
		INC(i)
	END;
	RETURN i
END StringLength;

PROCEDURE StringAppend*(VAR to: ARRAY OF CHAR; CONST this: ARRAY OF CHAR);
BEGIN Strings.Append (to, this);
END StringAppend;

PROCEDURE Lower*(CONST str: ARRAY OF CHAR; VAR lstr: ARRAY OF CHAR);
	VAR i: SIZE;
BEGIN
	i := 0;
	WHILE str[i] # 0X DO
		lstr[i] := LowerCh(str[i]); INC(i)
	END;
	lstr[i] := 0X
END Lower;

PROCEDURE LowerCh*(ch: CHAR): CHAR;
BEGIN
	CASE ch OF
		"A" .. "Z": ch := CHR(ORD(ch)-ORD("A")+ORD("a"))
(*		|"Ä": ch := "ä"
		|"Ö": ch := "ö"
		|"Ü": ch := "ü" *)
	ELSE
	END;
	RETURN ch
END LowerCh;

PROCEDURE Search*(CONST pat, src: ARRAY OF CHAR; VAR pos: SIZE);
	CONST MaxPat = 128;
	VAR
		buf: ARRAY MaxPat OF CHAR;
		len, i, srclen: SIZE;

	PROCEDURE Find(beg: SIZE);
		VAR
			i, j, b, e: SIZE;
			ch: CHAR;
			ref: ARRAY MaxPat OF CHAR;
	BEGIN
		ch := src[pos]; INC(pos);
		ref[0] := ch;
		i := 0; j := 0; b := 0; e := 1;
		WHILE (pos <= srclen) & (i < len) DO
			IF buf[i] = ch THEN
				INC(i); j := (j + 1) MOD MaxPat
			ELSE
				i := 0; b := (b + 1) MOD MaxPat; j := b
			END;
			IF j # e THEN
				ch := ref[j]
			ELSE
				IF pos >= srclen THEN
					ch := 0X
				ELSE
					ch := src[pos]
				END;
				INC(pos); ref[j] := ch; e := (e + 1) MOD MaxPat; INC(beg);
			END
		END;
		IF i = len THEN
			pos := beg-len
		ELSE
			pos := -1
		END
	END Find;

BEGIN
	len := StringLength(pat);
	IF MaxPat < len THEN
		len := MaxPat
	END;
	IF len <= 0 THEN
		pos := -1;
		RETURN
	END;
	i := 0;
	REPEAT
		buf[i] := pat[i]; INC(i)
	UNTIL i >= len;
	srclen := StringLength(src);
	IF pos < 0 THEN
		pos := 0
	ELSIF pos >= srclen THEN
		pos := -1;
		RETURN
	END;
	Find(pos)
END Search;

PROCEDURE ClearStatistics*;
BEGIN
	NnofRequests := 0;
	NnofHits := 0;
	NnofAdded := 0;
END ClearStatistics;

BEGIN
	ClearStatistics;
END DynamicStrings.

DynamicStrings.ClearStatistics ~

WMPerfMonPluginModVars.Install StringPool
	DynamicStrings.NnofRequests DynamicStrings.NnofHits DynamicStrings.NnofAdded
~
