MODULE Wedgelets IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Math := MathL IN A2, antsCommands, vyBase, antsArrayObjects, aM := antsMessages, vyName, wedgeTrees, vyGraphBase, 
	vyStrings := vyHostStrings, Oberon, antsArrays, antsArrayPictures16, vyPort, antsPictCoordinate, Objects, 
	antsPictureViews, antsHistogramEdit, antsToolbox, Out, CM := CumulativeMatrices;  

TYPE 
	
	PROCEDURE Min( a, b: SIZE ): SIZE;  
	BEGIN 
		IF a < b THEN RETURN a ELSE RETURN b END;  
	END Min;  

	PROCEDURE Max( a, b: SIZE ): SIZE;  
	BEGIN 
		IF a > b THEN RETURN a ELSE RETURN b END;  
	END Max;  

TYPE 

	LocalRectApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR mean: FLOAT64;   (* mean in the rectangle  *)
	END LocalRectApproximation;  

	
	RectModel*=OBJECT (wedgeTrees.Model)
	VAR 
		sum,sumsq,points: CM.RectSums; 
		useddata-: CM.Array2d;
		
		PROCEDURE PrepareApproximation( data: antsArrayObjects.tLONGREALArray );  
		VAR squares, pts: CM.Array2d;  
		BEGIN 
		useddata := data; 
			IF sum = NIL THEN 
				CM.AllocSame( data^, pts );  CM.AllocSame( data^, squares );  CM.Const( 1, pts^ );  
				CM.Square( data^, squares^ );  NEW( sum, data );  NEW( sumsq, squares );  NEW( points, pts );  
			ELSE 
				CM.Square( data^, sumsq.raw^ );  sum.Init( data );  sumsq.Init( sumsq.raw );  points.Init( points.raw );  
			END;  
		END PrepareApproximation;  

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: LocalRectApproximation;  mean, ssq,nrPoints: FLOAT64;  penalty: FLOAT64; 
		BEGIN 
			IF (w=1) & (h=1) THEN 
				ssq := 0; mean := useddata[y,x]; 
			ELSE
				ssq := sumsq.RectContent(x,y,x+w-1,y+h-1); 
				mean := sum.RectContent(x,y,x+w-1,y+h-1); 
				nrPoints := points.RectContent(x,y,x+w-1,y+h-1); 
				ssq:= ssq- mean * mean / nrPoints; 
				mean := mean/nrPoints; 
			END; 
			IF penaltyadaptive THEN penalty := w* SELF.penalty ELSE penalty := SELF.penalty END; 
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				local := approx( LocalRectApproximation );  
				IF local.distance <= ssq THEN  RETURN END;
			ELSE NEW( local );    
			END;  
			local.mean := mean;  local.distance := ssq;  local.penalty := penalty;  approx := local;  
		END Approximate;  
		
		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR sum1, nrPoints1, sum2, nrPoints2, sum3, nrPoints3: FLOAT64;  x1, y1, x2, y2, i: SIZE;  minl, maxl: SIZE;  
		BEGIN 
			sum3 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints3 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum3 / Math.sqrt( nrPoints3 ) ) > val THEN  RETURN FALSE END;  
			RETURN TRUE;  
		END CheckMRCoefficient;  
		
		PROCEDURE Reconstruct( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR xx, yy: SIZE;  mean: FLOAT64;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 
				mean := approx.mean;  
				FOR yy := y TO y + h - 1 DO 
					FOR xx := x TO x + w - 1 DO reco[yy, xx] := mean;  END;  
				END;  
			END;  
		END Reconstruct;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR xi, yi, wi, hi: SIGNED16;  
			string: ARRAY 64 OF CHAR;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, xi, yi, wi, hi );  vyGraphBase.FrameRect( xi, yi, wi + 1, hi + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (wi > 20) & (hi > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.mean, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( xi + wi DIV 2, yi + hi DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
			END;  
		END Display;  
		
		PROCEDURE & Init*;   (* can be used by implementation to initialize variables etc. *)
		BEGIN 
			 Init^;  penalty := 1; pieces := 1 ; 
		END Init;  

	END RectModel; 
	
	Parameter* = OBJECT (wedgeTrees.Parameter)
	VAR
		dx, dy: SIZE;  
	END Parameter;  
	
	Model* = OBJECT (wedgeTrees.Model)
	VAR sum, sumsq, points: CM.WedgeSums;  
		dx, dy: SIZE;   (* slope of wedges *)
		useddata-: CM.Array2d;   (* cache indicator *)
		keepdata: BOOLEAN;  
		
		PROCEDURE SetLine*( x, y: SIZE );  
		BEGIN 
			dx := x;  dy := y;  
			IF ABS( dx ) >= ABS( dy ) THEN 
				IF dx < 0 THEN dx := -dx;  dy := -dy END;  
			ELSE 
				IF dy < 0 THEN dy := -dy;  dx := -dx END;  
			END;  
		END SetLine;  

		PROCEDURE SetParameters( p: wedgeTrees.Parameter );  
		BEGIN 
			WITH p: Parameter DO SetLine( p.dx, p.dy );  
			END;  
		END SetParameters;  

		PROCEDURE GetParameters( ): wedgeTrees.Parameter;  
		VAR p: Parameter;  
		BEGIN 
			NEW( p );  p.dx := dx;  p.dy := dy;  
			RETURN p;  
		END GetParameters;  

		PROCEDURE PrepareApproximation*( data: CM.Array2d );  
		VAR squares, pts: CM.Array2d;  
		BEGIN 
			IF sum = NIL THEN 
				CM.AllocSame( data^, pts );  CM.AllocSame( data^, squares );  CM.Const( 1, pts^ );  
				CM.Square( data^, squares^ );  NEW( sum, data );  NEW( sumsq, squares );  NEW( points, pts );  
			ELSIF ~keepdata THEN 
				CM.Square( data^, sumsq.raw^ );  sum.Init( data );  sumsq.Init( sumsq.raw );  points.Init( points.raw );  
			END;  
			
			sum.SetAngle( dx, dy );  points.SetAngle( dx, dy );  sumsq.SetAngle( dx, dy );  keepdata := FALSE;  
		END PrepareApproximation;  

	END Model;  
	
	WedgeletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR dx, dy, nr: SIZE;  
		inmean, outmean: FLOAT64;   (* mean in the rectangle  *)
	END WedgeletApproximation;  
	
	WedgeletModel* = OBJECT (Model)
	VAR 

		PROCEDURE FindBestWedge( rx, ry, rw, rh: SIZE;  VAR nr: SIZE;  VAR in, out, ssq: FLOAT64 );  
		(** find piecewise constant segmentation of rectangle (rx,ry,rw,rh) by wedge with slope (dx,dy)  having minimal L2-Distance *)
		VAR minl, maxl, i: SIZE;  min: FLOAT64;  sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3: FLOAT64;  x1, y1, x2, y2: SIZE;  
		BEGIN 
			min := MAX( FLOAT64 );  CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  

			sum3 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq3 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints3 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			
			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					sum1 := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );   (* wedge *)
					ssq1 := sumsq.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					nrPoints1 := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  

					sum2 := sum3 - sum1;  ssq2 := ssq3 - ssq1;  nrPoints2 := nrPoints3 - nrPoints1;   (* rectangle \ wedge *)
					
					IF nrPoints1 > 0 THEN ssq1 := ssq1 - sum1 * sum1 / nrPoints1;  END;  
					IF nrPoints2 > 0 THEN ssq2 := ssq2 - sum2 * sum2 / nrPoints2;  END;  
					
					ssq := ssq1 + ssq2;   (*sum ssq from upper and lower part*)
					IF ssq < min THEN min := ssq;  nr := i;  in := sum1 / nrPoints1;  out := sum2 / nrPoints2;  END;  
				END;  
			END;  
			ssq := min;  
		END FindBestWedge;  

		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR sum1, nrPoints1, sum2, nrPoints2, sum3, nrPoints3: FLOAT64;  x1, y1, x2, y2, i: SIZE;  minl, maxl: SIZE;  
		BEGIN 
			CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  
			sum3 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints3 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum3 / Math.sqrt( nrPoints3 ) ) > val THEN  RETURN FALSE END;  
			
			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					sum1 := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					nrPoints1 := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					
					ASSERT ( nrPoints1 >= 0, 1001 );  
					ASSERT ( nrPoints1 <= rw * rh, 1002 );  
					
					sum2 := sum3 - sum1;  nrPoints2 := nrPoints3 - nrPoints1;   (* outside *)
					
					IF nrPoints1 > 0 THEN 
						sum1 := sum1 / Math.sqrt( nrPoints1 );  
						IF ABS( sum1 ) > val THEN RETURN FALSE END;  
					END;  
					IF nrPoints2 > 0 THEN 
						sum2 := sum2 / Math.sqrt( nrPoints2 );  
						IF ABS( sum2 ) > val THEN  RETURN FALSE END;  
					END;  
				END;  
			END;  
			
			RETURN TRUE;  
		END CheckMRCoefficient;  

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: WedgeletApproximation;  inmean, outmean, ssq: FLOAT64;  nr: SIZE;  
		BEGIN 
			IF (w = 1) OR (h = 1) THEN RETURN END;   (* no segmentation possible *)
			
			FindBestWedge( x, y, w, h, nr, inmean, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( WedgeletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.inmean := inmean;  local.outmean := outmean;  local.nr := nr;  local.dx := dx;  
			local.dy := dy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  reco: CM.Array2d );  
		VAR result: CM.Array2d;  local: WedgeletApproximation;  dx, dy, nr: SIZE;  in, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( WedgeletApproximation );  dx := local.dx;  dy := local.dy;  nr := local.nr;  
			in := local.inmean;  out := local.outmean;  CM.FillRect( result, rx, ry, rw, rh, out );  
			CM.FillWedge( result, dx, dy, nr, rx, ry, rw, rh, in );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  
			string: ARRAY 64 OF CHAR;  
			x1, y1, x2, y2: SIZE;  scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  dx, dy, maxd: FLOAT64;  
		BEGIN 
			WITH approx: WedgeletApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, rx, ry, rw, rh );  vyGraphBase.FrameRect( rx, ry, rw + 1, rh + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (rw > 20) & (rh > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.inmean, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( rx + rw DIV 2, ry + rh DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
				vyGraphBase.Rect2dToRect( 0, 0, 100, 100, scalex, scaley, scalew, scaleh );  
				IF scalew # scaleh THEN RETURN END;   (* kept aspect ratio 1:1 ? *)
				scalefactor := scalew / 100;  
				IF ABS( approx.dx ) > ABS( approx.dy ) THEN maxd := ABS( approx.dx ) ELSE maxd := ABS( approx.dy ) END;  
				
				IF CM.LineRectIntersect( approx.dx, approx.dy, approx.nr, x, y, w, h, x1, y1, x2, y2 ) THEN  (*! use intersection in transformed coordinate system *)
					dx := approx.dx;  dy := approx.dy;  dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (x1 > x2) THEN dx := -dx;  END;  
					IF (y1 > y2) THEN dy := -dy;  END;  
					
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  
					vyGraphBase.Line2d( x1 + 1 / 2 - dx, y1 + 1 / 2 - dy, x2 + 1 / 2 + dx, y2 + 1 / 2 + dy );  
				END;  
			
			END;  
		END Display;  

		PROCEDURE & Init;  
		BEGIN 
			Init^;  
			useddata := NIL;  penalty := 2;  pieces := 2;   (* reset cache indicator *)
		END Init;  

	END WedgeletModel;  

TYPE 
	
	BleatletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR dx, dy, nr1, nr2: SIZE;  
		mean1, mean2, outmean: FLOAT64;   (* mean in the rectangle  *)
	END BleatletApproximation;  
	
	BleatletModel* = OBJECT (Model)
	VAR ssqa, suma, pointsa: POINTER TO ARRAY OF FLOAT64;  
		minwidth, maxwidth: SIZE;  
		
		PROCEDURE FindBestWedges( rx, ry, rw, rh: SIZE;  VAR nr1, nr2: SIZE;  VAR in1, in2, out, ssq: FLOAT64 );  
		(** find piecewise constant segmentation of rectangle (rx,ry,rw,rh) by two parallel wedges with slope (dx,dy)  having minimal L2-Distance *)
		VAR minl, maxl, i, j: SIZE;  min: FLOAT64;  sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  
			x1, y1, x2, y2: SIZE;  start, stop: SIZE;  
		BEGIN 
			
			min := MAX( FLOAT64 );  CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxl - minl + 1) THEN 
				NEW( ssqa, maxl - minl + 1 );  NEW( suma, maxl - minl + 1 );  NEW( pointsa, maxl - minl + 1 );  
			END;  
			
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq4 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			
			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					ssqa[i - minl] := sumsq.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					suma[i - minl] := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					pointsa[i - minl] := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
				ELSE ssqa[i - minl] := 0;  suma[i - minl] := 0;  pointsa[i - minl] := 0;  
				END;  
			END;  
			
			FOR i := minl TO maxl DO 
				ssq1 := ssqa[i - minl];  sum1 := suma[i - minl];  nrPoints1 := pointsa[i - minl];   (* lower wedge *)
				IF nrPoints1 > 0 THEN 
					
					IF (ABS( dx ) >= ABS( dy )) OR (dx < 0) THEN start := i + minwidth;  stop := Min( maxl, i + maxwidth );  
					ELSE start := Max( minl, i - maxwidth );  stop := i - minwidth;  
					END;  
					
					FOR j := start TO stop DO 

						ssq2 := ssqa[j - minl];  sum2 := suma[j - minl];  nrPoints2 := pointsa[j - minl];   (* upper wedge *)
						IF (nrPoints2 > 0) THEN 
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;  ssq3 := ssq4 - ssq2;   (* background *)
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;  ssq2 := ssq2 - ssq1;   (* upper wedge again *)
							ASSERT ( ENTIER( nrPoints1 + nrPoints2 + nrPoints3 + 0.5 ) = rw * rh, 1005 );  
							ssq := 0;  
							IF nrPoints1 > 0 THEN ssq := ssq + ssq1 - sum1 * sum1 / nrPoints1;  END;  
							IF nrPoints2 > 0 THEN ssq := ssq + ssq2 - sum2 * sum2 / nrPoints2;  END;  
							IF nrPoints3 > 0 THEN ssq := ssq + ssq3 - sum3 * sum3 / nrPoints3;  END;  
							(*
											ASSERT ( ssq >= 0, 1010 );  
							ASSERT ( ssq1 >= 0, 1011 );  
							ASSERT ( ssq2 >= 0, 1012 );  
							ASSERT ( ssq3 >= 0, 1013 );  
							
						*) 
							
							IF ssq < min THEN 
								min := ssq;  nr1 := i;  nr2 := j;  in1 := sum1 / nrPoints1;  in2 := sum2 / nrPoints2;  
								out := sum3 / nrPoints3;  
							END;  
						
						END;  
					END;  
				
				END;  
			END;  
			
			ssq := min;  
		
		END FindBestWedges;  
		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
			(** find piecewise constant segmentation of rectangle (rx,ry,rw,rh) by two parallel wedges with slope (dx,dy)  having minimal L2-Distance *)
		VAR minl, maxl, i, j: SIZE;  min: FLOAT64;  sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  
			x1, y1, x2, y2: SIZE;  start, stop: SIZE;  
		BEGIN 
			
			CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxl - minl + 1) THEN 
				NEW( ssqa, maxl - minl + 1 );  NEW( suma, maxl - minl + 1 );  NEW( pointsa, maxl - minl + 1 );  
			END;  
			
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum4 / Math.sqrt( nrPoints4 ) ) > val THEN  RETURN FALSE END;  

			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					suma[i - minl] := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					pointsa[i - minl] := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
				ELSE suma[i - minl] := 0;  pointsa[i - minl] := 0;  
				END;  
			END;  
			
			FOR i := minl TO maxl DO 
				sum1 := suma[i - minl];  nrPoints1 := pointsa[i - minl];   (* lower wedge *)
				IF nrPoints1 > 0 THEN 
					
					IF (ABS( dx ) >= ABS( dy )) OR (dx < 0) THEN start := i + minwidth;  stop := Min( maxl, i + maxwidth );  
					ELSE start := Max( minl, i - maxwidth );  stop := i - minwidth;  
					END;  
					
					FOR j := start TO stop DO 

						sum2 := suma[j - minl];  nrPoints2 := pointsa[j - minl];   (* upper wedge *)
						IF (nrPoints2 > 0) THEN 
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;     (* background *)
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;     (* upper wedge again *)
							ASSERT ( ENTIER( nrPoints1 + nrPoints2 + nrPoints3 + 0.5 ) = rw * rh, 1005 );  
							IF nrPoints1 > 0 THEN 
						sum1 := sum1 / Math.sqrt( nrPoints1 );  
						IF ABS( sum1 ) > val THEN RETURN FALSE END;  
					END;  
					IF nrPoints2 > 0 THEN 
						sum2 := sum2 / Math.sqrt( nrPoints2 );  
						IF ABS( sum2 ) > val THEN  RETURN FALSE END;  
					END;  
					IF nrPoints3 > 0 THEN 
						sum3 := sum3 / Math.sqrt( nrPoints2 );  
						IF ABS( sum3 ) > val THEN  RETURN FALSE END;  
					END;  
							
						END;  
					END;  
				
				END;  
			END;  
			RETURN TRUE; 

		END CheckMRCoefficient; 
		
		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: BleatletApproximation;  mean1, mean2, outmean, ssq: FLOAT64;  nr1, nr2: SIZE;  
		BEGIN 
			IF (w = 1) OR (h = 1) THEN RETURN END;   (* no segmentation possible *)
			
			
			FindBestWedges( x, y, w, h, nr1, nr2, mean1, mean2, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( BleatletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.mean1 := mean1;  local.mean2 := mean2;  local.outmean := outmean;  
			local.nr1 := nr1;  local.nr2 := nr2;  local.dx := dx;  local.dy := dy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  reco: CM.Array2d );  
		VAR result: CM.Array2d;  local: BleatletApproximation;  dx, dy, nr1, nr2: SIZE;  in1, in2, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( BleatletApproximation );  dx := local.dx;  dy := local.dy;  nr1 := local.nr1;  
			nr2 := local.nr2;  in1 := local.mean1;  in2 := local.mean2;  out := local.outmean;  
			CM.FillRect( result, rx, ry, rw, rh, out );  CM.FillWedge( result, dx, dy, nr2, rx, ry, rw, rh, in2 );  
			CM.FillWedge( result, dx, dy, nr1, rx, ry, rw, rh, in1 );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  
			string: ARRAY 64 OF CHAR;  
			x1, y1, x2, y2: SIZE;  scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  dx, dy, maxd: FLOAT64;  
		BEGIN 
			WITH approx: BleatletApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, rx, ry, rw, rh );  vyGraphBase.FrameRect( rx, ry, rw + 1, rh + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (rw > 20) & (rh > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.mean1, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( rx + rw DIV 2, ry + rh DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
				vyGraphBase.Rect2dToRect( 0, 0, 100, 100, scalex, scaley, scalew, scaleh );  

				scalefactor := scalew / 100;  
				IF ABS( approx.dx ) > ABS( approx.dy ) THEN maxd := ABS( approx.dx ) ELSE maxd := ABS( approx.dy ) END;  
				
				IF CM.LineRectIntersect( approx.dx, approx.dy, approx.nr1, x, y, w, h, x1, y1, x2, y2 ) THEN  (*! use intersection in transformed coordinate system *)
					dx := approx.dx;  dy := approx.dy;  

					dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (x1 > x2) THEN dx := -dx;  END;  
					IF (y1 > y2) THEN dy := -dy;  END;  
					
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  
					vyGraphBase.Line2d( x1 + 1 / 2 - dx, y1 + 1 / 2 - dy, x2 + 1 / 2 + dx, y2 + 1 / 2 + dy );  
				END;  
				
				IF CM.LineRectIntersect( approx.dx, approx.dy, approx.nr2, x, y, w, h, x1, y1, x2, y2 ) THEN  (*! use intersection in transformed coordinate system *)
					dx := approx.dx;  dy := approx.dy;  

					dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (x1 > x2) THEN dx := -dx;  END;  
					IF (y1 > y2) THEN dy := -dy;  END;  
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  
					vyGraphBase.Line2d( x1 + 1 / 2 - dx, y1 + 1 / 2 - dy, x2 + 1 / 2 + dx, y2 + 1 / 2 + dy );  
				END;  
			
			END;  
		END Display;  

		PROCEDURE SetWidth( min, max: SIZE );  
		BEGIN 
			minwidth := min;  maxwidth := max;  
			IF minwidth < 1 THEN minwidth := 1 END;  
			IF maxwidth < 1 THEN maxwidth := 1 END;  
		END SetWidth;  

		PROCEDURE & Init;  
		BEGIN 
			Init^;  
			useddata := NIL;  penalty := 3;  pieces := 3;   (* reset cache indicator *)
			minwidth := 1;  maxwidth := 10000;  
		END Init;  

	END BleatletModel;  
	
	BeamletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR dx, dy, nr1, nr2: SIZE;  
		inmean, outmean: FLOAT64;   (* mean in the rectangle  *)
	END BeamletApproximation;  
	
	BeamletModel* = OBJECT (Model)
	VAR ssqa, suma, pointsa: POINTER TO ARRAY OF FLOAT64;  
		minwidth, maxwidth: SIZE;  
		
		PROCEDURE FindBestBeam( rx, ry, rw, rh: SIZE;  VAR nr1, nr2: SIZE;  VAR in, out, ssq: FLOAT64 );  
		VAR minl, maxl, i, j: SIZE;  min: FLOAT64;  sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  
			x1, y1, x2, y2: SIZE;  start, stop: SIZE;  
		BEGIN 
			min := MAX( FLOAT64 );  CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxl - minl + 1) THEN 
				NEW( ssqa, maxl - minl + 1 );  NEW( suma, maxl - minl + 1 );  NEW( pointsa, maxl - minl + 1 );  
			END;  
			
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq4 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );   (* rectangle *)
			
			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					ssqa[i - minl] := sumsq.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					suma[i - minl] := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					pointsa[i - minl] := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
				ELSE ssqa[i - minl] := 0;  suma[i - minl] := 0;  pointsa[i - minl] := 0;  
				END;  
			END;  
			
			FOR i := minl TO maxl DO 
				ssq1 := ssqa[i - minl];  sum1 := suma[i - minl];  nrPoints1 := pointsa[i - minl];   (* lower wedge *)
				IF nrPoints1 > 0 THEN 
					IF (ABS( dx ) >= ABS( dy )) OR (dx < 0) THEN start := i + minwidth;  stop := Min( maxl, i + maxwidth );  
					ELSE start := Max( minl, i - maxwidth );  stop := i - minwidth;  
					END;  
					
					FOR j := start TO stop DO 
						ssq2 := ssqa[j - minl];  sum2 := suma[j - minl];  nrPoints2 := pointsa[j - minl];   (* upper wedge *)
						IF (nrPoints2 > 0) THEN 
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;  ssq2 := ssq2 - ssq1;   (*  between upper and lower wedge*)
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;  ssq3 := ssq4 - ssq2;   (*  background *)
							
							ASSERT ( ENTIER( nrPoints2 + nrPoints3 + 0.5 ) = rw * rh, 1005 );  
							ssq := 0;  
							IF nrPoints2 > 0 THEN ssq := ssq + ssq2 - sum2 * sum2 / nrPoints2;  END;  
							IF nrPoints3 > 0 THEN ssq := ssq + ssq3 - sum3 * sum3 / nrPoints3;  END;  
							ASSERT ( ssq >= 0, 1010 );  
							ASSERT ( ssq2 >= 0, 1012 );  
							ASSERT ( ssq3 >= 0, 1013 );  
							
							IF ssq < min THEN min := ssq;  nr1 := i;  nr2 := j;  in := sum2 / nrPoints2;  out := sum3 / nrPoints3;  
							END;  
						
						END;  
					END;  
				
				END;  
			END;  
			ssq := min;  
		END FindBestBeam;  
		
		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR minl, maxl, i, j: SIZE;  min: FLOAT64;  sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  
			x1, y1, x2, y2: SIZE;  start, stop: SIZE;  
		BEGIN 
			CM.IntersectingLines( dx, dy, rx, ry, rw, rh, minl, maxl );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxl - minl + 1) THEN 
				NEW( ssqa, maxl - minl + 1 );  NEW( suma, maxl - minl + 1 );  NEW( pointsa, maxl - minl + 1 );  
			END;  
			
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );   (* rectangle *)
			IF ABS( sum4 / Math.sqrt( nrPoints4 ) ) > val THEN  RETURN FALSE END;  

			FOR i := minl TO maxl DO 
				IF sum.LineRectIntersect( dx, dy, i, rx, ry, rw, rh, x1, y1, x2, y2 ) THEN 
					ssqa[i - minl] := sumsq.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					suma[i - minl] := sum.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
					pointsa[i - minl] := points.WedgeContent( rx, ry, rw, rh, x1, y1, x2, y2 );  
				ELSE ssqa[i - minl] := 0;  suma[i - minl] := 0;  pointsa[i - minl] := 0;  
				END;  
			END;  
			
			FOR i := minl TO maxl DO 
				sum1 := suma[i - minl];  nrPoints1 := pointsa[i - minl];   (* lower wedge *)
				IF nrPoints1 > 0 THEN 
					IF (ABS( dx ) >= ABS( dy )) OR (dx < 0) THEN start := i + minwidth;  stop := Min( maxl, i + maxwidth );  
					ELSE start := Max( minl, i - maxwidth );  stop := i - minwidth;  
					END;  
					
					FOR j := start TO stop DO 
						sum2 := suma[j - minl];  nrPoints2 := pointsa[j - minl];   (* upper wedge *)
						IF (nrPoints2 > 0) THEN 
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;     (*  between upper and lower wedge*)
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;     (*  background *)
							
							ASSERT ( ENTIER( nrPoints2 + nrPoints3 + 0.5 ) = rw * rh, 1005 );  
							
							IF nrPoints2 > 0 THEN 
						sum2 := sum2 / Math.sqrt( nrPoints2 );  
						IF ABS( sum2 ) > val THEN  RETURN FALSE END;  
					END;  
					IF nrPoints3 > 0 THEN 
						sum3 := sum3 / Math.sqrt( nrPoints2 );  
						IF ABS( sum3 ) > val THEN  RETURN FALSE END;  
					END;  

						
						END;  
					END;  
				
				END;  
			END;  
			RETURN TRUE;  
		END CheckMRCoefficient; 

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: BeamletApproximation;  inmean, outmean, ssq: FLOAT64;  nr1, nr2: SIZE;  
		BEGIN 
			IF (w = 1) OR (h = 1) THEN RETURN END;   (* no segmentation possible *)
			
			
			FindBestBeam( x, y, w, h, nr1, nr2, inmean, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( BeamletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.inmean := inmean;  local.outmean := outmean;  local.nr1 := nr1;  local.nr2 := nr2;  
			local.dx := dx;  local.dy := dy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  reco: CM.Array2d );  
		VAR result: CM.Array2d;  local: BeamletApproximation;  dx, dy, nr1, nr2: SIZE;  in, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( BeamletApproximation );  dx := local.dx;  dy := local.dy;  nr1 := local.nr1;  
			nr2 := local.nr2;  in := local.inmean;  out := local.outmean;  CM.FillRect( result, rx, ry, rw, rh, out );  
			CM.FillWedge( result, dx, dy, nr2, rx, ry, rw, rh, in );  CM.FillWedge( result, dx, dy, nr1, rx, ry, rw, rh, out );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  
			string: ARRAY 64 OF CHAR;  
			x1, y1, x2, y2: SIZE;  scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  dx, dy, maxd: FLOAT64;  
		BEGIN 
			WITH approx: BeamletApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, rx, ry, rw, rh );  vyGraphBase.FrameRect( rx, ry, rw + 1, rh + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (rw > 20) & (rh > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.inmean, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( rx + rw DIV 2, ry + rh DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
				vyGraphBase.Rect2dToRect( 0, 0, 100, 100, scalex, scaley, scalew, scaleh );  

				scalefactor := scalew / 100;  
				IF ABS( approx.dx ) > ABS( approx.dy ) THEN maxd := ABS( approx.dx ) ELSE maxd := ABS( approx.dy ) END;  
				
				IF CM.LineRectIntersect( approx.dx, approx.dy, approx.nr1, x, y, w, h, x1, y1, x2, y2 ) THEN  (*! use intersection in transformed coordinate system *)
					dx := approx.dx;  dy := approx.dy;  

					dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (x1 > x2) THEN dx := -dx;  END;  
					IF (y1 > y2) THEN dy := -dy;  END;  
					
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  
					vyGraphBase.Line2d( x1 + 1 / 2 - dx, y1 + 1 / 2 - dy, x2 + 1 / 2 + dx, y2 + 1 / 2 + dy );  
				END;  
				
				IF CM.LineRectIntersect( approx.dx, approx.dy, approx.nr2, x, y, w, h, x1, y1, x2, y2 ) THEN  (*! use intersection in transformed coordinate system *)
					dx := approx.dx;  dy := approx.dy;  

					dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (x1 > x2) THEN dx := -dx;  END;  
					IF (y1 > y2) THEN dy := -dy;  END;  
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  
					vyGraphBase.Line2d( x1 + 1 / 2 - dx, y1 + 1 / 2 - dy, x2 + 1 / 2 + dx, y2 + 1 / 2 + dy );  
				END;  
			
			END;  
		END Display;  

		PROCEDURE SetWidth( min, max: SIZE );  
		BEGIN 
			minwidth := min;  maxwidth := max;  
			IF minwidth < 1 THEN minwidth := 1 END;  
			IF maxwidth < 1 THEN maxwidth := 1 END;  
		END SetWidth;  

		PROCEDURE & Init;  
		BEGIN 
			Init^;  
			useddata := NIL;  penalty := 2.5;  pieces := 3;   (* reset cache indicator *)
			minwidth := 1;  maxwidth := 10000;  
		END Init;  

	END BeamletModel;  
	
	PROCEDURE NewRectModel*;  
	VAR m: RectModel;  
		name: ARRAY 256 OF CHAR;  
		dx, dy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name )  THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );    
		END;  
	END NewRectModel;  
	
	PROCEDURE NewWedgeletModel*;  
	VAR m: WedgeletModel;  
		name: ARRAY 256 OF CHAR;  
		dx, dy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "dx", dx ) & 
		    antsCommands.ExpectSize( "dy", dy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetLine( dx, dy );  
		END;  
	END NewWedgeletModel;  

	PROCEDURE NewBleatletModel*;  
	VAR m: BleatletModel;  
		name: ARRAY 256 OF CHAR;  
		dx, dy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "dx", dx ) & 
		    antsCommands.ExpectSize( "dy", dy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetLine( dx, dy );  
		END;  
	END NewBleatletModel;  

	PROCEDURE NewBeamletModel*;  
	VAR m: BeamletModel;  
		name: ARRAY 256 OF CHAR;  
		dx, dy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "dx", dx ) & 
		    antsCommands.ExpectSize( "dy", dy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetLine( dx, dy );  
		END;  
	END NewBeamletModel;  

	PROCEDURE SetWidth*;  
	VAR obj: vyBase.Object;  min, max: SIZE;  
	BEGIN 
		antsCommands.InitScan( "model=OBJECT min=NUMBER max=NUMBER" );  
		IF antsCommands.ExpectObject( "model", obj ) & antsCommands.ExpectSize( "min", min ) & 
		    antsCommands.ExpectSize( "max", max ) THEN 
			WITH obj: BleatletModel DO obj.SetWidth( min, max );  aM.SISI( "Ok, set ", min, "<= width <=", max );  
			| obj: BeamletModel DO obj.SetWidth( min, max );  aM.SISI( "Ok, set ", min, "<= width <=", max );  
			END;  
		END;  
	END SetWidth;  

	PROCEDURE PlugInWith*;  
	VAR x, y: SIZE;  from, to, by, angle: FLOAT64;  tree, model: vyBase.Object;  time: SIZE;  mode: SIGNED16;  
	BEGIN 
		
		time := Oberon.Time();  antsCommands.InitScan( "tree=Obj model=Obj fromx=Number fromy=Number tox=Number toy=Number byx=Number byy=Number" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) & 
		    antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				WITH model: Model DO 
					ASSERT ( by > 0 );  
					
					angle := from;  
					WHILE (angle <= to) DO 
						aM.SR( "angle=", angle );  y := ENTIER( Math.sin( Math.pi * angle / 180 ) * 1000 );  
						x := ENTIER( Math.cos( Math.pi * angle / 180 ) * 1000 );  
						
						mode := aM.mode;  aM.mode := aM.errorMode;  
						model.SetLine( x, y );  tree.PlugIn( model, "WedgeModel", MAX( SIZE ) );   model.keepdata := TRUE;  aM.mode := mode;  
						angle := angle + by;  
					END;  
				END;  
				aM.S( "done." );  
			END;  
		END;  
		aM.SI( "Time = ", Oberon.Time() - time );  
	END PlugInWith;  
	
		PROCEDURE GreatestDivisorPower2( i: SIZE ): SIZE;  
	VAR j, k: SIZE;  
	BEGIN 
		j := 1;  k := 0;  
		WHILE ((i DIV j) * j = i) DO INC( k );  j := j * 2;  END;  
		RETURN k;  
	END GreatestDivisorPower2;  

	PROCEDURE PlugInAdaptive*;
	VAR x, y: SIZE;  from, to, by, angle: FLOAT64;  tree, model: vyBase.Object;  time: SIZE;  mode: SIGNED16;  depth,i,iterations,offset: SIZE; depthc: ARRAY 32 OF SIZE; 
	BEGIN
			time := Oberon.Time();  antsCommands.InitScan( "tree=Obj model=Obj" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model )  THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				WITH model: Model DO 
					Out.String("Adaptive Plugin, angles = "); 
					IF ~ antsCommands.GetSize("angles",iterations) THEN 
					iterations := Max(tree.w,tree.h); 
					END; 
					IF ~antsCommands.GetSize("offset",offset) THEN 
						offset := 1
					END; 
					Out.Int(SIGNED32(iterations),0); Out.String(":"); 
					FOR i := 1 TO iterations DO 
						Out.String("."); 
						angle := 180 / iterations*i; (* aM.SR( "setting angle: ", angle );*)   y := ENTIER( Math.sin( Math.pi * angle / 180 ) * 1000 ); 
						x := ENTIER( Math.cos( Math.pi * angle / 180 ) * 1000 );  model.SetLine( x, y ); 
						depth := GreatestDivisorPower2( i )+offset ;  (*aM.SI( "with max depth:", depth );*)   tree.PlugIn( model, "AdaptiveWedgeModel", depth ); model.keepdata := TRUE; 
						INC(depthc[depth]); 
					END; 
					Out.Ln; 
					(*
					FOR i := 0 TO 31 DO
						aM.SISI("depth: ",i," frequency:",depthc[i]); 
					END; 
					*) 
				END;  
				aM.S( "done." );  
			END;  
		END;  
		aM.SI( "Time = ", Oberon.Time() - time );  

	END PlugInAdaptive;



END Wedgelets.

Wedgelets.RoundTest ~
System.Free Wedgelets CumulativeMatrices wedgeTrees  ~
fofAutomatic.Do
Oberon.RefreshDisplay
Wedgelets.CheckIntersect 0 0 110 100 100 200 200  ~
~
Wedgelets.RoundTest ~
antsExpressions.Install
Wedgelets.CheckIntersect 752 928 110 100 100 200 200  ~
Wedgelets.CheckIntersect 17 58  110 100 100 200 200  ~
Wedgelets.CheckIntersect 17 0 110 100 100 200 200  ~

antsArrayObjects.LoadDialogedP2 testarrayint6 > show ~
Arclets.IntToReal src=testarrayint6 dest=testarray ~
Wedgelets.TryBestWedge testarray 1000 1100 32 32 32 32 ~
~
Wedgelets.TrySumup testarray 100 110 ~

Wedgelets.NewWedgeletModel wedgeModel 100 100 ~
Wedgelets.NewBleatletModel wedgeModel -100 100 ~
Wedgelets.NewBeamletModel wedgeModel 110 100 ~
Wedgelets.NewRectModel rectModel ~

Wedgelets.SetWidth wedgeModel 1 1  ~

fofAutomatic.Do 
Wedgelets.ApplyMR tree=myTree ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ToArray tree=myTree destI=resultI ~
~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=1 ~

fofAutomatic.Do 
wedgeTrees.ApplyMR tree=myTree ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ToArray tree=myTree destI=resultI ~
~
wedgeCommands.PlugIn tree=myTree model=rectModel ~

wedgeCommands.PlugIn tree=myTree model=wedgeModel ~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=45 ~

fofAutomatic.Do
wedgeNumOps.AddGaussNoise testarray noisyarray var=1000 ~
wedgeCommands.RealToInt noisyarray noisyarrayI ~
wedgeCommands.Show array=noisyarrayI tree=NIL~
~
fofAutomatic.Do 
wedgeCommands.NewTree src=noisyarray dest=myTree   ~
Wedgelets.NewRectModel rectModel ~
wedgeCommands.PlugIn tree=myTree model=rectModel ~
~
Wedgelets.NewWedgeletModel wedgeModel 100 0 ~
Wedgelets.PlugInAdaptive myTree wedgeModel ~
~
Wedgelets.NewBleatletModel wedgeModel 100 100 ~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=1 ~
Wedgelets.NewWedgeletModel wedgeModel 100 100 ~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=1 ~
Wedgelets.NewBeamletModel wedgeModel 100 100 ~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=0.1 ~
Arclets.NewArcletModel arcModel 0 0 ~
Arclets.PlugInWith myTree arcModel 0 0 128 128 4 4  ~
Arclets.NewRingletModel arcModel 0 0 ~
Arclets.PlugInWith myTree arcModel 0 0 128 128 4 4  ~
Arclets.NewCircletModel arcModel 0 0 ~
Arclets.PlugInWith myTree arcModel 0 0 128 128 4 4  ~
~

Arclets.NewRingletModel arcModel 0 0 ~
Arclets.PlugInWith myTree arcModel 0 0 128 128 8 8  ~
~

fofAutomatic.Do (* multiresolution criterion *) 
wedgeTrees.ApplyMR tree=myTree factor=2.5 ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ToArray tree=myTree destI=resultI ~
wedgeCommands.ComputePSNR src1=testarray src2=resultR~
wedgeNumOps.PSNR testarray resultR psnr ~
~

fofAutomatic.Do
wedgeNumOps.NewVec factorvec ~
wedgeNumOps.NewVec psnrvec ~
wedgeNumOps.NewReal factor ~
wedgeNumOps.Add factor 0.2
wedgeNumOps.NewReal tolerance ~
~
fofAutomatic.Do >iter  40 
wedgeTrees.ApplyMR tree=myTree factor= factor ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ComputePSNR src1=testarray src2=resultR~
wedgeNumOps.PSNR testarray resultR psnr ~
WedgeNumOps.Append psnr psnrvec ~
WedgeNumOps.Append factor factorvec ~
wedgeNumOps.Add factor 0.1 ~
wedgeCommands.RealToInt resultR resultI ~
~
fofAutomatic.Do
wedgeNumOps.ShowVec vecx=factorvec vecy=psnrvec  port=View1 >forcenew ~
vyScale.Insert
~
dyadic rects 
rects +aw 
rects + aw + abl 
rects+aw+c8
 

~
fofAutomatic.Do
wedgeNumOps.NewVec factorvec ~
wedgeNumOps.NewVec psnrvec ~
wedgeNumOps.NewReal factor ~
wedgeNumOps.Add factor -5
wedgeNumOps.NewReal tolerance ~
~
fofAutomatic.Do >iter  80 
wedgeCommands.Minimize tree=myTree loggamma= factor ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ComputePSNR src1=testarray src2=resultR~
wedgeNumOps.PSNR testarray resultR psnr ~
WedgeNumOps.Append psnr psnrvec ~
WedgeNumOps.Append factor factorvec ~
wedgeNumOps.Add factor 0.1 ~
~
fofAutomatic.Do
wedgeNumOps.ShowVec vecx=factorvec vecy=psnrvec  port=View1 >forcenew ~
vyScale.Insert
~
noise=1000, bird 128x128
rechteck + 0,45,90,135

rechteck

rechteck+adaptive

	
rechteck+adaptive+arclets (8)


Voyager.WriteData factorvec 

fofAutomatic.Do ~ (* theoretically best segmentation choosing local regression model *) 
wedgeCommands.MinimizeDistTo tree=myTree to=testarray ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ToArray tree=myTree destI=resultI ~
wedgeCommands.ComputePSNR src1=testarray src2=resultR~
~
wedgeNumOps.FindOptPSNRFast tree=myTree from=-10 to=10 precision =0.0001 src=testarray ~ (* optimal psnr with complexity penalized functional *) 
~

fofAutomatic.Do ~ (* gamma loop *) 
wedgeNumOps.GetDimensions testarray w h ~
wedgeNumOps.NewConstantArray constarrayi w h  value=128~
wedgeCommands.IntToReal src=constarrayi dest=constarrayr~
wedgeNumOps.AddGaussNoise source=constarrayr dest=constarrayr var=1 ~
wedgeCommands.NewTree src=constarrayr tree=constTree ~
wedgeTrees.PlugInFromTree from=myTree to=constTree ~
wedgeNumOps.ClearVec gammavec ~
wedgeNumOps.ClearVec piecesvec ~
wedgeNumOps.ClearVec gammavecflat ~
wedgeNumOps.ClearVec piecesvecflat ~
wedgeNumOps.LogGammaVectors tree=myTree from=-7  to=5 by=0.05 gamma=gammavec pieces=piecesvec  ~
wedgeNumOps.LogGammaVectors tree=constTree from=-7 to=5 by=0.05 gamma=gammavecflat pieces=piecesvecflat ~
wedgeNumOps.Log10 piecesvec ~
wedgeNumOps.Log10 gammavec~
wedgeNumOps.Log10 piecesvecflat ~
wedgeNumOps.Log10 gammavecflat~
wedgeNumOps.NewReal gammaopt1~
wedgeNumOps.NewReal gammaPSNR ~
wedgeNumOps.NewReal PSNRopt1 ~
wedgeNumOps.NewReal PSNRopt3 ~
wedgeNumOps.NewReal shift ~
wedgeNumOps.Translate srcx=gammavec srcy=piecesvec noisex=gammavecflat noisey=piecesvecflat tolerance=0.1  by= 0.05  length=4  src= testarray tree=myTree PSNRlogf=PSNRopt1 gammalogf=gammaopt1 shift=shift~
wedgeCommands.Minimize tree=myTree gamma=gammaopt1 >loggamma ~
wedgeCommands.ToArray tree =myTree destR = resultR ~
wedgeCommands.RealToInt resultR resultI ~
~
wedgeNumOps.ShowVec vecx=gammavec vecy=piecesvec  port=View1>forcenew ~
vyScale.Insert 
wedgeNumOps.ShowVec vecx=gammavecflat vecy=piecesvecflat  port=View1>forcenew ~
vyScale.Insert
~
wedgeCommands.Minimize constTree 0.0001 ~
wedgeCommands.ToArray tree=constTree destI=resultCI ~
wedgeCommands.Show array=resultCI tree=constTree ~

wedge/wedge.Tool 


 (log) 

fofAutomatic.Do 
System.Time
antsMessages.SetMode errors
wedgeCommands.PlugInCWedge  tree=myTree model=wedgeModelY  >steps from=0  to=180  by=1 ~
antsMessages.SetMode  normal ~
System.Time 
~
antsMessages.SetMode normal ~

fofAutomatic.Do 
wedgeCommands.NewTree src=noisyarray dest=myTree   ~
wedgeCommands.NewConstRectModel model=rectModel ~
wedgeCommands.PlugIn tree=myTree model=rectModel ~
wedgeCommands.ToArrayMR tree=myTree destI=resultI ~
~
~
fofAutomatic.Do
wedgeNumOps.AddGaussNoise testarray noisyarray var=300 ~
wedgeCommands.RealToInt noisyarray noisyarrayI ~
wedgeCommands.Show array=noisyarrayI tree=NIL~
~
fofAutomatic.Do 
wedgeCommands.NewTree src=noisyarray dest=myTree   ~
Wedgelets.NewWedgeletModel wedgeModel 100 110 ~
Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=1 ~
~
fofAutomatic.Do 
wedgeTrees.ApplyMR tree=myTree ~
wedgeCommands.ToArray tree=myTree destR=resultR ~
wedgeCommands.ToArray tree=myTree destI=resultI ~
~




wedgeCommands.ComputePSNR src1=testarray src2=resultR~
wedgeNumOps.ConserveImage resultI  ~

fofAutomatic.Do ~
 
	
	wedgeNumOps.NewReal from ~
	wedgeNumOps.NewReal to ~
	wedgeNumOps.NewReal by ~
	wedgeNumOps.NewReal tolerance ~
	wedgeNumOps.Add from -7 ~
	wedgeNumOps.Add to 5 ~
	wedgeNumOps.Add by 0.05 ~
	wedgeNumOps.Add tolerance 0.1 ~

	wedgeNumOps.NewConstantArray constarrayinto 128 128 value=128~
	
	wedgeCommands.IntToReal src=constarrayinto dest=constarrayo~
	wedgeNumOps.AddGaussNoise source=constarrayo dest=constarray var=1 ~
	wedgeNumOps.AddGaussNoise src=testarray dest=noisedarray var=500 ~
	wedgeCommands.RealToInt noisedarray noisedarrayI ~
	wedgeCommands.RealToInt constarray constarrayI ~

	wedgeCommands.Show array=noisedarrayI tree=NIL~
	wedgeCommands.Show array=constarrayI tree=NIL~
	
	wedgeCommands.NewTree src=noisedarray tree=myTree   ~ 
	wedgeCommands.NewTree src=constarray tree=myTree1   ~ 
	
	Wedgelets.NewWedgeletModel wedgeModel 100 110 ~
	Wedgelets.PlugInWith myTree wedgeModel from=0 to=180 by=1 ~
	Wedgelets.NewWedgeletModel wedgeModel 100 110 ~
	Wedgelets.PlugInWith myTree1 wedgeModel from=0 to=180 by=1 ~


	wedgeNumOps.ClearVec gammavec ~
	wedgeNumOps.ClearVec piecesvec ~
	wedgeNumOps.ClearVec gammavecflat ~
	wedgeNumOps.ClearVec piecesvecflat ~

	wedgeNumOps.LogGammaVectors tree=myTree from=from  to=to by=by gamma=gammavec pieces=piecesvec  ~
	wedgeNumOps.LogGammaVectors tree=myTree1 from=from to=to by=by gamma=gammavecflat pieces=piecesvecflat ~
	
	
	wedgeNumOps.Log10 piecesvec ~
	wedgeNumOps.Log10 gammavec~
	wedgeNumOps.Log10 piecesvecflat ~
	wedgeNumOps.Log10 gammavecflat~
	
	wedgeNumOps.ShowVec vecx=gammavec vecy=piecesvec  port=View1>forcenew ~
	wedgeNumOps.ShowVec vecx=gammavecflat vecy=piecesvecflat  port=View1>forcenew ~



	wedgeNumOps.NewReal gammaopt1~
	wedgeNumOps.NewReal gammaPSNR ~
	wedgeNumOps.NewReal PSNRopt1 ~
	wedgeNumOps.NewReal PSNRopt3 ~
	wedgeNumOps.NewReal shift ~
	
	wedgeNumOps.Translate srcx=gammavec srcy=piecesvec noisex=gammavecflat noisey=piecesvecflat tolerance=tolerance  by= by  length=4  src= testarray tree=myTree PSNRlogf=PSNRopt1 gammalogf=gammaopt1 shift=shift~
	
	wedgeCommands.Minimize tree=myTree gamma=gammaopt1 >loggamma ~
	wedgeCommands.ToArray tree =myTree destR = resultR ~
	wedgeCommands.RealToInt resultR resultI ~
