MODULE Models; (** AUTHOR "staubesv"; PURPOSE "Models"; *)

IMPORT
	Streams, Locks, Types, Strings, XML, Texts, TextUtilities, Repositories, XMLObjects;

CONST
	Ok* = Types.Ok;

	(** Notification mode *)
	NoNotifications* = 0; (** No notification of listeners upon changes *)
	OnChanged* = 1; (** Notify listeners when model value has changed after releasing the write lock *)


	InitialStringSize = 128;

	AttributeName = "name";

TYPE

	(**
		Base class of models.
		Services:
			- Abstract interface for generic read/write access
			- Recursive reader/writer lock
			- Notification of listeners
			- Internalization/externalization
	*)
	Model* = OBJECT(Repositories.Component)
	VAR
		changed : BOOLEAN;
		notificationMode : SIGNED8;
		lock : Locks.RWLock;

		PROCEDURE &Init*; (** protected *)
		BEGIN
			Init^;
			notificationMode := OnChanged;
			changed := FALSE;
			NEW(lock);
		END Init;

	(** Generic access to data of the model using type conversion *)

		(** Generically set data of model. Implicit type conversion if necessary and possible *)
		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER); (** abstract *)
		END SetGeneric;

		(** Generically get data of model. Implicit type conversion if necessary and possible *)
		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER); (** abstract *)
		END GetGeneric;

	(** Locking (Recursive reader/writer lock) *)

		(** Acquire read lock. *)
		PROCEDURE AcquireRead*;
		BEGIN
			lock.AcquireRead;
		END AcquireRead;

		(** Release read lock *)
		PROCEDURE ReleaseRead*;
		BEGIN
			lock.ReleaseRead;
		END ReleaseRead;

		(** Returns TRUE if the caller holds a read lock, FALSE otherwise *)
		PROCEDURE HasReadLock*() : BOOLEAN;
		BEGIN
			RETURN lock.HasReadLock();
		END HasReadLock;

		(** Acquire write lock *)
		PROCEDURE AcquireWrite*;
		BEGIN
			lock.AcquireWrite;
		END AcquireWrite;

		(** Release write lock. If the data has changed, all listeners will be notified when the last
			writer releases its lock *)
		PROCEDURE ReleaseWrite*;
		VAR notifyListeners : BOOLEAN;
		BEGIN
			(* If the last writer releases the lock and the model data has changed, we have to notify interested listeners *)
			IF (lock.GetWLockLevel() = 1) THEN
				IF (notificationMode = OnChanged) THEN
					notifyListeners := changed;
					changed := FALSE;
				ELSE
					notifyListeners := FALSE;
				END;
			ELSE
				notifyListeners := FALSE;
			END;
			lock.ReleaseWrite;
			IF notifyListeners THEN
				onChanged.Call(SELF);
			END;
		END ReleaseWrite;

		(** Returns TRUE if the caller holds the writer lock, FALSE otherwise *)
		PROCEDURE HasWriteLock*() : BOOLEAN;
		BEGIN
			RETURN lock.HasWriteLock();
		END HasWriteLock;

	(** Change notification *)

		(** Set how the model notifies listeners upon value changes *)
		PROCEDURE SetNotificationMode*(mode : SIGNED8);
		BEGIN
			ASSERT((mode = NoNotifications) OR (mode = OnChanged));
			lock.AcquireWrite;
			IF (notificationMode # mode) THEN
				notificationMode := mode;
			END;
			(*	the release of the write lock will cause notification if model value has changed and
				notification was disabled before *)
			lock.ReleaseWrite;
		END SetNotificationMode;

		(** 	Indicate that the value of the model has changed. Listeners will be notified when the writer lock
			is released. Caller must hold write lock! *)
		PROCEDURE Changed*; (** protected *)
		BEGIN
			ASSERT(HasWriteLock());
			changed := TRUE;
		END Changed;

	(** Internalization and externalization *)

		PROCEDURE AddContent*(content : XML.Content); (** overwrite, protected *)
		VAR string : Types.String; res : INTEGER;
		BEGIN
			IF (content # NIL) & (content IS XML.Element) & (content(XML.Element).GetName()^="VALUE") THEN
				content := content(XML.Element).GetFirst();
			END;

			IF (SELF IS Container) THEN
				AddContent^(content);
			ELSIF (content # NIL) & (content IS XML.ArrayChars) THEN
				(* This violates the XML document structure. Could be fixed by allowing XML.ArrayChars SET and GET
					procedures that dynamically set/get the model data as string *)
				string.value := content(XML.ArrayChars).GetStr();
				IF (string.value # NIL) THEN
					SetGeneric(string, res); (* ignore res *)
				END;
			ELSIF (content # NIL) THEN AddContent^(content);
			ELSE (* empty content, does not have to add content *)
			END;
		END AddContent;

		(** Write current data value of model to stream <w> at indention level <level>. Caller must hold read lock *)
		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32);
		BEGIN
			ASSERT(w # NIL);
			ASSERT(HasReadLock());
		END WriteValue;

		(** Externalize model to stream <w> at indention level <level> *)
		PROCEDURE Write*(w: Streams.Writer; context: ANY; level : SIGNED32); (** overwrite *)
		VAR name : Strings.String; enum: XMLObjects.Enumerator; c: ANY;
		BEGIN
			IF (SELF IS Container) THEN
				Write^(w, context, level);
			ELSE
				(* Hmm... this violates the idea of XML.Element as container *)
				AcquireRead;
				name := GetName();
				w.Char('<'); w.String(name^); WriteAttributes(w, context, level); w.Char('>');
				NewLine(w,level+1);
				w.String("<VALUE>");
				WriteValue(w, level + 1);
				w.String("</VALUE>");

				enum := GetContents();
				WHILE enum.HasMoreElements() DO
					c := enum.GetNext();
					c(XML.Content).Write(w, context, level+1);
				END;
				NewLine(w,level);
				w.String("</"); w.String(name^); w.Char('>');
				ReleaseRead;
			END;
		END Write;

	END Model;

TYPE

	Boolean* = OBJECT(Model)
	VAR
		value : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrBoolean);
			value := FALSE;
			SetGenerator("Models.GenBoolean");
		END Init;

		PROCEDURE Set*(value : BOOLEAN);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : BOOLEAN;
		VAR value : BOOLEAN;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : BOOLEAN;
		BEGIN
			Types.GetBoolean(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : BOOLEAN;
		BEGIN
			currentValue := Get();
			Types.SetBoolean(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			IF value THEN w.String("TRUE"); ELSE w.String("FALSE"); END;
		END WriteValue;

	END Boolean;

TYPE

	Integer* = OBJECT(Model)
	VAR
		value : SIGNED32;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrInteger);
			value := 0;
			SetGenerator("Models.GenInteger");
		END Init;

		PROCEDURE Set*(value : SIGNED32);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : SIGNED32;
		VAR value : SIGNED32;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Add*(value : SIGNED32);
		BEGIN
			IF (value # 0) THEN
				AcquireWrite;
				SELF.value := SELF.value + value;
				Changed;
				ReleaseWrite;
			END;
		END Add;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : SIGNED32;
		BEGIN
			Types.GetInteger(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : SIGNED32;
		BEGIN
			currentValue := Get();
			Types.SetInteger(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Int(value, 0);
		END WriteValue;

	END Integer;

	UInt32* = OBJECT(Model)
	VAR
		value : UNSIGNED32;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrUInt32);
			value := 0;
			SetGenerator("Models.GenUInt32");
		END Init;

		PROCEDURE Set*(value : UNSIGNED32);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : UNSIGNED32;
		VAR value : UNSIGNED32;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Add*(value : UNSIGNED32);
		BEGIN
			IF (value # 0) THEN
				AcquireWrite;
				SELF.value := SELF.value + value;
				Changed;
				ReleaseWrite;
			END;
		END Add;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : UNSIGNED32;
		BEGIN
			Types.GetUInt32(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : UNSIGNED32;
		BEGIN
			currentValue := Get();
			Types.SetUInt32(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.UInt(value, 0);
		END WriteValue;

	END UInt32;

	Hugeint* = OBJECT(Model)
	VAR
		value : SIGNED64;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrHugeint);
			value := 0;
			SetGenerator("Models.GenHugeint");
		END Init;

		PROCEDURE Set*(value : SIGNED64);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : SIGNED64;
		VAR value : SIGNED64;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Add*(value : SIGNED64);
		BEGIN
			IF (value # 0) THEN
				AcquireWrite;
				SELF.value := SELF.value + value;
				Changed;
				ReleaseWrite;
			END;
		END Add;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : SIGNED64;
		BEGIN
			Types.GetHugeint(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : SIGNED64;
		BEGIN
			currentValue := Get();
			Types.SetHugeint(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Int(value, 0);
		END WriteValue;

	END Hugeint;

	UInt64* = OBJECT(Model)
	VAR
		value : UNSIGNED64;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrUInt64);
			value := 0;
			SetGenerator("Models.GenUInt64");
		END Init;

		PROCEDURE Set*(value : UNSIGNED64);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : UNSIGNED64;
		VAR value : UNSIGNED64;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Add*(value : UNSIGNED64);
		BEGIN
			IF (value # 0) THEN
				AcquireWrite;
				SELF.value := SELF.value + value;
				Changed;
				ReleaseWrite;
			END;
		END Add;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : UNSIGNED64;
		BEGIN
			Types.GetUInt64(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : UNSIGNED64;
		BEGIN
			currentValue := Get();
			Types.SetUInt64(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.UInt(value, 0);
		END WriteValue;

	END UInt64;

	Size* = OBJECT(Model)
	VAR
		value : SIZE;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrSize);
			value := 0;
			SetGenerator("Models.GenSize");
		END Init;

		PROCEDURE Set*(value : SIZE);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : SIZE;
		VAR value : SIZE;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Add*(value : SIZE);
		BEGIN
			IF (value # 0) THEN
				AcquireWrite;
				SELF.value := SELF.value + value;
				Changed;
				ReleaseWrite;
			END;
		END Add;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : SIZE;
		BEGIN
			Types.GetSize(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : SIZE;
		BEGIN
			currentValue := Get();
			Types.SetSize(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Int(value, 0);
		END WriteValue;

	END Size;

TYPE

	Real* = OBJECT(Model)
	VAR
		value : FLOAT32;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrReal);
			value := 0.0;
			SetGenerator("Models.GenReal");
		END Init;

		PROCEDURE Set*(value : FLOAT32);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : FLOAT32;
		VAR value : FLOAT32;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : FLOAT32;
		BEGIN
			Types.GetReal(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : FLOAT32;
		BEGIN
			currentValue := Get();
			Types.SetReal(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Float(value, 15); (*8 decimal, 'E-', 2 expo, decimal point, leading space*)
		END WriteValue;

	END Real;

TYPE

	Longreal* = OBJECT(Model)
	VAR
		value : FLOAT64;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrLongreal);
			value := 0.0;
			SetGenerator("Models.GenLongreal");
		END Init;

		PROCEDURE Set*(value : FLOAT64);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : FLOAT64;
		VAR value : FLOAT64;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : FLOAT64;
		BEGIN
			Types.GetLongreal(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : FLOAT64;
		BEGIN
			currentValue := Get();
			Types.SetLongreal(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Float(value, 24); (* leading space, decimal point, 16 digits, 5 expo *)
		END WriteValue;

	END Longreal;

TYPE

	Char* = OBJECT(Model)
	VAR
		value : CHAR;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrChar);
			value := 0X;
			SetGenerator("Models.GenChar");
		END Init;

		PROCEDURE Set*(value : CHAR);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : CHAR;
		VAR value : CHAR;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : CHAR;
		BEGIN
			Types.GetChar(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : CHAR;
		BEGIN
			currentValue := Get();
			Types.SetChar(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			IF IsPrintableCharacter(value) THEN
				w.Char(value);
			ELSE
				w.String("0x"); w.Int(ORD(value), 0); (*? TBD Support in Types.Mod *)
			END;
		END WriteValue;

	END Char;

TYPE

	(** 0X-terminated string (no Unicode support here! *)
	String* = OBJECT(Model)
	VAR
		value : Strings.String; (* {value # NIL} *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			NEW(value, InitialStringSize);
			SetNameAsString(StrString);
			SetGenerator("Models.GenString");
		END Init;

		PROCEDURE Set*(value : Strings.String);
		BEGIN
			ASSERT(value # NIL); (*? CHECK *)
			AcquireWrite;
			IF (value # SELF.value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : Strings.String;
		VAR value : Strings.String;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			ASSERT(value # NIL);
			RETURN value;
		END Get;

		PROCEDURE SetAOC*(CONST value : ARRAY OF CHAR);
		VAR length : SIGNED32;
		BEGIN
			length := 0;
			WHILE (length < LEN(value)) & (value[length] # 0X) DO INC(length); END;
			AcquireWrite;
			IF (length+1 > LEN(SELF.value^)) THEN
				SELF.value := Strings.NewString(value);
				Changed;
			ELSIF (SELF.value^ # value) THEN
				COPY(value, SELF.value^);
				Changed;
			END;
			ASSERT(SELF.value # NIL);
			ReleaseWrite;
		END SetAOC;

		PROCEDURE GetAOC*(VAR value : ARRAY OF CHAR);
		BEGIN
			AcquireRead;
			COPY(SELF.value^, value);
			ReleaseRead;
		END GetAOC;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : Strings.String;
		BEGIN
			Types.GetString(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : Strings.String;
		BEGIN
			currentValue := Get();
			Types.SetString(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		VAR res : INTEGER;
		BEGIN
			WriteValue^(w, level);
			XML.UTF8ToStream(value^, w, res); (* ignore res *)
		END WriteValue;

	END String;

TYPE

	Set* = OBJECT(Model)
	VAR
		value : SET;

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrSet);
			value := {};
			SetGenerator("Models.GenSet");
		END Init;

		PROCEDURE Set*(value : SET);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value := value;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE Get*() : SET;
		VAR value : SET;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE Include*(element : SIGNED32);
		BEGIN
			AcquireWrite;
			IF ~(element IN SELF.value) THEN
				INCL(SELF.value, element);
				Changed;
			END;
			ReleaseWrite;
		END Include;

		PROCEDURE Exclude*(element : SIGNED32);
		BEGIN
			AcquireWrite;
			IF (element IN SELF.value) THEN
				EXCL(SELF.value, element);
				Changed;
			END;
			ReleaseWrite;
		END Exclude;

		PROCEDURE Contains*(element : SIGNED32) : BOOLEAN;
		VAR result : BOOLEAN;
		BEGIN
			AcquireRead;
			result := element IN SELF.value;
			ReleaseRead;
			RETURN result;
		END Contains;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : SET;
		BEGIN
			Types.GetSet(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : SET;
		BEGIN
			currentValue := Get();
			Types.SetSet(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			w.Set(value);
		END WriteValue;

	END Set;

TYPE

	(*? would make more sense to Texts.UnicodeText to be the model itself *)
	Text* = OBJECT(Model)
	VAR
		value : Texts.Text; (* {value # NIL} *)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrText);
			NEW(value); value.onTextChanged.Add(OnTextChanged);
			SetGenerator("Models.GenText");
		END Init;

		PROCEDURE AcquireRead*;
		BEGIN
			value.AcquireRead;
		END AcquireRead;

		PROCEDURE ReleaseRead*;
		BEGIN
			value.ReleaseRead;
		END ReleaseRead;

		PROCEDURE HasReadLock*() : BOOLEAN;
		BEGIN
			RETURN value.HasReadLock();
		END HasReadLock;

		PROCEDURE AcquireWrite*;
		BEGIN
			value.AcquireWrite;
		END AcquireWrite;

		PROCEDURE ReleaseWrite*;
		BEGIN
			value.ReleaseWrite;
			onChanged.Call(SELF); (*? TBD only call when text has changed *)
		END ReleaseWrite;

		PROCEDURE HasWriteLock*() : BOOLEAN;
		BEGIN
			RETURN value.HasWriteLock();
		END HasWriteLock;

		(* will copy text! *)
		PROCEDURE Set*(value : Texts.Text);
		BEGIN
			AcquireWrite;
			IF (SELF.value # value) THEN
				SELF.value.Delete(0, SELF.value.GetLength());
				value.AcquireRead;
				SELF.value.CopyFromText(value, 0, value.GetLength(), 0);
				value.ReleaseRead;
				Changed;
			END;
			ReleaseWrite;
		END Set;

		PROCEDURE SetReference*(value: Texts.Text);
		BEGIN
			SELF.value := value;
			AcquireWrite;
			Changed;
			ReleaseWrite;
		END SetReference;

		PROCEDURE Get*() : Texts.Text;
		VAR value : Texts.Text;
		BEGIN
			AcquireRead;
			value := SELF.value;
			ReleaseRead;
			RETURN value;
		END Get;

		PROCEDURE OnTextChanged(sender, data : ANY);
		BEGIN
			Changed;
		END OnTextChanged;

		PROCEDURE SetAsString*(CONST string : ARRAY OF CHAR);
		BEGIN
			value.AcquireWrite;
			value.Delete(0, value.GetLength());
			TextUtilities.StrToText(value, 0, string);
			ReleaseWrite;
		END SetAsString;

		PROCEDURE GetAsString*(VAR string : ARRAY OF CHAR);
		BEGIN
			AcquireRead;
			TextUtilities.TextToStr(value, string);
			ReleaseRead;
		END GetAsString;

		PROCEDURE SetGeneric*(CONST value : Types.Any; VAR res : INTEGER);
		VAR newValue : Texts.Text;
		BEGIN
			Types.GetText(value, newValue, res);
			IF (res = Types.Ok) THEN Set(newValue); END;
		END SetGeneric;

		PROCEDURE GetGeneric*(VAR value : Types.Any; VAR res : INTEGER);
		VAR currentValue : Texts.Text;
		BEGIN
			currentValue := Get();
			Types.SetText(value, currentValue, res);
		END GetGeneric;

		PROCEDURE WriteValue*(w : Streams.Writer; level : SIGNED32); (** protected *)
		BEGIN
			WriteValue^(w, level);
			(* TBD *)
		END WriteValue;

	END Text;

TYPE

	Container* = OBJECT(Model)

		PROCEDURE &Init*;
		BEGIN
			Init^;
			SetNameAsString(StrContainer);
			SetGenerator("Models.GenContainer");
		END Init;

		PROCEDURE FindModel(CONST name : ARRAY OF CHAR) : Model;
		VAR result : Model; string : Strings.String; content : XML.Content;
		BEGIN
			result := NIL;
			(*? locking!!! *)
			content := GetFirst();
			WHILE (result = NIL) & (content # NIL) DO
				IF (content IS Model) THEN
					string := content(Model).GetAttributeValue(AttributeName);
					IF (string # NIL) & (string^ = name) THEN result := content(Model); END;
				END;
				content := GetNext(content);
			END;
			RETURN result;
		END FindModel;

		PROCEDURE FindModelByName(CONST fullname : ARRAY OF CHAR) : Model;
		VAR curModel : Model; name : ARRAY 32 OF CHAR; i, j : SIGNED32; done : BOOLEAN;
		BEGIN
			curModel := SELF;
			done := FALSE;
			i := 0; j := 0;
			WHILE ~done & (curModel # NIL)  & (i < LEN(fullname)) & (j < LEN(name)) DO
				IF (fullname[i] = ".") OR (fullname[i] = 0X) THEN
					name[j] := 0X;
					IF (curModel IS Container) THEN
						curModel := curModel(Container).FindModel(name);
					ELSE
						curModel := NIL;
					END;
					done := (fullname[i] = 0X);
					j := 0;
				ELSE
					name[j] := fullname[i];
					INC(j);
				END;
				INC(i);
			END;
			RETURN curModel;
		END FindModelByName;

		PROCEDURE SetField*(CONST name : ARRAY OF CHAR; CONST value : Types.Any; VAR res : INTEGER);
		VAR model : Model;
		BEGIN
			model := FindModelByName(name);
			IF (model # NIL) & ~(model IS Container) THEN
				model.SetGeneric(value, res);
			ELSE
				res := 192;
			END;
		END SetField;

		PROCEDURE GetField*(CONST name : ARRAY OF CHAR; VAR value : Types.Any; VAR res : INTEGER);
		VAR model : Model;
		BEGIN
			model := FindModelByName(name);
			IF (model # NIL) & ~(model IS Container) THEN
				model.GetGeneric(value, res);
			ELSE
				res := 192;
			END;
		END GetField;

	END Container;


VAR
	StrBoolean, StrInteger, StrUInt32, StrHugeint, StrUInt64, StrSize, StrReal, StrLongreal, StrChar, StrString, StrSet, StrText, StrContainer : Strings.String;

PROCEDURE NewLine*(w : Streams.Writer; level : SIGNED32);
BEGIN
	ASSERT(w # NIL);
	w.Ln; WHILE level > 0 DO w.Char(09X); DEC(level) END
END NewLine;

(* Helper procedures *)

PROCEDURE IsPrintableCharacter(ch : CHAR) : BOOLEAN;
BEGIN
	RETURN (" " < ch) & (ORD(ch) < 128);
END IsPrintableCharacter;

(* global helper procedures *)



PROCEDURE GetReal*(m: Model; VAR r: FLOAT64): BOOLEAN;
VAR real: Types.Longreal; res: INTEGER;
BEGIN
	IF m = NIL THEN RETURN FALSE END;
	m.GetGeneric(real, res);
	IF (res = Ok) THEN
		r := real.value; RETURN TRUE
	ELSE RETURN FALSE
	END;
END GetReal;

PROCEDURE GetInteger*(m: Model; VAR i: SIGNED32): BOOLEAN;
VAR int: Types.Integer; res: INTEGER;
BEGIN
	IF m = NIL THEN RETURN FALSE END;
	m.GetGeneric(int, res);
	IF (res = Ok) THEN
		i := int.value; RETURN TRUE
	ELSE RETURN FALSE
	END;
END GetInteger;

PROCEDURE GetSize*(m: Model; VAR i: SIZE): BOOLEAN;
VAR int: Types.Size; res: INTEGER;
BEGIN
	IF m = NIL THEN RETURN FALSE END;
	m.GetGeneric(int, res);
	IF (res = Ok) THEN
		i := int.value; RETURN TRUE
	ELSE RETURN FALSE
	END;
END GetSize;

PROCEDURE SetReal*(m: Model; r: FLOAT64);
VAR real: Types.Longreal; res: INTEGER;
BEGIN
	IF m = NIL THEN RETURN END;
	real.value := r;
	m.SetGeneric(real, res);
END SetReal;

(** Generator procedures *)

PROCEDURE GenBoolean*() : XML.Element;
VAR boolean : Boolean;
BEGIN
	NEW(boolean); RETURN boolean;
END GenBoolean;

PROCEDURE GenInteger*() : XML.Element;
VAR integer : Integer;
BEGIN
	NEW(integer); RETURN integer;
END GenInteger;

PROCEDURE GenUInt32*() : XML.Element;
VAR integer : UInt32;
BEGIN
	NEW(integer); RETURN integer;
END GenUInt32;

PROCEDURE GenHugeint*() : XML.Element;
VAR hugeint : Hugeint;
BEGIN
	NEW(hugeint); RETURN hugeint;
END GenHugeint;

PROCEDURE GenUInt64*() : XML.Element;
VAR integer : UInt64;
BEGIN
	NEW(integer); RETURN integer;
END GenUInt64;

PROCEDURE GenSize*() : XML.Element;
VAR size : Size;
BEGIN
	NEW(size); RETURN size;
END GenSize;

PROCEDURE GenReal*() : XML.Element;
VAR real : Real;
BEGIN
	NEW(real); RETURN real;
END GenReal;

PROCEDURE GenLongreal*() : XML.Element;
VAR longReal : Longreal;
BEGIN
	NEW(longReal); RETURN longReal;
END GenLongreal;

PROCEDURE GenChar*() : XML.Element;
VAR char : Char;
BEGIN
	NEW(char); RETURN char;
END GenChar;

PROCEDURE GenString*() : XML.Element;
VAR string : String;
BEGIN
	NEW(string); RETURN string;
END GenString;

PROCEDURE GenSet*() : XML.Element;
VAR set : Set;
BEGIN
	NEW(set); RETURN set;
END GenSet;

PROCEDURE GenText*() : XML.Element;
VAR text : Text;
BEGIN
	NEW(text); RETURN text;
END GenText;

PROCEDURE GenContainer*() : XML.Element;
VAR container : Container;
BEGIN
	NEW(container); RETURN container;
END GenContainer;

PROCEDURE InitStrings;
BEGIN
	StrBoolean := Strings.NewString("Boolean");
	StrInteger := Strings.NewString("Integer");
	StrUInt32 := Strings.NewString("UInt32");
	StrHugeint := Strings.NewString("Hugeint");
	StrUInt64 := Strings.NewString("UInt64");
	StrSize := Strings.NewString("Size");
	StrReal := Strings.NewString("Real");
	StrLongreal := Strings.NewString("Longreal");
	StrChar := Strings.NewString("Char");
	StrString := Strings.NewString("String");
	StrSet := Strings.NewString("Set");
	StrText := Strings.NewString("Text");
	StrContainer := Strings.NewString("Container");
END InitStrings;

BEGIN
	InitStrings;
END Models.
