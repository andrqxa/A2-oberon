MODULE Arclets IN Oberon;   (** AUTHOR "pp;fof" ; PURPOSE "arclet and circlet decomposition"  **)

IMPORT Math := MathL IN A2, antsCommands, vyBase, antsArrayObjects, aM := antsMessages, vyName, wedgeTrees, vyGraphBase, 
	vyStrings := vyHostStrings, Oberon, CM := CumulativeMatrices,Out;  

TYPE 
	Parameter* = OBJECT (wedgeTrees.Parameter)
	VAR
		cx, cy: SIZE;  
	END Parameter;  
	
	Model* = OBJECT (wedgeTrees.Model)
	VAR sum, sumsq, points: CM.CircleSums;  
		cx, cy: SIZE;   (* coordinates of the center of the circle *)
		useddata-: antsArrayObjects.tLONGREALArray;   (* cache indicator *)
		keepdata: BOOLEAN;  
		
		PROCEDURE SetCenterPoint*( x, y: SIZE );  
		BEGIN 
			cx := x;  cy := y;  
		END SetCenterPoint;  

		PROCEDURE SetParameters( p: wedgeTrees.Parameter );  
		BEGIN 
			WITH p: Parameter DO SetCenterPoint( p.cx, p.cy );  
			END;  
		END SetParameters;  

		PROCEDURE GetParameters( ): wedgeTrees.Parameter;  
		VAR p: Parameter;  
		BEGIN 
			NEW( p );  p.cx := cx;  p.cy := cy;  RETURN p;  
		END GetParameters;  

		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		VAR squares, pts: antsArrayObjects.tLONGREALArray;  
		BEGIN 
			IF sum = NIL THEN 
				CM.AllocSame( data^, pts );  CM.AllocSame( data^, squares );  CM.Const( 1, pts^ );  
				CM.Square( data^, squares^ );  NEW( sum, data );  NEW( sumsq, squares );  NEW( points, pts );  
			ELSIF ~keepdata THEN 
				CM.Square( data^, sumsq.raw^ );  sum.Init( data );  sumsq.Init( sumsq.raw );  points.Init( points.raw );  
			END;  
			
			sum.SetCenter( cx, cy );  sumsq.SetCenter( cx, cy );  points.SetCenter( cx, cy );  keepdata := FALSE;  
		END PrepareApproximation;  

		PROCEDURE CircleRectValues( VAR rx, ry, rw, rh, cx, cy, i: SIZE;  VAR sum1, ssq1, nrPoints1: FLOAT64 );  
		VAR upy, uph, lowy, lowh: SIZE;  low, up: BOOLEAN;  q: CM.PointQueue;  
		
		BEGIN 
			CM.Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  sum1 := 0;  ssq1 := 0;  nrPoints1 := 0;  
			IF low THEN 
				CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, i, q );  
				IF q.head # NIL THEN 
					CM.ReorderForLower( cx, cy, i, q );  sum1 := sum1 + sum.LowerQContent( q, rx, lowy, rw, lowh );  
					ssq1 := ssq1 + sumsq.LowerQContent( q, rx, lowy, rw, lowh );  
					nrPoints1 := nrPoints1 + points.LowerQContent( q, rx, lowy, rw, lowh );  
				ELSIF CM.RectInCircle( rx, lowy, rw, lowh, cx, cy, i ) THEN 
					sum1 := sum1 + sum.RectContent( rx, lowy, rx + rw - 1, lowy + lowh - 1 );  
					ssq1 := ssq1 + sumsq.RectContent( rx, lowy, rx + rw - 1, lowy + lowh - 1 );  
					nrPoints1 := nrPoints1 + points.RectContent( rx, lowy, rx + rw - 1, lowy + lowh - 1 );  
				END;  
			END;  
			
			IF up THEN 
				CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, i, q );  
				IF q.head # NIL THEN 
					sum1 := sum1 + sum.UpperQContent( q, rx, upy, rw, uph, low );  
					ssq1 := ssq1 + sumsq.UpperQContent( q, rx, upy, rw, uph, low );  
					nrPoints1 := nrPoints1 + points.UpperQContent( q, rx, upy, rw, uph, low );  
				ELSIF CM.RectInCircle( rx, upy, rw, uph, cx, cy, i ) THEN 
					IF low THEN  (* omit  lowest line *)
						sum1 := sum1 + sum.RectContent( rx, upy + 1, rx + rw - 1, upy + uph - 1 );  
						ssq1 := ssq1 + sumsq.RectContent( rx, upy + 1, rx + rw - 1, upy + uph - 1 );  
						nrPoints1 := nrPoints1 + points.RectContent( rx, upy + 1, rx + rw - 1, upy + uph - 1 );  
					ELSE 
						sum1 := sum1 + sum.RectContent( rx, upy, rx + rw - 1, upy + uph - 1 );  
						ssq1 := ssq1 + sumsq.RectContent( rx, upy, rx + rw - 1, upy + uph - 1 );  
						nrPoints1 := nrPoints1 + points.RectContent( rx, upy, rx + rw - 1, upy + uph - 1 );  
					END;  
				END;  
			END;  
			ASSERT ( ENTIER( nrPoints1 + 0.5 ) <= rw * rh, 1002 );  
		END CircleRectValues;  

		PROCEDURE InRange( rx, ry, rw, rh: SIZE ): BOOLEAN;  
		VAR a, b, rsq: FLOAT64;  
		BEGIN 
			IF (rw = 1) OR (rh = 1) THEN RETURN FALSE END;  
			a := (rx + rw DIV 2 - cx);  a := a * a;  b := (ry + rh DIV 2 - cy);  b := b * b;  rsq := a + b;  
			a := ((rw * rw) + (rh * rh)) DIV 4;  
			IF (rsq - a > 0) & (Math.sqrt( rsq ) - Math.sqrt( rsq - a ) < 1) THEN RETURN FALSE END;  
			RETURN TRUE;  
		END InRange;  

	END Model;  

TYPE 
	ArcletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR cx, cy, cr: SIZE;  
		inmean, outmean: FLOAT64;   (* mean in the rectangle  *)
	END ArcletApproximation;  

TYPE 
	ArcletModel* = OBJECT (Model)

		PROCEDURE FindBestRadius( rx, ry, rw, rh: SIZE;  VAR r: SIZE;  VAR in, out, ssq: FLOAT64 );  
		VAR i: SIZE;  

			sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3: FLOAT64;  min: FLOAT64;  minc, maxc: SIZE;  
		BEGIN 
			min := MAX( FLOAT64 );  CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			nrPoints3 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum3 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq3 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			
			FOR i := minc TO maxc DO CircleRectValues( rx, ry, rw, rh, cx, cy, i, sum1, ssq1, nrPoints1 );  

				sum2 := sum3 - sum1;  ssq2 := ssq3 - ssq1;  nrPoints2 := nrPoints3 - nrPoints1;   (* outside *)
				
				IF nrPoints1 > 0 THEN ssq1 := ssq1 - sum1 * sum1 / nrPoints1;  END;  
				IF nrPoints2 > 0 THEN ssq2 := ssq2 - sum2 * sum2 / nrPoints2;  END;  
				
				ssq := ssq1 + ssq2;   (*sum ssq from upper and lower part*)
				
				IF ssq < min THEN min := ssq;  r := i;  in := sum1 / nrPoints1;  out := sum2 / nrPoints2;  END;  
			END;  
			ssq := min;  
		END FindBestRadius;  

		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR i: SIZE;  

			sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3: FLOAT64;  minc, maxc: SIZE;  
		BEGIN 
			IF ~InRange( rx, ry, rw, rh ) THEN RETURN TRUE  (* model not appropriate *) END;  
			
			nrPoints3 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum3 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum3 / Math.sqrt( nrPoints3 ) ) > val THEN RETURN FALSE END;  
			CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			
			FOR i := minc TO maxc DO 
				CircleRectValues( rx, ry, rw, rh, cx, cy, i, sum1, ssq1, nrPoints1 );  sum2 := sum3 - sum1;  ssq2 := ssq3 - ssq1;  
				nrPoints2 := nrPoints3 - nrPoints1;   (* outside *)
				IF nrPoints1 > 0 THEN 
					IF ABS( sum1 / Math.sqrt( nrPoints1 ) ) > val THEN RETURN FALSE END;  
				END;  
				IF nrPoints2 > 0 THEN 
					IF ABS( sum2 / Math.sqrt( nrPoints2 ) ) > val THEN RETURN FALSE END;  
				END;  
			
			END;  
			RETURN TRUE;  
		
		END CheckMRCoefficient;  

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: ArcletApproximation;  inmean, outmean, ssq: FLOAT64;  radius: SIZE;  
		BEGIN 
			IF ~InRange( x, y, w, h ) THEN RETURN END;  
			
			FindBestRadius( x, y, w, h, radius, inmean, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( ArcletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.inmean := inmean;  local.outmean := outmean;  local.cr := radius;  local.cx := cx;  
			local.cy := cy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR result: antsArrayObjects.tLONGREALArray;  local: ArcletApproximation;  cx, cy, cr: SIZE;  in, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( ArcletApproximation );  cx := local.cx;  cy := local.cy;  cr := local.cr;  
			in := local.inmean;  out := local.outmean;  CM.FillRect( result, rx, ry, rw, rh, out );  
			CM.FillCircle( result, cx, cy, cr, rx, ry, rw, rh, in );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  
	
	(*
			PROCEDURE Dot2d( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst2d( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot2d;  
		*)
	
		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  cx, cy: SIGNED16;  cr, lowy, lowh, upy, uph: SIZE;  low, up: BOOLEAN;  
			string: ARRAY 64 OF CHAR;  
			scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  q: CM.PointQueue;  p1, p2: CM.Point;  
		CONST round = 1 / 2 - 1.0D-10;  
		
		BEGIN 
			WITH approx: ArcletApproximation DO 
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

				vyGraphBase.SetForeColor( 2 );  
				
				(* for checking circles 
				cr := approx.cr; cx := SIGNED16(approx.cx); cy := SIGNED16(approx.cy); 
				Split( y, h, cy, lowy, lowh, upy, uph, low, up );  
				IF low THEN 
					RectCircleIntersect( x, lowy, w, lowh, cx, cy, cr, q );  ReorderForLower( cx, cy, cr, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, Dot2d );  p1 := p2.next;  END;  
				END;  
				IF up THEN 
					RectCircleIntersect( x, upy, w, uph, cx, cy, cr, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, clockwise, Dot2d );  p1 := p2.next;  END;  
				END;  
				*)
				
				
				vyGraphBase.Point2dToPoint( approx.cx + round, approx.cy + round, cx, cy );   (* circles are computed with respect to pixel midpoints ! With rounding down at 1/2*)
				cr := ENTIER( approx.cr * scalefactor + 0.5 );  

				vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  

				CM.Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  
				IF low THEN 
					CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr, q );  CM.ReorderForLower( cx, cy, cr, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				END;  
				IF up THEN 
					CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				END;  
				
				vyGraphBase.Point2dToPoint( approx.cx, approx.cy, cx, cy );  cr := ENTIER( approx.cr * scalefactor + 0.5 );  
			
			END;  
		END Display;  

		PROCEDURE & Init;  
		BEGIN 
			Init^;  
			useddata := NIL;  penalty := 2.00001;  pieces := 2;   (* reset cache indicator *)
		END Init;  

	END ArcletModel;  
	
	PROCEDURE Min( a, b: SIZE ): SIZE;  
	BEGIN 
		IF a < b THEN RETURN a ELSE RETURN b END;  
	END Min;  

TYPE 
	RingletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR cx, cy, cr1, cr2: SIZE;  
		mean1, mean2, outmean: FLOAT64;   (* mean in the rectangle  *)
	END RingletApproximation;  

TYPE 
	
	RingletModel* = OBJECT (Model)
	VAR ssqa, suma, pointsa: POINTER TO ARRAY OF FLOAT64;  
		minwidth, maxwidth: SIZE;  
		
		PROCEDURE FindBestRing( rx, ry, rw, rh: SIZE;  VAR r1, r2: SIZE;  VAR in1, in2, out, ssq: FLOAT64 );  
		
		VAR i, j: SIZE;  

			sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  min: FLOAT64;  minc, maxc: SIZE;  
		
		BEGIN 
			min := MAX( FLOAT64 );  CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq4 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxc - minc + 1) THEN 
				NEW( ssqa, maxc - minc + 1 );  NEW( suma, maxc - minc + 1 );  NEW( pointsa, maxc - minc + 1 );  
			END;  
			
			FOR i := minc TO maxc DO CircleRectValues( rx, ry, rw, rh, cx, cy, i, suma[i - minc], ssqa[i - minc], pointsa[i - minc] );  END;  
			
			FOR i := minc TO maxc DO 
				ssq1 := ssqa[i - minc];  sum1 := suma[i - minc];  nrPoints1 := pointsa[i - minc];   (* smaller circle *)
				IF nrPoints1 > 0 THEN 
					FOR j := i + minwidth TO Min( maxc, i + maxwidth ) DO 
						ssq2 := ssqa[j - minc];  sum2 := suma[j - minc];  nrPoints2 := pointsa[j - minc];   (* larger circle *)
						IF (nrPoints2 > 0) THEN 
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;  ssq3 := ssq4 - ssq2;   (* background *)
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;  ssq2 := ssq2 - ssq1;   (* larger circle again *)
							
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
								min := ssq;  r1 := i;  r2 := j;  in1 := sum1 / nrPoints1;  in2 := sum2 / nrPoints2;  out := sum3 / nrPoints3;  
							END;  
						
						END;  
					END;  
				
				END;  
			END;  
			
			ssq := min;  
		END FindBestRing;  

		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR i, j: SIZE;  

			sum1, nrPoints1, sum2, nrPoints2, sum3, nrPoints3, nrPoints4, sum4: FLOAT64;  minc, maxc: SIZE;  
		
		BEGIN 
			IF ~InRange( rx, ry, rw, rh ) THEN RETURN TRUE  (* model not appropriate *) END;  
			
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum4 / Math.sqrt( nrPoints4 ) ) > val THEN RETURN FALSE END;  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxc - minc + 1) THEN 
				NEW( ssqa, maxc - minc + 1 );  NEW( suma, maxc - minc + 1 );  NEW( pointsa, maxc - minc + 1 );  
			END;  
			CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			FOR i := minc TO maxc DO CircleRectValues( rx, ry, rw, rh, cx, cy, i, suma[i - minc], ssqa[i - minc], pointsa[i - minc] );  END;  
			
			FOR i := minc TO maxc DO 
				sum1 := suma[i - minc];  nrPoints1 := pointsa[i - minc];   (* smaller circle *)
				IF nrPoints1 > 0 THEN 
					FOR j := i + minwidth TO Min( maxc, i + maxwidth ) DO 
						sum2 := suma[j - minc];  nrPoints2 := pointsa[j - minc];   (* larger circle *)
						IF (nrPoints2 > 0) THEN 
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;   (* background *)
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;   (* larger circle again *)
							
							IF nrPoints1 > 0 THEN 
								IF ABS( sum1 / Math.sqrt( nrPoints1 ) ) > val THEN RETURN FALSE END;  
							END;  
							IF nrPoints2 > 0 THEN 
								IF ABS( sum2 / Math.sqrt( nrPoints2 ) ) > val THEN RETURN FALSE END;  
							END;  
							IF nrPoints3 > 0 THEN 
								IF ABS( sum3 / Math.sqrt( nrPoints3 ) ) > val THEN RETURN FALSE END;  
							END;  
						END;  
					END;  
				END;  
			END;  
			RETURN TRUE;  
		
		END CheckMRCoefficient;  

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: RingletApproximation;  in1, in2, outmean, ssq: FLOAT64;  r1, r2: SIZE;  
		BEGIN 
			IF ~InRange( x, y, w, h ) THEN RETURN END;  
			
			FindBestRing( x, y, w, h, r1, r2, in1, in2, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( RingletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.mean1 := in1;  local.mean2 := in2;  local.outmean := outmean;  local.cr1 := r1;  
			local.cr2 := r2;  local.cx := cx;  local.cy := cy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR result: antsArrayObjects.tLONGREALArray;  local: RingletApproximation;  cx, cy, cr1, cr2: SIZE;  in1, in2, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( RingletApproximation );  cx := local.cx;  cy := local.cy;  cr1 := local.cr1;  
			cr2 := local.cr2;  in1 := local.mean1;  in2 := local.mean2;  out := local.outmean;  
			CM.FillRect( result, rx, ry, rw, rh, out );  CM.FillCircle( result, cx, cy, cr2, rx, ry, rw, rh, in2 );  
			CM.FillCircle( result, cx, cy, cr1, rx, ry, rw, rh, in1 );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  cx, cy: SIGNED16;  cr1, cr2, lowy, lowh, upy, uph: SIZE;  low, up: BOOLEAN;  
			string: ARRAY 64 OF CHAR;  
			scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  q: CM.PointQueue;  p1, p2: CM.Point;  
		CONST round = 1 / 2 - 1.0D-10;  
		BEGIN 
			WITH approx: RingletApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, rx, ry, rw, rh );  vyGraphBase.FrameRect( rx, ry, rw + 1, rh + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (rw > 20) & (rh > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.mean1, 1, 1, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.mean2, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( rx + rw DIV 2, ry + rh DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
				vyGraphBase.Rect2dToRect( 0, 0, 100, 100, scalex, scaley, scalew, scaleh );  
				IF scalew # scaleh THEN RETURN END;   (* kept aspect ratio 1:1 ? *)
				scalefactor := scalew / 100;  

				vyGraphBase.Point2dToPoint( approx.cx + round, approx.cy + round, cx, cy );   (* circles are computed with respect to pixel midpoints ! With rounding down at 1/2*)
				cr1 := ENTIER( approx.cr1 * scalefactor + 0.5 );  cr2 := ENTIER( approx.cr2 * scalefactor + 0.5 );  

				vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  

				CM.Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  
				IF low THEN 
					CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr1, q );  CM.ReorderForLower( cx, cy, cr1, q );  
					p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr1, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
					CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr2, q );  CM.ReorderForLower( cx, cy, cr2, q );  
					p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr2, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				
				END;  
				IF up THEN 
					CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr1, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr1, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
					CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr2, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr2, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				
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
			useddata := NIL;  penalty := 3.00001;  pieces := 3;   (* reset cache indicator *)
			minwidth := 1;  maxwidth := 10000;  
		END Init;  

	END RingletModel;  

TYPE 
	
	CircletApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR cx, cy, cr1, cr2: SIZE;  
		inmean, outmean: FLOAT64;   (* mean in the rectangle  *)
	END CircletApproximation;  

TYPE 
	CircletModel* = OBJECT (Model)
	VAR ssqa, suma, pointsa: POINTER TO ARRAY OF FLOAT64;  
		minwidth, maxwidth: SIZE;  
		
		PROCEDURE FindBestCirclet( rx, ry, rw, rh: SIZE;  VAR r1, r2: SIZE;  VAR in, out, ssq: FLOAT64 );  
		
		VAR i, j: SIZE;  

			sum1, ssq1, nrPoints1, sum2, ssq2, nrPoints2, sum3, ssq3, nrPoints3, nrPoints4, sum4, ssq4: FLOAT64;  min: FLOAT64;  minc, maxc: SIZE;  
		
		BEGIN 
			min := MAX( FLOAT64 );  CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			ssq4 := sumsq.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxc - minc + 1) THEN 
				NEW( ssqa, maxc - minc + 1 );  NEW( suma, maxc - minc + 1 );  NEW( pointsa, maxc - minc + 1 );  
			END;  
			
			FOR i := minc TO maxc DO CircleRectValues( rx, ry, rw, rh, cx, cy, i, suma[i - minc], ssqa[i - minc], pointsa[i - minc] );  END;  
			
			FOR i := minc TO maxc DO 
				ssq1 := ssqa[i - minc];  sum1 := suma[i - minc];  nrPoints1 := pointsa[i - minc];   (* smaller circle *)
				IF nrPoints1 > 0 THEN 
					FOR j := i + minwidth TO Min( maxc, i + maxwidth ) DO 
						ssq2 := ssqa[j - minc];  sum2 := suma[j - minc];  nrPoints2 := pointsa[j - minc];   (* larger circle *)
						IF (nrPoints2 > 0) THEN 
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;  ssq2 := ssq2 - ssq1;   (* larger circle again *)
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;  ssq3 := ssq4 - ssq2;   (* background *)
							
							ASSERT ( ENTIER( nrPoints2 + nrPoints3 + 0.5 ) = rw * rh, 1005 );  
							ssq := 0;  
							(* IF nrPoints1 > 0 THEN ssq := ssq+ssq1 - sum1 * sum1 / nrPoints1;  END;  *)
							IF nrPoints2 > 0 THEN ssq := ssq + ssq2 - sum2 * sum2 / nrPoints2;  END;  
							IF nrPoints3 > 0 THEN ssq := ssq + ssq3 - sum3 * sum3 / nrPoints3;  END;  
							ASSERT ( ssq >= 0, 1010 );  
							(* ASSERT ( ssq1 >= 0, 1011 );   *)
							ASSERT ( ssq2 >= 0, 1012 );  
							ASSERT ( ssq3 >= 0, 1013 );  
							
							IF ssq < min THEN min := ssq;  r1 := i;  r2 := j;  in := sum2 / nrPoints2;  out := sum3 / nrPoints3;  
							END;  
						
						END;  
					END;  
				
				END;  
			END;  
			
			ssq := min;  
		END FindBestCirclet;  

		PROCEDURE CheckMRCoefficient( rx, ry, rw, rh: SIZE;  val: FLOAT64 ): BOOLEAN;  
		VAR i, j: SIZE;  

			sum1, nrPoints1, sum2, nrPoints2, sum3, nrPoints3, nrPoints4, sum4: FLOAT64;  minc, maxc: SIZE;  
		
		BEGIN 
			IF ~InRange( rx, ry, rw, rh ) THEN RETURN TRUE  (* model not appropriate *) END;  
			
			nrPoints4 := points.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			sum4 := sum.RectContent( rx, ry, rx + rw - 1, ry + rh - 1 );  
			IF ABS( sum4 / Math.sqrt( nrPoints4 ) ) > val THEN RETURN FALSE END;  
			
			IF (ssqa = NIL ) OR (LEN( ssqa ) < maxc - minc + 1) THEN 
				NEW( ssqa, maxc - minc + 1 );  NEW( suma, maxc - minc + 1 );  NEW( pointsa, maxc - minc + 1 );  
			END;  
			CM.FindIntersectingCircles( cx, cy, rx, ry, rw, rh, minc, maxc );  
			FOR i := minc TO maxc DO CircleRectValues( rx, ry, rw, rh, cx, cy, i, suma[i - minc], ssqa[i - minc], pointsa[i - minc] );  END;  
			
			FOR i := minc TO maxc DO 
				sum1 := suma[i - minc];  nrPoints1 := pointsa[i - minc];   (* smaller circle *)
				IF nrPoints1 > 0 THEN 
					FOR j := i + minwidth TO Min( maxc, i + maxwidth ) DO 
						sum2 := suma[j - minc];  nrPoints2 := pointsa[j - minc];   (* larger circle *)
						IF (nrPoints2 > 0) THEN 
							sum2 := sum2 - sum1;  nrPoints2 := nrPoints2 - nrPoints1;   (* larger circle again *)
							sum3 := sum4 - sum2;  nrPoints3 := nrPoints4 - nrPoints2;   (* background *)
							
							IF nrPoints2 > 0 THEN 
								IF ABS( sum2 / Math.sqrt( nrPoints2 ) ) > val THEN RETURN FALSE END;  
							END;  
							IF nrPoints3 > 0 THEN 
								IF ABS( sum3 / Math.sqrt( nrPoints3 ) ) > val THEN RETURN FALSE END;  
							END;  
						END;  
					END;  
				END;  
			END;  
			RETURN TRUE;  
		
		END CheckMRCoefficient;  

		PROCEDURE Approximate( x, y, w, h: SIZE;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: CircletApproximation;  in, outmean, ssq: FLOAT64;  r1, r2: SIZE;  
		BEGIN 
			IF ~InRange( x, y, w, h ) THEN RETURN END;  
			
			FindBestCirclet( x, y, w, h, r1, r2, in, outmean, ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( CircletApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.inmean := in;  local.outmean := outmean;  local.cr1 := r1;  local.cr2 := r2;  
			local.cx := cx;  local.cy := cy;  local.distance := ssq;  approx := local;  
		
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIZE;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR result: antsArrayObjects.tLONGREALArray;  local: CircletApproximation;  cx, cy, cr1, cr2: SIZE;  in, out: FLOAT64;  
		BEGIN 
			result := reco;  local := approx( CircletApproximation );  cx := local.cx;  cy := local.cy;  cr1 := local.cr1;  
			cr2 := local.cr2;  in := local.inmean;  out := local.outmean;  

			CM.FillRect( result, rx, ry, rw, rh, out );  CM.FillCircle( result, cx, cy, cr2, rx, ry, rw, rh, in );  
			CM.FillCircle( result, cx, cy, cr1, rx, ry, rw, rh, out );  
		END Reconstruct;  

		PROCEDURE Dot( x, y: SIZE );  
		BEGIN 
			vyGraphBase.ReplConst( SIGNED16( x ), SIGNED16( y ), 1, 1 );  
		END Dot;  

		PROCEDURE Display( x, y, w, h: SIZE;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR rx, ry, rw, rh: SIGNED16;  cx, cy: SIGNED16;  cr1, cr2, lowy, lowh, upy, uph: SIZE;  low, up: BOOLEAN;  
			string: ARRAY 64 OF CHAR;  
			scalex, scaley, scalew, scaleh: SIGNED16;  scalefactor: FLOAT64;  q: CM.PointQueue;  p1, p2: CM.Point;  
		CONST round = 1 / 2 - 1.0D-10;  
		BEGIN 
			WITH approx: CircletApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, rx, ry, rw, rh );  vyGraphBase.FrameRect( rx, ry, rw + 1, rh + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (rw > 20) & (rh > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.inmean, 1, 1, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.outmean, 1, 1, 0, string );  
						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( rx + rw DIV 2, ry + rh DIV 2, "Syntax8.Scn.Fnt", string );  
					END;  
				END;  
				vyGraphBase.Rect2dToRect( 0, 0, 100, 100, scalex, scaley, scalew, scaleh );  
				IF scalew # scaleh THEN RETURN END;   (* kept aspect ratio 1:1 ? *)
				scalefactor := scalew / 100;  

				vyGraphBase.Point2dToPoint( approx.cx + round, approx.cy + round, cx, cy );   (* circles are computed with respect to pixel midpoints ! With rounding down at 1/2*)
				cr1 := ENTIER( approx.cr1 * scalefactor + 0.5 );  cr2 := ENTIER( approx.cr2 * scalefactor + 0.5 );  

				vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  

				CM.Split( ry, rh, cy, lowy, lowh, upy, uph, low, up );  
				IF low THEN 
					CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr1, q );  CM.ReorderForLower( cx, cy, cr1, q );  
					p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr1, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
					CM.RectCircleIntersect( rx, lowy, rw, lowh, cx, cy, cr2, q );  CM.ReorderForLower( cx, cy, cr2, q );  
					p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr2, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				
				END;  
				IF up THEN 
					CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr1, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr1, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
					CM.RectCircleIntersect( rx, upy, rw, uph, cx, cy, cr2, q );  p1 := q.head;  
					WHILE p1 # NIL DO p2 := p1.next;  CM.ARC( cx, cy, cr2, p1.x, p1.y, p2.x, p2.y, CM.clockwise, Dot );  p1 := p2.next;  END;  
				
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
			useddata := NIL;  penalty := 2.500001;  pieces := 3;   (* reset cache indicator *)
			minwidth := 1;  maxwidth := 10000;  
		END Init;  

	END CircletModel;  
	
	PROCEDURE NewArcletModel*;  
	VAR m: ArcletModel;  
		name: ARRAY 256 OF CHAR;  
		cx, cy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "cx", cx ) & antsCommands.ExpectSize( "cy", cy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetCenterPoint( cx, cy );  
		END;  
	END NewArcletModel;  

	PROCEDURE NewRingletModel*;  
	VAR m: RingletModel;  
		name: ARRAY 256 OF CHAR;  
		cx, cy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "cx", cx ) & antsCommands.ExpectSize( "cy", cy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetCenterPoint( cx, cy );  
		END;  
	END NewRingletModel;  

	PROCEDURE NewCircletModel*;  
	VAR m: CircletModel;  
		name: ARRAY 256 OF CHAR;  
		cx, cy: SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectSize( "cx", cx ) & antsCommands.ExpectSize( "cy", cy ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  m.SetCenterPoint( cx, cy );  
		END;  
	END NewCircletModel;  

	PROCEDURE SetWidth*;  
	VAR obj: vyBase.Object;  min, max: SIZE;  
	BEGIN 
		antsCommands.InitScan( "model=OBJECT min=NUMBER max=NUMBER" );  
		IF antsCommands.ExpectObject( "model", obj ) & antsCommands.ExpectSize( "min", min ) & 
		    antsCommands.ExpectSize( "max", max ) THEN 
			WITH obj: RingletModel DO obj.SetWidth( min, max );  aM.SISI( "Ok, set ", min, "<= width <=", max );  
			| obj: CircletModel DO obj.SetWidth( min, max );  aM.SISI( "Ok, set ", min, "<= width <=", max );  
			END;  
		END;  
	END SetWidth;  

	PROCEDURE PlugInWith*;  
	VAR x, y, fromx, tox, byx, fromy, toy, byy: SIZE;  tree, model: vyBase.Object;  time: SIZE;  mode: SIGNED16;  cnt: SIZE; 
	BEGIN 
		time := Oberon.Time();  antsCommands.InitScan( "tree=Obj model=Obj fromx=Number fromy=Number tox=Number toy=Number byx=Number byy=Number" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) & 
		    antsCommands.ExpectSize( "fromx", fromx ) & antsCommands.ExpectSize( "fromy", fromy ) & 
		    antsCommands.ExpectSize( "tox", tox ) & antsCommands.ExpectSize( "toy", toy ) & 
		    antsCommands.ExpectSize( "byx", byx ) & antsCommands.ExpectSize( "byy", byy ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				WITH model: Model DO 
					ASSERT ( byx > 0 );  
					ASSERT ( byy > 0 );  
					
					y := fromy;  cnt := 0; 
					WHILE (y <= toy) DO 
						Out.String("+"); INC(cnt); IF cnt=100 THEN Out.Ln; cnt:=0 END; 
						(* aM.SI( "In Line ", y ); *)   x := fromx;  
						WHILE (x <= tox) DO 
							Out.String("."); INC(cnt); IF cnt=100 THEN Out.Ln; cnt:=0 END; 
							mode := aM.mode;  aM.mode := aM.errorMode;  model.SetCenterPoint( x, y );  tree.PlugIn( model, "CircleModel", MAX( SIZE ) );  
							model.keepdata := TRUE;  aM.mode := mode;  x := x + byx;  
						END;  
						y := y + byy;  
					END;  
					aM.S( "done." );  
				END;  
			END;  
		END;  
		aM.SI( "Time = ", Oberon.Time() - time );  
	END PlugInWith;  
	
	PROCEDURE PlugInByResolution*;  
	VAR x, y,resolution: SIZE;  tree, model: vyBase.Object;  time: SIZE;  mode: SIGNED16;  cnt: SIZE; 
	BEGIN 
		time := Oberon.Time();  antsCommands.InitScan( "tree=Obj model=Obj resolution=Number" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) & 
		    antsCommands.ExpectSize( "reolution", resolution )  THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				WITH model: Model DO 
						
					y := 0-resolution DIV 2;  cnt := 0; 
					WHILE (y < tree.h+resolution) DO 
						Out.String("+"); INC(cnt); IF cnt=100 THEN Out.Ln; cnt:=0 END; 
						(* aM.SI( "In Line ", y ); *)   x := -resolution DIV  2;  
						WHILE (x < tree.w + resolution) DO 
							Out.String("."); INC(cnt); IF cnt=100 THEN Out.Ln; cnt:=0 END; 
							mode := aM.mode;  aM.mode := aM.errorMode;  model.SetCenterPoint( x, y );  tree.PlugIn( model, "CircleModel", MAX( SIZE ) );  
							model.keepdata := TRUE;  aM.mode := mode;  x := x + resolution;  
						END;  
						y := y + resolution;  
					END;  
					aM.S( "done." );  
				END;  
			END;  
		END;  
		aM.SI( "Time = ", Oberon.Time() - time );  
	END PlugInByResolution;  
	


END Arclets.


System.Free Arclets CumulativeMatrices ~
Arclets.TestpaintArc 
Arclets.LineCircleIntersect
(*
antsArrayObjects.LoadDialogedP2 testarrayint6 > show ~
Arclets.IntToReal src=testarrayint6 dest=testarray ~
Arclets.TryColSum testarray  64 64  ~
Arclets.IntersectRect  a=1 b=1 w=3  h=3 x=5 y=4 r=3 ~
System.Free Arclets ~
*)

(* PGM Ascii files will work *)

Arclets.Testpaint    575 545 55 500 500 128 128 ~


Arclets.Testpaint 200 200 60 260 160 200  80 ~
Arclets.TestpaintArc 200 200 60 ~  140 140 140 140~
Arclets.Testpaint  564 490 151   500 500 128 128  ~
Arclets.TryColSum testarray 32 32 ~
Arclets.Testpaint  64 -10 151 0 0 128 128  ~
Arclets.Testpaint    650 510 23 500 500 128 128 ~

Arclets.TryBestCircle testarray  64 64    ~
Arclets.TryBestCircle testarray 32 74    ~
Arclets.TryBestCircle testarray 32 10    ~
Arclets.TryBestCircle testarray2 10 10 ~



Arclets.TryBestCircle testarray2  64 -10  64 64 64 64 ~
Arclets.TryBestCircle testarray2 64 -10 48 112 16 16 ~

Arclets.NewArcletModel arcModel 0 0 ~
Arclets.NewRingletModel arcModel 256 256 ~
Arclets.NewCircletModel arcModel 256 256 ~
Arclets.SetWidth arcModel 3 3 ~


Arclets.PlugInWith myTree arcModel 0 0 128 128 8 8  ~
Arclets.PlugInWith myTree arcModel 0 0 256 256 8 8   ~
Arclets.PlugInWith myTree arcModel 50 20 90 50   5 5  ~

wedgeCommands.PlugIn tree=myTree model=arcModel ~

~
Arclets.TryBestCirclet testarray 256 256  72 72 8 8  ~
Arclets.TryBestArclet testarray 256 256  72 72 8 8  ~


wedge/wedge.Tool 

 (log)




Arclets.TryBestCircle testarray -10 6   0 0 128 128   ~
antsMessages.SetMode normal ~
