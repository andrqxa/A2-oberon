MODULE WMFunctionBar; (** AUTHOR "BohdanT"; PURPOSE "functional key bar"; *)

IMPORT
	Strings, XML, WMGraphics, WMProperties, WMComponents, WMEvents, WMRectangles, Inputs;
CONST
	(** shift key states. *)
	Shift* = 1; Ctrl* = 2; 	Alt* = 3; Meta* = 4; 

TYPE
	EventSource = WMEvents.EventListener;


	FuncArr* = ARRAY 5 OF ARRAY 13 OF RECORD
		caption* : ARRAY 16 OF CHAR;
		onClick* : EventSource;
	END;
	FunctionBar* = OBJECT(WMComponents.VisualComponent)
	VAR
		textColor- : WMProperties.ColorProperty;
		funcArr* : FuncArr;
		curflags : SIZE;
		clickRect : WMRectangles.Rectangle;
		curfunc : SIZE;
		PROCEDURE SetFunc*(shiftkey,key:SIZE;CONST caption:ARRAY 16 OF CHAR;CONST onClick:EventSource);
		BEGIN
			funcArr[shiftkey,key].caption:=caption;
			funcArr[shiftkey,key].onClick:=onClick;
		END SetFunc;
		
		PROCEDURE &Init;
		BEGIN
			Init^;
			curfunc:=0; curflags :=0;
			SetNameAsString(StrFunctionBar);
			NEW(textColor, NIL, NIL, NIL); properties.Add(textColor);
		END Init;

		PROCEDURE Initialize;
		BEGIN (* called by sequencer -> hierarchy is locked *)
			Initialize^;
			(* Is called by component.Reset() to, (also when put into FormWindow). Without initialization, the component will not respond to messages *)
		END Initialize;

		(* 	Call upon change of single property. If multiple properties have been changed, <property> has the value <properties>
			and RecacheProperties is called addtionally *)
		PROCEDURE PropertyChanged(sender, property : ANY);
		BEGIN (* called by sequencer -> hierarchy is locked *)
				PropertyChanged^(sender, property);
		END PropertyChanged;

		(* Called whenever component is resetted (also when put into FormWindow) *)
		PROCEDURE RecacheProperties;
		BEGIN (* called by sequencer -> hierarchy is locked *)
			RecacheProperties^;
		END RecacheProperties;

		PROCEDURE DrawBackground(canvas : WMGraphics.Canvas);
		VAR
			i, l, w, fw, dy: SIZE;
			font : WMGraphics.Font;
			width, height, x : SIZE;
		VAR
			fkStr : ARRAY 3 OF CHAR;

		BEGIN (* called by sequencer -> hierarchy is locked *)
			IF ~visible.Get() THEN RETURN END;
			Acquire;
			font := GetFont();
			canvas.SetFont(font);
			canvas.SetColor(WMGraphics.Black);
			width := bounds.GetWidth();
			height := bounds.GetHeight();

			canvas.Fill(WMRectangles.MakeRect(0, 0, width, height), WMGraphics.Black, WMGraphics.ModeCopy);
			w:=width DIV 12;
			font.GetStringSize('888', fw, dy);
			canvas.SetColor(textColor.Get());

			FOR i:=0 TO 11 DO
				l:=w*i;
				Strings.IntToStr(i+1, fkStr);
				font.GetStringSize(fkStr, x, dy);
				canvas.SetColor(SIGNED32(0FFFF00FFH));

				WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(l, 0, l+fw, height), FALSE, WMGraphics.AlignRight, WMGraphics.AlignCenter, funcCap[i]);

				canvas.Fill(WMRectangles.MakeRect(l+fw, 0, l+w, height), fillColor.Get(), WMGraphics.ModeCopy);
				WMGraphics.DrawStringInRect(canvas, WMRectangles.MakeRect(l+fw, 0, l+w, height), FALSE, WMGraphics.AlignCenter, WMGraphics.AlignCenter, funcArr[curflags,i+1].caption);
					
			END;
			Release;
		END DrawBackground;
		
		PROCEDURE PointerDown*(x, y: SIZE; keys : SET); (** PROTECTED *)
		VAR
			w:SIZE;
		BEGIN
			IF enabled.Get() THEN 
					w := bounds.GetWidth() DIV 12;
					IF w#0 THEN
						curfunc:=x DIV w;
						clickRect:=WMRectangles.MakeRect(curfunc*w,0,(curfunc+1)*w,bounds.GetHeight());
					END;
			END;
			PointerDown^(x, y, keys)
		END PointerDown;
		PROCEDURE PointerUp*(x, y : SIZE; keys : SET); (** PROTECTED *)
		BEGIN
			IF WMRectangles.PointInRect(x, y, clickRect) THEN
					IF funcArr[curflags,curfunc+1].onClick#NIL THEN 
						funcArr[curflags,curfunc+1].onClick(NIL,NIL);
					END;

			END;
			PointerUp^(x, y, keys)
		END PointerUp;

		PROCEDURE GetFlagsString(flags : SET):SIZE;
		BEGIN
			IF Inputs.LeftCtrl IN flags THEN RETURN  Ctrl END;
			IF Inputs.RightCtrl IN flags THEN RETURN  Ctrl  END;
			
			IF Inputs.LeftShift IN flags THEN RETURN  Shift  END;
			IF Inputs.RightShift IN flags THEN RETURN  Shift END;
			
			IF Inputs.LeftAlt IN flags THEN RETURN  Alt END;
			IF Inputs.RightAlt IN flags THEN RETURN  Alt END;
			
(*			IF Inputs.LeftMeta IN flags THEN RETURN  Meta END;
			IF Inputs.RightMeta IN flags THEN RETURN  Meta END;*)
			RETURN 0;
		END GetFlagsString;
		
		PROCEDURE HandleShortcut*(ucs : SIZE; flags: SET; VAR keysym: SIZE):BOOLEAN; (** PROTECTED *)

		VAR 
			x : SIZE;
		BEGIN
			IF keysym # 0 THEN
				x:=GetFlagsString(flags);
				IF curflags#x THEN
					curflags:=x;
					Invalidate;
				END;
				IF (keysym>=0FFBEH) & (keysym<=0FFC9H) THEN 
					IF funcArr[x,keysym-0FFBEH+1].onClick#NIL THEN 
						funcArr[x,keysym-0FFBEH+1].onClick(NIL,NIL);
						RETURN TRUE
					END;
					RETURN FALSE; 
				ELSE 
					RETURN FALSE; 
				END;
			END;
			RETURN FALSE;
		END HandleShortcut;


	END FunctionBar;

VAR
	(* String constants *)
	StrFunctionBar,
	StrProperty, StrPropertyDescription,
	StrPropertyCached, StrPropertyCachedDescription : Strings.String;

	funcCap:ARRAY 13 OF ARRAY 4 OF CHAR;
	
PROCEDURE GenFunctionbar*() : XML.Element;
VAR functionbar : FunctionBar;
BEGIN
	NEW(functionbar); RETURN functionbar;
END GenFunctionbar;

PROCEDURE InitStrings;
VAR
	i:SIZE;
	fkStr:ARRAY 4 OF CHAR;
BEGIN
		FOR i:=0 TO 11 DO
			Strings.IntToStr(i+1, fkStr);
			funcCap[i]:=fkStr;
		END;

	StrFunctionBar := Strings.NewString("FunctionBar");
	StrProperty := Strings.NewString("Property");
	StrPropertyDescription := Strings.NewString("Description of Property");
	StrPropertyCached := Strings.NewString("PropertyCached");
	StrPropertyCachedDescription := Strings.NewString("Description of PropertyCached");
END InitStrings;

BEGIN
	InitStrings;
END WMFunctionBar.
