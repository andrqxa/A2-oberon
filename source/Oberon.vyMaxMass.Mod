MODULE vyMaxMass IN Oberon;
(* Copyright notice:

This file is part of Voyager
Copyright (C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

Copy of the GNU Lesser General Public License can be found in the file COPYING.TXT
Report any problems as soon as possible to voyager@statlab.uni-heidelberg.de
*)


(* 	(c) Project Voyager, StatLab Heidelberg
(c) G. Sawitzki, StatLab Heidelberg
(c) M. Diller, StatLab Heidelberg
*)

(*= max mass plot this plot has no interactive capabilities*)
(*	history:
9.8.95 md 0.0a1	alpha version
27.10.94 md 0.0d3	adaped to the renamed vyHostDisplay & vyPictures *)
(*	the sorting algorithm in the recall routine works on the original data*)
IMPORT Gadgets, Objects, Display, vyHostTexts, vyBase, vyRealVec, vyTypes, vyName, vyLinks, vyGraphBase, vyDisplay2d, vyPort;

CONST
	idversion* = "vyMaxMass v0r0a3";  cMin = 0;  cMax = 1;

TYPE
	tLayer* = POINTER TO tLayerDesc;
	tLayerDesc = RECORD (vyPort.tLayerDesc) END;

VAR
	slink*, dlink*: Objects.Object;  newlayer-: tLayer;

(*PROCEDURE^ Alloc*;*)

	PROCEDURE Recall( maxMass: tLayer );
	(*vs 0.0a1	md  10.08.94 *)
	(* converted from the shorth plot in Shorty (c) G. Sawitzki *)
	CONST cPens = 10;
	TYPE tPoint = RECORD
			H, V: FLOAT32
		END;
	VAR lenv, recordv: vyBase.tVector;  xp, yp: FLOAT32;  recordCount: SIGNED16;  lenMin: FLOAT32;  dataSpan: FLOAT32;
		penVec: ARRAY cPens + 1 OF tPoint;
		yFac: FLOAT32;  delta: SIGNED16;  I, J, rightLim, leftLim, dataPoint, count: SIZE;
	BEGIN
		IF maxMass.x # NIL THEN
			count := maxMass.x.nrData;
			(*! sort should work on a copy of the data *)
			vyTypes.Sort( maxMass.x );  vyGraphBase.SetDisplayMode( vyGraphBase.replace );  lenv := vyRealVec.New( count );
			recordv := vyRealVec.New( count );
			dataSpan := vyRealVec.Get( maxMass.x, count - 1 ) - vyRealVec.Get( maxMass.x, 0 );

			yFac := 1 / dataSpan;

			FOR I := 0 TO cPens - 1 DO penVec[I].H := 0;  penVec[I].V := 0 END;   (*FOR*)

			FOR I := 1 TO cPens DO
				IF I = cPens DIV 2 THEN vyGraphBase.SetPenSize( 2 ) ELSE vyGraphBase.SetPenSize( 1 ) END;   (*IF*)

				IF ABS( I - cPens DIV 2 ) > cPens DIV 3 THEN  (*PENPAT(LTGRAY)*) vyGraphBase.SetForeColor( vyGraphBase.mgrey )
				ELSIF ABS( I - cPens DIV 2 ) > cPens DIV 4 THEN  (*PENPAT(DKGRAY)*) vyGraphBase.SetForeColor( vyGraphBase.dgrey )
				END;   (*IF*)

				delta := SHORT( ENTIER( (I * count / cPens) + 0.5 ) );
				(*vyPaint2.MoveTo(penVec[I].H, penVec[I].V);*)

				FOR dataPoint := 1 TO count - delta DO
					vyRealVec.Set( vyRealVec.Get( maxMass.x, dataPoint + delta - 1 ) - vyRealVec.Get( maxMass.x, dataPoint - 1 ),
											 lenv, dataPoint - 1 )
				END;   (*FOR*)

				FOR dataPoint := 1 TO count DO

					recordCount := 0;  lenMin := dataSpan;  rightLim := count - delta + 1;
					IF rightLim > dataPoint THEN rightLim := dataPoint END;   (*IF*)  leftLim := dataPoint - delta;
					IF leftLim < 1 THEN leftLim := 1 END;   (*IF*)

					FOR J := rightLim TO leftLim BY -1 DO
						INC( recordCount );  vyRealVec.Set( vyRealVec.Get( lenv, J - 1 ), recordv, recordCount - 1 )
					END;   (*FOR j*)

					IF recordCount = 1 THEN lenMin := vyRealVec.Get( recordv, 1 - 1 )
					ELSE
						vyTypes.Sort( recordv );
						IF ODD( recordCount ) THEN lenMin := vyRealVec.Get( recordv, (recordCount DIV 2) + 1 - 1 )
						ELSE
							lenMin :=
								(vyRealVec.Get( recordv, (recordCount DIV 2) - 1 ) + vyRealVec.Get( recordv, (recordCount DIV 2) + 1 - 1 )) /
											2
						END;   (*IF*)
					END;   (*IF*)

					(*(*$IFC ranked*)*)
					xp := dataPoint;
					(*(*$ELSEC*)*)
					(*xp := vyTypes.CHunkREALEntry (data, dataPoint-1);*)
					(*(*$ENDC*)*)
					yp := -lenMin * yFac;
					IF dataPoint = 1 THEN vyGraphBase.MoveTo2d( xp, yp ) END;   (*IF*) vyGraphBase.LineTo2d( xp, yp )
				END;   (*FOR dataPoint*)
			END;   (*FOR cPen*)
		END
	END Recall;

	PROCEDURE Copy( source, dest: tLayer );   (* FOF inserted *)
	BEGIN
		dest^ := source^
	END Copy;

	PROCEDURE Consume( o: tLayer;  msg: Display.ConsumeMsg );
	VAR v: vyBase.tVector;  pict: vyPort.Picture;
	BEGIN
		pict := msg.dlink( vyPort.Picture );  v := vyBase.GetVFromObj( msg.obj );
		IF v # NIL THEN vyBase.UnSubscribe( o.x, o );

			Init( o, msg.obj );  vyPort.SetNewC2d( pict, 0, -1, o.x.nrData, 1 );  vyBase.Update( v )
		END
	END Consume;

	PROCEDURE HandleAttributes( obj: tLayer;  VAR M: Objects.AttrMsg );
	BEGIN
		IF M.id = Objects.get THEN
			IF M.name = "Gen" THEN COPY( 'vyMaxMass.New', M.s );  M.class := Objects.String;  M.res := 0 ELSE vyPort.LayerHandler( obj, M ) END
		ELSE vyPort.LayerHandler( obj, M )
		END
	END HandleAttributes;

	PROCEDURE AdjustCoord( pict: vyPort.Picture;  obj: tLayer );
	VAR minX, maxX: FLOAT32;  nans: SIZE;
	BEGIN
		IF pict # NIL THEN
			IF obj.x # NIL THEN vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans ) ELSE minX := 0;  maxX := 1 END;
			(*vyPort.SetNewC2d ( pict, minX, cMin, maxX - minX, cMax - cMin)*)
			vyPort.SetNewC2d( pict, 0, -1, obj.x.nrData, 1 )
		END
	END AdjustCoord;

	PROCEDURE SetModel( pict: vyPort.Picture;  obj: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;
	BEGIN
		IF (obj.x # NIL ) THEN vyBase.UnSubscribe( obj.x, obj );  obj.x := NIL END;
		IF data = NIL THEN RETURN END;
		obj.sources := NIL;  obj.x := vyBase.GetVFromObj( data );
		IF (obj.x = NIL ) THEN vyHostTexts.Note( vyHostTexts.cWarning, "vyMaxMass.SetModel: can't show these data as a maxMass-plot" )
		ELSE
			COPY( "maxMass: ", id );  vyName.AppendObjId( data( vyBase.Object ), id );  vyName.RegisterNamed( obj, id );
			vyBase.Subscribe( (*for messages from source*) obj.x, obj );
			AdjustCoord( pict, obj );  vyBase.Update( data )
		END
	END SetModel;

	PROCEDURE HandleLinks( obj: tLayer;  VAR msg: Objects.LinkMsg );
	(*! handle subscribe/unsubscribe. Move to vyPort *)
	VAR pict: vyPort.Picture;
	BEGIN
		IF (msg.id = Objects.enum) THEN msg.Enum( "x" );  vyPort.LayerHandler( obj, msg )
		ELSIF (msg.id = Objects.get) & (msg.name = "x") THEN msg.obj := obj.x;  msg.res := 0
		ELSIF (msg.id = Objects.set) & ((msg.name = "x") OR (msg.name = "Model")) & (msg.obj # NIL ) & (msg.obj IS vyBase.tVector) THEN
			(* check proper type *)
			IF msg.dlink # NIL THEN pict := msg.dlink( vyPort.Picture ) ELSE pict := NIL END;
			SetModel( pict, obj, msg.obj );  msg.res := 0
		ELSE vyPort.LayerHandler( obj, msg )
		END
	END HandleLinks;

	PROCEDURE Store0( obj: tLayer;  VAR M: Objects.FileMsg );
	BEGIN
		Gadgets.WriteRef( M.R, obj.lib, obj.x )
	END Store0;

	PROCEDURE Load0( obj: tLayer;  VAR M: Objects.FileMsg );
	VAR objsub: Objects.Object;
	BEGIN
		dlink := M.dlink;  Gadgets.ReadRef( M.R, obj.lib, objsub );
		IF (objsub # NIL ) & (objsub IS vyBase.tVector) THEN obj.x := objsub( vyBase.tVector ) END
	END Load0;

	PROCEDURE New*;   (* Gadgets.Insert vyMaxMass.New *)
	BEGIN
		NEW( newlayer );  Init( newlayer, NIL );  Objects.NewObj := newlayer
	END New;

	PROCEDURE Handler*( obj: Objects.Object;  VAR msg: Objects.ObjMsg );   (*vs 0.0a1	md  20.07.94 *)
	VAR minX, maxX: FLOAT32;  pict: vyPort.Picture;  nans: SIZE;
	BEGIN
		WITH obj: tLayer DO
			IF msg IS Display.DisplayMsg THEN
				WITH msg: Display.DisplayMsg DO Recall( obj );
				END;
			ELSIF msg IS Objects.CopyMsg THEN
				WITH msg: Objects.CopyMsg DO
				(*Alloc; copy := Objects.NewObj(tLayer);   msg.obj := copy;  vyPort.LayerHandler (obj, msg);
Copy (obj, msg.obj(tLayer));*)
					New;  msg.obj := newlayer;  vyPort.LayerHandler( obj, msg );  Copy( obj, msg.obj( tLayer ) );
				END;
			ELSIF msg IS Objects.FileMsg THEN
				WITH msg: Objects.FileMsg DO
					IF msg.id = Objects.load THEN
						Load0( obj, msg );  vyPort.LayerHandler( obj, msg );
						(*! hack *) IF obj.x # NIL THEN
							pict := msg.dlink( vyPort.Picture );
							IF pict # NIL THEN
								vyTypes.VGetMinMaxR( obj.x, minX, maxX, nans );  vyPort.SetNewC2d( pict, minX, 0, maxX - minX, 1 )
							ELSE  (*vyHostTexts.Note(vyHostTexts.cWarning,"vyMaxMass: no host picture  ")*)
							END
						ELSE vyHostTexts.Note( vyHostTexts.cWarning, "vyMaxMass: no x obj loaded  " )
						END
					ELSIF msg.id = Objects.store THEN Store0( obj, msg );  vyPort.LayerHandler( obj, msg )
					ELSE vyPort.LayerHandler( obj, msg )
					END;
				END;
			ELSIF msg IS Display.ConsumeMsg THEN
				WITH msg: Display.ConsumeMsg DO Consume( obj, msg );  vyPort.LayerHandler( obj, msg )
				END;
			ELSIF msg IS Objects.AttrMsg THEN
				WITH msg: Objects.AttrMsg DO HandleAttributes( obj, msg )
				END;
			ELSIF msg IS Objects.LinkMsg THEN
				WITH msg: Objects.LinkMsg DO HandleLinks( obj, msg )
				END;
			ELSIF msg IS Objects.BindMsg THEN
				WITH msg: Objects.BindMsg DO
					vyPort.LayerHandler( obj, msg );
					IF obj.x # NIL THEN Gadgets.BindObj( obj.x, msg.lib ) END
				END;
			ELSE vyPort.LayerHandler( obj, msg )
			END
		END
	END Handler;

	PROCEDURE Init*( F: tLayer;  data: Objects.Object );
	VAR id: vyName.tNameArray;  inconsistentConditions: BOOLEAN;
	BEGIN
		F.handle := Handler;  COPY( "maxMass: ", id );  F.x := vyBase.GetVFromObj( data );
		IF (F.x = NIL ) & (data # NIL ) THEN vyHostTexts.Msg( "can't plot this data as a maxMass plot: not the right type!" );  inconsistentConditions := TRUE;
			ASSERT ( ~inconsistentConditions )
		END;
		IF data # NIL THEN vyName.AppendObjId( data( vyBase.Object ), id ) END;
		vyPort.OpenLayer( F, id );
		IF F.x # NIL THEN
			(*		vyBase.Subscribe ((*for messages from source*) vyHighlight.GetSelectionAttribute (F.x.nrData), F);
vyBase.Subscribe ((*for messages from source*) vyHighlight.GetColorAttribute (F.x.nrData), F);*)
			vyBase.Subscribe( (*for messages from source*) F.x, F )
		END
	END Init;

	PROCEDURE ShowP*;
	VAR data: Objects.Object;
	BEGIN
		data := vyBase.NextParObj();
		WHILE data # NIL DO
			New;  Init( newlayer, data );
			(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d (0, -1, F.x.nrData,1));
vyPort.AddLayer (pict,F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			vyPort.SetNewC2d( vyPort.newpicture, 0, -1, newlayer.x.nrData, 1 );  data := vyBase.NextParObj()
		END
	END ShowP;

	PROCEDURE ShowL*( list: vyLinks.Link );
	BEGIN
		WHILE list # NIL DO
			New;  Init( newlayer, list.obj );
			(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d (0, -1, F.x.nrData,1));
vyPort.AddLayer (pict,F);*)
			vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
			vyPort.SetNewC2d( vyPort.newpicture, 0, -1, newlayer.x.nrData, 1 );  list := list.link;
			(*Objects.NewObj := pict*)
		END
	END ShowL;

	PROCEDURE ShowO*( obj: Objects.Object );
	BEGIN
		New;  Init( newlayer, obj );
		(*pict := vyPort.InsertNewCPicture (0, 0, 1, 1, vyDisplay2d.NewC2d (0, -1, F.x.nrData,1));
vyPort.AddLayer (pict,F);
Objects.NewObj := pict*)
		vyPort.AddLayer( vyPort.InsertNewVecPicture( newlayer.x, NIL ), newlayer );
		vyPort.SetNewC2d( vyPort.newpicture, 0, -1, newlayer.x.nrData, 1 )
	END ShowO;

	PROCEDURE NewPict*;   (* Gadgets.Insert vyMaxMass.NewPict *)
	VAR pict: vyPort.Picture;
	BEGIN
		New;  pict := vyPort.XNewCPicture( 0, 0, 1, 1, vyDisplay2d.NewC2d( 0, cMin, 1, cMax - cMin ) );
		vyPort.AddLayer( pict, newlayer );  Objects.NewObj := pict
		(* Out.String('vyMaxMass.XNewPict done'); IF pict.gcontext#NIL THEN Out.String(' w.context');END; Out.Ln; *)
	END NewPict;

(*	PROCEDURE Alloc*;
VAR	layer: tLayer;
BEGIN NEW (layer); layer.handle := Handler; Objects.NewObj := layer END Alloc;*)

END vyMaxMass.
