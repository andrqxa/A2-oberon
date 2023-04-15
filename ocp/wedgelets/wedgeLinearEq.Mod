MODULE wedgeLinearEq IN Oberon;   (**  AUTHOR "ld"; PURPOSE "";  **)

IMPORT Out, SYSTEM;  

TYPE 
	matrix3d = ARRAY 3 OF ARRAY 3 OF FLOAT64;  
	vector3d = ARRAY 3 OF ARRAY 1 OF FLOAT64;  
	matrix2d = ARRAY 2 OF ARRAY 2 OF FLOAT64;  
	vector2d = ARRAY 2 OF ARRAY 1 OF FLOAT64;  

VAR 
	id3: matrix3d;  id2: matrix2d; 	
TYPE 
	LinearEq* = OBJECT 
	VAR  (**)
		(* temporary variables used ine LinearRegression *)
		txx3, txx3inv: matrix3d;  
		txz3: vector3d;  
		(* temporary variables used ine LinearRegression1d *)
		txx2inv, txx2: matrix2d;  
		txz2: vector2d;  
		(* temporary variable used in SolveLinear  *)
		temp: POINTER TO ARRAY OF ARRAY OF FLOAT64;  
		(* temporary variable used in SolveLinear2 *)
		m2: matrix2d;  
		(* temporary variable used in SolveLinear3 *)
		m3: matrix3d;
		
		result3*: vector3d;   (* for use by outer procedures to prevent from repeated allocation *)
		result2*: vector2d;   (* for use by outer procedures to prevent from repeated allocation *)
		
		(*Computes regression parameters from an xyz data matrix*)
		PROCEDURE ComputeRegressionParameters*( VAR a: ARRAY OF ARRAY OF FLOAT64;  VAR X, Y, Z, XY, XZ, YZ, X2, Y2, Z2, N: FLOAT64 );  
		VAR i: SIGNED32;  
		BEGIN 
			ASSERT ( LEN( a[0] ) = 3, 1001 );  
			(*Warning number of columns msut be 3*)
			X := 0.0;  Y := 0.0;  Z := 0.0;  XY := 0.0;  XZ := 0.0;  YZ := 0.0;  X2 := 0.0;  Y2 := 0.0;  Z2 := 0.0;  N := LEN( a );  
			
			FOR i := 0 TO LEN( a ) - 1 DO 
				X := X + a[i, 0];  Y := Y + a[i, 1];  Z := Z + a[i, 2];  XY := XY + a[i, 0] * a[i, 1];  XZ := XZ + a[i, 0] * a[i, 2];  
				YZ := YZ + a[i, 1] * a[i, 2];  X2 := X2 + a[i, 0] * a[i, 0];  Y2 := Y2 + a[i, 1] * a[i, 1];  Z2 := Z2 + a[i, 2] * a[i, 2];  
			END;  
		
		END ComputeRegressionParameters;  
	
	(*Computes bidimensional linear regression with X=Sxi, Y=Syi, XY = Sxi*yi... *)
		PROCEDURE LinearRegression*( VAR abc: ARRAY OF ARRAY OF FLOAT64;  X, Y, Z, XY, XZ, YZ, X2, Y2, Z2, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, a, b, c: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( abc ) = 3, 1001 );  
			(*ASSERT ( LEN( abc[0] ) = 3, 1002 );  *)
			
			(*Filling system matrix*)
			txx3[0, 0] := X2;  txx3[0, 1] := XY;  txx3[0, 2] := X;  txx3[1, 0] := XY;  txx3[1, 1] := Y2;  txx3[1, 2] := Y;  
			txx3[2, 0] := X;  txx3[2, 1] := Y;  txx3[2, 2] := N;  
			
			(*Filling right member of the system*)
			txz3[0, 0] := XZ;  txz3[1, 0] := YZ;  txz3[2, 0] := Z;  
			
			(*New method*)
			(*SolveLinear3(txx3,txz3,abc);*)
			
			(*Inversion  of tXX*)
			SolveLinear3( txx3, id3, txx3inv );  
			
			(*Multiplication of tXX and tXZ*)
			DoMult( txx3inv, txz3, abc );  (*Dump( abc );*)
			
			a := abc[0, 0];  b := abc[1, 0];  c := abc[2, 0];  
			
			(*Computes quadratic error*)
			tmp1 := 0.0;  tmp1 := tmp1 + Z2;  tmp1 := tmp1 + a * a * X2;  tmp1 := tmp1 + b * b * Y2;  tmp1 := tmp1 + c * c * N;  
			tmp1 := tmp1 + 2.0 * a * b * XY;  tmp1 := tmp1 + 2.0 * a * c * X;  tmp1 := tmp1 + 2.0 * b * c * Y;  
			tmp1 := tmp1 - 2.0 * a * XZ;  tmp1 := tmp1 - 2.0 * b * YZ;  tmp1 := tmp1 - 2.0 * c * Z;  

			RETURN tmp1;  
		END LinearRegression;  
	
	(*Computes bidimensional linear regression for the one-dimensional case*)
		PROCEDURE LinearRegression1D*( VAR ab: ARRAY OF ARRAY OF FLOAT64;  X, Z, XZ, X2, Z2, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, a, c: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( ab ) = 2, 1001 );  
			(* ASSERT ( LEN( ab[0] ) = 2, 1002 );  *)
			txx2[0, 0] := X2;  txx2[0, 1] := X;  txx2[1, 0] := X;  txx2[1, 1] := N;  

			txz2[0, 0] := XZ;  txz2[1, 0] := Z;  
			
			(*Inversion  of tXX*)
			SolveLinear2( txx2, id2, txx2inv );  
			
			
			(*Multiplication of tXX and tXZ*)
			DoMult( txx2inv, txz2, ab );  a := ab[0, 0];  c := ab[1, 0];  
			
			(*Computes quadratic error*)
			tmp1 := 0.0;  tmp1 := tmp1 + Z2;  tmp1 := tmp1 + a * a * X2;  tmp1 := tmp1 + c * c * N;  
			tmp1 := tmp1 + 2.0 * a * c * X;  tmp1 := tmp1 - 2.0 * a * XZ;  tmp1 := tmp1 - 2.0 * c * Z;  

			RETURN tmp1;  
		END LinearRegression1D;  
	
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
		PROCEDURE DoSolveLinear( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64;  VAR temp: ARRAY OF ARRAY OF FLOAT64 );  
		VAR i, j, k, l, iMax: SIGNED32;  Pivot, tmp, tmp2: FLOAT64;  
		CONST size = SIZEOF( FLOAT64 );  
		BEGIN 
			SYSTEM.MOVE( SYSTEM.ADR( b[0, 0] ), SYSTEM.ADR( result[0, 0] ), LEN( b ) * LEN( b[0] ) * size );   (* fast copy of matrix b to result, does 
			NOT work if sizes differ! *)
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
				END;  
				
			END;  
			
			IF temp[LEN( temp ) - 1, LEN( temp[0] ) - 1] = 0 THEN  (* nonivnertible *)
				RETURN;  
			END;  
			
			(*Out.String("result,0"); Out.Ln; Dump(result);*)
			
			(*Substractions of the upper rows*)
			FOR k := 1 TO LEN( temp[0] ) - 1 DO 
				FOR i := 0 TO k - 1 DO 
					tmp := temp[i, k] / temp[k, k];  
					IF temp[k, k] = 0 THEN Out.String( "Warning modifié : " );  Dump( a );  Out.Int( k, 6 );  Out.LongRealFix( temp[k, k], 8, 8 );  Out.Ln;  END;  
					FOR l := k TO LEN( temp[0] ) - 1 DO tmp2 := tmp * temp[k, l];  temp[i, l] := temp[i, l] - tmp2;  END;  
					FOR l := 0 TO LEN( result[0] ) - 1 DO tmp2 := tmp * result[k, l];  result[i, l] := result[i, l] - tmp2;  END;  
				
				END;  
			END;  


			(* Out.String("result,1"); Out.Ln; Dump(result);*)
						
			(*Divides each line by the diagonal component*)
			FOR i := 0 TO LEN( result ) - 1 DO 
				FOR j := 0 TO LEN( result[0] ) - 1 DO result[i, j] := result[i, j] / temp[i, i];  END;  
			END;  
			
			(*  Out.String("result,2"); Out.Ln; Dump(result); *)
			
			RETURN  (*result*) ;  
		END DoSolveLinear;  

		PROCEDURE SolveLinear*( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve linear equation with arbitrary dimension*)
		BEGIN 
			IF (temp = NIL ) OR (LEN( temp ) # LEN( a )) OR (LEN( temp[0] ) # LEN( a[0] )) THEN NEW( temp, LEN( a ), LEN( a[0] ) );  END;  
			DoSolveLinear( a, b, result, temp^ );  
		END SolveLinear;  

		PROCEDURE SolveLinear2( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve linear equation with  dim=2 avoiding to allocate anything new*)
		BEGIN 
			DoSolveLinear( a, b, result, m2 );  
		END SolveLinear2;  

		PROCEDURE SolveLinear3( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve linear equation with  dim=3 avoiding to allocate anything new*)
		BEGIN 
			DoSolveLinear( a, b, result, m3 );  
		END SolveLinear3;  

	END LinearEq;  
	
	VAR 
	 global*: LinearEq;   (** for use by modules not needing concurrency, deprecated*)

	(*  matrix to In identity square matrix *)
	PROCEDURE Identity( VAR a: ARRAY OF ARRAY OF FLOAT64 );  
	VAR i, j: SIGNED32;  
	BEGIN 
		FOR i := 0 TO LEN( a ) - 1 DO 
			FOR j := 0 TO LEN( a[0] ) - 1 DO a[i, j] := 0.0;  END;  
			a[i, i] := 1.0;  
		END;  
	
	END Identity;  

(* Multipliy  two matrices : prod= a*b*)
	PROCEDURE DoMult( VAR a, b, prod: ARRAY OF ARRAY OF FLOAT64 );  
	VAR i, j, k: SIGNED32;  tmp: FLOAT64;  
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
	VAR i, j: SIGNED32;  
	BEGIN 
		FOR i := 0 TO LEN( a ) - 1 DO 
			FOR j := 0 TO LEN( a[0] ) - 1 DO Out.LongRealFix( a[i, j], 6, 6 );  END;  
			Out.Ln;  
		END;  
	END Dump;  

BEGIN 
	Identity( id2 );  Identity( id3 );  NEW( global );  
END wedgeLinearEq.

