MODULE CumulativeMatrices IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Math := MathL IN A2, antsCommands, vyBase, antsArrayObjects, aM := antsMessages, vyName, wedgeTrees, vyGraphBase, 
	vyStrings := vyHostStrings, Oberon, antsArrays, antsArrayPictures16, vyPort, antsPictCoordinate, Objects, 
	antsPictureViews, antsHistogramEdit, antsToolbox, Out;  

CONST 
	strongChecks = FALSE;  debug = FALSE;  clockwise* = -1;  counterclockwise* = +1;  

TYPE 
	
	DotProcedure = PROCEDURE {DELEGATE} ( x, y: SIZE );  
	
	PROCEDURE Min( x, y: SIZE ): SIZE;  
	BEGIN 
		IF x < y THEN RETURN x ELSE RETURN y;  END;  
	END Min;  

	PROCEDURE Max( x, y: SIZE ): SIZE;  
	BEGIN 
		IF x > y THEN RETURN x ELSE RETURN y;  END;  
	END Max;  

(********* first part: rectangles and matrices *********)
TYPE 
	Array2d* = antsArrayObjects.tLONGREALArray;  

	RectSums* = OBJECT 
	VAR raw-, colsum, rectsum: Array2d;  
		
		PROCEDURE & Init*( Raw: Array2d );  
		BEGIN 
			raw := Raw;  AllocSame( raw^, colsum );  AllocSame( raw^, rectsum );  ColSum( raw^, colsum^ );  
			RowSum( colsum^, rectsum^ );  
		END Init;  

		PROCEDURE RectContent*( x1, y1, x2, y2: SIZE ): FLOAT64;  
		VAR sum: FLOAT64;  left, right, lower, upper: SIZE;  
		BEGIN 
			IF (x1 > x2) OR (y1 > y2) THEN RETURN 0 END;  
			sum := 0;  left := x1 - 1;  right := x2;  lower := y1 - 1;  upper := y2;  

			sum := sum + rectsum[upper, right];  
			
			IF (left >= 0) THEN sum := sum - rectsum[upper, left];  
			END;  
			IF (lower >= 0) THEN 
				sum := sum - rectsum[lower, right];  
				IF (left >= 0) THEN sum := sum + rectsum[lower, left];  END;  
			END;  
			
			RETURN sum;  
		END RectContent;  

	END RectSums;  
	
	PROCEDURE AllocSame*( VAR in: ARRAY OF ARRAY OF FLOAT64;  VAR out: Array2d );  
	(** allocate 2d array out with same dimension as in *)
	VAR w, h: SIZE;  
	BEGIN 
		h := LEN( in );  w := LEN( in[0] );  
		IF (out = NIL ) OR (LEN( out ) # h) OR (LEN( out[0] ) # w) THEN NEW( out, h, w );  END;  
	END AllocSame;  

	PROCEDURE Const*( in: FLOAT64;  VAR out: ARRAY OF ARRAY OF FLOAT64 );  
	(** Fill array out with value in *)
	VAR x, y: SIZE;  
	BEGIN 
		FOR y := 0 TO LEN( out ) - 1 DO 
			FOR x := 0 TO LEN( out[0] ) - 1 DO out[y, x] := in;  END;  
		END;  
	END Const;  

	PROCEDURE Square*( VAR in, out: ARRAY OF ARRAY OF FLOAT64 );  
	(** Fill out with squared values of elements of in *)
	VAR x, y: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR y := 0 TO LEN( in ) - 1 DO 
			FOR x := 0 TO LEN( in[0] ) - 1 DO val := in[y, x];  out[y, x] := val * val;  END;  
		END;  
	END Square;  

	PROCEDURE ColSum( VAR in, out: ARRAY OF ARRAY OF FLOAT64 );  
	(** Fill out with sums of values in columns of in*)
	VAR x, y: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR x := 0 TO LEN( in[0] ) - 1 DO 
			val := 0;  
			FOR y := 0 TO LEN( in ) - 1 DO val := val + in[y, x];  out[y, x] := val;  END;  
		END;  
	END ColSum;  

	PROCEDURE RowSum( VAR in, out: ARRAY OF ARRAY OF FLOAT64 );  
	(** Fill out with sums over values in rows of in *)
	VAR x, y: SIZE;  val: FLOAT64;  
	BEGIN 
		FOR y := 0 TO LEN( in ) - 1 DO 
			val := 0;  
			FOR x := 0 TO LEN( in[0] ) - 1 DO val := val + in[y, x];  out[y, x] := val;  END;  
		END;  
	END RowSum;  

(********* second part: wedges *********)
TYPE 
	
	WedgeSums* = OBJECT (RectSums)
	(* object for the fast computation of sums within wedges *)
	VAR wedgesum: Array2d;  
		prevx: SIZE;  
		val: FLOAT64;  
		dx, dy: SIZE;  
		
		LineRectIntersect*: PROCEDURE ( dx, dy, nr: SIZE;  rx, ry, rw, rh: SIZE;  VAR x1, y1, x2, y2: SIZE ): BOOLEAN;  
		TraverseLine*: PROCEDURE ( dx, dy: SIZE;  x1, y1, x2, y2: SIZE;  P: DotProcedure );  
		WedgeContent*: PROCEDURE {DELEGATE} ( rx, ry, rw, rh: SIZE;  x1, y1, x2, y2: SIZE ): FLOAT64;  
		
		Dot: DotProcedure;  
		
		PROCEDURE DotH( x, y: SIZE );  
		(* used for flat lines (dx >= dy) *)
		BEGIN 
			val := val + colsum[y, x];  wedgesum[y, x] := val;  
		END DotH;  

		PROCEDURE DotV( x, y: SIZE );  
		(* used for steep lines (dx < dy) *)
		BEGIN 
			IF x # prevx THEN val := val + colsum[y, x] ELSE  (* guaranteed: (y > prevy) *) val := val + raw[y, x];  END;  
			wedgesum[y, x] := val;  prevx := x;  
		END DotV;  

		PROCEDURE SetAngle*( dx, dy: SIZE );  
		VAR nr, minc, maxc, x1, y1, x2, y2, w, h: SIZE;  
		BEGIN 
			IF ABS( dx ) >= ABS( dy ) THEN 
				IF dx < 0 THEN dx := -dx;  dy := -dy END;  
				LineRectIntersect := LineRectIntersectH;  TraverseLine := LineH;  WedgeContent := WedgeContentH;  
				Dot := DotH;  
			ELSE 
				IF dy < 0 THEN dy := -dy;  dx := -dx END;  
				LineRectIntersect := LineRectIntersectV;  TraverseLine := LineV;  WedgeContent := WedgeContentV;  Dot := DotV;  
			
			END;  
			SELF.dx := dx;  SELF.dy := dy;  
			IF strongChecks THEN CheckLine( dx, dy ) END;  
			
			AllocSame( raw^, wedgesum );  h := LEN( raw );  w := LEN( raw[0] );  

			IntersectingLines( dx, dy, 0, 0, w, h, minc, maxc );  
			
			FOR nr := minc TO maxc DO 
				IF LineRectIntersect( dx, dy, nr, 0, 0, w, h, x1, y1, x2, y2 ) THEN val := 0;  TraverseLine( dx, dy, x1, y1, x2, y2, Dot ) END;  
			END;  
		
		END SetAngle;  

		PROCEDURE WedgeContentH*( rx, ry, rw, rh: SIZE;  x1, y1, x2, y2: SIZE ): FLOAT64;  
		VAR sum: FLOAT64;  
		BEGIN 
			IF strongChecks THEN CheckLine( dx, dy );  END;  
			IF strongChecks THEN 
				ASSERT ( LineNr( dx, dy, x1, y1 ) = LineNr( dx, dy, x2, y2 ), 1003 )
			END;  
			
			INC( rw, rx - 1 );  INC( rh, ry - 1 );  

			sum := wedgesum[y2, x2] - wedgesum[y1, x1] + colsum[y1, x1];  
			IF ry > 0 THEN sum := sum - (rectsum[ry - 1, x2] - rectsum[ry - 1, x1] + colsum[ry - 1, x1]);  END;  
			IF (x1 # rx) & (y1 = rh) THEN sum := sum + RectContent( rx, ry, x1 - 1, rh );  
			ELSIF (x2 # rw) & (y2 = rh) THEN sum := sum + RectContent( x2 + 1, ry, rw, rh );  
			END;  
			RETURN sum;  
		END WedgeContentH;  

		PROCEDURE WedgeContentV*( rx, ry, rw, rh: SIZE;  x1, y1, x2, y2: SIZE ): FLOAT64;  
		VAR sum: FLOAT64;  
		BEGIN 
			IF strongChecks THEN CheckLine( dx, dy );  END;  
			IF strongChecks THEN 
				ASSERT ( LineNr( dx, dy, x1, y1 ) = LineNr( dx, dy, x2, y2 ), 1003 )
			END;  
			
			INC( rw, rx - 1 );  INC( rh, ry - 1 );  

			sum := wedgesum[y2, x2] - wedgesum[y1, x1] + colsum[y1, x1];  
			IF (dx >= 0) THEN  (* right wedge *)
				IF ry > 0 THEN sum := sum - (rectsum[ry - 1, x2] - rectsum[ry - 1, x1] + colsum[ry - 1, x1]);  END;  
				
				IF (x2 < rw) THEN sum := sum + RectContent( x2 + 1, ry, rw, rh )
				END;  
			
			ELSE  (* left wedge *)
				IF ry > 0 THEN sum := sum - (rectsum[ry - 1, x1] - rectsum[ry - 1, x2] + colsum[ry - 1, x2]);  END;  
				
				IF (x2 > rx) THEN sum := sum + RectContent( rx, ry, x2 - 1, rh )
				END;  
			END;  
			
			RETURN sum;  
		END WedgeContentV;  

	END WedgeSums;  
	
	PROCEDURE LineV( dx, dy: SIZE;  x1, y1, x2, y2: SIZE;  P: DotProcedure );  
	VAR fraction: SIZE;  
	BEGIN 
		IF strongChecks THEN 
			ASSERT ( ABS( dy ) > ABS( dx ), 1001 );  
			ASSERT ( dy >= 0, 1002 )
		END;  
		
		P( x1, y1 );  dy := ASH( dy, 1 );  
		IF dx < 0 THEN 
			dx := ASH( -dx, 1 );  fraction := (dy DIV 2 + y1 * dx) MOD dy + dx;   (* fraction offset as if started at 0 *)
			WHILE (y1 # y2) DO 
				IF fraction >= dy THEN DEC( x1 );  DEC( fraction, dy );  END;  
				INC( y1 );  INC( fraction, dx );  P( x1, y1 );  
			END;  
		ELSE 
			dx := ASH( dx, 1 );  fraction := (dy DIV 2 + y1 * dx) MOD dy + dx;   (* fraction offset as if started at 0 *)
			WHILE (y1 # y2) DO 
				IF fraction >= dy THEN INC( x1 );  DEC( fraction, dy );  END;  
				INC( y1 );  INC( fraction, dx );  P( x1, y1 );  
			END;  
		END;  
	END LineV;  

	PROCEDURE LineH( dx, dy: SIZE;  x1, y1, x2, y2: SIZE;  P: DotProcedure );  
	VAR fraction: SIZE;  
	BEGIN 
		IF strongChecks THEN 
			ASSERT ( ABS( dx ) >= ABS( dy ), 1001 );  
			ASSERT ( dx >= 0, 1002 )
		END;  
		
		P( x1, y1 );  dx := ASH( dx, 1 );  
		IF dy < 0 THEN 
			dy := ASH( -dy, 1 );  fraction := (dx DIV 2 + x1 * dy) MOD dx + dy;   (* fraction offset as if started at 0 *)
			WHILE (x1 # x2) DO 
				IF fraction >= dx THEN DEC( y1 );  DEC( fraction, dx );  END;  
				INC( x1 );  INC( fraction, dy );  P( x1, y1 );  
			END;  
		ELSE 
			dy := ASH( dy, 1 );  fraction := (dx DIV 2 + x1 * dy) MOD dx + dy;   (* fraction offset as if started at 0 *)
			WHILE (x1 # x2) DO 
				IF fraction >= dx THEN INC( y1 );  DEC( fraction, dx );  END;  
				INC( x1 );  INC( fraction, dy );  P( x1, y1 );  
			END;  
		END;  
	END LineH;  

	PROCEDURE CheckLine( dx, dy: SIZE );  
	(** check if line fulfills positivity preconditions : flat lines point to the right while steep lines point up *)
	BEGIN 
		IF ABS( dx ) >= ABS( dy ) THEN 
			ASSERT ( dx >= 0, 1001 );  
		ELSE 
			ASSERT ( dy >= 0, 1002 );  
		END;  
	END CheckLine;  

	PROCEDURE LineNr( dx, dy, x, y: SIZE ): SIZE;  
	BEGIN 
		IF dx >= dy THEN 
			IF dy > 0 THEN RETURN y - RoundRatU( x * dy, dx ) ELSE RETURN y - RoundRatD( x * dy, dx ) END;  
		ELSE 
			IF dx > 0 THEN RETURN x - RoundRatU( y * dx, dy ) ELSE RETURN x - RoundRatD( y * dx, dy ) END;  
		END;  
	END LineNr;  

	PROCEDURE RoundRatU( p, q: SIZE ): SIZE;  
	(** correct rounding: n+1/2 maps to n+1  *)
	BEGIN 
		IF (q < 0) THEN q := -q;  p := -p END;  
		
		RETURN (ASH( p, 1 ) + q) DIV (ASH( q, 1 )) (* = (2*p + q) DIV 2*q *)
	END RoundRatU;  

	PROCEDURE RoundRatD( p, q: SIZE ): SIZE;  
	(** rounding with n+1/2 maps to n *)
	BEGIN 
		IF q < 0 THEN q := -q;  p := -p END;  
		
		IF ASH( p, 1 ) MOD q = 0 THEN  (* 2*p / q is an integer *)
			RETURN p DIV q;  
		ELSE 
			RETURN (ASH( p, 1 ) + q) DIV ASH( q, 1 );   (* (2*p + q) DIV 2*q *)
		END;  
	END RoundRatD;  

	PROCEDURE LineRectIntersectH( dx, dy, nr: SIZE;  rx, ry, rw, rh: SIZE;  VAR x1, y1, x2, y2: SIZE ): BOOLEAN;  
	BEGIN 
		INC( rw, rx );  DEC( rw, 1 );  INC( rh, ry );  DEC( rh );   (* lengths to points *)
		IF strongChecks THEN CheckLine( dx, dy );  END;  
		DEC( ry, nr );  DEC( rh, nr );   (* consider shifted rectangle and line through 0,0 *)
		IF dy > 0 THEN 
			x1 := RoundRatU( ry * dx, dy );  x2 := RoundRatU( rh * dx, dy );  
			IF (x1 < rx) THEN x1 := rx END;  
			IF (x2 > rw) THEN x2 := rw END;  
			IF x2 < x1 THEN RETURN FALSE END;  
			y1 := RoundRatU( x1 * dy, dx );  y2 := RoundRatU( x2 * dy, dx );  
		ELSIF dy < 0 THEN 
			x2 := RoundRatU( ry * dx, dy );  x1 := RoundRatU( rh * dx, dy );  
			IF (x1 < rx) THEN x1 := rx END;  
			IF (x2 > rw) THEN x2 := rw END;  
			IF x2 < x1 THEN RETURN FALSE END;  
			y1 := RoundRatD( x1 * dy, dx );  y2 := RoundRatD( x2 * dy, dx );  
		ELSE 
			IF (ry > 0) OR (rh < 0) THEN RETURN FALSE END;  
			x1 := rx;  x2 := rw;  y1 := 0;  y2 := 0;  
		END;  
		INC( y1, nr );  INC( y2, nr );  RETURN TRUE;  
	END LineRectIntersectH;  

	PROCEDURE LineRectIntersectV( dx, dy, nr: SIZE;  rx, ry, rw, rh: SIZE;  VAR x1, y1, x2, y2: SIZE ): BOOLEAN;  
	BEGIN 
		INC( rw, rx );  DEC( rw, 1 );  INC( rh, ry );  DEC( rh );   (* lengths to points *)
		IF strongChecks THEN CheckLine( dx, dy );  END;  
		DEC( rx, nr );  DEC( rw, nr );   (* consider shifted rectangle *)
		
		IF dx > 0 THEN 
			y1 := RoundRatU( rx * dy, dx );  y2 := RoundRatU( rw * dy, dx );  
			IF (y1 < ry) THEN y1 := ry END;  
			IF (y2 > rh) THEN y2 := rh END;  
			IF y2 < y1 THEN RETURN FALSE END;  
			x1 := RoundRatU( y1 * dx, dy );  x2 := RoundRatU( y2 * dx, dy );  
		ELSIF dx < 0 THEN 
			y2 := RoundRatU( rx * dy, dx );  y1 := RoundRatU( rw * dy, dx );  
			IF (y1 < ry) THEN y1 := ry END;  
			IF (y2 > rh) THEN y2 := rh END;  
			IF y2 < y1 THEN RETURN FALSE END;  
			x1 := RoundRatD( y1 * dx, dy );  x2 := RoundRatD( y2 * dx, dy );  
		ELSE 
			IF (rx > 0) OR (rw < 0) THEN RETURN FALSE END;  
			y1 := ry;  y2 := rh;  x1 := 0;  x2 := 0;  
		END;  
		INC( x1, nr );  INC( x2, nr );  RETURN TRUE;  
	
	END LineRectIntersectV;  
	
	PROCEDURE LineRectIntersect*( dx, dy, nr: SIZE;  rx, ry, rw, rh: SIZE;  VAR x1, y1, x2, y2: SIZE ): BOOLEAN;  
	BEGIN 
		IF dx >= dy THEN RETURN LineRectIntersectH(dx,dy,nr,rx, ry, rw, rh,x1,y1,x2,y2)
		ELSE RETURN LineRectIntersectV(dx,dy,nr,rx, ry, rw, rh,x1,y1,x2,y2)
		END; 
	END LineRectIntersect;  


	PROCEDURE IntersectingLines*( dx, dy: SIZE;  rx, ry, rw, rh: SIZE;  VAR min, max: SIZE );  
	(* precondition: rx,ry,rw,rh in positive quarter of R2 *)
	BEGIN 
		IF strongChecks THEN CheckLine( dx, dy );  END;  
		INC( rw, rx - 1 );  INC( rh, ry - 1 );  min := MAX( SIZE );  max := MIN( SIZE );  
		
		IF dx >= dy THEN 
			IF dy >= 0 THEN 
				min := ry - RoundRatU( rw * dy, dx );   (*right bottom*)
				max := rh - RoundRatU( rx * dy, dx );   (* left top *)
			ELSE 
				min := ry - RoundRatU( rx * dy, dx );   (* left bottom *)
				max := rh - RoundRatU( rw * dy, dx );   (* righ top *)
			END;  
		ELSE 
			IF dx >= 0 THEN 
				min := rx - RoundRatU( rh * dx, dy );   (* left top *)
				max := rw - RoundRatU( ry * dx, dy );   (* right bottom  *)
			ELSE 
				min := rx - RoundRatU( ry * dx, dy );   (* left bottom *)
				max := rw - RoundRatU( rh * dx, dy );   (* right top  *)
			END;  
		END;  
	END IntersectingLines;  

(********* third part: circles and arcs *********)
TYPE 
	CircleSums* = OBJECT (RectSums);  
	VAR circlesum: Array2d;  
		prevx, prevy: SIZE;  
		upper: SIZE;  
		val: FLOAT64;  
		cx, cy: SIZE;  
		
		PROCEDURE DotUpper( x, y: SIZE );  
		BEGIN 
			IF x > prevx THEN val := val + colsum[y, x];  
			ELSIF (y > prevy) THEN val := val + raw[y, x];  
			END;  
			circlesum[y + 1, x] := val;  prevx := x;  prevy := y;  
		END DotUpper;  

		PROCEDURE DotLower( x, y: SIZE );  
		BEGIN 
			IF x > prevx THEN 
				val := val + raw[y, x] + colsum[upper, x] - colsum[y, x];   (* sum up columns above point *)
			ELSIF (y < prevy) THEN val := val + raw[y, x]
			END;  
			
			circlesum[y, x] := val;  prevx := x;  prevy := y;  
		END DotLower;  

		PROCEDURE SetCenter*( cx, cy: SIZE );  
		VAR i, minc, maxc: SIZE;  rx, ry, rw, rh: SIZE;  lowy, upy, lowh, uph: SIZE;  q: PointQueue;  low, up: BOOLEAN;  
		BEGIN 
			SELF.cx := cx;  SELF.cy := cy;  rx := 0;  ry := 0;  rw := LEN( raw[0] );  rh := LEN( raw );  upper := rh - 1;  
			
			IF (circlesum = NIL ) OR (LEN( circlesum ) # rh + 1) OR (LEN( circlesum[0] ) # rw) THEN NEW( circlesum, rh + 1, rw );  
			END;  
			
			FindIntersectingCircles( cx, cy, 0, 0, rw, rh, minc, maxc );  Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  
			
			FOR i := minc TO maxc DO 
				IF low THEN 
					RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, i, q );  prevx := MIN( SIZE );  prevy := MIN( SIZE );  val := 0;  
					DoArcLow( cx, cy, i, q, DotLower );  
				END;  
				IF up THEN 
					RectCircleIntersect( rx, upy, rw, uph, cx, cy, i, q );  prevx := MIN( SIZE );  prevy := MIN( SIZE );  val := 0;  
					DoArcUp( cx, cy, i, q, DotUpper );  
				END;  
			END;  
		
		END SetCenter;  

		PROCEDURE UpperArcContent*( pl, pr: Point;  lowy: SIZE;  omitLowestLine: BOOLEAN ): FLOAT64;  
		VAR leftx, lefty, rightx, righty: SIZE;  sum: FLOAT64;  
		BEGIN 
			(* we have to shift positions in the circle line up one pixel since we work on upper part, see sumUpObject, this does not apply to the rectangles  *)
			leftx := pl.x;  lefty := pl.y;  rightx := pr.x;  righty := pr.y;  
			
			IF ~omitLowestLine THEN DEC( lowy );  
			END;  
			
			sum := circlesum[righty + 1, rightx];  
			IF lowy >= 0 THEN sum := sum - rectsum[lowy, rightx];  END;  
			
			sum := sum - circlesum[lefty + 1, leftx] + colsum[lefty, leftx];  
			
			IF (lowy >= 0) & (leftx > 0) THEN sum := sum + rectsum[lowy, leftx - 1];  
			END;  
			RETURN sum;  
		
		END UpperArcContent;  

		PROCEDURE LowerArcContent*( pl, pr: Point;  upy: SIZE ): FLOAT64;  
		VAR leftx, lefty, rightx, righty, lowy: SIZE;  sum: FLOAT64;  
		BEGIN 
			leftx := pl.x;  lefty := pl.y;  rightx := pr.x;  righty := pr.y;  lowy := Min( lefty, righty ) - 1;  
			
			IF debug THEN aM.SISI( "AddLowerArcContent leftx", leftx, "lefty", lefty );  aM.SISI( "AddLowerArcContent rightx", rightx, "righty", righty );  
			END;  
			
			sum := 
				circlesum[righty, rightx] - circlesum[lefty, leftx] + colsum[upper, leftx] - colsum[lefty, leftx] + raw[lefty, leftx];  
			RETURN sum - RectContent( leftx, upy + 1, rightx, upper );  
		END LowerArcContent;  

		PROCEDURE LowerQContent*( q: PointQueue;  rx, ry, rw, rh: SIZE ): FLOAT64;  
		VAR p1, p2: Point;  ml, mr: SIZE;  sum: FLOAT64;  
		BEGIN 
			ml := rx;  mr := rx + rw - 1;  p1 := q.head;  
			ASSERT ( p1 # NIL , 1000 );  
			
			p2 := p1.next;  
			IF (p2.y = ry) & (p2.x # rx) THEN 
				mr := p2.x - 1;  sum := LowerArcContent( p2, p1, ry + rh - 1 );  p1 := p2.next;  
				IF p1 # NIL  (* further intersection *) THEN 
					p2 := p1.next;  ml := p1.x + 1;  sum := sum + LowerArcContent( p2, p1, ry + rh - 1 );  
				END;  
				sum := sum + RectContent( ml, ry, mr, ry + rh - 1 );  
			ELSIF (p1.y = ry) OR (p1.x = rx + rw - 1) THEN 
				ml := p1.x + 1;  sum := LowerArcContent( p2, p1, ry + rh - 1 ) + RectContent( ml, ry, mr, ry + rh - 1 );  
			ELSE  (* two intersections only starting at upper boundary or left boundary and ending at right boundary or upper boundary *)
				ASSERT ( p2.next = NIL );  
				sum := LowerArcContent( p2, p1, ry + rh - 1 );  
			END;  
			RETURN sum; 
		END LowerQContent;  

		PROCEDURE UpperQContent*( q: PointQueue;  rx, ry, rw, rh: SIZE;  omitLowestLine: BOOLEAN ): FLOAT64;  
		VAR p1, p2: Point;  ml, mr: SIZE;  sum: FLOAT64;  
		BEGIN 
			ml := rx;  mr := rx + rw - 1;  p1 := q.head;  
			ASSERT ( p1 # NIL , 1000 );  
			
			p2 := p1.next;  
			IF (p2.y = ry + rh - 1) & (p2.x # rx + rw - 1) THEN 
				ml := p2.x + 1;  sum := UpperArcContent( p1, p2, ry, omitLowestLine );  p1 := p2.next;  
				IF p1 # NIL  (* further intersection *) THEN 
					p2 := p1.next;  mr := p1.x - 1;  sum := sum + UpperArcContent( p1, p2, ry, omitLowestLine );  
				END;  
				IF omitLowestLine THEN sum := sum + RectContent( ml, ry + 1, mr, ry + rh - 1 );  
				ELSE sum := sum + RectContent( ml, ry, mr, ry + rh - 1 );  
				END;  
			ELSIF (p1.y = ry + rh - 1) OR (p1.x = rx) THEN 
				mr := p1.x - 1;  
				IF omitLowestLine THEN sum := RectContent( ml, ry + 1, mr, ry + rh - 1 );  
				ELSE sum := RectContent( ml, ry, mr, ry + rh - 1 );  
				END;  
				sum := sum + UpperArcContent( p1, p2, ry, omitLowestLine );  
			ELSE  (* two intersections only starting at lower boundary or left boundary and ending at right boundary or lower boundary *)
				ASSERT ( p2.next = NIL );  
				sum := UpperArcContent( p1, p2, ry, omitLowestLine );  
			END;  
			RETURN sum; 
		END UpperQContent;  

	END CircleSums;  

TYPE 
	Point* = OBJECT 
	VAR
		x-, y-: SIZE;  
		xr, yr: FLOAT64;  
		next*, prev: Point;  
	END Point;  
	
	PointQueue* = RECORD  (* fifo *)
		head*, tail: Point;  
		
		(* Get a point from a queue from head (NIL if none) *)
		PROCEDURE Get( ): Point;  
		VAR t: Point;  
		BEGIN 
			t := head;  
			IF t = NIL THEN  (* zero elements in q *)
				(* skip *)
			ELSIF t = tail THEN  (* one element in q *)
				head := NIL;  tail := NIL  (* {(t.next = NIL) & (t.prev = NIL)} *)
			ELSE  (* more than one element in q *)
				head := t.next;  
				ASSERT ( head # NIL );  
				t.next := NIL;  head.prev := NIL 
			END;  
			ASSERT ( (t = NIL ) OR (t.next = NIL ) & (t.prev = NIL ) );   (* temp strong check *)
			RETURN t;  
		END Get;  
	(* Put a point in a queue at tail position.  *)
		PROCEDURE Put( t: Point );  
		BEGIN 
			ASSERT ( (t # NIL ) & (t.next = NIL ) & (t.prev = NIL ) );  
			IF head = NIL THEN  (* q empty *)
				head := t
			ELSE  (* q not empty *)
				tail.next := t;  t.prev := tail
			END;  
			tail := t
		END Put;  

		PROCEDURE Insert( p: Point;  before: Point );  
		VAR prev: Point;  
		BEGIN 
			IF before = NIL THEN Put( p );  
			ELSIF before = head THEN head.prev := p;  p.next := head;  head := p;  
				ASSERT ( head.prev = NIL );  
			ELSIF before = tail THEN p.prev := tail.prev;  tail.prev.next := p;  p.next := tail;  tail.prev := p;  
			ELSE prev := before.prev;  p.prev := prev;  prev.next := p;  p.next := before;  before.prev := p;  
			END;  
		END Insert;  

	END;  
	
	PROCEDURE CompareAndInsert( VAR q: PointQueue;  cx, cy: SIZE;  x, y: FLOAT64 );  
	VAR p, new: Point;   (*! use containers later on to prevent from allocating all the time *)
	BEGIN 
		NEW( new );  new.xr := x;  new.yr := y;  new.x := ENTIER( x + 0.5 );  new.y := ENTIER( y + 0.5 );  new.prev := NIL;  new.next := NIL;  

		p := q.head;  
		WHILE (p # NIL ) & (IsBeforeOnCircle( p.xr - cx, p.yr - cy, x - cx, y - cy )) DO p := p.next;  END;  
		IF (p # NIL ) & (p.xr = x) & (p.yr = y) THEN RETURN END;  
		q.Insert( new, p );  
	END CompareAndInsert;  

	PROCEDURE IsBeforeOnCircle( x, y, thanx, thany: FLOAT64 ): BOOLEAN;  
	(*check if point (x,y) is clockwise before (thanx,thany) on the circle with midpoint (0,0) . Startpoint is at  9 o'clock. 
       pae: keep plot in mind for thesis (plot of sin(alpha)/cos(alpha) for -pi/2 <= alpha <= 3pi/2
	*)
	BEGIN 
		IF (x = thanx) & (y = thany) THEN RETURN FALSE END;   (* exclude same 'time' *)
		
		IF (y = 0) THEN  (* 9 o'clock or 3 o'clock?*)
			IF (x < 0) THEN  (* 9 o'clock, before any other points *)
				RETURN TRUE 
			ELSIF (thany < 0) THEN  (* (thanx,thany) is on lower half *)
				RETURN TRUE 
			ELSE  (* (thanx,thany) is on upper half *)
				RETURN FALSE 
			END;  
		ELSIF (y > 0) THEN  (* (x,y) is on upper half *)
			IF (thany < 0) THEN  (* (thanx,thany) is on lower half *)
				RETURN TRUE 
			ELSIF (x * thany) < (thanx * y) THEN  (*  same half check *)
				RETURN TRUE 
			ELSE RETURN FALSE 
			END;  
		ELSE  (* (x,y) is on lower half *)
			IF (thany >= 0) THEN  (* (thanx,thany) is on upper half *)
				RETURN FALSE 
			ELSIF (x * thany) < (thanx * y) THEN  (*  same half check *)
				RETURN TRUE 
			ELSE RETURN FALSE 
			END;  
		END;  
	END IsBeforeOnCircle;  

	PROCEDURE LineCircleIntersectV( lx, cx, cy, cr: SIZE;  VAR x1, y1, x2, y2: FLOAT64 ): BOOLEAN;  
	VAR rsq, dsq: SIZE;  dy: FLOAT64;  
	BEGIN 
		dsq := lx - cx;  dsq := dsq * dsq;  rsq := cr * cr;  
		IF rsq > dsq THEN dy := Math.sqrt( rsq - dsq );  x1 := lx;  x2 := lx;  y1 := cy - dy;  y2 := cy + dy;  RETURN TRUE;  
		ELSE RETURN FALSE 
		END;  
	END LineCircleIntersectV;  

	PROCEDURE RectCircleIntersect*( rx, ry, rw, rh, cx, cy, cr: SIZE;  VAR q: PointQueue );  
	VAR x1, y1, x2, y2: FLOAT64;  p: Point;  

		PROCEDURE CheckCorner( x, y: FLOAT64 ): BOOLEAN;  
		BEGIN 
			IF (x = rx) & (y = ry) THEN 
				IF ((cx > x) & (cy > y)) OR ((cx <= x) & (cy <= y)) THEN RETURN FALSE ELSE RETURN TRUE;  END;  
			ELSIF (x = rx + rw - 1) & (y = ry) THEN 
				IF ((cx < x) & (cy > y)) OR ((cx >= x) & (cy <= y)) THEN RETURN FALSE ELSE RETURN TRUE;  END;  
			ELSIF (x = rx) & (y = ry + rh - 1) THEN 
				IF ((cx <= x) & (cy >= y)) OR ((cx > x) & (cy < y)) THEN RETURN FALSE ELSE RETURN TRUE;  END;  
			ELSIF (x = rx + rw - 1) & (y = ry + rh - 1) THEN 
				IF ((cx >= x) & (cy >= y)) OR ((cx < x) & (cy < y)) THEN RETURN FALSE ELSE RETURN TRUE;  END;  
			ELSE RETURN TRUE;  
			END;  
		END CheckCorner;  

	BEGIN 
		q.head := NIL;  q.tail := NIL;  
		IF LineCircleIntersectV( rx, cx, cy, cr, x1, y1, x2, y2 ) THEN 
			IF (y1 >= ry) & (y1 <= ry + rh - 1) & CheckCorner( x1, y1 ) THEN CompareAndInsert( q, cx, cy, x1, y1 );  END;  
			IF (y2 >= ry) & (y2 <= ry + rh - 1) & CheckCorner( x2, y2 ) THEN CompareAndInsert( q, cx, cy, x2, y2 );  END;  
		END;  
		IF LineCircleIntersectV( rx + rw - 1, cx, cy, cr, x1, y1, x2, y2 ) THEN 
			IF (y1 >= ry) & (y1 <= ry + rh - 1) & CheckCorner( x1, y1 ) THEN CompareAndInsert( q, cx, cy, x1, y1 );  END;  
			IF (y2 >= ry) & (y2 <= ry + rh - 1) & CheckCorner( x2, y2 ) THEN CompareAndInsert( q, cx, cy, x2, y2 );  END;  
		END;  
		IF LineCircleIntersectV( ry, cy, cx, cr, y1, x1, y2, x2 ) THEN 
			IF (x1 >= rx) & (x1 <= rx + rw - 1) & CheckCorner( x1, y1 ) THEN CompareAndInsert( q, cx, cy, x1, y1 );  END;  
			IF (x2 >= rx) & (x2 <= rx + rw - 1) & CheckCorner( x2, y2 ) THEN CompareAndInsert( q, cx, cy, x2, y2 );  END;  
		END;  
		IF LineCircleIntersectV( ry + rh - 1, cy, cx, cr, y1, x1, y2, x2 ) THEN 
			IF (x1 >= rx) & (x1 <= rx + rw - 1) & CheckCorner( x1, y1 ) THEN CompareAndInsert( q, cx, cy, x1, y1 );  END;  
			IF (x2 >= rx) & (x2 <= rx + rw - 1) & CheckCorner( x2, y2 ) THEN CompareAndInsert( q, cx, cy, x2, y2 );  END;  
		END;  
		
		IF (rx < (cx - cr)) & (rx + rw > (cx - cr)) & (ry < cy) & (ry + rh > cy) THEN 
			(* 9 o'clock point of circle is within rectangle, necessary with distinction of upper and lower rectangles ??*)
			p := q.Get();  
			IF p # NIL THEN 
				p.next := NIL;  p.prev := NIL;  
				q.Put( p );   (* Put first element to last position *)
			END;  
		END;  
		(*DebugDumpQ( q ); DebugPaintCircle( cx, cy, cr );  DebugPaintRect( rx, ry, rw, rh ); DebugPaintQ( q ); *)
		
	END RectCircleIntersect;  

	PROCEDURE ReorderForLower*( xc, yc: SIZE;  r: SIZE;  VAR q: PointQueue );  
	VAR p1: Point;  
	BEGIN 
		p1 := q.head;  
		(*reorder point > the LHS to RHS*)
		IF (p1 # NIL ) & (p1.y = yc) & (p1.x = xc - r) THEN 
			p1 := q.Get();  p1.next := NIL;  p1.prev := NIL;  q.Put( p1 );   (* put p1  to tail of queue *)
			IF debug THEN aM.SISI( "removed and inserted", p1.x, " ", p1.y );  END;  
			p1 := q.head;   (* get (new) first element of queue*)
		END;  
	END ReorderForLower;  

	PROCEDURE FindIntersectingCircles*( xc, yc, x, y, w, h: SIZE;  VAR rmin, rmax: SIZE );  
	VAR dist, maxdist, mindist: SIZE;  
	BEGIN 
		dist := (xc - x) * (xc - x) + (yc - y) * (yc - y);  dist := ENTIER( Math.sqrt( dist ) + 0.5 );  maxdist := dist;  mindist := dist;  
		dist := (xc - x - w + 1) * (xc - x - w + 1) + (yc - y) * (yc - y);  dist := ENTIER( Math.sqrt( dist ) + 0.5 );  
		IF dist > maxdist THEN maxdist := dist END;  
		IF dist < mindist THEN mindist := dist END;  
		dist := (xc - x) * (xc - x) + (yc - y - h + 1) * (yc - y - h + 1);  dist := ENTIER( Math.sqrt( dist ) + 0.5 );  
		IF dist > maxdist THEN maxdist := dist END;  
		IF dist < mindist THEN mindist := dist END;  
		dist := (xc - x - w + 1) * (xc - x - w + 1) + (yc - y - h + 1) * (yc - y - h + 1);  dist := ENTIER( Math.sqrt( dist ) + 0.5 );  
		IF dist > maxdist THEN maxdist := dist END;  
		IF dist < mindist THEN mindist := dist END;  
		
		rmax := maxdist;  
		IF (xc >= x) & (xc < x + w) & (yc >= y) & (yc <= y + h - 1) THEN rmin := 1;  
		ELSIF (xc >= x) & (xc < x + w) THEN 
			IF (yc <= y) THEN rmin := y - yc
			ELSIF (yc >= y + h) THEN rmin := yc - y - h + 1
			END;  
		ELSIF (yc >= y) & (yc < y + h) THEN 
			IF (xc <= x) THEN rmin := x - xc
			ELSIF (xc >= x + w) THEN rmin := xc - x - w + 1
			END;  
		ELSE rmin := mindist;  
		END;  
	END FindIntersectingCircles;  

	PROCEDURE Split*( ry, rh, cy: SIZE;  VAR lowy, lowh, upy, uph: SIZE;  VAR lower, upper: BOOLEAN );  
	BEGIN 
		IF (ry <= cy) THEN lowy := ry;  lowh := Min( cy - ry + 1, rh );  ELSE lowh := 0;  END;  
		IF ry + rh > cy THEN upy := Max( ry, cy );  uph := Min( ry + rh - cy, rh );  ELSE uph := 0;  END;  
		IF uph > 1 THEN upper := TRUE ELSE upper := FALSE END;  
		IF lowh > 1 THEN lower := TRUE ELSE lower := FALSE END;  
	END Split;  

	PROCEDURE ARC*( xc, yc: SIZE;  r: SIZE;  x1, y1, x2, y2: SIZE;  dir: SIGNED16;  P: DotProcedure );  
	VAR e, ex, ey, exy, dxe, dye, d2e, dx, dy, rsq: SIZE;  time: SIZE;  
	CONST maxlen = 1000000;  
		(*  Given the intersections get and arc from the starting point to ending point  with respect to radius (r)*)
		(* Base on the Algorithms in the paper*)
		 (* ARC traverses arc of circle with midpoint at xc and yc and radius r. Digitization rule : { (x,y) in Z^2:  ABS(x-Circle(y)) <= 1/2 OR ABS(y-Circle(x)) <= 1/2 } *)
		
		PROCEDURE Negate( VAR e, dxe, dye, d2e: SIZE );  
		BEGIN 
			e := -e;  dxe := -dxe;  dye := -dye;  d2e := -d2e;  
		END Negate;  

		PROCEDURE sgn2( x, y: SIZE ): SIGNED16;  

			PROCEDURE sgn( x: SIZE ): SIGNED16;  
			BEGIN 
				IF x < 0 THEN RETURN -1
				ELSIF x = 0 THEN RETURN 0;  
				ELSE RETURN 1;  
				END;  
			END sgn;  

		BEGIN 
			IF x # 0 THEN RETURN sgn( x ) ELSE RETURN sgn( y );  END;  
		END sgn2;  

	BEGIN 
		IF (x1 = x2) & (y1 = y2) THEN P( x1, y1 );  RETURN END;  
		IF (x1 = MAX( SIZE )) OR (x2 = MAX( SIZE )) THEN RETURN END;  
		x1 := x1 - xc;  x2 := x2 - xc;  y1 := y1 - yc;  y2 := y2 - yc;  rsq := r * r;  dx := sgn2( -y1 * dir, -x1 );  
		dy := sgn2( x1 * dir, -y1 );  e := x1 * x1 + y1 * y1 - rsq;  dxe := 2 * x1 * dx + 1;  dye := 2 * y1 * dy + 1;  d2e := 2;  
		IF (dx * dy * dir) > 0 THEN Negate( e, dxe, dye, d2e );  END;  
		REPEAT 
			INC( time );  
			IF time > maxlen THEN HALT( 100 ) END;  
			P( xc + x1, yc + y1 );  ex := e + dxe;  ey := e + dye;  exy := e + dxe + dye;  
			IF -exy < ey THEN x1 := x1 + dx;  e := e + dxe;  dxe := dxe + d2e;  END;  
			IF exy < -ex THEN y1 := y1 + dy;  e := e + dye;  dye := dye + d2e;  END;  
			IF x1 = 0 THEN dy := -dy;  dye := -dye + d2e;  Negate( e, dxe, dye, d2e );  END;  
			IF y1 = 0 THEN dx := -dx;  dxe := -dxe + d2e;  Negate( e, dxe, dye, d2e );  END;  
		UNTIL ((x1 = x2) & (y1 = y2));  
		P( xc + x1, yc + y1 );  
	END ARC;  

	PROCEDURE DoArcUp( xc, yc: SIZE;  r: SIZE;  VAR q: PointQueue;  P: DotProcedure );  
	VAR p1, p2: Point;  
	BEGIN 
		p1 := q.head;   (* get first element of queue and remove from queue *)
		WHILE (p1 # NIL ) DO p2 := p1.next;  
			ASSERT ( p2 # NIL , 1001 );  
			(* IF p2 = NIL THEN aM.SI( "radius=", r );  DebugDumpQ( q );  HALT( 100 ) END;  *)
			ARC( xc, yc, r, p1.x, p1.y, p2.x, p2.y, clockwise, P );  p1 := p2.next;  
		END;  
	END DoArcUp;  

	PROCEDURE DoArcLow( xc, yc: SIZE;  r: SIZE;  VAR q: PointQueue;  P: DotProcedure );  
	VAR p1, p2: Point;  
	BEGIN 
		ReorderForLower( xc, yc, r, q );  p1 := q.head;  
		WHILE (p1 # NIL ) DO p2 := p1.next;  
			ASSERT ( p2 # NIL , 1001 );  
			(* IF p2 = NIL THEN aM.SI( "radius=", r );  DebugDumpQ( q );  HALT( 100 ) END;  *)
			ARC( xc, yc, r, p2.x, p2.y, p1.x, p1.y, counterclockwise, P );  p1 := p2.next;  
		END;  
	END DoArcLow;  

TYPE 
	LineR = RECORD 
		left, right: SIZE;  
	END;  
	
	LinePath = OBJECT 
	VAR start, len: SIZE;  
		lines: POINTER TO ARRAY OF LineR;  
		
		PROCEDURE & Init( start, len: SIZE );  
		VAR i: SIZE;  
		BEGIN 
			SELF.start := start;  SELF.len := len;  
			IF (lines = NIL ) OR (LEN( lines ) < len) THEN NEW( lines, len ) END;  
			FOR i := 0 TO len - 1 DO lines[i].left := MAX( SIZE );  lines[i].right := MIN( SIZE );  END;  
		END Init;  

		PROCEDURE EnterV( x, y: SIZE );  
		BEGIN 
			(* aM.SISI( "Enter: ", x, " ", y );  *)
			IF lines[x - start].left > y THEN lines[x - start].left := y END;  
			IF lines[x - start].right < y THEN lines[x - start].right := y END;  
		END EnterV;  

		PROCEDURE EnterH( x, y: SIZE );  
		BEGIN 
			(* aM.SISI( "Enter: ", x, " ", y );  *)
			IF lines[y - start].left > x THEN lines[y - start].left := x END;  
			IF lines[y - start].right < x THEN lines[y - start].right := x END;  
		END EnterH;  

		PROCEDURE FillV( a: Array2d;  with: FLOAT64 );  
		VAR x, y: SIZE;  
		BEGIN 
			FOR x := 0 TO len - 1 DO 
				FOR y := lines[x].left TO lines[x].right DO a[y, x + start] := with;  END;  
			END;  
		END FillV;  

		PROCEDURE FillH( a: Array2d;  with: FLOAT64 );  
		VAR x, y: SIZE;  
		BEGIN 
			FOR y := 0 TO len - 1 DO 
				FOR x := lines[y].left TO lines[y].right DO a[y + start, x] := with;  END;  
			END;  
		END FillH;  

	END LinePath;  
	
	PROCEDURE FillRect*( a: Array2d;  x, y, w, h: SIZE;  with: FLOAT64 );  
	VAR x0, y0: SIZE;  
	BEGIN 
		FOR y0 := y TO y + h - 1 DO 
			FOR x0 := x TO x + w - 1 DO a[y0, x0] := with;  END;  
		END;  
	END FillRect;  

	PROCEDURE FillWedge*( a: Array2d;  dx, dy, nr, rx, ry, rw, rh: SIZE;  val: FLOAT64 );  
	VAR x1, y1, x2, y2, i: SIZE;  lines: LinePath;  
	BEGIN 
		(*IF LineRectIntersect( dx, dy, nr, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN *)
		IF (ABS( dx ) >= ABS( dy )) & (LineRectIntersectH( dx, dy, nr, rx, ry, rw, rh, x1, y1, x2, y2 )) THEN 
			NEW( lines, rx, rw );  LineH( dx, dy, x1, y1, x2, y2, lines.EnterV );  
			FOR i := x1 TO x2 DO lines.EnterV( i, ry );  END;  
			lines.FillV( a, val );  
			
			IF (x1 # rx) & (y1 = ry + rh - 1) THEN FillRect( a, rx, ry, x1 - rx, rh, val );  
			ELSIF (x2 # rw) & (y2 = ry + rh - 1) THEN FillRect( a, x2 + 1, ry, rx + rw - x2 - 1, rh, val );  
			END;  
		ELSIF (LineRectIntersectV( dx, dy, nr, rx, ry, rw, rh, x1, y1, x2, y2 )) THEN 
			(*
			ASSERT ( y1 <= y2 );  
			
			NEW( lines, ry, rh );  LineV( dx, dy, nr, x1, y1, x2, y2, lines.EnterH );  
			FOR i := y1 TO y2 DO lines.EnterH( rx, i );  END;  
			lines.FillH( a, val );  
			
			IF (y1 # ry) & (x1 = rx + rw - 1) THEN FillRect( a, rx, ry, rw, y1 - ry, val );  
			ELSIF (y2 # rh) & (x2 = rx + rw - 1) THEN FillRect( a, rx, y2 + 1, rw, ry + rh - y2 - 1, val );  
			END;  
			*)
			NEW( lines, rx, rw );  LineV( dx, dy, x1, y1, x2, y2, lines.EnterV );  
			IF dx >= 0 THEN 
				FOR i := x1 TO x2 DO lines.EnterV( i, ry );  END;  
				lines.FillV( a, val );  
				IF (x2 # rw) THEN FillRect( a, x2 + 1, ry, rw + rx - x2 - 1, rh, val );  END;  
			ELSE 
				FOR i := x2 TO x1 DO lines.EnterV( i, ry );  END;  
				lines.FillV( a, val );  
				IF (x2 # rx) THEN FillRect( a, rx, ry, x2 - rx, rh, val );  END;  
			END;  
		
		END;  
		(*	END;  *)
	END FillWedge;  

	PROCEDURE RectInCircle*( rx, ry, rw, rh, cx, cy, cr: SIZE ): BOOLEAN;  
	BEGIN 
		DEC( rw );  DEC( rh );  DEC( rx, cx );  DEC( ry, cy );  INC( rw, rx );  INC( rh, ry );  cr := cr * cr;  rx := rx * rx;  ry := ry * ry;  rh := rh * rh;  
		rw := rw * rw;  
		IF (rx + ry <= cr) & (rx + rh <= cr) & (rw + ry <= cr) & (rw + rh <= cr) THEN RETURN TRUE ELSE RETURN FALSE END;  
	END RectInCircle;  

	PROCEDURE FillLineH( a: Array2d;  y: SIZE;  left, right: SIZE;  with: FLOAT64 );  
	VAR i: SIZE;  
	BEGIN 
		(* aM.SI( "FillLine", y );  aM.SISI( "left", left, "right", right );  aM.SR( "with=", with );  *)
		FOR i := left TO right DO a[y, i] := with;  END;  
	END FillLineH;  

	PROCEDURE FillCircleUp( cx, cy, cr, rx, ry, rw, rh: SIZE;  VAR q: PointQueue;  a: Array2d;  val: FLOAT64 );  
	VAR lines: LinePath;  
	VAR i: SIZE;  p1, p2: Point;  

		PROCEDURE EnterVLine( x, ystart, yend: SIZE );  
		VAR y: SIZE;  
		BEGIN 
			FOR y := ystart TO yend DO lines.EnterH( x, y );  END;  
		END EnterVLine;  

	BEGIN 
		NEW( lines, ry, rh );  

		p1 := q.head;  
		IF p1 # NIL THEN 
			p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, lines.EnterH );  
			IF p1.y < p2.y THEN 
				IF p1.x = rx THEN EnterVLine( rx, ry, p1.y - 1 ) (* ;  ELSIF p2.x=rx+rw-1 THEN  EnterVLine( rx , ry, ry+rh-1 ); *) END;  
				p1 := p2.next;  
				IF p1 # NIL THEN 
					p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, lines.EnterH );  
					IF p1.y >= p2.y THEN 
						IF p2.x = rx + rw - 1 THEN EnterVLine( rx + rw - 1, ry, p2.y - 1 );  END;  
					END;  
				ELSE  (* p1 = NIL *)
					IF p2.y = ry + rh - 1 THEN EnterVLine( rx + rw - 1, ry, ry + rh - 1 );  ELSE EnterVLine( rx + rw - 1, ry, p2.y - 1 );  END;  
				END;  
			ELSIF p1.y = p2.y THEN EnterVLine( rx, ry, p1.y - 1 );  EnterVLine( rx + rw - 1, ry, p2.y - 1 )
			ELSE 
				IF p2.x = rx + rw - 1 THEN EnterVLine( rx + rw - 1, ry, p2.y - 1 );  END;  
				IF p1.y = ry + rh - 1 THEN EnterVLine( rx, ry, ry + rh - 1 );  ELSE EnterVLine( rx, ry, p1.y - 1 );  END;  
			END;  
		ELSE 
			(* add left and right boundaries *)
			IF RectInCircle( rx, ry, rw, rh, cx, cy, cr ) THEN 
				EnterVLine( rx, ry, ry + rh - 1 );  EnterVLine( rx + rw - 1, ry, ry + rh - 1 );  
			END;  
		END;  
		FOR i := 0 TO rh - 1 DO FillLineH( a, ry + i, lines.lines[i].left, lines.lines[i].right, val );  END;  
	END FillCircleUp;  

	PROCEDURE FillCircleLow( cx, cy, cr, rx, ry, rw, rh: SIZE;  VAR q: PointQueue;  a: Array2d;  val: FLOAT64 );  
	VAR lines: LinePath;  
	VAR i: SIZE;  p1, p2: Point;  

		PROCEDURE EnterVLine( x, ystart, yend: SIZE );  
		VAR y: SIZE;  
		BEGIN 
			FOR y := ystart TO yend DO lines.EnterH( x, y );  END;  
		END EnterVLine;  

	BEGIN 
		NEW( lines, ry, rh );  

		p1 := q.head;  
		IF p1 # NIL THEN 
			p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, lines.EnterH );  
			IF p1.y > p2.y THEN 
				IF debug THEN aM.S( "Case 1" );  aM.SISI( "p1.x,p1.y = ", p1.x, ",", p1.y );  aM.SISI( "p2.x,p2.y = ", p2.x, ",", p2.y );  END;  
				
				IF p1.x = rx + rw - 1 THEN EnterVLine( rx + rw - 1, p1.y + 1, ry + rh - 1 );  
				END;  
				p1 := p2.next;  
				IF p1 # NIL THEN 
					IF debug THEN aM.S( "Case 2" );  aM.SISI( "p1.x,p1.y = ", p1.x, ",", p1.y );  aM.SISI( "p2.x,p2.y = ", p2.x, ",", p2.y );  END;  
					p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, lines.EnterH );  
					IF p1.y <= p2.y THEN 
						IF p2.x = rx THEN EnterVLine( rx, p2.y + 1, ry + rh - 1 );  END;  
					END;  
				ELSE  (* p1 = NIL *)
					IF p2.y = ry THEN EnterVLine( rx, ry, ry + rh - 1 );  ELSE EnterVLine( rx, p2.y + 1, ry + rh - 1 );  END;  
				END;  
			ELSIF p1.y = p2.y THEN EnterVLine( rx, p1.y + 1, ry + rh - 1 );  EnterVLine( rx + rw - 1, p2.y + 1, ry + rh - 1 )
			ELSE  (* p1.y < p2.y *)
				IF debug THEN aM.S( "Case 1 + 2" );  END;  
				EnterVLine( rx, p2.y + 1, ry + rh - 1 );  
				IF p1.y = ry THEN EnterVLine( rx + rw - 1, ry, ry + rh - 1 );  ELSE EnterVLine( rx + rw - 1, p1.y + 1, ry + rh - 1 );  END;  
			END;  
		ELSE 
			IF debug THEN aM.S( "Case 3" );  END;  
			(* add left and right boundaries *)
			IF RectInCircle( rx, ry, rw, rh, cx, cy, cr ) THEN 
				EnterVLine( rx, ry, ry + rh - 1 );  EnterVLine( rx + rw - 1, ry, ry + rh - 1 );  
			END;  
			(* add left and right boundaries *)
		END;  
		
		FOR i := 0 TO rh - 1 DO FillLineH( a, ry + i, lines.lines[i].left, lines.lines[i].right, val );  END;  
	END FillCircleLow;  

	PROCEDURE FillCircle*( a: Array2d;  cx, cy, cr, rx, ry, rw, rh: SIZE;  val: FLOAT64 );  
	VAR lowy, lowh, upy, uph: SIZE;  q: PointQueue;  low, up: BOOLEAN;  
	BEGIN 
		Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  
		IF low THEN 
			RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr, q );  ReorderForLower( cx, cy, cr, q );  
			FillCircleLow( cx, cy, cr, rx, lowy, rw, lowh, q, a, val );  
		END;  
		IF up THEN RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr, q );  FillCircleUp( cx, cy, cr, rx, upy, rw, uph, q, a, val );  END;  
	END FillCircle;  

END CumulativeMatrices.
