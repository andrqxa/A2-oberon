MODULE WMRestorable; (** AUTHOR "tf"; PURPOSE "Save and restore the desktop"; *)

IMPORT
	Commands, Files, Kernel, Modules, KernelLog, Strings, WMMessages,
	XML, XMLObjects, XMLScanner, XMLParser, WM := WMWindowManager, Streams;

TYPE

	String* = Strings.String;
	XmlElement* = XML.Element;

	Context* = OBJECT
	VAR
		l*, t*, r*, b* : SIZE;
		flags* : SET;
		appData* : XML.Element;
	END Context;

	RestoreContextProc = PROCEDURE(context : Context);

TYPE

	Storage* = OBJECT
	VAR data : XML.Element;

		PROCEDURE &New*;
		BEGIN
			NEW(data); data.SetName("Desktop");
		END New;

		PROCEDURE Add*(CONST name, loader : ARRAY OF CHAR; w : WM.Window; appData : XML.Element);
		VAR window: XML.Element;
		BEGIN {EXCLUSIVE}
			NEW(window); window.SetName("Window");

			StoreString(window, "name", name);
			StoreString(window, "loader", loader);

			StoreSize(window, "l", w.bounds.l);
			StoreSize(window, "t", w.bounds.t);
			StoreSize(window, "r", w.bounds.r);
			StoreSize(window, "b", w.bounds.b);

			StoreSet(window, "flags", w.flags);

			IF appData # NIL THEN window.AddContent(appData) END;

			data.AddContent(window)
		END Add;

		PROCEDURE Write*(CONST name : ARRAY OF CHAR);
		VAR f : Files.File; w : Files.Writer;
		BEGIN {EXCLUSIVE}
			f := Files.New(name);
			Files.OpenWriter(w, f, 0);
			data.Write(w, NIL, 0);
			w.Update;
			Files.Register(f)
		END Write;

	END Storage;

TYPE

	Loader = OBJECT
	VAR
		restoreContextProc : RestoreContextProc;
		par : Context;

		PROCEDURE &New*(c : RestoreContextProc; par : Context);
		BEGIN
			SELF.restoreContextProc := c; SELF.par := par
		END New;

	BEGIN {ACTIVE}
		restoreContextProc(par);
	END Loader;

VAR hasErrors : BOOLEAN;

PROCEDURE Store*(c : Commands.Context); (** filename ~ *)
VAR
	context : Storage;
	m : WM.WindowManager;
	msg : WMMessages.Message;
	t : Kernel.Timer;
	filename : ARRAY 256 OF CHAR;
BEGIN
	c.arg.SkipWhitespace; c.arg.String(filename);
	NEW(context);
	msg.ext := context; msg.msgType := WMMessages.MsgExt;
	m := WM.GetDefaultManager();
	m.Broadcast(msg);
	c.out.String("WMRestorable: Saving desktop to "); c.out.String(filename); c.out.String("..."); c.out.Ln;
	NEW(t); t.Sleep(100);
	context.Write(filename);
	NEW(t); t.Sleep(500);
	context.Write(filename);
	NEW(t); t.Sleep(1500);
	context.Write(filename);
	c.out.String("WMRestorable: Desktop saved."); c.out.Ln;
END Store;

PROCEDURE AddByContext*(w : WM.Window; c : Context);
VAR manager : WM.WindowManager;
BEGIN
	manager := WM.GetDefaultManager();
	w.bounds.l := c.l;
	w.bounds.t := c.t;
	w.bounds.r := c.r;
	w.bounds.b := c.b;
	manager.Add(c.l, c.t, w, c.flags);
END AddByContext;

(* Report errors while parsing *)
PROCEDURE Error(pos, line, row : Streams.Position; CONST msg : ARRAY OF CHAR);
BEGIN
	KernelLog.String("Parse error at pos "); KernelLog.Int(pos, 5); KernelLog.String(" in line "); KernelLog.Int(line,5);
	KernelLog.String(" row "); KernelLog.Int(row, 5); KernelLog.String(" - "); KernelLog.String(msg); KernelLog.Ln;
	hasErrors := TRUE
END Error;

PROCEDURE RestoreWindow(w : XML.Element);
VAR
	l : Strings.String;
	proc : RestoreContextProc;
	moduleName, procedureName : Modules.Name;
	msg : ARRAY 128 OF CHAR;
	res : INTEGER;
	loader : Loader;
	context : Context;
	c : XML.Content;
BEGIN
	l := w.GetAttributeValue("loader");
	IF l # NIL THEN
		NEW(context);
		LoadSize(w, "l", context.l);
		LoadSize(w, "t", context.t);
		LoadSize(w, "r", context.r);
		LoadSize(w, "b", context.b);
		LoadSet(w, "flags", context.flags);
		c := w.GetFirst();
		IF (c # NIL) & (c IS XML.Element) THEN
			context.appData := c(XML.Element);
		END;
		Commands.Split(l^, moduleName, procedureName, res, msg);
		IF (res = Commands.Ok) THEN
			GETPROCEDURE(moduleName, procedureName, proc);
			IF (proc # NIL) THEN
				NEW(loader, proc, context);
			END;
		END;
	END
END RestoreWindow;

PROCEDURE StoreWindow*(window: WM.Window; CONST fileName: ARRAY OF CHAR);
VAR context: Storage; msg: WMMessages.Message;
BEGIN
	NEW(context);
	msg.ext := context; msg.msgType := WMMessages.MsgExt;
	window.Handle(msg);
	context.Write(fileName);
END StoreWindow;

PROCEDURE Load*(context : Commands.Context); (** filename ~ *)
VAR f : Files.File;
	scanner : XMLScanner.Scanner;
	parser : XMLParser.Parser;
	reader : Files.Reader;
	doc : XML.Document;
	root : XML.Element;
	s : Strings.String;
	p : XML.Content;
	fn : ARRAY 256 OF CHAR;
BEGIN {EXCLUSIVE}
	context.arg.SkipWhitespace; context.arg.String(fn);
	context.out.String("WMRestorable: Loading desktop from "); context.out.String(fn); context.out.String("..."); context.out.Ln;
	hasErrors := FALSE;
	f := Files.Old(fn);
	IF f # NIL THEN
		NEW(reader, f, 0);
		NEW(scanner, reader); scanner.reportError := Error;
		NEW(parser, scanner); parser.reportError := Error;
		doc := parser.Parse();
		IF hasErrors THEN RETURN END;
		root := doc.GetRoot();
		p := root.GetFirst();
		WHILE (p # NIL) DO
			IF p IS XML.Element THEN
				s := p(XML.Element).GetName();
				IF (s # NIL) & (s^ = "Window") THEN
					RestoreWindow(p(XML.Element))
				END
			END;
			p := root.GetNext(p);
		END
	ELSE
		context.error.String("WMRestorable: File "); context.error.String(fn); context.error.String(" not found."); context.error.Ln;
	END;
END Load;

(** Returns a XML element contained in Context.appData by its path
	e.g. GetElement(c, "Configuration\DisplaySettings") *)
PROCEDURE GetElement*(c : Context; CONST path : ARRAY OF CHAR) : XmlElement;
CONST
	PathDelimiter = "\";
VAR
	strings : Strings.StringArray;
	string : String;
	elem : XML.Element;
	idx : SIGNED32;
BEGIN
	IF (c # NIL) & (c.appData # NIL) THEN
		elem := c.appData (XML.Element);
		strings := Strings.Split(path, PathDelimiter);
		string := elem.GetName();
		IF (string # NIL) OR (string^ = strings[0]^) THEN
			idx := 1;
			LOOP
				IF (idx >= LEN(strings)) OR (elem = NIL) THEN EXIT; END;
				elem := GetElementByName(elem, strings[idx]^);
				INC(idx);
			END;
		END;
	END;
	IF elem = NIL THEN
		KernelLog.String("WMRestorable: Element "); KernelLog.String(path); KernelLog.String(" not found."); KernelLog.Ln;
	END;
	RETURN elem;
END GetElement;

PROCEDURE LoadBoolean*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : BOOLEAN);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF (string # NIL) THEN
		IF (string^ = "true") THEN value := TRUE; ELSE value := FALSE; END;
	ELSE
		ShowLoadError("LoadBoolean", elem, name);
	END;
END LoadBoolean;

PROCEDURE StoreBoolean*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : BOOLEAN);
VAR a : XML.Attribute; string : ARRAY 8 OF CHAR;
BEGIN
	NEW(a); a.SetName(name);
	IF value THEN string := "true"; ELSE string := "false"; END; a.SetValue(string);
	elem.AddAttribute(a);
END StoreBoolean;

CONST LoadLongint* = LoadInt32;
PROCEDURE LoadInt32*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : SIGNED32);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF string # NIL THEN
		Strings.StrToInt32(string^, value);
	ELSE
		ShowLoadError("LoadInt32", elem, name);
	END;
END LoadInt32;

PROCEDURE LoadInt64*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : SIGNED64);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF string # NIL THEN
		Strings.StrToInt64(string^, value);
	ELSE
		ShowLoadError("LoadInt64", elem, name);
	END;
END LoadInt64;

PROCEDURE LoadUInt32*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : UNSIGNED32);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF (string # NIL) THEN
		Strings.StrToUInt32(string^, value);
	ELSE
		ShowLoadError("LoadUInt32", elem, name);
	END;
END LoadUInt32;

PROCEDURE LoadUInt64*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : UNSIGNED64);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF (string # NIL) THEN
		Strings.StrToUInt64(string^, value);
	ELSE
		ShowLoadError("LoadUInt64", elem, name);
	END;
END LoadUInt64;

PROCEDURE LoadSize*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : SIZE);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF string # NIL THEN
		Strings.StrToSize(string^, value);
	ELSE
		ShowLoadError("LoadLongint", elem, name);
	END;
END LoadSize;

CONST StoreLongint* = StoreInt32;
PROCEDURE StoreInt32*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : SIGNED32);
VAR a : XML.Attribute; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.IntToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreInt32;

PROCEDURE StoreInt64*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : SIGNED64);
VAR a : XML.Attribute; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.IntToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreInt64;

PROCEDURE StoreUInt32*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : UNSIGNED32);
VAR a : XML.Attribute; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.UIntToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreUInt32;

PROCEDURE StoreUInt64*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : UNSIGNED64);
VAR a : XML.Attribute; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.UIntToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreUInt64;

PROCEDURE StoreSize*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : SIZE);
VAR a : XML.Attribute; string : ARRAY 32 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.IntToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreSize;

PROCEDURE LoadString*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : ARRAY OF CHAR);
VAR string : String;
BEGIN
	string := elem.GetAttributeValue(name);
	IF string # NIL THEN
		COPY(string^, value);
	ELSE
		value[0] := 0X; ShowLoadError("LoadString", elem, name);
	END;
END LoadString;

PROCEDURE StoreString*(elem : XML.Element; CONST name, value : ARRAY OF CHAR);
VAR a : XML.Attribute;
BEGIN
	NEW(a); a.SetName(name); a.SetValue(value); elem.AddAttribute(a);
END StoreString;

PROCEDURE LoadStringPtr*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : String);
BEGIN
	value := elem.GetAttributeValue(name);
	IF value = NIL THEN
		ShowLoadError("LoadStringPtr", elem, name);
	END;
END LoadStringPtr;

PROCEDURE StoreStringPtr*(elem : XML.Element; CONST name : ARRAY OF CHAR;  value : String);
VAR a : XML.Attribute;
BEGIN
	IF (value # NIL) THEN
		NEW(a); a.SetName(name); a.SetValue(value^); elem.AddAttribute(a);
	END;
END StoreStringPtr;

PROCEDURE LoadSet*(elem : XML.Element; CONST name : ARRAY OF CHAR; VAR value : SET);
VAR string : String;
BEGIN
	value := {};
	string := elem.GetAttributeValue(name);
	IF (string # NIL) THEN
		Strings.StrToSet(string^, value);
	END;
END LoadSet;

PROCEDURE StoreSet*(elem : XML.Element; CONST name : ARRAY OF CHAR; value : SET);
VAR a : XML.Attribute; string : ARRAY 128 OF CHAR;
BEGIN
	NEW(a); a.SetName(name); Strings.SetToStr(value, string); a.SetValue(string);
	elem.AddAttribute(a);
END StoreSet;

PROCEDURE GetElementByName(parent : XML.Element; CONST name : ARRAY OF CHAR) : XML.Element;
VAR elem : XML.Element; enum : XMLObjects.Enumerator; ptr : ANY; string : String;
BEGIN
	IF parent # NIL THEN
		enum := parent.GetContents(); enum.Reset();
		WHILE enum.HasMoreElements() DO
			ptr := enum.GetNext();
			IF ptr IS XML.Element THEN
				elem := ptr (XML.Element);
				string := elem.GetName();
				IF (string # NIL) & (string^ = name) THEN
					RETURN elem;
				END;
			END;
		END;
	END;
	RETURN NIL;
END GetElementByName;

PROCEDURE ShowLoadError(CONST procedureName : ARRAY OF CHAR; elem : XML.Element; CONST name : ARRAY OF CHAR);
VAR string : String;
BEGIN
	KernelLog.String("WMRestorable: "); KernelLog.String(procedureName);
	KernelLog.String(": Attribute '"); KernelLog.String(name); KernelLog.String("' of element ");
	string := elem.GetName(); IF string # NIL THEN KernelLog.String(string^); ELSE KernelLog.String("<no name>"); END;
	KernelLog.String(" not found.");
	KernelLog.Ln;
END ShowLoadError;

END WMRestorable.

System.Free WMRestorable ~
WMRestorable.Store ~
WMRestorable.Load ~

PET.Open Auto.dsk ~	(* used to verify the behaviour of WMRestorable *)
