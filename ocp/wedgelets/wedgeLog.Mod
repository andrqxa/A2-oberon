MODULE wedgeLog IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

IMPORT antsReadWrite, antsCommands, aM := antsMessages, vyLongrealVec, antsArrayObjects, vyBase;  

VAR 
	R: antsReadWrite.Rider;  
	filename: ARRAY 256 OF CHAR;  
	
	PROCEDURE Open*;  
	VAR name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name=STRING" );  
		IF antsCommands.ExpectString( "name", name ) THEN 
			IF filename # "" THEN aM.eSS( "File was open: ", filename ) END;  
			R.ForceNew( name );  R.SetAscii;  aM.SS( "Opened ", name );  COPY( name, filename );  
		END;  
	END Open;  

	PROCEDURE Close*;  
	BEGIN 
		IF filename # "" THEN R.Close();  filename := "" ELSE aM.eS( "No file open" );  END;  
	END Close;  

	PROCEDURE String*;  
	VAR name: ARRAY 256 OF CHAR;  
	BEGIN 
		antsCommands.InitScan( "name=STRING" );  
		IF antsCommands.ExpectString( "name", name ) & (filename # "") THEN R.WriteString( name );  R.Write( 09X );  END;  
	END String;  

	PROCEDURE Ln*;  
	BEGIN 
		IF filename # "" THEN R.WriteLn();  END;  
	END Ln;  

	PROCEDURE Reals*;  
	VAR real: FLOAT64;  
	BEGIN 
		antsCommands.InitScan( "real=REAL" );  
		IF (filename # "") & antsCommands.ExpectReal( "real", real ) THEN 
			R.WriteLReal( real );  
			WHILE (antsCommands.GetReal( "", real )) DO R.WriteLReal( real );  END;  
		END;  
	END Reals;  

	PROCEDURE WriteObject( obj: vyBase.Object );  
	BEGIN 
		IF obj IS vyLongrealVec.tVector THEN 
			R.WriteLInt( vyLongrealVec.Len( obj( vyLongrealVec.tVector ) ) );  R.WriteLn;  
			R.WriteLRealsLine( obj( vyLongrealVec.tVector ) );  
		ELSIF obj IS antsArrayObjects.tLONGREALObject THEN 
			R.WriteLInt( obj( antsArrayObjects.tObject ).w );  R.WriteLInt( obj( antsArrayObjects.tObject ).h );  R.WriteLn;  
			R.WriteMatrixX( obj( antsArrayObjects.tLONGREALObject ).A^ );  
		ELSIF obj IS antsArrayObjects.tINTEGERObject THEN 
			R.WriteLInt( obj( antsArrayObjects.tObject ).w );  R.WriteLInt( obj( antsArrayObjects.tObject ).h );  R.WriteLn;  
			R.WriteMatrixI( obj( antsArrayObjects.tINTEGERObject ).A^ );  
		END;  
	
	END WriteObject;  

	PROCEDURE Objects*;  
	VAR obj: vyBase.Object;  
	BEGIN 
		antsCommands.InitScan( "obj=OBJECT" );  
		IF antsCommands.ExpectObject( "obj", obj ) THEN 
			WriteObject( obj );  
			WHILE (antsCommands.GetObject( "", obj )) DO WriteObject( obj );  END;  
		END;  
	END Objects;  

	
	(* folgende Prozeduren sind für die Anwendung aus einer Prozedur heraus, schreiben allerdings nur EIN Objekt ins logfile *)
	
	PROCEDURE StringIn*( VAR name: ARRAY OF CHAR );  
	BEGIN 
		R.WriteString( name );  R.Write( 09X );  
	END StringIn;  

	PROCEDURE RealIn*( VAR real: FLOAT64 );  
	BEGIN 
		R.WriteLReal( real ); R.Write(09X);  
	END RealIn;  

	PROCEDURE LnIn*;  
	BEGIN 
		R.WriteLn();  
	END LnIn;  

	PROCEDURE ObjectsIn*( VAR obj: vyBase.Object );  
	BEGIN 
		WriteObject( obj );  
	END ObjectsIn;  

END wedgeLog.

wedgeLog.Open testfile ~
wedgeLog.String "Hallo Welt"
wedgeLog.Ln testfile ~
wedgeLog.Reals 1.32 1.45 1.5  1.68 ~
wedgeLog.Objects testarrayI ~
wedgeLog.Close testfile ~
wedgeNumOps.NewReal h 100 ~
wedgeLog.Reals h ~
wedgeNumOps.WriteRE h ~
