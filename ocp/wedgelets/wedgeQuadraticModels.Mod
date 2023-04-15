MODULE wedgeQuadraticModels IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT wedgeTrees, wedgeArrays, antsArrayObjects, Math := MathL IN A2, aM := antsMessages, Out, Files,Objects,vyGraphBase, vyStrings := vyHostStrings, Gadgets;  

TYPE 
	
	LocalRectApproximation = OBJECT (wedgeTrees.LocalApproximation) (* local approximation belonging to RectModel *)
	VAR c, a, b, d, e, ee: FLOAT64;   (* Quadratic model: y = ax2 + bxy + cy2 + dx + ey+ ee  *)
	END LocalRectApproximation;  
	
	RectModel* = OBJECT (wedgeTrees.Model) (*! maybe as extension of constant model *)
	VAR linehor-: wedgeArrays.LineObject;  
		(* linehor = line object defined by angle zero , needed  for calculation of rectSumZ and rectSumZZ*)
		colM: wedgeArrays.QMoments;  
		rectM: wedgeArrays.QMomentsO;  
		
		(* new in  Quadratic model: *)
		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		VAR w, h: SIGNED32;  
		BEGIN 
			wedgeArrays.ComputeColSumsQ( data, colM );   (**)
			NEW( linehor, 10000, 0, LEN( data[0] ), LEN( data ) );   (**)
			wedgeArrays.MakeMomentOQ( colM, linehor, rectM );   (**)
		END PrepareApproximation;  

		PROCEDURE Approximate( x, y, w, h: SIGNED32;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: LocalRectApproximation;  c, ssq, a, b, d, e, ee: FLOAT64;  penalty: FLOAT64; 
		BEGIN 
			IF (w < 2) OR (h < 2) THEN RETURN END;  
			IF penaltyadaptive THEN penalty := w* SELF.penalty ELSE penalty := SELF.penalty END;
			
			wedgeArrays.RectStatQ( rectM, x, y, w, h, ssq, c, a, b, d, e, ee ); 
			(*aM.dSRSR( "a=      ", a, "b=", b );
			aM.dSRSR( "c=      ", c, "d=", d );
            aM.dSRSR( "e=      ", e, "ee=", ee );*)


			aM.dSISI( "x=", x, "y=", y );  aM.dSISI( "w=", w, "h=", h );  
			aM.dSR( "ssq=", ssq );  
			
			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				local := approx( LocalRectApproximation );  
				IF local.distance <= ssq THEN RETURN END;  
			ELSE NEW( local );  
			END;  
				local.c := c;  local.distance := ssq;  local.a := a;  local.b := b;  local.d := d;  local.e := e;  local.ee := ee;  
			local.penalty := penalty;   (* that is 6 parameters  *)
			approx := local;  
			(*aM.dSRSR( "local.a=      ", local.a, "local.b=", local.b );
			aM.dSRSR( "local.c=      ", local.c, "local.d=", local.d );
			aM.dSRSR( "local.e=      ", local.e, "local.ee=", local.ee ); *)

		END Approximate;  

		PROCEDURE Reconstruct( x, y, w, h: SIGNED32;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR xx, yy: SIGNED32;  c: FLOAT64;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 
				aM.dSRSR( "approx.a=", approx.a, "     approx.b", approx.b );  
				aM.dSRSR( "approx.c=", approx.c, "     approx.d", approx.d );  
				aM.dSRSR( "approx.e=", approx.e, "     approx.ee", approx.ee );  
				
					wedgeArrays.FillRectLinQ( reco, x, y, w, h, approx.a, approx.b, approx.c, approx.d, approx.e, approx.ee );  
			END;  
		END Reconstruct;  

		PROCEDURE Display( x, y, w, h: SIGNED32;  approx: wedgeTrees.LocalApproximation;  mode: SIGNED32 );  
		VAR xi, yi, wi, hi: SIGNED16;  
			string: ARRAY 128 OF CHAR;  
		BEGIN 
			WITH approx: LocalRectApproximation DO 
				vyGraphBase.Rect2dToRect( x, y, w, h, xi, yi, wi, hi );  
				vyGraphBase.FrameRect( xi, yi, wi + 1, hi + 1 );  
				IF mode > wedgeTrees.simple THEN 
					IF (wi > 60) & (hi > 20) THEN 
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.a, 1, 0, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.b, 1, 0, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.c, 1, 0, 0, string );  

						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( xi + wi DIV 2, yi + hi DIV 2-10, "Syntax8.Scn.Fnt", string );  
						vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  string := "";  
						vyStrings.AppendRealFix( approx.d, 1, 0, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.e, 1, 0, 0, string );  vyStrings.Append( string, "," );  
						vyStrings.AppendRealFix( approx.ee, 1, 0, 0, string );  

						vyGraphBase.SetStringJustification( vyGraphBase.center, vyGraphBase.center );  
						vyGraphBase.String( xi + wi DIV 2, yi + hi DIV 2+10, "Syntax8.Scn.Fnt", string );  

					END;  
				END;  
			END;  
		END Display;  
		
		PROCEDURE LoadApproximation( VAR R: Files.Rider;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR version: SIGNED32;  a: LocalRectApproximation;  
		BEGIN 
			Files.ReadLInt( R, version );  
			IF version < 0 THEN RETURN END;  
			IF approx = NIL THEN NEW( a );  approx := a;  ELSE a := approx( LocalRectApproximation ) END;  
			LoadApproximation^( R, approx );  Files.ReadLReal( R, a.a );  Files.ReadLReal( R, a.b );  Files.ReadLReal( R, a.c ); 
			 Files.ReadLReal( R, a.d );  Files.ReadLReal( R, a.e );  Files.ReadLReal( R, a.ee ); 
		END LoadApproximation;  

		PROCEDURE StoreApproximation( VAR R: Files.Rider;  approx: wedgeTrees.LocalApproximation );  
		VAR a: LocalRectApproximation;  
		CONST version = 20040802;  
		BEGIN 
			IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  END;  
			Files.WriteLInt( R, version );  a := approx( LocalRectApproximation );  StoreApproximation^( R, a );  
			Files.WriteLReal( R, a.a );  Files.WriteLReal( R, a.b);  Files.WriteLReal( R, a.c);
			Files.WriteLReal( R, a.e );  Files.WriteLReal( R, a.e);  Files.WriteLReal( R, a.ee);
		END StoreApproximation;  
		
		PROCEDURE & Init*;   (* can be used by implementation to initialize variables etc. *)
		BEGIN 
			Init^;  penalty := 6; (* might be modified, this is the default value *)
		END Init;  

	END RectModel;  
	
	
TYPE
	LocalWedgeApproximation = OBJECT (wedgeTrees.LocalApproximation)
	VAR a1, b1, c1, a2, b2, c2, d1, e1, ee1, d2, e2, ee2: FLOAT64;  
		line: wedgeArrays.LineObject;  
		linenr: SIGNED32;  
	END LocalWedgeApproximation;  
	
	WedgeModel* = OBJECT (wedgeTrees.Model)
	VAR line-, linehor-: wedgeArrays.LineObject;  
		(* line = line object defined by angle alpha , needed  for calculation of trapezeSumZ, trapezeSumZZ and in the local approximation *)
		(* linehor = line object defined by angle zero , needed  for calculation of rectSumZ and rectSumZZ*)
		useddata-: antsArrayObjects.tLONGREALArray;   (* cache indicator *)
		colM: wedgeArrays.QMoments;  
		rectM: wedgeArrays.QMomentsO;  
		trapezeM: wedgeArrays.QMomentsO;  
		alpha-: FLOAT64;   (* angle *)
		
		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		VAR dx, dy, w, h: SIGNED32;  
		BEGIN 
			w := LEN( data[0] );  h := LEN( data );  
			IF useddata # data THEN  (* very first call, prepare basic matrices *)
				wedgeArrays.ComputeColSumsQ( data, colM );   (**)
				NEW( linehor, 10000, 0, LEN( data[0] ), LEN( data ) );   (**)
				wedgeArrays.MakeMomentOQ( colM, linehor, rectM );   (**)
			END;  
			
			dx := ENTIER( Math.cos( alpha * Math.pi / 180 ) * 100000 );  dy := ENTIER( Math.sin( alpha * Math.pi / 180 ) * 100000 );  
			NEW( line, dx, dy, w, h );   (* reference line to angle alpha *)
			wedgeArrays.MakeMomentOQ( colM, line, trapezeM );  
		END PrepareApproximation;  

		PROCEDURE Approximate( x, y, w, h: SIGNED32;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR local: LocalWedgeApproximation;  ssq, a1, b1, c1, a2, b2, c2, d1, e1, ee1, d2, e2, ee2: FLOAT64;  linelen, linenr: SIGNED32;  penalty: FLOAT64;
		BEGIN 
			wedgeArrays.GetBestWedgeQ( rectM, trapezeM, x, y, w, h, linenr, linelen, a1, b1, c1, d1, e1, ee1, a2, b2, c2, d2, e2, ee2, 
															    ssq );  
				IF penaltyadaptive THEN penalty := w* SELF.penalty ELSE penalty := SELF.penalty END; 

			IF approx # NIL THEN  (* there has been some approximation of this model already *)
				ASSERT ( approx.penalty = penalty );  
				IF approx.distance <= ssq THEN RETURN END;   (* there is already a better approximation *)
				local := approx( LocalWedgeApproximation );  
			ELSE NEW( local );  
			END;  
			local.penalty := penalty;  local.c1 := c1;  local.c2 := c2;  local.a1 := a1;  local.b1 := b1;  local.a2 := a2;  local.b2 := b2;  
			local.d1 := d1;  local.d2 := d2;  local.e1 := e1;  local.e2 := e2;  local.ee1 := ee1;  local.ee2 := ee2;  
			local.linenr := linenr;  local.line := line;  local.distance := ssq;  

			approx := local;  
		END Approximate;  

		PROCEDURE Reconstruct( rx, ry, rw, rh: SIGNED32;  approx: wedgeTrees.LocalApproximation;  
											    reco: antsArrayObjects.tLONGREALArray );  
		VAR a1, b1, c1, d1, e1, ee1, a2, b2, c2, d2, e2, ee2: FLOAT64;  sx, sy, ex, ey, x, y: SIGNED32;  

			PROCEDURE swap( VAR x, y: SIGNED32 );   (*Swap of two SIGNED32s*)
			VAR temp: SIGNED32;  
			BEGIN 
				temp := x;  x := y;  y := temp;  
			END swap;  

		BEGIN 
			WITH approx: LocalWedgeApproximation DO 
				a1 := approx.a1;  a2 := approx.a2;  b1 := approx.b1;  b2 := approx.b2;  c1 := approx.c1;  c2 := approx.c2;  
				d1 := approx.d1;  d2 := approx.d2;  e1 := approx.e1;  e2 := approx.e2;  ee1 := approx.ee1;  ee2 := approx.ee2;  

				wedgeArrays.FillRectLinQ( reco, rx, ry, rw, rh, a2, b2, c2, d2, e2, ee2 );   (* fill rectangle with upmean *)
				IF ~approx.line.IntersectWRect( approx.linenr, rx, ry, rw, rh, sx, sy, ex, ey ) THEN HALT( 100 ) END;  
				
				IF ~approx.line.vertical THEN 
					IF sx > ex THEN swap( ex, sx );  swap( ey, sy ) END;  
					FOR x := sx TO ex DO 
						y := approx.line.GetY( approx.linenr, x );  
						wedgeArrays.FillVLineQ( reco, x, ry, y - ry + 1, a1, b1, c1, d1, e1, ee1 );  
					END;  
				ELSE  (*vertical*)
					IF sy > ey THEN swap( ex, sx );  swap( ey, sy ) END;  
					FOR y := sy TO ey DO 
						x := approx.line.GetX( approx.linenr, y );  
						wedgeArrays.FillVLineQ( reco, x, ry, y - ry + 1, a1, b1, c1, d1, e1, ee1 );  
					END;  
				END;  
				IF sx > ex THEN swap( ex, sx );  swap( ey, sy ) END;  
				
				IF (sx > rx) & (sy > ry) THEN wedgeArrays.FillRectLinQ( reco, rx, ry, sx - rx, sy - ry + 1, a1, b1, c1, d1, e1, ee1 );  
				END;  
				IF (ex < rx + rw - 1) & (ey > ry) THEN 
					wedgeArrays.FillRectLinQ( reco, ex + 1, ry, rx + rw - ex - 1, ey - ry + 1, a1, b1, c1, d1, e1, ee1 );  
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
					
					IF mode > wedgeTrees.simple THEN 
						IF (wi > 80) & (hi > 20) THEN 
							vyGraphBase.SetForeColor( vyGraphBase.S.fillcol );  
							IF (Sgn( line.dx ) = Sgn( line.dy )) THEN 
								string := "";  
								vyGraphBase.SetStringJustification( vyGraphBase.right, vyGraphBase.bottom ); 
								vyStrings.AppendRealFix( approx.a1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + dsr, "Syntax8.Scn.Fnt", string );  
								string := ""; 
								vyStrings.AppendRealFix( approx.d1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + dsr+20, "Syntax8.Scn.Fnt", string );  

								string := "";  vyStrings.AppendRealFix( approx.a2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c2, 1, 0, 0, string );  
								vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.top );  
								vyGraphBase.String( xi, yi + hi-20, "Syntax8.Scn.Fnt", string );  
								string := ""; 
								vyStrings.AppendRealFix( approx.d2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee2, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + hi, "Syntax8.Scn.Fnt", string );  

							ELSE 
								string := "";
								vyGraphBase.SetStringJustification( vyGraphBase.left, vyGraphBase.bottom ); 
								vyStrings.AppendRealFix( approx.a1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi, yi + dsr, "Syntax8.Scn.Fnt", string );  
								string := "";
								vyStrings.AppendRealFix( approx.d1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e1, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee1, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + dsr+20, "Syntax8.Scn.Fnt", string );  

								string := "";  vyStrings.AppendRealFix( approx.a2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.b2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.c2, 1, 0, 0, string );  
								vyGraphBase.SetStringJustification( vyGraphBase.right, vyGraphBase.top );  
								vyGraphBase.String( xi + wi, yi + hi-20, "Syntax8.Scn.Fnt", string );  
								string := ""; 
								vyStrings.AppendRealFix( approx.d2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.e2, 1, 0, 0, string );  vyStrings.Append( string, "," );  
								vyStrings.AppendRealFix( approx.ee2, 1, 0, 0, string );  
								vyGraphBase.GetStringSize( string, "Syntax8.Scn.Fnt", temp, temp, dsr );  vyGraphBase.String( xi + wi, yi + hi, "Syntax8.Scn.Fnt", string );  
								
							END;  
						END;  
					END;  
				END;  
			END;  
		
		END Display;  
		
		PROCEDURE LoadApproximation( VAR R: Files.Rider;  VAR approx: wedgeTrees.LocalApproximation );  
		VAR version: SIGNED32;  a: LocalWedgeApproximation;  obj: Objects.Object;  
		BEGIN 
			Files.ReadLInt( R, version );  
			IF version < 0 THEN RETURN END;  
			IF approx = NIL THEN NEW( a );  approx := a;  ELSE a := approx( LocalWedgeApproximation ) END;  
			LoadApproximation^( R, approx );  
			Files.ReadLReal( R, a.a1 );  Files.ReadLReal( R, a.a2 );  
			Files.ReadLReal( R, a.b1 );  Files.ReadLReal( R, a.b2 );  
			Files.ReadLReal( R, a.c1 );  Files.ReadLReal( R, a.c2 );
			Files.ReadLReal( R, a.d1 );  Files.ReadLReal( R, a.e1 );  
			Files.ReadLReal( R, a.d2 );  Files.ReadLReal( R, a.e2 );
			Files.ReadLReal( R, a.ee1 );  Files.ReadLReal( R, a.ee2 );
			Gadgets.ReadRef( R, lib, obj );  
			IF obj # NIL THEN a.line := obj( wedgeArrays.LineObject );  END;  
			Files.ReadLInt( R, a.linenr );  
		END LoadApproximation;  

		PROCEDURE StoreApproximation( VAR R: Files.Rider;  approx: wedgeTrees.LocalApproximation );  
		VAR a: LocalWedgeApproximation;  
		CONST version = 20040802;  
		BEGIN 
			IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  END;  
			Files.WriteLInt( R, version );  a := approx( LocalWedgeApproximation );  StoreApproximation^( R, a );  
			Files.WriteLReal( R, a.a1 );  Files.WriteLReal( R, a.a2 );  
			Files.WriteLReal( R, a.b1 );  Files.WriteLReal( R, a.b2 );  
			Files.WriteLReal( R, a.c1 );  Files.WriteLReal( R, a.c2 );  
			Files.WriteLReal( R, a.d1 );  Files.WriteLReal( R, a.e1 );  
			Files.WriteLReal( R, a.d2 );  Files.WriteLReal( R, a.e2 );
			Files.WriteLReal( R, a.ee1 );  Files.WriteLReal( R, a.ee2 );
			Gadgets.WriteRef( R, lib, a.line );  
			Files.WriteLInt( R, a.linenr );  
		END StoreApproximation;  

		PROCEDURE BindApproximation( VAR M: Objects.BindMsg;  approx: wedgeTrees.LocalApproximation );  
		BEGIN 
			IF (approx # NIL ) THEN BindObj( M, approx( LocalWedgeApproximation ).line );  END;  
		END BindApproximation;  

		PROCEDURE SetAngle*( alpha: FLOAT64 );  
		BEGIN 
			SELF.alpha := alpha;  
		END SetAngle;  

		PROCEDURE & Init;  
		BEGIN 
			useddata := NIL; Init^;  penalty := 12;  pieces := 2; (* reset cache indicator *)
		END Init;  

	END WedgeModel;  
	
	PROCEDURE GenWedgeModel*;   (* do not rename, must be compatible with QuadTree *)
	VAR q: WedgeModel;  
	BEGIN 
		NEW( q );  Objects.NewObj := q;  
	END GenWedgeModel;  
	
	PROCEDURE GenRectModel*;   (* do not rename, must be compatible with RectModel *)
	VAR q: RectModel;  
	BEGIN 
		aM.launch;  NEW( q );  Objects.NewObj := q;  
	END GenRectModel;  


BEGIN 
END wedgeQuadraticModels.
