MODULE wedgeQuadraticEq IN Oberon;   (**  AUTHOR "ld"; PURPOSE "";  **)

IMPORT Out, SYSTEM, aM := antsMessages;  

TYPE 
	matrix6d = ARRAY 6 OF ARRAY 6 OF FLOAT64;  
	vector6d = ARRAY 6 OF ARRAY 1 OF FLOAT64;  
	matrix3d = ARRAY 3 OF ARRAY 3 OF FLOAT64;  
	vector3d = ARRAY 3 OF ARRAY 1 OF FLOAT64;  
	matrix2d = ARRAY 2 OF ARRAY 2 OF FLOAT64;  
	vector2d = ARRAY 2 OF ARRAY 1 OF FLOAT64;  
VAR 
	id3: matrix6d;  
	id2: matrix3d;  id1: matrix2d;  
TYPE 
	QuadraticEq* = OBJECT 
	VAR  (**)
		(* temporary variables used in QuadraticRegression *)
		txx3, txx3inv: matrix6d;  
		txz3: vector6d;  
		(* temporary variables used in QuadraticRegression1d &LQuadratic *)
		txx2inv, txx2: matrix3d;  
		txz2: vector3d;  
		(* temporary variables used in LQRegression1d *)
		txx1inv, txx1: matrix2d;  
		txz1: vector2d;  
		(* temporary variable used in SolveLinear  *)
		temp: POINTER TO ARRAY OF ARRAY OF FLOAT64;  
		(* temporary variable used in SolveLinear1 *)
		m1: matrix2d;  
		(* temporary variable used in SolveLinear2 *)
		m2: matrix3d;  
		(* temporary variable used in SolveLinear3 *)
		m3: matrix6d;  
		result3*: vector6d;   (* for use by outer procedures to prevent from repeated allocation *)
		result2*: vector3d;   (* for use by outer procedures to prevent from repeated allocation *)
		result1*: vector2d;   (* for use by outer procedures to prevent from repeated allocation *)
		(*Computes regression parameters from an xyz data matrix*)
		PROCEDURE ComputeRegressionParameters*( VAR a: ARRAY OF ARRAY OF FLOAT64;  
																				    VAR X, Y, Z, XY, XZ, YZ, X2, Y2, Z2, X4, Y4, X3, Y3, X3Y, XY3, X2Y2, X2Y, XY2, X2Z, Y2Z, XYZ, N: FLOAT64 );  
		VAR i: SIZE;  
		BEGIN 
			ASSERT ( LEN( a[0] ) = 6, 1001 );  
			(*Warning number of columns must be 6*)
			X := 0.0;  Y := 0.0;  Z := 0.0;  XY := 0.0;  XZ := 0.0;  YZ := 0.0;  X2 := 0.0;  Y2 := 0.0;  Z2 := 0.0;  N := LEN( a );  X4 := 0.0;  
			Y4 := 0.0;  X3 := 0.0;  Y3 := 0.0;  X3Y := 0;  XY3 := 0.0;  X2Y2 := 0.0;  X2Y := 0.0;  XY2 := 0.0;  X2Z := 0.0;  Y2Z := 0.0;  
			XYZ := 0.0;  
			
			FOR i := 0 TO LEN( a ) - 1 DO 
				X := X + a[i, 0];  Y := Y + a[i, 1];  Z := Z + a[i, 2];  XY := XY + a[i, 0] * a[i, 1];  XZ := XZ + a[i, 0] * a[i, 2];  
				YZ := YZ + a[i, 1] * a[i, 2];  X2 := X2 + a[i, 0] * a[i, 0];  Y2 := Y2 + a[i, 1] * a[i, 1];  Z2 := Z2 + a[i, 2] * a[i, 2];  
				X4 := X4 + a[i, 0] * a[i, 0] * a[i, 0] * a[i, 0];  Y4 := 0.0 + a[i, 1] * a[i, 1] * a[i, 1] * a[i, 1];  
				X3 := 0.0 + a[i, 0] * a[i, 0] * a[i, 0];  Y3 := 0.0 + a[i, 1] * a[i, 1] * a[i, 1];  
				X3Y := 0 + a[i, 0] * a[i, 0] * a[i, 0] * a[i, 1];  XY3 := 0.0 + a[i, 0] * a[i, 1] * a[i, 1] * a[i, 1];  
				X2Y2 := 0.0 + a[i, 0] * a[i, 0] * a[i, 1] * a[i, 1];  X2Y := 0.0 + a[i, 0] * a[i, 0] * a[i, 1];  
				XY2 := 0.0 + a[i, 0] * a[i, 1] * a[i, 1];  X2Z := 0.0 + a[i, 0] * a[i, 0] * a[i, 2];  Y2Z := 0.0 + a[i, 1] * a[i, 1] * a[i, 2];  
				XYZ := 0.0 + a[i, 0] * a[i, 1] * a[i, 2];  
			END;  
		
		END ComputeRegressionParameters;  
	
	(*Computes bidimensional linear regression with X=Sxi, Y=Syi, XY = Sxi*yi... *)
		PROCEDURE QuadraticRegression*( VAR abc: ARRAY OF ARRAY OF FLOAT64;  
																  X, Y, Z, XY, XZ, YZ, X2, Y2, Z2, X4, Y4, X3, Y3, X3Y, XY3, X2Y2, X2Y, XY2, X2Z, Y2Z, XYZ, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, a, b, c, d, e, ee: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( abc ) = 6, 1001 );  
			ASSERT ( LEN( abc[0] ) = 1, 1002 );  
			
			txx3[0, 0] := N;  txx3[0, 1] := Y;  txx3[0, 2] := X;  txx3[0, 3] := XY;  txx3[0, 4] := Y2;  txx3[0, 5] := X2;  
			txx3[1, 0] := Y;  txx3[1, 1] := Y2;  txx3[1, 2] := XY;  txx3[1, 3] := XY2;  txx3[1, 4] := Y3;  txx3[1, 5] := X2Y;  
			txx3[2, 0] := X;  txx3[2, 1] := XY;  txx3[2, 2] := X2;  txx3[2, 3] := X2Y;  txx3[2, 4] := XY2;  txx3[2, 5] := X3;  
			txx3[3, 0] := XY;  txx3[3, 1] := XY2;  txx3[3, 2] := X2Y;  txx3[3, 3] := X2Y2;  txx3[3, 4] := XY3;  txx3[3, 5] := X3Y;  
			txx3[4, 0] := Y2;  txx3[4, 1] := Y3;  txx3[4, 2] := XY2;  txx3[4, 3] := XY3;  txx3[4, 4] := Y4;  txx3[4, 5] := X2Y2;  
			txx3[5, 0] := X2;  txx3[5, 1] := X2Y;  txx3[5, 2] := X3;  txx3[5, 3] := X3Y;  txx3[5, 4] := X2Y2;  txx3[5, 5] := X4;  
			
			(*Out.Ln;   aM.dSR( "XYZ = ", XYZ );aM.dSRSR( "Y2Z = ", Y2Z, "X2Z = ", X2Z );*)
			
			
				txz3[0, 0] := Z;  txz3[1, 0] := YZ;  txz3[2, 0] := XZ;  txz3[3, 0] := XYZ;  txz3[4, 0] := Y2Z;  txz3[5, 0] := X2Z;  
			
			(*Solution of the linear system*)
			SolveLinear3( txx3, txz3, abc );  
			
			(*SolveLinear3( txx3, id3, txx3inv ); 					
			DoMult( txx3inv, txz3, abc );  *)

			(*Multiplication of tXX and tXZ*)
				ee := abc[0, 0];  e := abc[1, 0];  d := abc[2, 0];  b := abc[3, 0];  c := abc[4, 0];  a := abc[5, 0];  
			
			(*Computes quadratic error*)
			tmp1 := 0.0;  
			tmp1 := tmp1 + 1.0 * Z2;  
			
			tmp1 := tmp1 - 2.0 * a * X2Z; 
			tmp1 := tmp1 - 2.0 * b * XYZ;  
			tmp1 := tmp1 - 2.0 * c * Y2Z;  
			tmp1 := tmp1 - 2.0 * d * XZ;  
			tmp1 := tmp1 - 2.0 * e * YZ;  
			tmp1 := tmp1 - 2.0 * ee * Z; 
			
			tmp1 := tmp1 + 2.0 * a * d * X3;  
			tmp1 := tmp1 + 2.0 * c * e * Y3;  
			tmp1 := tmp1 + 2.0 * a * b * X3Y;  
			tmp1 := tmp1 + 2.0 * b * c * XY3;  
			tmp1 := tmp1 + 2.0 * a * c  * X2Y2;  
			tmp1 := tmp1 + (2.0 * e * a + 2.0 * d * b) * X2Y;  
			tmp1 := tmp1 + (2.0 * b * e + 2.0 * c * d) * XY2;  
			tmp1 := tmp1 + (2.0 * b * ee + 2.0 * d * e) * XY;  
			tmp1 := tmp1 + 2.0 * d * ee * X;  
			tmp1 := tmp1 + 2.0 * e * ee * Y;  
			tmp1 := tmp1 + 2.0 * a * ee  * X2;  
			tmp1 := tmp1 + 2.0 * c * ee  * Y2;

			tmp1 := tmp1 + 1.0 * a * a * X4;  
			tmp1 := tmp1 + 1.0 * c * c * Y4;  
	        tmp1 := tmp1 + 1.0 * ee * ee * N;  
			tmp1 := tmp1 + 1.0 * e * e * Y2;
			tmp1 := tmp1 + 1.0 * d * d * X2;
			tmp1 := tmp1 + 1.0 * b * b * X2Y2;
		
		    RETURN tmp1;  
		END QuadraticRegression;  
	
	(*Computes bidimensional linear regression for the one-dimensional case*)
		PROCEDURE QuadraticRegression1D*( VAR ab: ARRAY OF ARRAY OF FLOAT64;  X, Z, XZ, X2, Z2, X4, X3, X2Z, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, a, d, ee: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( ab ) = 3, 1001 );  
			ASSERT ( LEN( ab[0] ) = 1, 1002 );  
			txx2[0, 0] := N;  txx2[0, 1] := X;  txx2[0, 2] := X2;  txx2[1, 0] := X;  txx2[1, 1] := X2;  txx2[1, 2] := X3;  
			txx2[2, 0] := X2;  txx2[2, 1] := X3;  txx2[2, 2] := X4;  
			
			(*Inversion  of tXX*)
			SolveLinear2( txx2, id2, txx2inv );  

			txz2[0, 0] := Z;  txz2[1, 0] := XZ;  txz2[2, 0] := X2Z;  
			
			(*Multiplication of tXX and tXZ*)
			DoMult( txx2inv, txz2, ab );  ee := ab[0, 0];  d := ab[1, 0];  a := ab[2, 0];  
			
			(*Computes quadratic error*)
			tmp1 := 0.0;  tmp1 := tmp1 + Z2;  tmp1 := tmp1 - 2.0 * a * X2Z;  tmp1 := tmp1 - 2.0 * d * XZ;  
			tmp1 := tmp1 - 2.0 * ee * Z;  tmp1 := tmp1 + a * a * X4;  tmp1 := tmp1 + 2.0 * a * d * X3;  
			tmp1 := tmp1 + (2.0 * d * ee) * X;  tmp1 := tmp1 + (2.0 * a * ee + d * d) * X2;  tmp1 := tmp1 + ee * ee * N;  

			RETURN tmp1;  
		END QuadraticRegression1D;  

		PROCEDURE LRegression*( VAR ab: ARRAY OF ARRAY OF FLOAT64;  X, Y, Z, XY, XZ, YZ, X2, Y2, Z2, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, d, e, ee: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( ab ) = 3, 1001 );  
			ASSERT ( LEN( ab[0] ) = 1, 1002 );  
			
			txx2[0, 0] := N;  txx2[0, 1] := Y;  txx2[0, 2] := X;  txx2[1, 0] := Y;  txx2[1, 1] := Y2;  txx2[1, 2] := XY;  txx2[2, 0] := X;  
			txx2[2, 1] := XY;  txx2[2, 2] := X2;  
			
				(*Inversion  of tXX*)
			SolveLinear2( txx2, id2, txx2inv );  txz2[0, 0] := Z;  txz2[1, 0] := YZ;  txz2[2, 0] := XZ;  
			
			
			(*Multiplication of tXX and tXZ*)
			(*Out.String( "txx2inv" );  Dump( txx2inv );*)
			DoMult( txx2inv, txz2, ab );  
			ee := ab[0, 0];  e := ab[1, 0];  d := ab[2, 0];   (*b := 0.0; c:=0.0; e:=0.0;*)
			(*Out.String( "txz2" );  Dump( txz2 ); Out.String( "ab" );  Dump( ab );*)
			
			(*Computes quadratic error*)
			
			tmp1 := 0.0;  tmp1 := tmp1 + Z2;  tmp1 := tmp1 + d * d * X2;  tmp1 := tmp1 + e * e * Y2;  
			tmp1 := tmp1 + ee * ee * N;  tmp1 := tmp1 + 2.0 * d * e * XY;  tmp1 := tmp1 + 2.0 * d * ee * X;  
			tmp1 := tmp1 + 2.0 * e * ee * Y;  tmp1 := tmp1 - 2.0 * d * XZ;  tmp1 := tmp1 - 2.0 * e * YZ;  
			tmp1 := tmp1 - 2.0 * ee * Z;  RETURN tmp1;  
		END LRegression;  

		PROCEDURE LRegression1D*( VAR ab1: ARRAY OF ARRAY OF FLOAT64;  X, Z, XZ, X2, Z2, N: FLOAT64 ): FLOAT64;  
		VAR tmp1, d, ee: FLOAT64;  
		BEGIN 
			ASSERT ( LEN( ab1 ) = 2, 1001 );  
			ASSERT ( LEN( ab1[0] ) = 1, 1002 );  
			txx1[0, 0] := N;  txx1[0, 1] := X;  txx1[1, 0] := X;  txx1[1, 1] := X2;  
			
			(*Inversion  of tXX*)
			SolveLinear1( txx1, id1, txx1inv );  txz1[0, 0] := Z;  txz1[1, 0] := XZ;  
			(*Multiplication of tXX and tXZ*)
			DoMult( txx1inv, txz1, ab1 );  d := ab1[0, 0];  ee := ab1[1, 0];  
			
			(*Computes quadratic error*)
			tmp1 := 0.0;  tmp1 := tmp1 + Z2;  tmp1 := tmp1 + d * d * X2;  tmp1 := tmp1 + ee * ee * N;  
			tmp1 := tmp1 + 2.0 * d * ee * X;  tmp1 := tmp1 - 2.0 * d * XZ;  tmp1 := tmp1 - 2.0 * ee * Z;  

			RETURN tmp1;  
		END LRegression1D;  
	
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
	(*Resolution of a simple linear system with a simple Gaussian pivot, solve a*result = b *)
		PROCEDURE DoSolveLinear( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64;  VAR temp: ARRAY OF ARRAY OF FLOAT64 );  
		VAR i, j, k, l, iMax: SIZE;  Pivot, tmp, tmp2: FLOAT64;  
		CONST size = SIZEOF( FLOAT64 );  epsilon = 0.0000001;  
		BEGIN 
			SYSTEM.MOVE( SYSTEM.ADR( b[0, 0] ), SYSTEM.ADR( result[0, 0] ), LEN( b ) * LEN( b[0] ) * size );   (* fast copy of matrix b to result, does NOT work if sizes differ! *)
			SYSTEM.MOVE( SYSTEM.ADR( a[0, 0] ), SYSTEM.ADR( temp[0, 0] ), LEN( a ) * LEN( a[0] ) * size );   (* fast copy of matrix a to temp, does NOT work if sizes differ! *)

			(*Triangulation of the matrix*)
			FOR i := 0 TO LEN( temp ) - 2 DO 
				Pivot := temp[i, i];  iMax := i;  
				FOR j := i + 1 TO LEN( temp ) - 1 DO 
					IF ABS( temp[j, i] ) > ABS( Pivot ) THEN Pivot := temp[j, i];  iMax := j;  END;  
				END;  
				
				IF ABS( Pivot ) > epsilon THEN 
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
				
				ELSE  (*non invertible: set the corresponding indices values to zero*)
					FOR k := 0 TO LEN( temp ) - 1 DO temp[k, i] := 0.0;  temp[i, k] := 0.0;  END;  
					FOR k := 0 TO LEN( result[0] ) - 1 DO result[i, k] := 0.0;  END;  
				END;  
			END;  
			
	
			IF ABS( temp[LEN( temp ) - 1, LEN( temp[0] ) - 1] ) < epsilon THEN  (* noninvertible *)
				FOR k := 0 TO LEN( temp ) - 1 DO temp[LEN( temp ) - 1, i] := 0.0;  temp[i, LEN( temp ) - 1] := 0.0;  END;  
				FOR k := 0 TO LEN( result[0] ) - 1 DO result[LEN( temp ) - 1, k] := 0.0;  END;  
			END;  
				
			(*Substractions of the upper rows*)
			FOR k := 1 TO LEN( temp[0] ) - 1 DO 
				FOR i := 0 TO k - 1 DO 
					IF ABS( temp[k, k] ) > epsilon THEN 
						tmp := temp[i, k] / temp[k, k];  
						FOR l := k TO LEN( temp[0] ) - 1 DO tmp2 := tmp * temp[k, l];  temp[i, l] := temp[i, l] - tmp2;  END;  
						FOR l := 0 TO LEN( result[0] ) - 1 DO tmp2 := tmp * result[k, l];  result[i, l] := result[i, l] - tmp2;  END;  
					END;  
				END;  
			END;  
		
			(*Divides each line by the diagonal component*)
			FOR i := 0 TO LEN( result ) - 1 DO 
				IF ABS( temp[i, i] ) > epsilon THEN 
					FOR j := 0 TO LEN( result[0] ) - 1 DO result[i, j] := result[i, j] / temp[i, i];  END;  
				END;  
			END;  
		
			RETURN  (*result*) ;  
		END DoSolveLinear;  


		PROCEDURE SolveLinear*( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );  
		(* solve linear equation with arbitrary dimension*)
		BEGIN 
			IF (temp = NIL ) OR (LEN( temp ) # LEN( a )) OR (LEN( temp[0] ) # LEN( a[0] )) THEN NEW( temp, LEN( a ), LEN( a[0] ) );  END;  
			DoSolveLinear( a, b, result, temp^ );  
		END SolveLinear;  

		PROCEDURE SolveLinear1( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve Quadratic equation with  dim=2 avoiding to allocate anything new*)
		BEGIN 
			DoSolveLinear( a, b, result, m1 );  
		END SolveLinear1;  

		PROCEDURE SolveLinear2( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve Quadratic equation with  dim=3 avoiding to allocate anything new*)
		BEGIN 
			DoSolveLinear( a, b, result, m2 );  
		END SolveLinear2;  

		PROCEDURE SolveLinear3( VAR a, b, result: ARRAY OF ARRAY OF FLOAT64 );   (* solve Quadratic equation with  dim=6 avoiding to allocate anything new*)
		BEGIN 
			DoSolveLinear( a, b, result, m3 );  
		END SolveLinear3;  

	END QuadraticEq;  
	VAR 
	global*: QuadraticEq;   (** for use by modules not needing concurrency, deprecated*)
	
	(*  matrix to In identity square matrix *)
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
	Identity( id2 );  Identity( id3 );  NEW( global );  
END wedgeQuadraticEq.

