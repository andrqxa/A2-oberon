(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE WebHTTPTools; (** AUTHOR "TF"; PURPOSE "HTTP download tool"; *)

IMPORT
	Commands, Files, IP, TCP, WebHTTP, WebHTTPClient, Streams, TFLog, Modules;

VAR log : TFLog.Log;

(*
PROCEDURE StrToIntDef(x: ARRAY OF CHAR; def : SIGNED32):SIGNED32;
VAR i, v, sgn: SIGNED32;
BEGIN
	IF x[0] = "-" THEN sgn := -1; INC(i) ELSE sgn := 1 END;
	WHILE (i < LEN(x)) & (x[i] # 0X) DO
		IF (x[i] >= "0") & (x[i] <= "9") THEN v := v * 10 + (ORD(x[i])-ORD("0")) ELSE RETURN def END;
		INC(i)
	END;
	RETURN sgn * v
END StrToIntDef;
*)

PROCEDURE HexStrToIntDef(CONST x: ARRAY OF CHAR; def : SIGNED32):SIGNED32;
VAR i, v: SIGNED32;
BEGIN
	WHILE (i < LEN(x)) & (x[i] # 0X) DO
		IF (x[i] >= "0") & (x[i] <= "9") THEN v := v * 16 + (ORD(x[i])-ORD("0"))
		ELSIF (CAP(x[i]) >= "A") & (CAP(x[i]) <= "F") THEN v := v * 16 + (ORD(CAP(x[i]))-ORD("A") + 10)
		ELSE RETURN def END;
		INC(i)
	END;
	RETURN v
END HexStrToIntDef;

PROCEDURE MatchPrefixI(CONST prefix, str: ARRAY OF CHAR):BOOLEAN;
VAR i: SIGNED32;
BEGIN
	i := 0; WHILE (prefix[i] # 0X) & (CAP(prefix[i]) = CAP(str[i])) DO INC(i) END;
	RETURN prefix[i] = 0X
END MatchPrefixI;

PROCEDURE Get*(context : Commands.Context);
VAR h : WebHTTP.ResponseHeader;
		rh : WebHTTP.RequestHeader;
		in : Streams.Reader;
		res: INTEGER; i: SIZE; cs : SIGNED32;
		ch : CHAR; token : ARRAY 16 OF CHAR;
		name : ARRAY 32 OF CHAR;
		url : ARRAY 256 OF CHAR;
		file : Files.File;
		fw : Files.Writer;
		con : TCP.Connection;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(url);
	context.arg.SkipWhitespace; context.arg.String(name);

	log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" to "); log.String(name); log.Exit;
	rh.useragent := "WebHTTPTool/0.1";
	WebHTTPClient.Get(url, rh, con, h, in, res);
	IF res = WebHTTPClient.Ok THEN
		file := Files.New(name);
		Files.OpenWriter(fw, file, 0);
		IF (h.transferencoding # "") & MatchPrefixI("chunked", h.transferencoding) THEN
			in.SkipSpaces(); in.Token(token); cs := HexStrToIntDef(token, 0); in.SkipLn();
			WHILE cs # 0 DO
				FOR i := 0 TO cs - 1 DO in.Char(ch); fw.Char( ch) END;
				in.SkipLn;in.SkipSpaces; in.Token(token); cs := HexStrToIntDef(token, 0); in.SkipLn;
			END;
			IF fw.res = Streams.Ok THEN log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
			ELSE log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - failed"); log.Exit
			END
		ELSE
			IF h.contentlength >= 0 THEN
				FOR i := 0 TO h.contentlength - 1 DO in.Char(ch);  fw.Char(ch) END;
				IF fw.res = Streams.Ok THEN log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
				ELSE log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - failed"); log.Exit
				END
			ELSE
				WHILE in.res = Streams.Ok DO in.Char(ch); fw.Char(ch) END;
				log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
			END
		END;
		fw.Update;
		Files.Register(file);
		con.Close
	ELSE
		log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - "); log.Int(h.statuscode, 5);
		log.String(h.reasonphrase); log.Exit
	END;
END Get;

PROCEDURE Head*(context : Commands.Context);
VAR
	h : WebHTTP.ResponseHeader;
	res : INTEGER;
	url : ARRAY 256 OF CHAR;
	con : TCP.Connection;
BEGIN
	context.arg.SkipWhitespace; context.arg.String(url);
	WebHTTPClient.Head(url, con, h, res);
	IF res = WebHTTPClient.Ok THEN
		WebHTTP.LogResponseHeader(log, h)
	ELSE log.Enter; log.String("Head not done."); log.Exit
	END;
END Head;

PROCEDURE GetAll*(context : Commands.Context);
VAR
	baseUrl, baseDir, fileName, url, name, token: ARRAY 256 OF CHAR;
	file: Files.File;
	fw: Files.Writer;
	rh: WebHTTP.RequestHeader;
	h: WebHTTP.ResponseHeader;
	con: TCP.Connection;
	in: Streams.Reader;
	res: INTEGER; i: SIZE; cs: SIGNED32;
	ch : CHAR;
BEGIN
	IF ~context.arg.GetString(baseUrl) THEN
		context.error.String("Expected base URL");
		context.error.Ln;
		RETURN;
	END;
	IF ~context.arg.GetString(baseDir) THEN
		context.error.String("Expected base directory");
		context.error.Ln;
		RETURN;
	END;

	WHILE context.arg.GetString(fileName) DO
		Files.JoinPath(baseUrl, fileName, url);
		Files.JoinPath(baseDir, fileName, name);
		log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" to "); log.String(name); log.Exit;
		rh.fadr := IP.NilAdr;
		rh.fport := 0;
		rh.method := 0;
		rh.maj := 0; rh.min := 0;
		rh.uri := '';
		rh.host := '';
		rh.referer := '';
		rh.useragent := "WebHTTPTool/0.1";
		rh.accept := '';
		rh.transferencoding := '';
		rh.additionalFields := NIL;
		res := WebHTTPClient.Ok;
		con := NIL;
		in := NIL;
		WebHTTPClient.Get(url, rh, con, h, in, res);
		IF res = WebHTTPClient.Ok THEN
			file := Files.New(name);
			Files.OpenWriter(fw, file, 0);
			IF (h.transferencoding # "") & MatchPrefixI("chunked", h.transferencoding) THEN
				in.SkipSpaces(); in.Token(token); cs := HexStrToIntDef(token, 0); in.SkipLn();
				WHILE cs # 0 DO
					FOR i := 0 TO cs - 1 DO in.Char(ch); fw.Char( ch) END;
					 in.SkipLn;in.SkipSpaces; in.Token(token); cs := HexStrToIntDef(token, 0); in.SkipLn;
				END;
				IF fw.res = Streams.Ok THEN log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
				ELSE log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - failed"); log.Exit
				END
			ELSE
				IF h.contentlength >= 0 THEN
					FOR i := 0 TO h.contentlength - 1 DO in.Char(ch);  fw.Char(ch) END;
					IF fw.res = Streams.Ok THEN log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
					ELSE log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - failed"); log.Exit
					END
				ELSE
					WHILE in.res = Streams.Ok DO in.Char(ch); fw.Char(ch) END;
					log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - OK"); log.Exit
				END
			END;
			fw.Update;
			Files.Register(file);
			con.Close
		ELSE
			log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.String(" - "); log.Int(h.statuscode, 5);
			log.String(" ("); log.Int(res, 0); log.String(") ");
			log.String(h.reasonphrase); log.Exit
		END
	END;
END GetAll;

PROCEDURE Read*(context : Commands.Context);
VAR
	url: ARRAY 512 OF CHAR;
	reader: WebHTTPClient.ContentReader;
	rh: WebHTTP.RequestHeader;
	h: WebHTTP.ResponseHeader;
	in: Streams.Reader;
	con: TCP.Connection;
	res: INTEGER;
BEGIN
	IF ~context.arg.GetString(url) THEN RETURN END;

	log.Enter; log.TimeStamp; log.String("GET "); log.String(url); log.Exit;
	rh.useragent := "WebHTTPTool/0.1";
	WebHTTPClient.Get(url, rh, con, h, in, res);
	IF res = WebHTTPClient.Ok THEN
		NEW(reader, in, h);
		WHILE reader.res = 0 DO
			context.out.Char(reader.Get());
		END
	END
END Read;

PROCEDURE Cleanup;
BEGIN
	log.Close
END Cleanup;

BEGIN
	NEW(log, "WebHTTPTools");
	Modules.InstallTermHandler(Cleanup)
END WebHTTPTools.

WebHTTPTools.Get https://www.google.com/ google.html ~
WebHTTPTools.Get https://google.com/ google2.html ~ SNI
WebHTTPTools.Get https://habr.com/ru/all/ habr.html ~

WebHTTPTools.Get http://www.enigon.com/ test.html~
WebHTTPTools.Get http://212.254.73.92/ test.html~
WebHTTPTools.Get http://www.nzz.ch/ test.html~
WebHTTPTools.Head http://212.254.73.92/~
WebHTTPTools.Head http://www.microsoft.com~
WebHTTPTools.Head http://slashdot.org~ (* whats wrong with slashdot ? telnet worked... *)

WebHTTPTools.Get https://www.mediapart.fr/ test.html ~
WebHTTPTools.Get http://files.rcsb.org/download/4hhb.cif.gz test.gz ~
WebHTTPTools.Get https://highdim.com/ test.html ~
WebHTTPTools.Get https://www.startpage.com/ test.html ~
WebHTTP.Mod

System.Free WebHTTPTools
System.FreeDownTo WebHTTP  ~
WebHTTPClient WebWormWatch WebHTTPServer WebHTTP~
WebHTTPServer.Start~
WebWormWatch.Install~

WebHTTPTools.GetAll http://files.rcsb.org/download/ WORK: 4hhb.cif 4hhb.cif.gz 4hhb.cif 4hhb.cif.gz ~
WebHTTPTools.Read http://www.highdim.com ~
