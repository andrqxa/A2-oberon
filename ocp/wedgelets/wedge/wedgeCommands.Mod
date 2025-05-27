MODULE wedgeCommands IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Out, antsArrayObjects, antsCommands, vyBase, wedgeTrees, wedgeConstantModels, wedgeLinearModels, 
	wedgeGenericModels, wedgeQuadraticModels, antsArrays, aM := antsMessages, antsHistogramEdit, vyName, 
	Math := MathL IN A2, vyLongrealVec, antsArrayPictures16, antsArrayImages16, antsImageViews, vyPort, antsPictCoordinate, 
	Objects, antsPictureViews, antsToolbox, wedgeTreePlot, Attributes, wedgeFunctions2d, AosOut := Out IN A2, antsReadWrite, 
	antsRegions, Files, antsFiles;  

TYPE 
	ssqObject = OBJECT 
	VAR ssq, penalty: FLOAT64;  
		t: wedgeTrees.QuadTree;  
		
		PROCEDURE Compute( node: wedgeTrees.QNode );  
		BEGIN 
			IF node.active # NIL THEN ssq := ssq + node.active.distance;  penalty := penalty + node.active.penalty;  RETURN;  END;  
			
			IF node.ll # NIL THEN Compute( node.ll )
			END;  
			IF node.lr # NIL THEN Compute( node.lr ) END;  
			IF node.ul # NIL THEN Compute( node.ul ) END;  
			IF node.ur # NIL THEN Compute( node.ur ) END;  
		END Compute;  

		PROCEDURE PSNR( ): FLOAT64;  
		VAR mse: FLOAT64;  PSNR, tmp: FLOAT64;  
		BEGIN 
			ssq := 0;  penalty := 0;  Compute( t.root );  mse := ssq / (t.w * t.h);  tmp := t.colordepth * t.colordepth / mse;  
			PSNR := 10 * Math.ln( tmp ) / Math.ln( 10 );  RETURN PSNR;  
		END PSNR;  

		PROCEDURE & Init( t: wedgeTrees.QuadTree );  
		BEGIN 
			ssq := 0;  SELF.t := t;  
		END Init;  

	END ssqObject;  
	
	PROCEDURE NewConstRectModel*;  
	VAR m: wedgeConstantModels.RectModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  END;  
	END NewConstRectModel;  

	PROCEDURE NewLinearRectModel*;  
	VAR m: wedgeLinearModels.RectModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  END;  
	END NewLinearRectModel;  

	PROCEDURE NewQuadraticRectModel*;  
	VAR m: wedgeQuadraticModels.RectModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  END;  
	END NewQuadraticRectModel;  

(*PROCEDURE NewGenericRectModel*;  
	VAR m: wedgeGenericModels.RectModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new rect model registered as ", name );  END;  
	END NewGenericRectModel;  
	*)

	PROCEDURE MakeFunctionsFromStrings( p: antsCommands.tParameter ): wedgeFunctions2d.FunctionO;  
	VAR f: wedgeGenericModels.Function2dArray;  i, n: SIZE;  o: wedgeFunctions2d.FunctionO;  
		nameList: ARRAY 64 OF ARRAY 1024 OF CHAR;   (* replace by queue *)
	BEGIN 
		IF p = NIL THEN aM.eS( 'Error: functions have to be provided in the form functions = "f1" "f2" "f3" ... ' );  HALT( 100 );  END;  
		WHILE p # NIL DO COPY( p( antsCommands.tString ).string, nameList[i] );  INC( i );  p := p.next;  END;  
		AosOut.String( "NEW(o)" );  AosOut.Ln;  NEW( o );  AosOut.String( "o.Make" );  AosOut.Ln;  o.Make( nameList, i );  RETURN o;  
	
	END MakeFunctionsFromStrings;  

	PROCEDURE NewGenericRectModel*;  
	VAR m: wedgeGenericModels.RectModel;  f: wedgeFunctions2d.FunctionO;  
		name: ARRAY 256 OF CHAR;  
		i, n: SIZE;  p: antsCommands.tParameter;  
		nameList: ARRAY 64 OF ARRAY 1024 OF CHAR;   (* replace by queue *)
		l: antsCommands.tScanList;  
		phi: POINTER TO ARRAY OF SIZE;  
	BEGIN 
		antsCommands.InitScan( "name= NAME functions={STRING}" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  p := antsCommands.ParsFromKeyword( l, "functions" );  
			f := MakeFunctionsFromStrings( p );  m.SetFunctions( f );  aM.SS( "new rect model registered as ", name );  
		END;  
	END NewGenericRectModel;  

	PROCEDURE NewModelTest*;  
	VAR m: wedgeGenericModels.RectModel;  f: wedgeFunctions2d.FunctionO;  
		name: ARRAY 256 OF CHAR;  
		i, n, w, h, stringlength, number: SIZE;  p: antsCommands.tParameter;  
		nameList: ARRAY 64 OF ARRAY 1024 OF CHAR;   (* replace by queue *)
		l: antsCommands.tScanList;  
		phi: POINTER TO ARRAY OF SIZE;  
		tree: vyBase.Object;  region: antsRegions.tRegion;  
	BEGIN 
		antsCommands.InitScan( "name= NAME tree=OBJ functions={STRING} nbregions=NUMBER" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectObject( "tree", tree ) & 
		    antsCommands.ExpectSize( "number", number ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				NEW( m );  vyName.RegisterNamed( m, name );  stringlength := 0;  
				IF antsCommands.Find( "functions" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "functions" );  f := MakeFunctionsFromStrings( p );  stringlength := LEN( f.fa );  
				END;  
				
				w := tree.w;  h := tree.h;  Out.String( "number : " );  Out.Int( SIGNED32(number), 6 );  Out.Ln;  Out.String( "stringlength : " );  Out.Int( SIGNED32(stringlength), 6 );  
				Out.Ln;  

				m.InitPhi( number + stringlength );  antsRegions.Gen;  region := Objects.NewObj( antsRegions.tRegion );  
				FOR i := 0 TO number - 1 DO m.SetFunctionsFromArray( region, i );  END;  
				FOR i := 0 TO stringlength - 1 DO m.phi.fa[i + number] := f.fa[i];  END;  
			
			END;  
		END;  
	END NewModelTest;  

	PROCEDURE SetPenalty*;  
	VAR model: vyBase.Object;  penalty: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " model=OBJECT penalty= REAL" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectReal( "penalty", penalty ) THEN 
			WITH model: wedgeTrees.Model DO model.penalty := penalty;  
			END;  
		END;  
	END SetPenalty;  

	PROCEDURE PenaltyAdaptive*;  
	VAR model: vyBase.Object;  
		adaptive: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "model=OBJECT adaptive=(YES|NO)" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectName( "adaptive", adaptive ) THEN 
			WITH model: wedgeTrees.Model DO 
				IF adaptive[0] = "Y" THEN model.penaltyadaptive := TRUE;  
				ELSIF adaptive[0] = "N" THEN model.penaltyadaptive := FALSE;  
				ELSE aM.eS( "I don't understand what you want.  I  would understand an adaptive = YES or an adaptive = NO." );  
				END;  
			END;  
		END;  
	END PenaltyAdaptive;  

	PROCEDURE PlugInCRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeConstantModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeConstantModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: wedgeTrees.QuadTree DO tree.PlugIn( model, name, MAX( SIZE ) );  
			END;  
		END;  
	END PlugInCRect;  

	PROCEDURE PlugInLRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeLinearModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeLinearModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: wedgeTrees.QuadTree DO tree.PlugIn( model, name, MAX( SIZE ) );  
			END;  
		END;  
	END PlugInLRect;  

	PROCEDURE PlugInQRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeQuadraticModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeQuadraticModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: wedgeTrees.QuadTree DO tree.PlugIn( model, name, MAX( SIZE ) );  
			END;  
		END;  
	END PlugInQRect;  

	PROCEDURE PlugInGRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeGenericModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
		l: antsCommands.tScanList;  p: antsCommands.tParameter;  f: wedgeFunctions2d.FunctionO;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeGenericModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			p := antsCommands.ParsFromKeyword( l, "functions" );  f := MakeFunctionsFromStrings( p );  model.SetFunctions( f );  
			WITH tree: wedgeTrees.QuadTree DO tree.PlugIn( model, name, MAX( SIZE ) );  
			END;  
		END;  
	END PlugInGRect;  

	PROCEDURE NewConstWedgeModel*;  
	VAR m: wedgeConstantModels.WedgeModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new wedge model registered as ", name );  END;  
	END NewConstWedgeModel;  

	PROCEDURE SetConstAngle*;  
	VAR model: vyBase.Object;  alpha: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "model= OBJ alpha=REAL" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectReal( "alpha", alpha ) THEN 
			WITH model: wedgeConstantModels.WedgeModel DO model.SetAngle( alpha );  aM.SR( "set angle for wegde model ", alpha );  
			END;  
		END;  
	END SetConstAngle;  

	PROCEDURE NewLinearWedgeModel*;  
	VAR m: wedgeLinearModels.WedgeModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new wedge model registered as ", name );  END;  
	END NewLinearWedgeModel;  

	PROCEDURE SetLinearAngle*;  
	VAR model: vyBase.Object;  alpha: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "model= OBJ alpha=REAL" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectReal( "alpha", alpha ) THEN 
			WITH model: wedgeLinearModels.WedgeModel DO model.SetAngle( alpha );  aM.SR( "set angle for wegde model ", alpha );  
			END;  
		END;  
	END SetLinearAngle;  

	PROCEDURE NewQuadraticWedgeModel*;  
	VAR m: wedgeQuadraticModels.WedgeModel;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name= NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN NEW( m );  vyName.RegisterNamed( m, name );  aM.SS( "new wedge model registered as ", name );  END;  
	END NewQuadraticWedgeModel;  

	PROCEDURE SetQuadraticAngle*;  
	VAR model: vyBase.Object;  alpha: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "model= OBJ alpha=REAL" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectReal( "alpha", alpha ) THEN 
			WITH model: wedgeQuadraticModels.WedgeModel DO model.SetAngle( alpha );  aM.SR( "set angle for wegde model ", alpha );  
			END;  
		END;  
	END SetQuadraticAngle;  

	PROCEDURE NewGenericWedgeModel*;  
	VAR m: wedgeGenericModels.WedgeModel;  
		name: ARRAY 256 OF CHAR;  
		l: antsCommands.tScanList;  p: antsCommands.tParameter;  f: wedgeFunctions2d.FunctionO;  
	BEGIN 
		antsCommands.InitScan( "name= NAME functions={STRING}" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			NEW( m );  vyName.RegisterNamed( m, name );  p := antsCommands.ParsFromKeyword( l, "functions" );  
			f := MakeFunctionsFromStrings( p );  m.SetFunctions( f );  aM.SS( "new wedge model registered as ", name );  
		END;  
	END NewGenericWedgeModel;  

	PROCEDURE SetGenericAngle*;  
	VAR model: vyBase.Object;  alpha: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "model= OBJ alpha=REAL" );  
		IF antsCommands.ExpectObject( "model", model ) & antsCommands.ExpectReal( "alpha", alpha ) THEN 
			WITH model: wedgeGenericModels.WedgeModel DO model.SetAngle( alpha );  aM.SR( "set angle for wegde model ", alpha );  
			END;  
		END;  
	END SetGenericAngle;  

	PROCEDURE GreatestDivisorPower2( i: SIZE ): SIZE;  
	VAR j, k: SIZE;  
	BEGIN 
		j := 1;  k := 0;  
		WHILE ((i DIV j) * j = i) DO INC( k );  j := j * 2;  END;  
		RETURN k;  
	END GreatestDivisorPower2;  

	PROCEDURE PlugInCWedge*;   (* PlugIn constant wedge model with given angles, creates new model if none given *)
	VAR tree, obj: vyBase.Object;  p: antsCommands.tParameter;  name: vyName.tNameArray;  from, to, by: FLOAT64;  
		l: antsCommands.tScanList;  model: wedgeConstantModels.WedgeModel;  i, iterations, iter, offset: SIZE;  numberofangles: FLOAT64;  
		penalty: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME) (angles={REAL}| >steps from=REAL to=REAL by=REAL)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN model := obj( wedgeConstantModels.WedgeModel )
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			IF antsCommands.Find( "penalty" ) THEN 
				IF antsCommands.ExpectReal( "penalty", penalty ) THEN aM.SR( "Setting model penalty to ", penalty );  model.penalty := penalty END;  
			END;  
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  
				IF antsCommands.Find( "numberofangles" ) THEN 
					IF antsCommands.ExpectReal( "numberofangles", numberofangles ) THEN 
						iterations := ENTIER( numberofangles + 0.5 );  
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  
						END;  
					END;  
				ELSIF antsCommands.Find( "steps" ) THEN 
					IF antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
						WHILE (from <= to) DO 
							aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  from := from + ABS( by );  
						END;  
					END;  
				ELSIF antsCommands.Find( "angles" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "angles" );  
					IF (p = NIL ) & antsCommands.ExpectReal( "angles", by ) THEN END;  
					WHILE p # NIL DO 
						aM.SR( "setting angle: ", p( antsCommands.tReal ).real );  model.SetAngle( p( antsCommands.tReal ).real );  
						tree.PlugIn( model, name, MAX( SIZE ) );  p := p.next;  
					END;  
				ELSIF antsCommands.Find( "adaptive" ) THEN 
					IF antsCommands.ExpectSize( "numofangles", iterations ) & antsCommands.ExpectSize( "offset", offset ) THEN 
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.PlugIn( model, name, iter );  
						END;  
					END;  
				END;  
			END;  
		END;  
	
	END PlugInCWedge;  

	PROCEDURE PlugInLWedge*;   (* PlugIn constant wedge model with given angles, creates new model if none given *)
	VAR tree, obj: vyBase.Object;  p: antsCommands.tParameter;  name: vyName.tNameArray;  from, to, by: FLOAT64;  
		l: antsCommands.tScanList;  model: wedgeLinearModels.WedgeModel;  i, iterations, iter, offset: SIZE;  numberofangles: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME) (angles={REAL}| >steps from=REAL to=REAL by=REAL)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN model := obj( wedgeLinearModels.WedgeModel )
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  
				IF antsCommands.Find( "numberofangles" ) THEN 
					IF antsCommands.ExpectReal( "numberofangles", numberofangles ) THEN 
						iterations := ENTIER( numberofangles + 0.5 );  
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  
						END;  
					END;  
				ELSIF antsCommands.Find( "steps" ) THEN 
					IF antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
						WHILE (from <= to) DO 
							aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  from := from + ABS( by );  
						END;  
					END;  
				ELSIF antsCommands.Find( "angles" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "angles" );  
					IF (p = NIL ) & antsCommands.ExpectReal( "angles", by ) THEN END;  
					WHILE p # NIL DO 
						aM.SR( "setting angle: ", p( antsCommands.tReal ).real );  model.SetAngle( p( antsCommands.tReal ).real );  
						tree.PlugIn( model, name, MAX( SIZE ) );  p := p.next;  
					END;  
				ELSIF antsCommands.Find( "adaptive" ) THEN 
					IF antsCommands.ExpectSize( "numofangles", iterations ) & antsCommands.ExpectSize( "offset", offset ) THEN 
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.PlugIn( model, name, iter );  
						END;  
					END;  
				END;  
			END;  
		END;  
	
	END PlugInLWedge;  

	PROCEDURE PlugInQWedge*;   (* PlugIn constant wedge model with given angles, creates new model if none given *)
	VAR tree, obj: vyBase.Object;  p: antsCommands.tParameter;  name: vyName.tNameArray;  from, to, by: FLOAT64;  
		l: antsCommands.tScanList;  model: wedgeQuadraticModels.WedgeModel;  i, iterations, iter, offset: SIZE;  
		numberofangles: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME) (angles={REAL}| >steps from=REAL to=REAL by=REAL)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN model := obj( wedgeQuadraticModels.WedgeModel )
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  
				IF antsCommands.Find( "numberofangles" ) THEN 
					IF antsCommands.ExpectReal( "numberofangles", numberofangles ) THEN 
						iterations := ENTIER( numberofangles + 0.5 );  
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  
						END;  
					END;  
				ELSIF antsCommands.Find( "steps" ) THEN 
					IF antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
						WHILE (from <= to) DO 
							aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  from := from + ABS( by );  
						END;  
					END;  
				ELSIF antsCommands.Find( "angles" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "angles" );  
					IF (p = NIL ) & antsCommands.ExpectReal( "angles", by ) THEN END;  
					WHILE p # NIL DO 
						aM.SR( "setting angle: ", p( antsCommands.tReal ).real );  model.SetAngle( p( antsCommands.tReal ).real );  
						tree.PlugIn( model, name, MAX( SIZE ) );  p := p.next;  
					END;  
				ELSIF antsCommands.Find( "adaptive" ) THEN 
					IF antsCommands.ExpectSize( "numofangles", iterations ) & antsCommands.ExpectSize( "offset", offset ) THEN 
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.PlugIn( model, name, iter );  
						END;  
					END;  
				END;  
			END;  
		END;  
	
	END PlugInQWedge;  

	PROCEDURE PlugInGWedge*;   (* PlugIn constant wedge model with given angles, creates new model if none given *)
	VAR tree, obj: vyBase.Object;  p: antsCommands.tParameter;  name: vyName.tNameArray;  from, to, by: FLOAT64;  
		l: antsCommands.tScanList;  model: wedgeGenericModels.WedgeModel;  i, iterations, iter, offset, modelindx: SIZE;  
		f: wedgeFunctions2d.FunctionO;  numberofangles: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME) (angles={REAL}| >steps from=REAL to=REAL by=REAL) modelindx=NUMBER" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN model := obj( wedgeGenericModels.WedgeModel )
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			p := antsCommands.ParsFromKeyword( l, "functions" );  f := MakeFunctionsFromStrings( p );  model.SetFunctions( f );  
			
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  
				IF antsCommands.Find( "numberofangles" ) THEN 
					IF antsCommands.ExpectReal( "numberofangles", numberofangles ) THEN 
						iterations := ENTIER( numberofangles + 0.5 );  
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  
						END;  
					END;  
				ELSIF antsCommands.Find( "steps" ) THEN 
					IF antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
						WHILE (from <= to) DO 
							aM.SR( "setting angle: ", from );  model.SetAngle( from );  tree.PlugIn( model, name, MAX( SIZE ) );  from := from + ABS( by );  
						END;  
					END;  
				ELSIF antsCommands.Find( "angles" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "angles" );  
					IF (p = NIL ) & antsCommands.ExpectReal( "angles", by ) THEN END;  
					WHILE p # NIL DO 
						aM.SR( "setting angle: ", p( antsCommands.tReal ).real );  model.SetAngle( p( antsCommands.tReal ).real );  
						tree.PlugIn( model, name, MAX( SIZE ) );  p := p.next;  
					END;  
				ELSIF antsCommands.Find( "adaptive" ) THEN 
					IF antsCommands.ExpectSize( "numofangles", iterations ) & antsCommands.ExpectSize( "offset", offset ) THEN 
						FOR i := 1 TO iterations DO 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.PlugIn( model, name, iter );  
						END;  
					END;  
				END;  
			END;  
		END;  
	
	END PlugInGWedge;  

	PROCEDURE IntToReal*;  
	VAR src: vyBase.Object;  dest: antsArrayObjects.tLONGREALObject;  
		destname: ARRAY 256 OF CHAR;  
		obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT dest=NAME" );  
		IF antsCommands.ExpectObject( "source", src ) & antsCommands.ExpectName( "dest", destname ) THEN 
			WITH src: antsArrayObjects.tINTEGERObject DO 
				IF antsCommands.ExpectName( "dest", destname ) THEN 
					obj := vyName.FindObj( destname );  
					IF (obj # NIL ) & (obj IS antsArrayObjects.tLONGREALObject) THEN 
						WITH obj: antsArrayObjects.tLONGREALObject DO 
							antsArrayObjects.ChangeSize( obj, src.w, src.h );  dest := obj;  
							dest := obj; 
						END;  
						
					ELSE 
						dest := antsArrayObjects.NewLONGREALObject( src.w, src.h, 256 );  
						vyName.RegisterNamed( dest, destname );  
					END;  
				END;  
				antsArrayObjects.CopyIR( src.A, dest.A, 0, 0, src.w, src.h, 0, 0 );  vyBase.Update( dest );  
			END;  
		END;  
	END IntToReal;  

	PROCEDURE RealToInt*;  
	VAR src: vyBase.Object;  dest: antsArrayObjects.tINTEGERObject;  obj: vyBase.Object;  
		destname: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT dest=OBJECT|NAME" );  
		IF antsCommands.ExpectObject( "source", src ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
			(*Allows only conversion with depth 256*)
				IF antsCommands.GetObject( "dest", obj ) THEN 
					WITH obj: antsArrayObjects.tINTEGERObject DO antsArrayObjects.ChangeSize( obj, src.w, src.h );  dest := obj;  
					END;  
				ELSIF antsCommands.ExpectName( "dest", destname ) THEN 
					dest := antsArrayObjects.NewINTEGERObject( src.w, src.h, 256 );  vyName.RegisterNamed( dest, destname );  
				END;  
				
				antsArrayObjects.CopyRI( src.A, dest.A, 0, 0, src.w, src.h, 0, 0 );  vyBase.Update( dest );  
			END;  
		END;  
	END RealToInt;  

	PROCEDURE ToAsciiFile*;  
	VAR obj: vyBase.Object;  
		filename: ARRAY 256 OF CHAR;  
		r: antsReadWrite.Rider;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT filename=STRING" );  
		IF antsCommands.ExpectObject( "src", obj ) & antsCommands.ExpectString( "filename", filename ) THEN 
			IF obj IS antsArrayObjects.tLONGREALObject THEN 
				WITH obj: antsArrayObjects.tLONGREALObject DO 
					IF r.New( filename ) THEN 
						r.SetAscii;  r.WriteLInt( SIGNED32(obj.w) );  r.WriteLInt( SIGNED32(obj.h) );  r.WriteLn;  r.WriteMatrixX( obj.A^ );  r.Close;  
					ELSE aM.SS( "could not open file ", filename );  
					END;  
				END;  
			END;  
		END;  
	END ToAsciiFile;  

	PROCEDURE VectorsToAsciiFile*;  
	VAR objx, objy: vyBase.Object;  
		filename: ARRAY 256 OF CHAR;  
		i: SIZE;  r: antsReadWrite.Rider;  
	BEGIN 
		antsCommands.InitScan( "srcx=OBJECT srcy=OBJECT  filename=STRING" );  
		IF antsCommands.ExpectObject( "srcx", objx ) & antsCommands.ExpectObject( "srcy", objy ) & 
		    antsCommands.ExpectString( "filename", filename ) THEN 
			IF (objx IS vyLongrealVec.tVector) & (objy IS vyLongrealVec.tVector) THEN 
				WITH objx: vyLongrealVec.tVector DO 
					WITH objy: vyLongrealVec.tVector DO 
						IF vyLongrealVec.Len( objx ) # vyLongrealVec.Len( objy ) THEN aM.eS( "Vectors are not of same length" );  RETURN END;  
						IF r.New( filename ) THEN 
							r.SetAscii;  r.WriteLInt( SIGNED32(vyLongrealVec.Len( objx )) );  r.WriteLn;  
							FOR i := 0 TO vyLongrealVec.Len( objx ) - 1 DO 
								r.WriteLReal( vyLongrealVec.Get( objx, i ) );  r.WriteLReal( vyLongrealVec.Get( objy, i ) );  r.WriteLn;  
							END;  
							r.Close;  
						ELSE aM.SS( "could not open file ", filename );  
						END;  
					END;  
				END;  
			END;  
		END;  
	END VectorsToAsciiFile;  



(*procedure which converts ASCII data into an image in format pgm*)
	PROCEDURE ASCIIToPGMFile*;  
	VAR obj: vyBase.Object;  
		A: POINTER TO ARRAY OF ARRAY OF FLOAT64;  
		srcname, filename: ARRAY 256 OF CHAR;  
		ch: CHAR;  Rsrc: antsFiles.Rider;  R: antsReadWrite.Rider;  x, y, valint, width, height, depth: SIZE;  val: FLOAT64;  c: SIGNED32;
	BEGIN 
		depth := 255;   (*in this case depth is fixed to 255 *)
		antsCommands.InitScan( " srcfile=STRING  filename=STRING" );   (*warning: filename must allready contain .pgm *)
		
		IF antsCommands.ExpectString( "srcfile", srcname ) THEN 
			IF ~Rsrc.Old( srcname ) THEN aM.eSS( "could not open ", srcname );  RETURN END;  
			
			Rsrc.SetAscii;  Rsrc.ReadLInt( c); width := c;  Rsrc.ReadLInt( c ); height := c;  
			
			IF A = NIL THEN NEW( A, width, height );  
			END;  
			FOR y := 0 TO height - 1 DO 
				FOR x := 0 TO width - 1 DO Rsrc.ReadLReal( val );  A[y, x] := val;  END;  
			END;  
			
			IF antsCommands.ExpectString( "filename", filename ) THEN 
				IF R.New( filename ) THEN R.SetAscii;  R.WriteString( "P2" );  R.Write( antsFiles.LF );  R.WriteString( "# obtained by Oberon after conversion of a float array" );  

					R.Write( antsFiles.LF );  R.WriteLInt( SIGNED32(width) );  R.WriteLInt( SIGNED32(height) );  R.Write( antsFiles.LF );  
					R.WriteLInt( c); depth := c;  R.Write( antsFiles.LF );  
					
					FOR y := height - 1 TO 0 BY -1 DO 
						FOR x := 0 TO width - 1 DO 
							valint := ENTIER( A[y, x] + 0.5 );  
							
							IF valint < 0 THEN valint := 0;  
							END;  
							IF valint > 255 THEN valint := 255;  END;  
							R.WriteLInt( SIGNED32(valint) );  
						END;  
						R.Write( antsFiles.LF );  
					END;  
				END;  
				
				R.Close;  
			END;  
		END;  
		
		(*WHILE ~Rsrc.eot DO 
			Rsrc.Read( ch )
		END;  *)
		Rsrc.Close;  
	
	END ASCIIToPGMFile;  

	PROCEDURE NewTree*;  
	VAR src, obj: vyBase.Object;  tree: wedgeTrees.QuadTree;  
		name: ARRAY 256 OF CHAR;  
		maxdepth: SIZE;   (* array: antsArrayObjects.tLONGREALArray;  data: antsArrayObjects.tLONGREALObject;  *)
	BEGIN 
		antsCommands.InitScan( "src=OBJECT tree=OBJECT|NAME [maxdepth=NUMBER]" );  
		IF antsCommands.ExpectObject( "source", src ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
			(* antsArrayObjects.CopyIR( src.A, array, 0, 0, src.w, src.h, 0, 0 );   
				data := src.A; antsArrayObjects.RealObj( array, src.depth );  data.depth := src.depth;  *)
			
			(* maxdepth = 0 corresponds to refienement of the tree, as long as possible *)
				IF ~antsCommands.GetSize( "maxdepth", maxdepth ) THEN maxdepth := 0 END;  
				
				IF antsCommands.Find( "forceNew" ) OR (~antsCommands.GetObject( "tree", obj )) THEN 
					IF antsCommands.ExpectName( "tree", name ) THEN NEW( tree );  vyName.RegisterNamed( tree, name );  ELSE RETURN END;  
					aM.SS( "Freshly created tree: ", name );  
				ELSE tree := obj( wedgeTrees.QuadTree );  vyName.GetObjId( obj, name );  aM.SS( "Using existing tree: (use >forceNew to override) ", name );  tree.Init;  
				END;  
				
				tree.Create( src, maxdepth );   (* tree creation *)
				aM.S( "tree generation done." );  aM.SI( "maxdepth = ", maxdepth );  
			END;  
		END;  
	END NewTree;  

	PROCEDURE PlugIn*;  
	VAR tree, model: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ model=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  tree.PlugIn( model( wedgeTrees.Model ), name, MAX( SIZE ) );  
			END;  
		END;  
	END PlugIn;  

	PROCEDURE Remove*;  
	VAR tree, model: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ model=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				vyName.GetObjId( model, name );  tree.Remove( model( wedgeTrees.Model ) );  
			END;  
		END;  
	END Remove;  

	PROCEDURE RemoveAll*;  
	VAR tree: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			WITH tree: wedgeTrees.QuadTree DO tree.RemoveAll();  
			END;  
		END;  
	
	END RemoveAll;  

	PROCEDURE Minimize*;  
	VAR tree: vyBase.Object;  name: vyName.tNameArray;  gamma, value: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ gamma=REAL" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.Find( "loggamma" ) & antsCommands.ExpectReal( "loggamma", gamma ) THEN 
				gamma := Math.exp( gamma * Math.ln( 10 ) );  
			ELSIF ~antsCommands.ExpectReal( "gamma", gamma ) THEN RETURN 
			END;  
			WITH tree: wedgeTrees.QuadTree DO value := tree.Minimize( gamma );  aM.vSR( "minimization return value=", value );  vyBase.Update( tree );  
			END;  
		END;  
	END Minimize;  

	PROCEDURE MinimizeDistTo*;  
	VAR tree, arrayobj: vyBase.Object;  name: vyName.tNameArray;  gamma, value: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ to=OBJECT" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "to", arrayobj ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				WITH arrayobj: antsArrayObjects.tLONGREALObject DO 
					value := tree.MinimizeDistTo( arrayobj.A );  aM.SR( "minimization return value=", value );  vyBase.Update( tree );  
				END;  
			END;  
		END;  
	END MinimizeDistTo;  

	PROCEDURE PSNR*;  
	VAR tree, vecobj: vyBase.Object;  name: vyName.tNameArray;  penaltyno, gamma, value: FLOAT64;  ssq: ssqObject;  
		vec, pvec: vyLongrealVec.tVector;  i: SIZE;  from, to, by: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ  PSNR=(OBJ|NAME)  penalty=(OBJ|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & 
		    antsCommands.ExpectReal( "by", by )

		THEN 
			IF antsCommands.GetObject( "PSNR", vecobj ) THEN  (* vector exists *)
				vec := vecobj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec, 0 );  
			ELSIF antsCommands.ExpectName( "PSNR", name ) THEN 
				vec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vec, name );  
			ELSE RETURN 
			END;  
			IF antsCommands.GetObject( "penalty", vecobj ) THEN  (* vector exists *)
				pvec := vecobj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( pvec, 0 );  
			ELSIF antsCommands.ExpectName( "penalty", name ) THEN 
				pvec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( pvec, name );  
			ELSE RETURN 
			END;  
			
			gamma := from;  
			WITH tree: wedgeTrees.QuadTree DO 
				NEW( ssq, tree );  
				WHILE (gamma < to) DO 
					value := tree.Minimize( gamma );  value := ssq.PSNR();  penaltyno := ssq.penalty;  
					aM.SRSR( "gamma=", gamma, "PSNR=", value );  aM.SR( "    penaltyno.=", penaltyno );  
					IF value > 1000 THEN value := 1000 END;  
					vyLongrealVec.Append( value, vec );  vyLongrealVec.Append( ssq.penalty, pvec );  gamma := gamma + ABS( by );  
				END;  
			END;  
		END;  
	END PSNR;  

	PROCEDURE ToArrayMR*;  
	VAR tree: vyBase.Object;  result: antsArrayObjects.tLONGREALArray;  min, max: FLOAT64;  msg: antsHistogramEdit.AdaptMsg;  
		obj: vyBase.Object;  
		name: ARRAY 256 OF CHAR;   (* array: antsArrayObjects.tLONGREALObject; arrayI : antsArrayObjects.tINTEGERObject;*)
	BEGIN 
		antsCommands.InitScan( "tree=OBJ  [destR=OBJ|NAME] [destI=OBJ|NAME]" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN  (* src needed for dimensions only *)
			WITH tree: wedgeTrees.QuadTree DO 
				
				IF (antsCommands.Find( "destR" )) THEN 
					IF antsCommands.GetObject( "destR", obj ) THEN 
					ELSIF antsCommands.ExpectName( "destR", name ) THEN 
						obj := antsArrayObjects.NewLONGREALObject( tree.w, tree.h, tree.colordepth );  
						vyName.RegisterNamed( obj, name );  
					END;  
					result := obj( antsArrayObjects.tLONGREALObject ).A;  
				ELSE result := NIL;  
				END;  
				tree.ReconstructMR( result );   (* reconstruction *)
				IF (antsCommands.Find( "destI" )) THEN 
					IF antsCommands.GetObject( "destI", obj ) THEN 
						WITH obj: antsArrayObjects.tINTEGERObject DO 
						(*
						antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
						*)
							antsArrayObjects.ChangeSize( obj, tree.w, tree.h );  antsArrayObjects.SetDepth( obj, tree.colordepth );  
							antsArrayObjects.SetLongreal( obj, result );   (*  vyBase.ForUsersHandle( array, msg ); *)
							vyBase.Update( obj );  
						END;  
					ELSIF antsCommands.ExpectName( "destI", name ) THEN 
						antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
						obj := antsArrayObjects.IntObjR( result, tree.colordepth );  vyName.RegisterNamed( obj, name );  
					END;  
				END;  
			
			END;  
		END;  
	END ToArrayMR;  

	PROCEDURE ToArray*;  
	VAR tree: vyBase.Object;  result: antsArrayObjects.tLONGREALArray;  min, max: FLOAT64;  msg: antsHistogramEdit.AdaptMsg;  
		obj: vyBase.Object;  
		name: ARRAY 256 OF CHAR;   (* array: antsArrayObjects.tLONGREALObject; arrayI : antsArrayObjects.tINTEGERObject;*)
	BEGIN 
		antsCommands.InitScan( "tree=OBJ  [destR=OBJ|NAME] [destI=OBJ|NAME]" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN  (* src needed for dimensions only *)
			WITH tree: wedgeTrees.QuadTree DO 
				
				IF (antsCommands.Find( "destR" )) THEN 
					IF antsCommands.GetObject( "destR", obj ) THEN 
						antsArrayObjects.ChangeSize( obj( antsArrayObjects.tObject ), tree.w, tree.h );  
					ELSIF antsCommands.ExpectName( "destR", name ) THEN 
						obj := antsArrayObjects.NewLONGREALObject( tree.w, tree.h, tree.colordepth );  
						vyName.RegisterNamed( obj, name );  
					END;  
					result := obj( antsArrayObjects.tLONGREALObject ).A;  
				ELSE result := NIL;  
				END;  
				tree.Reconstruct( result );   (* reconstruction *)
				IF (antsCommands.Find( "destI" )) THEN 
					IF antsCommands.GetObject( "destI", obj ) THEN 
						WITH obj: antsArrayObjects.tINTEGERObject DO 
						(*
						antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
						*)
							antsArrayObjects.ChangeSize( obj, tree.w, tree.h );  antsArrayObjects.SetDepth( obj, tree.colordepth );  
							antsArrayObjects.SetLongreal( obj, result );   (*  vyBase.ForUsersHandle( array, msg ); *)
							vyBase.Update( obj );  
						END;  
					ELSIF antsCommands.ExpectName( "destI", name ) THEN 
						antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
						obj := antsArrayObjects.IntObjR( result, tree.colordepth );  vyName.RegisterNamed( obj, name );  
					END;  
				END;  
			
			END;  
		END;  
	END ToArray;  

	PROCEDURE ComputePSNR*;  
	VAR src1, src2: vyBase.Object;  tmp, ssq, mse, depth, PSNR: FLOAT64;  i, j, w, h: SIZE;  
	BEGIN 
		depth := 256;  ssq := 0.;  antsCommands.InitScan( "src1=OBJECT src2=OBJECT" );  
		IF antsCommands.ExpectObject( "src1", src1 ) & antsCommands.ExpectObject( "src2", src2 ) THEN 
			WITH src1: antsArrayObjects.tLONGREALObject DO 
				WITH src2: antsArrayObjects.tLONGREALObject DO 
					w := LEN( src1.A );  h := LEN( src1.A[0] );  
					FOR i := 0 TO w - 1 DO 
						FOR j := 0 TO h - 1 DO ssq := ssq + (src1.A[i, j] - src2.A[i, j]) * (src1.A[i, j] - src2.A[i, j]);  END;  
					END;  
				END;  
			END;  
		END;  
		
		mse := ssq / (w * h);  tmp := depth * depth / mse;  PSNR := 10 * Math.ln( tmp ) / Math.ln( 10 );  

		Out.String( "PSNR : " );  Out.LongRealFix( PSNR, 6, 6 );  Out.Ln;  
	END ComputePSNR;  


(*	PROCEDURE ToArrayFloat*;  
	VAR tree, array: vyBase.Object;  result: antsArrayObjects.tLONGREALArray;  min, max: FLOAT64;  
		msg: antsHistogramEdit.AdaptMsg;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ  array=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN  (* src needed for dimensions only *)
			WITH tree: wedgeTrees.QuadTree DO 
				tree.Reconstruct( result );   (* reconstruction *)
				IF antsCommands.GetObject( "array", array ) THEN 
					WITH array: antsArrayObjects.tLONGREALObject DO 
						antsArrayObjects.ChangeSize( array, tree.w, tree.h );   (* antsArrayObjects.SetDepth( array, tree.colordepth );  *)
						antsArrayObjects.SetLongreal( array, result );   (*  vyBase.ForUsersHandle( array, msg ); *)
						vyBase.Update( array );  
					END;  
				ELSIF antsCommands.ExpectName( "array", name ) THEN 
					antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
					array := antsArrayObjects.IntObjR( result, tree.colordepth );  vyName.RegisterNamed( array, name );  
				END;  
			END;  
		END;  
	END ToArrayFloat;  *)

	PROCEDURE Report*;  
	VAR tree: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ " );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			WITH tree: wedgeTrees.QuadTree DO tree.Report;  
			END;  
		END;  
	END Report;  

(* Procedure used in Show*)
	PROCEDURE ShowArray( a: antsArrayObjects.tObject;  name: ARRAY OF CHAR );  
	VAR obj: antsArrayPictures16.tObject;  la: vyPort.tLayer;  pict: vyPort.Picture;  port: vyPort.Frame;  
		cc: antsPictCoordinate.tCoordinate;  c: Objects.Object;  
	BEGIN 
		WITH a: antsArrayObjects.tINTEGERObject DO 
			antsArrayPictures16.Gen;  obj := Objects.NewObj( antsArrayPictures16.tObject );  NEW( obj.curve );  

			antsHistogramEdit.InitObject( obj.curve, 0, 0, a.depth, 1 );  vyBase.Subscribe( obj.curve, obj );  
			antsArrayPictures16.FromArray( obj, a );  vyName.RegisterNamed( obj, name );  
			IF port = NIL THEN 
				la := antsPictureViews.DoShow( obj, FALSE , cc );  port := vyPort.GetFocus();  pict := vyPort.GetFocusPicture();  
				c := cc
			ELSE 
				antsPictureViews.New;  la := Objects.NewObj( antsPictureViews.tLayer );  
				antsPictureViews.Open( la( antsPictureViews.tLayer ), obj );  pict := NIL;  antsToolbox.ViewLayer( port, pict, la, c )
			END;  
			pict.backGround := 0;  
		END;  
	END ShowArray;  

(* Procedure used in Show*)
	PROCEDURE ShowArray2( a: antsArrayObjects.tObject;  name: ARRAY OF CHAR );  
	VAR obj: antsArrayImages16.tObject;  la: vyPort.tLayer;  pict: vyPort.Picture;  port: vyPort.Frame;  
		cc: antsPictCoordinate.tCoordinate;  c: Objects.Object;  
	BEGIN 
		WITH a: antsArrayObjects.tINTEGERObject DO 
			antsArrayImages16.Gen;  obj := Objects.NewObj( antsArrayImages16.tObject );  NEW( obj.curve );  

			antsHistogramEdit.InitObject( obj.curve, 0, 0, a.depth, 1 );  vyBase.Subscribe( obj.curve, obj );  
			antsArrayImages16.FromArray( obj, a );  vyName.RegisterNamed( obj, name );  
			IF port = NIL THEN 
				la := antsImageViews.DoShow( obj, FALSE , cc );  port := vyPort.GetFocus();  pict := vyPort.GetFocusPicture();  c := cc
			ELSE 
				antsImageViews.New;  la := Objects.NewObj( antsImageViews.tLayer );  
				antsImageViews.Open( la( antsImageViews.tLayer ), obj );  pict := NIL;  antsToolbox.ViewLayer( port, pict, la, c )
			END;  
			pict.backGround := 0;  
		END;  
	END ShowArray2;  


(*Used to show the image*)
	PROCEDURE Show*;  
	VAR layer: wedgeTreePlot.tLayer;  obj, obj2: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "[tree=NAME] [array=NAME] [>picture]" );  
		IF antsCommands.GetObject( "array", obj ) THEN 
			WITH obj: antsArrayObjects.tINTEGERObject DO 
				IF antsCommands.Find( "picture" ) THEN ShowArray( obj, "AResult" );  ELSE ShowArray2( obj, "AResult" );  END;  
				IF antsCommands.GetObject( "tree", obj2 ) THEN 
					WITH obj2: wedgeTrees.QuadTree DO 
						layer := wedgeTreePlot.NewLayer( obj2, NIL );  vyPort.AddLayer( vyPort.GetFocusPicture(), layer );  
						IF antsCommands.Find( "numbers" ) THEN Attributes.SetBool( layer, "Numbers", TRUE );  ELSE Attributes.SetBool( layer, "Numbers", FALSE );  END;  
					
					END;  
				END;  
			END;  
		ELSIF antsCommands.GetObject( "tree", obj2 ) THEN 
			WITH obj2: wedgeTrees.QuadTree DO 
				layer := wedgeTreePlot.DoShow( obj2, NIL );  
				IF antsCommands.Find( "numbers" ) THEN Attributes.SetBool( layer, "Numbers", TRUE );  ELSE Attributes.SetBool( layer, "Numbers", FALSE );  END;  
			END;  
		END;  
	END Show;  


(*	PROCEDURE ReadASCII*( VAR o: tINTEGERObject;  fname: ARRAY OF CHAR );  
	VAR Matrix: antsArrays.I2d;  rows, columns, y, x: SIZE;  R: antsReadWrite.Rider;  
	BEGIN 
		o := NIL;  
		IF ~R.Old( fname ) THEN RETURN END;  
		R.ReadType;   (* just if type is binary, unexpectedly *)
		
		R.ReadI2d( Matrix );  o := NewINTEGERObject( 1, 1, 10 );  EmbedINTEGERArray( Matrix, o );  
		
	END ReadASCII;  

	PROCEDURE ReadPGM*( VAR o: tINTEGERObject;  fname: ARRAY OF CHAR );  
	VAR A: tLONGINTArray;  h, w, depth: SIZE;  
	BEGIN 
		IF ~antsReadWrite.ReadPGM( A, fname, depth ) OR (A = NIL ) THEN o := NIL;  RETURN END;  
		w := LEN( A[0] );  h := LEN( A^ );  
		IF o = NIL THEN o := NewINTEGERObject( w, h, depth ) END;  
		SetLongint( o, A );  o.depth := depth
	END ReadPGM;  

	PROCEDURE StorePGMAscii*( A: tINTEGERObject;  VAR FR: Files.Rider );  
	VAR R: antsReadWrite.Rider;  x, y: SIZE;  
	BEGIN 
		R.Enter( FR );  R.SetAscii;  R.WriteString( "P2" );  R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  R.WriteString( "# by Oberon" );  
		R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  R.WriteLInt( A.w );  R.WriteLInt( A.h );  R.Write( antsFiles.LF );  
		R.Write( antsFiles.CR );  R.WriteLInt( A.depth - 1 );  R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  
		FOR y := A.h - 1 TO 0 BY -1 DO 
			FOR x := 0 TO A.w - 1 DO R.WriteInt( A.A[y, x] );  END;  
			R.Write( antsFiles.LF );  R.Write( antsFiles.CR );  
		END;  
		R.Leave( FR );  
	END StorePGMAscii;  

	PROCEDURE ReadPGMAscii*( VAR A: tINTEGERObject;  VAR FR: Files.Rider ): BOOLEAN;  
	VAR name: ARRAY 64 OF CHAR;  
		ch: CHAR;  pos: SIZE;  w, h, d: SIZE;  x, y: SIZE;  R: antsFiles.Rider;  int: SIGNED16;  lint: SIZE;  
	BEGIN 
		R.Enter( FR );  R.SetAscii;  R.ReadString( name );  
		IF (R.err) OR (name # "P2") THEN aM.eSS( "could not load PGM Ascii image, header=", name );  RETURN FALSE ELSE aM.S( "Loading PGM Ascii" );  END;  
		
		REPEAT R.Read( ch );  
		UNTIL ~antsFiles.WhiteSpace( ch );  
		
		WHILE (ch = "#") DO 
			REPEAT R.Read( ch ) UNTIL (ch = antsFiles.CR) OR (ch = antsFiles.LF);  
			REPEAT R.Read( ch );  UNTIL ~antsFiles.WhiteSpace( ch );  
		END;  
		R.SetPos( R.Pos() - 1 );  

		R.ReadLInt( w );   (* dimensions *)
		R.ReadLInt( h );  R.ReadLInt( d );  
		
		IF A = NIL THEN A := NewINTEGERObject( w, h, d + 1 );  
		ELSE ChangeSize( A, w, h );  SetDepth( A, d + 1 )
		END;  
		
		FOR y := A.h - 1 TO 0 BY -1 DO 
			FOR x := 0 TO A.w - 1 DO R.ReadInt( A.A[y, x] );  END;  
		END;  
		
		R.Leave( FR );  RETURN TRUE;  
	END ReadPGMAscii;  *)




BEGIN 
END wedgeCommands.

