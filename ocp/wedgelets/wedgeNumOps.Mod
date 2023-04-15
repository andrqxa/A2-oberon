MODULE wedgeNumOps IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT vyLongintVec, vyLongrealVec, vyName, vyBase, antsCommands, wedgeTrees, wedgeLog, MathL IN A2, vyCharts, vyScatter2, 
	vyDisplay2d, vyTypes, vyPort, aM := antsMessages, Oberon, vyHostStrings, vyHostTexts, Strings, antsArrayObjects, Kernel, 
	vyRandom, wedgeHierarchicModel, Objects, antsGammaShooting, antsReadWrite, Out, antsArrays, Math := MathL IN A2;  

VAR 
	time: SIGNED32;  
TYPE 
	
	
	(*
	PROCEDURE NewNumber*;  
	VAR name: ARRAY 256 OF CHAR;  
		r: vyLongintVec.tLONGINT;  number: SIGNED32;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "name=NAME [number=NUMBER]" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			obj := vyName.FindObj( name );  
			IF (obj # NIL ) & (obj IS vyLongintVec.tLONGINT) THEN r := obj( vyLongintVec.tLONGINT );  ELSE NEW( r );  END;  
			IF antsCommands.GetNumber( "number", number ) THEN r.i := number;  END;  
			vyName.RegisterNamed( r, name );  
		END;  
	END NewNumber;  
	*)
	
	PROCEDURE EstimateVarianceMAD*;  
	VAR x, y, w, h, pos: SIGNED32;  obj: vyBase.Object;  A: antsArrayObjects.tLONGREALArray;  
		test: POINTER TO ARRAY OF FLOAT64;  
		sigma: FLOAT64;  
		varname: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "img=OBJ" );  
		IF antsCommands.ExpectObject( "img", obj ) THEN 
			WITH obj: antsArrayObjects.tLONGREALObject DO 
				A := obj.A;  w := LEN( A[0] );  h := LEN( A );  NEW( test, (w - 1) * (h - 1) );  pos := 0;  
				FOR y := 0 TO h - 2 DO 
					FOR x := 0 TO w - 2 DO test[pos] := ABS( A[y + 1, x + 1] - A[y + 1, x] - A[y, x + 1] + A[y, x] );  INC( pos ) END;  
				END;  
				
				sigma := 1.48 / 2 * antsArrays.Median1dX( test^, (w - 1) * (h - 1) );  aM.SR( "var=", sigma * sigma );  
				IF antsCommands.Find( "var" ) & antsCommands.ExpectName( "var", varname ) THEN DoSet( varname, sigma * sigma );  END;  
			END;  
		END;  
	END EstimateVarianceMAD;  

	PROCEDURE DoSet*( name: ARRAY OF CHAR;  real: FLOAT64 );  
	VAR obj: vyBase.Object;  r: vyLongrealVec.tLONGREAL;  
	BEGIN 
		obj := vyName.FindObj( name );  
		IF (obj # NIL ) & (obj IS vyLongrealVec.tLONGREAL) THEN r := obj( vyLongrealVec.tLONGREAL );  
		ELSE NEW( r );  vyName.RegisterNamed( r, name );  
		END;  
		r.x := real;  
	END DoSet;  

	PROCEDURE DoSetNumber*( name: ARRAY OF CHAR;  i: SIGNED32 );  
	VAR obj: vyBase.Object;  r: vyLongintVec.tLONGINT;  
	BEGIN 
		obj := vyName.FindObj( name );  
		IF (obj # NIL ) & (obj IS vyLongintVec.tLONGINT) THEN r := obj( vyLongintVec.tLONGINT );  
		ELSE NEW( r );  vyName.RegisterNamed( r, name );  
		END;  
		r.i := i;  
	END DoSetNumber;  

	PROCEDURE NewReal*;  
	VAR name: ARRAY 256 OF CHAR;  
		r: vyLongrealVec.tLONGREAL;  real: FLOAT64;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "name=NAME [real=REAL]" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			IF ~antsCommands.GetReal( "real", real ) THEN real := 0 END;  
			DoSet( name, real );  
		END;  
	END NewReal;  

	PROCEDURE Add*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT real=REAL" );  
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectReal( "real", real ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := obj.x + real;  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO vyLongrealVec.Set( (vyLongrealVec.Get( obj, i )) + real, obj, i );  END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Add;  

	PROCEDURE Sub*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT real=REAL" );  
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectReal( "real", real ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := obj.x - real;  vyBase.Update( obj );  
			END;  
		END;  
	END Sub;  

	PROCEDURE Mult*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT real=REAL" );  
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectReal( "real", real ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := obj.x * real;  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO vyLongrealVec.Set( (vyLongrealVec.Get( obj, i )) * real, obj, i );  END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Mult;  

	PROCEDURE Div*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT real=REAL" );  
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectReal( "real", real ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := obj.x / real;  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO vyLongrealVec.Set( (vyLongrealVec.Get( obj, i )) / real, obj, i );  END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Div;  

	PROCEDURE Min*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT real=REAL" );  
		IF antsCommands.ExpectObject( "obj", obj ) & antsCommands.ExpectReal( "real", real ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO 
				IF obj.x > real THEN obj.x := real END;  
			END;  
		END;  
	END Min;  

	PROCEDURE Log10*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT" );  
		IF antsCommands.ExpectObject( "obj", obj ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := MathL.ln( obj.x ) / MathL.ln( 10 );  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO 
					IF vyLongrealVec.Get( obj, i ) = 0 THEN vyLongrealVec.Set( -100, obj, i ) ELSE 

						vyLongrealVec.Set( MathL.ln( vyLongrealVec.Get( obj, i ) ) / MathL.ln( 10 ), obj, i );  
					END;  
				END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Log10;  

	PROCEDURE Log*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT" );  
		IF antsCommands.ExpectObject( "obj", obj ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := MathL.ln( obj.x ) / MathL.ln( 10 );  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO 
					IF vyLongrealVec.Get( obj, i ) = 0 THEN vyLongrealVec.Set( -100, obj, i ) ELSE 

						vyLongrealVec.Set( MathL.ln( vyLongrealVec.Get( obj, i ) ), obj, i );  
					END;  
				END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Log;  

	PROCEDURE Exp10*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT" );  
		IF antsCommands.ExpectObject( "obj", obj ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := MathL.exp( obj.x * MathL.ln( 10 ) );  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO 
					vyLongrealVec.Set( MathL.exp( vyLongrealVec.Get( obj, i ) * MathL.ln( 10 ) ), obj, i );  
				END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Exp10;  

	PROCEDURE Exp*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  i: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT" );  
		IF antsCommands.ExpectObject( "obj", obj ) THEN 
			WITH obj: vyLongrealVec.tLONGREAL DO obj.x := MathL.exp( obj.x * MathL.ln( 10 ) );  vyBase.Update( obj );  
			| obj: vyLongrealVec.tVector DO 
				FOR i := 0 TO vyLongrealVec.Len( obj ) - 1 DO vyLongrealVec.Set( MathL.exp( vyLongrealVec.Get( obj, i ) ), obj, i );  END;  
				vyBase.Update( obj );  
			END;  
		END;  
	END Exp;  

	PROCEDURE Copy*;  
	VAR from, obj: vyBase.Object;  
		to: ARRAY 256 OF CHAR;  
		vec: vyLongrealVec.tVector;  
	BEGIN 
		antsCommands.InitScan( "from=OBJECT to=NAME" );  
		IF antsCommands.ExpectObject( "from", from ) & antsCommands.ExpectName( "to", to ) THEN 
			WITH from: vyLongrealVec.tLONGREAL DO DoSet( to, from.x )
			| from: vyLongrealVec.tVector DO 
				obj := vyName.FindObj( to );  
				IF obj # NIL THEN vec := obj( vyLongrealVec.tVector ) 
				ELSE vec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vec, to );  
				END;  
				vyLongrealVec.SetLen( vec, vyLongrealVec.Len( from ) );  vyLongrealVec.CopyData( from, vec );  
				vyBase.Update( vec );  
			END;  
		END;  
	END Copy;  

	PROCEDURE Statistics*;  
	VAR real: FLOAT64;  tree: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		stat: wedgeTrees.StatisticObject;  mse: FLOAT64;  psnr, tmp: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT [penalty=NAME] [psnr = NAME] [ssq= NAME] [pieces=NAME] [approxprepareT=NAME] [approxT=NAME] [allocT=NAME] [minT=NAME]" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				stat := tree.Stats();  mse := stat.sumofssq / (tree.w * tree.h);  tmp := tree.colordepth * tree.colordepth / mse;  
				psnr := 10 * MathL.ln( tmp ) / MathL.ln( 10 );  
				IF antsCommands.Find( "penalty" ) & antsCommands.ExpectName( "penalty", name ) THEN DoSet( name, stat.sumofpenalty );  END;  
				IF antsCommands.Find( "ssq" ) & antsCommands.ExpectName( "ssq", name ) THEN DoSet( name, stat.sumofssq );  END;  
				IF antsCommands.Find( "psnr" ) & antsCommands.ExpectName( "psnr", name ) THEN DoSet( name, psnr );  END;  
				IF antsCommands.Find( "pieces" ) & antsCommands.ExpectName( "pieces", name ) THEN DoSet( name, stat.sumofpieces );  END;  
				IF antsCommands.Find( "approxprepareT" ) & antsCommands.ExpectName( "approxprepareT", name ) THEN DoSet( name, stat.approxprepareT );  END;  
				IF antsCommands.Find( "approxT" ) & antsCommands.ExpectName( "approxT", name ) THEN DoSet( name, stat.approxT );  END;  
				IF antsCommands.Find( "allocT" ) & antsCommands.ExpectName( "allocT", name ) THEN DoSet( name, stat.alloctime );  END;  
				IF antsCommands.Find( "minT" ) & antsCommands.ExpectName( "minT", name ) THEN DoSet( name, stat.mintime );  END;  
				
				aM.vSRSR( "stat.sumofpieces=", stat.sumofpieces, "stat.sumofpenalty=", stat.sumofpenalty );  aM.vSRSR( "stat.sumofssq=", stat.sumofssq, "psnr = ", psnr );  
			| tree: wedgeHierarchicModel.Tree DO 
				IF antsCommands.Find( "approxprepareT" ) & antsCommands.ExpectName( "approxprepareT", name ) THEN DoSet( name, tree.preparetime );  END;  
				IF antsCommands.Find( "minT" ) & antsCommands.ExpectName( "minT", name ) THEN DoSet( name, tree.mintime );  END;  
			
			END;  
		END;  
	END Statistics;  

TYPE 
	LineComputer = OBJECT 
	VAR tree: wedgeTrees.QuadTree;  
		stat: wedgeTrees.StatisticObject;  
		ssq, penalty: FLOAT64;  
		evals: SIGNED32;  
		time: SIGNED32;  
		
		PROCEDURE & Init( tree: wedgeTrees.QuadTree );  
		BEGIN 
			SELF.tree := tree;  time := Oberon.Time();  evals := 0;  
		END Init;  

		PROCEDURE Stats( node: wedgeTrees.QNode );  
		VAR a: wedgeTrees.LocalApproximation;  
		BEGIN 
			a := node.active;  
			IF a # NIL THEN ssq := ssq + a.distance;  penalty := penalty + a.penalty;  ELSE 
				IF node.ll # NIL THEN Stats( node.ll ) END;  
				IF node.lr # NIL THEN Stats( node.lr ) END;  
				IF node.ul # NIL THEN Stats( node.ul ) END;  
				IF node.ur # NIL THEN Stats( node.ur ) END;  
			END;  
		
		END Stats;  

		PROCEDURE GetMin( x: FLOAT64;  VAR intercept, slope: FLOAT64 );  
		BEGIN 
			INC( evals );  
			IF Oberon.Time() > time + 1000 THEN time := Oberon.Time();  aM.SR( "currently at ", x );  aM.SI( "# evaluations:", evals );  END;  
			
			x := tree.Minimize( x );  penalty := 0;  ssq := 0;  Stats( tree.root );  intercept := ssq;  
			slope := penalty * tree.w * tree.h * tree.colordepth * tree.colordepth / 65536;  
			(*aM.SRSR("GetMin;: ssq",intercept,"penalty",slope); *)
		END GetMin;  

	END LineComputer;  
	
	PROCEDURE Shooting*;  
	VAR lineComputer: LineComputer;  lst, tmp: antsGammaShooting.Intersection;  tree, obj: vyBase.Object;  count: SIGNED32;  
		from, to: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				NEW( lineComputer, tree );  aM.SRSR( "Starting Shooting Algorithm starting from ", from, " ranging to ", to );  
				lst := antsGammaShooting.ComputeList( from, to, lineComputer.GetMin );  
				
				IF antsCommands.GetObject( "gamma", obj ) THEN 
					WITH obj: vyLongrealVec.tVector DO 
						vyLongrealVec.SetLen( obj, 0 );  tmp := lst.next;  
						WHILE ((tmp # NIL ) & (tmp.next # NIL )) DO vyLongrealVec.Append( tmp.x, obj );  INC( count );  tmp := tmp.next END;  
					END;  
				END;  
			END;  
		END;  
		count := 0;  tmp := lst;  
		WHILE (tmp # NIL ) DO INC( count );  tmp := tmp.next END;  
		aM.SI( "Found intersections: ", count );  
	END Shooting;  

(* 
		System.Free wedgeNumOps antsGammaShooting ~
	antsMessages.SetMode normal ~
	
	wedgeNumOps.Shooting tree=myTree gamma=gamma  from=0 to=1000 
	wedgeNumOps.ClearVec gamma ~
	wedgeNumOps.Log gamma ~
	Voyager.Show gamma  ~

	Voyager.WriteData gamma 
	vyScale.Insert
	*)

	PROCEDURE ClearVec*;  
	VAR name: ARRAY 256 OF CHAR;  
		r: vyLongrealVec.tVector;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "name=NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			obj := vyName.FindObj( name );  
			IF (obj # NIL ) & (obj IS vyLongrealVec.tVector) THEN vyLongrealVec.SetLen( obj( vyLongrealVec.tVector ), 0 );  
			ELSE r := vyLongrealVec.New( 0 );  vyName.RegisterNamed( r, name );  
			END;  
		END;  
	
	END ClearVec;  

	PROCEDURE NewVec*;  
	VAR name: ARRAY 256 OF CHAR;  
		r: vyLongrealVec.tVector;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "name=NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
		(*
			obj := vyName.FindObj(name); 
			*)
			(*
			IF (obj#NIL) & (obj IS vyLongrealVec.tVector) THEN 
				vyLongrealVec.SetLen(obj(vyLongrealVec.tVector),0); 
			ELSE
			*)
			
			r := vyLongrealVec.New( 0 );  vyName.RegisterNamed( r, name );  
			(*END;  *)
		END;  
	
	END NewVec;  

	PROCEDURE Append*;  
	VAR real: FLOAT64;  obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( " real=REAL obj=OBJECT" );  
		IF antsCommands.ExpectReal( "real", real ) & antsCommands.ExpectObject( "obj", obj ) THEN 
			WITH obj: vyLongrealVec.tVector DO vyLongrealVec.Append( real, obj );  vyBase.Update( obj );  
			END;  
		END;  
	END Append;  

	PROCEDURE Stats*;  
	VAR s: wedgeTrees.StatisticObject;  tree: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
	
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT [penalty=NAME] [ssq=NAME]" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				s := tree.Stats();  
				IF antsCommands.Find( "penalty" ) & antsCommands.GetName( "penalty", name ) THEN DoSet( name, s.sumofpenalty );  END;  
				IF antsCommands.Find( "ssq" ) & antsCommands.GetName( "ssq", name ) THEN DoSet( name, s.sumofssq );  END;  
			END;  
		END;  
	
	END Stats;  

TYPE 
	
	PortLink = OBJECT (vyBase.Object)
	VAR
		pict: vyPort.Picture;  
	END PortLink;  
	
	(*für anzeigen der PSNR Vec*)
	PROCEDURE ShowVec*;  
	VAR layer: vyPort.tLayer;  chart: vyCharts.tLayer;  scatter: vyScatter2.tLayer;  vecx, vecy, obj: vyBase.Object;  
		pict: vyPort.Picture;  c: vyDisplay2d.tCoordinate2d;  minX, maxX: FLOAT64;  minY, maxY: FLOAT64;  nans: SIGNED32;  
		port: ARRAY 256 OF CHAR;  
		portlink: PortLink;  
	BEGIN 
		antsCommands.InitScan( "vecx=OBJ vecy=OBJ  [>add]" );  
		IF antsCommands.ExpectObject( "vecx", vecx ) & antsCommands.ExpectObject( "vecy", vecy ) & 
		    antsCommands.ExpectName( "port", port ) THEN 
			WITH vecx: vyBase.tVector DO 
				WITH vecy: vyBase.tVector DO 
					IF antsCommands.Find( "scatter" ) THEN NEW( scatter );  vyScatter2.OpenO( scatter, vecx, vecy );  layer := scatter;  
					ELSE NEW( chart );  vyCharts.OpenO( chart, vecx, vecy );  layer := chart;  
					END;  
					IF ~antsCommands.Find( "forcenew" ) THEN 
						obj := vyName.FindObj( port );  
						IF obj # NIL THEN 
							WITH obj: PortLink DO pict := obj.pict;  
							END;  
						END;  
					END;  
					IF (pict = NIL ) THEN 
						NEW( portlink );  vyName.RegisterNamed( portlink, port );  vyTypes.VGetMinMax( layer.x, minX, maxX, nans );  
						vyTypes.VGetMinMax( layer.y, minY, maxY, nans );  
						
						IF maxX > 10000 THEN maxX := 10000
						END;  
						IF minX < -10000 THEN minX := -10000 END;  
						IF maxY > 100 THEN maxY := 100 END;  
						IF minY < -10000 THEN minY := -10000 END;  
						
						IF maxX = minX THEN minX := minX - 0.5;  maxX := minX + 1
						END;  
						IF maxY = minY THEN minY := minY - 0.5;  maxY := minY + 1 END;  
						
						aM.SRSR( "minX=", minX, "maxX=", maxX );  aM.SRSR( "minY=", minY, "maxY=", maxY );  

						NEW( c );  vyDisplay2d.OpenC2d( c, minX, minY, maxX - minX, maxY - minY );  
						pict := vyPort.InsertNewCPicture( 0, 0, 1, 1, c );  portlink.pict := pict;  
					END;  
					vyPort.AddLayer( pict, layer );  vyPort.SetFocusPicture( pict );  
				
				END;  
			END;  
		END;  
	END ShowVec;  

	PROCEDURE OpenDocument*;  
	VAR t, d, x: SIGNED32;  
		name, fname: ARRAY 256 OF CHAR;  
		
		PROCEDURE WritePair( x: SIGNED32 );  
		BEGIN 
			Strings.AppendCh( name, CHR( x DIV 10 + 30H ) );  Strings.AppendCh( name, CHR( x MOD 10 + 30H ) );  
		END WritePair;  

	BEGIN 
		antsCommands.InitScan( "name=NAME" );  
		IF antsCommands.ExpectName( "name", name ) THEN 
			Oberon.GetClock( t, d );  vyHostStrings.AppendInt( 1900 + d DIV 512, 1, name );  WritePair( d DIV 32 MOD 16 );  
			WritePair( d MOD 32 );  WritePair( t DIV 4096 MOD 32 );  WritePair( t DIV 64 MOD 64 );  WritePair( t MOD 64 );  
			Strings.Append( name, ".Text" );  fname := "";  Strings.Append( fname, name );  vyHostTexts.DoOpenLog( fname );  
		END;  
	END OpenDocument;  

	PROCEDURE NewNoisyArray*;  
	VAR obj: vyBase.Object;  array: antsArrayObjects.tINTEGERObject;  
		name: ARRAY 256 OF CHAR;  
		wr, hr: FLOAT64;  w, h: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "name=NAME w=NUMBER h=NUMBER" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectReal( "w", wr ) & antsCommands.ExpectReal( "h", hr ) THEN 
			obj := vyName.FindObj( name );  w := ENTIER( wr + 0.5 );  h := ENTIER( hr + 0.5 );  
			IF obj # NIL THEN array := obj( antsArrayObjects.tINTEGERObject );  antsArrayObjects.ChangeSize( array, w, h );  
			ELSE array := antsArrayObjects.NewINTEGERObject( w, h, 256 );  vyName.RegisterNamed( array, name );  
			END;  
			antsArrayObjects.UniformO( array );  
		END;  
	END NewNoisyArray;  

	PROCEDURE GetDimensions*;  
	VAR array: vyBase.Object;  
		wname, hname: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name=OBJ width=NAME height=NAME" );  
		IF antsCommands.ExpectObject( "name", array ) & antsCommands.ExpectName( "width", wname ) & 
		    antsCommands.ExpectName( "height", hname ) THEN 
			WITH array: antsArrayObjects.tObject DO DoSetNumber( wname, array.w );  DoSetNumber( hname, array.h );  
			END;  
		END;  
	END GetDimensions;  

	PROCEDURE NewConstantArray*;  
	VAR obj: vyBase.Object;  array: antsArrayObjects.tINTEGERObject;  
		name: ARRAY 256 OF CHAR;  
		wr, hr, valr: FLOAT64;  w, h, val: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "name=NAME w=NUMBER h=NUMBER value=NUMBER" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectReal( "w", wr ) & antsCommands.ExpectReal( "h", hr ) & 
		    antsCommands.ExpectReal( "value", valr ) THEN 
			obj := vyName.FindObj( name );  w := ENTIER( wr + 0.5 );  h := ENTIER( hr + 0.5 );  val := ENTIER( valr + 0.5 );  
			IF obj # NIL THEN array := obj( antsArrayObjects.tINTEGERObject );  antsArrayObjects.ChangeSize( array, w, h );  
			ELSE array := antsArrayObjects.NewINTEGERObject( w, h, 256 );  vyName.RegisterNamed( array, name );  
			END;  
			antsArrayObjects.FillIntArray( SHORT( val ), array.A, 0, 0, w, h );  vyBase.Update( array );  
		END;  
	END NewConstantArray;  

	PROCEDURE AddGaussNoise*;  
	VAR src, dest: vyBase.Object;  desta: antsArrayObjects.tLONGREALObject;  variance, random, newval: FLOAT64;  x, y, w, h: SIGNED32;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT  dest= NAME var=NUMBER" );  
		IF antsCommands.ExpectObject( "src", src ) & antsCommands.ExpectName( "dest", name ) & 
		    antsCommands.ExpectReal( "var", variance ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
				w := src.w;  h := src.h;  dest := vyName.FindObj( name );  
				IF dest # NIL THEN 
					desta := dest( antsArrayObjects.tLONGREALObject );  antsArrayObjects.ChangeSize( desta, w, h );  
				ELSE desta := antsArrayObjects.NewLONGREALObject( w, h, 256 );  vyName.RegisterNamed( desta, name );  
				END;  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO newval := vyRandom.Gauss( 0, variance ) + src.A[y, x];  desta.A[y, x] := newval;  END;  
				END;  
				vyBase.Update( desta );  
			END;  
		END;  
	END AddGaussNoise;  

	PROCEDURE AddUniformNoise*;  
	VAR src, dest: vyBase.Object;  desta: antsArrayObjects.tLONGREALObject;  variance, random, newval: FLOAT64;  x, y, w, h: SIGNED32;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT  dest= NAME var=NUMBER" );  
		IF antsCommands.ExpectObject( "src", src ) & antsCommands.ExpectName( "dest", name ) & 
		    antsCommands.ExpectReal( "var", variance ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
				w := src.w;  h := src.h;  dest := vyName.FindObj( name );  
				IF dest # NIL THEN 
					desta := dest( antsArrayObjects.tLONGREALObject );  antsArrayObjects.ChangeSize( desta, w, h );  
				ELSE desta := antsArrayObjects.NewLONGREALObject( w, h, 256 );  vyName.RegisterNamed( desta, name );  
				END;  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO 
						random := -MathL.sqrt( variance * 12 ) / 2 + vyRandom.Uniform() * MathL.sqrt( variance * 12 );  
						newval := random + src.A[y, x];  desta.A[y, x] := newval;  
					END;  
				END;  
				vyBase.Update( desta );  
			END;  
		END;  
	END AddUniformNoise;  

	PROCEDURE AddExpNoise*;  
	VAR src, dest: vyBase.Object;  desta: antsArrayObjects.tLONGREALObject;  variance, random, newval: FLOAT64;  x, y, w, h: SIGNED32;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT  dest= NAME var=NUMBER" );  
		IF antsCommands.ExpectObject( "src", src ) & antsCommands.ExpectName( "dest", name ) & 
		    antsCommands.ExpectReal( "var", variance ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
				w := src.w;  h := src.h;  dest := vyName.FindObj( name );  
				IF dest # NIL THEN 
					desta := dest( antsArrayObjects.tLONGREALObject );  antsArrayObjects.ChangeSize( desta, w, h );  
				ELSE desta := antsArrayObjects.NewLONGREALObject( w, h, 256 );  vyName.RegisterNamed( desta, name );  
				END;  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO 
						random := vyRandom.Exp( 1 / MathL.sqrt( variance ) );  newval := random + src.A[y, x];  
						desta.A[y, x] := newval + 0.5;  
					END;  
				END;  
				vyBase.Update( desta );  
			END;  
		END;  
	END AddExpNoise;  

	PROCEDURE AddLaplaceNoise*;  
	VAR src, dest: vyBase.Object;  desta: antsArrayObjects.tLONGREALObject;  variance, random, newval: FLOAT64;  x, y, w, h: SIGNED32;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "src=OBJECT  dest= NAME var=NUMBER" );  
		IF antsCommands.ExpectObject( "src", src ) & antsCommands.ExpectName( "dest", name ) & 
		    antsCommands.ExpectReal( "var", variance ) THEN 
			WITH src: antsArrayObjects.tLONGREALObject DO 
				w := src.w;  h := src.h;  dest := vyName.FindObj( name );  
				IF dest # NIL THEN 
					desta := dest( antsArrayObjects.tLONGREALObject );  antsArrayObjects.ChangeSize( desta, w, h );  
				ELSE desta := antsArrayObjects.NewLONGREALObject( w, h, 256 );  vyName.RegisterNamed( desta, name );  
				END;  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO 
						random := vyRandom.Exp( 2 / MathL.sqrt( variance ) );  
						IF vyRandom.Uniform() < 0.5 THEN random := -random END;  
						newval := random + src.A[y, x];  desta.A[y, x] := newval;  
					END;  
				END;  
				vyBase.Update( desta );  
			END;  
		END;  
	END AddLaplaceNoise;  

	PROCEDURE SameScale*;  
	VAR src, dest: vyBase.Object;  x, y, w, h: SIGNED32;  min, max, val: SIGNED16;  
	BEGIN 
		antsCommands.InitScan( "array1=OBJECT  array2= OBJECT" );  
		
		IF antsCommands.ExpectObject( "array1", src ) & antsCommands.ExpectObject( "array2", dest ) THEN 
			WITH src: antsArrayObjects.tINTEGERObject DO 
				WITH dest: antsArrayObjects.tINTEGERObject DO w := src.w;  h := src.h;  
					ASSERT ( (dest.w = w) & (dest.h = h) );  
					min := MAX( SIGNED16 );  max := MIN( SIGNED16 );  
					FOR y := 0 TO h - 1 DO 
						FOR x := 0 TO w - 1 DO 
							IF min > src.A[y, x] THEN min := src.A[y, x] END;  
							IF min > dest.A[y, x] THEN min := dest.A[y, x] END;  
							IF max < src.A[y, x] THEN max := src.A[y, x] END;  
							IF max < dest.A[y, x] THEN max := dest.A[y, x] END;  
						END;  
					END;  
					FOR y := 0 TO h - 1 DO 
						FOR x := 0 TO w - 1 DO 
							val := src.A[y, x];  val := SHORT( ENTIER( (val - min) / (max - min) * 255 + 0.5 ) );  src.A[y, x] := val;  val := dest.A[y, x];  
							val := SHORT( ENTIER( (val - min) / (max - min) * 255 + 0.5 ) );  dest.A[y, x] := val;  
						
						END;  
					END;  
					vyBase.Update( src );  vyBase.Update( dest );  
				
				END;  
			END;  
		END;  
	
	END SameScale;  

	PROCEDURE Rescale*;  
	VAR src: vyBase.Object;  x, y, w, h: SIGNED32;  min, max, val: SIGNED16;  newmin, newmax: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "array=OBJECT  min=NUMBER max=NUMBER" );  
		IF antsCommands.ExpectObject( "array", src ) & antsCommands.ExpectNumber( "min", newmin ) & 
		    antsCommands.ExpectNumber( "max", newmax ) THEN 
			WITH src: antsArrayObjects.tINTEGERObject DO 
				w := src.w;  h := src.h;  min := MAX( SIGNED16 );  max := MIN( SIGNED16 );  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO 
						IF min > src.A[y, x] THEN min := src.A[y, x] END;  
						IF max < src.A[y, x] THEN max := src.A[y, x] END;  
					END;  
				END;  
				FOR y := 0 TO h - 1 DO 
					FOR x := 0 TO w - 1 DO 
						val := src.A[y, x];  val := SHORT( ENTIER( (val - min) / (max - min) * (newmax - newmin) + newmin + 0.5 ) );  
						src.A[y, x] := val;  
					END;  
				END;  
				vyBase.Update( src );  
			END;  
		END;  
	END Rescale;  

	PROCEDURE ConserveImage*;  
	VAR obj: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		to: antsArrayObjects.tINTEGERObject;  
	BEGIN 
		antsCommands.InitScan( "array=OBJECT" );  
		IF antsCommands.ExpectObject( "array", obj ) THEN 
			WITH obj: antsArrayObjects.tINTEGERObject DO 
				vyName.GetObjId( obj, name );  antsArrayObjects.Gen;  
				to := Objects.NewObj( antsArrayObjects.tINTEGERObject );  antsArrayObjects.CopyObject( obj, to );  
				vyName.RegisterNamed( to, name );  
			END;  
		END;  
	END ConserveImage;  

	PROCEDURE L2Distance*;  
	VAR obj1, obj2: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		x, y, w, h: SIGNED32;  ssq, temp: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "array1=OBJECT array=OBJECT variable=NAME" );  
		IF antsCommands.ExpectObject( "array1", obj1 ) & antsCommands.ExpectObject( "array2", obj2 ) & 
		    antsCommands.ExpectName( "variable", name ) THEN 
			WITH obj1: antsArrayObjects.tLONGREALObject DO 
				WITH obj2: antsArrayObjects.tLONGREALObject DO w := obj1.w;  h := obj1.h;  
					ASSERT ( (w = obj2.w) & (h = obj2.h), 100 );  
					ssq := 0;  
					FOR y := 0 TO h - 1 DO 
						FOR x := 0 TO w - 1 DO temp := (obj1.A[y, x] - obj2.A[y, x]);  ssq := ssq + 1.0D0 * temp * temp;  END;  
					END;  
					DoSet( name, ssq );  aM.SR( "ssq= ", ssq );  
				END;  
			END;  
		END;  
	END L2Distance;  

	PROCEDURE PSNR*;  
	VAR obj1, obj2: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		x, y, w, h: SIGNED32;  ssq, temp: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "array1=OBJECT array=OBJECT variable=NAME" );  
		IF antsCommands.ExpectObject( "array1", obj1 ) & antsCommands.ExpectObject( "array2", obj2 ) & 
		    antsCommands.ExpectName( "variable", name ) THEN 
			WITH obj1: antsArrayObjects.tLONGREALObject DO 
				WITH obj2: antsArrayObjects.tLONGREALObject DO DoSet( name, ComputePSNR( obj1.A, obj2.A ) );  
				END;  
			END;  
		END;  
	END PSNR;  

	PROCEDURE GetLastZeroGamma*;  
	VAR loggamma, dist: FLOAT64;  stat: wedgeTrees.StatisticObject;  val, gamma: FLOAT64;  tree: vyBase.Object;  threshold: FLOAT64;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "thresh", threshold ) & 
		    antsCommands.ExpectName( "value", name ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				loggamma := 5;  dist := 1;  
				WHILE (dist > 0.001) DO 
					REPEAT 
						gamma := MathL.exp( MathL.ln( 10 ) * loggamma );  val := tree.Minimize( gamma );  stat := tree.Stats();  
						loggamma := loggamma - dist;  
					UNTIL (stat.sumofpieces > threshold) OR (loggamma < -5);  
					loggamma := loggamma + 2 * dist;  dist := dist / 10;  
				END;  
				aM.SR( "gamma", gamma );  DoSet( name, gamma );  
			END;  
		END;  
	END GetLastZeroGamma;  

	PROCEDURE Vector( name: ARRAY OF CHAR;  forcenew: BOOLEAN ): vyLongrealVec.tVector;  
	VAR obj: vyBase.Object;  vec: vyLongrealVec.tVector;  
	BEGIN 
		obj := vyName.FindObj( name );  
		IF forcenew OR (obj = NIL ) THEN vec := vyLongrealVec.New( 0 );  vyName.RegisterNamed( vec, name );  
		ELSE vec := obj( vyLongrealVec.tVector );  vyLongrealVec.SetLen( vec, 0 );  
		END;  
		RETURN vec;  
	END Vector;  

	PROCEDURE LogGammaVectors*;  
	VAR tree: vyBase.Object;  from, to, by: FLOAT64;  gamma, ssq, penalty, pieces, potts, psnr: vyLongrealVec.tVector;  
		name: ARRAY 256 OF CHAR;  
		loggamma, gammaval, pottsval, psnrval, tmp: FLOAT64;  stat: wedgeTrees.StatisticObject;  forcenew, logfile: BOOLEAN;  
		obj: vyBase.Object;  array: antsArrayObjects.tINTEGERObject;  result: antsArrayObjects.tLONGREALArray;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT from=REAL to=REAL by=REAL [gamma=NAME} [ssq=NAME] [penalty=NAME] [pieces=NAME] [potts=NAME] " );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & 
		    antsCommands.ExpectReal( "by", by ) THEN 
			aM.S( "Starting gamma loop" );  
			WITH tree: wedgeTrees.QuadTree DO 
				forcenew := antsCommands.Find( "forcenew" );  logfile := antsCommands.Find( "logfile" );  
				IF antsCommands.Find( "gamma" ) & antsCommands.ExpectName( "gamma", name ) THEN gamma := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "ssq" ) & antsCommands.ExpectName( "ssq", name ) THEN ssq := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "penalty" ) & antsCommands.ExpectName( "penalty", name ) THEN penalty := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "pieces" ) & antsCommands.ExpectName( "pieces", name ) THEN pieces := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "potts" ) & antsCommands.ExpectName( "potts", name ) THEN potts := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "psnr" ) & antsCommands.ExpectName( "psnr", name ) THEN psnr := Vector( name, forcenew ) END;  
				IF antsCommands.Find( "array" ) & antsCommands.ExpectObject( "array", obj ) THEN 
					array := obj( antsArrayObjects.tINTEGERObject )
				ELSE array := NIL 
				END;  
				loggamma := from;  
				WHILE (loggamma <= to) DO 
					gammaval := MathL.exp( loggamma * MathL.ln( 10 ) );  pottsval := tree.Minimize( gammaval );  
					stat := tree.Stats();  
					IF gamma # NIL THEN vyLongrealVec.Append( gammaval, gamma ) END;  
					IF ssq # NIL THEN vyLongrealVec.Append( stat.sumofssq, ssq ) END;  
					IF penalty # NIL THEN vyLongrealVec.Append( stat.sumofpenalty, penalty ) END;  
					IF pieces # NIL THEN vyLongrealVec.Append( stat.sumofpieces, pieces ) END;  
					IF potts # NIL THEN vyLongrealVec.Append( pottsval, potts ) END;  
					IF psnr # NIL THEN 
						tmp := stat.sumofssq / (tree.w * tree.h);  tmp := tree.colordepth * tree.colordepth / tmp;  
						psnrval := 10 * MathL.ln( tmp ) / MathL.ln( 10 );  
						IF psnrval > 200 THEN psnrval := 200 END;  
						vyLongrealVec.Append( psnrval, psnr )
					END;  
					IF array # NIL THEN 
						tree.Reconstruct( result );   (* reconstruction *)
						antsArrayObjects.ChangeSize( array, tree.w, tree.h );  antsArrayObjects.SetDepth( array, tree.colordepth );  
						antsArrayObjects.SetLongreal( array, result );   (*  vyBase.ForUsersHandle( array, msg ); *)
						vyBase.Update( array );  
					END;  
					loggamma := loggamma + by;  
				END;  
				Out.Ln;  
			END;  
			
			IF logfile THEN 
				name := "loggamma calculated from";  wedgeLog.StringIn( name );  wedgeLog.RealIn( from );  name := "to";  wedgeLog.StringIn( name );  
				wedgeLog.RealIn( to );  name := "by";  wedgeLog.StringIn( name );  wedgeLog.RealIn( by );  
			END;  
			
			aM.S( "gamma loop done." );  
		END;  
	
	END LogGammaVectors;  

	PROCEDURE FindVariance*;  
	VAR x, y, w, h: SIGNED32;  var, v: FLOAT64;  empiricalvar: FLOAT64;  loggamma: FLOAT64;  result, orig: antsArrayObjects.tLONGREALArray;  from, to, by: FLOAT64;  
		gammaval, pottsval: FLOAT64;  best, bgamma, dvar: FLOAT64;  tree, array: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "dvar", dvar ) & antsCommands.ExpectReal( "from", from ) & 
		    antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
			WITH tree: wedgeTrees.QuadTree DO 
				orig := tree.dataobj.A;  w := LEN( orig[0] );  h := LEN( orig );  loggamma := from;  best := MAX( FLOAT64 );  aM.SRSR( "from", from, "to", to );  
				WHILE (loggamma < to) DO 
					gammaval := MathL.exp( loggamma * MathL.ln( 10 ) );  pottsval := tree.Minimize( gammaval );  
					tree.Reconstruct( result );  var := 0;  
					FOR y := 0 TO h - 1 DO 
						FOR x := 0 TO w - 1 DO v := result[y, x] - orig[y, x];  v := v * v;  var := var + v;  END;  
					END;  
					var := var / w / h;  
					
					IF ABS( var - dvar ) < best THEN best := ABS( var - dvar );  bgamma := loggamma;  
					END;  
					
					loggamma := loggamma + by;  
				END;  
				aM.SR( "best log  gamma: ", bgamma );  
				IF antsCommands.Find( "array" ) & antsCommands.ExpectObject( "array", array ) THEN 
					WITH array: antsArrayObjects.tLONGREALObject DO 
						gammaval := MathL.exp( bgamma * MathL.ln( 10 ) );  pottsval := tree.Minimize( gammaval );  
						tree.Reconstruct( array.A );  vyBase.Update( array );  
					END;  
				END;  
			END;  
		
		END;  
	END FindVariance;  

	PROCEDURE FindOptPSNRFast*;  
	VAR tree, src: vyBase.Object;  from, to, by: FLOAT64;  
		name, gamma, PSNR1: ARRAY 256 OF CHAR;  
		dummy, gammaval, loggamma, PSNR, psnrmax, tmp, comp: FLOAT64;  forcenew, logfile, one, two: BOOLEAN;   (* obj: vyBase.Object;  *)
		array: antsArrayObjects.tINTEGERObject;  result: antsArrayObjects.tLONGREALArray;  max, maxLogGamma: FLOAT64;  
		precision: FLOAT64;  index, j: SIGNED32;  vecx, vecy: vyLongrealVec.tVector;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT from=REAL to=REAL by=REAL src=OBJECT [gamma=NAME] [PSNR1=NAME] [vecx=NAME] [vecy=NAME]" );  
		
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & 
		    antsCommands.ExpectReal( "precision", precision ) & antsCommands.ExpectObject( "src", src ) THEN 
			
			WITH tree: wedgeTrees.QuadTree DO 
				WITH src: antsArrayObjects.tLONGREALObject DO 
					logfile := antsCommands.Find( "logfile" );  loggamma := from;  
					IF antsCommands.Find( "vecx" ) & antsCommands.ExpectName( "vecx", name ) THEN vecx := Vector( name, forcenew ) END;  
					IF antsCommands.Find( "vecy" ) & antsCommands.ExpectName( "vecy", name ) THEN vecy := Vector( name, forcenew ) END;  
					comp := ABS( from - to ) / by;  index := SHORT( ENTIER( comp + 0.5 ) );  by := (to - from) / 20;  
					
					WHILE (by > ABS( precision )) DO 

						max := MIN( FLOAT64 );  loggamma := from;  
						WHILE (loggamma <= to) DO 
							gammaval := MathL.exp( loggamma * MathL.ln( 10 ) );   (* 10^loggamma *)
							
							dummy := tree.Minimize( gammaval );  
							tree.Reconstruct( result );   (* reconstruction *)
							
							
							PSNR := ComputePSNR( result, src.A );   (* Out.String( "log gamma :" );  Out.LongRealFix( loggamma, 6, 6 );  Out.String( "PSNR : " );  
						Out.LongRealFix( PSNR, 6, 6 );  Out.Ln;  
						aM.SRSR( "log gamma:  ", loggamma, "  PSNR:  ", PSNR );  *)
							IF PSNR > max THEN max := PSNR;  maxLogGamma := loggamma;  END;  
							IF vecx # NIL THEN vyLongrealVec.Append( loggamma, vecx ) END;  
							IF vecy # NIL THEN vyLongrealVec.Append( PSNR, vecy ) END;  
							loggamma := loggamma + by;  
						
						END;  
						(* aM.SR("by=",by); *)
						by := by / 10;  from := maxLogGamma - by * 20;  to := maxLogGamma + by * 20;  
						(* aM.SRSR("from=",from,"to=",to); *)
					END;  
					dummy := tree.Minimize( MathL.exp( maxLogGamma * MathL.ln( 10 ) ) );  
				
				END;  
			
			END;  
			
			aM.eSRSR( "Optimal log gamma:  ", maxLogGamma, "  Optimal PSNR:  ", max );  Out.String( "Optimal PSNR : " );  Out.LongRealFix( max, 6, 6 );  Out.Ln;  
			
			IF logfile THEN 
				name := "Optimalität bezgl. PSNR";  wedgeLog.StringIn( name );  
				(* name := "Optimal loggamma : ";  wedgeLog.StringIn( name ); *)
				wedgeLog.RealIn( maxLogGamma );  
				(* wedgeLog.LnIn;  name := "Optimal PSNR:  ";  wedgeLog.StringIn( name );  *)
				wedgeLog.RealIn( max );  wedgeLog.LnIn;  
			END;  
			
			IF antsCommands.Find( "gamma" ) & antsCommands.ExpectName( "gamma", gamma ) THEN DoSet( gamma, maxLogGamma );  
			END;  
			IF antsCommands.Find( "PSNR1" ) & antsCommands.ExpectName( "PSNR1", PSNR1 ) THEN DoSet( PSNR1, max );  END;  
			
			vyBase.Update( tree );  
			
			(* Out.String( "Optimal PSNR : " );  Out.LongRealFix( max, 6, 6 );  Out.Ln;  Out.String( "Optimal log gamma : " );  Out.LongRealFix( maxLogGamma, 6, 6 );  
			Out.Ln; *)
			
		END;  
	
	END FindOptPSNRFast;  

	PROCEDURE FindOptPSNR*;  
	VAR tree, src: vyBase.Object;  from, to, by: FLOAT64;  
		name, gamma, PSNR1: ARRAY 256 OF CHAR;  
		dummy, gammaval, loggamma, PSNR, psnrmax, tmp, comp: FLOAT64;  forcenew, logfile, one, two: BOOLEAN;   (* obj: vyBase.Object;  *)
		array: antsArrayObjects.tINTEGERObject;  result: antsArrayObjects.tLONGREALArray;  max, maxLogGamma: FLOAT64;  
		index, j: SIGNED32;  vecx, vecy: vyLongrealVec.tVector;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT from=REAL to=REAL by=REAL src=OBJECT [gamma=NAME] [PSNR1=NAME] [vecx=NAME] [vecy=NAME]" );  
		
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & 
		    antsCommands.ExpectReal( "by", by ) & antsCommands.ExpectObject( "src", src ) THEN 
			
			WITH tree: wedgeTrees.QuadTree DO 
				WITH src: antsArrayObjects.tLONGREALObject DO 
					logfile := antsCommands.Find( "logfile" );  loggamma := from;  
					IF antsCommands.Find( "vecx" ) & antsCommands.ExpectName( "vecx", name ) THEN vecx := Vector( name, forcenew ) END;  
					IF antsCommands.Find( "vecy" ) & antsCommands.ExpectName( "vecy", name ) THEN vecy := Vector( name, forcenew ) END;  
					comp := ABS( from - to ) / by;  index := SHORT( ENTIER( comp + 0.5 ) );  

					max := MIN( FLOAT64 );  
					
					WHILE (loggamma <= to) DO 
						gammaval := MathL.exp( loggamma * MathL.ln( 10 ) );   (* 10^loggamma *)
						
						dummy := tree.Minimize( gammaval );  
						tree.Reconstruct( result );   (* reconstruction *)
						
						
						PSNR := ComputePSNR( result, src.A );   (* Out.String( "log gamma :" );  Out.LongRealFix( loggamma, 6, 6 );  Out.String( "PSNR : " );  
						Out.LongRealFix( PSNR, 6, 6 );  Out.Ln;  *)
						aM.SRSR( "log gamma:  ", loggamma, "  PSNR:  ", PSNR );  
						IF PSNR > max THEN max := PSNR;  maxLogGamma := loggamma;  END;  
						IF vecx # NIL THEN vyLongrealVec.Append( loggamma, vecx ) END;  
						IF vecy # NIL THEN vyLongrealVec.Append( PSNR, vecy ) END;  
						loggamma := loggamma + by;  
					
					END;  
				END;  
			
			END;  
			aM.eSRSR( "Optimal log gamma:  ", maxLogGamma, "  Optimal PSNR:  ", max );  
			
			IF logfile THEN 
				name := "Optimalität bezgl. PSNR";  wedgeLog.StringIn( name );  
				(* name := "Optimal loggamma : ";  wedgeLog.StringIn( name ); *)
				wedgeLog.RealIn( maxLogGamma );  
				(* wedgeLog.LnIn;  name := "Optimal PSNR:  ";  wedgeLog.StringIn( name );  *)
				wedgeLog.RealIn( max );  wedgeLog.LnIn;  
			END;  
			
			IF antsCommands.Find( "gamma" ) & antsCommands.ExpectName( "gamma", gamma ) THEN DoSet( gamma, maxLogGamma );  
			END;  
			IF antsCommands.Find( "PSNR1" ) & antsCommands.ExpectName( "PSNR1", PSNR1 ) THEN DoSet( PSNR1, max );  END;  
			
			(* Out.String( "Optimal PSNR : " );  Out.LongRealFix( max, 6, 6 );  Out.Ln;  Out.String( "Optimal log gamma : " );  Out.LongRealFix( maxLogGamma, 6, 6 );  
			Out.Ln; *)
			
		END;  
	
	END FindOptPSNR;  

	PROCEDURE ComputePSNR*( VAR src1, src2: antsArrayObjects.tLONGREALArray ): FLOAT64;  
	VAR tmp, ssq, mse, depth, PSNR: FLOAT64;  i, j, w, h: SIGNED32;  
	BEGIN 
		depth := 256;  ssq := 0.;  w := LEN( src1 );  h := LEN( src1[0] );  
		FOR i := 0 TO w - 1 DO 
			FOR j := 0 TO h - 1 DO ssq := ssq + (src1[i, j] - src2[i, j]) * (src1[i, j] - src2[i, j]);  END;  
		END;  
		
		mse := ssq / (w * h);  tmp := depth * depth / mse;  PSNR := 10 * MathL.ln( tmp ) / MathL.ln( 10 );  RETURN PSNR;  
	END ComputePSNR;  

	PROCEDURE GC*;  
	BEGIN 
		aM.S( "GC" );  Kernel.GC;  aM.S( "GC done" );  
	END GC;  

	PROCEDURE Random*;  
	VAR name: ARRAY 256 OF CHAR;  
		real, offset: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "name=NAME range=real offset=real" );  
		IF antsCommands.ExpectName( "name", name ) & antsCommands.ExpectReal( "range", real ) & antsCommands.ExpectReal( "offset", offset ) THEN 
			DoSet( name, offset + vyRandom.Uniform() * real );  
		END;  
	END Random;  

	PROCEDURE WriteRE*;  
	VAR real: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "real=REAL" );  
		IF antsCommands.ExpectReal( "real", real ) THEN aM.eSR( "value: ", real );  aM.eSI( "is num : ", ENTIER( real + 0.5 ) );  END;  
	END WriteRE;  

	PROCEDURE WriteSE*;  
	VAR name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name=NAME" );  
		IF antsCommands.ExpectString( "name", name ) THEN aM.eS( name );  END;  
	END WriteSE;  

	PROCEDURE Distance( vec, comp: vyLongrealVec.tVector;  offset: SIGNED32 ): FLOAT64;  
	VAR pieces, i: SIGNED32;  ssq, val: FLOAT64;  
	BEGIN 
		i := 0;  ssq := 0;  
		WHILE (i < vyLongrealVec.Len( comp )) & (i + offset < vyLongrealVec.Len( vec )) DO 
			val := vyLongrealVec.Get( comp, i ) - vyLongrealVec.Get( vec, i + offset );  ssq := ssq + val * val;  INC( pieces );  INC( i );  
		END;  
		IF pieces = 0 THEN ssq := MAX( FLOAT64 );  ELSE ssq := ssq / pieces END;  
		RETURN ssq;  
	END Distance;  

	PROCEDURE FindTranslation*;  
	VAR src, dest: vyBase.Object;  from, to, i: SIGNED32;  comp: vyLongrealVec.tVector;  minpos: SIGNED32;  min, val: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "" );  
		IF antsCommands.ExpectObject( "src", src ) & antsCommands.ExpectObject( "dest", dest ) & 
		    antsCommands.ExpectNumber( "from", from ) & antsCommands.ExpectNumber( "to", to ) THEN 
			WITH src: vyLongrealVec.tVector DO 
				WITH dest: vyLongrealVec.tVector DO 
					comp := vyLongrealVec.New( to - from );  
					FOR i := from TO to - 1 DO vyLongrealVec.Set( vyLongrealVec.Get( src, i ), comp, i - from );  END;  
					min := MAX( FLOAT64 );  
					FOR i := 0 TO vyLongrealVec.Len( dest ) - 1 DO 
						val := Distance( dest, comp, i );  aM.SRSR( "at ", i, "dist", val );  
						IF val < min THEN min := val;  minpos := i END;  
					END;  
					aM.SI( "min at:", minpos );  
					aM.SRSR( "yields a value of ", -5 + (minpos) / 100 * 10 * 3, " ", MathL.exp( (-5 + (minpos) / 100 * 10 * 3) * MathL.ln( 10 ) ) );  
				END;  
			END;  
		END;  
	
	END FindTranslation;  

	PROCEDURE FirstDerivate*;  
	VAR fdx, fdy: vyBase.Object;  j: SIGNED32;  delx: FLOAT64;  bufx, bufy: vyLongrealVec.tVector;  
	BEGIN 
		antsCommands.InitScan( "fdx=OBJECT fdy=OBJECT" );  
		IF antsCommands.ExpectObject( "fdx", fdx ) & antsCommands.ExpectObject( "fdy", fdy ) THEN 
			WITH fdx: vyLongrealVec.tVector DO 
				WITH fdy: vyLongrealVec.tVector DO 
					IF vyLongrealVec.Len( fdx ) # vyLongrealVec.Len( fdy ) THEN aM.S( "vectors have different size - ending...." );  
					ELSE 
						bufx := vyLongrealVec.New( vyLongrealVec.Len( fdx ) );  
						bufy := vyLongrealVec.New( vyLongrealVec.Len( fdy ) );  
						
						FOR j := 1 TO vyLongrealVec.Len( fdx ) - 2 DO 
							delx := vyLongrealVec.Get( fdx, j + 1 ) - vyLongrealVec.Get( fdx, j );  
							vyLongrealVec.Set( (vyLongrealVec.Get( fdx, j )), bufx, j );  
							vyLongrealVec.Set( ((vyLongrealVec.Get( fdy, j + 1 )) - (vyLongrealVec.Get( fdy, j - 1 ))) / (2 * delx), bufy, j );  
						END;  
						
						vyLongrealVec.Set( vyLongrealVec.Get( fdx, 0 ), bufx, 0 );  
						vyLongrealVec.Set( vyLongrealVec.Get( fdx, vyLongrealVec.Len( fdx ) - 1 ), bufx, 
													    vyLongrealVec.Len( bufx ) - 1 );  
						
						vyLongrealVec.CopyData( bufx, fdx );  vyLongrealVec.CopyData( bufy, fdy );  
						
						(* 
						FOR j:=0 TO vyLongrealVec.Len(fdx)-1 DO
							vyLongrealVec.Set( ( vyLongrealVec.Get( bufx, j ) ), fdx, j );
							vyLongrealVec.Set( ( vyLongrealVec.Get( bufy, j ) ), fdy, j );
						END; 
						*)
						
						vyLongrealVec.Set( vyLongrealVec.Get( bufy, 1 ), fdy, 0 );  
						vyLongrealVec.Set( vyLongrealVec.Get( bufy, vyLongrealVec.Len( bufy ) - 2 ), fdy, vyLongrealVec.Len( fdy ) - 1 );  
					
					END;  
				END;  
			END;  
		END;  
	
	END FirstDerivate;  

	PROCEDURE SecondDerivate*;  
	VAR sdx, sdy: vyBase.Object;  bufx, bufy: vyLongrealVec.tVector;  j: SIGNED32;  delx1, delx2, delx3, zahl, nenn: FLOAT64;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "sdx=OBJECT sdy=OBJECT" );  
		IF antsCommands.ExpectObject( "sdx", sdx ) & antsCommands.ExpectObject( "sdy", sdy ) THEN 
			WITH sdx: vyLongrealVec.tVector DO 
				WITH sdy: vyLongrealVec.tVector DO 
					IF vyLongrealVec.Len( sdx ) # vyLongrealVec.Len( sdy ) THEN aM.S( "vectors have different size - ending...." );  
					ELSE 
						bufx := vyLongrealVec.New( vyLongrealVec.Len( sdx ) );  
						bufy := vyLongrealVec.New( vyLongrealVec.Len( sdy ) );  
						
						FOR j := 1 TO vyLongrealVec.Len( sdx ) - 2 DO 
							delx1 := vyLongrealVec.Get( sdx, j - 1 ) - vyLongrealVec.Get( sdx, j );  
							delx2 := vyLongrealVec.Get( sdx, j ) - vyLongrealVec.Get( sdx, j + 1 );  
							delx3 := vyLongrealVec.Get( sdx, j + 1 ) - vyLongrealVec.Get( sdx, j - 1 );  
							zahl := 
								2 * 
								(vyLongrealVec.Get( sdy, j + 1 ) * delx1 + vyLongrealVec.Get( sdy, j - 1 ) * delx2 + 
								  vyLongrealVec.Get( sdy, j ) * delx3);  
							nenn := (-1) * delx1 * delx2 * delx3;  

							vyLongrealVec.Set( vyLongrealVec.Get( sdx, j ), bufx, j );  vyLongrealVec.Set( (zahl / nenn), bufy, j );  
						END;  
						
						vyLongrealVec.Set( vyLongrealVec.Get( sdx, 0 ), bufx, 0 );  
						vyLongrealVec.Set( vyLongrealVec.Get( sdx, vyLongrealVec.Len( sdx ) - 1 ), bufx, 
													    vyLongrealVec.Len( bufx ) - 1 );  
						
						vyLongrealVec.CopyData( bufx, sdx );  vyLongrealVec.CopyData( bufy, sdy );  

						vyLongrealVec.Set( vyLongrealVec.Get( bufy, 1 ), sdy, 0 );  
						vyLongrealVec.Set( vyLongrealVec.Get( bufy, vyLongrealVec.Len( bufy ) - 2 ), sdy, 
													    vyLongrealVec.Len( sdy ) - 1 );  
						
						(* name:= "hakko";
						wedgeLog.StringIn(name); *)
					END;  
				END;  
			END;  
		END;  
	END SecondDerivate;  

	PROCEDURE Translate*;  
	VAR srcx, srcy, noisex, noisey, src, tree: vyBase.Object;  bufx, bufy, outx, outy: vyLongrealVec.tVector;  
		comp, tolerance, by, length, loggamma, PSNR, valx, valy, extrapol, thresh, min: FLOAT64;  
		i, j, index, maxindex, maxcount, count, border: SIGNED32;  ahead, one, two, logfile, forcenew: BOOLEAN;  
		result: antsArrayObjects.tLONGREALArray;  
		name, gammalogf, PSNRlogf, shift: ARRAY 256 OF CHAR;  
		threshc: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "srcx=OBJECT srcy=OBJECT  noisex=OBJECT  noisey=OBJECT  tolerance=REAL  by=REAL  length= REAL [src= OBJECT] [tree=OBJECT] [outx=NAME] [outy= NAME] [PSNRlogf= NAME] [gammalogf = NAME] [shift=NAME] [threshc=REAL]" );  
		IF antsCommands.ExpectObject( "srcx", srcx ) & antsCommands.ExpectObject( "srcy", srcy ) & 
		    antsCommands.ExpectObject( "noisex", noisex ) & antsCommands.ExpectObject( "noisey", noisey ) & 
		    antsCommands.ExpectReal( "tolerance", tolerance ) & antsCommands.ExpectReal( "by", by ) & antsCommands.ExpectReal( "length", length ) THEN 
			WITH srcx: vyLongrealVec.tVector DO 
				WITH srcy: vyLongrealVec.tVector DO 
					WITH noisex: vyLongrealVec.tVector DO 
						WITH noisey: vyLongrealVec.tVector DO 
							logfile := antsCommands.Find( "logfile" );  one := FALSE;  two := FALSE;  
							IF antsCommands.Find( "src" ) & antsCommands.ExpectObject( "src", src ) THEN one := TRUE;  END;  
							IF antsCommands.Find( "tree" ) & antsCommands.ExpectObject( "tree", tree ) THEN two := TRUE;  END;  
							IF antsCommands.Find( "outx" ) & antsCommands.ExpectName( "outx", name ) THEN outx := Vector( name, forcenew ) END;  
							IF antsCommands.Find( "outy" ) & antsCommands.ExpectName( "outy", name ) THEN outy := Vector( name, forcenew ) END;  
							IF antsCommands.Find( "threshc" ) & antsCommands.ExpectReal( "threshc", threshc ) THEN ELSE threshc := 0 END;  
							ahead := TRUE;  
							IF vyLongrealVec.Len( srcx ) # vyLongrealVec.Len( srcy ) THEN aM.eS( "vectors have different size - ending...." );  
							ELSE 
								
								
								
								(* Beschneiden des Rauschvektors auf eine bestimmte Länge *)
								index := SHORT( ENTIER( length / by + 0.5 ) );  aM.vSI( " index:  ", index );  bufx := vyLongrealVec.New( index );  
								bufy := vyLongrealVec.New( index );  
								FOR i := 0 TO index - 1 DO 
									vyLongrealVec.Set( vyLongrealVec.Get( noisex, i ), bufx, i );  
									vyLongrealVec.Set( vyLongrealVec.Get( noisey, i ), bufy, i );  
								END;  
								
								(* Start der Vergleichsprozedur *)
								maxindex := 0;  maxcount := 0;  
								FOR i := 0 TO vyLongrealVec.Len( srcx ) - index - 2 DO 
									ahead := TRUE;  j := 0;  count := 0;  
									WHILE (ahead) DO 
										count := count + 1;  comp := ABS( vyLongrealVec.Get( srcy, i + j ) - vyLongrealVec.Get( noisey, j ) );  
										IF comp > tolerance THEN 
											ahead := FALSE;  count := count - 1;  aM.vSR( "abbruch bei: ", vyLongrealVec.Get( srcx, i + j ) );  
											aM.vSR( "übereinstimmende Schritte: ", count );  
										END;  
										j := j + 1;  
										IF j > (index - 1) THEN ahead := FALSE;  END;  
									END;  
									IF count > maxcount THEN maxcount := count;  maxindex := i;  END;  
								
								END;  
								aM.vSRSR( "maxindex: ", maxindex, "maxcount: ", maxcount );  
								loggamma := vyLongrealVec.Get( srcx, maxindex + maxcount );   (**)
								aM.eSR( "bester Punkt bei: ", loggamma );  aM.eSR( "übereinstimmende Schritte: ", maxcount );  
								
								
								(* Erzeugen der Outputvektoren für Plot des Siegers *)
								border := vyLongrealVec.Len( noisex ) - maxindex - 1;  j := 0;  
								WHILE (border > 0) DO 
									valx := vyLongrealVec.Get( srcx, (maxindex + j) );  valy := vyLongrealVec.Get( noisey, j );  
									IF outx # NIL THEN vyLongrealVec.Append( valx, outx ) END;  
									IF outy # NIL THEN vyLongrealVec.Append( valy, outy ) END;  
									j := j + 1;  border := border - 1;  
								END;  
								
								thresh := MAX( FLOAT64 );  
								FOR i := 0 TO vyLongrealVec.Len( noisey ) - 1 DO 
									min := vyLongrealVec.Get( noisey, i );  
									IF (min < thresh) THEN thresh := min;  aM.vSR( "thresh: ", thresh );  END;  
								END;  
								thresh := thresh + threshc;  j := 0;  extrapol := MAX( FLOAT64 );  
								WHILE (extrapol > thresh) DO 
									j := j + 1;  extrapol := vyLongrealVec.Get( noisey, j - 1 );  aM.vSRSR( "j= ", j - 1, "extapol: ", extrapol );  
								END;  
								aM.vSR( "final j", j - 1 );  loggamma := vyLongrealVec.Get( srcx, (maxindex + j - 1) );  aM.eSR( "extrapolierter punkt bei: ", loggamma );  
								
								
								(* Berechnen der PSNR - erfordert tree und bildarray in der Kommandozeile *)
								
								IF (one = TRUE ) & (two = TRUE ) THEN 
									PSNR := PSNRofGamma( loggamma, tree, src );  aM.eSR( "zugehöriges PSNR: ", PSNR );  Out.String( "PSNR : " );  
									Out.LongRealFix( PSNR, 6, 6 );  Out.Ln;  
								END;  
								IF antsCommands.Find( "gammalogf" ) & antsCommands.ExpectName( "gammalogf", gammalogf ) THEN 
									DoSet( gammalogf, loggamma );  
								END;  
								IF antsCommands.Find( "PSNRlogf" ) & antsCommands.ExpectName( "PSNRlogf", PSNRlogf ) THEN DoSet( PSNRlogf, PSNR );  END;  
								
								(*Berechnung und Ausgabe des Shifts - wichtig konstantes Bild mit var=1 verrauschen *)
								min := by * maxindex;  aM.SR( "shift: ", min );  aM.SR( "factor = ", Math.exp( min * Math.ln( 10 ) ) );  
								IF antsCommands.Find( "shift" ) & antsCommands.ExpectName( "shift", shift ) THEN DoSet( shift, min );  END;  
							END;  
						END;  
					END;  
				END;  
			END;  
		END;  
	
	END Translate;  



(* Idee: Nulldurchgänge betrachten und durch Vorzeichenwechselkriterium mögliche Extrema bestimmen. 
				 evtl: (i)  sortieren nach absolutwert in y-Richtung, abschneiden und das am weitesten links in x-Richtung stehende Minimum nehmen
				 		(ii) Vektor abschneiden ( ? 50% ) das abolut grösste Minimum nehmen 
	*)

	PROCEDURE MinimaLoc*;  
	VAR vecx, vecy, fdx, fdy, src, tree: vyBase.Object;  bufx, bufy, stackx, stacky, test: vyLongrealVec.tVector;  
		j, k, l, zahl, index, rund, kleft, kright: SIGNED32;  
		kleiner, wert, grosser, min, max, comp, step, xmin, ymin, xopt, yopt, xout, yout, opt, dummy, PSNR, gammaval, xout1, test1: FLOAT64;  
		ahead, one, two, logfile: BOOLEAN;  
		wendepunkt, name, gamma1, gamma2, PSNR1, PSNR2: ARRAY 256 OF CHAR;  
		result: antsArrayObjects.tLONGREALArray;  
	BEGIN 
		antsCommands.InitScan( "vecx=OBJECT vecy=OBJECT  fdx=OBJECT  fdy=OBJECT  step=REAL [gamma1=NAME] [gamma2=NAME] [PSNR1=NAME] [PSNR2=NAME] [src= OBJECT] [tree=OBJECT] [test=REAL] " );  
		IF antsCommands.ExpectObject( "vecx", vecx ) & antsCommands.ExpectObject( "vecy", vecy ) & 
		    antsCommands.ExpectObject( "fdx", fdx ) & antsCommands.ExpectObject( "fdy", fdy ) & antsCommands.ExpectReal( "step", step ) THEN 
			WITH vecx: vyLongrealVec.tVector DO 
				WITH vecy: vyLongrealVec.tVector DO 
					WITH fdx: vyLongrealVec.tVector DO 
						WITH fdy: vyLongrealVec.tVector DO 
						(*		WITH mini: vyLongrealVec.tVector DO *)
							logfile := antsCommands.Find( "logfile" );  one := FALSE;  two := FALSE;  
							IF antsCommands.Find( "src" ) & antsCommands.ExpectObject( "src", src ) THEN one := TRUE;  END;  
							IF antsCommands.Find( "tree" ) & antsCommands.ExpectObject( "tree", tree ) THEN two := TRUE;  END;  
							
							IF vyLongrealVec.Len( vecx ) # vyLongrealVec.Len( vecy ) THEN aM.S( "vectors have different size - ending...." );  
							ELSE 
								bufx := vyLongrealVec.New( vyLongrealVec.Len( vecx ) );  
								bufy := vyLongrealVec.New( vyLongrealVec.Len( vecy ) );  k := 0;  
								
								FOR j := 1 TO vyLongrealVec.Len( vecy ) - 2 DO 
									kleiner := vyLongrealVec.Get( fdy, j - 1 );  wert := vyLongrealVec.Get( fdy, j );  
									grosser := vyLongrealVec.Get( fdy, j + 1 );  
									
									IF (kleiner < 0) & (grosser > 0) THEN 

										vyLongrealVec.Set( vyLongrealVec.Get( vecx, j ), bufx, k );  
										vyLongrealVec.Set( vyLongrealVec.Get( vecy, j ), bufy, k );  
										k := k + 1;   (* Anzahl der möglichen MInima *)
										(* aM.SRSR( "x= ", vyLongrealVec.Get( vecx, j ), "y= ", vyLongrealVec.Get( vecy, j ) ); *)
										
									END;  
								END;  
								
								aM.SI( "k=   ", k );  stackx := vyLongrealVec.New( k );  stacky := vyLongrealVec.New( k );  
								
								(* Schwellwert zur Bestimmung eines empfohlenen Minimums  - k beschreibt die Anzahl der möglichen Minima *)
								rund := SHORT( ENTIER( k / 10 + 1.5 ) );  aM.SI( "rund=   ", rund );  
								
								(* aM.S("Vektoren stackx, stacky"); *)
								FOR j := 0 TO k - 1 DO 
									vyLongrealVec.Set( vyLongrealVec.Get( bufx, j ), stackx, j );  
									vyLongrealVec.Set( vyLongrealVec.Get( bufy, j ), stacky, j );  
									(* aM.SRSR("x=  ", vyLongrealVec.Get(stackx,j), "  Y=  ", vyLongrealVec.Get(stacky,j)); *)
								END;  
								
								
								(*
								Sortieren des Vektors der potentiellen Minima, abschneiden bei einem gewissen Schwellwert, dann das  am weitesten links stehende Minimum wählen,
		(i)					zur Verbesserung der Genauigkeit in einer Umgebung des Minimums nach besserem Wert suchen	
								Evtl. als eigene Prozedur herausschreiben !!!
*)
								(* bufx := vyLongrealVec.New( k );  bufy := vyLongrealVec.New( k );  *)
								vyLongrealVec.SetLen( bufx, k );  vyLongrealVec.SetLen( bufy, k );  

								max := 0;  
								FOR j := 0 TO k - 1 DO 
									comp := vyLongrealVec.Get( stacky, j );   (*evtl. MAX prozedur herausschreiben *)
									IF comp >= max THEN max := comp;  END;  
								END;  
								(* aM.SR("max=   ", max);*)
								
								index := 0;  
								WHILE (k > 0) DO 
									min := max;  zahl := 0;  
									FOR j := 0 TO vyLongrealVec.Len( bufx ) - 1 DO 
										comp := vyLongrealVec.Get( stacky, j );  
										IF comp <= min THEN min := comp;  zahl := j;  END;  
									END;  
									(* aM.SRSR("min=    ",min, "   zahl=   ", zahl); *)
									vyLongrealVec.Set( vyLongrealVec.Get( stackx, zahl ), bufx, index );  
									vyLongrealVec.Set( vyLongrealVec.Get( stacky, zahl ), bufy, index );  index := index + 1;  
									vyLongrealVec.Set( max, stackx, zahl );  vyLongrealVec.Set( max + 1, stacky, zahl );  k := k - 1;  
								END;  
								
								aM.S( "Sortierte Ausgabe der Vektoren Bufx und Bufy" );  
								
								FOR j := 0 TO vyLongrealVec.Len( bufx ) - 1 DO 
									aM.SRSR( "x=  ", vyLongrealVec.Get( bufx, j ), "  Y=  ", vyLongrealVec.Get( bufy, j ) );  
								END;  
								
								index := 0;  max := vyLongrealVec.Get( bufx, 0 );  
								
								FOR j := 0 TO vyLongrealVec.Len( bufx ) - 1 DO 
									comp := vyLongrealVec.Get( bufx, j );  
									IF comp >= max THEN max := comp;  END;  
								END;  
								
								(* Abschneiden des Vektors der Minima. Auswählen des am weitesten links stehenden. *)
								min := max;  
								FOR j := 0 TO rund + 3 (*evtl andere Zahl, je grösser desto genauer bei kleinen schrittweiten *) DO 
									comp := vyLongrealVec.Get( bufx, j );  
									IF comp <= min THEN min := comp;  index := j;  END;  
								END;  
								xout := vyLongrealVec.Get( bufx, index );  PSNR := PSNRofGamma( xout, tree, src );  aM.eS( "potential inflection point at" );  
								aM.eSRSR( " x=   ", vyLongrealVec.Get( bufx, index ), "   y=  ", vyLongrealVec.Get( bufy, index ) );  
								aM.eSRSR( " x=   ", xout, "  PSNR", PSNR );  xout1 := xout;  
								(*
								IF logfile THEN 
									name := "Wendepunkt-Algorithmus  #1";  wedgeLog.StringIn( name );  
									(* name := "zweiter Wendepunkt bei   ";  wedgeLog.StringIn( name ); *)
									wedgeLog.RealIn( xout );  wedgeLog.RealIn( PSNR );  
									(* wedgeLog.LnIn;  name := "zugehörige PSNR: ";  wedgeLog.StringIn( name ); *)
									wedgeLog.LnIn;  wedgeLog.LnIn;  
								END;  
								
								IF antsCommands.Find( "gamma1" ) & antsCommands.ExpectName( "gamma1", gamma1 ) THEN DoSet( gamma1, xout1 );  
								END;  
								IF antsCommands.Find( "PSNR1" ) & antsCommands.ExpectName( "PSNR1", PSNR1 ) THEN DoSet( PSNR1, PSNR );  END;  
								*)
								
								(* Suche nach "besseren" Werten in der Nähe des bestimmten "Optimums" *)
								xmin := vyLongrealVec.Get( bufx, index );  ymin := vyLongrealVec.Get( bufy, index );  
								comp := 10 / (100 * step);  k := SHORT( ENTIER( comp + 0.5 ) );  aM.SI( "k:= ", k );  l := vyLongrealVec.Len( vecx );  
								(*Bestimmung der Position des Minimums im ursprünglichen unsortierten Vektor - Variable index*)
								FOR j := 0 TO vyLongrealVec.Len( vecx ) - 1 DO 
									comp := vyLongrealVec.Get( vecx, j );  
									IF comp = xmin THEN index := j;  END;  
								END;  
								aM.SISI( "länge=  ", vyLongrealVec.Len( vecx ), "   index =   ", index );  
								
								(* Suchen links vom Wert *)
								ahead := TRUE;  
								WHILE (ahead) DO 
									aM.eS( "searching left..." );  ahead := FALSE;  zahl := index;  
									IF index - k < 0 THEN kleft := index;  aM.SI( "beginning point is near the left boundary - shortening search intervall...", index );  ELSE kleft := k;  END;  
									
									FOR j := index - kleft TO index - 1 DO 
										aM.SR( "x= ", vyLongrealVec.Get( vecx, j ) );  comp := vyLongrealVec.Get( vecy, j );  
										IF comp <= ymin THEN 
											ymin := comp;  ahead := TRUE;  zahl := j;  
											aM.SRSR( "potential new minimum at   ", vyLongrealVec.Get( vecx, j ), "  with value  ", vyLongrealVec.Get( vecy, j ) );  
											aM.eSRSR( "potential new minimum at   ", vyLongrealVec.Get( vecx, j ), "  with value  ", vyLongrealVec.Get( vecy, j ) );  
										END;  
									END;  
									index := zahl;  
									IF ahead = FALSE THEN aM.S( "found nothing better in this direction" );  END;  
								
								END;  
								
								(*Suchen rechts vom Wert*)
								ahead := TRUE;  
								WHILE (ahead) DO 
									aM.eS( "searching right...." );  ahead := FALSE;  
									IF index + k - 1 > l THEN kright := l - index;  aM.SI( "beginning point is near the right boundary - shortening search intervall...", k );  ELSE kright := k;  END;  
									zahl := index;  
									FOR j := index + 1 TO index + kright DO 
										aM.SR( "x= ", vyLongrealVec.Get( vecx, j ) );  comp := vyLongrealVec.Get( vecy, j );  
										IF comp < ymin THEN 
											ymin := comp;  ahead := TRUE;  zahl := j;  
											aM.SRSR( "potential new minimum at   ", vyLongrealVec.Get( vecx, j ), "  with value  ", vyLongrealVec.Get( vecy, j ) );  
										END;  
									END;  
									index := zahl;  
									IF ahead = FALSE THEN aM.S( "found nothing better in this direction" );  END;  
								END;  
								xout := vyLongrealVec.Get( vecx, index );  yout := vyLongrealVec.Get( vecy, index );   (**)
								IF (one = TRUE ) & (two = TRUE ) THEN 
									(*	WITH tree: wedgeTrees.QuadTree DO 
										WITH src: antsArrayObjects.tLONGREALObject DO 
											gammaval := MathL.exp( xout * MathL.ln( 10 ) );  dummy := tree.Minimize( gammaval );  
											tree.Reconstruct( result );  PSNR := ComputePSNR( result, src.A );  
										END;  
									END;  
								*)
									PSNR := PSNRofGamma( xout, tree, src );  
								
								END;  
								aM.S( "new minimum:  " );  aM.eSRSR( " x=   ", vyLongrealVec.Get( vecx, index ), "  y=  ", vyLongrealVec.Get( vecy, index ) );  
								aM.eSRSR( " x=   ", xout, "  PSNR= ", PSNR );  
								
								IF logfile THEN 
									name := "Wendepunkt-Algorithmus  #2";  wedgeLog.StringIn( name );  
									(* name := "zweiter Wendepunkt bei   ";  wedgeLog.StringIn( name ); *)
									wedgeLog.RealIn( xout );  wedgeLog.RealIn( PSNR );  
									(* wedgeLog.LnIn;  name := "zugehörige PSNR: ";  wedgeLog.StringIn( name ); *)
									wedgeLog.LnIn;  
								END;  
								
								IF antsCommands.Find( "gamma2" ) & antsCommands.ExpectName( "gamma2", gamma2 ) THEN DoSet( gamma2, xout );  
								END;  
								IF antsCommands.Find( "PSNR2" ) & antsCommands.ExpectName( "PSNR2", PSNR2 ) THEN DoSet( PSNR2, PSNR );  END;  
								
								(* einige Ideen zur "Verbesserung" des  Algorithmus - grösstenteils schlecht bzw nicht robust  *)
								(*    (1) Abstand  *)
								IF antsCommands.Find( "test" ) & antsCommands.ExpectReal( "test", test1 ) THEN 
									wert := test1 - xout;  wert := (2 * wert) / 3;  wert := test1 - wert;  
									wert := (ENTIER( 100 * wert + 0.5 )) / 100;  PSNR := PSNRofGamma( wert, tree, src );  
									aM.eSRSR( " x_abstand=   ", wert, "  PSNR= ", PSNR );  
								END;  
								
								(*	(2)  Mittelwert der y-Werte zwischen Anfang und 2.Wendepunkt -> dazugehöriges x *)
								wert := 0;  
								FOR j := 0 TO index DO wert := wert + vyLongrealVec.Get( vecy, j );  END;  
								comp := wert / (index + 1);  grosser := 1000;  
								FOR j := 0 TO index DO 
									wert := vyLongrealVec.Get( vecy, j );  kleiner := comp - wert;  
									IF wert > comp THEN kleiner := kleiner * (-1);  END;  
									IF kleiner < grosser THEN grosser := kleiner;  min := vyLongrealVec.Get( vecx, j );  END;  
								END;  
								PSNR := PSNRofGamma( min, tree, src );  aM.eSRSR( " x_mittel=   ", min, "  PSNR= ", PSNR );  
								
								IF logfile THEN 
									name := "Mittelwert Algorithmus";  wedgeLog.StringIn( name );  wedgeLog.RealIn( min );  wedgeLog.RealIn( PSNR );  
									wedgeLog.LnIn;  wedgeLog.LnIn;  
								END;  
								
								IF antsCommands.Find( "gamma1" ) & antsCommands.ExpectName( "gamma1", gamma1 ) THEN DoSet( gamma1, min );  
								END;  
								IF antsCommands.Find( "PSNR1" ) & antsCommands.ExpectName( "PSNR1", PSNR1 ) THEN DoSet( PSNR1, PSNR );  END;  
							END;  
						END;  
					END;  
				END;  
			END;  
		END;  
	END MinimaLoc;  

	PROCEDURE PSNRofGamma*( loggamma: FLOAT64;  tree, src: vyBase.Object ): FLOAT64;  
	VAR gammaval, PSNR, dummy: FLOAT64;  result: antsArrayObjects.tLONGREALArray;  
	BEGIN 
		WITH tree: wedgeTrees.QuadTree DO 
			WITH src: antsArrayObjects.tLONGREALObject DO 
			(* gammaval := MathL.exp( loggamma * MathL.ln( 10 ) );  dummy := tree.Minimize( gammaval ); *)  (*berechnet falsche Werte für PSNR*)
				loggamma := MathL.exp( loggamma * MathL.ln( 10 ) );  dummy := tree.Minimize( loggamma );  
				tree.Reconstruct( result );  PSNR := ComputePSNR( result, src.A );  
			
			END;  
		END;  
		RETURN PSNR;  
	END PSNRofGamma;  





(* Sortieren der Werte eines Vektors - brute force *)
	PROCEDURE SortVec( vec: vyLongrealVec.tVector ): vyLongrealVec.tVector;  
	VAR buffer: vyLongrealVec.tVector;  j, zahl, k, index: SIGNED32;  comp, min, max: FLOAT64;  
	BEGIN 
		k := vyLongrealVec.Len( vec );  buffer := vyLongrealVec.New( k );  max := 0;  
		FOR j := 0 TO k - 1 DO 
			comp := vyLongrealVec.Get( vec, j );  
			IF comp >= max THEN max := comp;  END;  
		END;  
		index := 0;  
		WHILE (k > 0) DO 
			min := max;  zahl := 0;  
			FOR j := 0 TO vyLongrealVec.Len( vec ) - 1 DO 
				comp := vyLongrealVec.Get( vec, j );  
				IF comp <= min THEN min := comp;  zahl := j;  END;  
			END;  
			vyLongrealVec.Set( vyLongrealVec.Get( vec, zahl ), buffer, index );  index := index + 1;  
			vyLongrealVec.Set( max, vec, zahl );  k := k - 1;  
		END;  
		
		FOR j := 0 TO vyLongrealVec.Len( buffer ) - 1 DO aM.SR( "x=  ", vyLongrealVec.Get( buffer, j ) );  END;  
		
		RETURN buffer;  
	
	END SortVec;  

	PROCEDURE VecXY*;  
	VAR vecx, vecy: vyBase.Object;  x, y: FLOAT64;  j: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "vecx=OBJECT vecy=OBJECT " );  
		IF antsCommands.ExpectObject( "vecx", vecx ) & antsCommands.ExpectObject( "vecy", vecy ) THEN 
			WITH vecx: vyLongrealVec.tVector DO 
				WITH vecy: vyLongrealVec.tVector DO 
					IF vyLongrealVec.Len( vecx ) # vyLongrealVec.Len( vecy ) THEN aM.S( "vectors have different size - ending...." );  ELSE 
						FOR j := 0 TO vyLongrealVec.Len( vecx ) - 1 DO 
							aM.SRSR( "x=   ", vyLongrealVec.Get( vecx, j ), "  y=  ", vyLongrealVec.Get( vecy, j ) );  
						END;  
					END;  
				END;  
			END;  
		END;  
	END VecXY;  

	PROCEDURE PrintVec*;  
	VAR vec: vyBase.Object;  j: SIGNED32;  
	BEGIN 
		antsCommands.InitScan( "vec=OBJECT" );  
		IF antsCommands.ExpectObject( "vec", vec ) THEN 
			WITH vec: vyLongrealVec.tVector DO 
				FOR j := 0 TO vyLongrealVec.Len( vec ) - 1 DO aM.SR( "", vyLongrealVec.Get( vec, j ) );  END;  
			END;  
		END;  
	END PrintVec;  

	PROCEDURE StartTiming*;  
	BEGIN 
		time := Oberon.Time();  
	END StartTiming;  

	PROCEDURE StopTiming*;  
	BEGIN 
		aM.eSI( "time= ", Oberon.Time() - time );  
	END StopTiming;  

END wedgeNumOps.

wedgeNumOps.Copy penaltyveclog penaltyveclog1 ~
wedgeNumOps.FindTranslation penaltyveclog1 penaltyveclog 20 37 ~

wedgeNumOps.OpenDocument test ~

wedgeNumOps.NewNoisyArray testarray 256 256 ~
antsViews.Show testarray ~

fofAutomatic.Do 
wedgeNumOps.NewReal w 0 ~
wedgeNumOps.NewReal h w ~
wedgeNumOps.NewVec sizevec ~
wedgeNumOps.NewVec approxpreparevec ~
wedgeNumOps.NewVec approxvec ~
~
fofAutomatic.Do >iter 50
wedgeNumOps.Add w 10 ~
wedgeNumOps.NewReal h w ~
wedgeNumOps.Mult h 1 ~
wedgeNumOps.NewNoisyArray testarray w=w h=h ~
wedgeCommands.NewTree src=testarray tree=myTree  ~
wedgeNumOps.Mult h w ~
wedgeNumOps.Append h sizevec ~
wedgeCommands.NewConstRectModel model=rectModel ~
wedgeNumOps.GC  ~
wedgeCommands.PlugIn tree=myTree model=rectModel ~
wedgeNumOps.Statistics tree=myTree   approxprepareT=approxprepare approxT=approx ~
wedgeNumOps.Append  approxprepare approxpreparevec~
wedgeNumOps.Append  approx approxvec~
~
fofAutomatic.Do
wedgeNumOps.ShowVec  vecx=sizevec vecy=approxpreparevec port=View3 >forcenew ~
vyGraphicCtl.SetWidth 3 ~
vyGraphicCtl.SetColor FORECOL 3 ~
vyGraphicCtl.SetBackColor 0 ~
vyScale.Insert ~
wedgeNumOps.ShowVec  vecx=sizevec vecy=approxvec port=View3  ~
vyGraphicCtl.SetWidth 3 ~
vyGraphicCtl.SetColor FORECOL 1 ~
~
