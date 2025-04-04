MODULE wedgeGenericEq IN Oberon;   (**  AUTHOR "ld"; PURPOSE "";  **)

IMPORT Out, SYSTEM, aM := antsMessages;  

TYPE 
	matrix10d = ARRAY 10 OF ARRAY 10 OF FLOAT64;  
	matrix4d = ARRAY 4 OF ARRAY 4 OF FLOAT64;  
	vector10d = ARRAY 10 OF ARRAY 1 OF FLOAT64;  
	vector4d = ARRAY 4 OF ARRAY 1 OF FLOAT64;  

VAR 
	id: matrix10d;  
TYPE 
	Function1d* = PROCEDURE ( x: FLOAT64 ): FLOAT64;  
	Function2d* = PROCEDURE ( x, y: FLOAT64 ): FLOAT64;  
	GenericEq* = OBJECT 
	VAR  (**)
		(* temporary variables used in GenericRegression *)
		
		txx, txxinv: matrix10d;  
		
		ttesta: matrix4d;  
		ttestb: vector4d;  
		ttestx: vector4d;  
		
		txz: vector10d;  
		
		(* temporary variable used in SolveLinear  *)
		temp: POINTER TO ARRAY OF ARRAY OF FLOAT64;  
		
		result*: vector10d;  
		
		(*In the following beta denotes the unknown regression parameters*)
		PROCEDURE GenericRegression*( VAR beta: ARRAY OF ARRAY OF FLOAT64;  m: ARRAY OF FLOAT64;  psize: SIZE ): FLOAT64;  
		VAR tmp, zz: FLOAT64;  ii, jj, iii, size: SIZE;  
		BEGIN 
		size := psize;  
			
			(*Filling Gram-Schmidt matrix <Phit.Phi>*)
			FOR ii := 0 TO size - 1 DO 
				iii := ii * (ii + 1) DIV 2;  
				FOR jj := 0 TO ii DO txx[jj, ii] := m[iii + jj];  txx[ii, jj] := m[iii + jj];  END;  
			END;  
			
			iii := size * (size + 1) DIV 2;  
			(*Filling right member <Phi.I>, I image*)
			FOR jj := 0 TO size - 1 DO txz[jj, 0] := m[iii + jj];  END;  
			
			zz := m[iii + size];  
			
			(*Solves the linear system*)			
			SolveLinearSize( txx, txz, beta, size );  

			
			(*Computes quadratic error*)
			tmp := 0.0;  
			tmp := tmp + zz;  
			
		
			FOR ii := 0 TO size - 1 DO tmp := tmp - 2.0 * beta[ii, 0] * txz[ii, 0];  END;  
			
	
			FOR ii := 0 TO size - 1 DO 
				iii := ii * (ii + 1) DIV 2;  
				FOR jj := 0 TO ii - 1 DO tmp := tmp + 2.0 * beta[ii, 0] * beta[jj, 0] * txx[ii, jj];  END;  
				tmp := tmp + beta[ii, 0] * beta[ii, 0] * txx[ii, ii];  
			END;  
		
			IF tmp < -1.0 THEN 
			 Out.String("tmp : ");  Out.LongRealFix(tmp,6,6); Out.Ln;
			 Out.String( "txx " );  Out.Ln;  Dump( txx );  

				Out.String( "txz" );  Out.Ln;  Dump( txz );  Out.String( "beta " );  Out.Ln;  Dump( beta );  
			
			END;  
			
			RETURN tmp;  
		
		END GenericRegression;  
	
	
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
	
		PROCEDURE SolveLinear*( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );  
		(* solve linear equation with arbitrary dimension*)
		BEGIN 
			IF (temp = NIL ) OR (LEN( temp ) # LEN( a )) OR (LEN( temp[0] ) # LEN( a[0] )) THEN NEW( temp, LEN( a ), LEN( a[0] ) );  END;  
			DoSolveLinear( a, b, result, temp^ );  
		END SolveLinear;  

		PROCEDURE SolveLinearSize*( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64;  size: SIZE );  
		(* solve linear equation with arbitrary dimension*)
		BEGIN 
			IF (temp = NIL ) OR (LEN( temp ) # size) OR (LEN( temp[0] ) # size) THEN NEW( temp, size, size );  END;  
			DoSolveLinearSize( a, b, result, temp^, size );  
		END SolveLinearSize;  
	
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
		PROCEDURE DoSolveLinearSize( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64;  VAR temp: ARRAY OF ARRAY OF FLOAT64;  s: SIZE );  
		VAR i, j, k, l, iMax, sr: SIZE;  Pivot, tmp, tmp2: FLOAT64;  
		CONST size = SIZEOF( FLOAT64 );  epsilon = 0.00000001;  
		BEGIN 
		(*SYSTEM.MOVE( SYSTEM.ADR( b[0, 0] ), SYSTEM.ADR( result[0, 0] ), LEN( b ) * LEN( b[0] ) * size ); *)  (* fast copy of matrix b to result, does NOT work if sizes differ! *)
		(*SYSTEM.MOVE( SYSTEM.ADR( a[0, 0] ), SYSTEM.ADR( temp[0, 0] ), LEN( a ) * LEN( a[0] ) * size );   *)  (* fast copy of matrix a to temp, does NOT work if sizes differ! *)
			(*number of the columns of the reult : i.e. number of linear systems solved*)
			sr := LEN( b[0] );  
			
			(* Initialization of the matrices *)
			FOR i := 0 TO s - 1 DO 
				FOR j := 0 TO sr - 1 DO result[i, j] := b[i, j];  END;  
				FOR j := 0 TO s - 1 DO temp[i, j] := a[i, j];  END;  
			END;  
			
			(* Out.String( "result after the first loop" );  Out.Ln;  Dump( result );  *)
			
			(*Triangulation of the matrix*)
			FOR i := 0 TO s - 2 DO 
				Pivot := temp[i, i];  iMax := i;  
				FOR j := i + 1 TO s - 1 DO 
					IF ABS( temp[j, i] ) > ABS( Pivot ) THEN Pivot := temp[j, i];  iMax := j;  END;  
				END;  
				
				(*Modification 10-12-04*)
				(*	IF Pivot = 0 THEN  (* noninvertible *)
						RETURN;  				END;  *)
				IF ABS( Pivot ) > epsilon THEN 
					IF iMax # i THEN  (*Exchange of lines i and iMax*)
						FOR k := i TO s - 1 DO tmp := temp[i, k];  temp[i, k] := temp[iMax, k];  temp[iMax, k] := tmp;  END;  
						FOR k := 0 TO sr - 1 DO tmp := result[i, k];  result[i, k] := result[iMax, k];  result[iMax, k] := tmp;  END;  
					END;  
					
					(*Substraction of the rows*)
					FOR l := i + 1 TO s - 1 DO 
						tmp := temp[l, i] / temp[i, i];  
						FOR k := i TO s - 1 DO tmp2 := temp[i, k] * tmp;  temp[l, k] := temp[l, k] - tmp2;  END;  
						FOR k := 0 TO sr - 1 DO tmp2 := result[i, k] * tmp;  result[l, k] := result[l, k] - tmp2;  END;  
					END;  
					
					(*Rajout*)
				ELSE 
					FOR k := 0 TO s - 1 DO temp[k, i] := 0.0;  temp[i, k] := 0.0;  END;  
					FOR k := 0 TO sr - 1 DO result[i, k] := 0.0;  END;  
				END;  
				(*fin du rajout*)
			END;  
			
			(* Out.String( "result after the second loop" );  Out.Ln;  Dump( result );  *)
			
			IF ABS( temp[s - 1, s - 1] ) < epsilon THEN  (* non-invertible *)
				FOR k := 0 TO s - 1 DO temp[s - 1, i] := 0.0;  temp[i, s - 1] := 0.0;  END;  
				FOR k := 0 TO sr - 1 DO result[s - 1, k] := 0.0;  END;  
				(*RETURN;  *)
			END;  
			
			(* Out.String( "result after the third loop" );  Out.Ln;  Dump( result );  *)
			
			(*Substractions of the upper rows*)
			FOR k := 1 TO s - 1 DO 
				FOR i := 0 TO k - 1 DO 
					IF ABS( temp[k, k] ) > epsilon THEN 
						tmp := temp[i, k] / temp[k, k];  
						FOR l := k TO s - 1 DO tmp2 := tmp * temp[k, l];  temp[i, l] := temp[i, l] - tmp2;  END;  
						FOR l := 0 TO sr - 1 DO tmp2 := tmp * result[k, l];  result[i, l] := result[i, l] - tmp2;  END;  
					END;  
				END;  
			END;  
			
			(* Out.String( "result after the fourth loop" );  Out.Ln;  Dump( result );  *)
			
			(*Divides each line by the diagonal component*)
			FOR i := 0 TO s - 1 DO 
				IF ABS( temp[i, i] ) > epsilon THEN 
					FOR j := 0 TO sr - 1 DO result[i, j] := result[i, j] / temp[i, i];  END;  
				END;  
			END;  
			(*Out.String( "result after the fifth loop" );  Out.Ln;  Dump( result );  *)

			RETURN;  
		END DoSolveLinearSize;  
	
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
		PROCEDURE DoSolveLinear( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64;  VAR temp: ARRAY OF ARRAY OF FLOAT64 );  
		VAR i, j, k, l, iMax: SIZE;  Pivot, tmp, tmp2: FLOAT64;  
		CONST size = SIZEOF( FLOAT64 );  
		BEGIN 
			SYSTEM.MOVE( SYSTEM.ADR( b[0, 0] ), SYSTEM.ADR( result[0, 0] ), LEN( b ) * LEN( b[0] ) * size );   (* fast copy of matrix b to result, does NOT work if sizes differ! *)
			SYSTEM.MOVE( SYSTEM.ADR( a[0, 0] ), SYSTEM.ADR( temp[0, 0] ), LEN( a ) * LEN( a[0] ) * size );   (* fast copy of matrix a to temp, does NOT work if sizes differ! *)
			
			(*Triangulation of the matrix*)
			FOR i := 0 TO LEN( temp ) - 2 DO 
				Pivot := temp[i, i];  iMax := i;  
				FOR j := i + 1 TO LEN( temp ) - 1 DO 
					IF ABS( temp[j, i] ) > ABS( Pivot ) THEN Pivot := temp[j, i];  iMax := j;  END;  
				END;  
				IF Pivot = 0 THEN  (* noninvertible *)
					RETURN;  
				END;  
				
				IF iMax # i THEN  (*Exchange of lines i and iMax*)
					FOR k := i TO LEN( temp[0] ) - 1 DO tmp := temp[i, k];  temp[i, k] := temp[iMax, k];  temp[iMax, k] := tmp;  END;  
					FOR k := 0 TO LEN( result[0] ) - 1 DO tmp := result[i, k];  result[i, k] := result[iMax, k];  result[iMax, k] := tmp;  END;  
				END;  
				
				(*Substraction of the rows*)
				FOR l := i + 1 TO LEN( temp ) - 1 DO 
					tmp := temp[l, i] / temp[i, i];  
					FOR k := i TO LEN( temp[0] ) - 1 DO tmp2 := temp[i, k] * tmp;  temp[l, k] := temp[l, k] - tmp2;  END;  
					FOR k := 0 TO LEN( result[0] ) - 1 DO tmp2 := result[i, k] * tmp;  result[l, k] := result[l, k] - tmp2;  END;  
					(*
						 here one would typically want to write EXCHNG(result[i],temp[l]) or result[l] := result[l]-tmp * result[i];  
					*) 
					
				END;  
			END;  
			
			IF temp[LEN( temp ) - 1, LEN( temp[0] ) - 1] = 0 THEN  (* noninvertible *)
				RETURN;  
			END;  
			
			(*Substractions of the upper rows*)
			FOR k := 1 TO LEN( temp[0] ) - 1 DO 
				FOR i := 0 TO k - 1 DO 
					tmp := temp[i, k] / temp[k, k];  
					IF temp[k, k] = 0 THEN Out.String( "Warning modifié : " );  Dump( a );  Out.Int( SIGNED32(k), 6 );  Out.LongRealFix( temp[k, k], 8, 8 );  Out.Ln;  END;  
					FOR l := k TO LEN( temp[0] ) - 1 DO tmp2 := tmp * temp[k, l];  temp[i, l] := temp[i, l] - tmp2;  END;  
					FOR l := 0 TO LEN( result[0] ) - 1 DO tmp2 := tmp * result[k, l];  result[i, l] := result[i, l] - tmp2;  END;  
				
				END;  
			END;  
			
			(*Divides each line by the diagonal component*)
			FOR i := 0 TO LEN( result ) - 1 DO 
				FOR j := 0 TO LEN( result[0] ) - 1 DO result[i, j] := result[i, j] / temp[i, i];  END;  
			END;  
			
			RETURN  (*result*) ;  
		END DoSolveLinear;  
	
	(* Multiply  two matrices : prod= a*b*)
		PROCEDURE DoMultSize( VAR a, b, prod: ARRAY OF ARRAY OF FLOAT64;  size: SIZE );  
		VAR i, j, k: SIZE;  tmp: FLOAT64;  
		BEGIN 
			
			FOR i := 0 TO LEN( a ) - 1 DO 
				FOR j := 0 TO LEN( b[0] ) - 1 DO 
					prod[i, j] := 0;  
					FOR k := 0 TO size - 1 DO tmp := a[i, k] * b[k, j];  prod[i, j] := prod[i, j] + tmp;  END;  
				END;  
			END;  
		
		END DoMultSize;  

	END GenericEq;  
	
	VAR 
	global*: GenericEq;   (** for use by modules not needing concurrency, deprecated*)

	(*  matrix to In : identity square matrix *)
	PROCEDURE Identity( VAR a: ARRAY OF ARRAY OF FLOAT64 );  
	VAR i, j: SIZE;  
	BEGIN 
		FOR i := 0 TO LEN( a ) - 1 DO 
			FOR j := 0 TO LEN( a[0] ) - 1 DO a[i, j] := 0.0;  END;  
			a[i, i] := 1.0;  
		END;  
	
	END Identity;  

(* Multipliy  two matrices : prod= a*b*)
	PROCEDURE DoMult( VAR a, b, prod: ARRAY OF ARRAY OF FLOAT64 );  
	VAR i, j, k: SIZE;  tmp: FLOAT64;  
	BEGIN 
		
		FOR i := 0 TO LEN( a ) - 1 DO 
			FOR j := 0 TO LEN( b[0] ) - 1 DO 
				prod[i, j] := 0;  
				FOR k := 0 TO LEN( b ) - 1 DO tmp := a[i, k] * b[k, j];  prod[i, j] := prod[i, j] + tmp;  END;  
			END;  
		END;  
	
	END DoMult;  

(*Dumps the matrix on the standard output*)
	PROCEDURE Dump( VAR a: ARRAY OF ARRAY OF FLOAT64 );  
	VAR i, j: SIZE;  
	BEGIN 
		FOR i := 0 TO LEN( a ) - 1 DO 
			FOR j := 0 TO LEN( a[0] ) - 1 DO Out.LongRealFix( a[i, j], 6, 6 );  END;  
			Out.Ln;  
		END;  
	END Dump;  

BEGIN 
	Identity( id );  NEW( global );  
END wedgeGenericEq.

