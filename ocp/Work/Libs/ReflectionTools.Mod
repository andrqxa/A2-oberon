MODULE ReflectionTools; 
(** AUTHOR "BohdanT"; PURPOSE "misc routines for extend reflection functionality"; *)

IMPORT Reflection, Modules;

TYPE
 Name = Reflection.Name;

PROCEDURE GetMethodByName*(typ:ANY; CONST methodname: ARRAY OF CHAR):ADDRESS;
VAR
  resadr:ADDRESS;
VAR
	t:Modules.TypeDesc;
	offset: SIZE

	PROCEDURE ProcessType(refs: Modules.Bytes; VAR offset: SIZE);
	VAR c: CHAR;
	BEGIN
		c := Reflection.GetChar(refs, offset);
		CASE c OF
			Reflection.sfTypeNone: (*w.String("no type")*);
		| Reflection.sfTypePointerToRecord: (*w.String("POINTER TO RECORD")*);
		| Reflection.sfTypePointerToArray: (*w.String("POINTER TO ");*) ProcessType(refs, offset);
		| Reflection.sfTypeOpenArray: (*w.String("ARRAY OF ");*) ProcessType(refs, offset);
		| Reflection.sfTypeStaticArray: (*w.String("ARRAY "); w.Int(Reflection.GetSize(refs, offset),1 ); w.String(" OF ");*)Reflection.SkipSize(offset);ProcessType(refs, offset);
		| Reflection.sfTypeDynamicArray: (*w.String("DARRAY OF ");*) ProcessType(refs, offset);
		| Reflection.sfTypeMathOpenArray: (*w.String("ARRAY [*] OF ");*) ProcessType(refs, offset);
		| Reflection.sfTypeMathStaticArray: (*w.String("ARRAY ["); w.Int(Reflection.GetSize(refs, offset),1); w.String("] OF ");*)Reflection.SkipSize(offset); ProcessType(refs, offset);
		| Reflection.sfTypeMathTensor: (*w.String("ARRAY [?] OF ");*) ProcessType(refs, offset);
		| Reflection.sfTypeRecord: (*w.String("RECORD ");  w.Address(Reflection.GetAddress(refs, offset))*);
		| Reflection.sfTypeProcedure, Reflection.sfTypeDelegate:
(*			w.String("PROCEDURE"); IF c = Reflection.sfTypeDelegate THEN w.String(" {DELEGATE}") END; w.String(" (");*)
			WHILE refs[offset] =Reflection.sfVariable DO ProcessVariable(refs, offset) END;
			(*w.String("):");*) ProcessType(refs, offset);
		| Reflection.sfTypeBOOLEAN: (*w.String("BOOLEAN");*)
		| Reflection.sfTypeCHAR: (*w.String("CHAR");*)
		| Reflection.sfTypeSHORTINT: (*w.String("SIGNED8")*);
		| Reflection.sfTypeINTEGER: (*w.String("SIGNED16")*);
		| Reflection.sfTypeLONGINT: (*w.String("SIGNED32")*);
		| Reflection.sfTypeHUGEINT: (*w.String("SIGNED64")*);
		| Reflection.sfTypeWORD: (*w.String("INTEGER")*);
		| Reflection.sfTypeLONGWORD: (*w.String("LONGINTEGER")*);
		| Reflection.sfTypeSIGNED8: (*w.String("SIGNED8")*);
		| Reflection.sfTypeSIGNED16: (*w.String("SIGNED16")*);
		| Reflection.sfTypeSIGNED32: (*w.String("SIGNED32")*);
		| Reflection.sfTypeSIGNED64: (*w.String("SIGNED64")*);
		| Reflection.sfTypeUNSIGNED8: (*w.String("UNSIGNED8")*);
		| Reflection.sfTypeUNSIGNED16: (*w.String("UNSIGNED16")*);
		| Reflection.sfTypeUNSIGNED32: (*w.String("UNSIGNED32")*);
		| Reflection.sfTypeUNSIGNED64: (*w.String("UNSIGNED64")*);
		| Reflection.sfTypeREAL: (*w.String("FLOAT32")*);
		| Reflection.sfTypeLONGREAL: (*w.String("FLOAT64")*);
		| Reflection.sfTypeCOMPLEX: (*w.String("COMPLEX32")*);
		| Reflection.sfTypeLONGCOMPLEX: (*w.String("COMPLEX64")*);
		| Reflection.sfTypeSET: (*w.String("SET")*);
		| Reflection.sfTypeANY: (*w.String("ANY")*);
		| Reflection.sfTypeOBJECT: (*w.String("OBJECT")*);
		| Reflection.sfTypeBYTE: (*w.String("BYTE")*);
		| Reflection.sfTypeRANGE: (*w.String("RANGE")*);
		| Reflection.sfTypeADDRESS: (*w.String("ADDRESS")*);
		| Reflection.sfTypeSIZE: (*w.String("SIZE")*);
		| Reflection.sfTypePORT: (*w.String("PORT");*) IF Reflection.GetChar(refs,offset) = Reflection.sfIN THEN (*w.String("IN") ELSE w.String("OUT") *)END;
		| Reflection.sfTypeIndirect: (*w.String ("INDIRECT AT "); w.Int(Reflection.GetSize(refs, offset),1)*)Reflection.SkipSize(offset);
		ELSE (*w.String("????? TYPE ?????")*);
		END;
	END ProcessType;

	PROCEDURE ProcessVariable(refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  adr: ADDRESS;  size: SIZE;
	BEGIN
		IF Reflection.GetChar(refs, offset) # Reflection.sfVariable THEN RETURN END;
		Reflection.SkipSize(offset);
		Reflection.GetString(refs, offset, name);
		IF Reflection.GetChar(refs, offset) = Reflection.sfRelative THEN
			size := Reflection.GetSize(refs, offset);
		ELSE (* absolute *)
			adr := Reflection.GetAddress(refs, offset);
		END;
		ProcessType(refs, offset);
	END ProcessVariable;
	PROCEDURE ProcessProcedure(refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  start, end: ADDRESS;  flags: SET;
	BEGIN
		IF Reflection.GetChar(refs, offset) # Reflection.sfProcedure THEN RETURN END;
		Reflection.SkipSize(offset);
		Reflection.GetString(refs, offset, name);
		start := Reflection.GetAddress(refs, offset);
		end := Reflection.GetAddress(refs, offset);
	  flags := Reflection.GetSet(refs, offset);
		IF name=methodname THEN 
(*			TRACE("OK");*)
			resadr:=start; 
		END;

		WHILE refs[offset] = Reflection.sfVariable DO
			ProcessVariable(refs, offset);
		END;
		ProcessType(refs, offset);
		ProcessScope(refs, offset);
	END ProcessProcedure;


	PROCEDURE ProcessScope(refs: Modules.Bytes; VAR offset: SIZE);
	VAR
		offsetOld: SIZE;
	BEGIN
		offsetOld := offset;
		IF Reflection.GetChar(refs, offset) # Reflection.sfScopeBegin THEN RETURN END;
		WHILE (refs[offset] = Reflection.sfVariable) DO (* Variable *)
			ProcessVariable(refs, offset);
		END;
		WHILE (refs[offset] = Reflection.sfProcedure) DO (* Procedure *)
			ProcessProcedure(refs, offset);
		END;
		WHILE (refs[offset] = Reflection.sfTypeDeclaration) DO (* TypeDeclaration *)
			ProcessTypeDeclaration(refs, offset);
		END;
		IF Reflection.GetChar(refs, offset) # Reflection.sfScopeEnd THEN RETURN END;
	END ProcessScope;


	PROCEDURE ProcessTypeDeclaration(refs: Modules.Bytes; VAR offset: SIZE);
	VAR name: Name;  adr: ADDRESS;
	BEGIN
		IF Reflection.GetChar(refs, offset) # Reflection.sfTypeDeclaration THEN RETURN END;
		Reflection.SkipSize(offset);
		Reflection.GetString(refs, offset, name);
		adr := Reflection.GetAddress(refs, offset);
		IF refs[offset] = Reflection.sfScopeBegin THEN ProcessScope(refs, offset) END;
	END ProcessTypeDeclaration;

BEGIN
	resadr:=NIL;
	t:=Modules.TypeOf(typ);
	offset:=t.refsOffset;
	ProcessTypeDeclaration (t.mod.refs, offset);
	RETURN resadr;
END GetMethodByName;

END ReflectionTools.
