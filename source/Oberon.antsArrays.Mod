MODULE antsArrays IN Oberon; 	(** fof  **)
(* Copyright notice:

This file is part of AntsInFields
Copyright (C) 1997-2002, Felix Friedrich

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
Report any problems as soon as possible to ants@AntsInFields.de
*)


IMPORT vyLongreal, vyLongrealVec, vyInteger, vyIntVec, vyLongint, vyLongintVec, Out, vyRanBase, aM := antsMessages;


TYPE
	I1d* = POINTER TO ARRAY OF SIGNED16;
	R1d* = POINTER TO ARRAY OF FLOAT32;
	X1d* = POINTER TO ARRAY OF FLOAT64;
	L1d* = POINTER TO ARRAY OF SIGNED32;

	I2d* = POINTER TO ARRAY OF ARRAY OF SIGNED16;
	R2d* = POINTER TO ARRAY OF ARRAY OF FLOAT32;
	X2d* = POINTER TO ARRAY OF ARRAY OF FLOAT64;
	L2d* = POINTER TO ARRAY OF ARRAY OF SIGNED32;

	I3d* = POINTER TO ARRAY OF I2d;
	R3d* = POINTER TO ARRAY OF R2d;
	X3d* = POINTER TO ARRAY OF X2d;
	L3d* = POINTER TO ARRAY OF L2d;

	I4d* = POINTER TO ARRAY OF I3d;
	R4d* = POINTER TO ARRAY OF R3d;
	X4d* = POINTER TO ARRAY OF X3d;
	L4d* = POINTER TO ARRAY OF L3d;

	(* greater dimensions should not be handled like that, treat the general case ? *)

VAR
	ra*: X1d;
	la*: L1d;
	ia*: I1d;

PROCEDURE kSmallestX* (VAR a: ARRAY OF FLOAT64;   n, k: SIZE): FLOAT64;
	(** caution: modifies a*)
	(* algorithm of Nikolaus Wirth *)
	VAR i, j, l, m: SIZE;    x: FLOAT64;
PROCEDURE swap (VAR x, y: FLOAT64);
	VAR z : FLOAT64;
BEGIN
	z := x;   x := y;   y := z
END swap;
BEGIN
	l := 0;   m := n - 1;
	WHILE(l < m) DO
		x := a[k];
		i := l;   j := m;
		REPEAT
			WHILE(a[i] < x)  DO INC(i) END;
			WHILE(x < a[j])  DO DEC(j) END;
			IF i <= j THEN swap(a[i], a[j]);   INC(i);   DEC(j) END
		UNTIL i > j;
		IF j < k THEN l := i END;
		IF k < i THEN m := j END
	END;
	RETURN a[k]
END kSmallestX;

PROCEDURE kSmallestL* (VAR a: ARRAY OF SIGNED32;   n, k: SIZE): SIGNED32;
	(** caution: modifies a*)
	(* algorithm of Nikolaus Wirth *)
	VAR i, j, l, m: SIZE;    x: SIGNED32;
PROCEDURE swap (VAR x, y: SIGNED32);
	VAR z : SIGNED32;
BEGIN
	z := x;   x := y;   y := z
END swap;
BEGIN
	l := 0;   m := n - 1;
	WHILE(l < m) DO
		x := a[k];
		i := l;   j := m;
		REPEAT
			WHILE(a[i] < x)  DO INC(i) END;
			WHILE(x < a[j])  DO DEC(j) END;
			IF i <= j THEN swap(a[i], a[j]);   INC(i);   DEC(j) END
		UNTIL i > j;
		IF j < k THEN l := i END;
		IF k < i THEN m := j END
	END;
	RETURN a[k]
END kSmallestL;

PROCEDURE kSmallestI* (VAR a: ARRAY OF SIGNED16;   n, k: SIZE): SIGNED16;
	(** caution: modifies a*)
	(* algorithm of Nikolaus Wirth *)
	VAR i, j, l, m: SIZE;    x: SIGNED16;
PROCEDURE swap (VAR x, y: SIGNED16);
	VAR z : SIGNED16;
BEGIN
	z := x;   x := y;   y := z
END swap;
BEGIN
	l := 0;   m := n - 1;
	WHILE(l < m) DO
		x := a[k];
		i := l;   j := m;
		REPEAT
			WHILE(a[i] < x)  DO INC(i) END;
			WHILE(x < a[j])  DO DEC(j) END;
			IF i <= j THEN swap(a[i], a[j]);   INC(i);   DEC(j) END
		UNTIL i > j;
		IF j < k THEN l := i END;
		IF k < i THEN m := j END
	END;
	RETURN a[k]
END kSmallestI;

PROCEDURE Use1dX (VAR a: ARRAY OF FLOAT64;  n: SIZE);
BEGIN
	IF (ra = NIL) OR (LEN(ra) < n) THEN NEW(ra, n) END;
	vyLongreal.Copy(n, a, 0, ra^, 0)
END Use1dX;

PROCEDURE Use1dI (VAR a: ARRAY OF SIGNED16;  n: SIZE);
BEGIN
	IF (ia = NIL) OR (LEN(ia) < n) THEN NEW(ia, n) END;
	vyInteger.Copy(n, a, 0, ia^, 0)
END Use1dI;

PROCEDURE Use1dL (VAR a: ARRAY OF SIGNED32;  n: SIZE);
BEGIN
	IF (la = NIL) OR (LEN(la) < n) THEN NEW(la, n) END;
	vyLongint.Copy(n, a, 0, la^, 0)
END Use1dL;

PROCEDURE Median1dX* (VAR a: ARRAY OF FLOAT64;   n: SIZE): FLOAT64;
BEGIN
	Use1dX(a, n);
	IF ODD(n) THEN
		RETURN kSmallestX(ra^, n, n DIV 2)
	ELSE
		RETURN (kSmallestX(ra^, n, n DIV 2 - 1) + kSmallestX(ra^, n, n DIV 2)) / 2
	END
END Median1dX;

PROCEDURE Median1dL* (VAR a: ARRAY OF SIGNED32;   n: SIZE): SIGNED32;
BEGIN
	Use1dL(a, n);
	IF ODD(n) THEN
		RETURN kSmallestL(la^, n, n DIV 2)
	ELSE
		RETURN (kSmallestL(la^, n, n DIV 2 - 1) + kSmallestL(la^, n, n DIV 2)) DIV 2
	END
END Median1dL;

PROCEDURE Median1dI* (VAR a: ARRAY OF SIGNED16;   n: SIZE): SIGNED16;
BEGIN
	Use1dI(a, n);
	IF ODD(n) THEN
		RETURN kSmallestI(ia^, n, n DIV 2)
	ELSE
		RETURN (kSmallestI(ia^, n, n DIV 2 - 1) + kSmallestI(ia^, n, n DIV 2)) DIV 2
	END
END Median1dI;

PROCEDURE Median2dX* (VAR S: ARRAY OF ARRAY OF FLOAT64): FLOAT64;
	(** does not modify S*)
	VAR values: POINTER TO ARRAY OF FLOAT64;    w, h, i: SIZE;
BEGIN
	h := LEN(S);           w := LEN(S[0]);
	NEW(values, w * h);
	FOR i := 0 TO h - 1 DO
		vyLongreal.Copy(w, S[i], 0, values^, i * w)
	END;
	RETURN kSmallestX(values^, w * h, w * h DIV 2)
END Median2dX;

PROCEDURE MinMax2dX* (VAR S: ARRAY OF ARRAY OF FLOAT64;    VAR min, max: FLOAT64);
	VAR h, i, minpos, currentminpos, maxpos, currentmaxpos, na: SIZE;       currentmax, currentmin: FLOAT64;
BEGIN
	h := LEN(S);
	min := MAX(FLOAT64);      	max := MIN(FLOAT64);
	FOR i := 0 TO h - 1 DO
		vyLongreal.MinMax(LEN(S[i]), S[i], 0, currentmin, currentminpos, currentmax, currentmaxpos, na);
		IF currentmin < min THEN  min := currentmin;               minpos := currentminpos END;
		IF currentmax > max THEN max := currentmax;    		 maxpos := currentmaxpos  END
	END
END MinMax2dX;

PROCEDURE Out2dX* (A: ARRAY OF ARRAY OF FLOAT64);
	VAR i, j: SIZE;
BEGIN
	FOR i := 0 TO LEN(A) - 1 DO
		Out.Ln;
		FOR j := 0 TO LEN(A[0]) - 1 DO
			Out.LongReal(A[i, j], 20)
		END
	END;
	Out.Ln
END Out2dX;

PROCEDURE Transpose2dX* (VAR A: ARRAY OF ARRAY OF FLOAT64): X2d;
	VAR h, w, i, j: SIZE;        Atr: X2d;
BEGIN
	h := LEN(A);             	w := LEN(A[0]);
	NEW(Atr, w, h);
	FOR i := 0 TO h - 1 DO
		FOR j := 0 TO w - 1 DO
			Atr[j, i]  := A[i, j]
		END
	END;
	RETURN Atr;
END Transpose2dX;

PROCEDURE Uniform1dX* (VAR a: ARRAY OF FLOAT64;  x, w: SIZE;  top: FLOAT64);
	VAR  xx: SIZE;
BEGIN
	vyRanBase.RandomUVX(SIGNED32(w), a, SIGNED32(x));
	IF top # 1 THEN
		FOR xx := x TO x + w - 1 DO
			a[xx] := a[xx] * top
		END
	END
END Uniform1dX;

PROCEDURE Uniform1dL* (VAR a: ARRAY OF SIGNED32;  x, w: SIZE;  top: SIGNED32);
BEGIN
	vyRanBase.RandomLV(top, TRUE, SIGNED32(LEN(a)), a, 0);
	(*antsRandom.gen.GetRandomLV(antsRandom.gen,top,LEN(a),a,0); *)
END Uniform1dL;

PROCEDURE Uniform1dI* (VAR a: ARRAY OF SIGNED16;  x, w: SIZE;  top: SIGNED16);
	VAR xx: SIZE;
BEGIN
	IF (la = NIL) OR (LEN(la^) # w) THEN NEW(la, w) END;
	Uniform1dL(la^, 0, w, top);
	FOR xx := 0 TO w - 1 DO
		a[xx + x] := SHORT(la[xx])
	END
END Uniform1dI;

PROCEDURE Uniform2dI* (VAR A: ARRAY OF ARRAY OF SIGNED16 ;  top: SIGNED16;  x, y, w, h: SIZE);
	VAR  y0: SIZE ;
BEGIN
	FOR y0 := y TO y + h - 1 DO
		Uniform1dI(A[y0], x, w, top)
	END
END Uniform2dI;

PROCEDURE Uniform2dL* (VAR A: ARRAY OF ARRAY OF SIGNED32;  top: SIGNED32;  x, y, w, h: SIZE);
	VAR  y0: SIZE ;
BEGIN
	FOR y0 := y TO y + h - 1 DO
		Uniform1dL(A[y0], x, w, top)
	END
END Uniform2dL;

PROCEDURE Uniform2dX* (VAR A: ARRAY OF ARRAY OF FLOAT64;  top: FLOAT64;  x, y, w, h: SIZE);
	VAR  y0: SIZE ;
BEGIN
	FOR y0 := y TO y + h - 1 DO
		Uniform1dX(A[y0], x, w, top)
	END
END Uniform2dX;

PROCEDURE Uniform3dI* (VAR A: I3d;  top: SIGNED16);
	VAR l: SIZE;
BEGIN
	FOR l := 0 TO LEN(A) - 1 DO
		Uniform2dI(A[l]^, top, 0, 0, LEN(A[l, 0]), LEN(A[l]))
	END
END Uniform3dI;

PROCEDURE Uniform4dI* (VAR A: I4d;  top: SIGNED16);
	VAR l: SIZE;
BEGIN
	FOR l := 0 TO LEN(A) - 1 DO
		Uniform3dI(A[l], top)
	END
END Uniform4dI;

PROCEDURE FindFirstI* (VAR f: ARRAY OF SIGNED16;  value: SIGNED16): SIGNED32;
	VAR i: SIGNED32;
BEGIN
	i := 0;
	WHILE(f[i] # value) & (i < LEN(f)) DO INC(i) END;
	RETURN i
END FindFirstI;

PROCEDURE FindFirstX* (VAR f: ARRAY OF FLOAT64;  value: FLOAT64): SIGNED32;
	VAR i: SIGNED32;
BEGIN
	i := 0;
	WHILE (i < LEN(f)) & (f[i] # value) DO INC(i) END;
	RETURN i
END FindFirstX;

PROCEDURE FindMaxima1dX* (orig: ARRAY OF FLOAT64;                 		VAR maxima: ARRAY OF FLOAT64 );
	(* berechnet einen Vektor maxima mit Eintrag 1 fuer Max bei Vektor orig (sonst 0)
	if i is a local maximum or orig then maxima[i] = 1 else maxima[i] = 0.
	local maxima can also be at the beginning or end of the array, local maxima can have a with of more than 2
	*)
	VAR i, N, lastuppos: SIZE;                 		lastv, thisv: FLOAT64;                 		up: BOOLEAN;
BEGIN
	N := LEN(orig);
	vyLongreal.Fill(N, maxima, 0, 0);
	lastv := MIN(FLOAT64);                 		up := TRUE;                 		lastuppos := 0;
	FOR i := 0 TO N - 1 DO
		thisv := orig[i];
		IF thisv = lastv THEN
		ELSIF thisv > lastv THEN
			up := TRUE;                 		lastuppos := i
		ELSE
			IF up THEN
				vyLongreal.Fill(i - lastuppos, maxima, lastuppos, 1);
				up := FALSE
			END
		END;
		lastv := thisv
	END;
	IF up THEN  vyLongreal.Fill(N - lastuppos, maxima, lastuppos, 1)          END
END FindMaxima1dX;

PROCEDURE FindMaxima2dXRows* (VAR Orig, Maxima: ARRAY OF ARRAY OF FLOAT64);
	(* applies FindMaxima1dX on all rows on Orig *)
	VAR  i, h: SIZE;
BEGIN
	h := LEN(Orig);
	FOR i := 0 TO h - 1 DO
		FindMaxima1dX(Orig[i], Maxima[i])
	END
END FindMaxima2dXRows;

PROCEDURE AndMax* (VAR Max1, Max2, Result: ARRAY OF ARRAY OF FLOAT64);
	(*berechnet eine Matrix Result, mit Eintrag 1 an den Stellen, an denen Max1 und Max2 ebenfalls Eintrag 1 haben*)
	VAR  i, j, h, w: SIZE;
BEGIN
	h := LEN(Max1);              		w := LEN(Max1[0]);
	FOR i := 0 TO h - 1 DO
		vyLongreal.Fill(w, Result[i], 0, 0);
		FOR j := 0 TO w - 1 DO
			IF (Max1[i, j] =  1) & (Max2[i, j] = 1) THEN  Result[i, j] := 1  		END
		END
	END
END AndMax;

PROCEDURE VecFromArrayX* (VAR a: ARRAY OF FLOAT64): vyLongrealVec.tVector;
	VAR v: vyLongrealVec.tVector;
BEGIN
	v := vyLongrealVec.New(LEN(a));
	vyLongrealVec.CopyToVec(a, v, LEN(a), 0, 0 );
	RETURN v
END VecFromArrayX;

PROCEDURE VecFromArrayL* (VAR a: ARRAY OF SIGNED32): vyLongintVec.tVector;
	VAR v: vyLongintVec.tVector;
BEGIN
	v := vyLongintVec.New(LEN(a));
	vyLongintVec.CopyToVec(a, v, LEN(a), 0, 0 );
	RETURN v
END VecFromArrayL;

PROCEDURE VecFromArrayI* (VAR a: ARRAY OF SIGNED16): vyIntVec.tVector;
	VAR v: vyIntVec.tVector;
BEGIN
	v := vyIntVec.New(LEN(a));
	vyIntVec.CopyToVec(a, v, LEN(a), 0, 0 );
	RETURN v
END VecFromArrayI;

(*count the number of local maxima*)
PROCEDURE CountModi* ( x: vyLongrealVec.tVector;  minlen, maxlen: SIGNED32): SIGNED32;
	VAR i: SIZE;              N: SIZE;              number: SIGNED32;              last, this: FLOAT64;
	len, startpoint: SIZE;
CONST invalid = -1;                       (* original: from=4,to=14 *)
BEGIN
	N := vyLongrealVec.Len( x( vyLongrealVec.tVector ) );

	number := 0;              startpoint := 0;              last := vyLongrealVec.Get( x, 0 );
	FOR i := 1 TO N - 1 DO
		this := vyLongrealVec.Get( x, i );
		IF this < last THEN
			IF startpoint # invalid THEN
				len := i - 1 - startpoint;              startpoint := invalid;
				IF (minlen <= len) & (len <= maxlen) THEN INC( number )          END
			END
		ELSIF this > last THEN startpoint := i
		END;
		last := this
	END;

	IF startpoint # invalid THEN
		len := N - 1 - startpoint;              startpoint := invalid;
		IF (minlen <= len) & (len <= maxlen) THEN INC( number )          END
	END;

	startpoint := 0;              last := vyLongrealVec.Get( x, 0 );
	FOR i := 1 TO N - 1 DO
		this := vyLongrealVec.Get( x, i );
		IF this > last THEN
			IF startpoint # invalid THEN
				len := i - 1 - startpoint;              startpoint := invalid;
				IF (minlen <= len) & (len <= maxlen) THEN INC( number )          END
			END
		ELSIF this < last THEN startpoint := i
		END;
		last := this
	END;

	IF startpoint # invalid THEN
		len := N - 1 - startpoint;              startpoint := invalid;
		IF (minlen <= len) & (len <= maxlen) THEN INC( number )          END
	END;


	(*Gesamtzahl Höhen und Tiefen*)

	RETURN number
END CountModi;

PROCEDURE TestMedian*;
	VAR a: ARRAY 4 OF FLOAT64;
BEGIN

	a[0] := 1;  a[1] := 10;  a[2] := 100;  a[3] := 1000;
	Out.LongReal(Median1dX(a, 4), 20)
END TestMedian;

BEGIN
aM.launch;
END antsArrays.
antsArrays.TestMedian ~
