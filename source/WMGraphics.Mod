MODULE WMGraphics;	(** AUTHOR "TF"; PURPOSE "Generic Graphic Support"; *)

IMPORT
	Kernel, Rectangles := WMRectangles, Raster, KernelLog, UTF8Strings, Strings, RasterScale := WMRasterScale,
	Codecs, Files, Streams, Reals;

CONST
	(** Copy Modes *)
	ModeCopy* = RasterScale.ModeCopy; ModeSrcOverDst* = RasterScale.ModeSrcOverDst;

	(** Scale Modes *)
	ScaleBox* = RasterScale.ScaleBox; ScaleBilinear* = RasterScale.ScaleBilinear;

	(** Clip Modes *)
	ClipNone* = 0; ClipRect* = 1; (*ClipStencil* = 2;*)

	(** FontStyles *)
	FontBold* = 0; FontItalic* = 1;

	Black* = 0FFH; White* = SIGNED32(0FFFFFFFFH); Transparent*=0H;
	Gray*=SIGNED32(0777777FFH);
	Red* = SIGNED32(0FF0000FFH);
	DarkRed* = SIGNED32(08C0000FFH);
	Green* = 000FF00FFH; Blue* = 0FFFFH;
	Yellow* = SIGNED32(0FFFF00FFH);
	Magenta* = SIGNED32(0FF00FFFFH);
	Cyan* = 00FFFFFFH;
	Gold* = SIGNED32(0FFD700FFH);

TYPE
	Color* = Raster.Color;

	Real* = FLOAT32;
	Char32* = UTF8Strings.Char32;
	Point2d* = RECORD x*, y* : SIZE END;
	Image* = OBJECT(Raster.Image)
	VAR
		key* : POINTER TO ARRAY OF CHAR;
	END Image;

	Rectangle* = Rectangles.Rectangle;

	GlyphSpacings* = RECORD
		bearing* : Rectangle;
		width*, height*, ascent*, descent* : SIZE;
		dx*, dy* : SIZE; (** Delta position where the bitmap returned by GetGlyphMap has to be placed relatively to
											x, y on the base line *)
	END;

	(* Bearings are the blank spaces left an right of a character.
		bearing.l is the left, bearing.r is the right, bearing.t top and bearing.b the bottom side - bearing of the character
		hadvance = bearing.l + width + bearing.r --> the distance to the next character on the line without --> kerning
		vadvance = bearing.t + height + bearing.b --> the baseline to baseline distance of two lines of this font

		When rendering a character at the position (x, y), y refers to the y position of the baseline, x refers to .
		--> Kerning pairs


	*)
	(* ascent is the height of the font above the base line in units of the destination canvas *)
	(* descent is the height of the font below the base line in units of the destination canvas *)
	(* basetobasedist is the suggested distance between two lines of this font *)

	Font* = OBJECT
	VAR
		ascent*, descent* : SIZE;
		name* : ARRAY 256 OF CHAR;
		size* : SIZE;
		style* : SET;
		isScalable* : BOOLEAN;

		PROCEDURE &Init*;
		BEGIN
			ascent := 0; descent := 0;
			name := "";
			size := 0;
			style := {};
			isScalable := FALSE;
		END Init;

		PROCEDURE GetHeight*():SIZE;
		BEGIN
			RETURN ascent + descent
		END GetHeight;

		PROCEDURE GetAscent*():SIZE;
		BEGIN
			RETURN ascent
		END GetAscent;

		PROCEDURE GetDescent*():SIZE;
		BEGIN
			RETURN descent
		END GetDescent;

		(* return TRUE if the font can render the character *)
		PROCEDURE HasChar*(char : Char32) : BOOLEAN;
		BEGIN
			RETURN FALSE
		END HasChar;

		(** Render an UTF8 string to a canvas *)
		PROCEDURE RenderString*(canvas : Canvas ; x, y : Real; CONST text : ARRAY OF CHAR);
		VAR i, len: SIZE; code : Char32; g : GlyphSpacings;
		BEGIN
			len := LEN(text); i := 0;
			WHILE (i < len) & (text[i] # 0X) DO
				IF UTF8Strings.DecodeChar(text, i, code) THEN
					IF HasChar(code) THEN
						GetGlyphSpacings(code, g);
						RenderChar(canvas, x, y, code)
					ELSE
						FBGetGlyphSpacings(code, g);
						FBRenderChar(canvas, x, y, code)
					END;
					x := x + g.bearing.l + g.width + g.bearing.r
				ELSE INC(i) (* avoid endless loop *)
				END
			END
		END RenderString;

		(** Render an UTF8 string to a canvas *)
		PROCEDURE GetStringSize*(CONST text : ARRAY OF CHAR; VAR dx, dy : SIZE);
		VAR i, len: SIZE; code : Char32; g : GlyphSpacings;
		BEGIN
			len := LEN(text); i := 0; dx := 0; dy := GetHeight();
			WHILE (i < len) & (text[i] # 0X) DO
				IF UTF8Strings.DecodeChar(text, i, code) THEN
					IF HasChar(code) THEN GetGlyphSpacings(code, g);
					ELSE FBGetGlyphSpacings(code, g)
					END;
					dy := MAX(dy, g.height);
					dx := dx + g.bearing.l + g.width + g.bearing.r
				ELSE INC(i) (* avoid endless loop *)
				END
			END
		END GetStringSize;

		(** Render character char to canvas at x, y (baseline) *)
		PROCEDURE RenderChar*(canvas : Canvas ; x, y : Real; char : Char32);
		VAR g : GlyphSpacings; img : Image;
		BEGIN
			GetGlyphSpacings(char, g);
			GetGlyphMap(char, img);
			canvas.DrawImage(ENTIER(x + g.bearing.l) + g.dx, ENTIER(y - ascent) + g.dy, img, ModeSrcOverDst)
		END RenderChar;

		(** return a bitmap of character code *)
		PROCEDURE GetGlyphMap*(code : Char32; VAR map : Image);
		END GetGlyphMap;

		(** return spacing of character code *)
		PROCEDURE GetGlyphSpacings*(code : Char32; VAR glyphSpacings : GlyphSpacings);
		END GetGlyphSpacings;
	END Font;

	FontManager* = OBJECT
		PROCEDURE GetFont*(CONST name : ARRAY OF CHAR; size : SIZE; style : SET) : Font;
		BEGIN
			RETURN NIL
		END GetFont;

		PROCEDURE GetSystemFont*(CONST name : ARRAY OF CHAR) : Font;
		BEGIN
			RETURN NIL;
		END GetSystemFont;

		PROCEDURE GetSystemFontInfo*(CONST systemName : ARRAY OF CHAR; VAR name : ARRAY OF CHAR; VAR size: SIZE; VAR style: SET) : BOOLEAN;
		BEGIN
			RETURN FALSE;
		END GetSystemFontInfo;
	END FontManager;

	CanvasState* = RECORD
		clipMode : SET;
		clipRect : Rectangle;
		limits : Rectangle;
		dx, dy : SIZE;
		font : Font;
		color : Color;
	END;

	Canvas* = OBJECT
	VAR
		limits*, (* The limits to which the clip Rect can be set *)
		clipRect* : Rectangle; (* The current clip rectangle *)
		dx*, dy* : SIZE;
		color* : Color;
		clipMode* : SET;
		generator*: Strings.String;
		font- : Font;

		(** IF cs is NIL a new canvas state object is created for this canvas, otherwise cs is reused *)
		PROCEDURE SaveState*(VAR cs : CanvasState);
		BEGIN
			cs.clipMode := clipMode;
			cs.limits := limits;
			cs.dx := dx; cs.dy := dy;
			cs.font := font; cs.color := color;
			GetClipRect(cs.clipRect)
		END SaveState;

		(** Restore a previously saved canvas state *)
		PROCEDURE RestoreState*(CONST cs : CanvasState);
		BEGIN
			clipMode := cs.clipMode;
			limits := cs.limits;
			dx := cs.dx; dy := cs.dy;
			font := cs.font; color := cs.color;
			SetClipRect(cs.clipRect)
		END RestoreState;

		(** set the current clipping rectangle as the limit for new SetClipRect operations.
			ddx and ddy specify a coordinate shift. *)
		PROCEDURE ClipRectAsNewLimits*(ddx, ddy : SIZE);
		BEGIN
			limits := clipRect;
			SetDelta(dx + ddx, dy + ddy)
		END ClipRectAsNewLimits;

		(** in user coordinates *)
		PROCEDURE SetClipRect*(rect : Rectangle);
		BEGIN
			INCL(clipMode, ClipRect);
			rect.r := MAX(rect.r, rect.l); rect.b := MAX(rect.b, rect.t);
			Rectangles.MoveRel(rect, dx, dy);
			Rectangles.ClipRect(rect, limits);
			clipRect := rect
		END SetClipRect;

		(** return the current Clipping rectangle in user coordinates; Clients may use this to avoid drawing that is
			clipped away for sure *)
		PROCEDURE GetClipRect*(VAR rect : Rectangle);
		BEGIN
			rect := clipRect;
			Rectangles.MoveRel(rect, -dx, -dy)
		END GetClipRect;

		(**	*)
		PROCEDURE SetClipMode*(mode : SET);
		BEGIN
			clipMode := mode
		END SetClipMode;

		(** Set color for fonts *)
		PROCEDURE SetColor*(x : Color);
		BEGIN
			color := x
		END SetColor;

		PROCEDURE GetColor*() : Color;
		BEGIN
			RETURN color;
		END GetColor;

		(** Set the current font. IF f is NIL, GetFont will search for the system default font. *)
		PROCEDURE SetFont*(f: Font);
		BEGIN
			font := f
		END SetFont;

		(** Return the font currently set for this canvas. If no font is set, return the system default font. If no
			system default font is set, block until a default font is set *)
		PROCEDURE GetFont*():Font;
		BEGIN
			IF font = NIL THEN font := GetDefaultFont() END;
			RETURN font
		END GetFont;

		(** Draw an UTF8 String at position x, y (base line)
			The currently set font and color is used
		*)
		PROCEDURE DrawString*(x, y: SIZE; CONST text : ARRAY OF CHAR);
		BEGIN
			IF font # NIL THEN
				font.RenderString(SELF, x, y, text)
			END
		END DrawString;

		PROCEDURE SetLineWidth*(w : Real);
		BEGIN
			(* Dummy. But is implemented in WMGraphicsGfx *)
		END SetLineWidth;

		(** draw a line within the current clipping rectangle *)
		(** Override for improved speed *)
		PROCEDURE Line*(x0, y0, x1, y1 : SIZE; color : Color; mode : INTEGER);
		VAR t (*, xi, mi, xf, mf, dt2, ds2*) : SIZE; r: Rectangles.Rectangle;


			(* clipped bresenham algorithm according to
				Bresenham's Line Generation Algorithm with Built-in Clipping, Yevgeny P. Kuzmin, 1995
			*)
			PROCEDURE ClippedLine(x0,y0,x1,y1: SIZE; r: Rectangle; color : Color; mode : INTEGER);
			VAR
				dsx,dsy,stx,sty,xd,yd,dx2,dy2,rem,term,e: SIZE;
				tmp: SIGNED64;
				rev,setx: BOOLEAN;
			BEGIN
				(* standardization && trivial reject *)
				IF( x1 - x0 > 0 ) THEN
					IF ( x0 > r.r) OR (x1 < r.l ) THEN RETURN END;
					stx := 1;
				ELSE
					IF ( x1 > r.r) OR ( x0 < r.l ) THEN RETURN END;
					stx := -1;
					x0 :=-x0; x1 :=-x1;
					r.l :=-r.l; r.r :=-r.r;
					Swap(r.l,r.r);
				END;

				IF ( y1 - y0 > 0 ) THEN
					IF ( y0 > r.b) OR (y1 < r.t ) THEN RETURN END;
					sty:=1;
				ELSE
					IF ( y1 > r.b) OR (y0 < r.t ) THEN RETURN END;
					sty :=-1;
					y0 :=-y0; y1 :=-y1;
					r.t :=-r.t; r.b :=-r.b;
					Swap(r.t,r.b);
				END;

				dsx := x1-x0; dsy := y1-y0;
				IF ( dsx < dsy ) THEN
					rev := TRUE;
					Swap(x0,y0); Swap(x1,y1); Swap(dsx,dsy);
					Swap(r.l,r.t); Swap(r.r,r.b); Swap(stx,sty);
				ELSE
					rev := FALSE;
				END;

				(* Bresenham's set up *)
				dx2 := 2*dsx; dy2 := 2*dsy;
				xd := x0; yd :=y0;
				e := 2*dsy-dsx; term := x1;
				setx := TRUE;
				IF (y0 < r.t) THEN
					(* window horizontal entry *)
					tmp := SIGNED64(dx2) *(r.t-y0)-dsx;
					INC(xd,SIZE(tmp DIV dy2));
					rem := SIZE(tmp MOD dy2);
					IF ( xd>r.r ) THEN RETURN END;
					IF ( xd+1>=r.l ) THEN
						yd := r.t; DEC(e,rem+dsx);
						IF (rem>0 ) THEN INC(xd); INC(e,dy2) END;
						setx := FALSE;
					END;
				END;

				IF setx & ( x0 < r.l )  THEN
					(* window vertical entry *)
					tmp := SIGNED64(dy2) * (r.l-x0);
					INC(yd, SIZE(tmp DIV dx2));
					rem := SIZE(tmp MOD dx2);
					IF ( yd>r.b) OR (yd=r.b) & (rem>=dsx) THEN RETURN END;
					xd :=r.l; INC(e,rem);
					IF( rem>=dsx ) THEN INC(yd); DEC(e,dx2) END;
				END;

				IF ( y1 > r.b )  THEN
					(* window exit *)
					tmp := SIGNED64(dx2)*(r.b-y0)+dsx;
					term := x0+SIZE(tmp DIV dy2);
					rem := SIZE(tmp MOD dy2);
					IF ( rem=0 ) THEN DEC(term) END;
				END;
				IF ( term>r.r) THEN term := r.r; END;
				INC(term);
				IF ( sty =-1 ) THEN yd := -yd END;

				(* reverse transformation *)
				IF ( stx =-1 ) THEN xd := -xd; term := -term; END;
				DEC(dx2,dy2);

				(* Bresenham's line drawing *)
				IF rev THEN
					WHILE ( xd # term ) DO
						SetPixel(yd, xd, color, mode);
						IF ( e >= 0 ) THEN INC(xd, stx); INC(yd, sty); DEC(e,dx2)
						ELSE INC(xd, stx); INC(e, dy2);
						END;
					END;
				ELSE
					WHILE ( xd # term ) DO (* Bresenham's line drawing *)
							SetPixel(xd,yd, color, mode);
						IF ( e >= 0 ) THEN INC(xd, stx); INC(yd, sty); DEC(e,dx2)
						ELSE INC(xd, stx); INC(e, dy2);
						END;
					END;
				END;
			END ClippedLine;

		BEGIN
			IF y0 = y1 THEN (* horizontal case *)
				IF x0 > x1 THEN t := x0; x0 := x1; x1 := t END;
				Fill(Rectangles.MakeRect(x0, y0, x1 + 1, y0 + 1), color, mode)
			ELSIF x0 = x1 THEN (* vertical case *)
				IF y0 > y1 THEN t := y0; y0 := y1; y1 := t END;
				Fill(Rectangles.MakeRect(x0, y0, x0 + 1, y1 + 1), color, mode)
			ELSE (* general case *)
				GetClipRect(r);
				ClippedLine(x0,y0,x1,y1,r,color,mode);
				(*
				IF ABS(y1 - y0) > ABS(x1 - x0) THEN
					IF y0 > y1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
					xi := x0; xf :=	y0 - y1; mi := (x1 - x0) DIV (y1 - y0); mf := 2 * ( (x1 - x0) MOD (y1 - y0)); dt2 := 2 * (y1 - y0);
					GetClipRect(r);
					IF y0 < r.t THEN
						(* this loop should be replaced by a closed expression *)
						FOR t := y0 TO r.t-1 DO
							INC(xi, mi); INC(xf, mf);
							IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
						END;
						y0 := r.t;
					END;
					IF y1 > r.b THEN
						y1 := r.b;
					END;

					FOR t := y0 TO y1 DO
						SetPixel(xi, t, color, mode);
						INC(xi, mi); INC(xf, mf);
						IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
					END
				ELSE
					IF x0 > x1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
					xi := y0; xf :=	x0 - x1; mi := (y1 - y0) DIV (x1 - x0); mf := 2 * ( (y1 - y0) MOD (x1 - x0)); dt2 := 2 * (x1 - x0);
					GetClipRect(r);
					IF x0 < r.l THEN
						(* this loop should be replaced by a closed expression *)
						FOR t := x0 TO r.l-1 DO
							INC(xi, mi); INC(xf, mf);
							IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
						END;
						x0 := r.l;
					END;
					IF x1 > r.r THEN
						x1 := r.r;
					END;
					FOR t := x0 TO x1 DO
						SetPixel(t, xi, color, mode);
						INC(xi, mi); INC(xf, mf);
						IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
					END
				END
				*)
			END
		END Line;

		PROCEDURE LineReal*(x0, y0, x1, y1 : Real; color : Color; mode : INTEGER);
		BEGIN
			IF ~( Reals.IsNaN(x0) OR Reals.IsNaN(y0) OR Reals.IsNaN(x1) OR Reals.IsNaN(y1)) THEN
				Line(ENTIER(x0),ENTIER(y0),ENTIER(x1),ENTIER(y1),color,mode);
			END;
		END LineReal;

		(** set a pixel within the current clipping rectangle *)
		PROCEDURE SetPixel*(x, y : SIZE; color : Color; mode : INTEGER);
		BEGIN
			Fill(Rectangles.MakeRect(x, y, x + 1, y + 1), color, mode)
		END SetPixel;

		(** fill a rectangle within the current clipping rectangle *)
		PROCEDURE Fill*(rect : Rectangle; color : Color; mode : INTEGER);
		END Fill;

		(** fill a polygon given by points *)
		PROCEDURE FillPolygonFlat*(CONST points : ARRAY OF Point2d; nofPoints : SIZE; color : Color; mode : INTEGER);
		END FillPolygonFlat;

		PROCEDURE FillPolygonCB*(CONST points : ARRAY OF Point2d; nofPoints : SIZE; callBack : FillLineCallBack);
		END FillPolygonCB;

		PROCEDURE PolyLine*(CONST points : ARRAY OF Point2d; nofPoints : SIZE; closed : BOOLEAN;	color : Color; mode : INTEGER);
		VAR i : SIZE;
		BEGIN
			FOR i := 1 TO nofPoints - 1 DO
				Line(points[i-1].x, points[i-1].y, points[i].x, points[i].y, color, mode)
			END;
			IF closed THEN
				Line(points[nofPoints-1].x, points[nofPoints-1].y, points[0].x, points[0].y, color, mode)
			END
		END PolyLine;

		(** draw an image within the current clipping rectangle *)
		PROCEDURE DrawImage*(x, y: SIZE; image: Raster.Image; mode : INTEGER);
		END DrawImage;

		PROCEDURE ScaleImage*(src : Raster.Image; sr, dr : Rectangle; copyMode, scaleMode : INTEGER);
		END ScaleImage;

		(** Set coordinate shift *)
		PROCEDURE SetDelta*(dx, dy: SIZE);
		BEGIN
			SELF.dx := dx; SELF.dy := dy
		END SetDelta;

		(** Set the available range in the super drawing space *)
		PROCEDURE SetLimits*(r : Rectangle);
		BEGIN
			limits := r
		END SetLimits;

		(** Get the avalilable range in the super drawing space, like the range set but clipped *)
		PROCEDURE GetLimits*(): Rectangle;
		BEGIN
			RETURN limits
		END GetLimits;

	END Canvas;

TYPE
	FillPosEntry = RECORD pos, next : SIZE END;
	FillHeap = POINTER TO ARRAY OF FillPosEntry;
	FillLineCallBack* = PROCEDURE {DELEGATE} (canvas : Canvas; y, x0, x1 : SIZE);
	CanvasGenerator* = PROCEDURE(img:Raster.Image):BufferCanvas;

TYPE
	BufferCanvas* = OBJECT(Canvas)
	VAR img- : Raster.Image;
		bounds : Rectangle; (* real limiting img bounds *)
		(* filling *)
		fillHeap : FillHeap;
		heapSize, topHeap : SIZE;
		height : SIZE;
		edges : POINTER TO ARRAY OF SIZE;

		PROCEDURE &New*(img : Raster.Image);
		BEGIN
			SELF.img := img;
			bounds := Rectangles.MakeRect(0, 0, img.width, img.height);
			SetLimits(bounds);
			clipRect := bounds;
			clipMode := { ClipRect };
			(* filling *)
			height := img.height; NEW(edges, height);
			SetFont(GetDefaultFont());
			generator:=Strings.NewString("WMGraphics.GenCanvas");
		END New;

		(* Not thread-safe!!! *)
		PROCEDURE GetImage*() : Raster.Image;
		BEGIN
			RETURN img;
		END GetImage;

		PROCEDURE SetLimits*(r : Rectangle);
		BEGIN
			r.r := MAX(r.r, r.l); r.b := MAX(r.t, r.b);
			Rectangles.ClipRect(r, bounds); SetLimits^(r)
		END SetLimits;

	(*	PROCEDURE Line*(x0, y0, x1, y1 : SIZE; color : Color; mode : INTEGER);
		BEGIN
		END Line; *)

		PROCEDURE Fill*(rect : Rectangle; color : Color; mode : INTEGER);
		VAR rm : Raster.Mode; pix : Raster.Pixel;
		BEGIN
			(* convert to super coordinates *)
			Rectangles.MoveRel(rect, dx, dy);
			IF ClipRect IN clipMode THEN Rectangles.ClipRect(rect, clipRect) END;
			Rectangles.ClipRect(rect, limits);

			IF ~Rectangles.RectEmpty(rect) THEN
				Raster.SetRGBA(pix, ((color DIV 65536) DIV 256) MOD 256, (color DIV 65536) MOD 256,
				(color DIV 256) MOD 256, color MOD 256);

				IF mode = ModeCopy THEN Raster.InitMode(rm, Raster.srcCopy) ELSE Raster.InitMode(rm, Raster.srcOverDst) END;
				Raster.Fill(SELF.img, rect.l, rect.t, rect.r, rect.b, pix, rm);
			END
		END Fill;

		(* Polygon filling *)
		(** fill a polygon given by points *)
		PROCEDURE FillPolygonFlat*(CONST points : ARRAY OF Point2d; nofPoints : SIZE; color : Color; mode : INTEGER);
		VAR i : SIZE;
		BEGIN
			IF nofPoints < 3 THEN RETURN END;
			ASSERT(nofPoints <= LEN(points));
			ClearHeap;
			FOR i := 1 TO nofPoints - 1 DO AddLine(points[i - 1].x, points[i - 1].y, points[i].x, points[i].y) END;
			AddLine(points[nofPoints - 1].x, points[nofPoints - 1].y, points[0].x, points[0].y);
			FillFlat(color, mode)
		END FillPolygonFlat;

		(** fill a polygon given by points *)
		PROCEDURE FillPolygonCB*(CONST points : ARRAY OF Point2d; nofPoints : SIZE; callBack : FillLineCallBack);
		VAR i : SIZE;
		BEGIN
			IF nofPoints < 3 THEN RETURN END;
			ASSERT(nofPoints <= LEN(points));
			ClearHeap;
			FOR i := 1 TO nofPoints - 1 DO AddLine(points[i - 1].x, points[i - 1].y, points[i].x, points[i].y) END;
			AddLine(points[nofPoints - 1].x, points[nofPoints - 1].y, points[0].x, points[0].y);
			FillCB(callBack)
		END FillPolygonCB;

		 PROCEDURE ClearHeap;
		 VAR i : SIZE;
		 BEGIN
			topHeap := 0;
			FOR i := 0 TO height - 1 DO edges[i] := 0 END;
			IF fillHeap = NIL THEN NEW(fillHeap, 1024); heapSize := 1024 END
		 END ClearHeap;

		 PROCEDURE NewFillPos(pos : SIZE) : SIZE;
		 VAR newHeap : FillHeap;
			i : SIZE;
		 BEGIN
			INC(topHeap);
			IF topHeap >= heapSize THEN (* grow heap *)
				NEW(newHeap, heapSize * 2);
				FOR i := 0 TO heapSize - 1 DO newHeap[i] := fillHeap[i] END;
				heapSize := heapSize * 2;
				fillHeap := newHeap
			END;
			fillHeap[topHeap].pos := pos;
			fillHeap[topHeap].next := 0;
			RETURN topHeap
		 END NewFillPos;

		 PROCEDURE AddIntersection(y, pos : SIZE);
		 VAR new, cur : SIZE;
		 BEGIN
			IF (y < 0) OR (y >= height) THEN RETURN END;
			new := NewFillPos(pos);
			IF edges[y] = 0 THEN edges[y] := new
			ELSE
				cur := edges[y];
				IF fillHeap[cur].pos > pos THEN
					fillHeap[new].next := cur;
					edges[y] := new
				ELSE
					WHILE (fillHeap[cur].next # 0) & (fillHeap[fillHeap[cur].next].pos < pos) DO cur := fillHeap[cur].next END;
					fillHeap[new].next := fillHeap[cur].next;
					fillHeap[cur].next := new
				END;
			END;
		 END AddIntersection;

		PROCEDURE AddLine(x0, y0, x1, y1 : SIZE);
		VAR t, xi, xf, mi, mf, dt2	: SIZE ;
		BEGIN
			IF (y0 = y1) THEN RETURN END;
			IF y0 > y1 THEN t := y0; y0 := y1; y1 := t; t := x0; x0 := x1; x1 := t END;
			xi := x0; xf :=	y0 - y1; mi := (x1 - x0) DIV (y1 - y0); mf := 2 * ( (x1 - x0) MOD (y1 - y0)); dt2 := 2 * (y1 - y0);
			FOR t := y0 TO y1 - 1 DO
				AddIntersection(t, xi);
				INC(xi, mi); INC(xf, mf);
				IF xf > 0 THEN INC(xi); DEC(xf, dt2) END
			END
		END AddLine;

		PROCEDURE FillFlat(color : Color; mode : INTEGER);
		VAR i, sp, cur : SIZE;
		in : BOOLEAN;
		BEGIN
			FOR i := 0 TO height - 1 DO
				cur := edges[i];
				in := FALSE;
				WHILE cur # 0 DO
					in := ~in;
					IF in THEN sp := fillHeap[cur].pos
					ELSE Fill(Rectangles.MakeRect(sp, i, fillHeap[cur].pos, i + 1), color, mode)
					END;
					cur := fillHeap[cur].next
				END
			END
		END FillFlat;

		PROCEDURE FillCB(cb : FillLineCallBack);
		VAR i, sp, cur : SIZE;
		in : BOOLEAN;
		BEGIN
			FOR i := 0 TO height - 1 DO
				cur := edges[i];
				in := FALSE;
				WHILE cur # 0 DO
					in := ~in;
					IF in THEN sp := fillHeap[cur].pos
					ELSE cb(SELF, i, sp, fillHeap[cur].pos)
					END;
					cur := fillHeap[cur].next
				END
			END
		END FillCB;

		PROCEDURE DrawImage*(x, y: SIZE; img: Raster.Image; mode : INTEGER);
		VAR imgBounds : Rectangle;
			rm : Raster.Mode;
			dx, dy: SIZE;
		BEGIN
			IF (img = NIL) OR (img.adr = NIL) THEN RETURN END;
			dx := SELF.dx; dy := SELF.dy; (* avoid race below *)
			imgBounds := Rectangles.MakeRect(0, 0, img.width, img.height);

			(* to super coordinates *)
			Rectangles.MoveRel(imgBounds, x + dx, y + dy);
			IF ClipRect IN clipMode THEN Rectangles.ClipRect(imgBounds, clipRect) END;
			Rectangles.ClipRect(imgBounds, limits);

			IF ~Rectangles.RectEmpty(imgBounds) THEN
				IF mode = ModeCopy THEN Raster.InitMode(rm, Raster.srcCopy) ELSE Raster.InitMode(rm, Raster.srcOverDst) END;
				Raster.SetRGBA(rm.col, (color DIV 1000000H) MOD 100H, (color DIV 10000H) MOD 100H,
				(color DIV 100H) MOD 100H, color MOD 100H);
				IF imgBounds.l - (x + dx) < 0 THEN
					KernelLog.String("Error...");
					KernelLog.String("x + dx = "); KernelLog.Int(x + dx, 4); KernelLog.Ln;
					KernelLog.String("x = "); KernelLog.Int(x, 4); KernelLog.Ln;
					KernelLog.String("dx = "); KernelLog.Int(dx, 4); KernelLog.Ln;
					KernelLog.String("clip = "); KernelLog.Int(clipRect.l, 4); KernelLog.Int(clipRect.t, 4);
						KernelLog.Int(clipRect.r, 4); KernelLog.Int(clipRect.b, 4);KernelLog.Ln;
					KernelLog.String("imgBounds = ");
						KernelLog.Int(imgBounds.l, 4); KernelLog.Int(imgBounds.t, 4); KernelLog.Int(imgBounds.r, 4); KernelLog.Int(imgBounds.b, 4);KernelLog.Ln;
					KernelLog.String("limits = "); KernelLog.Int(limits.l, 4); KernelLog.Int(limits.t, 4);
						KernelLog.Int(limits.r, 4); KernelLog.Int(limits.b, 4);KernelLog.Ln;
					RETURN
				END;
				Raster.Copy(img, SELF.img,	imgBounds.l - (x + dx), imgBounds.t - (y + dy),
					imgBounds.r - imgBounds.l + (imgBounds.l - (x + dx)), imgBounds.b - imgBounds.t + (imgBounds.t - (y + dy)),
					imgBounds.l, imgBounds.t, rm);
			END;
		END DrawImage;

		PROCEDURE ScaleImage*(src : Raster.Image; sr , dr : Rectangle; copyMode, scaleMode : INTEGER);
		BEGIN
			Rectangles.MoveRel(dr, dx, dy);
			RasterScale.Scale(src, sr, img, dr, clipRect, copyMode, scaleMode);
		END ScaleImage;

	END BufferCanvas;


VAR imgCache : Kernel.FinalizedCollection;
	searchName : ARRAY 128 OF CHAR;
	foundImg : Image;

	defaultFont : Font;
	fontManager : FontManager;
	fallbackFonts* : ARRAY 5 OF Font;
	nofFallbackFonts : SIZE;

CONST
	AlignLeft* = 0; AlignCenter* = 1; AlignRight* = 2;
	AlignTop* = 0; AlignBottom* = 2;

PROCEDURE Swap(VAR a,b: SIZE);
VAR t: SIZE;
BEGIN
	t := a; a := b; b := t;
END Swap;

(* Tool Functions *)
PROCEDURE MakeRectangle*(l, t, r, b: SIZE):Rectangle;
VAR result : Rectangle;
BEGIN
	result.l := l; result.t := t; result.r := r; result.b := b; RETURN result
END MakeRectangle;

PROCEDURE ColorToRGBA*(color : Color; VAR r, g, b, a : Color);
BEGIN
	r := (color DIV 1000000H) MOD 100H;
	g := (color DIV 10000H) MOD 100H;
	b := (color DIV 100H) MOD 100H;
	a :=	color MOD 100H
END ColorToRGBA;

PROCEDURE RGBAToColor*(r, g, b, a: Color): Color;
BEGIN
	RETURN r * 1000000H + g * 10000H + b * 100H + a
END RGBAToColor;

PROCEDURE RGBtoHSL*(r, g, b: Color; VAR h, s, l: Color);
VAR delta, maxC, minC, HL: Color;
BEGIN
	h := 0; s := 0;
	maxC := MAX(r, MAX(g, b));
	minC := MIN(r, MIN(g, b));
	l := (maxC + minC) DIV 2;
	IF maxC # minC THEN
		delta := (maxC - minC) * 255;
		s := (delta DIV (maxC + minC) IF l <= 127 ELSE delta DIV (255 * 2 - maxC - minC)) MOD 256;

		delta := delta * 6;
		HL := (g - b) * 255 * 255 DIV delta IF r = maxC
			ELSE 255 * 2 DIV 6 + (b - r) * 255 * 255 DIV delta IF g = maxC
				ELSE 255 * 4 DIV 6 + (r - g) * 255 * 255 DIV delta;
		h := (HL + 255 * 2 IF HL < 0 ELSE HL) MOD 256;
	END;
END RGBtoHSL;

PROCEDURE HSLtoRGB*(h, s, l: Color; VAR r, g, b: Color);
VAR v, vsf, m, m1, m2: Color;
BEGIN
	r := 0; g := 0; b := 0;
	v := l * (256 + s) DIV 256 IF l <= 127 ELSE l + s - l * s DIV 255;
	IF v > 0 THEN
		m := l * 2 - v;
		h := h * 6;
		vsf := (v - m) * (h MOD 256) DIV 256;
		m1 := (m + vsf) MOD 256;
		m2 := (v - vsf) MOD 256;
		m := m MOD 256;
		CASE h DIV 256 OF
			|0: r := v; g := m1; b := m;
		 	|1: r := m2; g := v; b := m;
		 	|2: r := m; g := v; b := m1;
		 	|3: r := m; g := m2; b := v;
		 	|4: r := m1; g := m; b := v;
		 	|5: r := v; g := m; b := m2;
		END;
	END;
END HSLtoRGB;

PROCEDURE ComplementaryRGB*(r, g, b: Color; VAR R, G, B: Color);
VAR h, s, l: Color;
BEGIN
  RGBtoHSL(r, g, b, h, s, l);
  h := h + 128;
  IF h > 255 THEN h := h - 255 END;
  HSLtoRGB(h, s, l, R, G, B);
END ComplementaryRGB;

PROCEDURE DominantRGB*(r, g, b: Color; VAR R, G, B: Color);
VAR maxValue: Color;
BEGIN
	maxValue := MAX(r, MAX(b, g));
	IF r = maxValue THEN
		r := 255;
		b := 64;
		g := 64;
	ELSIF b = maxValue THEN
		r := 64;
		g := 64;
		b := 255;
	ELSIF g = maxValue THEN
		r := 64;
		g := 255;
		b := 64;
	END;
	R := r;
	G := g;
	B := b;
END DominantRGB;

PROCEDURE ChangeBrightnessHSL*(r, g, b: Color; VAR R, G, B: Color; amount: SIGNED32);
VAR h, s, l: Color;
BEGIN
  RGBtoHSL(r, g, b, h, s, l);
  l := l + amount;
  l := MIN(MAX(l, 0), 255);
  HSLtoRGB(h, s, l, R, G, B);
END ChangeBrightnessHSL;

PROCEDURE Dark*(color:Color):Color;
VAR c:Color;
BEGIN
	c := MAX(0, (color DIV 1000000H) MOD 100H-40H);
	c := 100H * c + MAX(0, (color DIV 10000H) MOD 100H - 40H);
	c := 100H * c +MAX(0, (color DIV 100H) MOD 100H-40H);
	c := 100H * c + color MOD 100H;
	RETURN c;
END Dark;

PROCEDURE Light*(color:Color):Color;
VAR c:Color;
BEGIN
	c := MIN(0FFH, (color DIV 1000000H) MOD 100H + 40H);
	c := 100H * c + MIN(0FFH, (color DIV 10000H) MOD 100H + 40H);
	c := 100H * c +MIN(0FFH, (color DIV 100H) MOD 100H + 40H);
	c := 100H * c + color MOD 100H;
	RETURN c;
END Light;

PROCEDURE CheckImage(obj: ANY; VAR cont: BOOLEAN);
BEGIN
	IF obj IS Image THEN
		IF obj(Image).key # NIL THEN
			IF obj(Image).key^ = searchName THEN
				foundImg := obj(Image);
				cont := FALSE
			END
		END
	END
END CheckImage;


PROCEDURE GetExtension (CONST name : ARRAY OF CHAR;VAR ext: ARRAY OF CHAR);
VAR i, j: SIZE; ch: CHAR;
BEGIN
	i := 0; j := 0;
	WHILE name[i] # 0X DO
		IF name[i] = "." THEN j := i+1 END;
		INC(i)
	END;
	i := 0;
	REPEAT
		ch := name[j]; ext[i] := ch; INC(i); INC(j)
	UNTIL (ch = 0X) OR (i = LEN(ext));
	ext[i-1] := 0X
END GetExtension;

(** loads an image and returns a BGRA8888 bitmap if successful, NIL otherwise.
	If shared is TRUE, the image will not be reloaded if it is already in memory.
*)
PROCEDURE LoadImage*(CONST name : ARRAY OF CHAR; shared : BOOLEAN): Image;
VAR img : Image;
	res: INTEGER; w, h : SIZE; x : SIGNED32;
	decoder : Codecs.ImageDecoder;
	in : Streams.Reader;
	ext : ARRAY 16 OF CHAR;

BEGIN
	IF name = "" THEN RETURN NIL END;
	BEGIN {EXCLUSIVE}
		IF shared THEN
			foundImg := NIL; COPY(name, searchName);
			imgCache.Enumerate(CheckImage);
			IF foundImg # NIL THEN RETURN foundImg END
		END;
	END;

	GetExtension(name, ext);
	Strings.UpperCase(ext);
	decoder := Codecs.GetImageDecoder(ext);

	IF decoder = NIL THEN
		KernelLog.String("No decoder found for "); KernelLog.String(ext); KernelLog.Ln;
		RETURN NIL
	END;
	in := Codecs.OpenInputStream(name);
	IF in # NIL THEN
		decoder.Open(in, res);
		IF res = 0 THEN
			decoder.GetImageInfo(w, h, x, x);
			NEW(img);
			Raster.Create(img, w, h, Raster.BGRA8888);
			decoder.Render(img);
			NEW(img.key, LEN(name)); COPY(name, img.key^);
			IF shared THEN imgCache.Add(img, NIL) END
		END
	END;
	RETURN img
END LoadImage;

PROCEDURE StoreImage*(img : Raster.Image; CONST name : ARRAY OF CHAR; VAR res : INTEGER);
VAR encoder : Codecs.ImageEncoder;
	f : Files.File;
	w : Files.Writer;
	ext : ARRAY 16 OF CHAR;
BEGIN
	res := -1;
	GetExtension(name, ext);
	Strings.UpperCase(ext);
	encoder := Codecs.GetImageEncoder(ext);

	IF encoder = NIL THEN
		KernelLog.String("No encoder found for "); KernelLog.String(ext); KernelLog.Ln;
		RETURN
	END;

	f := Files.New(name);
	IF f # NIL THEN
		Files.OpenWriter(w, f, 0);
	END;

	IF w # NIL THEN
		encoder.Open(w);
		encoder.WriteImage(img, res);
		Files.Register(f);
	END
END StoreImage;


(** Draw an UTF8 String in a rectangle *)
PROCEDURE DrawStringInRect*(canvas : Canvas; rect : Rectangle; wrap : BOOLEAN; hAlign, vAlign : INTEGER;
								CONST text : ARRAY OF CHAR);
VAR tw, th, xPos, yPos : SIZE;
	font : Font;
BEGIN
	font := canvas.GetFont();
	IF font # NIL THEN
		font.GetStringSize(text, tw, th);
	END;
	xPos := rect.l; yPos := rect.t + font.GetAscent();
	IF ~wrap THEN
		IF hAlign = AlignCenter THEN xPos := ((rect.l + rect.r) - tw) DIV 2
		ELSIF hAlign = AlignRight THEN xPos := rect.r - tw
		END;
		IF vAlign = AlignCenter THEN yPos := (rect.t + rect.b - font.GetDescent() - font.GetAscent() ) DIV 2 + font.GetAscent() ;
		ELSIF vAlign = AlignBottom THEN yPos := rect.b - font.GetDescent();
		END;
		canvas.DrawString(xPos, yPos, text);
	ELSE
		(* not implemented *)
	END
END DrawStringInRect;

PROCEDURE GenCanvas*(img:Raster.Image):BufferCanvas;
VAR c:BufferCanvas;
BEGIN
	NEW(c,img); RETURN c
END GenCanvas;


PROCEDURE InstallDefaultFont*(f : Font);
BEGIN { EXCLUSIVE }
	defaultFont := f;
	fallbackFonts[0] := defaultFont
END InstallDefaultFont;

PROCEDURE GetDefaultFont*() : Font;
BEGIN { EXCLUSIVE }
	AWAIT(defaultFont # NIL);
	RETURN defaultFont
END GetDefaultFont;

PROCEDURE InstallFontManager*(fm : FontManager);
BEGIN { EXCLUSIVE }
	fontManager := fm;
	IF fontManager # NIL THEN
		fallbackFonts[1] := fontManager.GetFont("Single", 20, {});
	END
END InstallFontManager;

PROCEDURE GetSystemFontFamily*(CONST systemName: ARRAY OF CHAR; VAR name: ARRAY OF CHAR): BOOLEAN;
VAR size: SIZE; style: SET;
BEGIN
	RETURN (fontManager # NIL) & fontManager.GetSystemFontInfo(systemName, name, size, style);
END GetSystemFontFamily;

PROCEDURE GetSystemFontSize*(CONST systemName: ARRAY OF CHAR; VAR size: SIZE) : BOOLEAN;
VAR name(*unused*): ARRAY 2 OF CHAR; style: SET;
BEGIN
	RETURN (fontManager # NIL) & fontManager.GetSystemFontInfo(systemName, name, size, style);
END GetSystemFontSize;

PROCEDURE GetSystemFontInfo*(CONST systemName : ARRAY OF CHAR; VAR name : ARRAY OF CHAR; VAR size: SIZE; VAR style: SET) : BOOLEAN;
BEGIN
	RETURN (fontManager # NIL) & fontManager.GetSystemFontInfo(systemName, name, size, style);
END GetSystemFontInfo;

PROCEDURE GetSystemFont*(CONST name: ARRAY OF CHAR; VAR font: Font): BOOLEAN;
BEGIN { EXCLUSIVE }
	font := NIL;
	IF fontManager # NIL THEN font := fontManager.GetSystemFont(name) END;
	RETURN font # NIL;
END GetSystemFont;

(*Workaround:
	If the font with a weight other than Bold is required, use a full name of the file (for ttf-fonts) with empty style.
	For example: GetFont( "IBMPlexSans-SemiBold", 24, {} );
*)
PROCEDURE GetFont*(CONST name : ARRAY OF CHAR; size : SIZE; style : SET) : Font;
VAR f := NIL: Font; fontName: ARRAY 256 OF CHAR;
BEGIN { EXCLUSIVE }
	COPY(name, fontName);
	REPEAT
	UNTIL ~GetSystemFontFamily(fontName, fontName);
	IF fontManager # NIL THEN f := fontManager.GetFont(fontName, size, style) END;
	IF f = NIL THEN AWAIT(defaultFont # NIL); f := defaultFont END;
	RETURN f
END GetFont;

(** Render the fallback case of the character char to canvas at x, y (baseline) *)
PROCEDURE FBRenderChar*(canvas : Canvas; x, y : Real; char : Char32);
VAR i, w, h : SIZE; f : Font; found : BOOLEAN; str : ARRAY 16 OF CHAR; r: Rectangles.Rectangle;
BEGIN
	i := 0; found := FALSE;
	WHILE ~found & (i < nofFallbackFonts) DO
		f := fallbackFonts[i];
		IF (f # NIL) & f.HasChar(char) THEN found := TRUE END;
		INC(i)
	END;
	IF found THEN f.RenderChar(canvas, x, y, char)
	ELSIF (char > ORD(' ')) THEN
		f := GetDefaultFont();
		Strings.IntToStr(char,str); Strings.Concat("U", str, str);
		f.GetStringSize(str, w, h);
		r := Rectangles.MakeRect(ENTIER(x), ENTIER(y) - f.ascent, ENTIER(x) + w, ENTIER(y) + f.descent);
		canvas.Fill(r, SIGNED32(0CCCC00FFH), ModeCopy);
		f.RenderString(canvas, x, y, str)
	END
END FBRenderChar;

(** return the fallback spacing of character code *)
PROCEDURE FBGetGlyphSpacings*(code : Char32; VAR glyphSpacings : GlyphSpacings);
VAR i : SIZE; f : Font; found : BOOLEAN; str : ARRAY 16 OF CHAR;
BEGIN
	i := 0; found := FALSE;
	WHILE ~found & (i < nofFallbackFonts) DO
		f := fallbackFonts[i];
		IF (f # NIL) & f.HasChar(code) THEN found := TRUE END;
		INC(i)
	END;
	IF found THEN f.GetGlyphSpacings(code, glyphSpacings)
	ELSIF (code > ORD(' ')) THEN
		f := GetDefaultFont();
		Strings.IntToStr(code, str); Strings.Concat("U", str, str);
		glyphSpacings.bearing := Rectangles.MakeRect(0, 0, 0, 0);
		f.GetStringSize(str, glyphSpacings.width, glyphSpacings.height);
		glyphSpacings.ascent := f.ascent; glyphSpacings.descent := f.descent;
		glyphSpacings.dx := 0; glyphSpacings.dy := 0
	END
END FBGetGlyphSpacings;

(** Tools *)
(* Return true if the alpha value at pos x, y in img is >= threshold. Returns false if x, y are out of image *)
PROCEDURE IsBitmapHit*(x, y: SIZE; threshold: SIGNED32; img: Raster.Image) : BOOLEAN;
VAR pix : Raster.Pixel;
	mode : Raster.Mode;
BEGIN
	IF (img # NIL) & (x >= 0) & (y >= 0) & (x < img.width) & (y < img.height) THEN
		Raster.InitMode(mode, Raster.srcCopy);
		Raster.Get(img, x, y, pix, mode);
		RETURN (ORD(pix[Raster.a]) >= threshold)
	ELSE RETURN FALSE
	END
END IsBitmapHit;

PROCEDURE IsScaledBitmapHit*(x,y,w,h: SIZE; threshold: SIGNED32; img: Raster.Image): BOOLEAN;
BEGIN
	RETURN IsBitmapHit(x*img.width DIV w, y*img.height DIV h, threshold,img);
END IsScaledBitmapHit;

PROCEDURE ClearCache*;
BEGIN
	imgCache.Clear;
END ClearCache;


BEGIN
	nofFallbackFonts := 3;
	NEW(imgCache)
END WMGraphics.

Release.Rebuild -b Win64 WMGraphics.Mod WMFontManager.Mod~