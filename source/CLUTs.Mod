(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE CLUTs; (** portable *)	(* eos  **)
(** AUTHOR "eos"; PURPOSE "Color lookup tables"; *)

	(**
		Color lookup tables with reverse lookup
	**)

	IMPORT
		Streams;


	CONST
		colors* = 256;


	TYPE
		Color* = SIGNED32;

		CLUT* = RECORD
			col*: ARRAY colors OF Color;	(** blue: bit 0..7; green: bit 8..15; red: bit 16..23 **)
			size*: SIGNED16;	(** number of valid colors **)
			bits: SIGNED16;	(* number of bits per component in color cube *)
			cube: POINTER TO ARRAY OF CHAR;	(* maps RGB triples to indices, size is (2^bits)^3 *)
		END;


	(** set CLUT entry to specific color (invalidates existing reverse lookup structure) **)
	PROCEDURE Set* (VAR clut: CLUT; n: SIZE; col: Color);
	BEGIN
		ASSERT((0 <= n) & (n < colors), 100);
		clut.col[n] := col MOD 1000000H;
		clut.bits := 0	(* invalidate reverse lookup *)
	END Set;

	(** get CLUT entry **)
	PROCEDURE Get* (VAR clut: CLUT; n: SIZE; VAR col: Color);
	BEGIN
		ASSERT((0 <= n) & (n < colors), 100);
		col := clut.col[n]
	END Get;

	(** initialize CLUT with number of valid colors and number of bits per component for reverse lookup table **)
	PROCEDURE Init* (VAR clut: CLUT; size, bits: SIGNED32);
		VAR
			nbits, x, cur: SIGNED32; colormax, rcol, gcol, bcol, col: Color;
			xsqr, txsqr, bsize, i: SIGNED32; rstride, gstride, rdist, gdist, bdist, cdist: Color;
			dbuf: POINTER TO ARRAY OF Color;
			rcenter, gcenter, bcenter, ghere, bhere, gmin, bmin, gmax, bmax: Color;
			incr, incg, incb, p, rp, gp: Color;
			ginc, binc: Color;

		PROCEDURE blueloop(): BOOLEAN;
			VAR detect: BOOLEAN; blue, bp, bdist, bxx: Color;
		BEGIN
			detect := FALSE;
			blue := bhere; bp := gp; bdist := gdist; bxx := binc;
			WHILE (blue < bmax) & (dbuf[bp] <= bdist) DO
				INC(blue); INC(bp); INC(bdist, bxx); INC(bxx, txsqr)
			END;
			IF blue < bmax THEN	(* found applicable cell *)
				IF blue > bhere THEN
					bhere := blue; gp := bp; gdist := bdist; binc := bxx
				END;
				detect := TRUE;
				WHILE (blue < bmax) & (dbuf[bp] > bdist) DO
					dbuf[bp] := bdist; clut.cube[bp] := CHR(cur);
					INC(blue); INC(bp); INC(bdist, bxx); INC(bxx, txsqr)
				END
			END;

			blue := bhere-1; bp := gp-1; bxx := binc - txsqr; bdist := gdist - bxx;
			IF ~detect THEN
				WHILE (blue >= bmin) & (dbuf[bp] <= bdist) DO
					DEC(blue); DEC(bp); DEC(bxx, txsqr); DEC(bdist, bxx)
				END;
				IF blue >= bmin THEN
					bhere := blue; gp := bp; gdist := bdist; binc := bxx; detect := TRUE
				END
			END;
			WHILE (blue >= bmin) & (dbuf[bp] > bdist) DO
				dbuf[bp] := bdist; clut.cube[bp] := CHR(cur);
				DEC(blue); DEC(bp); DEC(bxx, txsqr); DEC(bdist, bxx)
			END;

			RETURN detect
		END blueloop;

		PROCEDURE greenloop(): BOOLEAN;
			VAR detect: BOOLEAN; green, ggp, ggdist, gxx: Color;
		BEGIN
			detect := FALSE;
			bhere := bcenter; bmin := 0; bmax := colormax; binc := incb;	(* restart blueloop *)
			green := ghere; gp := rp; ggp := gp; gdist := rdist; ggdist := gdist; gxx := ginc;
			WHILE green < gmax DO
				IF blueloop() THEN
					IF ~detect THEN
						IF green > ghere THEN
							ghere := green; rp := ggp; rdist := ggdist; ginc := gxx
						END;
						detect := TRUE
					END;
					INC(green); INC(gp, gstride); INC(ggp, gstride); INC(gdist, gxx); INC(ggdist, gxx); INC(gxx, txsqr)
				ELSIF ~detect THEN
					green := gmax
				ELSE
					INC(green); INC(gp, gstride); INC(ggp, gstride); INC(gdist, gxx); INC(ggdist, gxx); INC(gxx, txsqr)
				END
			END;

			bhere := bcenter; bmin := 0; bmax := colormax; binc := incb;	(* restart blueloop *)
			green := ghere-1; gp := rp - gstride; ggp := gp; gxx := ginc - txsqr; gdist := rdist - gxx; ggdist := gdist;
			WHILE green >= gmin DO
				IF blueloop() THEN
					IF ~detect THEN
						ghere := green; rp := ggp; rdist := ggdist; ginc := gxx; detect := TRUE
					END;
					DEC(green); DEC(gp, gstride); DEC(ggp, gstride); DEC(gxx, txsqr); DEC(gdist, gxx); DEC(ggdist, gxx)
				ELSIF ~detect THEN
					green := gmin-1
				ELSE
					DEC(green); DEC(gp, gstride); DEC(ggp, gstride); DEC(gxx, txsqr); DEC(gdist, gxx); DEC(ggdist, gxx)
				END
			END;

			RETURN detect
		END greenloop;

		PROCEDURE redloop;
			VAR detect: BOOLEAN; red, rxx: Color;
		BEGIN
			(* red up loop *)
			detect := FALSE;
			ghere := gcenter; gmin := 0; gmax := colormax; ginc := incg;	(* restart greenloop *)
			red := rcenter; rp := p; rdist := cdist; rxx := incr;
			WHILE red < colormax DO
				IF greenloop() THEN detect := TRUE; INC(red); INC(rp, rstride); INC(rdist, rxx); INC(rxx, txsqr)
				ELSIF detect THEN red := colormax	(* leave loop *)
				ELSE INC(red); INC(rp, rstride); INC(rdist, rxx); INC(rxx, txsqr)
				END
			END;

			(* red down loop *)
			ghere := gcenter; gmin := 0; gmax := colormax; ginc := incg;	(* restart greenloop *)
			red := rcenter-1; rp := p - rstride; rxx := incr - txsqr; rdist := cdist - rxx;
			WHILE red >= 0 DO
				IF greenloop() THEN detect := TRUE; DEC(red); DEC(rp, rstride); DEC(rxx, txsqr); DEC(rdist, rxx)
				ELSIF detect THEN red := -1	(* leave loop *)
				ELSE DEC(red); DEC(rp, rstride); DEC(rxx, txsqr); DEC(rdist, rxx)
				END
			END
		END redloop;

	BEGIN
		(* uses Spencer W. Thomas' algorithm from Graphics Gems II (ugly as it is) *)
		ASSERT((2 <= size) & (size <= colors), 100);
		clut.size := SHORT(size);
		IF bits <= 0 THEN RETURN END;	(* no reverse lookup table *)

		IF bits > 6 THEN bits := 6 END;	(* (2^6)^3 = 262144! *)
		nbits := 8-bits; x := SIGNED16(ASH(1, nbits)); xsqr := ASH(1, 2*nbits); txsqr := 2*xsqr;
		colormax := SIGNED16(ASH(1, bits)); rstride := ASH(1, 2*bits); gstride := colormax;

		(* fill buffer with maximal distance *)
		bsize := ASH(1, 3*bits); NEW(dbuf, bsize);
		i := 0; WHILE i < bsize DO dbuf[i] := MAX(SIGNED32); INC(i) END;
		IF (clut.cube = NIL) OR (LEN(clut.cube^) < bsize) THEN NEW(clut.cube, bsize) END;
		clut.bits := SHORT(bits);

		cur := 0;
		WHILE cur < size DO
			col := clut.col[cur];
			rcol := ASH(col, -16) MOD 100H; gcol := ASH(col, -8) MOD 100H; bcol := col MOD 100H;
			rcenter := SIGNED16(ASH(rcol, -nbits)); rdist := rcol - (rcenter * x + x DIV 2);
			gcenter := SIGNED16(ASH(gcol, -nbits)); gdist := gcol - (gcenter * x + x DIV 2);
			bcenter := SIGNED16(ASH(bcol, -nbits)); bdist := bcol - (bcenter * x + x DIV 2);
			cdist := rdist * rdist + gdist * gdist + bdist * bdist;
			incr := 2*((rcenter+1) * xsqr - rcol * x); incg := 2*((gcenter+1) * xsqr - gcol * x); incb := 2*((bcenter+1) * xsqr - bcol * x);
			p := rcenter * rstride + gcenter * gstride + bcenter;
			redloop;
			INC(cur)
		END
	END Init;

	(** return index of color that best matches the given RGB triple **)
	PROCEDURE Match* (VAR clut: CLUT; col: Color): SIGNED32;
		VAR shift, n, best: SIGNED32; red, green, blue, err, r, g, b, e: Color;
	BEGIN
		IF clut.bits # 0 THEN	(* can do reverse lookup *)
			shift := clut.bits-8;
			RETURN ORD(clut.cube[
				ASH(ASH(ASH(col, -16) MOD 100H, shift), 2*clut.bits) +
				ASH(ASH(ASH(col, -8) MOD 100H, shift), clut.bits) +
				ASH(col MOD 100H, shift)])
		END;

		(* linear search *)
		red := ASH(col, -16) MOD 100H; green := ASH(col, -8) MOD 100H; blue := col MOD 100H;
		n := 0; best := 0; err := MAX(SIGNED32);
		WHILE n < clut.size DO
			e := clut.col[n];
			IF e = col THEN RETURN n END;
			r := ASH(e, -16) MOD 100H - red;
			g := ASH(e, -8) MOD 100H - green;
			b := e MOD 100H - blue;
			e := r * r + g * g + b * b;
			IF e < err THEN
				err := e; best := n
			END;
			INC(n)
		END;
		RETURN best
	END Match;

	(** copy color lookup table **)
	PROCEDURE Copy* (from, to: CLUT);
		VAR n: SIZE;
	BEGIN
		to.col := from.col; to.size := from.size; to.bits := from.bits;
		IF from.cube = NIL THEN
			to.cube := NIL
		ELSE
			NEW(to.cube, LEN(from.cube^));
			FOR n := 0 TO LEN(from.cube^)-1 DO
				to.cube[n] := from.cube[n]
			END
		END
	END Copy;


	(** write colors to file (only the color values themselves are written) **)
	PROCEDURE Write* (VAR w: Streams.Writer; VAR clut: CLUT);
		VAR n: SIGNED32; col: Color;
	BEGIN
		FOR n := 0 TO clut.size-1 DO
			col := clut.col[n];
			w.Char(CHR(ASH(col, -16) MOD 100H));
			w.Char(CHR(ASH(col, -8) MOD 100H));
			w.Char(CHR(col MOD 100H));
			w.Update
		END
	END Write;

	(** read up to size colors from file **)
	PROCEDURE Read* (r: Streams.Reader; VAR clut: CLUT; size: SIGNED32);
		VAR n: SIGNED32; red, green, blue: CHAR;
	BEGIN
		FOR n := 0 TO size-1 DO
			r.Char(red); 	r.Char(green); 	r.Char(blue);
			Set(clut, n, ASH(ASH(ORD(red), 8) + ORD(green), 8) + ORD(blue));
		END
	END Read;

END CLUTs.

(**
Notes

1. Color Lookup Tables
A color lookup table stores up to 256 color values. CLUTs are necessary for mapping index values to color values in displays or bitmaps that have a depth of at most 8 bits.

2. Reverse Color Lookup
To speed up the conversion from a RGB triple to a matching index with Match, Init computes a reverse color lookup table. The amount of memory this reverse lookup table requires grows exponentially with the value of bits. (The exact number of bytes used is 2^(3*bits)). A reasonable value for bits is 4, which makes Init allocate 4096 bytes on the heap. Values larger than 6 are automatically truncated.
	A value of zero for bits indicates that no reverse lookup structure should be created. Match still returns a matching index, but has to linearly search the whole table, taking up O(size) instead of O(1) time.

3. Input/Output
Write and Read can be used to store and load color values to and from a palette file. Only the colors themselves are written and read. After a CLUT has been read, it should therefore be set up with Init.
**)
