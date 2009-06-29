MODULE Highlighter; (** AUTHOR "RS"; PURPOSE "Syntaxhighlighting"; *)

IMPORT
	KernelLog, Texts, TextUtilities, Strings, XML, XMLScanner, XMLParser, XMLObjects, Files;

CONST
	MaxSize= 256;
	cArraySize = 10000;
	HighlightFile = "Highlight.XML";
	VeryLargeNumber = 100000000;

	(* element and attribute names - must match DTD in ConfigFile *)
	languagesblock = "languages"; 
	languageblock = "language";
	styleblock = "styles";
	NameAttr = "name";
	commentblock = "comment";
	inquotesblock = "inquotes";

	FontNameAttr = "fontname"; FontSizeAttr = "fontsize";
	FontStyleAttr = "fontstyle"; VoffAttr = "voff";
	ColorAttr = "color"; BgColorAttr = "bgcolor";
	
	OpenBracket = "("; CloseBracket = ")"; 
	Quote = "!"; Star = "+";
	
	QuoteTag = "quote"; DefaultTag = "default"; CommentTag = "comment";

	Trace = TRUE;

TYPE
	Attributes = Texts.Attributes;
	
	Char32 = Texts.Char32;
	
	Array32* = ARRAY 32 OF CHAR;
	
	ArrayList = ARRAY MaxSize OF Array32;

	Keyword = RECORD
		name: Array32;
		attributes: POINTER TO Style;
	END;
	
	KeywordArray = ARRAY MaxSize OF Keyword;
	
	KeywordList = RECORD
	 	name: Array32;
	 	style : Array32;
		keywords: ArrayList;
	END;
	
	Style = RECORD
	 	name: Array32;
		attributes: Attributes;
	END;

	Comment = RECORD
		name: Array32;
		distance: LONGINT;
		prev, next: pComment;
	END;
	
	pComment = POINTER TO Comment;
	
	CommentLight = RECORD
		name: Array32;
		pos: LONGINT;
	END;

	pcArray = POINTER TO ARRAY cArraySize OF CommentLight;
	
VAR	
	KeywordListList: ARRAY MaxSize OF KeywordList;
	StyleList: ARRAY MaxSize OF Style;
	Comments: Style;
	InQuotes: Style;
	
	highlight: XML.Document;	(** internalized highlight file *)
	error : BOOLEAN;

TYPE

	Highlighter* = OBJECT
	VAR
		keywords: KeywordArray;
		hiattr : Attributes;
		hCounter : LONGINT;
		first: pComment;
		textReader : Texts.TextReader;
		pArray: pcArray;

		PROCEDURE SetAttributes(CONST attr : Attributes);
		BEGIN
			IF (hiattr = NIL) THEN
				NEW(hiattr); NEW(hiattr.fontInfo);
			END;
			hiattr := attr.Clone();
		END SetAttributes;

		PROCEDURE GetAttributes(): Attributes;
		BEGIN
			RETURN hiattr;
		END GetAttributes;

		PROCEDURE isComment(reader: Texts.TextReader; CONST pos: LONGINT; VAR name: Array32):BOOLEAN;
		VAR char : Char32; isCom : BOOLEAN;
		BEGIN
			reader.SetPosition(pos);
			reader.ReadCh(char);

			IF (char = ORD('"')) THEN
				name := Quote;
				isCom := TRUE;
			ELSIF (char = ORD("(")) THEN
				name := OpenBracket;
				isCom := TRUE;
			ELSIF (char = ORD(")")) THEN
				name := CloseBracket;
				isCom := TRUE;
			ELSIF (char = ORD("*")) THEN
				name := Star;
				isCom := TRUE;
			ELSE
				name := "";
				isCom := FALSE;
			END;

			reader.SetPosition(pos);
			RETURN isCom;
		END isComment;

		PROCEDURE findElement(VAR current: pComment; CONST pos: LONGINT; VAR counter:LONGINT; VAR overflow: BOOLEAN);
		BEGIN
			overflow := FALSE;
			IF (first # NIL) THEN
				current := first;
				counter := current.distance;
				WHILE (pos > counter) & (~overflow) DO
					IF (current.next # NIL) THEN
						current := current.next;
						counter := counter + current.distance;
					ELSE
						overflow := TRUE;
					END;
				END;
			END;
		END findElement;

		PROCEDURE addComment(com: pComment; CONST pos: LONGINT);
		VAR
			current : pComment;
			curpos : LONGINT;
			overflow, add: BOOLEAN;
		BEGIN
			IF (first = NIL) THEN
				first := com;
				com.prev := NIL;
				com.next := NIL;
				com.distance := pos;
			ELSE
				overflow := FALSE;
				add := FALSE;
				
				NEW (current);
				current := NIL;
				
				findElement(current,pos,curpos,overflow);

				IF (overflow) THEN
					(* if last *)
					com.next := NIL;
					current.next := com;
					com.prev := current;
					com.distance := pos - curpos;
				ELSE
					(* if first *)
					IF (current.prev = NIL) THEN
						first := com;
						com.next := current;
						current.prev := com;
						com.distance := pos;
						current.distance := current.distance - com.distance+1;
					ELSE
						(* if somewhere in the middle *)
						com.prev := current.prev;
						com.prev.next := com;
						com.next := current;
						com.next.prev := com;
						com.distance := current.distance - (curpos - pos);
						current.distance := curpos - pos + 1;
					END;
				END;
			END;
		END addComment;

		PROCEDURE removeComment(CONST com: pComment);
		BEGIN
			IF (com # NIL) THEN
				(* Remove only element from the list *)
				IF (com.prev = NIL) & (com.next = NIL) THEN
					first := NIL;
				END;

				(* Remove first element *)
				IF (com.prev = NIL) & (com.next # NIL) THEN
					first := com.next;
					com.next.prev := NIL;
					com.next.distance := com.distance + com.next.distance - 1;
				END;

				(* Remove a middle element *)
				IF (com.prev # NIL) & (com.next # NIL) THEN
					com.prev.next := com.next;
					com.next.prev := com.prev;
					com.next.distance := com.distance + com.next.distance - 1;
				END;

				(* Remove last element *)
				IF (com.prev # NIL) & (com.next = NIL) THEN
					com.prev.next := NIL;
				END;
			END;
		END removeComment;

		PROCEDURE UpdateArray;
		VAR current: pComment; counter, pos, depth : LONGINT; quotes : BOOLEAN;
		BEGIN
			NEW(pArray);
			quotes := FALSE;
			counter := 0;
			depth := 0;
			pos := 0;
			NEW(current);
			current := first;

			IF (current # NIL) THEN
				pos := current.distance;
			END;

			WHILE (current # NIL) DO
				IF (Strings.Match(current.name,Quote)) THEN
					(* In a quote *)
					IF (quotes) THEN
						quotes := FALSE;
						depth := 0;
						pArray[counter].name := DefaultTag;
						pArray[counter].pos := pos;
						INC(counter);
					ELSE
						(* Not in a quote or a comment *)
						IF (depth < 1) THEN
							quotes := TRUE;
							depth := 0;
							pArray[counter].name := QuoteTag;
							pArray[counter].pos := pos-1;				
							INC(counter);
						END;
					END;
					current := current.next;

					IF (current # NIL) THEN
						pos := pos + current.distance;
					END;
				END;

				IF (current # NIL) & (Strings.Match(current.name,Star)) THEN
					current := current.next;

					IF (current # NIL) THEN
						pos := pos + current.distance;
					END;

					IF (current # NIL) & (Strings.Match(current.name,CloseBracket)) & (current.distance = 1) THEN
						IF (~quotes) THEN
							(* Last comment closed *)
							IF (depth > 1) THEN
								DEC(depth);
							ELSE
								IF (depth = 1) THEN
									depth := 0;
									pArray[counter].name := DefaultTag;
									pArray[counter].pos := pos;
									INC(counter);
								ELSE
									DEC(depth);
								END;
							END;
							current := current.next;

							IF (current # NIL) THEN
								pos := pos + current.distance;
							END;
						END;
					END;
				END;

				IF (current # NIL) & (Strings.Match(current.name,OpenBracket)) THEN
					current := current.next;
					IF (current # NIL) THEN
						pos := pos + current.distance;
					END;

					IF (current # NIL) & (Strings.Match(current.name,Star)) & (current.distance = 1) THEN
						IF (~quotes) THEN
							IF (depth < 1) THEN
								depth := 1;
								pArray[counter].name := CommentTag;
								pArray[counter].pos := pos-2;
								INC(counter);
							ELSE
								INC(depth);
							END;

							current := current.next;
							IF (current # NIL) THEN
								pos := pos + current.distance;
							END;
						END;
					END;
				END;

				IF (current # NIL) & (Strings.Match(current.name,CloseBracket)) THEN
					current := current.next;
					IF (current # NIL) THEN
						pos := pos + current.distance;
					END;
				END;				
			END;

			pArray[counter+1].name := 0X;
			pArray[counter+1].pos := VeryLargeNumber;
		END UpdateArray;

		PROCEDURE UpdateComments*(text : Texts.Text; info: Texts.TextChangeInfo; VAR fullLayout: BOOLEAN);
		VAR
			(* info: timestamp*, op*, pos*, len* *)
			counter,compos, check, sp, eot: LONGINT;
			name: Array32;
			com : pComment;
			overflow: BOOLEAN;
		BEGIN
			IF Trace THEN
				KernelLog.Ln;
				KernelLog.String("Op: "); KernelLog.Int(info.op, 0); 
				KernelLog.String(" Pos: "); KernelLog.Int(info.pos, 0); 
				KernelLog.String(" Len: "); KernelLog.Int(info.len, 0); 
				KernelLog.String(" Timestamp: "); KernelLog.Int(info.timestamp, 0); 
				KernelLog.Ln;
			END;		
			IF (textReader = NIL) THEN NEW(textReader, text); END;
			textReader.SetPosition(info.pos);
			textReader.SetDirection(1);

			IF (info.op = 0) THEN
				IF Trace THEN KernelLog.String("Add: "); KernelLog.Int(info.len,0); KernelLog.String(" letter(s)"); END;
				counter := info.pos;
				WHILE (counter < info.pos + info.len) DO
					NEW(com);

					IF (isComment(textReader,counter,name)) THEN
						com.name := name;
						addComment(com, counter);
						fullLayout := TRUE;
					ELSE
						findElement(com, counter, compos, overflow);
						IF (~overflow) THEN
							INC(com.distance);
						END;
					END;
					INC(counter);
				END;
			ELSIF (info.op = 1) THEN
				IF Trace THEN KernelLog.String("Sub: "); KernelLog.Int(info.len,0); KernelLog.String(" letter(s)"); END;
				counter := info.pos;
				check := info.len;
				WHILE (check > 0) DO				
					NEW(com);
					findElement(com, counter, compos, overflow);
					IF (info.pos = compos) THEN
						removeComment(com);
						fullLayout := TRUE;
					ELSE
						IF (~overflow) THEN
							DEC(com.distance);
						END;
					END;
					DEC(check);
				END;
			ELSIF (info.op = 3) THEN
				IF Trace THEN KernelLog.String("Multi: "); KernelLog.Int(info.len,0); KernelLog.String(" letter(s)"); END;
				NEW(com);
				first := NIL;
				sp := textReader.GetPosition();
				counter := 0;
				textReader.SetPosition(0);
				eot := textReader.text.GetLength();
				WHILE (counter < eot) DO
					NEW(com);
					IF (isComment(textReader,counter,name)) THEN
						com.name := name;
						addComment(com, counter);
					END;
					INC (counter);
				END;
				textReader.SetPosition(sp);						
			END;
			UpdateArray;
		END UpdateComments;

		PROCEDURE CheckComments*(reader: Texts.TextReader; CONST pos: LONGINT; VAR attr: Attributes; VAR notDefault: BOOLEAN);
		VAR counter: LONGINT; overflow: BOOLEAN;
		BEGIN
			notDefault := FALSE;
			counter := 0;
			
			IF (pArray = NIL) THEN
				NEW(pArray);
			END;

			WHILE (pArray[counter].pos < pos) & (~overflow) DO
				IF (pArray[counter].name # 0X) THEN
					INC(counter);
				ELSE
					overflow := TRUE;
				END;
			END;
			
			IF (counter > 0) THEN
				DEC(counter);

				IF (Strings.Match(DefaultTag,pArray[counter].name)) THEN
					notDefault := FALSE;
					attr:= NIL;
				END;
				IF (Strings.Match(CommentTag,pArray[counter].name)) THEN
					notDefault := TRUE;
					attr:= Comments.attributes.Clone();
				END;
				IF (Strings.Match(QuoteTag,pArray[counter].name)) THEN
					notDefault := TRUE;
					attr:= InQuotes.attributes.Clone();
				END;
			END;
		END CheckComments;

		PROCEDURE CheckKeyword(CONST word : ARRAY OF CHAR): BOOLEAN;
		VAR i,j : LONGINT; isKeyword : BOOLEAN;
		BEGIN
			i := 0; j := 0;
			isKeyword := FALSE;
			WHILE (keywords[i].name # 0X) DO
				IF (Strings.Match(word,keywords[i].name)) THEN
					isKeyword := TRUE;
					SetAttributes(keywords[i].attributes.attributes);
				END;
				INC(i);
			END;
			RETURN isKeyword;
		END CheckKeyword;

		PROCEDURE CheckHighlight*(reader : Texts.TextReader; CONST sp : LONGINT; VAR attr:  Attributes; VAR hiSwitch : BOOLEAN; VAR resetHCounter:BOOLEAN);
		VAR start, end : LONGINT; word : Array32; char : Char32;
		BEGIN
			IF (resetHCounter) THEN
				hCounter := 0;
				resetHCounter := FALSE;
			END;

			(* check highlight *)
			reader.ReadCh(char);

			GetWordBorders(reader, sp,start,end);

			IF (hCounter > 0 ) THEN
				DEC(hCounter);
				IF (hCounter = 0) THEN
					hiSwitch := FALSE;
				END;
			ELSE
				IF (sp = start) & (sp # end) THEN
					(* we found a new word *)
					hCounter := end - start;
					GetWord(reader, start, end, word);
					IF (CheckKeyword(word)) THEN
						hiSwitch := TRUE;
						attr := GetAttributes();
					ELSE
						hiSwitch := FALSE;
					END;
				ELSE
					hiSwitch := FALSE;
				END;				
			END;			
			reader.SetPosition(sp);
		END CheckHighlight;		

		PROCEDURE &Init(CONST language : Array32);
		BEGIN
			IF LoadXML() THEN
				KernelLog.Ln; 
				KernelLog.String(HighlightFile); KernelLog.String(" loaded "); KernelLog.Ln;
			ELSE
				KernelLog.Ln; KernelLog.String("Loading ");  KernelLog.String(HighlightFile); 
				KernelLog.String(" failed!!!"); KernelLog.Ln;
			END;
			keywords := GetHighlighting(language);		
		END Init;

	END Highlighter;

PROCEDURE GetWordBorders(reader: Texts.TextReader; pos: LONGINT; VAR start, end : LONGINT);
VAR a : Texts.Char32;
BEGIN
	start := pos; end := pos;
	reader.SetPosition(pos);
	reader.SetDirection(1);
	reader.ReadCh(a);
	IF (TextUtilities.IsAlphaNum(a)) THEN
		(* Find the start of the word *)
		start := TextUtilities.FindPosWordLeft(reader,pos);
		(* Find the end of the word *)
		end := TextUtilities.FindEndWordRight(reader, pos);
	END; 
END GetWordBorders;

PROCEDURE GetWord(reader: Texts.TextReader; start, end : LONGINT; VAR word : ARRAY OF CHAR);
VAR length, i : LONGINT; a : Texts.Char32;
BEGIN
	(* Write the wort into the wordarray if it is long enough *)
	length := end - start;
	IF (length < 32) THEN
		reader.SetPosition(start);
		reader.SetDirection(1);
		reader.ReadCh(a);
		i := 0;
		WHILE (i < length) DO
			word[i] := CHR(a);
			reader.ReadCh(a);
			INC(i);
		END;
		word[i] := 0X;
	END;
END GetWord;

PROCEDURE GetHighlighting(CONST language: Array32): KeywordArray;
VAR
	keywords: KeywordArray;
	keywordListListCounter, styleListCounter : LONGINT;
	i: LONGINT;
	keywordCounter: LONGINT;
	attributes : Attributes;
BEGIN
	NEW (attributes);
	keywordCounter := 0;
	keywordListListCounter := 0;
	WHILE (KeywordListList[keywordListListCounter].name # 0X) DO
		IF (Strings.Match(language,KeywordListList[keywordListListCounter].name)) THEN
			styleListCounter := 0;
			WHILE (StyleList[styleListCounter].name # 0X) DO
				IF (Strings.Match(KeywordListList[keywordListListCounter].style,StyleList[styleListCounter].name)) THEN
					i := 0;
					WHILE (KeywordListList[keywordListListCounter].keywords[i] # 0X) DO
						Strings.Copy(KeywordListList[keywordListListCounter].keywords[i],0,Strings.Length(KeywordListList[keywordListListCounter].keywords[i]),keywords[keywordCounter].name);
						NEW(keywords[keywordCounter].attributes);
						keywords[keywordCounter].attributes.attributes := StyleList[styleListCounter].attributes.Clone();
						INC(keywordCounter);
						INC(i);
					END;
				END;
				INC(styleListCounter);
			END;
		END;
		INC(keywordListListCounter);
	END;
	RETURN keywords;
END GetHighlighting;

PROCEDURE LoadXML(): BOOLEAN;
VAR
	enum: XMLObjects.Enumerator; e : XML.Element; p: ANY; s, last: XML.String;	
	i, keywordListIndex, styleIndex : LONGINT;

	color, bgcolor, size, voff : LONGINT;
	name,fontname: Array32;
	style: SET;

	loaded: BOOLEAN;

	temp, temp2 : LONGINT;

	styleStr : Array32;
	
	p2,p3,p4: ANY; 
	s2,s3,s4: XML.String; 
	enum2,enum3,enum4: XMLObjects.Enumerator; 
BEGIN
	NEW(s,32);
	NEW(last,32);
	
	loaded := InitXML();
	
	IF (loaded) THEN
		s := NIL;
		i := 0;
		keywordListIndex := 0;
		styleIndex := 0;
		temp := 0;
		temp2 := 0;

		e := highlight.GetRoot();
		enum := e.GetContents();
		
		WHILE enum.HasMoreElements() DO
			p := enum.GetNext();
			IF p IS XML.Element THEN

				(* LANGUAGES *)
				s := p(XML.Element).GetName();

				IF (s # NIL) THEN
					IF (s^ = languagesblock) THEN
						enum2 := p(XML.Element).GetContents();
						WHILE enum2.HasMoreElements() DO
							p2 := enum2.GetNext();
							IF p2 IS XML.Element THEN

								(* LANGUAGE *)
								s2 := p2(XML.Element).GetName();

								IF (s2 # NIL) THEN
									IF (s2^ = languageblock) THEN

										(* LANGUAGE NAME *)
										s2 := p2(XML.Element).GetAttributeValue(NameAttr);

										enum3 := p2(XML.Element).GetContents();
										WHILE enum3.HasMoreElements() DO
											p3 := enum3.GetNext();
											IF p3 IS XML.Element THEN

												(* STYLE *)
												s3 := p3(XML.Element).GetName();

												IF (s3 # NIL) THEN

													(* STYLE NAME *)
													s3 := p3(XML.Element).GetAttributeValue(NameAttr);

													Strings.Copy(s2^,0,Strings.Length(s2^),KeywordListList[keywordListIndex].name); (* save keywordlistname *)
													Strings.Copy(s3^,0,Strings.Length(s3^),KeywordListList[keywordListIndex].style); (* save keywordliststyle *)

													enum4 := p3(XML.Element).GetContents();
													i := 0;
													WHILE enum4.HasMoreElements() DO

														p4 := enum4.GetNext();

														IF p4 IS XML.Element THEN
															(* KEYWORD *)
															s4 := p4(XML.Element).GetAttributeValue(NameAttr);

															Strings.Copy(s4^,0,Strings.Length(s4^),KeywordListList[keywordListIndex].keywords[i]); (* save keywordlistitem*)
															INC(i);
														END;
													END;
													INC(keywordListIndex);
												END;
											END;
										END;
									END;
								END;
							END;
						END;

					ELSE

						(* STYLES *)
						(* Assumption: No two styles have the same name *)
						IF (s^ = styleblock) THEN

							enum2 := p(XML.Element).GetContents();
							WHILE enum2.HasMoreElements() DO
								p2 := enum2.GetNext();
								IF p2 IS XML.Element THEN

									(* STYLE NAME *)
									s := p2(XML.Element).GetName();

									IF (s # NIL) THEN
										s := p2(XML.Element).GetAttributeValue(NameAttr);
										Strings.Copy(s^,0,Strings.Length(s^),name);

										s := p2(XML.Element).GetAttributeValue(ColorAttr);
										Strings.HexStrToInt(s^,color,temp);
										
										s := p2(XML.Element).GetAttributeValue(BgColorAttr);
										Strings.HexStrToInt(s^,bgcolor,temp);

										s := p2(XML.Element).GetAttributeValue(VoffAttr);
										Strings.StrToInt(s^,voff);

										s := p2(XML.Element).GetAttributeValue(FontNameAttr);
										Strings.Copy(s^,0,Strings.Length(s^),fontname);

										s := p2(XML.Element).GetAttributeValue(FontSizeAttr);
										Strings.StrToInt(s^,size);

										s := p2(XML.Element).GetAttributeValue(FontStyleAttr);
										Strings.StrToSet(s^,style);
										Strings.SetToStr(style, styleStr);

										IF (Strings.Match(name,commentblock)) THEN
											Strings.Copy(name,0,Strings.Length(name),Comments.name);
											NEW(Comments.attributes);
											Comments.attributes.Set(color, bgcolor, voff, fontname, size, style);
										END;
										
										IF (Strings.Match(name,inquotesblock)) THEN
											Strings.Copy(name,0,Strings.Length(name),InQuotes.name);
											NEW(InQuotes.attributes);
											InQuotes.attributes.Set(color, bgcolor, voff, fontname, size, style);
										ELSE
											Strings.Copy(name,0,Strings.Length(name),StyleList[styleIndex].name);
											NEW(StyleList[styleIndex].attributes);
											StyleList[styleIndex].attributes.Set(color, bgcolor, voff, fontname, size, style);
										END;

										INC(styleIndex);
									END;
								END;
							END;

						ELSE
							KernelLog.Ln;
							KernelLog.String("----Unknown kind of line in ");
							KernelLog.String(HighlightFile);
							KernelLog.String(" (line will be ignored)");
						END;		
					END;
				ELSE
					KernelLog.Ln;
					KernelLog.String("s = NIL");
				END;
			END;
		END;
	END;
	RETURN loaded;
END LoadXML;

PROCEDURE InitXML(): BOOLEAN;
VAR f: Files.File; scanner: XMLScanner.Scanner; parser: XMLParser.Parser; r: Files.Reader;
BEGIN {EXCLUSIVE}
	error := FALSE;
	highlight := NIL;
	f := Files.Old(HighlightFile);
	IF f # NIL THEN
		NEW(r, f, 0);
		NEW(scanner, r); 
		NEW(parser, scanner); 
		parser.reportError := TrapHandler; 
		highlight := parser.Parse();
		IF error THEN
			KernelLog.String("Error in "); KernelLog.String(HighlightFile); KernelLog.Ln;
			KernelLog.Ln;
		END;
	END;
	RETURN ~error;
END InitXML;

PROCEDURE TrapHandler(pos, line, row: LONGINT; CONST msg: ARRAY OF CHAR);
BEGIN
	IF ~error THEN
		KernelLog.String("Error in "); KernelLog.String(HighlightFile); KernelLog.String(" at position "); 
		KernelLog.String("pos= "); KernelLog.Int(pos, 0); KernelLog.String(" line= "); KernelLog.Int(line, 0); KernelLog.String(" row= "); KernelLog.Int(row, 0); 
		KernelLog.String(" !"); KernelLog.Ln
	ELSE
		KernelLog.String("Error in "); KernelLog.String(HighlightFile); KernelLog.String(" giving up!"); KernelLog.Ln;
	END;	
	error := TRUE; highlight := NIL;
END TrapHandler;

END Highlighter.

Highlighter.Test ~

SystemTools.Free Highlighter ~

