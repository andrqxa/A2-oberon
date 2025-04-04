MODULE wedgeTrees IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT antsArrayObjects, aM := antsMessages, Oberon, Strings, antsHybridObjects, Gadgets, Objects, Files, Math := MathL IN A2, 
	antsArrays, Out, vyBase, vyName, antsCommands, antsArrayPictures16, vyPort, antsPictCoordinate, antsPictureViews, 
	antsHistogramEdit, antsToolbox;  
	
	(*! todo*
use antsHybridObjects for persistency
*)
	
(*
- it must be possible to traverse the tree for each model separately, otherwise too much memory might be allocated beforehand
- the "model" must provide: local minimization, reconstruction. 
- model should be able to check previous models used (allocation avoidance)
- plugin mechanism provided seperated from the tree ?
*)
CONST  (* modes *)
	simple* = 0;  detailed* = 1;  full* = 2;  

TYPE 
	
	LocalApproximation* = OBJECT  (* to be extended by implementation of Model *)
	VAR penalty*: FLOAT64;  
		distance*: FLOAT64;  
		model*: Model;  
		
		next-: LocalApproximation;   (* queue *)
	END LocalApproximation;  
	
	Parameter* = OBJECT
	VAR 
		next: Parameter;  
	END Parameter;  
	
	Model* = OBJECT (antsHybridObjects.Object) (* model object for local approximation of signals *)
	VAR penalty*: FLOAT64;  
		penaltyadaptive*: BOOLEAN;  
		pieces*: SIZE;   (* not persistent since fix for each model *)
		(*  functional H(gamma) = gamma * penalty + distance*)
		
		PROCEDURE GetParameters*( ): Parameter;  
		BEGIN 
			RETURN NIL;  
		END GetParameters;  

		PROCEDURE SetParameters*( p: Parameter );  
		BEGIN 
			ASSERT ( p = NIL );  
		END SetParameters;  

		PROCEDURE CheckMRCoefficient*( x, y, w, h: SIZE;  val: FLOAT64 ): BOOLEAN;  
		BEGIN 
			HALT( 100 );  
		END CheckMRCoefficient;  

		PROCEDURE PrepareApproximation*( data: antsArrayObjects.tLONGREALArray );  
		BEGIN 
		END PrepareApproximation;  

		PROCEDURE Approximate*( x, y, w, h: SIZE;  VAR approx: LocalApproximation );   (* must be provided by implementation of Model *)
		BEGIN 
			HALT( 1001 );  
		END Approximate;  

		PROCEDURE FinishApproximation*;  
		BEGIN 
		END FinishApproximation;  

		PROCEDURE Reconstruct*( x, y, w, h: SIZE;  approx: LocalApproximation;  reco: antsArrayObjects.tLONGREALArray );   (* must be provided by implementation of Model *)
		BEGIN 
			HALT( 1002 );  
		END Reconstruct;  

		PROCEDURE Display*( x, y, w, h: SIZE;  approx: LocalApproximation;  mode: SIGNED32 );  
		BEGIN 
			(* empty *)
		END Display;  

		PROCEDURE Report*;  
		BEGIN 
			aM.SR( "penalty per piece               ", penalty );  aM.SB( "penalty adaptive                ", penaltyadaptive );  aM.SI( "pieces per quad                   ", pieces );  
		END Report;  

		PROCEDURE LoadApproximation*( VAR R: Files.Rider;  VAR approx: LocalApproximation );  
		VAR version: SIGNED32;  
		BEGIN 
			Files.ReadLInt( R, version );  
			IF version < 0 THEN RETURN END;  
			IF approx = NIL THEN NEW( approx );  END;  
			Files.ReadLReal( R, approx.penalty );  Files.ReadLReal( R, approx.distance );  
			IF version >= 20041130 THEN Files.ReadLReal( R, penalty );  Files.ReadBool( R, penaltyadaptive );  END;  
		END LoadApproximation;  

		PROCEDURE StoreApproximation*( VAR R: Files.Rider;  approx: LocalApproximation );  
		CONST  (* version = 20040720; *) version = 20041130;  
		BEGIN 
			IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  END;  
			Files.WriteLInt( R, version );  Files.WriteLReal( R, approx.penalty );  Files.WriteLReal( R, approx.distance );  
			Files.WriteLReal( R, penalty );  Files.WriteBool( R, penaltyadaptive );  
		END StoreApproximation;  

		PROCEDURE BindApproximation*( VAR M: Objects.BindMsg;  approx: LocalApproximation );  
		BEGIN 
		END BindApproximation;  

		PROCEDURE & Init*;   (* can be used by implementation to initialize variables etc. *)
		BEGIN 
			Init^;  penalty := 1;  penaltyadaptive := FALSE;  pieces := 1;  
		END Init;  

	END Model;  

CONST 
	unmodified = 0;  failed = -1;  success = 1;  
TYPE 
	
	QNode* = OBJECT 
	VAR approximations-: LocalApproximation;   (*queue of all possible local Approximations, might be empty *)
		active*: LocalApproximation;   (* local approximation activated while minimization process *)
		ul-, ur-, ll-, lr-: QNode;   (* children of QNode, might be NIL *)
		mrConditionStatus*: INTEGER;  
		(*
		mrConditionFailed*: BOOLEAN;  
		*)
		
	END QNode;  
	PlugInQ = OBJECT 
	VAR model: Model;  
		parameter: Parameter;  
		name: ARRAY 256 OF CHAR;  
		approxT, approxprepareT, approxfinishT: SIGNED32;
		used, plugged, depth: SIZE;  
		next: PlugInQ;  
		
		PROCEDURE & Init;  
		BEGIN 
			approxT := 0;  approxprepareT := 0;  approxfinishT := 0;  
		END Init;  

	END PlugInQ;  

TYPE 
	StatisticObject* = OBJECT 
	VAR sumofpenalty*: FLOAT64;  
		sumofpieces*: SIZE;  
		sumofssq*: FLOAT64;  
		maxactivedepth*: SIZE;  
		minactivedepth*: SIZE;  
		approxprepareT*: SIGNED32;  
		mintime*: SIGNED32;  
		alloctime*: SIGNED32;  
		approxT*: SIGNED32;  
		depth*: SIZE;   (* for statistics *)
		plugins: PlugInQ;  
		
		PROCEDURE Active( node: QNode;  depth: SIGNED32; x, y, w, h: SIZE );  
		VAR a: LocalApproximation;  left, right, lower, upper: SIZE;  p: PlugInQ;  
		BEGIN 
			a := node.active;  
			IF a # NIL THEN 
				IF maxactivedepth < depth THEN maxactivedepth := depth;  END;  
				IF minactivedepth > depth THEN minactivedepth := depth;  END;  
				sumofpenalty := sumofpenalty + a.penalty;  sumofssq := sumofssq + a.distance;  p := plugins;  
				INC( sumofpieces, a.model.pieces );  
				(*
				WHILE (p # NIL ) DO 
					IF p.model = a.model THEN INC( p.used );  END;  
					p := p.next;  
				END;  
				*)
			ELSE 
				left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
				IF node.ll # NIL THEN Active( node.ll, depth + 1, x, y, left, lower ) END;  
				IF node.lr # NIL THEN Active( node.lr, depth + 1, x + left, y, right, lower ) END;  
				IF node.ul # NIL THEN Active( node.ul, depth + 1, x, y + lower, left, upper ) END;  
				IF node.ur # NIL THEN Active( node.ur, depth + 1, x + left, y + lower, right, upper ) END;  
			END;  
		END Active;  

		PROCEDURE Global( node: QNode;  depth: SIGNED32; x, y, w, h: SIZE );  
		VAR a: LocalApproximation;  left, right, lower, upper: SIZE;  
		BEGIN 
			IF SELF.depth < depth THEN SELF.depth := depth;  END;  
			left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN Global( node.ll, depth + 1, x, y, left, lower ) END;  
			IF node.lr # NIL THEN Global( node.lr, depth + 1, x + left, y, right, lower ) END;  
			IF node.ul # NIL THEN Global( node.ul, depth + 1, x, y + lower, left, upper ) END;  
			IF node.ur # NIL THEN Global( node.ur, depth + 1, x + left, y + lower, right, upper ) END;  
		END Global;  

		PROCEDURE & Compute( node: QNode;  plugins: PlugInQ;  w, h: SIZE );  
		VAR p: PlugInQ;  
		BEGIN 
			
			sumofpenalty := 0;  sumofssq := 0;  maxactivedepth := 0;  minactivedepth := MAX( SIGNED32 );  SELF.plugins := plugins;  
			sumofpieces := 0;  p := plugins;  
			WHILE (p # NIL ) DO p.used := 0;  p := p.next;  END;  
			Active( node, 1, 0, 0, w, h );  Global( node, 1, 0, 0, w, h );  
		END Compute;  

	END StatisticObject;  
TYPE 
	TimingObject = OBJECT 
	VAR t, last: SIGNED32;  
		
		PROCEDURE Step( msg: ARRAY OF CHAR );  
		VAR s1, s2: ARRAY 128 OF CHAR;  
		BEGIN 
			last := Oberon.Time() - t;  s1 := "( ";  Strings.Append( s1, msg );  Strings.Append( s1, " time:" );  Strings.IntToStr( last, s2 );  
			aM.vSSS( s1, s2, "ms )" );  t := Oberon.Time()
		END Step;  

		PROCEDURE & Start;  
		BEGIN 
			t := Oberon.Time();  
		END Start;  

	END TimingObject;  

TYPE 
	QuadTree* = OBJECT (antsHybridObjects.Object)
	VAR root-: QNode;  
		dataobj-: antsArrayObjects.tLONGREALObject;  
		(*plugins: PlugIns;  *)
		w-, h-: SIZE; colordepth-: SIGNED32;  
		plugins: PlugInQ;   (* plug in queue only for reporting *)
		t: TimingObject;  
		alloctime, mintime: SIGNED32;  
		gamma, scaledgamma: FLOAT64;  
		
		PROCEDURE & Init;  
		BEGIN 
			Init^;  root := NIL;  NEW( t );  plugins := NIL;  dataobj := NIL;  
		END Init;  

		PROCEDURE Load( VAR R: Files.Rider );  
		VAR version,c: SIGNED32;  obj: Objects.Object;  
		BEGIN 
			Files.ReadLInt( R, version );  Files.ReadLInt( R, c); w := c;  Files.ReadLInt( R, c); h := c;  Files.ReadLInt( R, colordepth );  
			Files.ReadLReal( R, gamma );  Files.ReadLReal( R, scaledgamma );  Gadgets.ReadRef( R, lib, obj );  
			IF obj # NIL THEN dataobj := obj( antsArrayObjects.tLONGREALObject ) END;  
			LoadPluginQ( R, lib, plugins );  LoadNode( R, lib, root );  
		END Load;  

		PROCEDURE Store( VAR R: Files.Rider );  
		CONST version = 0;  
		BEGIN 
			Files.WriteLInt( R, version );  Files.WriteLInt( R, SIGNED32(w) );  Files.WriteLInt( R, SIGNED32(h) );  Files.WriteLInt( R, colordepth );  
			Files.WriteLReal( R, gamma );  Files.WriteLReal( R, scaledgamma );  Gadgets.WriteRef( R, lib, dataobj );  
			StorePluginQ( R, lib, plugins );  StoreNode( R, lib, root );  
		END Store;  

		PROCEDURE Bind( VAR M: Objects.BindMsg );  
		BEGIN 
			BindObj( M, dataobj );  BindPlugInQ( M, plugins );  BindNode( M, root );  
		END Bind;  

		PROCEDURE PlugIn*( model: Model;  name: ARRAY OF CHAR;  maxdepth: SIZE );   (* put in Plugin fifo *)
		VAR p: PlugInQ;  
		BEGIN 
			p := AddPlugIn( plugins, model, name, maxdepth );   (* *)
			aM.vSS( "wedgeTrees: plugin, preparing ", name );  t.Start;  model.PrepareApproximation( dataobj.A );  t.Step( "plugin preparation" );  aM.vSS( "plugin, preparation done, starting approximation ", name );  
			INC( p.approxprepareT, t.last );  t.Start;  RApproximate( model, root, maxdepth, 0, 0, w, h );  t.Step( "plugin approximation" );  
			aM.vSS( "plugin,  approximation done, finishing ", name );   (* *)
			INC( p.approxT, t.last );  t.Start;  model.FinishApproximation;  t.Step( "plugin finishing" );  aM.vSS( "plugin done ", name );  INC( p.approxfinishT, t.last );  
		END PlugIn;  

		PROCEDURE Remove*( model: Model );  
		VAR p: PlugInQ;  found: SIGNED32;  
		BEGIN 
			aM.S( "Trying to remove model:" );  p := plugins;  
			IF (p # NIL ) THEN 
				IF p.model = model THEN aM.SS( "Removing: ", p.name );  plugins := p.next;  ELSE 
					WHILE (p.next # NIL ) DO 
						IF p.next.model = model THEN aM.SS( "Removing: ", p.next.name );  p.next := p.next.next;  ELSE p := p.next;  END;  
					END;  
				END;  
			END;  
			aM.S( "Removing in tree.." );  RRemove( root, model, found );  aM.SI( "Removal done, found instances: ", found );  aM.S( "note that active nodes are not removed, rerun minimize !" );  
		END Remove;  

		PROCEDURE RemoveAll*;  
		VAR p: PlugInQ;  found: SIGNED32;  
		BEGIN 
			p := plugins;  
			WHILE (p # NIL ) DO 
				IF p.model # NIL THEN aM.SS( "Removing from tree: ", p.name );  RRemove( root, p.model, found );  INC( found );  END;  
				p := p.next;  
			END;  
			aM.SI( "Removal done, found instances: ", found );  aM.S( "note that active nodes are not removed, further minimization not possible without model !" );  plugins := NIL;  
		END RemoveAll;  

		PROCEDURE Minimize*( gamma: FLOAT64 ): FLOAT64;  
		VAR result: FLOAT64;  
		BEGIN 
			SELF.gamma := gamma;  SELF.scaledgamma := ScaledGamma( gamma, w, h, colordepth );  aM.vS( "wedgeTrees: starting minimization" );  t.Start;  
			result := RMinimize( root, ScaledGamma( gamma, w, h, colordepth ) );  t.Step( "minimization" );  mintime := t.last;  aM.vS( "minimization done " );  
			RETURN result;  
		END Minimize;  

		PROCEDURE MinimizeDistTo*( to: antsArrayObjects.tLONGREALArray ): FLOAT64;  
		VAR reco: antsArrayObjects.tLONGREALArray;  
		BEGIN 
			NEW( reco, h, w );  RETURN RMinimizeDistTo( root, 0, 0, w, h, to, reco );  
		END MinimizeDistTo;  

		PROCEDURE Reconstruct*( VAR reco: antsArrayObjects.tLONGREALArray );  
		BEGIN 
			t.Start;  aM.vS( "wedgeTrees: starting reconstruction" );  
			IF (reco = NIL ) OR (LEN( reco ) # h) OR (LEN( reco[0] ) # w) THEN NEW( reco, h, w ) END;  
			ASSERT ( LEN( reco ) >= h );  
			ASSERT ( LEN( reco[0] ) >= w );  
			RReconstruct( root, 0, 0, w, h, reco );  aM.vS( "reconstruction done." );  t.Step( "reconstruction" );  
		END Reconstruct;  

		PROCEDURE ReconstructAtLevel*( VAR reco: antsArrayObjects.tLONGREALArray;  level: SIGNED32;  VAR model: Model );  
		BEGIN 
			t.Start;   (*aM.S( "wedgeTrees: starting reconstruction" );  *)
			IF (reco = NIL ) OR (LEN( reco ) # h) OR (LEN( reco[0] ) # w) THEN NEW( reco, h, w ) END;  
			ASSERT ( LEN( reco ) >= h );  
			ASSERT ( LEN( reco[0] ) >= w );  
			RReconstructAtLevel( root, level, model, 0, 0, w, h, reco );   (* aM.S( "reconstruction done." ); *) t.Step( "reconstruction" );  
		END ReconstructAtLevel;  

		PROCEDURE ReconstructMR*( VAR reco: antsArrayObjects.tLONGREALArray );  
		BEGIN 
			t.Start;  aM.S( "wedgeTrees: starting MR reconstruction" );  
			IF (reco = NIL ) OR (LEN( reco ) # h) OR (LEN( reco[0] ) # w) THEN NEW( reco, h, w ) END;  
			ASSERT ( LEN( reco ) >= h );  
			ASSERT ( LEN( reco[0] ) >= w );  
			MRMinimize( root, 0, 0, w, h, dataobj.A, reco );  aM.S( "reconstruction done." );  t.Step( "reconstruction" );  
		END ReconstructMR;  

		PROCEDURE Report*;  
		VAR p: PlugInQ;  s: StatisticObject;  
		BEGIN 
			aM.S( "---- wegdeTrees: Report --------- " );  aM.SISI( "dimensions: w=", w, " h=", h );  aM.SI( "colordepth            =", colordepth );  s := Stats();  aM.SI( "overal tree depth    =", s.depth );  aM.S( "Registered Plugins  :" );  p := plugins;  
			WHILE (p # NIL ) DO 
				aM.S( "--" );  aM.SS( "plugin                     :", p.name );  aM.SI( "plugged                    :", p.plugged );  aM.SI( "used                         :", p.used );  aM.SI( "prepare approx time:", p.approxprepareT );  
				aM.SI( "finish approx time   :", p.approxfinishT );  aM.SI( "approx time             :", p.approxT );  p.model.Report;  p := p.next;  
			
			END;  
			aM.S( "---- total times ----" );  aM.SISI( "approx prepare ", s.approxprepareT, "approx ", s.approxT );  aM.S( " ----  statistics snapshot  ----" );  aM.SR( "last gamma          =", gamma );  aM.SR( "gamma (scaled)   =", scaledgamma );  
			aM.SI( "min active depth    =", s.minactivedepth );  aM.SI( "max active depth    =", s.maxactivedepth );  aM.SR( "sumofpenalty       =", s.sumofpenalty );  
			aM.SR( "penalty*gamma  =", scaledgamma * s.sumofpenalty );  aM.SR( "sum of ssq       =", s.sumofssq );  
			aM.SR( "Hgamma              =", scaledgamma * s.sumofpenalty + s.sumofssq );  
			aM.SR( "psnr                      =", 10 * Math.ln( 1.0D0 * w * h * colordepth * colordepth / s.sumofssq ) / Math.ln( 10 ) );  
			aM.SI( " active pieces        =", s.sumofpieces );  

			aM.S( "---- wegdeTrees: Report done ---- " );  
		END Report;  

		PROCEDURE Stats*( ): StatisticObject;  
		VAR s: StatisticObject;  p: PlugInQ;  
		BEGIN 
			NEW( s, root, plugins, w, h );  p := plugins;  s.approxprepareT := 0;  s.approxT := 0;  
			WHILE (p # NIL ) DO 
				s.approxprepareT := s.approxprepareT + p.approxprepareT;  s.approxT := s.approxT + p.approxT;  p := p.next;  
			END;  
			s.alloctime := alloctime;  s.mintime := mintime;  RETURN s;  
		END Stats;  

		PROCEDURE Create*( data: antsArrayObjects.tLONGREALObject;  maxdepth: SIZE );   (* create all nodes of tree until depth maxdepth, maxdepth=0 indicates no limit!*)
		BEGIN 
			t.Start;  aM.S( "wedgeTrees: creating tree ... " );  
			IF maxdepth = 0 THEN maxdepth := MAX( SIGNED32 ) END;  
			w := data.w;  h := data.h;  SELF.colordepth := ENTIER( data.depth + 0.5 );  SELF.dataobj := data;  t.Start;  
			CreateNode( root, 0, 0, w, h, 1, maxdepth );  t.Step( "tree creation" );  alloctime := t.last;  aM.S( "tree creation done " );  
		END Create;  

	END QuadTree;  
	
	PROCEDURE LoadApproximations( VAR R: Files.Rider;  lib: Objects.Library;  VAR approx: LocalApproximation );  
	VAR version: SIGNED32;  obj: Objects.Object;  model: Model;  
	BEGIN 
		Files.ReadLInt( R, version );  
		IF version < 0 THEN approx := NIL;  RETURN END;  
		Gadgets.ReadRef( R, lib, obj );  
		IF obj # NIL THEN model := obj( Model );  model.LoadApproximation( R, approx );  ELSE aM.eS( "Warning: approximation without model loaded, trying but not stable!" );  NEW( approx );  END;  
		approx.model := model;  LoadApproximations( R, lib, approx.next );  
	END LoadApproximations;  

	PROCEDURE StoreApproximations( VAR R: Files.Rider;  lib: Objects.Library;  approx: LocalApproximation );  
	CONST version = 20040720;  
	BEGIN 
		IF approx = NIL THEN Files.WriteLInt( R, -1 );  RETURN ELSE Files.WriteLInt( R, version );  END;  
		Gadgets.WriteRef( R, lib, approx.model );  
		IF approx.model # NIL THEN approx.model.StoreApproximation( R, approx ) ELSE aM.eS( "Warning: approximation without model stored !" );  END;  
		StoreApproximations( R, lib, approx.next );  
	END StoreApproximations;  

	PROCEDURE BindApproximations( M: Objects.BindMsg;  approx: LocalApproximation );  
	BEGIN 
		IF approx = NIL THEN RETURN END;  
		IF approx.model # NIL THEN 
			approx.model.BindObj( M, approx.model );   (* binds itself *)
			approx.model.BindApproximation( M, approx );  
		END;  
		BindApproximations( M, approx.next );  
	END BindApproximations;  

	PROCEDURE LoadNode( VAR R: Files.Rider;  lib: Objects.Library;  VAR node: QNode );  
	VAR version: SIGNED32;  
	BEGIN 
		Files.ReadLInt( R, version );  
		IF version < 0 THEN node := NIL;  RETURN END;  
		NEW( node );  LoadApproximations( R, lib, node.approximations );  LoadApproximations( R, lib, node.active );  
		LoadNode( R, lib, node.ul );  LoadNode( R, lib, node.ur );  LoadNode( R, lib, node.ll );  LoadNode( R, lib, node.lr );  
	END LoadNode;  

	PROCEDURE StoreNode( VAR R: Files.Rider;  lib: Objects.Library;  VAR node: QNode );  
	CONST version = 20040720;  
	BEGIN 
		IF node = NIL THEN Files.WriteLInt( R, -1 );  RETURN;  ELSE Files.WriteLInt( R, version );  END;  
		StoreApproximations( R, lib, node.approximations );  StoreApproximations( R, lib, node.active );  
		StoreNode( R, lib, node.ul );  StoreNode( R, lib, node.ur );  StoreNode( R, lib, node.ll );  StoreNode( R, lib, node.lr );  
	END StoreNode;  

	PROCEDURE BindNode( VAR M: Objects.BindMsg;  node: QNode );  
	BEGIN 
		IF node = NIL THEN RETURN END;  
		BindApproximations( M, node.approximations );  BindApproximations( M, node.active );  BindNode( M, node.ul );  
		BindNode( M, node.ur );  BindNode( M, node.ll );  BindNode( M, node.lr );  
	END BindNode;  

	PROCEDURE RApproximate( model: Model;  node: QNode;  maxdepth: SIZE;  x, y, w, h: SIZE );  
	VAR approx: LocalApproximation;  a, prev: LocalApproximation;  left, right, lower, upper: SIZE;  
	BEGIN 
		IF (node = NIL ) OR (maxdepth < 0) THEN RETURN END;  
		a := node.approximations;  
		WHILE (a # NIL ) DO  (* has the model already been used to approximate ? if yes, then avoid allocation *)
			IF a.model = model THEN approx := a;  END;  
			a := a.next;  
		END;  
		model.Approximate( x, y, w, h, approx );  
		IF approx = NIL THEN RETURN END;   (* this model denies to go any further down in tree *)
		approx.model := model;  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  

		a := node.approximations;  prev := NIL;  
		WHILE (a # NIL ) DO 
			IF a = approx THEN 
				approx := NIL;  a := NIL;   (* approx is already in list *)
			ELSIF (a.penalty = approx.penalty) THEN 
				IF (a.distance > approx.distance) THEN  (* approx has same penalty but better approximation than a, substitute a by approx  *)
					IF prev # NIL THEN  (* "middle" queue element *)
						prev.next := approx;  
					ELSE  (* first element in queue *)
						node.approximations := approx;  
					END;  
					approx.next := a.next;  
					(* ELSE: approx has same penalty and worse approximation and is thus discarded *)
				END;  
				approx := NIL;  a := NIL;  
			ELSE prev := a;  a := a.next;  
			END;  
		END;  
		
		IF approx # NIL THEN 
			approx.next := node.approximations;  node.approximations := approx;   (* enter this approximation *)
		END;  
		
		IF node.ll # NIL THEN RApproximate( model, node.ll, maxdepth - 1, x, y, left, lower );  
		END;  
		IF node.lr # NIL THEN RApproximate( model, node.lr, maxdepth - 1, x + left, y, right, lower );  END;  
		IF node.ul # NIL THEN RApproximate( model, node.ul, maxdepth - 1, x, y + lower, left, upper );  END;  
		IF node.ur # NIL THEN RApproximate( model, node.ur, maxdepth - 1, x + left, y + lower, right, upper );  END;  
	END RApproximate;  

	PROCEDURE RMinimize( node: QNode;  gamma: FLOAT64 ): FLOAT64;  
	VAR current, localmin, subnodemin: FLOAT64;  a, minapprox: LocalApproximation;  used: BOOLEAN;  
	BEGIN 
		ASSERT ( node # NIL );  
		a := node.approximations;  localmin := MAX( FLOAT64 ) / 100;  
		WHILE (a # NIL ) DO  (* determine best local fit with respect to gamma *)
			current := a.distance + gamma * a.penalty;  
			IF current < localmin THEN localmin := current;  minapprox := a;  END;  
			a := a.next;  
		END;  
		used := FALSE;  subnodemin := 0;  
		IF node.ll # NIL THEN subnodemin := subnodemin + RMinimize( node.ll, gamma );  used := TRUE;  END;  
		IF node.lr # NIL THEN subnodemin := subnodemin + RMinimize( node.lr, gamma );  used := TRUE;  END;  
		IF node.ul # NIL THEN subnodemin := subnodemin + RMinimize( node.ul, gamma );  used := TRUE;  END;  
		IF node.ur # NIL THEN subnodemin := subnodemin + RMinimize( node.ur, gamma );  used := TRUE;  END;  
		IF ~used THEN subnodemin := MAX( FLOAT64 ) END;  
		IF localmin < subnodemin THEN node.active := minapprox;  RETURN localmin;  ELSE node.active := NIL;  RETURN subnodemin END;  
	END RMinimize;  

	PROCEDURE RMinimizeDistTo( node: QNode;  x, y, w, h: SIZE;  to, reco: antsArrayObjects.tLONGREALArray ): FLOAT64;  
	VAR current, localmin, subnodemin: FLOAT64;  a, minapprox: LocalApproximation;  used: BOOLEAN;  xx, yy: SIZE;  left, right, lower, upper: SIZE;  
	BEGIN 
		ASSERT ( node # NIL );  
		a := node.approximations;  localmin := MAX( FLOAT64 ) / 100;  
		WHILE (a # NIL ) DO  (* determine best local fit with respect to distance to "to" *)
			a.model.Reconstruct( x, y, w, h, a, reco );  current := 0;  
			FOR xx := x TO x + w - 1 DO 
				FOR yy := y TO y + h - 1 DO current := current + (reco[yy, xx] - to[yy, xx]) * (reco[yy, xx] - to[yy, xx]);  END;  
			END;  
			IF current < localmin THEN localmin := current;  minapprox := a;  END;  
			a := a.next;  
		END;  
		used := FALSE;  subnodemin := 0;  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
		IF node.ll # NIL THEN subnodemin := subnodemin + RMinimizeDistTo( node.ll, x, y, left, lower, to, reco );  used := TRUE;  END;  
		IF node.lr # NIL THEN 
			subnodemin := subnodemin + RMinimizeDistTo( node.lr, x + left, y, right, lower, to, reco );  used := TRUE;  
		END;  
		IF node.ul # NIL THEN 
			subnodemin := subnodemin + RMinimizeDistTo( node.ul, x, y + lower, left, upper, to, reco );  used := TRUE;  
		END;  
		IF node.ur # NIL THEN 
			subnodemin := subnodemin + RMinimizeDistTo( node.ur, x + left, y + lower, right, upper, to, reco );  used := TRUE;  
		END;  
		IF ~used THEN subnodemin := MAX( FLOAT64 ) END;  
		IF localmin < subnodemin THEN node.active := minapprox;  RETURN localmin;  ELSE node.active := NIL;  RETURN subnodemin END;  
	END RMinimizeDistTo;  

	PROCEDURE MRMinimize( node: QNode;  x, y, w, h: SIZE;  orig, reco: antsArrayObjects.tLONGREALArray );  
	VAR a: LocalApproximation;  done: BOOLEAN;  xx, yy: SIZE;  sigma, res, k: FLOAT64;  left, right, upper, lower: SIZE;  
		test: POINTER TO ARRAY OF FLOAT64;  
		pos: SIGNED32;  
	BEGIN 
		k := Math.ln( LEN( orig ) ) / Math.ln( 2 );  NEW( test, w * h );  pos := 0;  
		FOR yy := y TO y + h - 2 DO 
			FOR xx := x TO x + w - 2 DO 
				test[pos] := ABS( orig[yy + 1, xx + 1] - orig[yy + 1, xx] - orig[yy, xx + 1] + orig[yy, xx] );  INC( pos )
			END;  
		END;  
		sigma := 1.48 / 2 * antsArrays.Median1dX( test^, w * h );  

		done := FALSE;  a := node.approximations;  
		WHILE (a # NIL ) DO 

			a.model.Reconstruct( x, y, w, h, a, reco );  

			res := 0;  
			FOR yy := y TO y + h - 1 DO 
				FOR xx := x TO x + w - 1 DO res := res + (orig[yy, xx] - reco[yy, xx]) * (orig[yy, xx] - reco[yy, xx]);  END;  
			END;  
			res := Math.sqrt( res ) / Math.sqrt( w * h );  
			
			(*
			res := Math.sqrt(a.distance) / Math.sqrt(w*h); 
			*)
			
			
			
			IF ABS( res ) <= sigma * Math.sqrt( 4.6 * Math.ln( 2 ) * k ) THEN 
				(* a.model.Reconstruct(x,y,w,h,a,reco); *)
				node.active := a;  a := NIL;  done := TRUE;  
			ELSE a := a.next;  
			END;  
		
		END;  
		
		IF ~done THEN 
			left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN MRMinimize( node.ll, x, y, left, lower, orig, reco ) END;  
			IF node.lr # NIL THEN MRMinimize( node.lr, x + left, y, right, lower, orig, reco ) END;  
			IF node.ul # NIL THEN MRMinimize( node.ul, x, y + lower, left, upper, orig, reco ) END;  
			IF node.ur # NIL THEN MRMinimize( node.ur, x + left, y + lower, right, upper, orig, reco ) END;  
			node.active := NIL;  
		END;  
	
	END MRMinimize;  

	PROCEDURE RRemove( node: QNode;  model: Model;  VAR found: SIGNED32 );  
	VAR current, localmin, subnodemin: FLOAT64;  a, minapprox: LocalApproximation;  used: BOOLEAN;  
	BEGIN 
		ASSERT ( node # NIL );  
		a := node.approximations;  
		IF (a # NIL ) THEN 
			IF (a.model = model) THEN INC( found );  node.approximations := a.next ELSE 
				WHILE (a.next # NIL ) DO 
					IF a.next.model = model THEN INC( found );  a.next := a.next.next;  ELSE a := a.next;  END;  
				END;  
			END;  
		END;  
		
		IF node.ll # NIL THEN RRemove( node.ll, model, found );  
		END;  
		IF node.lr # NIL THEN RRemove( node.lr, model, found );  END;  
		IF node.ul # NIL THEN RRemove( node.ul, model, found );  END;  
		IF node.ur # NIL THEN RRemove( node.ur, model, found );  END;  
	END RRemove;  

	PROCEDURE RReconstruct( node: QNode;  x, y, w, h: SIZE;  reco: antsArrayObjects.tLONGREALArray );  
	VAR a: LocalApproximation;  left, right, lower, upper: SIZE;  
	BEGIN 
		a := node.active;  
		IF a # NIL THEN 
			a.model.Reconstruct( x, y, w, h, a, reco );   (* first active node is used for reconstruction, subnodes then ignored *)
		ELSE 
			left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN RReconstruct( node.ll, x, y, left, lower, reco ) END;  
			IF node.lr # NIL THEN RReconstruct( node.lr, x + left, y, right, lower, reco ) END;  
			IF node.ul # NIL THEN RReconstruct( node.ul, x, y + lower, left, upper, reco ) END;  
			IF node.ur # NIL THEN RReconstruct( node.ur, x + left, y + lower, right, upper, reco ) END;  
		END;  
	END RReconstruct;  

	PROCEDURE RReconstructAtLevel( node: QNode;  level: SIGNED32;  VAR model: Model;  x, y, w, h: SIZE;  
														  reco: antsArrayObjects.tLONGREALArray );  
	VAR a: LocalApproximation;  left, right, lower, upper: SIZE;  
	BEGIN 
		IF model = NIL THEN RETURN END;  
		IF level = 0 THEN 
			a := node.approximations;   (* take first model only, for the moment *)
			WHILE (a # NIL ) & (a.model # model) DO a := a.next;  END;  
			IF a = NIL THEN model := NIL;  RETURN END;  
			ASSERT ( a # NIL );  
			a.model.Reconstruct( x, y, w, h, a, reco );  
		ELSE 
			DEC( level );  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN RReconstructAtLevel( node.ll, level, model, x, y, left, lower, reco ) END;  
			IF node.lr # NIL THEN RReconstructAtLevel( node.lr, level, model, x + left, y, right, lower, reco ) END;  
			IF node.ul # NIL THEN RReconstructAtLevel( node.ul, level, model, x, y + lower, left, upper, reco ) END;  
			IF node.ur # NIL THEN RReconstructAtLevel( node.ur, level, model, x + left, y + lower, right, upper, reco ) END;  
		END;  
	END RReconstructAtLevel;  

	PROCEDURE CreateNode( VAR node: QNode;  x, y, w, h: SIZE;  depth, maxdepth: SIZE );  
	VAR left, right, upper, lower: SIZE;  
	BEGIN 
		NEW( node (*,x,y,w,h,depth*) );   (* node.x := x;  node.y := y;  node.w := w;  node.h := h;  node.depth := depth;  *)
		IF depth >= maxdepth THEN RETURN END;  
		IF ((w > 1) OR (h > 1)) & (depth < maxdepth) THEN 
			left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			(* lower left  rectangle*)
			IF (left > 0) & (lower > 0) THEN CreateNode( node.ll, x, y, left, lower, depth + 1, maxdepth ) END;  
			(* lower right rectangle*)
			IF (right > 0) & (lower > 0) THEN CreateNode( node.lr, x + left, y, right, lower, depth + 1, maxdepth ) END;  
			(* upper left rectangle*)
			IF (left > 0) & (upper > 0) THEN CreateNode( node.ul, x, y + lower, left, upper, depth + 1, maxdepth ) END;  
			(* upper right rectangle*)
			IF (right > 0) & (upper > 0) THEN CreateNode( node.ur, x + left, y + lower, right, upper, depth + 1, maxdepth ) END;  
		END;  
	
	END CreateNode;  

	PROCEDURE ScaledGamma( gamma, w, h, depth: FLOAT64 ): FLOAT64;  
	BEGIN 
		RETURN gamma * w * h * depth * depth / 65536;  
	END ScaledGamma;  

	PROCEDURE StorePluginQ( VAR R: Files.Rider;  lib: Objects.Library;  q: PlugInQ );  
	CONST  (* version = 20040720; *) version = 20041201;  
	BEGIN 
		IF q = NIL THEN Files.WriteLInt( R, -1 ) 
		ELSE 
			Files.WriteLInt( R, version );  Gadgets.WriteRef( R, lib, q.model );  Files.WriteString( R, q.name );  
			Files.WriteLInt( R, q.approxT );  Files.WriteLInt( R, q.approxprepareT );  Files.WriteLInt( R, q.approxfinishT );  
			Files.WriteLInt( R, SIGNED32(q.used) );  StorePluginQ( R, lib, q.next );  Files.WriteLInt( R, SIGNED32(q.plugged) );  
		END;  
	END StorePluginQ;  

	PROCEDURE BindPlugInQ( VAR M: Objects.BindMsg;  q: PlugInQ );  
	BEGIN 
		IF q = NIL THEN RETURN END;  
		IF q.model # NIL THEN q.model.BindObj( M, q.model ) END;  
		BindPlugInQ( M, q.next );  
	END BindPlugInQ;  

	PROCEDURE LoadPluginQ( VAR R: Files.Rider;  lib: Objects.Library;  VAR q: PlugInQ );  
	VAR version,c: SIGNED32;  obj: Objects.Object;  
	BEGIN 
		Files.ReadLInt( R, version );  
		IF version < 0 THEN q := NIL;  RETURN END;  
		NEW( q );  Gadgets.ReadRef( R, lib, obj );  
		IF obj # NIL THEN q.model := obj( Model ) END;  
		Files.ReadString( R, q.name );  Files.ReadLInt( R, q.approxT );  Files.ReadLInt( R, q.approxprepareT );  
		Files.ReadLInt( R, q.approxfinishT );  Files.ReadLInt( R, c); q.used := c;  LoadPluginQ( R, lib, q.next );  
		IF version >= 20041201 THEN Files.ReadLInt( R, c); q.plugged := c;  END;  
	END LoadPluginQ;  

	PROCEDURE AddPlugIn( VAR root: PlugInQ;  model: Model;  name: ARRAY OF CHAR;  depth: SIZE ): PlugInQ;  
	VAR p: PlugInQ;  
	BEGIN 
		IF root = NIL THEN 
			NEW( root );  root.model := model;  root.parameter := model.GetParameters();  COPY( name, root.name );  root.plugged := 1;  
			root.depth := depth;  RETURN root;  
		END;  
		p := root;  
		WHILE (p.next # NIL ) DO p := p.next;  END;  
		
		NEW( p.next );  p := p.next;  p.model := model;  p.parameter := model.GetParameters();  p.depth := depth;  
		COPY( name, p.name );   (* p.next := root;  root := p; *) p.plugged := 1;  RETURN p;  
	END AddPlugIn;  

	PROCEDURE GenQuadTree*;   (* do not rename, must be compatible with QuadTree *)
	VAR q: QuadTree;  
	BEGIN 
		NEW( q );  Objects.NewObj := q;  
	END GenQuadTree;  

	PROCEDURE RResetMRCondition( node: QNode );  
	BEGIN 
		node.mrConditionStatus := unmodified;  node.active := NIL;  
		IF node.ll # NIL THEN RResetMRCondition( node.ll ) END;  
		IF node.lr # NIL THEN RResetMRCondition( node.lr ) END;  
		IF node.ul # NIL THEN RResetMRCondition( node.ul ) END;  
		IF node.ur # NIL THEN RResetMRCondition( node.ur ) END;  
	
	END RResetMRCondition;  

	PROCEDURE RReconstructMR( node: QNode;  x, y, w, h: SIGNED32 );  
	VAR a: LocalApproximation;  left, right, lower, upper: SIGNED32;  
	BEGIN 
		a := node.approximations;   (* first model only .. *)
		IF node.mrConditionStatus = success THEN node.active := a;  
		ELSE 
			node.active := NIL;  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN RReconstructMR( node.ll, x, y, left, lower ) END;  
			IF node.lr # NIL THEN RReconstructMR( node.lr, x + left, y, right, lower ) END;  
			IF node.ul # NIL THEN RReconstructMR( node.ul, x, y + lower, left, upper ) END;  
			IF node.ur # NIL THEN RReconstructMR( node.ur, x + left, y + lower, right, upper ) END;  
		END;  
	END RReconstructMR;  

	PROCEDURE RFixModel( node: QNode;  tmodel: Model;  level: SIGNED32 );  
	VAR a: LocalApproximation;  
	BEGIN 
		IF (level <= 0) THEN 
			IF (node.mrConditionStatus = unmodified) THEN 
				node.mrConditionStatus := success;  a := node.approximations;  
				WHILE (a # NIL ) & (a.model # tmodel) DO a := a.next;  END;  
				IF a # NIL THEN node.active := a;  END;  
			ELSIF (node.mrConditionStatus = failed) THEN node.active := NIL;  node.mrConditionStatus := unmodified;  
			END;  
		ELSE 
			DEC( level );  RFixModel( node.ll, tmodel, level );  RFixModel( node.lr, tmodel, level );  
			RFixModel( node.ul, tmodel, level );  RFixModel( node.ur, tmodel, level );  
		END;  
	END RFixModel;  

	PROCEDURE RCheckMRCondition( node: QNode;  model: Model;  sigma, f1, f2, n: FLOAT64;  x, y, w, h: SIZE;  level: SIGNED32;  VAR status: INTEGER );  
	VAR left, right, lower, upper: SIZE;  mr: FLOAT64;  a: LocalApproximation;  successed: BOOLEAN;  tsigma: FLOAT64;  
	BEGIN 
		IF (w < 2) OR (h < 2) OR (node.approximations = NIL ) OR (status = failed) THEN RETURN END; 
		IF (level > 0)  THEN 
			IF  (node.mrConditionStatus = success) THEN RETURN END; 
		ELSIF level = 0 THEN  (* this is the level of nodes that have to be tested *)
			
			IF (node.mrConditionStatus = failed) OR (node.mrConditionStatus = success) THEN RETURN END;   (* has already failed or  succeeded by previous model *)
			
			
			DEC( level );  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN 
				RCheckMRCondition( node.ll, model, sigma, f1, f2, n, x, y, left, lower, level, node.mrConditionStatus )
			END;  
			IF node.lr # NIL THEN 
				RCheckMRCondition( node.lr, model, sigma, f1, f2, n, x + left, y, right, lower, level, node.mrConditionStatus )
			END;  
			IF node.ul # NIL THEN 
				RCheckMRCondition( node.ul, model, sigma, f1, f2, n, x, y + lower, left, upper, level, node.mrConditionStatus )
			END;  
			IF node.ur # NIL THEN 
				RCheckMRCondition( node.ur, model, sigma, f1, f2, n, x + left, y + lower, right, upper, level, 
												   node.mrConditionStatus )
			END;  
			
			IF node.mrConditionStatus = unmodified THEN status := unmodified
			END;  
			
			RETURN;  
		ELSE 
			(* check mr conditions *)
			IF f2 <= 0.00001 THEN tsigma := sigma * Math.sqrt( f1 * Math.ln( n ) );  
			ELSE tsigma := sigma * Math.sqrt( f1 * Math.ln( n / w / h ) + f2 * (Math.ln( Math.exp( 1 ) + Math.ln( n / w / h ) )) );  
			END;  
			(* original formula: 
			sigma * sqrt (fact* log n / |I|+ 1.1 * log log e^e n/|I|)
			*)
			
			IF ~model.CheckMRCoefficient( x, y, w, h, tsigma ) THEN status := failed;  RETURN END;  
		END;  
		
		DEC( level );  left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  successed := TRUE;  
		IF node.ll # NIL THEN 
			RCheckMRCondition( node.ll, model, sigma, f1, f2, n, x, y, left, lower, level, status );  
			successed := successed & (node.ll.mrConditionStatus = success)
		END;  
		IF node.lr # NIL THEN 
			RCheckMRCondition( node.lr, model, sigma, f1, f2, n, x + left, y, right, lower, level, status );  
			successed := successed & (node.lr.mrConditionStatus = success)
		END;  
		IF node.ul # NIL THEN 
			RCheckMRCondition( node.ul, model, sigma, f1, f2, n, x, y + lower, left, upper, level, status );  
			successed := successed & (node.ul.mrConditionStatus = success)
		END;  
		IF node.ur # NIL THEN 
			RCheckMRCondition( node.ur, model, sigma, f1, f2, n, x + left, y + lower, right, upper, level, status );  
			successed := successed & (node.ur.mrConditionStatus = success)
		END;  
		IF successed THEN node.mrConditionStatus := success END;  
	
	END RCheckMRCondition;  

	PROCEDURE Subtract( from, this: antsArrayObjects.tLONGREALArray );  
	VAR y, x: SIZE;  
	BEGIN 
		FOR y := 0 TO LEN( from ) - 1 DO 
			FOR x := 0 TO LEN( from[0] ) - 1 DO from[y, x] := from[y, x] - this[y, x];  END;  
		END;  
	END Subtract;  
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

	PROCEDURE CheckMRConditions( tree: QuadTree;  factor, factor2: FLOAT64 );  
	VAR reco, orig: antsArrayObjects.tLONGREALArray;  angle: SIGNED32;  temp: BOOLEAN;  y, x, w, h: SIZE;  logn, k: FLOAT64;  
		test: POINTER TO ARRAY OF FLOAT64;  
		pos: SIGNED32;  sigma: FLOAT64;  dx, dy: SIGNED32;  level, app: SIGNED32;  obj: antsArrayObjects.tObject;  maxlevel: SIGNED32;  plugin: PlugInQ;  
		model, tmodel: Model;  mq, mqr, mqlast: MQueue;  status: INTEGER;  p: PlugInQ;  dotc: SIGNED32;  
	TYPE MQueue = OBJECT 
		VAR
			model: Model;  
			name: ARRAY 256 OF CHAR;  
			next: MQueue
		END MQueue;  
	BEGIN 
		p := tree.plugins;  
		
		(* build a queue of unique models *)
		aM.S( "Using models: " );  
		WHILE (p # NIL ) DO 
			IF mqr = NIL THEN NEW( mqr );  mqr.model := p.model;  COPY( p.name, mqr.name );  aM.SS( "->  ", p.name );  
			ELSE 
				mq := mqr;  
				WHILE (mq # NIL ) & (mq.model # p.model) DO mqlast := mq;  mq := mq.next;  END;  
				IF mq = NIL THEN NEW( mq );  mq.model := p.model;  mqlast.next := mq;  COPY( p.name, mq.name );  aM.SS( "->  ", p.name );  END;  
			END;  
			p := p.next;  
		END;  
		
		orig := tree.dataobj.A;  

		w := LEN( orig[0] );  h := LEN( orig );  logn := Math.ln( w * h );   (* sample size *)
		k := Math.ln( LEN( orig ) ) / Math.ln( 2 );  NEW( test, (w - 1) * (h - 1) );  pos := 0;  maxlevel := ENTIER( k + 1 / 2 ) - 1;  
		aM.SI( "maxlevel=", maxlevel );  
		
		FOR y := 0 TO h - 2 DO 
			FOR x := 0 TO w - 2 DO test[pos] := ABS( orig[y + 1, x + 1] - orig[y + 1, x] - orig[y, x + 1] + orig[y, x] );  INC( pos ) END;  
		END;  
		
		sigma := 1.48 / 2 * antsArrays.Median1dX( test^, (w - 1) * (h - 1) );  
		
		(*
		sigma := sigma * Math.sqrt( factor * Math.ln( 2 ) * k );  aM.SR( "sigma=", sigma );  
		*)
		
		RResetMRCondition( tree.root );  vyBase.Update( tree );  
		
		FOR level := 0 TO maxlevel DO 
			aM.SI( "Checking MR conditions at level: ", level );  mq := mqr;  
			WHILE (mq # NIL ) DO 
				Out.String( mq.name );  Out.String( ":" );  tmodel := mq.model;  tree.ReconstructAtLevel( reco, level, tmodel );  
				IF tmodel # NIL THEN Subtract( reco, orig );  

					plugin := tree.plugins;  status := unmodified;  dotc := 0;  
					WHILE (plugin # NIL ) & (status = unmodified) DO 
						IF plugin.depth >= level THEN 
							Out.String( "." );  INC( dotc );  
							IF dotc = 100 THEN dotc := 0;  Out.Ln;  END;  
							model := plugin.model;  model.SetParameters( plugin.parameter );  model.PrepareApproximation( reco );  
							status := success;  
							RCheckMRCondition( tree.root, model, sigma, factor, factor2, w * h, 0, 0, w, h, level, status );   
							(* if status # failed then node.status # failed for one node *)
						END;  
						plugin := plugin.next;  
					END;  
					RFixModel( tree.root, tmodel, level );  
				ELSE Out.String( "-" );  
				END;  
				Out.Ln;  mq := mq.next;  
			END;  
			Out.Ln;  vyBase.Update( tree );  
			(*
			RReconstructMR( tree.root, 0, 0, w, h ); vyBase.Update(tree); (* testing *) 
			*)
		END;  
		(* RReconstructMR( tree.root, 0, 0, w, h );  *)
	END CheckMRConditions;  

	PROCEDURE ApplyMR*;  
	VAR tree: vyBase.Object;  name: vyName.tNameArray;  gamma, value: FLOAT64;  factor, factor2: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "tree=OBJ" );  
		IF antsCommands.ExpectObject( "tree", tree ) THEN 
			IF ~antsCommands.GetReal( "factor", factor ) THEN factor := 4.6 END;  
			IF ~antsCommands.GetReal( "factor2", factor2 ) THEN factor2 := 0 END;  
			aM.SRSR( "Doing MR reconstruction with f1=", factor, "f2=", factor2 );  
			WITH tree: QuadTree DO CheckMRConditions( tree, factor, factor2 );  vyBase.Update( tree );  
			END;  
		END;  
	END ApplyMR;  

	PROCEDURE PlugInFromTree*;  
	VAR from, to, tree, array: vyBase.Object;  name, copy: vyName.tNameArray;  newtree: QuadTree;  p: PlugInQ;  
	BEGIN 
		antsCommands.InitScan( "from=OBJ to=OBJ" );  
		IF antsCommands.ExpectObject( "from", from ) & antsCommands.ExpectObject( "to", to ) THEN 
			WITH from: QuadTree DO 
				WITH to: QuadTree DO 
					p := from.plugins;  Out.String( "Pluggin Models:" );  
					WHILE (p # NIL ) DO 
						Out.String( "." );  p.model.SetParameters( p.parameter );  to.PlugIn( p.model, p.name, p.depth );  p := p.next;  
					END;  
					Out.Ln;  
				END;  
			END;  
		END;  
	
	END PlugInFromTree;  

BEGIN 
END wedgeTrees.

System.Free wedgeTrees ~

antsToolbox.Launch ~
wedgeTrees.Test ~
