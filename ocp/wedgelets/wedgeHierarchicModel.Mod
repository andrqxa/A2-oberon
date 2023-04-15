MODULE wedgeHierarchicModel IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT antsArrays, wedgeTrees, wedgeConstantModels, wedgeLinearModels, wedgeQuadraticModels, antsArrayObjects, vyBase, antsCommands, 
	aM := antsMessages, vyName,Out,antsFunctions,Oberon;  

TYPE 
	PlugInQ = OBJECT 
	VAR model: wedgeTrees.Model;  
		a: wedgeTrees.LocalApproximation;  
		name: ARRAY 256 OF CHAR;  
		next: PlugInQ;  
	END PlugInQ;  
	
	Function = PROCEDURE {DELEGATE} ( from, to: SIGNED32 ): FLOAT64;  
	(*! für Katrin Modul: Indexverschiebung in der Statistik! *)
		
	ApproxQ*= OBJECT
	VAR 
		a*: wedgeTrees.LocalApproximation; 
		x-,y-,w-,h-: SIGNED32;
		next*: ApproxQ; 
	END ApproxQ; 

	Tree* = OBJECT (vyBase.Object)
	VAR
		plugins: PlugInQ;  
		src: antsArrayObjects.tLONGREALObject;  
		w*, h*, depth: SIGNED32;  
		transpose: BOOLEAN; 
		approxQ*: ApproxQ; 
		preparetime*, mintime* : SIGNED32; 
		PROCEDURE &Init;
		BEGIN
			preparetime := 0; mintime := 0;  approxQ := NIL; plugins := NIL; 
		END Init;
	END Tree;  

	Stripe = OBJECT 
	VAR fromh, toh: SIGNED32;  
		hor: BOOLEAN;  
		gamma: FLOAT64;  
		plugins: PlugInQ;  minQ: PlugInQ; 
		(*a: wedgeTrees.LocalApproximation;  
		model: wedgeTrees.Model;  *)
		
		PROCEDURE BestLocalApprox( fromv, tov: SIGNED32 ): FLOAT64;  
		VAR p: PlugInQ;  min, cur: FLOAT64;  
		BEGIN 
			min := MAX( FLOAT64 );  p := plugins;  
			WHILE (p # NIL ) DO 
				IF p.a # NIL THEN p.a.distance := MAX( FLOAT64 ) END;  
				p.model.Approximate( fromh, fromv, toh - fromh + 1, tov - fromv + 1, p.a ); 
				IF p.a = NIL THEN cur := MAX( FLOAT64 ) ELSE 
					IF p.a.distance <0 THEN p.a.distance := 0 END; 
					cur := gamma  * p.a.penalty  + p.a.distance; p.a.model := p.model END;  
				IF cur < min THEN minQ := p; min := cur;  (* a := p.a;  model := p.model;  *) 
					END;  
				p := p.next;  
			END;  
			(* ASSERT ( model # NIL );  *)
			RETURN min;  
		END BestLocalApprox;  

		PROCEDURE WriteBack( rstern: antsArrays.I1d;  len: SIGNED32;  reco: antsArrayObjects.tLONGREALArray; tree: Tree );  
		VAR k, next, y: SIGNED32;  min: FLOAT64;  q: ApproxQ; 
		BEGIN 
			k := len;   (* fof 020709 *)
			WHILE (k > 0) DO 
				next := rstern[k];  minQ := NIL;  min := BestLocalApprox( next, k - 1 );  
				IF (minQ # NIL ) THEN 
					minQ.model.Reconstruct( fromh, next, toh - fromh + 1, k - next, minQ.a, reco );  
					NEW(q); 
					q.x := fromh; q.y := next; q.w := toh - fromh + 1; q.h := k - next; 
					q.a := minQ.a; 
					q.next :=  tree.approxQ; 
					tree.approxQ := q; 
					minQ.a := NIL; 
				END;  
				k := next
			
			END 
		
		END WriteBack;  

	END Stripe;  
	TYPE 
	
	MaskArray = POINTER TO ARRAY OF BOOLEAN;  
	
	Global = OBJECT 
	VAR hor: BOOLEAN;  
		gamma: FLOAT64;  
		model: wedgeTrees.Model;  
		stripe: Stripe;  
		len: SIGNED32;  
		argmin: antsArrays.I1d;  
		min: antsArrays.X1d;  
		mask: MaskArray;  
		
		PROCEDURE BestLocalApprox( fromh, toh: SIGNED32 ): FLOAT64;  
		VAR a: wedgeTrees.LocalApproximation;  
		BEGIN 
			stripe.fromh := fromh;  stripe.toh := toh;  
			DynMinimize( stripe.BestLocalApprox, len, gamma, argmin, min, mask^, FALSE );  RETURN min[SELF.len ];  
		END BestLocalApprox;  

		PROCEDURE WriteBack( VAR reco: antsArrayObjects.tLONGREALArray;  len: SIGNED32;  rstern: antsArrays.I1d ; tree: Tree);  
		VAR k, next: SIGNED32;  
		BEGIN 
			k := len;  
			WHILE (k > 0) DO 
				next := rstern[k];  stripe.fromh := next;  stripe.toh := k - 1;  
				DynMinimize( stripe.BestLocalApprox, SELF.len, gamma, argmin, min, mask^, FALSE );  
				stripe.WriteBack( argmin, SELF.len, reco ,tree);  k := next
			END 
		END WriteBack;  

	END Global;  
	

	PROCEDURE AddPlugIn( VAR root: PlugInQ;  model: wedgeTrees.Model;  name: ARRAY OF CHAR ): PlugInQ;  
	VAR p: PlugInQ;  
	BEGIN 
		IF root = NIL THEN NEW( root );  root.model := model;  COPY( name, root.name );  RETURN root;  END;  
		p := root;  
		WHILE (p # NIL ) DO 
			IF (p.model # model) THEN 
				IF (p.name = name) THEN aM.eSS( "Warning, different model with same identifier added: ", name );  END;  
			ELSE 
				RETURN p;   (*do not integrate more than once *)
			END;  
			p := p.next;  
		END;  
		NEW( p );  p.model := model;  COPY( name, p.name );  p.next := root;  root := p;  RETURN p;  
	END AddPlugIn;  

	PROCEDURE Max( i, j: SIGNED32 ): SIGNED32;  
	BEGIN 
		IF i > j THEN RETURN i ELSE RETURN j END 
	END Max;  

	PROCEDURE Min( i, j: SIGNED32 ): SIGNED32;  
	BEGIN 
		IF i < j THEN RETURN i ELSE RETURN j END 
	END Min;  


	PROCEDURE DynMinimize*( p: Function;  len: SIGNED32;  gamma: FLOAT64;  VAR argmin: antsArrays.I1d;  VAR min: antsArrays.X1d;  
												 VAR mask: ARRAY OF BOOLEAN;  report: BOOLEAN );  
	VAR i, j: SIGNED32;  minpos: SIGNED32;  minv, current: FLOAT64;  
	BEGIN 
		IF (min = NIL ) OR (LEN( min ) # len + 1) THEN NEW( min, len + 1 );  NEW( argmin, len + 1 ) END;  
		argmin[0] := MIN( SIGNED16 );  argmin[0] := 0;  min[0] := 0; (* -gamma; if counting the boundaries *) 
		FOR i := 1 TO (len ) DO  (* vorsicht: Index-Verschiebung durch den Startwert der Bellman-Fkt *)
			IF report THEN Out.String("computing step "); Out.Int(i,0); Out.String(" "); END; 
				minpos := argmin[i - 1];  minv := MAX( FLOAT64 );  min[i] := 0;  
			FOR j := 1 TO i DO 
				IF mask[i - j] THEN 
					IF (min[j-1] # MAX( FLOAT64 )) THEN  (* evaluate only if chance that better *)
						current := min[j-1] + p( j-1, i-1 );
						IF current < 0 THEN aM.S("current < 0 !"); current := 0; END; 
						IF current < minv THEN minv := current;  minpos := j-1;  END;  
						IF report THEN Out.String("x"); END;
							ELSIF report THEN Out.String(":"); 
					END;  
				ELSIF report THEN Out.String("."); 				
				END;  
				END;  
			IF report THEN Out.String(" done "); Out.Ln; END; 
			argmin[i] := SHORT( minpos );  min[i] := minv;  
			(* IF report THEN aM.SISI( "DynMinimize: Done step ", i , "result = ",minpos) END;  *) 
		END;  
		(*Step( argmin^, min^, len, 0, maxlen, p ) (* fill last points *)*)
	END DynMinimize;  

	
	
	
	PROCEDURE GlobalMinimize( gamma: FLOAT64;  maskw,maskh: MaskArray;  tree: Tree;  VAR reco: antsArrayObjects.tLONGREALArray; report: BOOLEAN );  
	VAR stripe: Stripe;  global: Global;  argmin: antsArrays.I1d;  min: antsArrays.X1d;  len, i: SIGNED32;  
		array: vyBase.Object;   (*reco: antsArrayObjects.tLONGREALArray;  *)
		mask: MaskArray;  
	BEGIN 
		aM.S( "Starting Global Minimization" );  NEW( stripe );  stripe.plugins := tree.plugins;  stripe.gamma := gamma;  NEW( global );  global.stripe := stripe;  
		global.len := tree.h;   (* global.minlen := minlen;  global.maxlen := maxlen; *) len := tree.w;  aM.S( "Preparation done." );  
		global.mask := maskh; mask := maskw; 
		(*
		NEW( global.mask, tree.h );  NEW( mask, tree.w );  
		FOR i := 0 TO tree.h - 1 DO 
			global.mask[i] := (minh - 1 <= i) & (maxh - 1 >= i);  
			(*IF global.mask[i] THEN aM.SI( "mask set at:", i );  END;  *)
		END;  
		FOR i := 0 TO tree.w - 1 DO mask[i] := (minw - 1 <= i) & (maxw - 1 >= i);  END;  
		*) 
		tree.approxQ := NIL; 
		DynMinimize( global.BestLocalApprox, len, gamma, argmin, min, mask^, report );  aM.S( "DynMinimize done." );  NEW( reco, tree.h, tree.w );  
		(*FOR i := 0 TO LEN( argmin ) - 1 DO aM.SISI( "argmin[", i, "] = ", argmin[i] );  END;  *)
		
		global.WriteBack( reco, len, argmin ,tree);  aM.S( "WriteBack  done." );  
		(*array := antsArrayObjects.IntObjR( reco, 256 );  vyName.RegisterNamed( array, "result" );  *)
	END GlobalMinimize;  

	PROCEDURE ScaledGamma( gamma, w, h, depth: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN gamma * w * h * depth * depth / 65536;  
	END ScaledGamma;  

	PROCEDURE Transpose(VAR array: antsArrayObjects.tLONGREALArray);
	VAR copy: antsArrayObjects.tLONGREALArray; x,y: SIGNED32; 
	BEGIN
					copy := antsArrayObjects.NewLONGREALArray(LEN(array),LEN(array[0]));
					FOR y := 0 TO LEN(array)-1 DO 
					FOR x := 0 TO LEN(array[0])-1 DO 
						copy[x,y] := array[y,x]; 
					END; 
					END; 
		array := copy; 
	END Transpose;


	PROCEDURE NewTree*;  
	VAR model: Tree;  src, obj: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		array: antsArrayObjects.tLONGREALArray;  
	BEGIN 
		antsCommands.InitScan( "source=OBJECT name=NAME|OBJ [>forceNew]" );  
		IF antsCommands.ExpectObject( "source", src ) THEN 
			IF (~antsCommands.Find( "forceNew" )) & antsCommands.GetObject( "name", obj ) THEN 
				model := obj( Tree );  vyName.GetObjId( model, name ); model.Init;  
			ELSIF antsCommands.ExpectName( "name", name ) THEN NEW( model );  vyName.RegisterNamed( model, name );  
			ELSE RETURN 
			END;  
			model.transpose := antsCommands.Find("transpose");
			WITH src: antsArrayObjects.tINTEGERObject DO 
				antsArrayObjects.CopyIR( src.A, array, 0, 0, src.w, src.h, 0, 0 );  
				IF model.transpose THEN 
					Transpose(array); 
					END; 
				model.src := antsArrayObjects.RealObj( array, src.depth );  model.w := src.w;  model.h := src.h;  
				model.depth := src.depth;  aM.SS( "New 'tree' created: ", name );  
			END;  
		END;  
	END NewTree;  

	PROCEDURE AddModel*;  
	VAR tree, model: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ model=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectObject( "model", model ) THEN 
			WITH tree: Tree DO 
				WITH model: wedgeTrees.Model DO 
					vyName.GetObjId( model, name );  aM.SS( "adding model:", name );  tree.plugins := AddPlugIn( tree.plugins, model, name );  
					(* model.PrepareApproximation( tree.src.A ); *)  aM.S( "model added." );  
				END;  
			END;  
		END;  
	END AddModel;  
	
	PROCEDURE AddCRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeConstantModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeConstantModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: Tree DO tree.plugins := AddPlugIn( tree.plugins, model, name);  
			END;  
		END;  
	END AddCRect;  

	PROCEDURE AddLRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeLinearModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeLinearModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: Tree DO tree.plugins := AddPlugIn( tree.plugins, model, name);  
			END;  
		END;  
	END AddLRect;  

	PROCEDURE AddQRect*;   (* plug in new rect model into tree, creates new model if necessary *)
	VAR model: wedgeQuadraticModels.RectModel;  tree, obj: vyBase.Object;  name: vyName.tNameArray;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF antsCommands.GetObject( "model", obj ) THEN 
				model := obj( wedgeQuadraticModels.RectModel );  vyName.GetObjId( model, name );  
			ELSIF antsCommands.ExpectName( "model", name ) THEN NEW( model );  vyName.RegisterNamed( model, name )
			END;  
			WITH tree: Tree DO tree.plugins := AddPlugIn( tree.plugins, model, name);  
			END;  
		END;  
	END AddQRect;  
	
	PROCEDURE GreatestDivisorPower2( i: SIGNED32 ): SIGNED32;  
	VAR j, k: SIGNED32;  
	BEGIN 
		j := 1;  k := 0;  
		WHILE ((i DIV j) * j = i) DO INC( k );  j := j * 2;  END;  
		RETURN k;  
	END GreatestDivisorPower2;  

	PROCEDURE AddCWedge*;   (* PlugIn constant wedge model with given angles, creates new model if none given *)
	VAR tree, obj: vyBase.Object;  p: antsCommands.tParameter;  name: vyName.tNameArray;  from, to, by: FLOAT64;  
		l: antsCommands.tScanList;  model: wedgeConstantModels.WedgeModel;  i, iterations, iter, offset: SIGNED32; numberofangles: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( " tree=OBJECT model=(OBJECT|NAME) (angles={REAL}| >steps from=REAL to=REAL by=REAL)" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			WITH tree: Tree DO 
				IF antsCommands.Find("numberofangles") THEN 
					IF antsCommands.ExpectReal("numberofangles",numberofangles) THEN 
						iterations := ENTIER(numberofangles+0.5); 
						FOR i := 1 TO iterations DO 
							NEW(model); 
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.plugins := AddPlugIn( tree.plugins, model, "wedge");   
						END; 
					END; 
				ELSIF antsCommands.Find( "steps" ) THEN 
					IF antsCommands.ExpectReal( "from", from ) & antsCommands.ExpectReal( "to", to ) & antsCommands.ExpectReal( "by", by ) THEN 
						WHILE (from <= to) DO
										NEW( model );   
							aM.SR( "setting angle: ", from );  model.SetAngle( from ); tree.plugins := AddPlugIn( tree.plugins, model, "wedge");   from := from + ABS( by );  
						END;  
					END;  
				ELSIF antsCommands.Find( "angles" ) THEN 
					p := antsCommands.ParsFromKeyword( l, "angles" );  
					IF (p = NIL ) & antsCommands.ExpectReal( "angles", by ) THEN END;  
					WHILE p # NIL DO 
						NEW( model ); 
						aM.SR( "setting angle: ", p( antsCommands.tReal ).real );  model.SetAngle( p( antsCommands.tReal ).real );  
						tree.plugins := AddPlugIn( tree.plugins, model, "wedge"); p := p.next;  
					END;  
				ELSIF antsCommands.Find( "adaptive" ) THEN 
					IF antsCommands.ExpectNumber( "numofangles", iterations ) & antsCommands.ExpectNumber( "offset", offset ) THEN 
						FOR i := 1 TO iterations DO 
							NEW( model );
							from := 180 / iterations * i;  aM.SR( "setting angle: ", from );  model.SetAngle( from );  
							iter := GreatestDivisorPower2( i ) + offset;  aM.SI( "with max depth:", iter );  tree.plugins := AddPlugIn( tree.plugins, model, "wedge");  
						END;  
					END;  
				ELSE HALT(100);
				END;  
			END;  
		END;  
	END AddCWedge;  

	PROCEDURE Minimize*;  
	VAR src, obj: vyBase.Object;  tree: vyBase.Object;  
		name: ARRAY 256 OF CHAR;  
		maxdepth: SIGNED32;  model: wedgeConstantModels.RectModel;  gamma: FLOAT64;  minw, maxw,minh,maxh,t: SIGNED32;  
		result: antsArrayObjects.tLONGREALArray;  array: vyBase.Object;  p: PlugInQ; maskw,maskh: MaskArray; i: SIGNED32;  par: antsCommands.tParameter;	l: antsCommands.tScanList;  
		mnum: SIGNED32; 
	BEGIN 
		antsCommands.InitScan( "tree=OBJECT gamma=REAL  minw=NUMBER maxw=NUMBER result=OBJ|NAME" );  
		IF antsCommands.ExpectObject( "tree", tree ) & antsCommands.ExpectReal( "gamma", gamma ) & 
		    antsCommands.ExpectNumber( "minw", minw ) & antsCommands.ExpectNumber( "maxw", maxw ) 
		    & antsCommands.ExpectNumber( "minh", minh ) & antsCommands.ExpectNumber( "maxh", maxh ) 
		    THEN 
			WITH tree: Tree DO 
				aM.S("Preparation of data."); 
				p := tree.plugins; 
				t := Oberon.Time(); 
				WHILE(p # NIL) DO 
					aM.SS("preparing ",p.name); 
					p.model.PrepareApproximation(tree.src.A); 
					p := p.next; 
				END; 
				tree.preparetime := Oberon.Time()-t; 
				NEW(maskw,tree.w); NEW(maskh,tree.h); 
				FOR i := 0 TO tree.h - 1 DO 
					maskh[i] := (minh - 1 <= i) & (maxh - 1 >= i);  
			(*IF global.mask[i] THEN aM.SI( "mask set at:", i );  END;  *)
		END;  
		FOR i := 0 TO tree.w - 1 DO maskw[i] := (minw - 1 <= i) & (maxw - 1 >= i);  END;  


				
				IF antsCommands.Find("widths") THEN (* allow additional widths *) 
					par := antsCommands.ParsFromKeyword( l, "widths" );  
					WHILE par # NIL DO 
						mnum := par( antsCommands.tNumber).number; 
						aM.SR( "setting additional width: ", mnum ); 
						IF (0< mnum) & (mnum <= LEN(maskw)) THEN 
							maskw[mnum-1] := TRUE; 
						END; 
					  par := par.next;  
					END;  

				END; 
				IF antsCommands.Find("heights") THEN  (* allow aditional heights *) 
						par := antsCommands.ParsFromKeyword( l, "heights" ); 
						WHILE par # NIL DO
									mnum := par( antsCommands.tNumber).number; 
						aM.SR( "setting additional height: ", mnum ); 
						IF (0< mnum) & (mnum <= LEN(maskh)) THEN 
							maskh[mnum-1] := TRUE; 
						END; 
					  par := par.next;  
						END; 
				END; 
								aM.S( "Starting Minimization" ); 
				t := Oberon.Time(); 
				 GlobalMinimize( ScaledGamma( gamma, tree.w, tree.h, tree.depth ), maskw,maskh, tree, result ,~antsCommands.Find("silent"));  
				 tree.mintime := Oberon.Time()-t; 
				 IF tree.transpose THEN Transpose(result) END; 
				 vyBase.Update(tree); 
				aM.S( "Minimization done." );  

				IF antsCommands.GetObject( "result", array ) THEN 
					WITH array: antsArrayObjects.tINTEGERObject DO 
					(*
						antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  
						*)
						
						antsArrayObjects.ChangeSize( array, LEN(result[0]), LEN(result) );  antsArrayObjects.SetDepth( array, tree.depth );  
						antsArrayObjects.SetLongreal( array, result );   (*  vyBase.ForUsersHandle( array, msg ); *)
						vyBase.Update( array );  
					END;  
				ELSIF antsCommands.ExpectName( "array", name ) THEN 
					(*antsArrays.MinMax2dX( result^, min, max );  aM.SRSR( "AResult: min", min, "max", max );  *)
					array := antsArrayObjects.IntObjR( result, tree.depth );  vyName.RegisterNamed( array, name );  
				END;  
			END;  
		
		END;  
	END Minimize;  

	PROCEDURE MakeHorizon*;
	VAR obj,function: vyBase.Object; w,h,lower,upper,x,y: SIGNED32; value: FLOAT64; below: BOOLEAN; array: antsArrayObjects.tINTEGERObject; name: ARRAY 256 OF CHAR; 
	BEGIN
	antsCommands.InitScan( "function=OBJECT (array=OBJECT| array=NAME  w=NUMBER h=NUMBER)  lower=NUMBER upper=NUMBER" );
		IF antsCommands.ExpectObject("function",function) THEN 
			IF antsCommands.GetObject("array",obj) THEN 
				array := obj(antsArrayObjects.tINTEGERObject); 
				IF antsCommands.GetNumber("w",w) & antsCommands.GetNumber("h",h) THEN 
					antsArrayObjects.ChangeSize(array,w,h); 
				END; 
			ELSIF antsCommands.ExpectName("array",name)  THEN 
					IF antsCommands.ExpectNumber("w",w) & antsCommands.ExpectNumber("h",h) THEN 
					array := antsArrayObjects.NewINTEGERObject(w,h,256); 
					vyName.RegisterNamed(array,name); 
					END; 
			ELSE RETURN 
			END; 
			IF antsCommands.ExpectNumber("lower",lower) & antsCommands.ExpectNumber("upper",upper) THEN 
			
				WITH function: antsFunctions.Function DO
					FOR x := 0 TO array.w-1 DO 
						value := function.get(function,x/array.w);
						FOR y := 0 TO array.h-1 DO 
							IF (y/(array.h) < value) & (lower >=0) THEN 
								array.A[y,x] := SHORT(lower); 
							ELSIF (y/(array.h)>=value) & (upper>=0) THEN 
								array.A[y,x] := SHORT(upper); 
							END; 
						END; 
					END; 
				vyBase.Update(array); 
				END; 
			END; 	
				
		END; 
	END MakeHorizon;


END wedgeHierarchicModel.


antsArrayObjects.LoadP2  file="peppers32.pgm"    name=testarray    >show    ~ 
antsArrayObjects.LoadP2  file="peppers64.pgm"    name=testarray    >show    ~ 
antsArrayObjects.LoadP2  file="peppers128.pgm"    name=testarray    >show    ~ 
antsArrayObjects.LoadP2  file="/home/felix/horizon.pgm"    name=testarray    >show    ~ 


System.Free wedgeHierarchicModel ~

wedgeHierarchicModel.NewTree source=testarray  name=experiment  >forceNew ~
wedgeHierarchicModel.AddCRect tree=experiment  name=crect ~
wedgeHierarchicModel.AddCWedge tree=experiment  numberofangles=2 ~
wedgeHierarchicModel.Minimize tree=experiment gama= 1  minw= 0 maxw=0  minh=0 maxh=0 result=myResult  widths= 1 2 4 8 16 32 64 128 256 512   heights= 1 2  4 8 16 32 64 128 256 512 ~
Voyager.Show experiment as wedgeTreePlot ~
wedgeCommands.Show tree=NIL array=myResult ~
~

wedgeNumOps.Statistics tree=experiment approxprepareT=preparetime minT=mintime ~
wedgeNumOps.WriteRE preparetime ~
wedgeNumOps.WriteRE mintime ~


wedgeHierarchicModel.NewTree source=testarray  name=experiment  >forceNew >transpose  ~

wedgeCommands.NewConstRectModel model=rectModel ~
wedgeHierarchicModel.AddModel tree=experiment model=rectModel ~

wedgeCommands.NewLinearRectModel model=rectLModel ~
wedgeHierarchicModel.AddModel tree=experiment model=rectLModel ~

wedgeCommands.NewQuadraticRectModel model=rectLModel ~
wedgeHierarchicModel.AddModel tree=experiment model=rectLModel ~

fofAutomatic.Do 

wedgeHierarchicModel.NewTree source=testarray  name=experiment  >forceNew ~

wedgeCommands.NewConstRectModel model=rectModel ~
wedgeHierarchicModel.AddModel tree=experiment model=rectModel ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= 0 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= 45 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= 90 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= 135 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= 67.5 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= -22.5 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

wedgeCommands.NewConstWedgeModel model=wedgeModel0 ~ (* a wedge model alone does NOT work *)
wedgeCommands.SetConstAngle  model=wedgeModel0 alpha= -67.5 ~
wedgeHierarchicModel.AddModel tree=experiment model=wedgeModel0 ~

~

antsFunctions.Define horizon ~
antsFunctions.Set horizon "Math.exp(3/2 * Math.ln(x) )"~
antsFctEdit.Show horizon from=0 to =1 by = 0.01 ~
wedgeHierarchicModel.MakeHorizon  function=horizon array=testarray w=256 h=256 lower=0 upper=255 ~
wedgeCommands.Show tree=NIL array=testarray  ~
 
wedgeHierarchicModel.NewTree source=testarray  name=experiment ~ (register new data )

wedgeHierarchicModel.Minimize tree=experiment gama= 0.0001  minw= 8 maxw=8  minh=10 maxh=48 result=myResult ~
wedgeHierarchicModel.Minimize tree=experiment gama= 1  minw= 0 maxw=0  minh=0 maxh=0 result=myResult  widths= 1 2 4 8 16 32 64    heights= 1 2  4 8 16 32 64  ~


Voyager.Show experiment as wedgeTreePlot ~

vyScale.Insert 

wedgeCommands.Show tree=NIL array=myResult ~

 vyScale.Insert 
 vyScale.Insert 


wedgeHierarchicModel.Test  testarray  gamma= 0.1 minw=0 maxw= 10000 ~
wedgeCommands.Show tree=NIL array=result ~

vyScale.Insert 

