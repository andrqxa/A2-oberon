MODULE wedgeGenericModels IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT wedgeTrees, wedgeArrays, antsArrayObjects, Math := MathL IN A2, aM := antsMessages, Out, Files, Objects, vyGraphBase, 
	vyStrings := vyHostStrings, Gadgets, wedgeFunctions2d, antsRegions, antsCommands, vyName, Input, SYSTEM, antsHybridObjects;  

TYPE 
	FunctionName* = wedgeFunctions2d.FunctionName;  Function2d* = wedgeFunctions2d.Function;  
	Function2dArray* = wedgeFunctions2d.FunctionArray;  

	matrix = POINTER TO ARRAY OF ARRAY OF FLOAT64;  
	
	LocalRectApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR beta: POINTER TO ARRAY OF FLOAT64;  
		f: wedgeFunctions2d.FunctionO;  
	END LocalRectApproximation;  
	
	Test* = OBJECT 
	VAR A: antsArrayObjects.tLONGREALArray;  
		
		PROCEDURE f*( x, y: SIGNED32 ): FLOAT64;  
		VAR value: FLOAT64;  
		BEGIN 
			RETURN A[x, y];  
		END f;  

		PROCEDURE testFromArray*( x, y: FLOAT64 ): FLOAT64;  
		VAR xi, yi: SIGNED32;  
		BEGIN 
			ASSERT ( A # NIL );  
			xi := ENTIER( x );  yi := ENTIER( y );  RETURN f( xi, yi );  
		END testFromArray;  

		PROCEDURE & InitFromArray*( Array: antsArrayObjects.tLONGREALArray );  
		VAR i, j, w, h: SIGNED32;  
		BEGIN 
			w := LEN( Array );  h := LEN( Array[0] );  

			NEW( A, w, h );  
			FOR i := 0 TO LEN( Array ) - 1 DO 
				FOR j := 0 TO LEN( Array[0] ) - 1 DO A[i, j] := Array[i, j];  END;  
			END;  
			ASSERT ( A # NIL );  
		END InitFromArray;  

	END Test;  
	
	RectModel* = OBJECT (wedgeTrees.Model) (*! maybe as extension of constant model *)
	VAR linehor-: wedgeArrays.LineObject;  
		(* linehor = line object defined by angle zero , needed  for calculation of rectSumZ and rectSumZZ*)
		colM: wedgeArrays.GMoments;  
		rectM: wedgeArrays.GMomentsO;  
		
		minbeta: matrix;   (* ARRAY 10 OF ARRAY 1 OF FLOAT64;  *)
		
		phi*: wedgeFunctions2d.FunctionO;  
		testvec: POINTER TO ARRAY OF Test;  
		
		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		VAR i, w, h, msize: SIGNED32;  
		BEGIN 			
			wedgeArrays.ComputeColSumsG( data, phi.fa^, colM );   (**)
			
			NEW( linehor, 10000, 0, LEN( data[0] ), LEN( data ) );   (**)
			wedgeArrays.MakeMomentOG( colM, linehor, phi.fa^, rectM );  
			(**)
		END PrepareApproximation;  

		PROCEDURE & Init*;  
		BEGIN 
			Init^;  NEW( minbeta, 10, 1 );    NEW(phi);		 
		END Init;  

	PROCEDURE InitPhi*( p: SIGNED32 );  
		VAR i: SIGNED16;  
		BEGIN 
			phi.InitL( p );  NEW( testvec, p );  
		END InitPhi;  

		PROCEDURE SetFunctions*( o: wedgeFunctions2d.FunctionO );  
		BEGIN 
			phi := o;  
		END SetFunctions;  
		
	PROCEDURE SetFunctionsFromArray*( region: antsRegions.tRegion;  l: SIGNED32 );  
		VAR i, j, x, y, w, h, ws, hs, ip, jp: SIGNED32;  Array: antsArrayObjects.tLONGREALArray;  
			IntegerArray: antsArrayObjects.tINTEGERObject;  test: Test;  
		BEGIN 
			antsRegions.DoSelectRegion( region );  
			IF ~region.valid THEN RETURN END;  
			IntegerArray := antsRegions.A;  w := LEN( IntegerArray.A^ );  h := LEN( IntegerArray.A^[0] );  
			(*Out.String( "w : " );  
			Out.Int( w, 5 );  Out.String( " h : " );  Out.Int( h, 5 );  Out.Ln; *) 

			NEW( Array, w, h );  

			(* Out.String( "a:w : " );  Out.Int( IntegerArray.w, 5 );  Out.Ln;  *)

			ws := region.w;  hs := region.h;  x := region.x;  y := region.y;  
			
			(* Periodize *)
			FOR i := 0 TO w - 1 DO 
				FOR j := 0 TO h - 1 DO ip := i MOD hs;  jp := j MOD ws;  Array[i, j] := IntegerArray.A^[ip + y, jp + x];  END;  
			END;  
				
			NEW( testvec[l], Array );  

			phi.fa[l] := testvec[l].testFromArray;  
		END SetFunctionsFromArray;  


		PROCEDURE Approximate( x, y, w, h: SIGNED32;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR i, msize, psize: SIGNED32;  local: LocalRectApproximation;  ssq: FLOAT64;  
		BEGIN 
			IF (w < 2) OR (h < 2) THEN RETURN END;  
			
			psize := LEN( phi.fa );  
			IF ((minbeta = NIL ) OR (LEN( minbeta ) # psize)) THEN NEW( minbeta, psize, 1 ) END;  
			
			wedgeArrays.RectStatG( rectM, x, y, w, h, ssq, minbeta^, psize );  

			aM.dSISI( "x=", x, "y=", y );  aM.dSISI( "w=", w, "h=", h );  aM.dSR( "ssq=", ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				local := approx( LocalRectApproximation );  
				IF local.distance <= ssq THEN RETURN END;  
			ELSE NEW( local );  
			END;  
			
			local.distance := ssq;  local.f := phi;  
			(*	IF ((local.f = NIL ) OR (LEN( local.f^ ) # psize)) THEN NEW( local.f, psize );  
			END;   *)
			
			IF ((local.beta = NIL ) OR (LEN( local.beta^ ) # psize)) THEN NEW( local.beta, psize );  END;  
			
			FOR i := 0 TO psize - 1 DO  (* local.f[i] := phi[i]; *) local.beta[i] := minbeta[i, 0];  END;  
			
			local.penalty := psize;  approx := local;  
				
		END Approximate;  

		PROCEDURE Reconstruct( x, y, w, h: SIGNED32;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR xx, yy: SIGNED32;  c: FLOAT64;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 

				wedgeArrays.FillRectLinG( reco, x, y, w, h, approx.beta^, approx.f.fa^ );  
			END;  
		END Reconstruct;  

		PROCEDURE Display( x, y, w, h: SIGNED32;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR xi, yi, wi, hi: SIGNED16;  
			string: ARRAY 128 OF CHAR;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, xi, yi, wi, hi );  vyGraphBase.FrameRect( xi, yi, wi + 1, hi + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (wi > 60) & (hi > 20) THEN vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  

						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( xi + wi DIV 2, yi + hi DIV 2 + 10, "Syntax8.Scn.Fnt", string );  
					
					END;  
				END;  
			END;  
		END Display;  

		PROCEDURE LoadApproximation( VAR R: Files.Rider;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR version, i, n: SIGNED32;  a: LocalRectApproximation;  obj: Objects.Object;  
		BEGIN 
			Files.ReadLInt( R, version );  
			IF version < 0 THEN RETURN END;  
			IF approx = NIL THEN NEW( a );  approx := a;  ELSE a := approx( LocalRectApproximation ) END;  
			LoadApproximation^( R, approx );  Files.ReadLInt( R, n );  
			IF n > 0 THEN 
				NEW( a.beta, n );  
				FOR i := 0 TO n - 1 DO Files.ReadLReal( R, a.beta[i] );  END;  
			END;  
			Gadgets.ReadRef( R, lib, obj );  
			IF obj # NIL THEN a.f := obj( wedgeFunctions2d.FunctionO ) END;  
		END LoadApproximation;  

		PROCEDURE StoreApproximation( VAR R: Files.Rider;  approx: wedgeTrees.LocalApproximation );  
		VAR i: SIGNED32;  a: LocalRectApproximation;  
		CONST  (* version = 20040802;  *) version = 20050211;  
		BEGIN 
			IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  END;  
			Files.WriteLInt( R, version );  a := approx( LocalRectApproximation );  StoreApproximation^( R, a );  

			Files.WriteLInt( R, LEN( a.beta ) );  
			FOR i := 0 TO LEN( a.beta ) - 1 DO Files.WriteLReal( R, a.beta[i] );  END;  
			Gadgets.WriteRef( R, lib, a.f );  
		END StoreApproximation;  

		PROCEDURE BindApproximation*( VAR M: Objects.BindMsg;  approx: wedgeTrees.LocalApproximation );  
		BEGIN 
			IF approx # NIL THEN BindObj( M, approx( LocalRectApproximation ).f );  END;  
			BindApproximation^( M, approx );  
		END BindApproximation;  

	END RectModel;  

TYPE 
	LocalWedgeApproximation = OBJECT (wedgeTrees.LocalApproximation)
	VAR line: wedgeArrays.LineObject;  
		linenr: SIGNED32;  
		beta1, beta2: POINTER TO ARRAY OF FLOAT64;  
		f: wedgeFunctions2d.FunctionO;  
	
	END LocalWedgeApproximation;  
	
	WedgeModel* = OBJECT (wedgeTrees.Model)
	VAR line-, linehor-: wedgeArrays.LineObject;  
		(* line = line object defined by angle alpha , needed  for calculation of trapezeSumZ, trapezeSumZZ and in the local approximation *)
		(* linehor = line object defined by angle zero , needed  for calculation of rectSumZ and rectSumZZ*)
		useddata-: antsArrayObjects.tLONGREALArray;   (* cache indicator *)
		colM: wedgeArrays.GMoments;  
		rectM: wedgeArrays.GMomentsO;  
		trapezeM: wedgeArrays.GMomentsO;  
		alpha-: FLOAT64;   (* angle *)
		
		minbeta1, minbeta2: matrix;  
		phi: wedgeFunctions2d.FunctionO;  
		modelindx: SIGNED32;  
		
		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		VAR dx, dy, w, h: SIGNED32;  
		BEGIN 
			w := LEN( data[0] );  h := LEN( data );  
			
			IF useddata # data THEN  (* very first call, prepare basic matrices *)
				wedgeArrays.ComputeColSumsG( data, phi.fa^, colM );   (**)
				NEW( linehor, 10000, 0, LEN( data[0] ), LEN( data ) );   (**)
				wedgeArrays.MakeMomentOG( colM, linehor, phi.fa^, rectM );   (**)
			END;  
			
			dx := ENTIER( Math.cos( alpha * Math.pi / 180 ) * 100000 );  dy := ENTIER( Math.sin( alpha * Math.pi / 180 ) * 100000 );  
			NEW( line, dx, dy, w, h );   (* reference line to angle alpha *)
			wedgeArrays.MakeMomentOG( colM, line, phi.fa^, trapezeM );  
		END PrepareApproximation;  

		PROCEDURE & Init( );  
		BEGIN 
			Init^;  NEW( minbeta1, 10, 1 );  NEW( minbeta2, 10, 1 );  phi := NIL;  
		END Init;  

		PROCEDURE SetFunctions*( o: wedgeFunctions2d.FunctionO );  
		BEGIN 
			phi := o;  
		END SetFunctions;  

		PROCEDURE Approximate( x, y, w, h: SIGNED32;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR i, psize: SIGNED32;  local: LocalWedgeApproximation;  ssq: FLOAT64;  linelen, linenr: SIGNED32;  
		BEGIN 
			psize := LEN( phi.fa );  
			wedgeArrays.GetBestWedgeG( rectM, trapezeM, x, y, w, h, linenr, linelen, ssq, minbeta1^, minbeta2^, psize );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				
				local := approx( LocalWedgeApproximation );  
			ELSE NEW( local );  
			END;  
			
			local.distance := ssq;  local.f := phi;  
			IF ((local.beta1 = NIL ) OR (LEN( local.beta1^ ) # psize)) THEN NEW( local.beta1, psize );  END;  
			IF ((local.beta2 = NIL ) OR (LEN( local.beta2^ ) # psize)) THEN NEW( local.beta2, psize );  END;  
			
			FOR i := 0 TO psize - 1 DO local.beta1[i] := minbeta1[i, 0];  local.beta2[i] := minbeta2[i, 0];  END;  
			local.penalty := 2 * psize;  

			local.linenr := linenr;  local.line := line;  approx := local;  
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIGNED32;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR sx, sy, ex, ey, x, y: SIGNED32;  

			PROCEDURE swap( VAR x, y: SIGNED32 );   (*Swap of two SIGNED32s*)
			VAR temp: SIGNED32;  
			BEGIN 
				temp := x;  x := y;  y := temp;  
			END swap;  

		BEGIN 
			WITH approx: LocalWedgeApproximation DO 

				wedgeArrays.FillRectLinG( reco, rx, ry, rw, rh, approx.beta2^, approx.f.fa^ );   (* fill rectangle with upmean *)
				
				IF ~approx.line.IntersectWRect( approx.linenr, rx, ry, rw, rh, sx, sy, ex, ey ) THEN 
					(*	RETURN; *)
					HALT( 100 );  
				END;  
				
				IF ~approx.line.vertical THEN 
					IF sx > ex THEN swap( ex, sx );  swap( ey, sy ) END;  
					FOR x := sx TO ex DO y := approx.line.GetY( approx.linenr, x );  

						wedgeArrays.FillVLineG( reco, x, ry, y - ry + 1, approx.beta1^, approx.f.fa^ );  
					END;  
				ELSE  (*vertical*)
					IF sy > ey THEN swap( ex, sx );  swap( ey, sy ) END;  
					
					FOR y := sy TO ey DO 
						x := approx.line.GetX( approx.linenr, y );  
						wedgeArrays.FillVLineG( reco, x, ry, y - ry + 1, approx.beta1^, approx.f.fa^ );  
					END;  
				END;  
				
				IF sx > ex THEN swap( ex, sx );  swap( ey, sy )
				END;  
				
				IF (sx > rx) & (sy > ry) THEN 
					wedgeArrays.FillRectLinG( reco, rx, ry, sx - rx, sy - ry + 1, approx.beta1^, approx.f.fa^ );  
				END;  
				IF (ex < rx + rw - 1) & (ey > ry) THEN 
					wedgeArrays.FillRectLinG( reco, ex + 1, ry, rx + rw - ex - 1, ey - ry + 1, approx.beta1^, approx.f.fa^ );  
				END;  
			END;  
		
		END Reconstruct;  

		PROCEDURE Display( x, y, w, h: SIGNED32;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR xi, yi, wi, hi, dsr: SIGNED16;  sx, sy, ex, ey: SIGNED32;  temp: SIGNED16;  
			string: ARRAY 64 OF CHAR;  
			maxd, dx, dy: FLOAT64;  line: wedgeArrays.LineObject;  

			PROCEDURE Sgn( x: SIGNED32 ): SIGNED32;  
			BEGIN 
				IF x < 0 THEN RETURN -1 ELSE RETURN 1 END;  
			END Sgn;  

		BEGIN 
			WITH approx: LocalWedgeApproximation DO 

				vyGraphBase.Rect2dToRect( x, y, w, h, xi, yi, wi, hi );  vyGraphBase.FrameRect( xi, yi, wi + 1, hi + 1 );  
				line := approx.line;  
				IF line.IntersectWRect( approx.linenr, x, y, w, h, sx, sy, ex, ey ) THEN 
					vyGraphBase.SetForeColor( vyGraphBase.S.selectcol );  dx := line.dx;  dy := line.dy;  
					
					IF ABS( dx ) > ABS( dy ) THEN maxd := ABS( dx )
					ELSE maxd := ABS( dy )
					END;  
					dx := ABS( dx ) / maxd / 2;  dy := ABS( dy ) / maxd / 2;  
					IF (sx > ex) THEN dx := -dx;  END;  
					IF (sy > ey) THEN dy := -dy;  END;  
					vyGraphBase.Line2d( sx + 0.5 - dx, sy + 0.5 - dy, ex + 0.5 + dx, ey + 0.5 + dy );  
					
					(*					IF mode > wedgeTrees.simple THEN 
						IF (wi > 80) & (hi > 20) THEN 
							vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  
							IF (Sgn( line.dx ) = Sgn( line.dy )) THEN 
								string := "";  vyGraphBase.SetStringJustification( vyGraphBase.right, vyGraphBase.bottom );  
								vyStrings.AppendRealFix( approx.a1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + dsr, "Syntax8.Scn.Fnt", string );  
								string := "";  vyStrings.AppendRealFix( approx.d1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  
								vyGraphBase.String( xi + wi, yi + dsr + 20, "Syntax8.Scn.Fnt", string );  

								string := "";  vyStrings.AppendRealFix( approx.a2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c2, 1, 0, 0, string );  
								vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.top );  
								vyGraphBase.String( xi, yi + hi - 20, "Syntax8.Scn.Fnt", string );  string := "";  
								vyStrings.AppendRealFix( approx.d2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee2, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + hi, "Syntax8.Scn.Fnt", string );  
							
							ELSE 
								string := "";  vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.bottom );  
								vyStrings.AppendRealFix( approx.a1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi, yi + dsr, "Syntax8.Scn.Fnt", string );  
								string := "";  vyStrings.AppendRealFix( approx.d1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  
								vyGraphBase.String( xi + wi, yi + dsr + 20, "Syntax8.Scn.Fnt", string );  

								string := "";  vyStrings.AppendRealFix( approx.a2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c2, 1, 0, 0, string );  
								vyGraphBase.SetStringJustification( vyGraphBase.right, vyGraphBase.top );  
								vyGraphBase.String( xi + wi, yi + hi - 20, "Syntax8.Scn.Fnt", string );  string := "";  
								vyStrings.AppendRealFix( approx.d2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee2, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + hi, "Syntax8.Scn.Fnt", string );  
							
							END;  
						END;  
					END;  *)
				END;  
			END;  
		
		END Display;  

		PROCEDURE LoadApproximation( VAR R: Files.Rider;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR version, n, i: SIGNED32;  a: LocalWedgeApproximation;  obj: Objects.Object;  
		BEGIN 
			Files.ReadLInt( R, version );  
			IF version < 0 THEN RETURN END;  
			IF approx = NIL THEN NEW( a );  approx := a;  ELSE a := approx( LocalWedgeApproximation ) END;  
			LoadApproximation^( R, approx );  Gadgets.ReadRef( R, lib, obj );  
			IF obj # NIL THEN a.line := obj( wedgeArrays.LineObject );  END;  
			Files.ReadLInt( R, a.linenr );  Gadgets.ReadRef( R, lib, obj );  
			IF obj # NIL THEN a.f := obj( wedgeFunctions2d.FunctionO ) END;  
			Files.ReadLInt( R, n );  
			IF n > 0 THEN 
				NEW( a.beta1, n );  
				FOR i := 0 TO n - 1 DO Files.ReadLReal( R, a.beta1[i] );  END;  
			END;  
			Files.ReadLInt( R, n );  
			IF n > 0 THEN 
				NEW( a.beta2, n );  
				FOR i := 0 TO n - 1 DO Files.ReadLReal( R, a.beta2[i] );  END;  
			END;  
		END LoadApproximation;  

		PROCEDURE StoreApproximation( VAR R: Files.Rider;  approx: wedgeTrees.LocalApproximation );  
		VAR a: LocalWedgeApproximation;  i: SIGNED32;  
		CONST version = 20050211;  
		BEGIN 
			IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  END;  
			Files.WriteLInt( R, version );  a := approx( LocalWedgeApproximation );  StoreApproximation^( R, a );  
			Gadgets.WriteRef( R, lib, a.line );  Files.WriteLInt( R, a.linenr );  Gadgets.WriteRef( R, lib, a.f );  
			Files.WriteLInt( R, LEN( a.beta1 ) );  
			FOR i := 0 TO LEN( a.beta1 ) - 1 DO Files.WriteLReal( R, a.beta1[i] );  END;  
			Files.WriteLInt( R, LEN( a.beta2 ) );  
			FOR i := 0 TO LEN( a.beta2 ) - 1 DO Files.WriteLReal( R, a.beta2[i] );  END;  
		END StoreApproximation;  

		PROCEDURE BindApproximation( VAR M: Objects.BindMsg;  approx: wedgeTrees.LocalApproximation );  
		BEGIN 
			IF (approx # NIL ) THEN BindObj( M, approx( LocalWedgeApproximation ).line );  END;  
			IF approx # NIL THEN BindObj( M, approx( LocalWedgeApproximation ).f );  END;  
		END BindApproximation;  

		PROCEDURE SetAngle*( alpha: FLOAT64 );  
		BEGIN 
			SELF.alpha := alpha;  
		END SetAngle;  

		PROCEDURE SetModelIndx*( modelindx: SIGNED32 );  
		BEGIN 
			SELF.modelindx := modelindx;  
		END SetModelIndx;  
	
	(*		PROCEDURE & Init;  
		BEGIN 
			useddata := NIL;   (* reset cache indicator *)
		END Init;  *)
	
	END WedgeModel;  
	
	PROCEDURE GenRectModel*;   (* do not rename, must be compatible with RectModel *)
	VAR q: RectModel;  
	BEGIN 
		aM.launch;  NEW( q );  Objects.NewObj := q;  
	END GenRectModel;  

	PROCEDURE GenWedgeModel*;   (* do not rename, must be compatible with QuadTree *)
	VAR q: WedgeModel;  
	BEGIN 
		NEW( q );  Objects.NewObj := q;  
	END GenWedgeModel;  

BEGIN 
END wedgeGenericModels.


(* old: 

	PROCEDURE constanteproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0;  
	END constanteproc;  

	PROCEDURE xproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 1.0 * x;  
	END xproc;  

	PROCEDURE yproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 1.0 * y;  
	
	END yproc;  

	PROCEDURE sinxhsinyhproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( x / 2.0 ) * Math.sin( y / 2.0 );  
	
	END sinxhsinyhproc;  

	PROCEDURE sinxsinyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( x ) * Math.sin( y );  
	
	END sinxsinyproc;  

	PROCEDURE sin2xsin2yproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( 2.0 * x ) * Math.sin( 2.0 * y );  
	
	END sin2xsin2yproc;  

(*Procedures used for testing on Barbara *)
	PROCEDURE cosxyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( x + y );  
	END cosxyproc;  

	PROCEDURE cos2xyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( 2 * (x + y) );  
	END cos2xyproc;  

	PROCEDURE cosxmyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( x - y );  
	END cosxmyproc;  

	PROCEDURE cos2xmyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( 2.0 * (1.0 * x - 1.0 * y) );  
	END cos2xmyproc;  

	PROCEDURE sinxyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( x + y );  
	END sinxyproc;  

	PROCEDURE sin2xyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( 2.0 * (x + y) );  
	END sin2xyproc;  

	PROCEDURE sinxmyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( x - y );  
	END sinxmyproc;  

	PROCEDURE sin2xmyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( 2.0 * (1.0 * x - 1.0 * y) );  
	END sin2xmyproc;  

	PROCEDURE cos2xproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( 2.0 * x );  
	
	END cos2xproc;  

	PROCEDURE cosxproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( 1.0 * x );  
	
	END cosxproc;  

	PROCEDURE cos2yproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( 2.0 * y );  
	
	END cos2yproc;  

	PROCEDURE cosyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( y );  
	
	END cosyproc;  

	PROCEDURE sin2xproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( 2.0 * x );  
	
	END sin2xproc;  

	PROCEDURE sinxproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( x );  
	
	END sinxproc;  

	PROCEDURE sin2yproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( 2.0 * y );  
	
	END sin2yproc;  

	PROCEDURE sinyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.sin( y );  
	
	END sinyproc;  

	PROCEDURE cosxcosyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN 100.0 * Math.cos( x ) * Math.cos( y );  
	
	END cosxcosyproc;  

	PROCEDURE xyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN x * y * 10.0;  
	
	END xyproc;  

	PROCEDURE xxproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN x * x * 10.0;  
	
	END xxproc;  

	PROCEDURE yyproc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN y * y * 10.0;  
	
	END yyproc;  

	PROCEDURE y4proc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN y * y * y * y * 1.0;  
	
	END y4proc;  

	PROCEDURE x4proc*( x, y: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN x * x * x * x * 1.0;  
	
	END x4proc;  
*) 