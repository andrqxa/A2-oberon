MODULE wedgeArrays IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT antsArrayObjects, Math := MathL IN A2, wedgeLinearEq, wedgeQuadraticEq, wedgeGenericEq, antsHybridObjects, Objects, Files, Out, 
	aM := antsMessages, Display, antsCommands, vyRandom;  

TYPE 
	LineArray = POINTER TO ARRAY OF SIZE;  
	Function2d* = PROCEDURE {DELEGATE} ( x, y: FLOAT64 ): FLOAT64;  

	LineObject* = OBJECT (antsHybridObjects.Object)
	VAR XbyY, YbyX: LineArray;  
		(* XbyY:  x offset by y offset, YbyX: vice versa, if not unique then last possible value in line direction is taken  
		since dy > 0: YByX[x] is always uppermost pixel at position x
		*)
		a: LineArray;   (* area under line *)
		dx-, dy-: SIZE;   (* total length of line in x and y direction, dy >= 0 guaranteed *)
		w-, h-: SIZE;   (* surrounding max rectangle *)
		vertical-: BOOLEAN;  
		(* dy < 0 => tabellieren wird umgedreht in x-Richtung, denn wir tabellieren IMMER von unten nach oben !*)
		
		(*
		
		*)
		
		PROCEDURE & InitX*( dx, dy, w, h: SIZE );   (* visual test passed 13.09.2004 *)
		(** compute the line offsets of a line with angle "angle", algorithm: Bresenham *)
		VAR x, y, inx, d, dy2, dx2, oldx, oldy, X1, Y1: SIZE;  

			PROCEDURE MakeAreaArray;   (* visual test passed 13.09.2004 *)
			VAR oldx, newx: SIZE;  
			BEGIN 
				IF vertical THEN 
					NEW( a, ABS( dy ) + 1 );  a[0] := 1 (* first pixel ! *) ;  oldx := XbyY[0];  
					FOR y := 1 TO ABS( dy ) DO 
						newx := XbyY[y];  
						IF oldx # newx THEN  (* same x position ? *)
							a[y] := a[y - 1] + y + 1;   (* new line => take column below y *)
							oldx := newx;  
						ELSE 
							a[y] := a[y - 1] + 1;   (* same line => increasement by 1 only *)
						END;  
					END;  
				ELSE 
					NEW( a, ABS( dx ) + 1 );  
					IF SELF.dx > 0 THEN 
						a[0] := YbyX[0] + 1;  
						FOR x := 1 TO ABS( dx ) DO a[x] := YbyX[x] + 1 + a[x - 1];  END;  
					ELSE 
						a[ABS( dx )] := YbyX[ABS( dx )] + 1;  
						FOR x := ABS( dx ) - 1 TO 0 BY -1 DO a[x] := YbyX[x] + 1 + a[x + 1];  END;  
					END;  
				END;  
			END MakeAreaArray;  

		BEGIN 
			Init;   (* call to antsHybridObjects.Object for handler etc. *)
			ASSERT ( w > 0, 100 );   (* frame for size of arrays *)
			ASSERT ( h > 0, 101 );  
			ASSERT ( (dx # 0) OR (dy # 0), 102 );   (* preconditions *)
			
			SELF.h := h;  SELF.w := w;   (* boundary dimensions *) DEC( h );  DEC( w );  
			
			IF dy < 0 THEN dx := -dx;  dy := -dy
			END;  
			(***! from here on dy >= 0 *)
			vertical := dy > ABS( dx );  
			
			IF vertical THEN dx := ENTIER( dx * h / dy + 0.5 );  dy := h;  
			ELSE 
				dy := ENTIER( dy * w / ABS( dx ) + 0.5 );  
				IF dx >= 0 THEN dx := w ELSE dx := -w END;  
			END;  
			
			SELF.dx := dx;  SELF.dy := dy;   (* line dimensions *)
			
			IF dx < 0 THEN x := ABS( dx );  X1 := 0 ELSE x := 0;  X1 := dx END;  
			y := 0;  Y1 := ABS( dy );  

			NEW( YbyX, ABS( dx ) + 1 );  NEW( XbyY, ABS( dy ) + 1 );  XbyY[y] := x;  YbyX[x] := y;  oldx := x;  oldy := y;  
			
			IF vertical THEN 
				d := -ABS( dx );  dy2 := 2 * dy;  dx2 := 2 * ABS( dx );  
				IF dx < 0 THEN inx := -1;  ELSE inx := 1;  END;  
				
				WHILE (y # Y1) DO 
					INC( y );  INC( d, dx2 );  
					IF d > 0 THEN INC( x, inx );  DEC( d, dy2 );  END;  
					
					XbyY[y] := x;   (* line takes on new value in y direction *)
					IF oldx # x THEN YbyX[oldx] := oldy;  END;   (* line takes on new value in x direction *)
					oldx := x;  oldy := y;  
				END;  
				YbyX[oldx] := oldy;  
			ELSE  (* ~vertical *)
				
				d := -ABS( dx );  dy2 := 2 * dy;  dx2 := 2 * ABS( dx );  
				IF dx < 0 THEN inx := -1;  ELSE inx := 1;  END;  
				
				WHILE (x # X1) DO 
					INC( x, inx );  INC( d, dy2 );  
					IF d > 0 THEN INC( y );  DEC( d, dx2 );  END;  
					
					IF oldy # y THEN XbyY[oldy] := oldx
					END;   (* line takes on new value in y direction *)
					YbyX[x] := y;   (* line takes on new value in x direction *)
					oldx := x;  oldy := y;  
				END;  
				XbyY[oldy] := oldx;  
			END;  
			MakeAreaArray;   (* dbgOut;  			CheckLineIntegrity( SELF ); *)  (* post conditions *)
		END InitX;  

		PROCEDURE GetLineNr*( x, y: SIZE ): SIZE;  
		(* get offset identifying lines parallel to the "template" line through 0,0 
			offset is in x direction if line is vertical, is in y direction is line is not vertical
		*)
		VAR d: SIZE;  
		BEGIN 
			IF vertical THEN d := XbyY[y];  d := x - d;  ELSE d := YbyX[x];  d := y - d;  END;  
			RETURN d;  
		END GetLineNr;  

		PROCEDURE PreviousForCumSum*( x, y: SIZE;  VAR px, py: SIZE;  VAR inRange: BOOLEAN ): BOOLEAN;   (* visual test passed 13.09.2004 *)
		(* get previous position in line starting at (x,y) *)
		(* line must be computed such, that increase/decrease in constant 1 on x or y (as done by Init) *)
		VAR d: SIZE;  
		BEGIN 
			ASSERT ( vertical OR ((x <= ABS( dx )) & (x >= 0)), 100 );  
			ASSERT ( (~vertical) OR ((y <= ABS( dy )) & (y >= 0)), 101 );  
			inRange := FALSE;  
			
			IF vertical THEN  (* ABS(dy) > ABS(dx) *)
				d := XbyY[y];  d := x - d;   (* horizontal distance to line *)
				IF (dx > 0) THEN 
					px := x - d - 1;  
					IF px < 0 THEN RETURN FALSE END;  
				ELSE 
					px := x - d + 1;  
					IF px > ABS( dx ) THEN RETURN FALSE END;  
				END;  
				py := YbyX[px];  INC( px, d );  
				IF (0 <= px) & (px < w) THEN inRange := TRUE END;  
				RETURN TRUE;  
			ELSE 
				d := YbyX[x];  d := y - d;   (* vertical distance to line *)
				IF (dx > 0) THEN 
					px := x - 1;  
					IF px < 0 THEN RETURN FALSE END;  
				ELSE 
					px := x + 1;  
					IF px > ABS( dx ) THEN RETURN FALSE END;  
				END;  
				py := YbyX[px];  INC( py, d );   (* add vertical distance to get back *)
				IF (0 <= py) & (py < h) THEN inRange := TRUE END;  
				RETURN TRUE;  
			END;  
		END PreviousForCumSum;  

		PROCEDURE IntersectWRect*( linenr: SIZE;  x, y, w, h: SIZE;  VAR sx, sy, ex, ey: SIZE ): BOOLEAN;  
		VAR xx, yy: ARRAY 2 OF SIZE;  
			this: SIZE;  tx, ty: SIZE;  
			
			(*
				PROCEDURE InRange( this, from, w: SIZE ): BOOLEAN;  
			BEGIN 
				IF (from <= this) & (from + w > this) THEN RETURN TRUE ELSE RETURN FALSE END;  
			END InRange;  
			*)
			
		BEGIN 
			IF vertical THEN 
				DEC( x, linenr );   (* consider shifted rectangle *)
				
				this := 0;  ty := y;  tx := XbyY[ty];  
				IF  (*InRange( tx, x, w ) *)
				(tx >= x) & (tx < x + w) THEN 
					xx[this] := tx + linenr;  yy[this] := ty;  INC( this );  
				END;  
				ty := y + h - 1;  tx := XbyY[ty];  
				IF (tx >= x) & (tx < x + w)
				(*
				InRange( tx, x, w )*)
				THEN 
					xx[this] := tx + linenr;  yy[this] := ty;  INC( this );  
				END;  
				IF (this < 2) &  (*InRange( x, 0, LEN( YbyX ) ) *)
				(x >= 0) & (x < LEN( YbyX )) THEN 
					tx := x;  ty := YbyX[tx];  
					IF  (*InRange( ty, y, h )*) (ty >= y) & (ty < y + h) THEN xx[this] := tx + linenr;  yy[this] := ty;  INC( this );  END;  
				END;  
				IF (this < 2) & (x + w - 1 >= 0) & (x + w - 1 < LEN( YbyX ))
				(*InRange( x + w - 1, 0, LEN( YbyX ) ) *) THEN 
					tx := x + w - 1;  ty := YbyX[tx];  
					IF  (*InRange( ty, y, h )*) (ty >= y) & (ty < y + h) THEN xx[this] := tx + linenr;  yy[this] := ty;  INC( this );  END;  
				END;  
				
				sx := xx[0];  sy := yy[0];  ex := xx[1];  ey := yy[1];  
				
				IF this = 1 THEN ex := sx;  ey := sy;  INC( this )
				END;  
				
				ASSERT ( GetLineNr( sx, sy ) = GetLineNr( ex, ey ) );  
				IF this = 2 THEN RETURN TRUE 
				ELSIF this = 0 THEN RETURN FALSE 
				ELSE HALT( 100 )
				END;  
			
			ELSE 
				DEC( y, linenr );   (* consider shifted rectangle *)
				
				(* intersection with left boundary: *)
				this := 0;  tx := x;  ty := YbyX[x];  
				IF  (*InRange( ty, y, h )*) (ty >= y) & (ty < y + h) THEN xx[this] := tx;  yy[this] := ty + linenr;  INC( this );  END;  
				(* intersection with right  boundary: *)
				tx := x + w - 1;  ty := YbyX[tx];  
				IF  (*InRange( ty, y, h )*) (ty >= y) & (ty < y + h) THEN xx[this] := tx;  yy[this] := ty + linenr;  INC( this );  END;  
				IF (this < 2) &  (*InRange( y, 0, LEN( XbyY ) )*) (y >= 0) & (y < LEN( XbyY )) THEN 
					ty := y;  tx := XbyY[ty];  
					IF  (*InRange( tx, x, w )*) (tx >= x) & (tx < x + w) THEN xx[this] := tx;  yy[this] := ty + linenr;  INC( this );  END;  
				END;  
				IF (this < 2) &  (* InRange( y + h - 1, 0, LEN( XbyY ) ) *) (y + h - 1 >= 0) & (y + h - 1 < LEN( XbyY )) THEN 
					ty := y + h - 1;  tx := XbyY[ty];  
					IF  (*InRange( tx, x, w )*) (tx >= x) & (tx < x + w) THEN xx[this] := tx;  yy[this] := ty + linenr;  INC( this );  END;  
				END;  
				
				sx := xx[0];  sy := yy[0];  ex := xx[1];  ey := yy[1];   (* ASSERT(this=2);  *)  (* may happen since application x -> y is not unique*)
				IF this = 1 THEN ex := sx;  ey := sy;  INC( this ) END;  
				
				ASSERT ( GetLineNr( sx, sy ) = GetLineNr( ex, ey ), 100 );  
				
				IF this = 2 THEN RETURN TRUE 
				ELSIF this = 0 THEN RETURN FALSE 
				ELSE HALT( 100 )
				END;  
			
			END;  
		END IntersectWRect;  

		PROCEDURE GetX*( linenr: SIZE;  y: SIZE ): SIZE;  
		BEGIN 
			ASSERT ( vertical );  
			RETURN XbyY[y] + linenr;  
		END GetX;  

		PROCEDURE GetY*( linenr: SIZE;  x: SIZE ): SIZE;  
		BEGIN 
			ASSERT ( ~vertical );  
			RETURN YbyX[x] + linenr;  
		END GetY;  

		PROCEDURE Store( VAR R: Files.Rider );  
		CONST version = 20040720;  
		BEGIN 
			Files.WriteLInt( R, version );  Files.WriteLInt( R, SIGNED32(dx) );  Files.WriteLInt( R, SIGNED32(dy) );  Files.WriteLInt( R, SIGNED32(w) );  
			Files.WriteLInt( R, SIGNED32(h) );  
		END Store;  

		PROCEDURE Load( VAR R: Files.Rider );  
		VAR version: SIGNED32;  c: SIGNED32;
		BEGIN 
			Files.ReadLInt( R, version );  Files.ReadLInt( R, c); dx := c;  Files.ReadLInt( R, c); dy := c;  Files.ReadLInt( R, c); w := c;  
			Files.ReadLInt( R, c); h := c;  InitX( dx, dy, w, h );  
		END Load;  

		PROCEDURE dbgOut;  
		VAR x, y: SIZE;  
		BEGIN 
			Out.String( "Line YbyX: " );  
			FOR x := 0 TO ABS( dx ) DO Out.Int( SIGNED32(YbyX[x]), 1 );  Out.String( "," );  END;  
			Out.Ln;  Out.String( "Line XbyY: " );  
			FOR y := 0 TO ABS( dy ) DO Out.Int( SIGNED32(XbyY[y]), 1 );  Out.String( "," );  END;  
			Out.Ln;  
			IF vertical THEN 
				Out.String( "area [y] : " );  
				FOR y := 0 TO ABS( dy ) DO Out.Int( SIGNED32(a[y]), 1 );  Out.String( "," );  END;  
				Out.Ln;  
			ELSE 
				Out.String( "area [x] : " );  
				FOR x := 0 TO ABS( dx ) DO Out.Int( SIGNED32(a[x]), 1 );  Out.String( "," );  END;  
				Out.Ln;  
			END;  
		END dbgOut;  

	END LineObject;  



TYPE 
	
	ArraySumObject* = OBJECT 
	VAR A: antsArrayObjects.tLONGREALArray;  
		line-: LineObject;  
		dx*, dy*: SIZE;  
		
		PROCEDURE & Init*( ColSum: antsArrayObjects.tLONGREALArray;  line: LineObject (*line: pxlCumMat3.Line*) );  
		VAR x, y, bx, by, h, w, dx, startx, endx: SIZE;  val: FLOAT64;  inrange: BOOLEAN;  
		BEGIN 
			(*
		MakeLineMatrix( line, Avertical, SELF.A ); 
		*)
			ASSERT ( ColSum # NIL , 100 );  
			ASSERT ( LEN( ColSum ) > 0, 101 );  
			ASSERT ( LEN( ColSum[0] ) > 0, 102 );  
			h := SIZE(LEN( ColSum ));  w := SIZE(LEN( ColSum[0] ));  
			IF (SELF.A = NIL ) OR (LEN( SELF.A ) # h) OR (LEN( SELF.A[0] ) # w) THEN NEW( SELF.A, h, w );  END;  
			bx := 0;  by := 0;  
			
			IF (line.dx > 0) THEN dx := 1;  endx := w;  startx := 0;  
			ELSE dx := -1;  endx := -1;  startx := w - 1;  
			END;  
			
			y := 0;  
			WHILE (y < h) DO 
				x := startx;  
				WHILE (x # endx) DO 
					val := ColSum[y, x];  
					IF (line.PreviousForCumSum( x, y, bx, by, inrange ) & inrange) THEN 
						val := val + SELF.A[by, bx] ;  
					END;  
					SELF.A[y, x] := val;  INC( x, dx );  
				END;  
				INC( y, 1 );  
			END;  
			
			SELF.dx := line.dx;  SELF.dy := line.dy;  SELF.line := line;  
		END Init;  

		PROCEDURE GetSum*( xstart, ystart, xend, yend: SIZE;  VAR area: SIZE ): FLOAT64;  
		VAR sum: FLOAT64;  px, py, d: SIZE;  inrange: BOOLEAN;  
		BEGIN 
			ASSERT ( line.GetLineNr( xstart, ystart ) = line.GetLineNr( xend, yend ), 101 );  
			
			
			IF yend < ystart THEN swap( ystart, yend );  swap( xstart, xend )
			ELSIF (yend = ystart) & (xstart < xend) & (line.dx < 0) THEN   swap( xstart, xend );  
			ELSIF (yend = ystart) & (xstart > xend) & (line.dx > 0) THEN   swap( xstart, xend );  
			END;  
			
			sum := A[yend, xend];  
			
			IF line.vertical THEN area := line.a[yend]
			ELSE area := line.a[xend]
			END;  
			
			IF line.PreviousForCumSum( xstart, ystart, px, py, inrange ) THEN  (* get previous point not on y axis of start point *)
				IF inrange THEN sum := sum - A[py, px];  END;  
				IF line.vertical THEN DEC( area, line.a[py] );  ELSE DEC( area, line.a[px] );  END;  
			END;  
			IF ~line.vertical THEN 
				d := line.YbyX[xstart];  d := ystart - d;  INC( area, (ABS( xstart - xend ) + 1) *  d )
			END;  
			RETURN sum;  
		END GetSum;  
	
	(* currently unused
		PROCEDURE GetIntersect*( xstart, ystart, xrect, yrect: SIZE;  VAR px, py: SIZE );  
		VAR intersect: BOOLEAN;  
		BEGIN 
			ASSERT ( line # NIL , 100 );  
			intersect := TRUE;  intersect := line.GetLineIntersect( xstart, ystart, xrect, yrect, px, py );  
		END GetIntersect;  
*)
	
	END ArraySumObject;  
	
	Moments* = RECORD 
		X-, Y-, Z-, XX-, YY-, ZZ-, XY-, XZ-, YZ-, N-: antsArrayObjects.tLONGREALArray;  
	END ;  
	
	MomentsO* = RECORD 
		X-, Y-, Z-, XX-, YY-, ZZ-, XY-, XZ-, YZ-, N-: ArraySumObject;  
	END ;  
	
	QMoments* = RECORD (Moments)
	(*  inherited: X-, Y-, Z-, X2-, Y2-, Z2-, XY-, XZ-, YZ-, N-: antsArrayObjects.tLONGREALArray;  *)
		X4-, Y4-, X3-, Y3-, X3Y-, XY3-, X2Y2-, X2Y-, XY2-, X2Z-, Y2Z-, XYZ-: antsArrayObjects.tLONGREALArray;  
	END ;  
	
	QMomentsO* = RECORD (MomentsO)
	(*  inherited: X-, Y-, Z-, XX-, YY-, ZZ-, XY-, XZ-, YZ-, N-: ArraySumObject;  *)
		X4-, Y4-, X3-, Y3-, X3Y-, XY3-, X2Y2-, X2Y-, XY2-, X2Z-, Y2Z-, XYZ-: ArraySumObject;  
	END ;  
	
GMoments* = POINTER TO ARRAY OF antsArrayObjects.tLONGREALArray;  
	GMomentsO* = POINTER TO ARRAY OF ArraySumObject;  


VAR 
	sumPhi: ARRAY 100 OF FLOAT64;  
	upsumPhi: ARRAY 100 OF FLOAT64;  
	minsumPhi: ARRAY 100 OF FLOAT64;  
	minupsumPhi: ARRAY 100 OF FLOAT64;  
	rect: ARRAY 100 OF FLOAT64;  
	beta: ARRAY 10 OF ARRAY 1 OF FLOAT64;  
	beta1: ARRAY 10 OF ARRAY 1 OF FLOAT64;  
	beta2: ARRAY 10 OF ARRAY 1 OF FLOAT64;  

		
	PROCEDURE CheckLineIntegrity( line: LineObject );  
	VAR x, y, tx, ty: SIZE;  
	BEGIN 
		FOR x := 0 TO ABS( line.dx ) DO 
			ASSERT ( line.YbyX[x] <= ABS( line.dy ), 100 );  
			ASSERT ( line.YbyX[x] >= 0, 101 );  
			ty := line.YbyX[x];  tx := line.XbyY[ty];  
			(* condition ? *)
		END;  
		FOR y := 0 TO ABS( line.dy ) DO 
			ASSERT ( line.XbyY[y] <= ABS( line.dx ), 103 );  
			ASSERT ( line.XbyY[y] >= 0, 104 );  
			tx := line.XbyY[y];  ty := line.YbyX[tx];  
			(* condition ? *) END;  
	END CheckLineIntegrity;  

	PROCEDURE GenLineObject*;  
	VAR l: LineObject;  
	BEGIN 
		NEW( l, 1, 1, 1, 1 );  Objects.NewObj := l;  
	END GenLineObject;  
	
	PROCEDURE swap( VAR x, y: SIZE );  
	VAR tmp: SIZE;  
	BEGIN 
		tmp := x;  x := y;  y := tmp;  
	END swap;  

	(* make matrix containing sums of columns of values data and the sums of squares of values of data *)
	PROCEDURE MakeColSumM*( data: antsArrayObjects.tLONGREALArray;  
													VAR rectSumZ, rectSumZZ: antsArrayObjects.tLONGREALArray );   (*! move to generic array module *)
	VAR y, x, w, h: SIZE;  val: FLOAT64;  
	BEGIN 
		w := SIZE(LEN( data[0] ));  h := SIZE(LEN( data ));  
		IF (rectSumZ=NIL) OR (LEN(rectSumZ) # h) OR (LEN(rectSumZ[0])#w) THEN 
			NEW( rectSumZ, h, w );   
		END; 
		IF (rectSumZZ=NIL) OR (LEN(rectSumZZ) # h) OR (LEN(rectSumZZ[0])#w) THEN 
			NEW( rectSumZZ, h, w );    
		END; 

		FOR x := 0 TO w - 1 DO val := data[0, x];  rectSumZ[0, x] := val;  rectSumZZ[0, x] := val * val;  END;  
		
		FOR y := 1 TO h - 1 DO 
			FOR x := 0 TO w - 1 DO 
				val := data[y, x];  rectSumZ[y, x] := val + rectSumZ[y - 1, x];  rectSumZZ[y, x] := val * val + rectSumZZ[y - 1, x];  
			END;  
		END;  
	END MakeColSumM;  

(*Fills a rectangle [x,x+w-1]X[y,y+h-1] iwht the value val*)
	PROCEDURE FillRectC*( a: antsArrayObjects.tLONGREALArray;  x, y, w, h: SIZE;  val: FLOAT64 );   (*! move to generic array module *)
	VAR xx, yy: SIZE;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 
			FOR xx := x TO x + w - 1 DO a[yy, xx] := val;  END;  
		END;  
	END FillRectC;  

(*Fills a rectangle [x,x+w-1]X[y,y+h-1] with the affine function x1*x+x2*y+x3 *)
	PROCEDURE FillRectLin*( a: antsArrayObjects.tLONGREALArray;  x, y, w, h: SIZE;  x1, x2, x3: FLOAT64 );  
	VAR xx, yy: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 
			FOR xx := x TO x + w - 1 DO 
				val := x1 * xx + x2 * yy + x3;  
				IF val < 0.0 THEN a[yy, xx] := 0.0;  
				ELSIF val > 255.0 THEN a[yy, xx] := 255.0;  
				ELSE a[yy, xx] := val;  
				END;  
			END;  
		END;  
	END FillRectLin;  

(*Fills  rectangle with quadratic polynomials*)
	PROCEDURE FillRectLinQ*( a: antsArrayObjects.tLONGREALArray;  x, y, w, h: SIZE;  x1, x2, x3, x4, x5, x6: FLOAT64 );  
	VAR xx, yy: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 
			FOR xx := x TO x + w - 1 DO 
				val := x1 * xx * xx + x2 * xx * yy + x3 * yy * yy + x4 * xx + x5 * yy + x6;  
				IF val < 0.0 THEN a[yy, xx] := 0.0;  
				ELSIF val > 255.0 THEN a[yy, xx] := 255.0;  
				ELSE a[yy, xx] := val;  
				END;  
			END;  
		END;  
	END FillRectLinQ;  

(*Fills a rectangle with a generic models*)
	PROCEDURE FillRectLinG*( a: antsArrayObjects.tLONGREALArray;  x, y, w, h: SIZE;  beta: ARRAY OF FLOAT64;  f: ARRAY OF Function2d );  
	VAR xx, yy, ii: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 
			FOR xx := x TO x + w - 1 DO 
				val := 0.0;  
				FOR ii := 0 TO LEN( beta ) - 1 DO val := val + beta[ii] * f[ii]( yy, xx );  END;  
				IF val < 0.0 THEN a[yy, xx] := 0.0;  
				ELSIF val > 255.0 THEN a[yy, xx] := 255.0;  
				ELSE a[yy, xx] := val;  
				END;  
			END;  
		END;  
	END FillRectLinG;  


(*Fills a vertical line [x]X[y,y+h-1] with value val*)
	PROCEDURE FillVLineC*( a: antsArrayObjects.tLONGREALArray;  x, y, h: SIZE;  val: FLOAT64 );   (*! move to generic array module *)
	VAR yy: SIZE;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO a[yy, x] := val;  END;  
	END FillVLineC;  

(*Fills a vertical line [x]X[y,y+h-1] with the affine function x1*y+x2 *)
	PROCEDURE FillVLineL*( a: antsArrayObjects.tLONGREALArray;  x, y, h: SIZE;  x1, x2, x3: FLOAT64 );  
	VAR yy: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 

			val := x1 * x + x2 * yy + x3;  
			
			IF val < 0.0 THEN a[yy, x] := 0.0;  
			ELSIF val > 255.0 THEN a[yy, x] := 255.0;  
			ELSE a[yy, x] := val;  
			END;  
		
		END;  
	END FillVLineL;  

	(*Filling of a line with quadratic polynomial functions*)
PROCEDURE FillVLineQ*( a: antsArrayObjects.tLONGREALArray;  x, y, h: SIZE;  x1, x2, x3, x4, x5, x6: FLOAT64 );  
	VAR yy: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR yy := y TO y + h - 1 DO 

			val := x1 * x * x + x2 * x * yy + x3 * yy * yy + x4 * x + x5 * yy + x6;  
			
			IF val < 0.0 THEN a[yy, x] := 0.0;  
			ELSIF val > 255.0 THEN a[yy, x] := 255.0;  
			ELSE a[yy, x] := val;  
			END;  
		
		END;  
	END FillVLineQ;  

	(*Filling of a line with generic functions*)
	PROCEDURE FillVLineG*( a: antsArrayObjects.tLONGREALArray;  x, y, h: SIZE;  beta: ARRAY OF FLOAT64;  f: ARRAY OF Function2d );  
	VAR yy, ii: SIZE;  val: FLOAT64;  
	BEGIN 
		
		FOR yy := y TO y + h - 1 DO 
			val := 0.0;  
			FOR ii := 0 TO LEN( beta ) - 1 DO val := val + beta[ii] * f[ii]( yy, x );  END;  
			IF val < 0.0 THEN a[yy, x] := 0.0;  
			ELSIF val > 255.0 THEN a[yy, x] := 255.0;  
			ELSE a[yy, x] := val;  
			END;  
		END;  
	
	END FillVLineG;  

PROCEDURE ComputeColSums*( data: antsArrayObjects.tLONGREALArray;  VAR m: Moments );  
	VAR z: FLOAT64;  x, y, w, h: SIZE;  
	BEGIN 
		h := LEN( data );  w := LEN( data[0] );  
		IF (m.Z = NIL ) OR (LEN( m.Z ) # h) OR (LEN( m.Z[0] ) # w) THEN 
			NEW( m.X, h, w );  NEW( m.Y, h, w );  NEW( m.Z, h, w );  NEW( m.XX, h, w );  NEW( m.YY, h, w );  NEW( m.ZZ, h, w );  NEW( m.XY, h, w );  
			NEW( m.XZ, h, w );  NEW( m.YZ, h, w );  
			NEW( m.N, h, w );   (**)
		END;  
		FOR x := 0 TO w - 1 DO  (* first line *)
			z := data[y, x];  m.X[0, x] := x;  m.Y[0, x] := 0;  m.Z[0, x] := z;  m.XX[0, x] := x * x;  m.YY[0, x] := 0;  
			m.ZZ[0, x] := z * z;  m.XY[0, x] := 0;  m.XZ[0, x] := x * z;  m.YZ[0, x] := 0;  m.N[0, x] := 1;  
		END;  
		
		FOR y := 1 TO h - 1 DO  (* add up remaining lines 1 .. h-1*)
			FOR x := 0 TO w - 1 DO 
				z := data[y, x];  
				m.X[y, x] := m.X[y - 1, x] + x;  m.Y[y, x] := m.Y[y - 1, x] + y;  m.Z[y, x] := m.Z[y - 1, x] + z;   (**)
				m.XX[y, x] := m.XX[y - 1, x] + x * x;  m.YY[y, x] := m.YY[y - 1, x] + y * y;  m.ZZ[y, x] := m.ZZ[y - 1, x] + z * z;   (**)
				m.XY[y, x] := m.XY[y - 1, x] + x * y;  m.XZ[y, x] := m.XZ[y - 1, x] + x * z;  m.YZ[y, x] := m.YZ[y - 1, x] + y * z;   (**)
				m.N[y, x] := m.N[y - 1, x] + 1;  
			END;  
		END;  
	
	END ComputeColSums;  

	PROCEDURE ComputeColSumsQ*( data: antsArrayObjects.tLONGREALArray;  VAR m: QMoments );  
	VAR z: FLOAT64;  x, y, w, h: SIZE;  
	BEGIN 
		ComputeColSums( data, m );  h := SIZE(LEN( data ));  w := SIZE(LEN( data[0] ));  
		
		IF (m.X4 = NIL ) OR (LEN( m.X4 ) # h) OR (LEN( m.X4[0] ) # w) THEN 
			NEW( m.X4, h, w );  NEW( m.Y4, h, w );  NEW( m.X3, h, w );  NEW( m.Y3, h, w );  NEW( m.X3Y, h, w );  NEW( m.XY3, h, w );  NEW( m.X2Y2, h, w );  
			NEW( m.X2Y, h, w );  NEW( m.XY2, h, w );  NEW( m.X2Z, h, w );  NEW( m.Y2Z, h, w );  NEW( m.XYZ, h, w );  
			
			FOR x := 0 TO w - 1 DO  (* first line *)
				z := data[0, x];  m.X4[0, x] := 1.0D0 * x * x * x * x;  m.Y4[0, x] := 0;  m.X3[0, x] :=  1.0D0 *x * x * x;  m.Y3[0, x] := 0;  
				m.X3Y[0, x] := 0;  m.XY3[0, x] := 0;  m.X2Y2[0, x] := 0;  m.X2Y[0, x] := 0;  m.XY2[0, x] := 0;  m.Y2Z[0, x] := 0;  
				m.X2Z[0, x] := 1.D0 * x * x * z;  m.XYZ[0, x] := 0
			END;  
			
			FOR y := 1 TO h - 1 DO  (* add up remaining lines 1 .. h-1*)
				FOR x := 0 TO w - 1 DO 

					z := data[y, x];  m.X4[y, x] := m.X4[y - 1, x] + 1.0D0 * x * x * x * x;  m.Y4[y, x] := m.Y4[y - 1, x] + 1.0D0 * y * y * y * y;  
					m.X3[y, x] := m.X3[y - 1, x] + 1.0D0 * x * x * x;  m.Y3[y, x] := m.Y3[y - 1, x] + 1.0D0 * y * y * y;  
					m.X3Y[y, x] := m.X3Y[y - 1, x] + 1.0D0 * x * x * x * y;  m.XY3[y, x] := m.XY3[y - 1, x] + 1.0D0 * x * y * y * y;  
					m.X2Y2[y, x] := m.X2Y2[y - 1, x] + 1.0D0 *x * x * y * y;  m.X2Y[y, x] := m.X2Y[y - 1, x] + 1.0D0 *x * x * y;  
					m.XY2[y, x] := m.XY2[y - 1, x] + 1.0D0 * x * y * y;  m.X2Z[y, x] := m.X2Z[y - 1, x] + 1.0D0 *x * x * z;  
					m.Y2Z[y, x] := m.Y2Z[y - 1, x] + 1.0D0 * y * y * z;  m.XYZ[y, x] := m.XYZ[y - 1, x] + 1.0D0 * x * y * z;  
				END;  
			END;  
		
		END;  
	END ComputeColSumsQ;  
	PROCEDURE ComputeColSumsG*( data: antsArrayObjects.tLONGREALArray;  phi: ARRAY OF Function2d;  VAR m: GMoments );  
	VAR z: FLOAT64;  ii, iii, jj, x, y, w, h, psize, msize: SIZE;  
	BEGIN 
		(*psize : number of regressor functions*)
		psize := SIZE(LEN( phi ));  h := SIZE(LEN( data ));  w := SIZE(LEN( data[0] ));  Out.Ln;  Out.String( "size of phi" );  Out.Int( SIGNED32(psize), 6 );  Out.Ln;  
		
		(*msize: total number of moments required, containing the <phi_i,phi,j> moments, <phi-i,f> moments and <f,f>*)
		msize := (psize + 1) * (psize + 2) DIV 2;  Out.String( "size of m" );  Out.Int( SIGNED32(msize), 6 );  Out.Ln;  
		
		IF m = NIL THEN NEW( m, msize );  
		END;  
		
		FOR ii := 0 TO msize - 1 DO 
			IF (m[ii] = NIL ) OR (LEN( m[ii] ) # w) OR (LEN( m[ii][0] ) # h) THEN NEW( m[ii], h, w );  END;  
		END;  
		
		FOR x := 0 TO w - 1 DO  (* first line *)
		
			z := data[0, x];  
			(*Out.String("z pour x : "); Out.Int(x,6); Out.String(":"); Out.LongRealFix(z,6,6); Out.Ln;*)
			m[msize - 1][0, x] := m[msize - 1][0, x] + z * z;  
			
			FOR ii := 0 TO psize - 1 DO 
				iii := ii * (ii + 1) DIV 2;  
				FOR jj := 0 TO ii DO 

					m[iii + jj][0, x] := 0.;  m[iii + jj][0, x] := phi[ii]( 0.0, 1.0D0 * x ) * phi[jj]( 0.0, 1.0D0 * x );  
				
				END;  
			END;  
			iii := psize * (psize + 1) DIV 2;  
			FOR ii := 0 TO psize - 1 DO m[iii + ii][0, x] := phi[ii]( 0.0, 1.0D0 * x ) * z;  END;  
		END;  
		
		FOR y := 1 TO h - 1 DO  (* add up remaining lines 1 .. h-1*)
			FOR x := 0 TO w - 1 DO z := data[y, x];  

				m[msize - 1][y, x] := m[msize - 1][y - 1, x] + z * z;  
				
				FOR ii := 0 TO psize - 1 DO 
					iii := ii * (ii + 1) DIV 2;  
					FOR jj := 0 TO ii DO 
					
					(* <phi_i,phi-j> moments*)
						m[iii + jj][y, x] := m[iii + jj][y - 1, x] + phi[ii]( 1.0D0 * y, 1.0D0 * x ) * phi[jj]( 1.0D0 * y, 1.0D0 * x );  
					
					END;  
				END;  
				iii := psize * (psize + 1) DIV 2;  
				FOR ii := 0 TO psize - 1 DO m[iii + ii][y, x] := m[iii + ii][y - 1, x] + phi[ii]( 1.0D0 * y, 1.0D0 * x ) * z;  END;  
			END;  
		END;  
		
		Out.String( "Fin de ComputeCoSumsG" );  Out.Ln;  
	
	END ComputeColSumsG;  

	PROCEDURE MakeMomentO*( col: Moments;  line: LineObject;  VAR m: MomentsO );  
	BEGIN 
		IF m.Z = NIL THEN 
			NEW( m.X, col.X, line );  NEW( m.Y, col.Y, line );  NEW( m.Z, col.Z, line );   (**)
			NEW( m.XX, col.XX, line );  NEW( m.YY, col.YY, line );  NEW( m.ZZ, col.ZZ, line );   (**)
			NEW( m.XY, col.XY, line );  NEW( m.XZ, col.XZ, line );  NEW( m.YZ, col.YZ, line );  NEW( m.N, col.N, line );  
		ELSE 
			m.X.Init( col.X, line );  m.Y.Init( col.Y, line );  m.Z.Init( col.Z, line );   (**)
			m.XX.Init( col.XX, line );  m.YY.Init( col.YY, line );  m.ZZ.Init( col.ZZ, line );   (**)
			m.XY.Init( col.XY, line );  m.XZ.Init( col.XZ, line );  m.YZ.Init( col.YZ, line );  m.N.Init( col.N, line );  
		END;  
	END MakeMomentO;  

	PROCEDURE MakeMomentOQ*( col: QMoments;  line: LineObject;  VAR m: QMomentsO );  
	BEGIN 
		MakeMomentO( col, line, m );  
		IF m.X4 = NIL THEN 

			NEW( m.X4, col.X4, line );  NEW( m.Y4, col.Y4, line );  NEW( m.X3, col.X3, line );  NEW( m.Y3, col.Y3, line );  NEW( m.X3Y, col.X3Y, line );  
			NEW( m.XY3, col.XY3, line );  NEW( m.X2Y2, col.X2Y2, line );  NEW( m.X2Y, col.X2Y, line );  NEW( m.XY2, col.XY2, line );  
			NEW( m.X2Z, col.X2Z, line );  NEW( m.Y2Z, col.Y2Z, line );  NEW( m.XYZ, col.XYZ, line );  
		ELSE 

			m.X4.Init( col.X4, line );  m.Y4.Init( col.Y4, line );  m.X3.Init( col.X3, line );  m.Y3.Init( col.Y3, line );  
			m.X3Y.Init( col.X3Y, line );  m.XY3.Init( col.XY3, line );  m.X2Y2.Init( col.X2Y2, line );  m.XY2.Init( col.XY2, line );  
			m.X2Y.Init( col.X2Y, line );  m.X2Z.Init( col.X2Z, line );  m.Y2Z.Init( col.Y2Z, line );  m.XYZ.Init( col.XYZ, line );  
		
		END;  
	END MakeMomentOQ;  
	
	PROCEDURE MakeMomentOG*( col: GMoments;  line: LineObject;  phi: ARRAY OF Function2d;  VAR m: GMomentsO );  
	VAR ii, psize, msize: SIZE;  
	BEGIN 
		(*functional space size*)
		psize := LEN( phi );  
		(*total number of moments needed : n(n+3)/2*)
		msize := (psize + 1) * (psize + 2) DIV 2;  
		
		IF m = NIL THEN NEW( m, msize );  
		END;  
		
		FOR ii := 0 TO msize - 1 DO 
			
			IF (m[ii] = NIL ) THEN NEW( m[ii], col[ii], line );  
			ELSE m[ii].Init( col[ii], line );  
			END;  
		END;  
	
	END MakeMomentOG;  


	PROCEDURE Min( a, b: SIZE ): SIZE;  
	BEGIN 
		IF a < b THEN RETURN a ELSE RETURN b END;  
	END Min;  

	PROCEDURE Copy*( A, ACopy: antsArrayObjects.tLONGREALArray );  
	VAR w, h, xsrc, ysrc: SIZE;  
	BEGIN 
		w := SIZE(LEN( A[0] ));  h := SIZE(LEN( A ));  
		FOR xsrc := 0 TO w - 1 DO 
			FOR ysrc := 0 TO h - 1 DO ACopy[ysrc, xsrc] := A[ysrc, xsrc];  END;  
		END;  
	END Copy;  

(* ssq and mean of a rectangle *)
	PROCEDURE RectStatC*( rectSumZ, rectSumZZ: ArraySumObject;  x, y, w, h: SIZE;  VAR ssq, mean: FLOAT64 );  
	VAR rectsum, rectSq, L: FLOAT64;  f, f1, f2: SIZE;  
	BEGIN 
		f := w * h;   (*Flaeche*)
		DEC( y );  

		rectsum := rectSumZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectSq := rectSumZZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		
		IF y >= 0 THEN 
			rectsum := rectsum - rectSumZ.GetSum( x, y, x + w - 1, y, f2 );  
			rectSq := rectSq - rectSumZZ.GetSum( x, y, x + w - 1, y, f2 );  
		ELSE f2 := 0;  
		END;  
		(* ASSERT(f1-f2=f,1001) *)
		mean := rectsum / f;  L := rectsum * rectsum;  ssq := rectSq - L / f;  
	END RectStatC;  

(*ssq und min in einem ganzen Rechteck : lineare interpolation*)
	PROCEDURE RectStatL*( M: MomentsO;  x, y, w, h: SIZE;  VAR ssq, c, a, b: FLOAT64 );  
	VAR Error, rectsum, rectSq, rectX, rectY, rectZ, rectXX, rectYY, rectZZ, rectXY, rectYZ, rectXZ, rectN, L: FLOAT64;  f, f1, f2: SIZE;  
		g: wedgeLinearEq.LinearEq;  
	BEGIN 
		g := wedgeLinearEq.global;  
		f := w * h;   (*Flaeche*)
		DEC( y );  

		rectX := M.X.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectY := M.Y.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectZ := M.Z.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXX := M.XX.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectYY := M.YY.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectZZ := M.ZZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectXY := M.XY.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXZ := M.XZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectYZ := M.YZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectN := M.N.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		
		IF y >= 0 THEN 
			rectX := rectX - M.X.GetSum( x, y, x + w - 1, y, f2 );  rectY := rectY - M.Y.GetSum( x, y, x + w - 1, y, f2 );  
			rectZ := rectZ - M.Z.GetSum( x, y, x + w - 1, y, f2 );  rectXX := rectXX - M.XX.GetSum( x, y, x + w - 1, y, f2 );  
			rectYY := rectYY - M.YY.GetSum( x, y, x + w - 1, y, f2 );  rectZZ := rectZZ - M.ZZ.GetSum( x, y, x + w - 1, y, f2 );  
			rectXY := rectXY - M.XY.GetSum( x, y, x + w - 1, y, f2 );  rectXZ := rectXZ - M.XZ.GetSum( x, y, x + w - 1, y, f2 );  
			rectYZ := rectYZ - M.YZ.GetSum( x, y, x + w - 1, y, f2 );  rectN := rectN - M.N.GetSum( x, y, x + w - 1, y, f2 );  
		ELSE f2 := 0;  
		END;  
		
		ASSERT ( (f1 - f2) = w * h );  
			
		IF (h # 1) & (w # 1) THEN 
			ssq := g.LinearRegression( g.result3, rectX, rectY, rectZ, rectXY, rectXZ, rectYZ, rectXX, rectYY, rectZZ, rectN );  
			a := g.result3[0, 0];  b := g.result3[1, 0];  c := g.result3[2, 0];  
		END;  
		IF (w = 1) & (h # 1) THEN 
			ssq := g.LinearRegression1D( g.result2, rectY, rectZ, rectYZ, rectYY, rectZZ, rectN );  a := 0.0;  b := g.result2[0, 0];  
			c := g.result2[1, 0];  
		END;  
		
		IF (h = 1) & (w # 1) THEN 
			ssq := g.LinearRegression1D( g.result2, rectX, rectZ, rectXZ, rectXX, rectZZ, rectN );  b := 0.0;  a := g.result2[0, 0];  
			c := g.result2[1, 0];  
		END;  
		
		IF (h = 1) & (w = 1) THEN c := rectZ;  
		END;  
	END RectStatL;  

	PROCEDURE RectStatQ*( M: QMomentsO;  x, y, w, h: SIZE;  VAR ssq, c, a, b, d, e, ee: FLOAT64 );  
	VAR rectsum, rectSq, rectX, rectY, rectZ, rectXX, rectYY, rectZZ, rectXY, rectYZ, rectXZ, rectN, L: FLOAT64;  
		rectX4, rectY4, rectX3, rectY3, rectX3Y, rectXY3, rectX2Y2, rectX2Y, rectXY2, rectX2Z, rectY2Z, rectXYZ: FLOAT64;  f, f1, f2: SIZE;  
		g: wedgeQuadraticEq.QuadraticEq;  
	BEGIN 
		g := wedgeQuadraticEq.global;  
		f := w * h;   (*Flaeche*)
		DEC( y );  

		rectX := M.X.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectY := M.Y.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectZ := M.Z.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXX := M.XX.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectYY := M.YY.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectZZ := M.ZZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectXY := M.XY.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXZ := M.XZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectYZ := M.YZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectN := M.N.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectX4 := M.X4.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectY4 := M.Y4.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectX3 := M.X3.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectY3 := M.Y3.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectX3Y := M.X3Y.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXY3 := M.XY3.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectX2Y2 := M.X2Y2.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectX2Y := M.X2Y.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectXY2 := M.XY2.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectX2Z := M.X2Z.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		rectY2Z := M.Y2Z.GetSum( x, y + h, x + w - 1, y + h, f1 );  rectXYZ := M.XYZ.GetSum( x, y + h, x + w - 1, y + h, f1 );  
		IF y >= 0 THEN 
			rectX := rectX - M.X.GetSum( x, y, x + w - 1, y, f2 );  rectY := rectY - M.Y.GetSum( x, y, x + w - 1, y, f2 );  
			rectZ := rectZ - M.Z.GetSum( x, y, x + w - 1, y, f2 );  rectXX := rectXX - M.XX.GetSum( x, y, x + w - 1, y, f2 );  
			rectYY := rectYY - M.YY.GetSum( x, y, x + w - 1, y, f2 );  rectZZ := rectZZ - M.ZZ.GetSum( x, y, x + w - 1, y, f2 );  
			rectXY := rectXY - M.XY.GetSum( x, y, x + w - 1, y, f2 );  rectXZ := rectXZ - M.XZ.GetSum( x, y, x + w - 1, y, f2 );  
			rectYZ := rectYZ - M.YZ.GetSum( x, y, x + w - 1, y, f2 );  rectN := rectN - M.N.GetSum( x, y, x + w - 1, y, f2 );  
			rectX4 := rectX4 - M.X4.GetSum( x, y, x + w - 1, y, f2 );  rectY4 := rectY4 - M.Y4.GetSum( x, y, x + w - 1, y, f2 );  
			rectX3 := rectX3 - M.X3.GetSum( x, y, x + w - 1, y, f2 );  rectY3 := rectY3 - M.Y3.GetSum( x, y, x + w - 1, y, f2 );  
			rectX3Y := rectX3Y - M.X3Y.GetSum( x, y, x + w - 1, y, f2 );  
			rectXY3 := rectXY3 - M.XY3.GetSum( x, y, x + w - 1, y, f2 );  
			rectX2Y2 := rectX2Y2 - M.X2Y2.GetSum( x, y, x + w - 1, y, f2 );  
			rectX2Y := rectX2Y - M.X2Y.GetSum( x, y, x + w - 1, y, f2 );  
			rectXY2 := rectXY2 - M.XY2.GetSum( x, y, x + w - 1, y, f2 );  
			rectX2Z := rectX2Z - M.X2Z.GetSum( x, y, x + w - 1, y, f2 );  
			rectY2Z := rectY2Z - M.Y2Z.GetSum( x, y, x + w - 1, y, f2 );  
			rectXYZ := rectXYZ - M.XYZ.GetSum( x, y, x + w - 1, y, f2 );  
		
		ELSE f2 := 0;  
		END;  
		
		ssq := 
			g.QuadraticRegression( g.result3, rectX, rectY, rectZ, rectXY, rectXZ, rectYZ, rectXX, rectYY, rectZZ, rectX4, rectY4, 
												   rectX3, rectY3, rectX3Y, rectXY3, rectX2Y2, rectX2Y, rectXY2, rectX2Z, rectY2Z, rectXYZ, 
												   rectN );  
		ee := g.result3[0, 0];  e := g.result3[1, 0];  d := g.result3[2, 0];  b := g.result3[3, 0];  c := g.result3[4, 0];  
		a := g.result3[5, 0];  
		
		END RectStatQ;  
	
	PROCEDURE RectStatG*( M: GMomentsO;  x, y, w, h: SIZE;  VAR ssq: FLOAT64;  VAR minbeta: ARRAY OF ARRAY OF FLOAT64;  psize: SIZE );  
	VAR ii: SIZE; f1, f2: SIZE;  g: wedgeGenericEq.GenericEq;  
	BEGIN 
		g := wedgeGenericEq.global;  DEC( y );  
		
		FOR ii := 0 TO LEN( M ) - 1 DO rect[ii] := M[ii].GetSum( x, y + h, x + w - 1, y + h, f1 );  END;  
		
		IF y >= 0 THEN 
			FOR ii := 0 TO LEN( M ) - 1 DO rect[ii] := rect[ii] - M[ii].GetSum( x, y, x + w - 1, y, f1 );  END;  
		END;  
		
		ssq := g.GenericRegression( beta, rect, psize );  
		
		FOR ii := 0 TO psize - 1 DO minbeta[ii, 0] := beta[ii, 0];  END;  
	
	END RectStatG;  



(* get best wedge constant  partition of data defined by the sums of values and squared values  in rectangles and trapezes rectSumZ, rectSumZZ, trapezeSumSZ and trapezeSumZZ *)
	PROCEDURE GetBestWedgeC*( rectSumZ, rectSumZZ, trapezeSumZ, trapezeSumZZ: ArraySumObject;  x, y, w, h: SIZE;  
													 VAR linenr, linelen: SIZE;  VAR mean, upmean, ssq: FLOAT64 );  
	VAR sx, ex, sy, ey, sline, eline: SIZE;  line: LineObject;  sum, upsum, sumsq, upsumsq: FLOAT64;  f1, f2, f3, f4, f5, f6: SIZE;  minsq: FLOAT64;  lnr: SIZE;  
	BEGIN 
		IF (trapezeSumZ.dx >=0)  THEN sx := x;  sy := y + h - 1;  ex := x + w - 1;  ey := y;   
		ELSE sx := x;  ex := x + w - 1;  sy := y;  ey := y + h - 1;  
		END;  
		
		f1 := 0;  f2 := 0;  f3 := 0;  f4 := 0;  f5 := 0;  f6 := 0;  line := trapezeSumZ.line;  
		
		sline := line.GetLineNr( sx, sy );  
		eline := line.GetLineNr( ex, ey );  
		
		IF eline < sline THEN swap( sline, eline )
		END;  
		
		minsq := MAX( FLOAT64 );  
		
		FOR lnr := sline TO eline DO 
			IF ~line.IntersectWRect( lnr, x, y, w, h, sx, sy, ex, ey ) THEN HALT( 100 ) END;  
			
			IF (sx > ex) OR ((sx = ex) & (sy > ey)) THEN swap( sx, ex );  swap( sy, ey )
			END;  
			
			sum := trapezeSumZ.GetSum( sx, sy, ex, ey, f1 );  
			IF y > 0 THEN sum := sum - rectSumZ.GetSum( sx, y - 1, ex, y - 1, f2 );  END;  
			
			IF (ex < x + w - 1) & (ey > y) THEN 
				sum := sum + rectSumZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				IF y > 0 THEN sum := sum - rectSumZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			
			IF (sx > x) & (sy > y) THEN 
				sum := sum + rectSumZ.GetSum( x, sy, sx - 1, sy, f3 );  
				IF y > 0 THEN sum := sum - rectSumZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			
			upsum := rectSumZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sum;  
			IF y > 0 THEN upsum := upsum - rectSumZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			sumsq := trapezeSumZZ.GetSum( sx, sy, ex, ey, f1 );  
			IF y > 0 THEN sumsq := sumsq - rectSumZZ.GetSum( sx, y - 1, ex, y - 1, f2 );  END;  
			
			IF (ex < x + w - 1) & (ey > y) THEN 
				sumsq := sumsq + rectSumZZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				IF y > 0 THEN sumsq := sumsq - rectSumZZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  END;  
			END;  
			IF (sx > x) & (sy > y) THEN 
				sumsq := sumsq + rectSumZZ.GetSum( x, sy, sx - 1, sy, f3 );  
				IF y > 0 THEN sumsq := sumsq - rectSumZZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  END;  
			END;  
			
			upsumsq := rectSumZZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumsq;  
			IF y > 0 THEN upsumsq := upsumsq - rectSumZZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			ssq := sumsq - (sum * sum) / (f1 - f2 + f3 - f4);  
			
			ASSERT ( (f1 - f2 + f3 - f4) > 0, 103 );  
			IF (upsumsq > 0) & ( (f5 - f6 - (f1 - f2 + f3 - f4)) > 0)  THEN ssq := ssq + upsumsq - (upsum * upsum) / (f5 - f6 - (f1 - f2 + f3 - f4));  
				(* ASSERT ( (f5 - f6 - (f1 - f2 + f3 - f4)) > 0, 104 );   (*no partition*)*) 
			END;  
			
			IF ssq < minsq THEN 
				minsq := ssq;  mean := sum / (f1 - f2 + f3 - f4);  upmean := upsum / (f5 - f6 - (f1 - f2 + f3 - f4));  linenr := lnr;  
				linelen := ENTIER( Math.sqrt( (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy) ) + 0.5 );  
			END;  
			
			(*ASSERT ( (f1 - f2 + f3 - f4 # w * h) & (sy = ey), 105 );*)
			(* ASSERT ( f5 - f6 = w * h );  *)
		END;  
		ssq := minsq;  
	END GetBestWedgeC;  

	PROCEDURE GetBestWedgeL*( rectM: MomentsO;  trapezeM: MomentsO;  x, y, w, h: SIZE;  VAR linenr, linelen: SIZE;  
													 VAR c1, a1, b1, c2, a2, b2, ssq: FLOAT64 );  
	VAR sx, ex, sy, ey, sline, eline, case, mincase: SIZE;  line: LineObject;  
		sum, upsum, sumsq, upsumsq, sumX, upsumX, sumY, upsumY, sumXY, upsumXY, sumXZ, upsumXZ, sumYZ, upsumYZ, sumXX, upsumXX, sumYY, upsumYY, sumN, upsumN: FLOAT64;  
		f1, f2, f3, f4, f5, f6: SIZE;  
		mean, a, b, upc, upa, upb, minsq, minsq1, minsq2, ssq1, ssq2, tmp, minN, minupN, minX, minY, minZ, minXX, minYY, minZZ: FLOAT64;  
		lnr: SIZE;   (*abc: wedgeMatrix.matrx;  *)
		g: wedgeLinearEq.LinearEq;   (* equation solver *)
	BEGIN 
		g := wedgeLinearEq.global;  
		IF (trapezeM.Z.dx < 0) = (trapezeM.Z.dy < 0) (* (Sgn( trapezeM.Z.dx ) = Sgn( trapezeM.Z.dy )) *) THEN 
			sx := x;  sy := y + h - 1;  ex := x + w - 1;  ey := y;  
		ELSE sx := x;  ex := x + w - 1;  sy := y;  ey := y + h - 1;  
		END;  
		
		f1 := 0;  f2 := 0;  f3 := 0;  f4 := 0;  f5 := 0;  f6 := 0;  line := trapezeM.Z.line;  sline := line.GetLineNr( sx, sy );  
		eline := line.GetLineNr( ex, ey );  
		
		IF eline < sline THEN swap( sline, eline )
		END;  
		
		minsq := MAX( FLOAT64 );  
		
		FOR lnr := sline TO eline DO 
			IF ~line.IntersectWRect( lnr, x, y, w, h, sx, sy, ex, ey ) THEN HALT( 100 ) END;  
			
			IF (sx > ex) OR ((sx = ex) & (sy > ey)) THEN swap( sx, ex );  swap( sy, ey )
			END;  
			
			sum := trapezeM.Z.GetSum( sx, sy, ex, ey, f1 );  sumsq := trapezeM.ZZ.GetSum( sx, sy, ex, ey, f1 );  
			sumX := trapezeM.X.GetSum( sx, sy, ex, ey, f1 );  sumY := trapezeM.Y.GetSum( sx, sy, ex, ey, f1 );  
			sumXY := trapezeM.XY.GetSum( sx, sy, ex, ey, f1 );  sumXZ := trapezeM.XZ.GetSum( sx, sy, ex, ey, f1 );  
			sumYZ := trapezeM.YZ.GetSum( sx, sy, ex, ey, f1 );  sumXX := trapezeM.XX.GetSum( sx, sy, ex, ey, f1 );  
			sumYY := trapezeM.YY.GetSum( sx, sy, ex, ey, f1 );  sumN := trapezeM.N.GetSum( sx, sy, ex, ey, f1 );  
			
				
			IF y > 0 THEN 
				sum := sum - rectM.Z.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumsq := sumsq - rectM.ZZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX := sumX - rectM.X.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumY := sumY - rectM.Y.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXY := sumXY - rectM.XY.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXZ := sumXZ - rectM.XZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumYZ := sumYZ - rectM.YZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXX := sumXX - rectM.XX.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumYY := sumYY - rectM.YY.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumN := sumN - rectM.N.GetSum( sx, y - 1, ex, y - 1, f2 );  
			END;  
			
			IF (ex < x + w - 1) & (ey > y) THEN 
				sum := sum + rectM.Z.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumsq := sumsq + rectM.ZZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX := sumX + rectM.X.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumY := sumY + rectM.Y.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXY := sumXY + rectM.XY.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXZ := sumXZ + rectM.XZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumYZ := sumYZ + rectM.YZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXX := sumXX + rectM.XX.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumYY := sumYY + rectM.YY.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumN := sumN + rectM.N.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				
				IF y > 0 THEN 
					sum := sum - rectM.Z.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumsq := sumsq - rectM.ZZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX := sumX - rectM.X.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumY := sumY - rectM.Y.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXY := sumXY - rectM.XY.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXZ := sumXZ - rectM.XZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumYZ := sumYZ - rectM.YZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXX := sumXX - rectM.XX.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumYY := sumYY - rectM.YY.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumN := sumN - rectM.N.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
				END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			
			IF (sx > x) & (sy > y) THEN 
				sum := sum + rectM.Z.GetSum( x, sy, sx - 1, sy, f3 );  sumsq := sumsq + rectM.ZZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX := sumX + rectM.X.GetSum( x, sy, sx - 1, sy, f3 );  sumY := sumY + rectM.Y.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXY := sumXY + rectM.XY.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXZ := sumXZ + rectM.XZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumYZ := sumYZ + rectM.YZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXX := sumXX + rectM.XX.GetSum( x, sy, sx - 1, sy, f3 );  
				sumYY := sumYY + rectM.YY.GetSum( x, sy, sx - 1, sy, f3 );  sumN := sumN + rectM.N.GetSum( x, sy, sx - 1, sy, f3 );  
				
				IF y > 0 THEN 
					sum := sum - rectM.Z.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumsq := sumsq - rectM.ZZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX := sumX - rectM.X.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumY := sumY - rectM.Y.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXY := sumXY - rectM.XY.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXZ := sumXZ - rectM.XZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumYZ := sumYZ - rectM.YZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXX := sumXX - rectM.XX.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumYY := sumYY - rectM.YY.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumN := sumN - rectM.N.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
				END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			
			upsum := rectM.Z.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sum;  
			IF y > 0 THEN upsum := upsum - rectM.Z.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumsq := rectM.ZZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumsq;  
			IF y > 0 THEN upsumsq := upsumsq - rectM.ZZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX := rectM.X.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX;  
			IF y > 0 THEN upsumX := upsumX - rectM.X.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumY := rectM.Y.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumY;  
			IF y > 0 THEN upsumY := upsumY - rectM.Y.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXY := rectM.XY.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXY;  
			IF y > 0 THEN upsumXY := upsumXY - rectM.XY.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXZ := rectM.XZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXZ;  
			IF y > 0 THEN upsumXZ := upsumXZ - rectM.XZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumYZ := rectM.YZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumYZ;  
			IF y > 0 THEN upsumYZ := upsumYZ - rectM.YZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXX := rectM.XX.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXX;  
			IF y > 0 THEN upsumXX := upsumXX - rectM.XX.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumYY := rectM.YY.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumYY;  
			IF y > 0 THEN upsumYY := upsumYY - rectM.YY.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumN := rectM.N.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumN;  
			IF y > 0 THEN upsumN := upsumN - rectM.N.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			aM.dSR( "sumN = ", sumN );  aM.dSR( "upsumN = ", upsumN );  
				
			IF sumN # 0 THEN 
				ssq1 := 0.0;  
				IF  (sumN = 1) THEN 
					a := 0.0;  b := 0.0;  mean := sum;  ssq1 := 0.0;  case := 0;  
				ELSIF sumN = 2 (*not enough pixels to have a bidimensional model*)
				THEN 
					IF trapezeM.Z.dx = 0 THEN 
						ssq1 := g.LinearRegression1D( g.result2, sumY, sum, sumYZ, sumYY, sumsq, sumN );  a := 0.0;  
						b := g.result2[0, 0];  mean := g.result2[1, 0];  case := 1;  
					ELSE 
						ssq1 := g.LinearRegression1D( g.result2, sumX, sum, sumXZ, sumXX, sumsq, sumN );  b := 0.0;  
						a := g.result2[0, 0];  mean := g.result2[1, 0];  case := 2;  
					END;  
				
				ELSIF (sx = 0) & (ex = 0) THEN 
					ssq1 := g.LinearRegression1D( g.result2, sumY, sum, sumYZ, sumYY, sumsq, sumN );  a := 0.0;  
					b := g.result2[0, 0];  case := 3;  mean := g.result2[1, 0];  
				ELSIF (sy = 0) & (ey = 0) THEN 
					ssq1 := g.LinearRegression1D( g.result2, sumX, sum, sumXZ, sumXX, sumsq, sumN );  b := 0.0;  
					a := g.result2[0, 0];  mean := g.result2[1, 0];  case := 4;  
				ELSE 
					ssq1 := g.LinearRegression( g.result3, sumX, sumY, sum, sumXY, sumXZ, sumYZ, sumXX, sumYY, sumsq, sumN );  

					a := g.result3[0, 0];  b := g.result3[1, 0];  mean := g.result3[2, 0];  case := 5;  
				END;  
			END;  
			
			IF upsumN # 0 THEN 
				ssq2 := 0.0;  
				IF (upsumN = 1) (* (sx = w - 1) & (ex = w - 1) & (sy = h - 1) & (ey = h - 1) *) THEN 
					upa := 0.0;  upb := 0.0;  upc := upsum;  ssq2 := 0.0;  
				ELSIF upsumN = 2 (*not enough pixels to have a bidimensionnal model*)
				THEN 
					IF trapezeM.Z.dx = 0 THEN 
						ssq2 := g.LinearRegression1D( g.result2, upsumY, upsum, upsumYZ, upsumYY, upsumsq, upsumN );  
						upa := 0.0;  upb := g.result2[0, 0];  upc := g.result2[1, 0];  case := case + 1;  
					ELSE 
						ssq2 := g.LinearRegression1D( g.result2, upsumX, upsum, upsumXZ, upsumXX, upsumsq, upsumN );  
						upb := 0.0;  upa := g.result2[0, 0];  upc := g.result2[1, 0];  case := case + 2;  
					
					END;  
				ELSIF (sx = w - 1) & (ex = w - 1) THEN 
					ssq2 := g.LinearRegression1D( g.result2, upsumY, upsum, upsumYZ, upsumYY, upsumsq, upsumN );  upa := 0.0;  
					upb := g.result2[0, 0];  upc := g.result2[1, 0];  case := case + 3;  
					
				ELSIF (sy = h - 1) & (ey = h - 1) THEN 
					ssq2 := g.LinearRegression1D( g.result2, upsumX, upsum, upsumXZ, upsumXX, upsumsq, upsumN );  upb := 0.0;  
					upa := g.result2[0, 0];  upc := g.result2[1, 0];  case := case + 4;  
					
				ELSE 
					ssq2 := 
						g.LinearRegression( g.result3, upsumX, upsumY, upsum, upsumXY, upsumXZ, upsumYZ, upsumXX, upsumYY, 
														 upsumsq, upsumN );  
					upa := g.result3[0, 0];  upb := g.result3[1, 0];  upc := g.result3[2, 0];  case := case + 5;  
				END;  
			
			END;  
			
			ssq := ssq1 + ssq2;  aM.dSR( "ssq1+ssq2......", ssq );  aM.dSR( "minsq before copy to ssq final", minsq );  
			IF ssq < minsq THEN 
				mincase := case;  minsq1 := ssq1;  minsq2 := ssq2;  minsq := ssq;  c1 := mean;  c2 := upc;  a1 := a;  b1 := b;  
				a2 := upa;  b2 := upb;  linenr := lnr;  linelen := ENTIER( Math.sqrt( (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy) ) + 0.5 );  
				minN := sumN;  minupN := upsumN;  minX := sumX;  minY := sumY;  minZ := sum;  minXX := sumXX;  
				minYY := sumYY;  minZZ := sumsq;  
			
			END;  
		
		END;  
		
		ssq := minsq;  
		
	END GetBestWedgeL;  

	PROCEDURE GetBestWedgeQ*( rectM: QMomentsO;  trapezeM: QMomentsO;  x, y, w, h: SIZE;  VAR linenr, linelen: SIZE;  
													  VAR a1, b1, c1, d1, e1, ee1, a2, b2, c2, d2, e2, ee2, ssq: FLOAT64 );  
	VAR sx, ex, sy, ey, sline, eline: SIZE;  line: LineObject;  
		sum, upsum, sumsq, upsumsq, sumX, upsumX, sumY, upsumY, sumXY, upsumXY, sumXZ, upsumXZ, sumYZ, upsumYZ, sumXX, upsumXX, sumYY, upsumYY, sumN, upsumN: FLOAT64;  
		sumX4, sumY4, sumX3, sumY3, sumX3Y, sumXY3, sumX2Y2, sumX2Y, sumXY2, sumX2Z, sumY2Z, sumXYZ: FLOAT64;  
		upsumX4, upsumY4, upsumX3, upsumY3, upsumX3Y, upsumXY3, upsumX2Y2, upsumX2Y, upsumXY2, upsumX2Z, upsumY2Z, upsumXYZ: FLOAT64;  
		f1, f2, f3, f4, f5, f6, xx, yy, ddx, ddy, rx, ry: SIZE;  
		c, a, b, d, e, ee, upc, upa, upb, upd, upe, upee, minsq, minsq1, minsq2, ssq1, ssq2, tmp, minN, minupN, minX, minY, minZ, minXX, minYY, minXY, minZZ: FLOAT64;  
		minX4, minY4, minX3, minY3, minX3Y, minXY3, minX2Y2, minX2Y, minXY2: FLOAT64;  
		lnr: SIZE;   (*abc: wedgeMatrix.matrx;  *)
		g: wedgeQuadraticEq.QuadraticEq;   (* equation solver *)
		
	BEGIN 
		g := wedgeQuadraticEq.global;  
		IF (trapezeM.Z.dx < 0) = (trapezeM.Z.dy < 0) (* (Sgn( trapezeM.Z.dx ) = Sgn( trapezeM.Z.dy )) *) THEN 
			sx := x;  sy := y + h - 1;  ex := x + w - 1;  ey := y;  
		ELSE sx := x;  ex := x + w - 1;  sy := y;  ey := y + h - 1;  
		END;  
		
		f1 := 0;  f2 := 0;  f3 := 0;  f4 := 0;  f5 := 0;  f6 := 0;  line := trapezeM.Z.line;  sline := line.GetLineNr( sx, sy );  
		eline := line.GetLineNr( ex, ey );  
		
		IF eline < sline THEN swap( sline, eline )
		END;  
		
		minsq := MAX( FLOAT64 );  
		
		FOR lnr := sline TO eline DO 
			IF ~line.IntersectWRect( lnr, x, y, w, h, sx, sy, ex, ey ) THEN HALT( 100 ) END;  
			
			IF (sx > ex) OR ((sx = ex) & (sy > ey)) THEN swap( sx, ex );  swap( sy, ey )
			END;  
			sum := trapezeM.Z.GetSum( sx, sy, ex, ey, f1 );  sumsq := trapezeM.ZZ.GetSum( sx, sy, ex, ey, f1 );  
			sumX := trapezeM.X.GetSum( sx, sy, ex, ey, f1 );  sumY := trapezeM.Y.GetSum( sx, sy, ex, ey, f1 );  
			sumXY := trapezeM.XY.GetSum( sx, sy, ex, ey, f1 );  sumXZ := trapezeM.XZ.GetSum( sx, sy, ex, ey, f1 );  
			sumYZ := trapezeM.YZ.GetSum( sx, sy, ex, ey, f1 );  sumXX := trapezeM.XX.GetSum( sx, sy, ex, ey, f1 );  
			sumYY := trapezeM.YY.GetSum( sx, sy, ex, ey, f1 );  sumN := trapezeM.N.GetSum( sx, sy, ex, ey, f1 );  
			sumX4 := trapezeM.X4.GetSum( sx, sy, ex, ey, f1 );  sumY4 := trapezeM.Y4.GetSum( sx, sy, ex, ey, f1 );  
			sumX3 := trapezeM.X3.GetSum( sx, sy, ex, ey, f1 );  sumY3 := trapezeM.Y3.GetSum( sx, sy, ex, ey, f1 );  
			sumX3Y := trapezeM.X3Y.GetSum( sx, sy, ex, ey, f1 );  sumXY3 := trapezeM.XY3.GetSum( sx, sy, ex, ey, f1 );  
			sumX2Y2 := trapezeM.X2Y2.GetSum( sx, sy, ex, ey, f1 );  sumX2Y := trapezeM.X2Y.GetSum( sx, sy, ex, ey, f1 );  
			sumXY2 := trapezeM.XY2.GetSum( sx, sy, ex, ey, f1 );  sumX2Z := trapezeM.X2Z.GetSum( sx, sy, ex, ey, f1 );  
			sumY2Z := trapezeM.Y2Z.GetSum( sx, sy, ex, ey, f1 );  sumXYZ := trapezeM.XYZ.GetSum( sx, sy, ex, ey, f1 );  
			
			IF y > 0 THEN 
				sum := sum - rectM.Z.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumsq := sumsq - rectM.ZZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX := sumX - rectM.X.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumY := sumY - rectM.Y.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXY := sumXY - rectM.XY.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXZ := sumXZ - rectM.XZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumYZ := sumYZ - rectM.YZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXX := sumXX - rectM.XX.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumYY := sumYY - rectM.YY.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumN := sumN - rectM.N.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX4 := sumX4 - rectM.X4.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumY4 := sumY4 - rectM.Y4.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX3 := sumX3 - rectM.X3.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumY3 := sumY3 - rectM.Y3.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX3Y := sumX3Y - rectM.X3Y.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXY3 := sumXY3 - rectM.XY3.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX2Y2 := sumX2Y2 - rectM.X2Y2.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX2Y := sumX2Y - rectM.X2Y.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXY2 := sumXY2 - rectM.XY2.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumX2Z := sumX2Z - rectM.X2Z.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumY2Z := sumY2Z - rectM.Y2Z.GetSum( sx, y - 1, ex, y - 1, f2 );  
				sumXYZ := sumXYZ - rectM.XYZ.GetSum( sx, y - 1, ex, y - 1, f2 );  
			END;  
			IF (ex < x + w - 1) & (ey > y) THEN 
				sum := sum + rectM.Z.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumsq := sumsq + rectM.ZZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX := sumX + rectM.X.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumY := sumY + rectM.Y.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXY := sumXY + rectM.XY.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXZ := sumXZ + rectM.XZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumYZ := sumYZ + rectM.YZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXX := sumXX + rectM.XX.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumYY := sumYY + rectM.YY.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumN := sumN + rectM.N.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX4 := sumX4 + rectM.X4.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumY4 := sumY4 + rectM.Y4.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX3 := sumX3 + rectM.X3.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumY3 := sumY3 + rectM.Y3.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX3Y := sumX3Y + rectM.X3Y.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXY3 := sumXY3 + rectM.XY3.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX2Y2 := sumX2Y2 + rectM.X2Y2.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX2Y := sumX2Y + rectM.X2Y.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXY2 := sumXY2 + rectM.XY2.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumX2Z := sumX2Z + rectM.X2Z.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumY2Z := sumY2Z + rectM.Y2Z.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				sumXYZ := sumXYZ + rectM.XYZ.GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
				
				IF y > 0 THEN 
					sum := sum - rectM.Z.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumsq := sumsq - rectM.ZZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX := sumX - rectM.X.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumY := sumY - rectM.Y.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXY := sumXY - rectM.XY.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXZ := sumXZ - rectM.XZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumYZ := sumYZ - rectM.YZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXX := sumXX - rectM.XX.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumYY := sumYY - rectM.YY.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumN := sumN - rectM.N.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX4 := sumX4 - rectM.X4.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumY4 := sumY4 - rectM.Y4.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX3 := sumX3 - rectM.X3.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumY3 := sumY3 - rectM.Y3.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX3Y := sumX3Y - rectM.X3Y.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXY3 := sumXY3 - rectM.XY3.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX2Y2 := sumX2Y2 - rectM.X2Y2.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX2Y := sumX2Y - rectM.X2Y.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXY2 := sumXY2 - rectM.XY2.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumX2Z := sumX2Z - rectM.X2Z.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumY2Z := sumY2Z - rectM.Y2Z.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
					sumXYZ := sumXYZ - rectM.XYZ.GetSum( ex + 1, y - 1, x + w - 1, y - 1, f4 );  
				
				END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			
			IF (sx > x) & (sy > y) THEN 
				sum := sum + rectM.Z.GetSum( x, sy, sx - 1, sy, f3 );  sumsq := sumsq + rectM.ZZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX := sumX + rectM.X.GetSum( x, sy, sx - 1, sy, f3 );  sumY := sumY + rectM.Y.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXY := sumXY + rectM.XY.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXZ := sumXZ + rectM.XZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumYZ := sumYZ + rectM.YZ.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXX := sumXX + rectM.XX.GetSum( x, sy, sx - 1, sy, f3 );  
				sumYY := sumYY + rectM.YY.GetSum( x, sy, sx - 1, sy, f3 );  sumN := sumN + rectM.N.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX4 := sumX4 + rectM.X4.GetSum( x, sy, sx - 1, sy, f3 );  
				sumY4 := sumY4 + rectM.Y4.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX3 := sumX3 + rectM.X3.GetSum( x, sy, sx - 1, sy, f3 );  
				sumY3 := sumY3 + rectM.Y3.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX3Y := sumX3Y + rectM.X3Y.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXY3 := sumXY3 + rectM.XY3.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX2Y2 := sumX2Y2 + rectM.X2Y2.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX2Y := sumX2Y + rectM.X2Y.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXY2 := sumXY2 + rectM.XY2.GetSum( x, sy, sx - 1, sy, f3 );  
				sumX2Z := sumX2Z + rectM.X2Z.GetSum( x, sy, sx - 1, sy, f3 );  
				sumY2Z := sumY2Z + rectM.Y2Z.GetSum( x, sy, sx - 1, sy, f3 );  
				sumXYZ := sumXYZ + rectM.XYZ.GetSum( x, sy, sx - 1, sy, f3 );  
				
				IF y > 0 THEN 
					sum := sum - rectM.Z.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumsq := sumsq - rectM.ZZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX := sumX - rectM.X.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumY := sumY - rectM.Y.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXY := sumXY - rectM.XY.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXZ := sumXZ - rectM.XZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumYZ := sumYZ - rectM.YZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXX := sumXX - rectM.XX.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumYY := sumYY - rectM.YY.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumN := sumN - rectM.N.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX4 := sumX4 - rectM.X4.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumY4 := sumY4 - rectM.Y4.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX3 := sumX3 - rectM.X3.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumY3 := sumY3 - rectM.Y3.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX3Y := sumX3Y - rectM.X3Y.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXY3 := sumXY3 - rectM.XY3.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX2Y2 := sumX2Y2 - rectM.X2Y2.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX2Y := sumX2Y - rectM.X2Y.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXY2 := sumXY2 - rectM.XY2.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumX2Z := sumX2Z - rectM.X2Z.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumY2Z := sumY2Z - rectM.Y2Z.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					sumXYZ := sumXYZ - rectM.XYZ.GetSum( x, y - 1, sx - 1, y - 1, f4 );  
				END;  
			ELSE f3 := 0;  f4 := 0;  
			END;  
			upsum := rectM.Z.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sum;  
			IF y > 0 THEN upsum := upsum - rectM.Z.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumsq := rectM.ZZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumsq;  
			IF y > 0 THEN upsumsq := upsumsq - rectM.ZZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX := rectM.X.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX;  
			IF y > 0 THEN upsumX := upsumX - rectM.X.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumY := rectM.Y.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumY;  
			IF y > 0 THEN upsumY := upsumY - rectM.Y.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXY := rectM.XY.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXY;  
			IF y > 0 THEN upsumXY := upsumXY - rectM.XY.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXZ := rectM.XZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXZ;  
			IF y > 0 THEN upsumXZ := upsumXZ - rectM.XZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumYZ := rectM.YZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumYZ;  
			IF y > 0 THEN upsumYZ := upsumYZ - rectM.YZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXX := rectM.XX.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXX;  
			IF y > 0 THEN upsumXX := upsumXX - rectM.XX.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumYY := rectM.YY.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumYY;  
			IF y > 0 THEN upsumYY := upsumYY - rectM.YY.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumN := rectM.N.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumN;  
			IF y > 0 THEN upsumN := upsumN - rectM.N.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX4 := rectM.X4.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX4;  
			IF y > 0 THEN upsumX4 := upsumX4 - rectM.X4.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumY4 := rectM.Y4.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumY4;  
			IF y > 0 THEN upsumY4 := upsumY4 - rectM.Y4.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX3 := rectM.X3.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX3;  
			IF y > 0 THEN upsumX3 := upsumX3 - rectM.X3.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumY3 := rectM.Y3.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumY3;  
			IF y > 0 THEN upsumY3 := upsumY3 - rectM.Y3.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX3Y := rectM.X3Y.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX3Y;  
			IF y > 0 THEN upsumX3Y := upsumX3Y - rectM.X3Y.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXY3 := rectM.XY3.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXY3;  
			IF y > 0 THEN upsumXY3 := upsumXY3 - rectM.XY3.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX2Y2 := rectM.X2Y2.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX2Y2;  
			IF y > 0 THEN upsumX2Y2 := upsumX2Y2 - rectM.X2Y2.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX2Y := rectM.X2Y.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX2Y;  
			IF y > 0 THEN upsumX2Y := upsumX2Y - rectM.X2Y.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXY2 := rectM.XY2.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXY2;  
			IF y > 0 THEN upsumXY2 := upsumXY2 - rectM.XY2.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumX2Z := rectM.X2Z.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumX2Z;  
			IF y > 0 THEN upsumX2Z := upsumX2Z - rectM.X2Z.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumY2Z := rectM.Y2Z.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumY2Z;  
			IF y > 0 THEN upsumY2Z := upsumY2Z - rectM.Y2Z.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			upsumXYZ := rectM.XYZ.GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumXYZ;  
			IF y > 0 THEN upsumXYZ := upsumXYZ - rectM.XYZ.GetSum( x, y - 1, x + w - 1, y - 1, f6 ) END;  
			
			(*////////////////////////////////////////////////////////////////////////*)
			
			aM.dSR( "sumN =", sumN );  aM.dSR( "upsumN =", upsumN );  xx := ABS( sx - ex );  yy := ABS( sy - ey );  
			
			IF (sumN # 0) THEN 
								
				ssq1 := 
					g.QuadraticRegression( g.result3, sumX, sumY, sum, sumXY, sumXZ, sumYZ, sumXX, sumYY, sumsq, sumX4, 
														   sumY4, sumX3, sumY3, sumX3Y, sumXY3, sumX2Y2, sumX2Y, sumXY2, sumX2Z, sumY2Z, 
														   sumXYZ, sumN );  
				
				ee := g.result3[0, 0];  e := g.result3[1, 0];  d := g.result3[2, 0];  b := g.result3[3, 0];  c := g.result3[4, 0];  
				a := g.result3[5, 0];  
			ELSE ssq1 := 0; 
			END;  
			
			IF (upsumN # 0) THEN 
					ssq2 := 
					g.QuadraticRegression( g.result3, upsumX, upsumY, upsum, upsumXY, upsumXZ, upsumYZ, upsumXX, upsumYY, 
														   upsumsq, upsumX4, upsumY4, upsumX3, upsumY3, upsumX3Y, upsumXY3, upsumX2Y2, 
														   upsumX2Y, upsumXY2, upsumX2Z, upsumY2Z, upsumXYZ, upsumN );  
				upee := g.result3[0, 0];  upe := g.result3[1, 0];  upd := g.result3[2, 0];  upb := g.result3[3, 0];  
				upc := g.result3[4, 0];  upa := g.result3[5, 0];  
			ELSE ssq2 := 0; 
			END;  
			
			ssq := ssq1 + ssq2;  
			IF ssq < minsq THEN 
				minsq1 := ssq1;  minsq2 := ssq2;  minsq := ssq;  a1 := a;  b1 := b;  c1 := c;  d1 := d;  e1 := e;  ee1 := ee;  a2 := upa;  
				b2 := upb;  c2 := upc;  d2 := upd;  e2 := upe;  ee2 := upee;  linenr := lnr;  
				linelen := ENTIER( Math.sqrt( (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy) ) + 0.5 );  minN := sumN;  minupN := upsumN;  
				minX := sumX;  minY := sumY;  minZ := sum;  minXX := sumXX;  minYY := sumYY;  minZZ := sumsq;  
				minX4 := sumX4;  minY4 := sumY4;  minX3 := sumX3;  minY3 := sumY3;  
			
			END;  
		
		END;  
		
		ssq := minsq;  
	
	END GetBestWedgeQ;  
(*Gets the best wedge with a generic regression model*)
	PROCEDURE GetBestWedgeG*( rectM: GMomentsO;  trapezeM: GMomentsO;  x, y, w, h: SIZE;  VAR linenr, linelen: SIZE;  VAR ssq: FLOAT64;  
													  VAR minbeta1, minbeta2: ARRAY OF ARRAY OF FLOAT64;  psize: SIZE );  
	VAR ii, jj, iii, sx, ex, sy, ey, sline, eline: SIZE;  line: LineObject;  f1, f2, f3, f4, f5, f6, xx, yy, ddx, ddy, rx, ry: SIZE;  
		ssq1, ssq2, minsq, minsq1, minsq2, tmp: FLOAT64;  
		lnr: SIZE;   (*abc: wedgeMatrix.matrx;  *)
		g: wedgeGenericEq.GenericEq;   (* equation solver *)
	BEGIN 
		g := wedgeGenericEq.global;  
		
		IF (trapezeM[0].dx < 0) = (trapezeM[0].dy < 0) THEN sx := x;  sy := y + h - 1;  ex := x + w - 1;  ey := y;  
		ELSE sx := x;  ex := x + w - 1;  sy := y;  ey := y + h - 1;  
		END;  
		
		line := trapezeM[0].line;  sline := line.GetLineNr( sx, sy );  eline := line.GetLineNr( ex, ey );  
	
		IF eline < sline THEN swap( sline, eline ) END;  
		
		minsq := MAX( FLOAT64 );  
		
		FOR lnr := sline TO eline DO 
			IF ~line.IntersectWRect( lnr, x, y, w, h, sx, sy, ex, ey ) THEN HALT( 100 ) END;  
			
			IF (sx > ex) OR ((sx = ex) & (sy > ey)) THEN swap( sx, ex );  swap( sy, ey )
			END;  
			
			FOR ii := 0 TO SIZE(LEN( rectM )) - 1 DO 

				sumPhi[ii] := trapezeM[ii].GetSum( sx, sy, ex, ey, f1 );  
				
				IF y > 0 THEN sumPhi[ii] := sumPhi[ii] - rectM[ii].GetSum( sx, y - 1, ex, y - 1, f2 );  
				END;  
				
				IF (ex < x + w - 1) & (ey > y) THEN 
					sumPhi[ii] := sumPhi[ii] + rectM[ii].GetSum( ex + 1, ey, x + w - 1, ey, f3 );  
					IF y > 0 THEN sumPhi[ii] := sumPhi[ii] - rectM[ii].GetSum( ex + 1, y - 1, x + w - 1, y - 1, f3 );  END;  
				END;  
				
				IF (sx > x) & (sy > y) THEN 
					sumPhi[ii] := sumPhi[ii] + rectM[ii].GetSum( x, sy, sx - 1, sy, f3 );  
					
					IF y > 0 THEN sumPhi[ii] := sumPhi[ii] - rectM[ii].GetSum( x, y - 1, sx - 1, y - 1, f4 );  
					END;  
				END;  
				
				upsumPhi[ii] := rectM[ii].GetSum( x, y + h - 1, x + w - 1, y + h - 1, f5 ) - sumPhi[ii];  
				
				IF y > 0 THEN upsumPhi[ii] := upsumPhi[ii] - rectM[ii].GetSum( x, y - 1, x + w - 1, y - 1, f6 )
				END;  
			END;  
			
			ssq1 := g.GenericRegression( beta1, sumPhi, psize );  ssq2 := g.GenericRegression( beta2, upsumPhi, psize );  
			ssq := ssq1 + ssq2;  aM.dSR( "ssq1+ssq2......", ssq );  aM.dSR( "minsq before copy to ssq final", minsq );  
			
			IF ssq < minsq THEN 
				minsq1 := ssq1;  minsq2 := ssq2;  minsq := ssq;  linenr := lnr;  
				linelen := ENTIER( Math.sqrt( (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy) ) + 0.5 );  
				
				FOR ii := 0 TO (psize + 1) * (psize + 2) DIV 2 DO minsumPhi[ii] := sumPhi[ii];  minupsumPhi[ii] := upsumPhi[ii];  END;  
				FOR ii := 0 TO psize - 1 DO minbeta1[ii, 0] := beta1[ii, 0];  minbeta2[ii, 0] := beta2[ii, 0];  END;  
			
			END;  
		END;  
		
		ssq := minsq;  
	
	END GetBestWedgeG;  

	PROCEDURE dbgPaint( x, y: SIZE;  col: INTEGER;  smaller: BOOLEAN );  
	BEGIN 
		x := 100 + x * 5;  y := 100 + y * 5;  
		IF ~smaller THEN Display.ReplConst( col, SIGNED32(x), SIGNED32(y), 5, 5, Display.paint );  
		ELSE Display.ReplConst( col, SIGNED32(x) + 1, SIGNED32(y) + 1, 3, 3, Display.paint );  
		END;  
	END dbgPaint;  

	PROCEDURE Test*;  
	VAR l: LineObject;  w, h, dx, dy: SIGNED32;  x, y, z: SIZE;  inRange: BOOLEAN;  aerea, lasta: SIZE;  
	BEGIN 
		antsCommands.InitScan( "" );  
		IF antsCommands.ExpectNumber( "w", w ) & antsCommands.ExpectNumber( "h", h ) & antsCommands.ExpectNumber( "dx", dx ) & 
		    antsCommands.ExpectNumber( "dy", dy ) THEN 
			NEW( l, dx, dy, w, h );  
			IF l.vertical THEN 
				aM.S( "vertical" );  lasta := 0;  
				FOR y := 0 TO l.dy DO 
					dbgPaint( l.GetX( 0, y ), y, 1, FALSE );  aerea := l.a[y];  
					FOR z := 1 TO aerea - lasta DO dbgPaint( l.GetX( 0, y ), y - z, 5, TRUE );  END;  
					lasta := aerea;  
				END;  
				FOR x := 0 TO ABS( l.dx ) DO dbgPaint( x, l.YbyX[x], 2, TRUE );  END;  
			ELSE 
				aM.S( "not vertical" );  lasta := 0;  
				
				IF l.dx < 0 THEN dx := -1;  x := ABS( l.dx )
				ELSE dx := 1;  x := 0;  
				END;  
				
				WHILE (0 <= x) & (x <= ABS( l.dx )) DO 
					dbgPaint( x, l.GetY( 0, x ), 1, FALSE );  aerea := l.a[x];  
					FOR z := 1 TO aerea - lasta DO dbgPaint( x, l.GetY( 0, x ) - z, 5, TRUE );  END;  
					lasta := aerea;  INC( x, dx );  
				END;  
				FOR y := 0 TO l.dy DO dbgPaint( l.XbyY[y], y, 2, TRUE );  END;  
				Out.Ln;  
			END;  
			
			x := ENTIER( vyRandom.Uniform() * 100 );  y := ENTIER( vyRandom.Uniform() * 100 );  dbgPaint( x, y, 3, FALSE );  
			IF ~l.PreviousForCumSum( x, y, x, y, inRange ) THEN aM.S( "no previous for cum sum" );  ELSE dbgPaint( x, y, 3, inRange );  END;  
		
		END;  
	
	END Test;  

	PROCEDURE PaintLine( l: LineObject;  linenr: SIZE );  
	VAR x, y, dx: SIZE;  
	BEGIN 
		IF l.vertical THEN 
			FOR y := 0 TO l.dy DO dbgPaint( l.GetX( 0, y ) + linenr, y, 1, FALSE );  END;  
		ELSE 
			
			IF l.dx < 0 THEN dx := -1;  x := ABS( l.dx )
			ELSE dx := 1;  x := 0;  
			END;  
			
			WHILE (0 <= x) & (x <= ABS( l.dx )) DO dbgPaint( x, l.GetY( 0, x ) + linenr, 1, FALSE );  x := x + dx;  
			END;  
		END;  
	
	END PaintLine;  

	PROCEDURE IntersectTest*;  
	VAR l: LineObject;  w, h, dx, dy, nr, sx, sy, ex, ey, xx, yy: SIZE;  x, y, z: SIZE;  inRange: BOOLEAN;  aerea, lasta: SIZE;  
	BEGIN 
		dx := ENTIER( vyRandom.Uniform() * 100 );  dy := ENTIER( vyRandom.Uniform() * 100 );  
		IF (dx = 0) & (dy = 0) THEN dy := 1 END;  
		nr := ENTIER( vyRandom.Uniform() * 100 );  NEW( l, dx, dy, 100, 100 );  
		(*PaintLine(l,nr);*)
		x := ENTIER( vyRandom.Uniform() * 100 );  y := ENTIER( vyRandom.Uniform() * 100 );  w := ENTIER( vyRandom.Uniform() * (100 - x) );  
		h := ENTIER( vyRandom.Uniform() * (100 - y) );  
		(*
		FOR xx := 0 TO w-1 DO 
			FOR yy := 0 TO h-1 DO 
				IF (xx=0) OR (xx=w-1) OR (yy=0) OR (yy=h-1) THEN 
				dbgPaint(xx+x,yy+y,8,TRUE); 
				END; 
			END; 
		END; *)
		IF l.IntersectWRect( nr, x, y, w, h, sx, sy, ex, ey ) THEN 
			(*		dbgPaint(sx,sy,9,FALSE);
		dbgPaint(ex,ey,9,FALSE);*)
			ASSERT ( (sx = x) OR (sy = y) OR (sx = x + w - 1) OR (sy = y + h - 1), 1001 );  
			ASSERT ( (ex = x) OR (ey = y) OR (ex = x + w - 1) OR (ey = y + h - 1), 1002 );  
		
		END;  
	END IntersectTest;  
 
BEGIN  (* for profiler *)
END wedgeArrays.

System.Free wedgeArrays  ~
fofAutomatic.Do 
antsOrganizers.Refresh ~ (* clean up *)
wedgeArrays.Test 100 100 100  -20 ~
~
fofAutomatic.Do 
antsOrganizers.Refresh ~ (* clean up *)
wedgeArrays.IntersectTest
~
fofAutomatic.Do >iter 100000
wedgeArrays.IntersectTest
~


antsOrganizers.Refresh ~ (* clean up *)
~




		(*
		in Line: 
		
		PROCEDURE dbgOut;  
		VAR x, y: SIZE;  
		BEGIN 
			Out.String( "Line YbyX: " );  
			FOR x := 0 TO ABS( dx ) DO Out.Int( YbyX[x], 1 );  Out.String( "," );  END;  
			Out.Ln;  Out.String( "Line XbyY: " );  
			FOR y := 0 TO ABS( dy ) DO Out.Int( XbyY[y], 1 );  Out.String( "," );  END;  
			Out.Ln;  
			IF vertical THEN 
				Out.String( "area [y] : " );  
				FOR y := 0 TO ABS( dy ) DO Out.Int( a[y], 1 );  Out.String( "," );  END;  
				Out.Ln;  
			ELSE 
				Out.String( "area [x] : " );  
				FOR x := 0 TO ABS( dx ) DO Out.Int( a[x], 1 );  Out.String( "," );  END;  
				Out.Ln;  
			END;  
		END dbgOut;  
		
			(* currently unused
		PROCEDURE Neighbour*( x, y: SIZE;  forward: BOOLEAN;  VAR px, py: SIZE;  VAR inRange: BOOLEAN ): BOOLEAN;  
		(* get next position in line starting at (x,y) *)
		(* line must be computed such, that increase/decrease in constant 1 on x or y (as done by Init) *)
		VAR d: SIZE;  
		BEGIN 
			ASSERT ( vertical OR ((x <= ABS( dx )) & (x >= 0)), 100 );  
			ASSERT ( (~vertical) OR ((y <= ABS( dy )) & (y >= 0)), 101 );  
			inRange := FALSE;  
			(*d := GetLineNr( x, y );   (* offset to line through 0,0 *)*)
			IF vertical THEN  (* ABS(dy) > ABS(dx) *)
				d := XbyY[y];  d := x - d;  
				IF forward = positive THEN  (* line is from bottom to top *)
					py := y + 1;   (* next position in y direction *)
					IF py > ABS( dy ) THEN RETURN FALSE END;   (* out of range of line, not necessarily in (0,0,w,h)*)
				ELSE  (* line is from top to bottom *)
					py := y - 1;   (* next position in y direction *)
					IF py < 0 THEN RETURN FALSE END;   (* out of range of line, not necessarily in (0,0,w,h)  *)
				END;  
				px := XbyY[py];   (* x coordinate to next y position on "template" line *)
				INC( px, d );   (* move back to line through (x,y)  *)
				IF (0 <= px) & (px < w) THEN inRange := TRUE END;  
				RETURN TRUE;  
			ELSE 
				d := YbyX[x];  d := y - d;  
				IF forward = positive THEN 
					px := x + 1;  
					IF px > ABS( dx ) THEN RETURN FALSE END;  
				ELSE 
					px := x - 1;  
					IF px < 0 THEN RETURN FALSE END;  
				END;  
				py := YbyX[px];  INC( py, d );  
				IF (0 <= py) & (py < h) THEN inRange := TRUE END;  
				RETURN TRUE;  
			END;  
		END Neighbour;  
		*)

		*)
	(* currently unused

		PROCEDURE GetLineIntersect*( startx, starty: SIZE;  rx, ry: SIZE;  VAR endx, endy: SIZE ): BOOLEAN;  
		(* find end of line in rectangle rx,ry,rw,rh when starting at startx,starty; startx,starty must be in the rectangle *)
		VAR d: SIZE;  hx, hy, vx, vy: SIZE;  hor, ver: BOOLEAN;  
		BEGIN 
			ASSERT ( (0 <= rx) & (rx < w), 100 );  
			ASSERT ( (0 <= ry) & (ry < h), 101 );  
			
			endx := MAX( SIZE );  endy := MAX( SIZE );   (*d := GetLineNr( startx, starty );  *)
			
			ver := FALSE;  hor := FALSE;  
			
			IF vertical THEN  (* use x-d,y *)
				d := XbyY[starty];  d := startx - d;  vx := XbyY[ry] + d;  vy := ry;  
				IF (0 <= vx) & (vx < w) THEN ver := TRUE;  END;  
				IF ((rx - d) >= 0) & ((rx - d) <= ABS( SELF.dx )) THEN 
					hy := YbyX[rx - d];  hx := rx;  
					IF (0 <= hy) & (hy < h) THEN hor := TRUE;  END;  
				END;  
			ELSE  (* used x,y-d *)
				d := YbyX[startx];  d := starty - d;  hy := YbyX[rx] + d;  hx := rx;  
				IF (0 <= hy) & (hy < h) THEN hor := TRUE;  END;  
				IF ((ry - d) >= 0) & ((ry - d) <= ABS( SELF.dy )) THEN 
					vx := XbyY[ry - d];  vy := ry;  
					IF (0 <= vx) & (vx < w) THEN ver := TRUE;  END;  
				END;  
			END;  
			IF (hor = FALSE ) & (ver = FALSE ) THEN RETURN FALSE 
			ELSIF (hor = FALSE ) THEN endx := vx;  endy := vy
			ELSIF (ver = FALSE ) THEN endx := hx;  endy := hy
			ELSIF (ABS( vx - startx ) + ABS( vy - starty ) < ABS( hx - startx ) + ABS( hy - starty )) THEN endx := vx;  endy := vy
			ELSE endx := hx;  endy := hy
			END;  
			ASSERT ( (endx # MAX( SIZE )) & (endy # MAX( SIZE )) );  
			RETURN TRUE;  
		END GetLineIntersect;  
*)

	(*
		PROCEDURE TestVerticalM( ASrc, ACum: antsArrayObjects.tLONGREALArray );  
	VAR w, h: SIZE;  x, y: SIZE;  val: FLOAT64;  
	BEGIN 
		ASSERT ( ASrc # NIL , 100 );  
		ASSERT ( ACum # NIL , 101 );  
		ASSERT ( LEN( ASrc ) = LEN( ACum ), 102 );  
		ASSERT ( LEN( ASrc[0] ) = LEN( ACum[0] ), 103 );  
		
		FOR y := 0 TO h - 1 DO 
			ASSERT ( ACum[y, 0] = ASrc[y, 0] );  
			FOR x := 1 TO w - 1 DO val := ACum[y, x] - ACum[y - 1, x];  
				ASSERT ( ASrc[y, x] = val );  
			END;  
		END;  
	END TestVerticalM;  

	PROCEDURE CheckLineIntegrity( line: LineObject );  
	VAR x, y, tx, ty: SIZE;  
	BEGIN 
		FOR x := 0 TO ABS( line.dx ) DO 
			ASSERT ( line.YbyX[x] <= ABS( line.dy ), 100 );  
			ASSERT ( line.YbyX[x] >= 0, 101 );  
			ty := line.YbyX[x];  tx := line.XbyY[ty];  
			(* condition ? *)
		END;  
		FOR y := 0 TO ABS( line.dy ) DO 
			ASSERT ( line.XbyY[y] <= ABS( line.dx ), 103 );  
			ASSERT ( line.XbyY[y] >= 0, 104 );  
			tx := line.XbyY[y];  ty := line.YbyX[tx];  
			(* condition ? *) END;  
	END CheckLineIntegrity;  
	*)
