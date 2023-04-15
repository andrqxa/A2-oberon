MODULE wedgeTreePlot IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)


IMPORT vyPort, Objects, vyName, vyBase, vyGraphBase := vyGraphBase, Display, Files, Gadgets, vyCommandMenus, 
	aM := antsMessages, vyHostStrings, vyCG := vyName, antsCommands, vyLayers2d := vyDisplay2d, wedgeTrees, 
	vyStrings := vyHostStrings, Attributes, wedgeHierarchicModel;  

TYPE 
	
	(** Layer definition *)
	tLayer* = POINTER TO tLayerDesc;  
	tLayerDesc* = RECORD (vyPort.tLayerDesc);  
		tree: wedgeTrees.QuadTree;  
		tree2: wedgeHierarchicModel.Tree; 
		rx, ry, rw, rh: FLOAT64;  
	END;  
VAR 
	tempLayer: tLayer;  

	PROCEDURE DisplayNode( node: wedgeTrees.QNode;  x, y, w, h: SIGNED32;  mode: SIGNED32;  xr, yr, wr, hr: FLOAT64 );  
	VAR approx: wedgeTrees.LocalApproximation;  left, right, upper, lower: SIGNED32;  s: vyGraphBase.Style;  
	BEGIN 
		IF (x + w < xr) OR (x > xr + wr) OR (y + h < yr) OR (y > yr + hr) THEN RETURN END;  
		approx := node.active;  
		IF approx # NIL THEN s := vyGraphBase.S;  approx.model.Display( x, y, w, h, approx, mode );  vyGraphBase.SetStyle( s );  
		ELSE 
			left := w DIV 2;  right := w - left;  lower := h DIV 2;  upper := h - lower;  
			IF node.ll # NIL THEN DisplayNode( node.ll, x, y, left, lower, mode ,xr,yr,wr,hr);  END;  
			IF node.lr # NIL THEN DisplayNode( node.lr, x + left, y, right, lower, mode ,xr,yr,wr,hr);  END;  
			IF node.ul # NIL THEN DisplayNode( node.ul, x, y + lower, left, upper, mode  ,xr,yr,wr,hr) ;  END;  
			IF node.ur # NIL THEN DisplayNode( node.ur, x + left, y + lower, right, upper, mode ,xr,yr,wr,hr );  END;  
		END;  
	
	END DisplayNode;  

	PROCEDURE DisplayNodes(a: wedgeHierarchicModel.ApproxQ; mode: SIGNED32);
VAR   s: vyGraphBase.Style;	BEGIN
		WHILE(a#NIL) DO 
			IF a.a#NIL THEN 
				IF a.a.model # NIL THEN 
				s := vyGraphBase.S; 
			a.a.model.Display( a.x, a.y, a.w, a.h, a.a, mode ); vyGraphBase.SetStyle( s );
			END; 
			END; 
			a := a.next; 
		END; 
	END DisplayNodes;

	

	PROCEDURE Recall( layer: tLayer );  
	VAR tree: wedgeTrees.QuadTree;  x, y, w, h: SIGNED16;  numbers: BOOLEAN;  xr, yr, wr, hr: FLOAT64;  mode: SIGNED32;  
	BEGIN 
		tree := layer.tree;  
		IF (tree = NIL) & (layer.tree2=NIL) THEN RETURN END;  
		
		IF tree # NIL THEN vyGraphBase.Rect2dToRect( 0, 0, tree.w, tree.h, x, y, w, h );  
		ELSIF layer.tree2 # NIL THEN vyGraphBase.Rect2dToRect( 0, 0, layer.tree2.w, layer.tree2.h, x, y, w, h );  
		END; 
		vyGraphBase.SetForeColor( 1 );  
		vyGraphBase.FrameRect( x, y, w + 1, h + 1 );  vyGraphBase.SetForeColor( layer.style.fcol );  numbers := FALSE;  
		Attributes.GetBool( layer, "Numbers", numbers );  
		IF numbers THEN mode := wedgeTrees.detailed ELSE mode := wedgeTrees.simple END;  
		vyGraphBase.GetRealWorldRgn( xr, yr, wr, hr );  vyGraphBase.SetForeColor( layer.style.fcol );  
		IF layer.tree2 # NIL THEN DisplayNodes(layer.tree2.approxQ,mode); RETURN END; 
		DisplayNode( tree.root, 0, 0, tree.w, tree.h, mode, xr, yr, wr, hr );  
	END Recall;  

(*	PROCEDURE Responsible( layer: tLayer;  VAR event: vyEvents.EventMsg );  
	VAR priority: SIGNED16;  
	BEGIN 
		priority := vyEvents.PrioNone;  
	END Responsible;  
*)
	PROCEDURE Copy( source, dest: tLayer );  
	BEGIN 
		dest^ := source^
	END Copy;  

	PROCEDURE HandleFileMsg( obj: tLayer;  VAR msg: Objects.FileMsg );  
	VAR objsub: Objects.Object;  version: SIGNED16;  
	
	BEGIN 
		IF msg.id = Objects.load THEN 
			Files.ReadInt( msg.R, version );  vyPort.LayerHandler( obj, msg );  Gadgets.ReadRef( msg.R, obj.lib, objsub );  
			IF objsub # NIL THEN obj.tree := objsub( wedgeTrees.QuadTree ) END;  
		ELSIF msg.id = Objects.store THEN 
			Files.WriteInt( msg.R, 2 );  vyPort.LayerHandler( obj, msg );  Gadgets.WriteRef( msg.R, obj.lib, obj.tree );  
		ELSE vyPort.LayerHandler( obj, msg )
		END 
	END HandleFileMsg;  

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );  
	BEGIN 
		IF M.id = Objects.enum THEN M.Enum( "Gen" );  vyPort.LayerHandler( obj, M )
		ELSIF M.id = Objects.get THEN 
			IF M.name = "Gen" THEN COPY( 'wedgeTreePlot.Gen', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END 
		ELSIF M.id = Objects.set THEN vyPort.LayerHandler( obj, M )
		ELSE vyPort.LayerHandler( obj, M )
		END 
	END HandleAttributes;  

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );  
	BEGIN 
		IF (msg.id = Objects.enum) THEN msg.Enum( "Tree" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "Tree") THEN msg.obj := obj.tree;  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END 
	END HandleLinks;  

	PROCEDURE ToggleNumbers;  
	VAR numbers: BOOLEAN;  
	BEGIN 
		Attributes.GetBool( tempLayer, "Numbers", numbers );  Attributes.SetBool( tempLayer, "Numbers", ~numbers );  
		vyBase.Update( tempLayer );  
	END ToggleNumbers;  
	
	PROCEDURE PresetColors;
	BEGIN
		IF tempLayer.style.fcol=vyGraphBase.red THEN 
			tempLayer.style.fcol := vyGraphBase.dkred; tempLayer.style.selectcol := vyGraphBase.dkblue; tempLayer.style.fillcol := vyGraphBase.dkgreen; 
		ELSIF tempLayer.style.fcol=vyGraphBase.dkred THEN 
			tempLayer.style.fcol := vyGraphBase.black ; tempLayer.style.selectcol := vyGraphBase.black;  tempLayer.style.fillcol := vyGraphBase.black; 
		ELSE
			tempLayer.style.fcol := vyGraphBase.red; tempLayer.style.selectcol := vyGraphBase.green; tempLayer.style.fillcol := vyGraphBase.blue;
		END; 
		vyBase.Update( tempLayer );
	END PresetColors;


	PROCEDURE GHandler*( o: Objects.Object;  VAR msg: Objects.ObjMsg );   (*= layer handling, responsible for messages and vyPort event handling *)
	VAR layer, copy: tLayer;  
	BEGIN 
		ASSERT ( o IS tLayer, 100 );  
		layer := o( tLayer );  tempLayer := layer;  
		WITH msg: Display.DisplayMsg DO 
		(* IF layer.Edges THEN Recall2(layer) ELSE *)
			Recall( layer );   (*  END;     *)
		| msg: vyBase.UpdateMessage DO vyPort.LayerHandler( o, msg )
		| msg: Objects.CopyMsg DO NEW( copy );  msg.obj := copy;  Copy( layer, msg.obj( tLayer ) );  
		| msg: Objects.FileMsg DO HandleFileMsg( layer, msg )
		| msg: Objects.AttrMsg DO HandleAttributes( layer, msg )
		| msg: Objects.LinkMsg DO HandleLinks( layer, msg )
		| msg: vyCommandMenus.enumMsg DO 
			vyPort.LayerHandler( layer, msg );  tempLayer := layer;  msg.Enum( "Toggle Numbers", ToggleNumbers, layer );  msg.Enum( "Preset Colors", PresetColors, layer ); 
		| msg: Objects.BindMsg DO 
			IF msg.lib # layer.lib THEN 
				vyPort.LayerHandler( layer, msg );  Gadgets.BindObj( layer.tree, msg.lib );  
				IF (layer.tree # NIL ) & (layer.tree.handle # NIL ) THEN layer.tree.handle( layer.tree, msg ) END 
			END;  
		ELSE vyPort.LayerHandler( o, msg )
		END;  
	END GHandler;  

	PROCEDURE Init( layer: tLayer );  
	BEGIN 
		layer.handle := GHandler;  
	END Init;  

	PROCEDURE OpenLayer( layer: tLayer;  tree: wedgeTrees.QuadTree; tree2: wedgeHierarchicModel.Tree  );  
	VAR name: vyName.tNameArray;  
	BEGIN 
		vyName.GetObjId( tree, name );  vyHostStrings.Append( name, ":TreePlot" );  vyPort.OpenLayer( layer, name );  Init( layer );  
		layer.style.fcol := vyGraphBase.dkred;  layer.style.selectcol := vyGraphBase.dkblue;  
		layer.style.fillcol := vyGraphBase.dkgreen;  layer.tree := tree;  layer.tree2 := tree2; 
		IF layer.tree # NIL THEN 
		vyBase.Subscribe( layer.tree, layer )
		END; 
				IF layer.tree2 # NIL THEN 
		vyBase.Subscribe( layer.tree2, layer )
		END; 

	END OpenLayer;  

	PROCEDURE Gen*;  
	VAR m: tLayer;  
	BEGIN 
		aM.cmd;  NEW( m );  Init( m );  m.handle := GHandler;  Objects.NewObj := m;  
	
	END Gen;  

	PROCEDURE NewLayer*( n: wedgeTrees.QuadTree; tree2: wedgeHierarchicModel.Tree ): tLayer;  
	VAR m: tLayer;  
	BEGIN 
		Gen;  m := Objects.NewObj( tLayer );  OpenLayer( m, n,tree2 );  RETURN m
	END NewLayer;  

	PROCEDURE DoShow*( tree: wedgeTrees.QuadTree; tree2: wedgeHierarchicModel.Tree ): tLayer;  
	(*= creates new instance of a layer, calls Open, opens new port and picture, adds layer to picture *)
	VAR port: vyPort.Frame;  picture: vyPort.Picture;  c: vyLayers2d.tCoordinate2d;  layer: tLayer;  w,h: SIGNED32; 
	BEGIN 
		IF tree#NIL THEN w := tree.w; h := tree.h ELSIF tree2#NIL THEN w := tree2.w; h := tree2.h END; 
		layer := NewLayer( tree ,tree2);  c := vyLayers2d.NewC2d( 0, 0, w,h );  
		port := vyPort.InsertNewFrame( SHORT( w ), SHORT( h ) );  picture := vyPort.NewP( c );  
		picture.backGround := vyGraphBase.white;  vyPort.AddPicture( port, picture, 0, 0, 1, 1 );  

		vyPort.AddLayer( picture, layer );  RETURN layer
	END DoShow;  

	PROCEDURE Show*;  
	VAR l: antsCommands.tScanList;  obj: vyBase.Object;  la: tLayer;  n: wedgeTrees.QuadTree;  tree2: wedgeHierarchicModel.Tree;
	BEGIN 
		l := antsCommands.ScanFromPar( "name=OBJ" );  
		IF antsCommands.ExpectObjectFromKeyword( l, "name", obj ) THEN 
			IF obj IS wedgeTrees.QuadTree THEN 
		n := obj( wedgeTrees.QuadTree );  
			ELSIF obj IS wedgeHierarchicModel.Tree THEN 
				tree2 := obj(wedgeHierarchicModel.Tree)
				END; 
		la := DoShow( n ,tree2) END 
	END Show;  

	PROCEDURE ShowP*;  
	VAR data: Objects.Object;  editor: tLayer;  name: vyCG.tNameArray;  n: wedgeTrees.QuadTree;  tree2: wedgeHierarchicModel.Tree;

	BEGIN 
		data := vyBase.NextParObj();  
		WHILE (data # NIL ) DO 
			vyName.GetObjId( data( vyBase.Object ), name );  
					IF data IS wedgeTrees.QuadTree THEN 
		n := data( wedgeTrees.QuadTree );  
			ELSIF data IS wedgeHierarchicModel.Tree THEN 
				tree2 := data (wedgeHierarchicModel.Tree)
				END; 

			editor := DoShow( n ,tree2);  
			data := vyBase.NextParObj()
		END 
	END ShowP;  

BEGIN 
	aM.launch;  
END wedgeTreePlot.
