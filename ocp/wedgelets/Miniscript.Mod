MODULE Miniscript IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT Texts, aM := antsMessages, Oberon, Display;  

TYPE 
	
	StringList = OBJECT 
	VAR s: ARRAY 256 OF CHAR;  
		next: StringList;  
	END StringList;  
	
	StringList2 = OBJECT 
	VAR from, to: ARRAY 256 OF CHAR;  
		next: StringList2;  
	END StringList2;  
	
	ReplacementList = OBJECT 
	VAR list: StringList2;  
		
		PROCEDURE Enter( from, to: ARRAY OF CHAR );  
		VAR this, last: StringList2;  
		BEGIN 
			IF list = NIL THEN NEW( list );  COPY( from, list.from );  COPY( to, list.to );  RETURN END;  
			this := list;  
			WHILE (this # NIL ) DO 
				IF this.from = from THEN COPY( to, this.to );  RETURN END;  
				last := this;  this := this.next;  
			END;  
			NEW( last.next );  this := last.next;  COPY( from, this.from );  COPY( to, this.to );  
		END Enter;  

		PROCEDURE Remove( from: ARRAY OF CHAR );  
		VAR this: StringList2;  
		BEGIN 
			IF list = NIL THEN RETURN 
			ELSIF list.from = from THEN list := list.next
			ELSE 
				this := list;  
				WHILE (this.next # NIL ) & (this.next.from # from) DO this := this.next;  END;  
				IF this # NIL THEN this.next := this.next.next;  END;  
			END;  
		END Remove;  

	END ReplacementList;  

TYPE 
	Scanner = OBJECT 
	VAR sc: Texts.Scanner;  
		lastpos, lastline: SIGNED32;  
		otext: Texts.Text;  
		opos: SIGNED32;  
		repl: ReplacementList;  
		
		PROCEDURE Scan;  
		BEGIN 
			lastpos := Texts.Pos( sc );  lastline := sc.line;  Texts.Scan( sc );  
		END Scan;  

		PROCEDURE & Init( text: Texts.Text;  pos: SIGNED32 );  
		BEGIN 
			otext := text;  opos := pos;  Texts.OpenScanner( sc, text, pos );  Scan;  NEW( repl );  
		END Init;  

		PROCEDURE Ident( VAR name: ARRAY OF CHAR );  
		BEGIN 
			IF (sc.class # Texts.Name) THEN Error( lastpos, "Identifier", "expected." );  HALT( 101 ) ELSE COPY( sc.s, name );  END;  
			(* aM.SS("Ident ",name); *)
			Scan;  
		END Ident;  

		PROCEDURE String( VAR name: ARRAY OF CHAR );  
		BEGIN 
			IF (sc.class # Texts.String) THEN Error( lastpos, "String", "expected." );  HALT( 101 ) ELSE COPY( sc.s, name );  END;  
			(* aM.SS("String ",name); *)
			Scan;  
		END String;  

		PROCEDURE ExpectIdent( name: ARRAY OF CHAR );  
		BEGIN 
			IF (sc.class # Texts.Name) OR (sc.s # name) THEN Error( lastpos, name, "expected." );  HALT( 102 ) END;  
			Scan;  
		END ExpectIdent;  

		PROCEDURE ExpectChar( ch: CHAR );  
		VAR s: ARRAY 4 OF CHAR;  
		BEGIN 
			s[0] := '"';  s[1] := ch;  s[2] := '"';  s[3] := 0X;  
			IF sc.class # Texts.Char THEN Error( lastpos, s, "expected." );  HALT( 103 ) END;  
			Scan;  
		END ExpectChar;  

	END Scanner;  

VAR 
	W: Texts.Writer;  

	PROCEDURE Error( pos: SIGNED32;  msg1, msg2: ARRAY OF CHAR );  
	BEGIN 
		aM.eSI( "Error at pos ", pos );  aM.eSS( msg1, msg2 );  
	END Error;  

	PROCEDURE InSet( sc: Scanner;  VAR hook: StringList ): BOOLEAN;  
	VAR name: ARRAY 256 OF CHAR;  
		temp: StringList;  
	BEGIN 
		(* aM.S("InSet"); *)
		IF (sc.sc.class # Texts.Name) OR (sc.sc.s # "IN") THEN RETURN FALSE END;  
		sc.Scan;  sc.ExpectChar( "{" );  sc.String( name );  NEW( hook );  COPY( name, hook.s );  temp := hook;  
		WHILE (sc.sc.class = Texts.Char) & (sc.sc.c = ",") DO 
			sc.Scan;  sc.String( name );  NEW( temp.next );  temp := temp.next;  COPY( name, temp.s );  
		END;  
		sc.ExpectChar( "}" );  RETURN TRUE;  
	END InSet;  

	PROCEDURE InRange( sc: Scanner ): BOOLEAN;  
	BEGIN 
		Error( sc.lastpos, "not yet implemented", "" );  
	END InRange;  

	PROCEDURE CommandLine( sc: Scanner;  VAR line: ARRAY OF CHAR );  
	VAR R: Texts.Reader;  ch: CHAR;  i: SIGNED32;  
	CONST CR = 0DX;  
	BEGIN 
		Texts.OpenReader( R, sc.otext, sc.lastpos-1 );  Texts.Read( R, ch );  i := 0;  
		WHILE (~R.eot) & (ch # CR) DO line[i] := ch;  INC( i );  Texts.Read( R, ch );  END;  
		Texts.OpenScanner( sc.sc, sc.otext, Texts.Pos( R ) );  sc.Scan;  
		(* aM.SS("CommandLine: ",line); *)
	END CommandLine;  

	PROCEDURE Replace( VAR src: ARRAY OF CHAR;  VAR from, to: ARRAY OF CHAR );  
	VAR spos, dpos, start, fpos, i: SIGNED32;  
		dest: ARRAY 1024 OF CHAR;  
	BEGIN 
		(*
	aM.S("Replacing"); aM.SSS(from,"->", to); 	aM.SS("in ",src); 
	*)
		spos := 0;  fpos := 0;  dpos := 0;  
		WHILE (src[spos] # 0X) DO 
			IF src[spos] = from[fpos] THEN 
				IF fpos = 0 THEN start := dpos;  END;  
				INC( fpos );  
				IF from[fpos] = 0X THEN 
					fpos := 0;  dpos := start;  
					WHILE (to[fpos] # 0X) DO dest[dpos] := to[fpos];  INC( fpos );  INC( dpos );  END;  
				ELSE dest[dpos] := src[spos];  INC( dpos );  
				END;  
			ELSE fpos := 0;  dest[dpos] := src[spos];  INC( dpos );  
			END;  
			INC( spos );  
		END;  
		dest[dpos] := 0X;  COPY( dest, src );  
		(*aM.S(dest); *)
	END Replace;  

	PROCEDURE DoReplacements( r: ReplacementList;  VAR s: ARRAY OF CHAR );  
	VAR this: StringList2;  
	BEGIN 
		this := r.list;  
		WHILE (this # NIL ) DO Replace( s, this.from, this.to );  this := this.next;  END;  
		Texts.WriteString( W, s );   Texts.WriteLn( W );  
	END DoReplacements;  

	PROCEDURE Lines( sc: Scanner );  
	VAR forname: ARRAY 256 OF CHAR;  
		command: ARRAY 256 OF CHAR;  
		pos: SIGNED32;  list: StringList;  
	BEGIN 
		IF sc.sc.class = Texts.Name THEN 
			IF sc.sc.s = "FOR" THEN 
				sc.Scan;  sc.String( forname );  
				IF InSet( sc, list ) OR InRange( sc ) THEN 
					sc.ExpectIdent( "DO" );  pos := sc.lastpos;  
					WHILE (list # NIL ) DO 
						(*aM.S("using replacement"); 
					aM.SS(forname,list.s); 
					*)
						sc.repl.Enter( forname, list.s );  Texts.OpenScanner( sc.sc, sc.otext, pos );  sc.Scan;  Lines( sc );  
						sc.ExpectIdent( "END" );  sc.ExpectChar( ";" );  list := list.next;  
					END;  
					sc.repl.Remove( forname );  
				ELSE Error( sc.lastpos, "Syntax Error", "." );  
				END;  
			ELSIF sc.sc.s = "END" THEN RETURN 
			ELSE  (* command *)
				CommandLine( sc, command );  DoReplacements( sc.repl, command );   
			END;  
			Lines(sc); 
		END;  
	END Lines;  

	PROCEDURE Script( sc: Scanner );  
	VAR scriptname: ARRAY 256 OF CHAR;  
	BEGIN 
		sc.ExpectIdent( "BEGIN" );  sc.Ident( scriptname );  sc.ExpectChar( ";" );  Lines( sc );  sc.ExpectIdent( "END" );  
		sc.ExpectIdent( scriptname );  sc.ExpectChar( ";" );  
	
	END Script;  

	PROCEDURE Execute*;  
	VAR text: Texts.Text;  pos: SIGNED32;  sc: Scanner;  newtext: Texts.Text;  
	BEGIN 
		text := Oberon.Par.text;  pos := Oberon.Par.pos;  NEW( sc, text, pos );  Texts.OpenWriter( W );  Texts.WriteString( W, "fofAutomatic.Do ~" );  
		Texts.WriteLn( W );  Script( sc );  NEW( newtext );  Texts.Open( newtext, "" );  Texts.Append( newtext, W.buf );  
		Oberon.OpenText( "Miniscript", newtext, Display.Width DIV 8 * 3, Display.Height DIV 3 );  
	
	END Execute;  

END Miniscript.

wedgeCommands.ASCIIToPGMFile srcfile="camera_128_Gauss_100.txt" filename="est.pgm" ~
wedgeCommands.PlugInCWedge  tree=myTree  model=wedgeModel   >steps from= 0 to=180 by=45   ~
wedgeCommands.PlugInCWedge  tree=myTree model=adaptiveWedgeModel  >adaptive numofangles=512 offset=0 ~
,"barb_256","peppers_256","bird_256"
,"barb_256","peppers_256","bird_256"
(* Für die Ausgabe des minimierten Bildes*)

	wedgeCommands.Minimize tree=myTree gamma=gammaopt ~
	wedgeCommands.ToArray tree =myTree destR = resultR ~
	wedgeCommands.ToAsciiFile src=resultR filename="<image>_<noise>_<var>_rec_wende.txt" ~
	wedgeCommands.ASCIIToPGMFile srcfile="<image>_<noise>_<var>_rec_wende.txt" filename="<image>_<noise>_<var>_rec_wende.pgm"~






Miniscript.Execute 

BEGIN testScript; 
	antsMessages.SetMode errors 
	wedgeLog.Open testfile ~
FOR "<image>" IN {"camera_256"} DO 
	antsArrayObjects.LoadP2 filename="images/<image>.pgm" image=testarrayI ~
	wedgeCommands.IntToReal src=testarrayI dest=testarray ~
FOR "<noise>" IN {"Gauss"} DO 
FOR "<var>" IN {"1000"} DO 
	wedgeNumOps.Add<noise>Noise src=testarray dest=noisedarray var=<var> ~
	wedgeCommands.ToAsciiFile src=noisedarray filename="<image>_<noise>_<var>.txt" ~
	wedgeCommands.ASCIIToPGMFile srcfile="<image>_<noise>_<var>.txt" filename="<image>_<noise>_<var>.pgm"~
	wedgeCommands.NewTree src=noisedarray tree=myTree >forceNew  ~ 
	wedgeCommands.NewConstRectModel model=rectModel ~
	wedgeCommands.PlugIn tree=myTree model=rectModel ~
	wedgeCommands.PlugInCWedge  tree=myTree  model=wedgeModel   >steps from= 0 to=180 by=45   ~
	wedgeNumOps.NewVec gammavec ~
	wedgeNumOps.NewVec piecesvec ~
	wedgeLog.String "<image>_<noise>_<var>" ~
	wedgeLog.Ln testfile ~
	wedgeLog.String"-----------------------------------------" ~
	wedgeLog.Ln testfile ~
	wedgeNumOps.LogGammaVectors tree=myTree from=-5  to=5 by=0.05 gamma=gammavec pieces=piecesvec >logfile ~
	wedgeLog.Ln testfile ~
	wedgeLog.Ln testfile ~
	wedgeNumOps.Log10 piecesvec ~
	wedgeNumOps.Log10 gammavec~
	wedgeNumOps.Copy from=gammavec to= gammavecfd ~
	wedgeNumOps.Copy from=piecesvec to=piecesvecfd ~
	wedgeNumOps.Copy from=gammavec to= gammavecsd ~
	wedgeNumOps.Copy from=piecesvec to=piecesvecsd ~
	wedgeNumOps.FirstDerivate fdx=gammavecfd fdy=piecesvecfd ~
	wedgeCommands.VectorsToAsciiFile srcx=gammavecfd srcy=piecesvecfd filename="<image>_<noise>_<var>_fd.txt"
	wedgeNumOps.SecondDerivate sdx= gammavecsd sdy=piecesvecsd ~
	wedgeNumOps.NewReal gammaopt1~
	wedgeNumOps.NewReal gammaopt2~
	wedgeNumOps.NewReal PSNRopt1 ~
	wedgeNumOps.NewReal PSNRopt2 ~
	
	wedgeNumOps.MinimaLoc vecx=gammavecfd vecy=piecesvecfd fdx= gammavecsd fdy=piecesvecsd step=0.02 gamma1=gammaopt1 gamma2=gammaopt2 PSNR1=PSNRopt1 PSNR2=PSNRopt2  src=testarray tree=myTree >logfile~  
	
	wedgeCommands.Minimize tree=myTree gamma=gammaopt1 >loggamma ~
	wedgeCommands.ToArray tree =myTree destR = resultR ~
	wedgeCommands.ComputePSNR src1=resultR src2=testarray ~
	wedgeCommands.ToAsciiFile src=resultR filename="<image>_<noise>_<var>_rec_wende_1.txt" ~
	wedgeCommands.ASCIIToPGMFile srcfile="<image>_<noise>_<var>_rec_wende_1.txt" filename="<image>_<noise>_<var>_rec_wende_1.pgm"~
	
	wedgeCommands.Minimize tree=myTree gamma=gammaopt2 >loggamma ~
	wedgeCommands.ToArray tree =myTree destR = resultR ~
	wedgeCommands.ComputePSNR src1=resultR src2=testarray ~
	wedgeCommands.ToAsciiFile src=resultR filename="<image>_<noise>_<var>_rec_wende_2.txt" ~
	wedgeCommands.ASCIIToPGMFile srcfile="<image>_<noise>_<var>_rec_wende_2.txt" filename="<image>_<noise>_<var>_rec_wende_2.pgm"~
	
	wedgeLog.Ln testfile ~
	wedgeNumOps.NewReal gammaPSNR ~
	wedgeNumOps.NewReal PSNRopt3 ~
	wedgeNumOps.FindOptPSNR tree=myTree from=-5 to=5 by=0.05 src=testarray gamma = gammaPSNR PSNR1=PSNRopt3 >logfile~
	wedgeCommands.Minimize tree=myTree gamma=gammaPSNR >loggamma ~
	wedgeCommands.ToArray tree =myTree destR = resultR ~
	wedgeCommands.ComputePSNR src1=resultR src2=testarray ~
	wedgeCommands.ToAsciiFile src=resultR filename="<image>_<noise>_<var>_rec_PSNR.txt" ~
	wedgeCommands.ASCIIToPGMFile srcfile="<image>_<noise>_<var>_rec_PSNR.txt" filename="<image>_<noise>_<var>_rec_PSNR.pgm"~
	wedgeLog.Ln testfile ~
	wedgeNumOps.Sub PSNRopt3 PSNRopt2 ~
	wedgeLog.Reals PSNRopt3 ~
	
	wedgeLog.Ln testfile ~
	wedgeLog.Ln testfile ~
		
END;
END; 
END; 
	wedgeLog.Close testfile ~
	antsMessages.SetMode normal 
END testScript;



Script	=	BEGIN ident [Lines] END ident".".
Lines	=	{Line}. 
Line	= 	FOR string InSet DO  [Line] END ";".
	|	FOR string InRange DO  [Line] END ";".
	|	Command";" rest [Line].
InSet	=	IN "{"string{,string}"}".
InRange	=	":=" real TO real BY real
Command	=	ident rest CR.
rest	=	{CHAR\CR} CR.
Miniscript.Text



Miniscript.Execute 

BEGIN testScript; 
FOR "<image>" IN {"camera_256","circles_256","barb_256","peppers_256","bird_256"} DO 
antsArrayObjects.LoadP2 filename="images/<image>.pgm" image=testarrayI ~
wedgeCommands.IntToReal src=testarrayI dest=testarray ~
wedgeCommands.ToAsciiFile src=testarray filename="<image>.txt" ~
wedgeCommands.ASCIIToPGMFile srcfile="<image>.txt" filename="<image>.pgm"~
END;
END testScript;	