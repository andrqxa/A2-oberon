MODULE antsGammaShooting IN Oberon;   (**  AUTHOR "fof"; PURPOSE "";  **)

TYPE 
	Intersection* = OBJECT 
	VAR x-, interceptL-, slopeL-, interceptR-, slopeR-: FLOAT64;  
		next*: Intersection;  
	END Intersection;  
	
	List = OBJECT 
	VAR first, last: Intersection;  
		
		PROCEDURE Append( x, interceptL, slopeL, interceptR, slopeR: FLOAT64 );  
		BEGIN 
			IF first = NIL THEN NEW( first );  last := first;  ELSE NEW( last.next );  last := last.next;  END;  
			last.x := x;  last.interceptL := interceptL;  last.slopeL := slopeL;  last.interceptR := interceptR;  last.slopeR := slopeR;  
			(*aM.vSR( "Add intersection at ", x );  *) 
		END Append;  

	END List;  
	
	GetLine = PROCEDURE {DELEGATE} ( x: FLOAT64;  VAR intercept, slope: FLOAT64 );  
	
	PROCEDURE Shoot( interceptL, slopeL, interceptR, slopeR: FLOAT64;  getLine: GetLine;  VAR lst: List );  
	VAR x, slopeM, interceptM: FLOAT64;  
	BEGIN 
		x := (interceptR - interceptL) / (slopeL - slopeR);   (* intersection point of the lines given by interceptL,slopeL and interceptR,slopeR *)
		getLine( x, interceptM, slopeM );  
		IF (slopeL=slopeM) OR (slopeR=slopeM) OR (interceptM + x * slopeM = interceptL + x * slopeL) THEN  (* no line beyond this line *)
			lst.Append( x, interceptL, slopeL, interceptR, slopeR );  
		ELSE  (* recursion for right and left lines *)
			Shoot( interceptL, slopeL, interceptM, slopeM, getLine, lst );  Shoot( interceptM, slopeM, interceptR, slopeR, getLine, lst );  
		END;  
	END Shoot;  

	PROCEDURE ComputeList*( left, right: FLOAT64;  getLine: GetLine ): Intersection;  
	VAR lst: List;  interceptL, slopeL, interceptR, slopeR: FLOAT64;  
	BEGIN 
		NEW( lst );  getLine( left, interceptL, slopeL );  
		lst.Append( left, MIN( FLOAT64 ), MIN( FLOAT64 ), interceptL, slopeL );  
		getLine( right, interceptR, slopeR );  
		IF slopeR # slopeL THEN Shoot( interceptL, slopeL, interceptR, slopeR, getLine, lst );  END;  
		IF lst.last.x # right THEN 
		lst.Append( right, interceptR, slopeR, MAX( FLOAT64 ), MAX( FLOAT64 ) );  
		END; 
		IF (lst.first.next # NIL) & (lst.first.next.x = lst.first.x) THEN 
			lst.first := lst.first.next; 
		END; 
		RETURN lst.first;  
	END ComputeList;  


END antsGammaShooting.


antsGammaShooting.Test 
vyScale.Insert 

(*
IMPORT aM := antsMessages,vyPort,vyLine,vyDisplay2d,vyRandom,Objects;  
TYPE
	TestObject = OBJECT 
		VAR slopeA,interceptA: POINTER TO ARRAY OF FLOAT64; len: LONGINT; 
		
		PROCEDURE &Init(nr: LONGINT);
		VAR i: LONGINT; last: FLOAT64; 
		BEGIN
			NEW(slopeA,nr); NEW(interceptA,nr); len := nr; last := 40; 
			FOR i := 0 TO len-1 DO 
				slopeA[i] := vyRandom.Uniform()*2-1; interceptA[i] := last+ vyRandom.Uniform()*2; last := interceptA[i]; 
			END; 
		END Init;
		
		PROCEDURE GetLowestLine(x: FLOAT64; VAR intercept,slope: FLOAT64);
		VAR i: LONGINT; min,y: FLOAT64; 
		BEGIN
			min := MAX(LONGREAL); 
			FOR i := 0 TO len-1 DO 
				y := interceptA[i] + slopeA[i]*x; 
				IF y < min THEN 
					intercept := interceptA[i]; 
					slope := slopeA[i]; 
					min := y; 
				END; 
			END; 
		END GetLowestLine;
		
	PROCEDURE PaintLine(intercept,slope: FLOAT64): vyPort.tLayer; 
VAR l: vyLine.tLayer; 
BEGIN 
	vyLine.New; l := Objects.NewObj(vyLine.tLayer); 
	vyLine.Open(l,FALSE,FALSE,0,100,SHORT(slope),SHORT(intercept)); 
	RETURN l; 
END PaintLine; 

PROCEDURE Paint; 
VAR p: vyPort.Picture; gc: vyDisplay2d.tCoordinate2d; l: vyPort.tLayer;  i: LONGINT; 
BEGIN
	gc := vyDisplay2d.NewC2d(-100,0,200,100); 
	p := vyPort.NewP(gc); 
	FOR i := 0 TO len-1 DO 
			l :=PaintLine(interceptA[i],slopeA[i]); 
				vyPort.AddLayer(p,l);	
	END; 
	vyPort.Write(p);
END Paint; 

			
	END TestObject;
	
	PROCEDURE Test*;
	VAR test: TestObject; lst: List; tmp: Intersection; p: vyPort.Picture; gc: vyDisplay2d.tCoordinate2d; l: vyLine.tLayer; lastslope,lastintercept,lastx: FLOAT64; 
	BEGIN
		NEW(test,10000); test.Paint; 
		tmp := ComputeList(-100,100,test.GetLowestLine); 
		gc := vyDisplay2d.NewC2d(-100,0,200,100); 
		p := vyPort.NewP(gc); 
		
		lastx := -100; 
		aM.S("-------------------------------------------"); 
		WHILE(tmp#NIL) DO 
			aM.SR("x= ",tmp.x); 
			aM.SRSR("interceptL=",tmp.interceptL,", slopeL=",tmp.slopeL); 
			aM.SRSR("interceptR=",tmp.interceptR,", slopeR=",tmp.slopeR);
			
			vyLine.New; l := Objects.NewObj(vyLine.tLayer); 
			vyLine.Open(l,TRUE,TRUE,SHORT(lastx),SHORT(tmp.x),SHORT(tmp.slopeL),SHORT(tmp.interceptL)); 
			vyPort.AddLayer(p,l);	

			lastx := tmp.x; lastslope := tmp.slopeR; lastintercept := tmp.interceptR; 
			tmp := tmp.next;  
		END; 
		vyLine.New; l := Objects.NewObj(vyLine.tLayer); 
		vyLine.Open(l,TRUE,TRUE,SHORT(lastx),100,SHORT(lastslope),SHORT(lastintercept)); 
		vyPort.Write(p);

	END Test;

*)