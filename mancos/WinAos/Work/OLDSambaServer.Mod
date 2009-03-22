<?xml version="1.0" encoding="UTF-8"?>
<?bluebottle format version="0.1" ?>
<?xml-stylesheet type="text/xsl" href="http://bluebottle.ethz.ch/bluebottle.xsl" ?>
<Text>
<Span style="Normal"><![CDATA[MODULE SambaServer;	(** AUTHOR "Marcel Bihr (bihrm@student)"; PURPOSE "CIFS 1.0 Server";*)

IMPORT AosOut, AosIO, AosFS, AosTCP, AosTCPServices, AosCommands, Utilities, AosBoot, AosRandom, SYSTEM, AosFATFiles;

CONST
	LOG = TRUE;
	moduleName = "SambaServer.Mod ";
	ServerVersion* = "Aos Samba Server/0.1";
	(* Set domain name and primary domain *)
	oemDomainName = "ETHZ";
	primaryDomain = "WORKGROUP";
	
	namelen = 32;
	pwlen = 32;
	sharelen = 1024;
	shareFile = "SambaShare.dat";
	pathlen = 1024;
	buflen = 32767;
	
	read = 0; ]]></Span><Span style="Comment"><![CDATA[(* can read the files - bit 0 *)]]></Span><Span style="Normal"><![CDATA[
	write = 1; ]]></Span><Span style="Comment"><![CDATA[(* can write the files - bit 1 *)]]></Span><Span style="Normal"><![CDATA[
	
	]]></Span><Span style="Comment"><![CDATA[(* DOS ERROR CLASSES *)]]></Span><Span style="Normal"><![CDATA[
	ERRDOS = CHR(01H); ERRSRV = CHR(02H); ERRHRD = CHR(03H); ERRCMD = CHR(0FFH);
	]]></Span><Span style="Comment"><![CDATA[(* DOS ERROR CODES *)]]></Span><Span style="Normal"><![CDATA[
	ERRbadfunc = 1; ERRbadfile = 2; ERRbadpath =  3; ERRnofids = 4; ERRnoaccess = 5; ERRbadfid = 6; ERRbadmcb = 7; ERRnomem = 8;
	ERRbadmem = 9; ERRbadenv = 10; ERRbadformat = 11; ERRbadaccess = 12; ERRbaddata = 13; ERRbaddrive = 15; ERRremcd = 16;
	ERRdiffdevice = 17; ERRnofiles = 18; ERRbadshare = 32; ERRlock = 33; ERRfileexists = 80; ErrQuota = 512; ErrNotALink = 513;
	ERRunknownlevel = 124; (* not documented in SNIA *)
	ERRerror = 1; ERRbadpw = 2; ERRaccess = 4; ERRinvtid = 5; ERRinvnetname = 6; ERRinvdevice = 7; ERRqfull = 49; ERRqtoobig = 50;
	ERRqeof = 51; ERRinvpfid = 52; ERRsmbcmd = 64; ERRsrverror = 65; ERRfilespecs = 67; ERRbadLink = 68; ERRbadpermits = 69;
	ERRbadPID = 70; ERRsetattrmode = 71; ERRpaused = 81; ERRmsgoff = 82; ERRnoroom = 83; ERRrmuns = 87; ERRtimeout = 88;
	ERRnorresource = 89; ERRtoomanyuids = 90; ERRbaduid = 91; ERRusempx = 250; ERRusestd = 251; ERRcontmpx = 252;
	ERRNOTIFYENUMDIR = 1024; ERRaccountExpired = 2239; ERRbadClient = 2240; ERRbadLogonTime = 2241;
	ERRpasswordExpired = 2242; ERRnosupport = 65535;
	ERRnowrite = 19; ERRbadunit = 20; ERRnotready = 21; ERRbadcmd = 22; ERRdata = 23; ERRseek = 25; ERRbadmedia = 26;
	ERRbadsector = 27; ERRnopaper = 28; ERRwrite = 29; ERRread = 30; ERRgeneral = 31; 
	ERRwrongdisk = 34; ERRFCBUnavail = 35; ERRsharebufexc = 36;
	
TYPE

	]]></Span><Span style="Comment"><![CDATA[(* represents a user added with the AddUser method *)]]></Span><Span style="Normal"><![CDATA[
	User = POINTER TO RECORD
		name: ARRAY namelen OF CHAR;
		password: ARRAY pwlen OF CHAR;
		next: User;
	END;
	
	]]></Span><Span style="Comment"><![CDATA[(* represents a user associated to a share. *)]]></Span><Span style="Normal"><![CDATA[
	SUser = POINTER TO RECORD
		user: User;
		permissions: SET;
		next: SUser;
	END;
	
	]]></Span><Span style="Comment"><![CDATA[(* represents a single share *)]]></Span><Span style="Normal"><![CDATA[
	Share = POINTER TO RECORD;
		name: ARRAY sharelen OF CHAR;
		root: ARRAY sharelen OF CHAR;
		users: SUser;
		next: Share;
	END;
	
	]]></Span><Span style="Comment"><![CDATA[(* represents a tree with the user actually connected to it *)]]></Span><Span style="Normal"><![CDATA[
	Connection = POINTER TO RECORD;
		UID, TID: INTEGER;
		capabilities: LONGINT;
		share: Share;
		user: SUser;
		files: SMBFile;
		lastFID: INTEGER;
		uok: BOOLEAN;
		next: Connection;
	END;
	
	]]></Span><Span style="Comment"><![CDATA[(* represents an open file *)]]></Span><Span style="Normal"><![CDATA[
	SMBFile = POINTER TO RECORD;
		fid: INTEGER;
		file: AosFS.File;
		next: SMBFile;
	END;
	
]]></Span><Span style="Comment"><![CDATA[	(* contains the parameters and the data of one Transation2 Request *)]]></Span><Span style="Normal"><![CDATA[
	Trans2 = POINTER TO RECORD;
		tid: INTEGER;
		tpCount, tdCount, mdCount, flags: INTEGER;
		setup: INTEGER;
		dataBuffer: Utilities.Buffer;
		next: Trans2;
	END;
	
	]]></Span><Span style="Comment"><![CDATA[(* representation of one smb packet - mainly the header
		the data is passed to the handler method within the
		inputstream. Outgoing data is written into the buffer *)]]></Span><Span style="Normal"><![CDATA[
	Packet = OBJECT
		VAR
			command: CHAR;
			status: ARRAY 4 OF CHAR;;
			flags: CHAR;
			flags2: INTEGER;
			pad: ARRAY 12 OF CHAR;
			TID, PID, UID, MID: INTEGER;
			outBuf: Utilities.Buffer;
			al: LONGINT;
			buf: Utilities.String;
			msgSize: LONGINT;
			i: INTEGER;
			skipSend: BOOLEAN;
			
		PROCEDURE Internalize(VAR in: AosIO.Reader);
		BEGIN
			skipSend := FALSE;
			in.SkipBytes(2);
			msgSize := in.Net16();
			in.SkipBytes(4); (* 0xFF SMB *);
			command := in.Get();
			in.Bytes(status, 0, 4, al);
			in.Char(flags);
			in.RawInt(flags2);
			in.SkipBytes(12);
			in.RawInt(TID);
			in.RawInt(PID);
			in.RawInt(UID);
			in.RawInt(MID);
			NEW(outBuf, 0);
		END Internalize;
		
		PROCEDURE Serialize(VAR out: AosIO.Writer);
		VAR i: LONGINT;
		BEGIN
			IF skipSend THEN RETURN END; ]]></Span><Span style="Comment"><![CDATA[(* if skipSend is set don't send nothing *)]]></Span><Span style="Normal"><![CDATA[
			]]></Span><Span style="Comment"><![CDATA[(* make sure wordCount and byteCount are always written - at least as zero *)]]></Span><Span style="Normal"><![CDATA[
			IF outBuf.GetLength() < 3 THEN
				i := outBuf.GetLength();
				msgSize := 35;
			ELSE
				]]></Span><Span style="Comment"><![CDATA[(* compute message size *)]]></Span><Span style="Normal"><![CDATA[
				msgSize := 32 + outBuf.GetLength();
			END;
			out.Char(CHR(0));
			out.Char(0X);
(* *)		out.Net16(msgSize);
			out.Char(CHR(255));
			out.Char('S');
			out.Char('M');
			out.Char('B');
			out.Char(command);
			out.Bytes(status, 0, 4);
			out.Char(flags);
			out.RawInt(flags2);
			out.Bytes(pad, 0, 12);
			out.RawInt(TID);
			out.RawInt(PID);
			out.RawInt(UID);
			out.RawInt(MID);
			]]></Span><Span style="Comment"><![CDATA[(* write directly the buffer (it has to contain byteCount and stuff *)]]></Span><Span style="Normal"><![CDATA[
			IF outBuf.GetLength() < 3 THEN
				WHILE i < 3 DO
					out.Char(0X);
					INC(i);
				END;
			ELSE
				buf := outBuf.GetString();
				out.Bytes(buf^, 0, outBuf.GetLength());
			END;
			out.Update();
		END Serialize;
	END Packet;
		
	SambaAgent = OBJECT (AosTCPServices.Agent)
	VAR
		nOfCon: LONGINT;
		packet:Packet;
		out, w:AosIO.Writer;
		in:AosIO.Reader;
		closeRequest: BOOLEAN;
		sessionKey: LONGINT;
		encKey: ARRAY 8 OF CHAR;
		cBufSize: LONGINT;
		cVC: INTEGER;
		cCaps: LONGINT;
		cUID: INTEGER;
		state: INTEGER; ]]></Span><Span style="Comment"><![CDATA[(* 0: readyForConnection, 1: Negotiated, 2: Set-Up, 3: Connected to Resource *)]]></Span><Span style="Normal"><![CDATA[
			
	PROCEDURE HandleNegotiate(in: AosIO.Reader; w: AosIO.Writer);
	VAR
		i, index, idx: INTEGER;
		caps, len: LONGINT;
		time: ARRAY 2 OF LONGINT;
		serverTimeZone: SHORTINT;
		now: Utilities.TDateTime;
		byteCount: INTEGER;
		act: CHAR;
		test: ARRAY 5 OF CHAR;
		bc: ARRAY 2 OF CHAR;
		sr: AosIO.StringReader;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleNegotiate"); AosOut.Ln();
		END;
		IF state # 0 THEN
			]]></Span><Span style="Comment"><![CDATA[(* Not in a valid state *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				AosOut.String(moduleName); AosOut.String("Not in a valid state!"); AosOut.Ln();
			END;
			SetError(ERRSRV, ERRerror);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* prepare header of packet appropriate *)]]></Span><Span style="Normal"><![CDATA[
		packet.flags := 80X; (* 84X: caseless *)
		packet.flags2 := 1; (* Strings are ascii *)
		]]></Span><Span style="Comment"><![CDATA[(* handle input *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(1); (* wordCount *)
		in.RawInt(byteCount);
		]]></Span><Span style="Comment"><![CDATA[(* search for NT LM 0.12 dialect and find out position *)]]></Span><Span style="Normal"><![CDATA[
		i := 0; index := -1; idx := -1;
(* *)	WHILE i < byteCount DO (* ev. byteCount -1 *)
			act := in.Get();
			IF ORD(act) = 2 THEN
				INC(idx);
			ELSE 
				IF (act = 'N') THEN
					in.Bytes(test, 0 , 4, len);
					i := i + 4;
					IF test = "T LM" THEN 
						index := idx;
					END;
				END;
			END;
			INC(i);
		END;
		]]></Span><Span style="Comment"><![CDATA[(* index holds now the right value *)]]></Span><Span style="Normal"><![CDATA[
		sessionKey := rg.Integer(); ]]></Span><Span style="Comment"><![CDATA[(* random *)]]></Span><Span style="Normal"><![CDATA[
		caps := 0;]]></Span><Span style="Comment"><![CDATA[ (* probably 0x10 -> supportNT-SMBs, implies 0x0200 NT_FIND *)]]></Span><Span style="Normal"><![CDATA[
		now := Utilities.Now();
(* 		set systemTimeHigh and ...Low to current time (SNIA page 26) *)
		GetSambaTime(Utilities.Now(), time);
(* *)	encKey := "notused";
		w.Char(CHR(17)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *);]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(index);]]></Span><Span style="Comment"><![CDATA[ (* index *)]]></Span><Span style="Normal"><![CDATA[
 		w.Char(CHR(1)); ]]></Span><Span style="Comment"><![CDATA[(* SecurityMode: 0001 -> user level sec, no encrypted passwd, no sec.-signatures *)]]></Span><Span style="Normal"><![CDATA[
(* w.Char(CHR(2)); (* encrypted *)*)
		w.RawInt(1); ]]></Span><Span style="Comment"><![CDATA[(* MaxMpxCount: max pending outstanding requests [Samba: 50] *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(1); ]]></Span><Span style="Comment"><![CDATA[(* MaxNumberVcs: max VCs between client and server *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(buflen); ]]></Span><Span style="Comment"><![CDATA[(* MaxBufferSize: max transmit buffer size *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(buflen);]]></Span><Span style="Comment"><![CDATA[ (* MaxRawSize: maximum raw buffer size, used for SMB_COM_WRITE_RAW and ...-READ_RAW (not used here) *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(sessionKey); ]]></Span><Span style="Comment"><![CDATA[(* unique token identifying this session *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(caps); ]]></Span><Span style="Comment"><![CDATA[(* capabilities *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(time[0]); ]]></Span><Span style="Comment"><![CDATA[(* servertime low *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(time[1]); ]]></Span><Span style="Comment"><![CDATA[(* servertime high *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawInt(-120); ]]></Span><Span style="Comment"><![CDATA[(* timezone *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(CHR(8)); ]]></Span><Span style="Comment"><![CDATA[(* lenght of encryption key -> 8 byte *)]]></Span><Span style="Normal"><![CDATA[
		byteCount :=  LEN(encKey) + SHORT(Utilities.Length(oemDomainName)) + 1;
		w.RawInt(SHORT(byteCount));
(* *)	w.Bytes(encKey, 0, 8);  ]]></Span><Span style="Comment"><![CDATA[(* encrypton key | only in non-extended-security mode *)]]></Span><Span style="Normal"><![CDATA[
		w.RawString(oemDomainName); ]]></Span><Span style="Comment"><![CDATA[(* set in CONST *)]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Comment"><![CDATA[(* if extended security is used, don't send encryption key and OemDomainName but GUID (array 16 of Char) and a char array securityBlob
]]></Span><Span style="Normal"><![CDATA[		]]></Span><Span style="Comment"><![CDATA[	extended security mode is not implemented here. *)]]></Span><Span style="Normal"><![CDATA[
		state := 1;]]></Span><Span style="Comment"><![CDATA[ (* Negotiated *)]]></Span><Span style="Normal"><![CDATA[
	END HandleNegotiate;
		
	PROCEDURE HandleSessionSetup(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		tskey: LONGINT;
		ansiSize, unicodeSize: INTEGER;
		aPwd: ARRAY 32 OF CHAR;
		uPwd: ARRAY 32 OF CHAR;
		i, j: LONGINT;
		accName, primDomain, nativeOS, nativeLanMan: ARRAY 64 OF CHAR;
		nativeSOS, nativeSLanMan: ARRAY 12 OF CHAR;
		isAndX: BOOLEAN;
		wordCount, byteCount: INTEGER;
		andXCmd: CHAR;
		andXOff: INTEGER;
		action: INTEGER;
		cbs: INTEGER;
		uok: BOOLEAN;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleSessionSetup"); AosOut.Ln();
		END;	
		packet.flags := 80X;
		packet.flags2 := 1;
		IF state < 1 THEN
			]]></Span><Span style="Comment"><![CDATA[(* Not in a valid state *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRerror);
			AosOut.String(moduleName); AosOut.String("Not in a valid state!"); AosOut.Ln();
			RETURN;
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		]]></Span><Span style="Comment"><![CDATA[(* process input *)]]></Span><Span style="Normal"><![CDATA[
		wordCount := ORD(in.Get());
		INC(pos);
		andXCmd := in.Get(); INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* retrieve client max buffer size *)]]></Span><Span style="Normal"><![CDATA[
		cBufSize := ORD(in.Get()) + LONG(ORD(in.Get())) * 100H; ]]></Span><Span style="Comment"><![CDATA[(* read in an unsigned integer, even if the msb is 1 *)]]></Span><Span style="Normal"><![CDATA[
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* maxMpxCount *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(2);
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* retrieve client vc number *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(cVC);
		pos := pos + 2;
(*		VC should be handled 0 -> first vc (-> close all other files ? *)
		]]></Span><Span style="Comment"><![CDATA[(*  retrieve sessionKey *)]]></Span><Span style="Normal"><![CDATA[
		in.RawLInt(tskey);
		pos := pos + 4;
		]]></Span><Span style="Comment"><![CDATA[(* compare sessionKey with the one sent in NEGOTIATE
]]></Span><Span style="Normal"><![CDATA[		]]></Span><Span style="Comment"><![CDATA[	It has to be ignored because there are clients that send always '0' *)]]></Span><Span style="Normal"><![CDATA[
		IF tskey # sessionKey THEN
			IF LOG THEN
				AosOut.String("SessionKey missmatch - ignoring"); AosOut.Ln();
			END;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* retrive length of ansi password (caseless) *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(ansiSize);
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* retrieve lenght of unicode password (case sensitive) *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(unicodeSize);
		pos := pos + 2;
		in.SkipBytes(4);
		pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Comment"><![CDATA[(* retrieve client capabilities *)]]></Span><Span style="Normal"><![CDATA[
		in.RawLInt(cCaps);
		pos := pos + 4;
		]]></Span><Span style="Comment"><![CDATA[(* the client capabilities are not of interest, because the client should only
			set caps, that the server supports - and it supports none atm. *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		pos := pos + 2 ;
		IF ansiSize > 0 THEN ]]></Span><Span style="Comment"><![CDATA[	(* read in ANSI pwd and validate *)]]></Span><Span style="Normal"><![CDATA[
			in.Bytes(aPwd, 0, ansiSize, i);
			pos := pos + ansiSize;
		ELSIF unicodeSize > 0 THEN ]]></Span><Span style="Comment"><![CDATA[(* read in unicode pwd and validate *)]]></Span><Span style="Normal"><![CDATA[
			in.Bytes(uPwd, 0, unicodeSize, i);
			pos := pos + unicodeSize;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* Ignore reserved2 *)]]></Span><Span style="Normal"><![CDATA[
		IF in.Peek() = 0X THEN
			in.SkipBytes(1);
			INC(pos);
		END;
		]]></Span><Span style="Comment"><![CDATA[(* retrieve accountName *)]]></Span><Span style="Normal"><![CDATA[
		in.RawString(accName);
		pos := pos + Utilities.Length(accName) + 1;
		in.RawString(primDomain);
		pos := pos + Utilities.Length(primDomain) + 1;
		in.RawString(nativeOS);
		pos := pos + Utilities.Length(nativeOS) + 1;
		in.RawString(nativeLanMan);
		pos := pos + Utilities.Length(nativeLanMan) + 1;
		IF LOG THEN
			AosOut.String("**Information about the client:"); AosOut.Ln(); AosOut.String("Native OS: '"); AosOut.String(nativeOS); AosOut.String("' Lan Manager: '");
			AosOut.String(nativeLanMan); AosOut.String("' on Domain: '"); AosOut.String(primDomain); AosOut.String("'."); AosOut.Ln();
			AosOut.String("Username: '"); AosOut.String(accName); AosOut.String("'."); AosOut.Ln();
		END;
		uok := FALSE;
		action := 0;
		]]></Span><Span style="Comment"><![CDATA[(* check if the user is valid. If user and password are correct, log in. If the user exists, but the password
			is wrong -> error: badpw. If the user exists and the password is empty (=0X) it is marked s.t. in the
			TreeConnect request the password is checked (it is possible to provide one there). If the user does
			not exist at all a guest login is checked. If there exists one and the password for guest is empty
			the user is logged in as guest and in the response the action is set to 1 which means guest
			access granted *)]]></Span><Span style="Normal"><![CDATA[
		IF ~UserValid(accName, aPwd, uPwd) THEN
			IF UserExists(accName) THEN
				IF (ansiSize > 0) OR (unicodeSize > 0) THEN (* there is a pwd an it's wrong *)
					SetError(ERRSRV, ERRbadpw);
					IF LOG THEN
						AosOut.String("wrong password"); AosOut.Ln();
					END;
					RETURN;
				END;]]></Span><Span style="Comment"><![CDATA[ (* there is no pwd -> note with leaving uok to false -> check on treeconnect *)]]></Span><Span style="Normal"><![CDATA[
			ELSE
				IF UserValid("guest", "", "") THEN
					accName := "GUEST";
					IF LOG THEN
						AosOut.String("user does not exist -> grant guest access"); AosOut.Ln();
					END;
					action := 1;
					uok := TRUE;
				ELSE 
					SetError(ERRSRV, ERRbadpw);
					IF LOG THEN
						AosOut.String("wrong password"); AosOut.Ln();
					END;
					RETURN;
				END;
			END;
		ELSE
			uok := TRUE;
		END;
(* AosOut.String("ignore user and password"); AosOut.Ln(); *)

		]]></Span><Span style="Comment"><![CDATA[(* generate new UID *)]]></Span><Span style="Normal"><![CDATA[
		cUID := lastUID;
		INC(lastUID);
		packet.UID := cUID;
		]]></Span><Span style="Comment"><![CDATA[(* create a half-way connection for this user. The second part of the connection is created
]]></Span><Span style="Normal"><![CDATA[		]]></Span><Span style="Comment"><![CDATA[	on TreeConnection where the share is known and the user permissions are set *)]]></Span><Span style="Normal"><![CDATA[
		CreateConnection(cUID, accName, cCaps, uok); 
]]></Span><Span style="Comment"><![CDATA[		(* generate output *)]]></Span><Span style="Normal"><![CDATA[
		nativeSOS := "Bluebottle";
		nativeSLanMan := "Aos LAN MAN";
		byteCount := SHORT(1 ]]></Span><Span style="Comment"><![CDATA[(* secBlobLength *)]]></Span><Span style="Normal"><![CDATA[ + Utilities.Length(nativeSOS) + 3 + Utilities.Length(nativeSLanMan) + Utilities.Length(primaryDomain));
		w.Char(CHR(4)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			outOff := outOff + byteCount + 8 + 3; 
			w.RawInt(SHORT(outOff));]]></Span><Span style="Comment"><![CDATA[ (* ANDX offset *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(action);
		w.RawInt(1);]]></Span><Span style="Comment"><![CDATA[ (* security blobl length -> no blob *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(SHORT(byteCount));
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* no security blob *)]]></Span><Span style="Normal"><![CDATA[
		w.Bytes(nativeSOS, 0, 11); ]]></Span><Span style="Comment"><![CDATA[(* Native OS *)]]></Span><Span style="Normal"><![CDATA[
		w.Bytes(nativeSLanMan, 0, 12);]]></Span><Span style="Comment"><![CDATA[ (* native Lan Manager *)]]></Span><Span style="Normal"><![CDATA[
		w.RawString(primaryDomain);]]></Span><Span style="Comment"><![CDATA[ (* primary domain *)]]></Span><Span style="Normal"><![CDATA[
		state := 2; ]]></Span><Span style="Comment"><![CDATA[(* Set-Up *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleSessionSetup;
	
	PROCEDURE HandleTreeConnect(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		pwdLength: INTEGER;
		pwd: ARRAY pwlen OF CHAR;
		i: LONGINT;
		wordCount: INTEGER;
		path, service: ARRAY pathlen OF CHAR;
		nativeFileSystem: ARRAY pathlen OF CHAR;
		cFlags: INTEGER;
		cTID: INTEGER;
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		temp2: ARRAY 3 OF CHAR;
		byteCount: LONGINT;
		ec: LONGINT;
		len: LONGINT;
		fs: AosFS.FileSystem;
		c: Connection;
		fsn: ARRAY pathlen OF CHAR;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleTreeConnect"); AosOut.Ln();
		END;
		packet.flags := 80X; ]]></Span><Span style="Comment"><![CDATA[(* 84X would be caseless *)]]></Span><Span style="Normal"><![CDATA[
		packet.flags2 := 1;
		IF state # 2 THEN
			]]></Span><Span style="Comment"><![CDATA[(* Not in a valid state *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRerror);
			IF LOG THEN
				AosOut.String(moduleName); AosOut.String("not in a valid state!"); AosOut.Ln();
			END;
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* process input *)]]></Span><Span style="Normal"><![CDATA[
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		wordCount := ORD(in.Get());
		INC(pos);
		in.Char(andXCmd);
		INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos);]]></Span><Span style="Comment"><![CDATA[ (* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* check if disconnect flag set *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(cFlags);
		pos := pos + 2;
		IF cFlags = 1 THEN
			ec := ReleaseShare(packet.TID, packet.UID); ]]></Span><Span style="Comment"><![CDATA[(* disconnect Tree *)]]></Span><Span style="Normal"><![CDATA[
			IF ec > 0 THEN
				SetError(ERRSRV, ec);
				RETURN;
			END;
		END;
		in.RawInt(pwdLength);
		pos := pos + 2;
		in.SkipBytes(2);
		pos := pos + 2;]]></Span><Span style="Comment"><![CDATA[ (* skip byteCount *)]]></Span><Span style="Normal"><![CDATA[
		in.Bytes(pwd, 0, pwdLength, len);
		IF pwd[pwdLength-1] # 0X THEN
			pwd[pwdLength] := 0X;
		END;
		pos := pos + pwdLength;
		in.RawString(path);
		pos := pos + Utilities.Length(path);
		IF in.Peek() = 0X THEN
			in.SkipBytes(1);
			INC(pos);
		END;
		in.RawString(service);
		pos := pos + Utilities.Length(service);
		IF LOG THEN
			AosOut.String("**Requested Path is: '"); AosOut.String(path); AosOut.String("' (service: '"); AosOut.String(service); AosOut.String("')."); AosOut.Ln();
		END;
(*		Check service and react appropriate *)
		cTID := lastTID;
		INC(lastTID);
		]]></Span><Span style="Comment"><![CDATA[(* check and register the share and TID *)]]></Span><Span style="Normal"><![CDATA[
		IF ~ActivateConnection(packet.UID, cTID, path, pwd) THEN
			]]></Span><Span style="Comment"><![CDATA[(* error is set in ActivateConnection *)]]></Span><Span style="Normal"><![CDATA[
			RETURN;
		END;
		packet.TID := cTID;
		]]></Span><Span style="Comment"><![CDATA[(* generate output *)]]></Span><Span style="Normal"><![CDATA[
		service := "A:";]]></Span><Span style="Comment"><![CDATA[ (* filesystem share *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
		END;
		i := 0;
		WHILE (c.share.root[i] # 0X) & (c.share.root[i] # ':') DO
			fsn[i] := c.share.root[i];
			INC(i);
		END;
		fs := AosFS.This(fsn);
		IF fs = NIL THEN
			IF LOG THEN
				AosOut.String("## ERROR fs not found"); AosOut.Ln();
			END;
			SetError(ERRSRV, ERRinvdevice);
			RETURN;
		END;
		byteCount := Utilities.Length(service) + 1 + Utilities.Length(fs.desc) + 1;
		w.Char(CHR(3)); (* wordCount *)
		w.Char(andXCmd);
		w.Char(0X);
		IF isAndX THEN
			outOff := outOff + byteCount + 6 + 3; 
			w.RawInt(SHORT(outOff));
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(0); (* no optional support. 1 would be support_search_bits, 2 share_is_in_dfs *)
		w.RawInt(SHORT(byteCount));
		w.RawString(service);
		w.RawString(fs.desc);
		state := 3;
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleTreeConnect;
	
	PROCEDURE HandleCloseORTreeDisconnect(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		byteCount, wordCount: LONGINT;
		isClose, isTDC: BOOLEAN;
		fid, ec: INTEGER;
		lastWriteTime, date, time: LONGINT;
		c: Connection;
		f, prev: SMBFile;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleCloseORTreeDisconnect"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		wordCount := ORD(in.Get());
		IF wordCount > 0 THEN
			isClose := TRUE;
			in.RawInt(fid);
			in.RawLInt(lastWriteTime);
		ELSE
			isClose := FALSE;
		END;
		IF packet.command = CHR(04H) THEN
			isTDC := FALSE;
		ELSE
			isTDC := TRUE;
		END;
		IF isClose THEN
			c := FindConnection(packet.TID);
			IF c = NIL THEN
				SetError(ERRSRV, ERRinvtid);
				RETURN;
			END;
			f := FindFile(fid, c);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadfid);
				RETURN;
			END;
			GetDTFromSmbDT(lastWriteTime, date, time);
			IF (time # 0) & (date # 0) THEN  ]]></Span><Span style="Comment"><![CDATA[(* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
				f.file.SetDate(time, date);
			END;
			f.file.Update(); ]]></Span><Span style="Comment"><![CDATA[(* write file *)]]></Span><Span style="Normal"><![CDATA[
			]]></Span><Span style="Comment"><![CDATA[(* remove from connection *)]]></Span><Span style="Normal"><![CDATA[
			f := c.files; prev := NIL;
			WHILE f #NIL DO
				IF f.fid = fid THEN
					IF prev = NIL THEN
						c.files := f.next;
					ELSE
						prev.next := f.next;
					END;
				END;
				prev := f; f := f.next;
			END;
		END;
		IF isTDC THEN
			ec := ReleaseShare(packet.TID, packet.UID); ]]></Span><Span style="Comment"><![CDATA[(* disconnect Tree *)]]></Span><Span style="Normal"><![CDATA[
			closeRequest := TRUE;
			IF ec > 0 THEN
				SetError(ERRSRV, ec);
				RETURN;
			END;
		END;
		w.Char(CHR(0));]]></Span><Span style="Comment"><![CDATA[ (* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* byteCount *)]]></Span><Span style="Normal"><![CDATA[
		IF isTDC THEN
			state := 2;
		END;
	END HandleCloseORTreeDisconnect;
	
	PROCEDURE HandleCheckDirectory(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR dir: ARRAY pathlen OF CHAR; i, j: LONGINT; f: AosFS.File; c: Connection; fsPath: ARRAY pathlen OF CHAR;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleCheckDirectory"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(4);]]></Span><Span style="Comment"><![CDATA[ (* skip wordCount, byteCount and BufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		in.RawString(dir);
		]]></Span><Span style="Comment"><![CDATA[(* Search in the Connected Tree ! *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN (* TID not valid *)
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF (dir = "/") OR (dir = "\") THEN
			]]></Span><Span style="Comment"><![CDATA[(* OK *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			i := 0; j := 0;
			WHILE c.share.root[i] # 0X DO
				fsPath[j] := c.share.root[i];
				INC(j); INC(i);
			END;
			i := 0;
			WHILE dir[i] # 0X DO
				fsPath[j] := dir[i];
				INC(i); INC(j);
			END;
			fsPath[j+1] := 0X;
			IF LOG THEN
				AosOut.String("Checking '"); AosOut.String(fsPath); AosOut.String("'."); AosOut.Ln();
			END;
			f :=  AosFS.Old(fsPath);
			IF (f = NIL) OR ~(AosFS.Directory IN f.flags) THEN
				]]></Span><Span style="Comment"><![CDATA[(* is a File -> report wia ERRbadpath or STATUS_NOT_A_DIRECTORY *)]]></Span><Span style="Normal"><![CDATA[
				SetError(ERRDOS, ERRbadpath);
				RETURN;
			END;
		END;
		w.Char(0X);
		w.RawInt(0);
	END HandleCheckDirectory;
	
	PROCEDURE HandleLogoff(offset, outOff, pos: LONGINT; in: AosIO.Reader;  w, out: AosIO.Writer);
	VAR
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		c, prev: Connection;
		ec: INTEGER;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleLogoff"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		in.SkipBytes(1);
		INC(pos);]]></Span><Span style="Comment"><![CDATA[ (* skip wordCount *);]]></Span><Span style="Normal"><![CDATA[
		in.Char(andXCmd);
		INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		ec := ReleaseShare(packet.TID, packet.UID);
	(* ignore ec ? *)
		c := connections; prev := NIL;
		WHILE c # NIL DO
			]]></Span><Span style="Comment"><![CDATA[(* close all connections from this user *)]]></Span><Span style="Normal"><![CDATA[
			IF c.UID = packet.UID THEN
				IF prev # NIL THEN
					prev.next := c.next;
				ELSE
					connections := c.next;
				END;
			END;
			prev := c; c := c.next;
		END;
		w.Char(CHR(2)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X);
		IF isAndX THEN
			outOff := outOff + 4 + 3; 
			w.RawInt(SHORT(outOff));
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(0);
		state := 1;
		IF isAndX THEN
			AosOut.String("--AndX-Command"); AosOut.Ln();
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END
	END HandleLogoff;
	
	]]></Span><Span style="Comment"><![CDATA[(* A limited version of the Echo-Command. EchoCount has to be 1 *)]]></Span><Span style="Normal"><![CDATA[
	PROCEDURE HandleEcho(in: AosIO.Reader; w: AosIO.Writer);
	VAR
		i: LONGINT;
		byteCount, echoCount: INTEGER;
		data: ARRAY packet.msgSize OF CHAR;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleEcho"); AosOut.Ln();
		END;
		IF state < 2 THEN
			SetError(ERRSRV, ERRnoaccess);
			RETURN;
		END;
		in.SkipBytes(1);]]></Span><Span style="Comment"><![CDATA[(* skip wordCount *)]]></Span><Span style="Normal"><![CDATA[
		packet.flags := 80X;
		packet.flags2 := 1;
		in.RawInt(echoCount);
		in.RawInt(byteCount);
		IF echoCount # 1 THEN
			SetError(ERRSRV, ERRnosupport);
			RETURN;
		END;
		i := 0;
		WHILE i < byteCount DO
			w.Char(in.Get());
			INC(i);
		END;
	END HandleEcho;
	
	PROCEDURE HandleNTCreate(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		i, j, len: LONGINT;
		namelength : INTEGER;
		allocSize: LONGINT; (* HUGEINT ? *)
		extFileAttributes, shareAccess, createDisposition, createOptions, impersonationLevel, rootDirFid, flags, desiredAccess: LONGINT;
		securityFlags: CHAR;
		name, path: ARRAY pathlen OF CHAR;
		cFid: INTEGER;
		c: Connection;
		f: SMBFile;
		time, date, dateTime: LONGINT;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleNTCreate"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		packet.flags := 80X;
		packet.flags2 := 1;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* skip wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.Char(andXCmd);
		INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		in.RawInt(namelength);
		pos := pos + 2;
		in.RawLInt(flags);
		pos := pos + 4;
		in.RawLInt(rootDirFid);
		pos := pos + 4;
		in.RawLInt(desiredAccess);
		pos := pos + 4;
(* *) in.RawLInt(allocSize);
		pos := pos + 4;
		]]></Span><Span style="Comment"><![CDATA[(* ignore 4 high order bytes of allocSize (> 4GB) *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(4);
		pos := pos + 4;
		in.RawLInt(extFileAttributes);
		pos := pos + 4;
		in.RawLInt(shareAccess);
		pos := pos + 4;
		in.RawLInt(createDisposition);
		pos := pos + 4;
		in.RawLInt(createOptions);
		pos := pos + 4;
		in.RawLInt(impersonationLevel);
		pos := pos + 4;
		in.Char(securityFlags);
		INC(pos);
		in.Bytes(name, 0, namelength, len);
		pos := pos + len;
		IF LOG THEN
			AosOut.String("**Requested File to create is: "); AosOut.String(name); AosOut.String(" (action 0X"); AosOut.Hex(createDisposition, 4);
			AosOut.String(")."); AosOut.Ln();
		END;
]]></Span><Span style="Comment"><![CDATA[		(* try to open or create the file according to the createDisposition -> alloc new SMBFile and add to c.files *)
		]]></Span><Span style="Normal"><![CDATA[c := FindConnection(packet.TID);
		IF c = NIL THEN ]]></Span><Span style="Comment"><![CDATA[(* TID not valid *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		i := 0; j := 0;
		WHILE c.share.root[i] # 0X DO
			path[j] := c.share.root[i];
			INC(j); INC(i);
		END;
		i := 0;
		WHILE name[i] # 0X DO
			path[j] := name[i];
			INC(i); INC(j);
		END;
		path[j+1] := 0X;
		FlipDelimiter(path);
		f := CreateFile(path, createDisposition);
		IF f = NIL THEN ]]></Span><Span style="Comment"><![CDATA[(* error occurred *)]]></Span><Span style="Normal"><![CDATA[
			RETURN;
		END;
		w.Char(CHR(26)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			outOff := outOff +  52 + 3; 
			w.RawInt(SHORT(outOff));]]></Span><Span style="Comment"><![CDATA[ (* ANDX offset *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(0);
		END;
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* no oplock granted *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(f.fid);
		f.file.GetDate(time, date);
		dateTime := GetDateTime(date, time);
(* *)	w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[ (* create action *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(dateTime); ]]></Span><Span style="Comment"><![CDATA[ (* CreationTime *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(dateTime); ]]></Span><Span style="Comment"><![CDATA[ (* lastAccessTime *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(dateTime);  ]]></Span><Span style="Comment"><![CDATA[(* LastWriteTime *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(dateTime);  ]]></Span><Span style="Comment"><![CDATA[(* ChangeTime *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* ExtFileAttributes *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawLInt(0); w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* AllocationSize *)]]></Span><Span style="Normal"><![CDATA[
(* *) 	w.RawLInt(0); w.RawLInt(f.file.Length()); ]]></Span><Span style="Comment"><![CDATA[(* end of file offset *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* FileType *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* DeviceState *)]]></Span><Span style="Normal"><![CDATA[
(* *)	(* check if its a directory in c.file.flags *)	w.Char(0X); (* isDirectory? *)
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* ByteCount *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleNTCreate;
	
	PROCEDURE HandleOpenAndX(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		i, ec: LONGINT;
		wordCount, byteCount: INTEGER;
		flags, mode, sattr, attr, ofun, action: INTEGER;
		time, date, inTime, size, timeout: LONGINT;
		name: ARRAY pathlen OF CHAR;
		c: Connection;
		f: AosFS.File;
		smbf: SMBFile;
		isCreate: BOOLEAN;
		attrib, ats: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleOpenAndX"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		packet.flags := 80X;
		packet.flags2 := 1;
		wordCount := ORD(in.Get());
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.Char(andXCmd);
		INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		in.RawInt(flags);
		pos := pos + 2;
		in.RawInt(mode);
		pos := pos + 2;
		in.RawInt(sattr);
		pos := pos + 2;
		in.RawInt(attr);
		pos := pos + 2;
		in.RawLInt(inTime);
		pos := pos + 4;
		in.RawInt(ofun);
		pos := pos + 2;
		in.RawLInt(size);
		pos := pos + 4;
		in.RawLInt(timeout);
		pos := pos + 4;
		in.SkipBytes(4);
		pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		pos := pos + 2;
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		i := 0;
		WHILE c.share.root[i] # 0X DO
			name[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
			INC(pos);
		END;
		WHILE in.Peek() # 0X DO
			name[i] := in.Get();
			INC(i); INC(pos);
		END;
		name[i+1] := 0X;
		INC(pos);
		FlipDelimiter(name);
		]]></Span><Span style="Comment"><![CDATA[(* handle logic *)]]></Span><Span style="Normal"><![CDATA[
		IF ofun > 3 THEN
			isCreate := TRUE;
			GetDTFromSmbDT(inTime, date, time);
			ofun := ofun - 16;]]></Span><Span style="Comment"><![CDATA[ (* only bit 0 and 1 *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			isCreate := FALSE;
		END;
		f := AosFS.Old(name);
		IF ofun = 0 THEN
			IF f # NIL THEN
				SetError(ERRDOS, ERRfileexists);
				RETURN;
			ELSIF isCreate THEN
				]]></Span><Span style="Comment"><![CDATA[(* check permissions *)]]></Span><Span style="Normal"><![CDATA[
				IF ~(write IN c.user.permissions) THEN
					SetError(ERRDOS, ERRnoaccess);
					RETURN;
				END;
				f := AosFS.New(name);
				IF f = NIL THEN
					SetError(ERRDOS, ERRnoaccess);
					RETURN;
				END;
				action := 2;
				IF f IS AosFATFiles.File THEN
					attrib := SYSTEM.VAL(SET, attr);]]></Span><Span style="Comment"><![CDATA[ (* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
					IF LOG THEN
						AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
					END;
					f(AosFATFiles.File).SetAttributes(attrib);
				END;
				IF (time # 0) & (date # 0) THEN ]]></Span><Span style="Comment"><![CDATA[ (* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
					f.SetDate(time, date);
				END;
			ELSE
				SetError(ERRSRV, ERRerror);
				RETURN;
			END;
		ELSIF ofun = 1 THEN
			IF f = NIL THEN
				IF isCreate THEN
					IF ~(write IN c.user.permissions) THEN
						SetError(ERRDOS, ERRnoaccess);
						RETURN;
					END;
					f := AosFS.New(name);
					IF f = NIL THEN
						SetError(ERRDOS, ERRnoaccess);
						RETURN;
					END;
					action := 2;
					IF f IS AosFATFiles.File THEN
						attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
						IF LOG THEN
							AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
						END;
						f(AosFATFiles.File).SetAttributes(attrib);
					END;
					IF (time # 0) & (date # 0) THEN ]]></Span><Span style="Comment"><![CDATA[ (* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
						f.SetDate(time, date);
					END;
				ELSE
					SetError(ERRDOS, ERRbadfile);
					RETURN;
				END;
			ELSE
				action := 1;
			END;
		ELSIF ofun = 2 THEN
			IF f = NIL THEN
				IF isCreate THEN
					]]></Span><Span style="Comment"><![CDATA[(* check permissions *)]]></Span><Span style="Normal"><![CDATA[
					IF ~(write IN c.user.permissions) THEN
						SetError(ERRDOS, ERRnoaccess);
						RETURN;
					END;
					f := AosFS.New(name);
					IF f = NIL THEN
						SetError(ERRDOS, ERRnoaccess);
						RETURN;
					END;
					action := 2;
					IF f IS AosFATFiles.File THEN
						attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
						IF LOG THEN
							AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
						END;
						f(AosFATFiles.File).SetAttributes(attrib);
					END;
					IF (time # 0) & (date # 0) THEN ]]></Span><Span style="Comment"><![CDATA[ (* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
						f.SetDate(time, date);
					END;
				ELSE
					SetError(ERRDOS, ERRbadfile);
				END;
			ELSE
				]]></Span><Span style="Comment"><![CDATA[(* check permissions *)]]></Span><Span style="Normal"><![CDATA[
				IF ~(write IN c.user.permissions) THEN
					SetError(ERRDOS, ERRnoaccess);
					RETURN;
				END;
				AosFS.Delete(name, ec);
				IF ec # 0 THEN
					SetError(ERRDOS, ERRnoaccess);
					RETURN;
				END;
				f := AosFS.New(name);
				IF f = NIL THEN
					SetError(ERRDOS, ERRaccess);
					RETURN;
				END;
				action := 3;
				IF f IS AosFATFiles.File THEN
					attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
					IF LOG THEN
						AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
					END;
					f(AosFATFiles.File).SetAttributes(attrib);
				END;
				IF (time # 0) & (date # 0) THEN ]]></Span><Span style="Comment"><![CDATA[ (* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
					f.SetDate(time, date);
				END;
			END;
		ELSIF ofun = 3 THEN
			]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			SetError(ERRSRV, ERRnosupport);
			RETURN;
		END;
		IF f # NIL THEN
			IF action > 1 THEN
				AosFS.Register(f);
			END;
			NEW(smbf);
			smbf.file := f;
			smbf.next := c.files;
			c.files := smbf;
			smbf.fid := c.lastFID;
			INC(c.lastFID);
		ELSE
			SetError(ERRSRV, ERRerror);
			RETURN;
		END;
		IF LOG THEN
			f.GetName(name);
			AosOut.String("**File "); AosOut.String(name); AosOut.String(" opened."); AosOut.Ln();
		END;
		w.Char(CHR(15));]]></Span><Span style="Comment"><![CDATA[ (* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X);]]></Span><Span style="Comment"><![CDATA[ (* reserved *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			outOff := outOff +  30 + 3; 
			w.RawInt(SHORT(outOff));]]></Span><Span style="Comment"><![CDATA[ (* ANDX offset *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(smbf.fid);
		IF ~(write IN c.user.permissions) THEN
			attr := 1;
		ELSE
			attr := 0;
		END;
		IF AosFS.Directory IN f.flags THEN
			attr := attr + 10H;
		END;
		IF f IS AosFATFiles.File THEN
			ats := f(AosFATFiles.File).GetAttributes();
			IF (0 IN ats) & (write IN c.user.permissions)THEN
				attr := attr + 1;
			END;
			IF 1 IN ats THEN
				attr := attr + 2;
			END;
			IF 2 IN ats THEN
				attr := attr + 4;
			END;
			IF 3 IN ats THEN
				attr := attr + 8;
			END;
			IF 5 IN ats THEN
				attr := attr + 32;
			END;
		END;
		w.RawInt(attr);]]></Span><Span style="Comment"><![CDATA[ (* attributes *)]]></Span><Span style="Normal"><![CDATA[
		f.GetDate(time, date);
		w.RawLInt(GetDateTime(date, time));
		w.RawLInt(f.Length());
		IF ~(write IN c.user.permissions) THEN
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* read only *)]]></Span><Span style="Normal"><![CDATA[
		ELSIF ~(read IN c.user.permissions) THEN
			w.RawInt(1);]]></Span><Span style="Comment"><![CDATA[ (* write only *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(2); ]]></Span><Span style="Comment"><![CDATA[(* read/write *)]]></Span><Span style="Normal"><![CDATA[
		END;
		w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* type: file or directory *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* state of named pipe *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(action);
		w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawInt(0); (* reserved ? *)
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleOpenAndX;

	PROCEDURE HandleReadAndX(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		i, av: LONGINT;
		fOffset: LONGINT;
		wordCount, byteCount, fid, dataOffset, maxCount: INTEGER;
		fr: AosFS.Reader;
		c: Connection; f: SMBFile;
		buf: ARRAY buflen OF CHAR;
		max: LONGINT;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleReadAndX"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		packet.flags := 80X;
		packet.flags2 := 1;
		wordCount := ORD(in.Get());
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		andXCmd := in.Get(); INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		in.RawInt(fid);
		pos := pos + 2;
		in.RawLInt(fOffset);
		pos := pos + 4;
		in.RawInt(maxCount);
		pos := pos + 2;
		in.SkipBytes(2);
		pos := pos + 2;]]></Span><Span style="Comment"><![CDATA[ (* skip minCount *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(4);
		pos := pos + 4;]]></Span><Span style="Comment"><![CDATA[ (* skip maxCountHigh *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(2);
		pos := pos + 2; ]]></Span><Span style="Comment"><![CDATA[(* skip remaining *)]]></Span><Span style="Normal"><![CDATA[
		IF wordCount = 12 THEN
			in.SkipBytes(4);
			pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* skip offsetHigh *)]]></Span><Span style="Normal"><![CDATA[
		END;
		]]></Span><Span style="Comment"><![CDATA[(* handle logic *)]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Comment"><![CDATA[(* search file by tid _> fid and read bytes up to maxcount starting at fOffset *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		f := FindFile(fid, c);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* check access permissions *)]]></Span><Span style="Normal"><![CDATA[
		IF ~(read IN c.user.permissions) THEN
			SetError(ERRDOS, ERRbadaccess);
			RETURN;
		END;
		AosFS.OpenReader(fr, f.file, fOffset);
		]]></Span><Span style="Comment"><![CDATA[(* read MAX(cBufSize-30, maxCount, buflen) and retreive av, the nr. of bytes read *)]]></Span><Span style="Normal"><![CDATA[
		IF cBufSize-30 < maxCount THEN
			max := cBufSize-30;
		ELSE
			max := maxCount;
		END;
		IF buflen < max THEN
			max := buflen;
		END;
		fr.Bytes(buf, 0, max, av);
		dataOffset := SHORT(outOff + 27);
		w.Char(CHR(12)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			outOff := outOff +  24 + 3 + av; 
			w.RawInt(SHORT(outOff)); ]]></Span><Span style="Comment"><![CDATA[(* ANDX offset *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(-1);]]></Span><Span style="Comment"><![CDATA[ (* remaining: reserved, must be -1 *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0);  ]]></Span><Span style="Comment"><![CDATA[(* dataCompactionMode *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(SHORT(av)); ]]></Span><Span style="Comment"><![CDATA[(* low order length bytes *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(dataOffset);
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* no write-large-capability -> datalengthhigh is 0 *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(0); w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* 8 bytes reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(SHORT(av)); ]]></Span><Span style="Comment"><![CDATA[(* ByteCount *)]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Comment"><![CDATA[(* no pad *)
		(* write data *)]]></Span><Span style="Normal"><![CDATA[
		w.Bytes(buf, 0, av);
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleReadAndX;
	
	PROCEDURE HandleWriteAndX(offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		isAndX: BOOLEAN;
		andXCmd: CHAR;
		andXOff: INTEGER;
		i, av: LONGINT;
		fOffset, dataLength: LONGINT;
		fid, wordCount, byteCount, dataOffset, writeMode, remaining: INTEGER;
		fw: AosFS.Writer;
		c: Connection; f: SMBFile;
		dl1, dl2: INTEGER;
		buf: ARRAY buflen OF CHAR;
		ar, tr: LONGINT;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleWriteAndX"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		packet.flags := 80X;
		packet.flags2 := 1;
		wordCount := ORD(in.Get());
		INC(pos); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.Char(andXCmd); INC(pos);
		IF ORD(andXCmd) # 0FFH THEN
			isAndX := TRUE;
		ELSE
			isAndX := FALSE;
		END;
		in.SkipBytes(1);
		INC(pos);]]></Span><Span style="Comment"><![CDATA[ (* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(andXOff);
		pos := pos + 2;
		in.RawInt(fid);
		pos := pos + 2;
		in.RawLInt(fOffset);
		pos := pos + 4;
		in.SkipBytes(4);
		pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(writeMode);
		pos := pos + 2;
		in.RawInt(remaining);
		pos := pos + 2;
		]]></Span><Span style="Comment"><![CDATA[(* screwed up order of bytes -> 2 bytes high order as SHORT, then 2 low order as SHORT *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(dl1);
		in.RawInt(dl2);
		dataLength := dl2 + dl1*10000H;
		pos := pos + 4; 
		in.RawInt(dataOffset);
		pos := pos + 2;
		IF wordCount = 14 THEN
			in.SkipBytes(4);
			pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* ignore offsetHigh *)]]></Span><Span style="Normal"><![CDATA[
		END;
		in.RawInt(byteCount);
		pos := pos + 2;
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		f := FindFile(fid, c);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* check access permissions *)]]></Span><Span style="Normal"><![CDATA[
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRDOS, ERRbadaccess);
			RETURN;
		END;
		AosFS.OpenWriter(fw, f.file, fOffset);
		IF pos < dataOffset THEN
			in.SkipBytes(dataOffset - pos);
		END;
(* *)	pos := dataOffset; (* check this *)
		i := 0;
		WHILE dataLength > 0 DO
			IF dataLength > buflen THEN
				tr := buflen;
			ELSE 
				tr := dataLength;
			END;
			in.Bytes(buf, 0, tr, ar);
			fw.Bytes(buf, 0, ar);
			dataLength := dataLength - ar;
			pos := pos + ar;
			i := i + ar;
		END;
(* *)	fw.Update(); (* necessary ? *)
		IF writeMode > 0 THEN]]></Span><Span style="Comment"><![CDATA[ (* flush file to disk *)]]></Span><Span style="Normal"><![CDATA[
			f.file.Update();
		END;
		w.Char(CHR(6)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.Char(andXCmd);
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			outOff := outOff +  12 + 3; 
			w.RawInt(SHORT(outOff)); ]]></Span><Span style="Comment"><![CDATA[(* ANDX offset *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(0);
		END;
		w.RawInt(SHORT(i)); ]]></Span><Span style="Comment"><![CDATA[(* number of bytes written *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* remaining: reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
		IF isAndX THEN
			IF LOG THEN
				AosOut.String("--AndX-Command"); AosOut.Ln();
			END;
			Dispatch(andXCmd, andXOff, outOff, pos, in, w, out);
		END;
	END HandleWriteAndX;
	
	PROCEDURE HandleCreateDirectory(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		res, i: LONGINT;
		byteCount: INTEGER;
		name: ARRAY pathlen OF CHAR;
		c: Connection;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleCreateDirectory"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		in.SkipBytes(1);]]></Span><Span style="Comment"><![CDATA[ (* buffer format *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRHRD, ERRnowrite);
			RETURN;
		END;
		i := 0;
		WHILE c.share.root[i] # 0X DO
			name[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X DO
			name[i] := in.Get();
			INC(i);
		END;
		FlipDelimiter(name);
		IF LOG THEN
			AosOut.String("**Trying to create "); AosOut.String(name); AosOut.Ln();
		END;
		AosFS.CreateDirectory(name, res);
		IF res # 0 THEN
			SetError(ERRDOS, ERRnoaccess);
			RETURN;
		END;
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleCreateDirectory;
	
	PROCEDURE HandleRemoveDirectory(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		res, i: LONGINT;
		byteCount: INTEGER;
		name: ARRAY pathlen OF CHAR;
		c: Connection;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleRemoveDirectory"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* WordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* Buffer format *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRHRD, ERRnowrite);
			RETURN;
		END;
		i := 0;
		WHILE c.share.root[i] # 0X DO
			name[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X DO
			name[i] := in.Get();
			INC(i);
		END;
		FlipDelimiter(name);
		IF LOG THEN
			AosOut.String("** Trying to remove dir "); AosOut.String(name); AosOut.Ln();
		END;
		AosFS.RemoveDirectory(name, FALSE, res);
		IF res # 0 THEN
			SetError(ERRDOS, ERRnoaccess);
			RETURN;
		END;
		w.Char(0X);
		w.RawInt(0);
	END HandleRemoveDirectory;

	PROCEDURE HandleOpen(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		mode, byteCount, attr: INTEGER;
		size, date, time, i: LONGINT;
		name: ARRAY pathlen OF CHAR;
		c: Connection;
		f: AosFS.File;
		smbf: SMBFile;
		ats: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleOpen"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(mode);
		in.SkipBytes(2); ]]></Span><Span style="Comment"><![CDATA[(* ignore iattr *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* buffer format *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		i := 0;
		WHILE c.share.root[i] # 0X DO
			name[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X DO
			name[i] := in.Get();
			INC(i);
		END;
		name[i+1] := 0X;
		FlipDelimiter(name);
		IF LOG THEN
			AosOut.String("** try to open: "); AosOut.String(name); AosOut.Ln();
		END;
		f := AosFS.Old(name);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfile);
			RETURN;
		END;
		NEW(smbf);
		smbf.file := f;
		smbf.next := c.files;
		c.files := smbf;
		smbf.fid := c.lastFID;
		INC(c.lastFID);
		w.Char(CHR(7)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(smbf.fid);
		IF AosFS.Directory IN f.flags THEN ]]></Span><Span style="Comment"><![CDATA[(* is Directory *)]]></Span><Span style="Normal"><![CDATA[
			attr := 10H;
		ELSE
			attr := 0H;
		END;
		IF f IS AosFATFiles.File THEN
			ats := f(AosFATFiles.File).GetAttributes();
			IF (0 IN ats) & (write IN c.user.permissions) THEN ]]></Span><Span style="Comment"><![CDATA[(* make sure the readonly is not set twice *)]]></Span><Span style="Normal"><![CDATA[
				attr := attr + 1;
			END;
			IF 1 IN ats THEN
				attr := attr + 2;
			END;
			IF 2 IN ats THEN
				attr := attr + 4;
			END;
			IF 3 IN ats THEN
				attr := attr + 8;
			END;
			IF 5 IN ats THEN
				attr := attr + 32;
			END;
		END;
		IF ~(write IN c.user.permissions) THEN
			attr := attr + 1; ]]></Span><Span style="Comment"><![CDATA[(* read only *)]]></Span><Span style="Normal"><![CDATA[
		END;
		w.RawInt(attr);
		f.GetDate(time, date);
		w.RawLInt(GetDateTime(date, time));
		w.RawLInt(f.Length());
		IF ~(write IN c.user.permissions) THEN
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* read only *)]]></Span><Span style="Normal"><![CDATA[
		ELSIF ~(read IN c.user.permissions) THEN
			w.RawInt(1); ]]></Span><Span style="Comment"><![CDATA[(* write only *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			w.RawInt(2);]]></Span><Span style="Comment"><![CDATA[ (* read/write *)]]></Span><Span style="Normal"><![CDATA[
		END;
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleOpen;
	
	PROCEDURE HandleCreateORMkNew(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		smbf: SMBFile;
		f: AosFS.File;
		name: ARRAY pathlen OF CHAR;
		fTime, time, date, ec, i: LONGINT;
		byteCount, attr: INTEGER;
		attrib: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleCreateORMkNew"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(attr);
		in.RawLInt(fTime);
		in.RawInt(byteCount);
		in.SkipBytes(1);]]></Span><Span style="Comment"><![CDATA[ (* buffer format *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRDOS, ERRnoaccess);
			RETURN;
		END;
		i := 0;
		WHILE c.share.root[i] # 0X DO
			name[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X DO
			name[i] := in.Get();
			INC(i);
		END;
		name[i+1] := 0X;
		FlipDelimiter(name);
		IF LOG THEN
			AosOut.String("** Try to create file: "); AosOut.String(name); AosOut.Ln();
		END;
		f := AosFS.Old(name);
		IF f # NIL THEN
			IF packet.command = CHR(0FH) THEN
				SetError(ERRDOS, ERRfileexists);
				RETURN;
			END;
			IF LOG THEN
				AosOut.String("**exists already -> delete first"); AosOut.Ln();
			END;
			AosFS.Delete(name, ec);
			IF ec # 0 THEN
				SetError(ERRDOS, ERRaccess);
				RETURN;
			END;
		END;
		f := AosFS.New(name);
		IF f = NIL THEN
			SetError(ERRDOS, ERRaccess);
			RETURN;
		END;
		AosFS.Register(f);
		IF f IS AosFATFiles.File THEN
			attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
			END;
			f(AosFATFiles.File).SetAttributes(attrib);
		END;
		GetDTFromSmbDT(fTime, date, time);
		IF (time # 0) & (date # 0) THEN  ]]></Span><Span style="Comment"><![CDATA[(* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
			f.SetDate(time, date);
		END;
		NEW(smbf);
		smbf.file := f;
		smbf.next := c.files;
		c.files := smbf;
		smbf.fid := c.lastFID;
		INC(c.lastFID);
		w.Char(CHR(1)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(smbf.fid);
		w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleCreateORMkNew;
	
	PROCEDURE HandleFlush(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		f: SMBFile;
		fid: INTEGER;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleFlush"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(fid);
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF fid =  0FFFFH THEN
			f := c.files;
			WHILE f # NIL DO
				f.file.Update();
				f := f.next;
			END;
		ELSE
			f := FindFile(fid, c);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadfid);
				RETURN;
			END;
			f.file.Update();
		END;
		w.Char(CHR(0));]]></Span><Span style="Comment"><![CDATA[ (* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleFlush;
	
	PROCEDURE HandleDelete(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		fid: INTEGER;
		searchAttr, byteCount: INTEGER;
		i, ec: LONGINT;
		fileName: ARRAY pathlen OF CHAR;
		eName: ARRAY pathlen OF CHAR;
		fsFlags, eFlags: SET;
		eTime, eDate, eSize: LONGINT;
		enum: AosFS.Enumerator;
		success: BOOLEAN;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleDelete"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(searchAttr);
(*		searchAttributes are ignored at the moment *)
		in.RawInt(byteCount);
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* ignore bufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* check permissions *)]]></Span><Span style="Normal"><![CDATA[
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRSRV, ERRaccess);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* combine path *)]]></Span><Span style="Normal"><![CDATA[
		i := 0;
		WHILE c.share.root[i] # 0X DO
			fileName[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X (* j < byteCount-1*) DO
			fileName[i] := in.Get();
			INC(i);
		END;
		IF fileName[i] # 0X THEN
			fileName[i+1] := 0X;
		END;
		FlipDelimiter(fileName);
		]]></Span><Span style="Comment"><![CDATA[(* enable deleting with wildcards *)]]></Span><Span style="Normal"><![CDATA[
		NEW(enum);
		enum.Open(fileName, fsFlags);
		WHILE enum.HasMoreEntries() DO
			success := enum.GetEntry(eName, eFlags, eTime, eDate, eSize);
			AosFS.Delete(eName, ec);
			IF ec # 0 THEN
				IF LOG THEN
					AosOut.String("Error deleting: "); AosOut.String(eName); AosOut.Ln();
				END;
				SetError(ERRDOS, ERRbadfile);
				RETURN;
			ELSE
				IF LOG THEN
					AosOut.String(eName); AosOut.String(" deleted"); AosOut.Ln();
				END;
			END;
		END;
		w.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleDelete;
	
	PROCEDURE HandleRename(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		i, res, ar: LONGINT;
		attr: INTEGER;
		fileName, newName, oldname, oldpath, newname, newpath: ARRAY pathlen OF CHAR;
		fr: AosFS.Reader;
		fw: AosFS.Writer;
		of, nf: AosFS.File;
		buf: ARRAY buflen OF CHAR;
	BEGIN
		IF LOG THEN
			AosOut.String("HandleRename"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		IF pos  < offset THEN
			in.SkipBytes(offset - pos);
		END;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordcount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(attr);
	(* attr is ignored atm; it could be used for searching *)
		in.SkipBytes(2); ]]></Span><Span style="Comment"><![CDATA[(*wordCount*)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* bufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRHRD, ERRnowrite);
			RETURN;
		END;
		(* combine path *)
		i := 0;
		WHILE c.share.root[i] # 0X DO
			fileName[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\") DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X  DO
			fileName[i] := in.Get();
			INC(i);
		END;
		IF fileName[i] # 0X THEN
			fileName[i+1] := 0X;
		END;
		FlipDelimiter(fileName);
		i := 0; 
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* 0X *)]]></Span><Span style="Normal"><![CDATA[
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* bufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		WHILE c.share.root[i] # 0X DO
			newName[i] := c.share.root[i];
			INC(i);
		END;
		WHILE (in.Peek() = "/") OR (in.Peek() = "\")DO
			in.SkipBytes(1);
		END;
		WHILE in.Peek() # 0X  DO
			newName[i] := in.Get();
			INC(i);
		END;
		IF newName[i] # 0X THEN
			newName[i+1] := 0X;
		END;
		FlipDelimiter(newName);
		IF LOG THEN
			AosOut.String("**Rename '"); AosOut.String(fileName); AosOut.String("' to '"); AosOut.String(newName); AosOut.String("'"); AosOut.Ln();
		END;
		AosFS.SplitPath(fileName, oldpath, oldname);
		AosFS.SplitPath(newName, newpath, newname);
		IF oldpath = newpath THEN
			AosFS.Rename(fileName, newName, res);
			IF (res = 2926) OR (res = 2) THEN ]]></Span><Span style="Comment"><![CDATA[(*file not found*]]></Span><Span style="Normal"><![CDATA[)
				SetError(ERRDOS, ERRbadfile);
				RETURN;
			ELSIF res = 2923 THEN
				SetError(ERRDOS, ERRbadpath);
				RETURN;
			ELSIF res = 2905 THEN ]]></Span><Span style="Comment"><![CDATA[(* readonly *)]]></Span><Span style="Normal"><![CDATA[
				SetError(ERRHRD, ERRnowrite);
				RETURN;
			ELSIF res # 0 THEN
				IF LOG THEN
					AosOut.String("** ERROR res is: "); AosOut.Int(res, 5); AosOut.Ln();
				END;
				SetError(ERRSRV, ERRerror);
				RETURN;
			END;
		ELSE ]]></Span><Span style="Comment"><![CDATA[(* copy by hand *)]]></Span><Span style="Normal"><![CDATA[
			of := AosFS.Old(fileName);
			nf := AosFS.New(newName);
			AosFS.Register(nf);
			AosFS.OpenReader(fr, of ,0);
			AosFS.OpenWriter(fw, nf, 0);
			ar := 1; (* precondition for loop *)
			WHILE ar > 0 DO
				fr.Bytes(buf, 0, buflen, ar);
				fw.Bytes(buf, 0, ar);
			END;
			fw.Update();
			AosFS.Delete(fileName, ar);
		END;
		w.Char(0X);]]></Span><Span style="Comment"><![CDATA[ (* wordcount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount*)]]></Span><Span style="Normal"><![CDATA[
	END HandleRename;
		
	PROCEDURE HandleWriteAndClose(in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		f, prev: SMBFile;
		fid, wordCount, ct: INTEGER;
		count, off, fTime, time, date, i: LONGINT;
		buf: ARRAY buflen OF CHAR;
		fw: AosFS.Writer;
		ar, tr: LONGINT;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleWriteAndClose"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		wordCount := ORD(in.Get());
		in.RawInt(fid);
		in.RawInt(ct);
		count := ct;
		in.RawLInt(off);
		in.RawLInt(fTime);
		IF wordCount = 12 THEN
			in.SkipBytes(12);
		END;
		in.SkipBytes(3); ]]></Span><Span style="Comment"><![CDATA[ (* byteCount and Pad *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		f := FindFile(fid, c);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* check access permissions *)]]></Span><Span style="Normal"><![CDATA[
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRDOS, ERRbadaccess);
			RETURN;
		END;
		AosFS.OpenWriter(fw, f.file, off);
		i := 0;
		WHILE count > 0 DO
			IF count > buflen THEN
				tr := buflen;
			ELSE
				tr := count;
			END;
			in.Bytes(buf, 0, tr, ar);
			fw.Bytes(buf, 0, ar);
			count := count - ar;
			i := i + ar;
		END;
		fw.Update();
		GetDTFromSmbDT(fTime, date, time);
		IF (time # 0) & (date # 0) THEN ]]></Span><Span style="Comment"><![CDATA[ (* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
			f.file.SetDate(time, date);
		END;
		f.file.Update();
		]]></Span><Span style="Comment"><![CDATA[(* remove file from connection *)]]></Span><Span style="Normal"><![CDATA[
		f := c.files; prev := NIL;
		WHILE f #NIL DO
			IF f.fid = fid THEN
				IF prev = NIL THEN
					c.files := f.next;
				ELSE
					prev.next := f.next;
				END;
			END;
			prev := f; f := f.next;
		END;
		w.Char(CHR(1));
		w.RawInt(SHORT(i));
		w.RawInt(0);
	END HandleWriteAndClose;
	
	PROCEDURE HandleQueryInformation(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		f: AosFS.File;
		fid: INTEGER;
		i: LONGINT;
		byteCount: INTEGER;
		fileName: ARRAY pathlen OF CHAR;
		time, date: LONGINT;
		attr: INTEGER;;
		ats: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleQueryInformation"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* skip wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* ignore bufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* combine path *)]]></Span><Span style="Normal"><![CDATA[
		i := 0;
		WHILE c.share.root[i] # 0X DO
			fileName[i] := c.share.root[i];
			INC(i);
		END;
		WHILE in.Peek() # 0X DO
			fileName[i] := in.Get();
			INC(i);
		END;
		fileName[i+1] := 0X;
		FlipDelimiter(fileName);
		IF LOG THEN			
			AosOut.String("**Information about "); AosOut.String(fileName); AosOut.Ln();
		END;
		f := AosFS.Old(fileName);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfile);
			RETURN;
		END;
		f.GetDate(time, date);
		IF f IS AosFATFiles.File THEN
			ats := f(AosFATFiles.File).GetAttributes();
			IF 0 IN ats THEN
				attr := attr + 1;
			END;
			IF 1 IN ats THEN
				attr := attr + 2;
			END;
			IF 2 IN ats THEN
				attr := attr + 4;
			END;
			IF 3 IN ats THEN
				attr := attr + 8;
			END;
			IF 4 IN ats THEN
				attr := attr + 16;
			END;
			IF 5 IN ats THEN
				attr := attr + 32;
			END;
		END;
		w.Char(CHR(10)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[		
		w.RawInt(attr);]]></Span><Span style="Comment"><![CDATA[ (* attribute *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(GetDateTime(date, time));]]></Span><Span style="Comment"><![CDATA[ (* date & time as samba time *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(f.Length()); ]]></Span><Span style="Comment"><![CDATA[(* file length *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(0); w.RawLInt(0); w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleQueryInformation;
	
	PROCEDURE HandleSetInformation(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		attr, byteCount: INTEGER;
		time, date, modifyDT, i: LONGINT;
		c: Connection;
		f: AosFS.File;
		fileName: ARRAY pathlen OF CHAR;
		attrib: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleSetInformation"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* skip wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(attr);
		in.RawLInt(modifyDT);
		in.SkipBytes(5); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(byteCount);
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* ignore bufferFormat *)]]></Span><Span style="Normal"><![CDATA[
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* combine path *)]]></Span><Span style="Normal"><![CDATA[
		i := 0;
		WHILE c.share.root[i] # 0X DO
			fileName[i] := c.share.root[i];
			INC(i);
		END;
		WHILE in.Peek() # 0X DO
			fileName[i] := in.Get();
			INC(i);
		END;
		fileName[i + 1] := 0X;
		FlipDelimiter(fileName);
		IF LOG THEN			
			AosOut.String("**Set information of "); AosOut.String(fileName); AosOut.Ln();
		END;
		f := AosFS.Old(fileName);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfile);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRSRV, ERRaccess);
			RETURN;
		END;
		IF f IS AosFATFiles.File THEN
			attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
			END;
			f(AosFATFiles.File).SetAttributes(attrib);
		END;
		GetDTFromSmbDT(modifyDT, date, time);
		IF (time # 0) & (date # 0) THEN  ]]></Span><Span style="Comment"><![CDATA[(* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
			f.SetDate(time, date);
		END;
		w.Char(0X);
		w.RawInt(0);
	END HandleSetInformation;
	
	PROCEDURE HandleQueryInformation2(offset, pos: LONGINT; in: AosIO.Reader; w: AosIO.Writer);
	VAR
		c: Connection;
		f: SMBFile;
		fid: INTEGER;
		time, date: LONGINT;
		tdate: Utilities.TDateTime;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleQueryInformation2"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* skip wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(fid);
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		f := FindFile(fid, c);
		IF f = NIL THEN
			SetError(ERRDOS, ERRbadfid);
			RETURN;
		END;
		f.file.GetDate(time, date);
		w.Char(CHR(11));]]></Span><Span style="Comment"><![CDATA[ (* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(GetDateTime(date, time)); ]]></Span><Span style="Comment"><![CDATA[(* c smbtime *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(GetDateTime(date, time)); ]]></Span><Span style="Comment"><![CDATA[(* a smbtime *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(GetDateTime(date, time)); ]]></Span><Span style="Comment"><![CDATA[(* m smbtime *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(f.file.Length()); ]]></Span><Span style="Comment"><![CDATA[(* file length *)]]></Span><Span style="Normal"><![CDATA[
		w.RawLInt(f.file.Length()); ]]></Span><Span style="Comment"><![CDATA[(* file alloc length *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* attributes *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleQueryInformation2;
	
	PROCEDURE HandleQueryInformationDisk(w: AosIO.Writer);
	VAR
		c: Connection;
		fs: AosFS.FileSystem;
		fsn: ARRAY pathlen OF CHAR;
		i: LONGINT;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleQueryInformationDisk"); AosOut.Ln(	);
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
		END;
		i := 0;
		WHILE (c.share.root[i] # 0X) & (c.share.root[i] # ':') DO
			fsn[i] := c.share.root[i];
			INC(i);
		END;
		fs := AosFS.This(fsn);
		IF fs = NIL THEN
			IF LOG THEN
				AosOut.String("## ERROR fs not found"); AosOut.Ln();
			END;
			SetError(ERRSRV, ERRinvdevice);
			RETURN;
		END;
		w.Char(CHR(5)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(SHORT(fs.vol.size)); ]]></Span><Span style="Comment"><![CDATA[(* no. allocation units *)]]></Span><Span style="Normal"><![CDATA[
(* *)	w.RawInt(1); (* 1 block per allocation unit. Senseful?? *)
		w.RawInt(SHORT(fs.vol.blockSize)); ]]></Span><Span style="Comment"><![CDATA[(* blocksize *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(SHORT(fs.vol.Available()));
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleQueryInformationDisk;
	
	PROCEDURE HandleSetInformation2(offset, pos: LONGINT; in: AosIO.Reader; w:AosIO.Writer);
	VAR
		createDT, accessDT, modifyDT, time, date: LONGINT;
		fid: INTEGER;
		smbf: SMBFile;
		c: Connection;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleSetInformation2"); AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		in.SkipBytes(1); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(fid);
		in.RawLInt(createDT);
		in.RawLInt(accessDT);
		in.RawLInt(modifyDT);
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN;
		END;
		smbf := FindFile(fid, c);
		IF smbf = NIL THEN
			SetError(ERRDOS, ERRbadfid);
			RETURN;
		END;
		IF ~(write IN c.user.permissions) THEN
			SetError(ERRSRV, ERRaccess);
			RETURN;
		END;
		IF modifyDT = 0 THEN
			modifyDT := accessDT;
		END;
		IF modifyDT = 0 THEN
			modifyDT := createDT;
		END;
		GetDTFromSmbDT(modifyDT, date, time);
		IF (time # 0) & (date # 0) THEN  ]]></Span><Span style="Comment"><![CDATA[(* only set time and date if valid *)]]></Span><Span style="Normal"><![CDATA[
			smbf.file.SetDate(time, date);
		END;
		w.Char(CHR(0)); ]]></Span><Span style="Comment"><![CDATA[(* wordCount *)]]></Span><Span style="Normal"><![CDATA[
		w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *)]]></Span><Span style="Normal"><![CDATA[
	END HandleSetInformation2;
	
	PROCEDURE HandleTrans2(offset, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	VAR
		i: LONGINT;
		wordCount, byteCount, tpsCnt, tdsCnt, mprCnt, mdrCnt, msrCnt, flags, psCnt, psOff, dsCnt, dsOff, suwCnt, setup: INTEGER;
		timeout: LONGINT;
		data: AosIO.Writer;
		t: Trans2;
		ch: CHAR;
		zs: INTEGER;
	BEGIN
		IF LOG THEN
			AosOut.String("--HandleTrans2");AosOut.Ln();
		END;
		IF pos < offset THEN
			in.SkipBytes(offset - pos);
		END;
		pos := offset;
		packet.flags := 80X;
		packet.flags2 := 1;
		wordCount := ORD(in.Get());
		INC(pos);
		in.RawInt(tpsCnt);
		pos := pos + 2;
		in.RawInt(tdsCnt);
		pos := pos + 2;
		in.RawInt(mprCnt);
		pos := pos + 2;
		in.RawInt(mdrCnt);
		pos := pos + 2;
		in.RawInt(msrCnt);
		pos := pos + 2;
		in.RawInt(flags);
		pos := pos + 2;
		in.RawLInt(timeout);
		pos := pos + 4;
		in.SkipBytes(2);
		pos := pos + 2; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
		in.RawInt(psCnt);
		pos := pos + 2;
		in.RawInt(psOff);
		pos := pos + 2;
		in.RawInt(dsCnt);
		pos := pos + 2;
		in.RawInt(dsOff);
		pos := pos + 2;
		in.RawInt(suwCnt);
		pos := pos + 2;
		IF suwCnt = 1 THEN
			in.RawInt(setup);
			pos := pos + 2;
		END;
		in.SkipBytes(2); ]]></Span><Span style="Comment"><![CDATA[(* byteCount *);]]></Span><Span style="Normal"><![CDATA[
		pos := pos + 2;
		NEW(t); (* necessary? *)
		t.next := trans2s;
		trans2s := t;
		t.setup := setup;
		t.tpCount := tpsCnt; ]]></Span><Span style="Comment"><![CDATA[(* total param bytes *)]]></Span><Span style="Normal"><![CDATA[
		t.tdCount := tdsCnt;]]></Span><Span style="Comment"><![CDATA[ (* total data bytes *)]]></Span><Span style="Normal"><![CDATA[
		t.mdCount := mdrCnt;
		t.flags := flags;
		NEW(t.dataBuffer, 0);
		data := t.dataBuffer.GetWriter();
		(* read in params *)
		IF pos < psOff THEN
			in.SkipBytes(psOff - pos);
		END; 
		pos := psOff; i := 0;
		WHILE i < psCnt DO
			data.Char(in.Get());
			INC(i); INC(pos);
		END;
		]]></Span><Span style="Comment"><![CDATA[(* read in data *)]]></Span><Span style="Normal"><![CDATA[
		IF pos < dsOff THEN
			in.SkipBytes(dsOff - pos);
		END;
		pos := dsOff; i := 0;
		WHILE i < dsCnt DO
			data.Char(in.Get());
			INC(pos); INC(i);
		END;
		IF (tpsCnt > psCnt) OR (tdsCnt > dsCnt) THEN
			IF LOG THEN
				AosOut.String("Send interim message"); AosOut.Ln();
			END;
			w.Char(CHR(0));]]></Span><Span style="Comment"><![CDATA[ (* WordCount *)]]></Span><Span style="Normal"><![CDATA[
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* ByteCount *)]]></Span><Span style="Normal"><![CDATA[
		ELSE
			]]></Span><Span style="Comment"><![CDATA[(* handleLogic *)]]></Span><Span style="Normal"><![CDATA[
			Trans2Logic(t, w, out);
			packet.skipSend := TRUE; ]]></Span><Span style="Comment"><![CDATA[(* all packets are sent in Trans2Logic *) ]]></Span><Span style="Normal"><![CDATA[
		END;
	END HandleTrans2;
	
	PROCEDURE HandleNotSupported();
	BEGIN
		IF LOG THEN
			AosOut.String("--Command 0x"); AosOut.Hex(ORD(packet.command), -1); AosOut.String(" not supported"); AosOut.Ln();
		END;
		packet.flags := 80X;
		packet.flags2 := 1;
		SetError(ERRSRV, ERRnosupport);
	END HandleNotSupported;
	
	]]></Span><Span style="Comment"><![CDATA[(* is called if the Trans2 is complete. Handles the whole logic and sends as many packets back as necessary *)]]></Span><Span style="Normal"><![CDATA[
	PROCEDURE Trans2Logic(t: Trans2; w, out: AosIO.Writer);
	VAR 
		buf: Utilities.String;
		pos, i, j: LONGINT;
		c: Connection;
		name, fName: ARRAY pathlen OF CHAR;
		outParam: ARRAY 24 OF INTEGER;
		f: AosFS.File;
		sf: SMBFile;
		enum: AosFS.Enumerator;
		outData: Utilities.Buffer;
		data: AosIO.Writer;
		eName: ARRAY namelen OF CHAR;
		eFlags, fsFlags: SET;
		eTime, eDate, eSize, date, time: LONGINT;
		success: BOOLEAN;
		ind, nOfNames, accMode, nl: LONGINT;
		sTime: ARRAY 2 OF LONGINT;
		setup, searchCnt, infoLevel, sFlags, dirHandle, fid, wordCount, byteCount, attr: INTEGER;
		tprCnt, tdrCnt, prCnt, prOff, prDisp, drCnt, drOff, drDisp, suwCnt: INTEGER;
		special, done, multiple: BOOLEAN;
		dataLength, dataOffset: INTEGER;
		flagS, ats, attrib: SET;
	BEGIN
		IF LOG THEN
			AosOut.String("HandleLogic"); AosOut.Ln();
		END;
		setup := t.setup;
		NEW(outData, 0);
		data := outData.GetWriter();
		buf := t.dataBuffer.GetString();
		IF LOG THEN
			AosOut.String("**command 0x"); AosOut.Hex(setup, -1); AosOut.Ln();
		END;
		IF setup = 0 THEN
			]]></Span><Span style="Comment"><![CDATA[(* open *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN
		ELSIF setup = 1 THEN ]]></Span><Span style="Comment"><![CDATA[(* findfirst *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				AosOut.String("**FindFirst"); AosOut.Ln();
			END;
			pos := 0;
			attr := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			searchCnt := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			sFlags := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			]]></Span><Span style="Comment"><![CDATA[(* transform flags to a set *)]]></Span><Span style="Normal"><![CDATA[
			flagS := SYSTEM.VAL(SET, sFlags);
			infoLevel := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
			c := FindConnection(packet.TID);
			IF c = NIL THEN
				SetError(ERRSRV, ERRinvtid);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			WHILE (buf[pos] = "/") OR (buf[pos] = "\") DO
				INC(pos);
			END;
			i := 0;
			WHILE c.share.root[i] # 0X DO
				name[i] := c.share.root[i];
				INC(i);
			END;
			j := 0;
			WHILE buf[pos] # 0X DO
				name[i] := buf[pos];
				fName[j] := buf[pos];
				INC(i); INC(pos);INC(j);
			END;
			name[i] := 0X; fName[j] := 0X;
			FlipDelimiter(name);
			IF LOG THEN
				AosOut.String("search for '"); AosOut.String(name); AosOut.String("'."); AosOut.Ln();
			END;
			NEW(enum);
			INCL(fsFlags, AosFS.EnumTime); INCL(fsFlags, AosFS.EnumSize);
			enum.Open(name, fsFlags);
			ind := 0; nOfNames := 0;
			WHILE (enum.HasMoreEntries()) & (nOfNames < searchCnt) DO
				success := enum.GetEntry(eName, eFlags, eTime, eDate, eSize);
				IF success THEN
					i := 0; j := 0;
					WHILE eName[j] # 0X DO
						IF (eName[j] = '/') OR (eName[j] = ':') THEN i := j+1; END; INC(j);
					END;
					nl := Utilities.Length(eName) - i;
					IF (infoLevel = 1) OR (infoLevel = 2) THEN ]]></Span><Span style="Comment"><![CDATA[(* INFO_STANDARD, INFO_QUERY_EA_SIZE *)]]></Span><Span style="Normal"><![CDATA[
						IF 2 IN flagS THEN
							data.RawLInt(rkey); INC(rkey); ]]></Span><Span style="Comment"><![CDATA[(* unique resume key *)]]></Span><Span style="Normal"><![CDATA[
						END;
						data.RawLInt(GetDateTime(eDate, eTime));]]></Span><Span style="Comment"><![CDATA[ (* creation time & date *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(GetDateTime(eDate, eTime)); ]]></Span><Span style="Comment"><![CDATA[(* last access time & date *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(GetDateTime(eDate, eTime)); ]]></Span><Span style="Comment"><![CDATA[(* last write time & date *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(eSize);]]></Span><Span style="Comment"><![CDATA[ (* data size *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* alloc size *)]]></Span><Span style="Normal"><![CDATA[
						IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
							attr := 10H;
						ELSE
							attr := 0;
						END;
						data.RawInt(attr); ]]></Span><Span style="Comment"><![CDATA[(* attributes *)]]></Span><Span style="Normal"><![CDATA[
						IF infoLevel = 2 THEN
							data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* size of EA Information *)]]></Span><Span style="Normal"><![CDATA[
							ind := ind + 2;
						END;
						data.Char(CHR(nl));
						WHILE i < Utilities.Length(eName) + 1 DO
							data.Char(eName[i]); INC(i);
						END;
						ind := ind + 27 + nl + 1;
						INC(nOfNames);
					ELSIF infoLevel = 260 THEN ]]></Span><Span style="Comment"><![CDATA[(* BOTH_DIRECTORY_INFO *)]]></Span><Span style="Normal"><![CDATA[
						IF 2 IN flagS THEN
							data.RawLInt(rkey); INC(rkey);]]></Span><Span style="Comment"><![CDATA[ (* unique resume key *)]]></Span><Span style="Normal"><![CDATA[
						END;
						data.RawLInt(94 + nl + 1 ]]></Span><Span style="Comment"><![CDATA[(* 0X at end of name *)]]></Span><Span style="Normal"><![CDATA[); ]]></Span><Span style="Comment"><![CDATA[(* offset to next record *)]]></Span><Span style="Normal"><![CDATA[
(* *)					data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* FileIndex *)]]></Span><Span style="Normal"><![CDATA[
						GetSambaTime(Utilities.OberonToDateTime(eDate, eTime), sTime);
						data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* creation time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last access date & time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[1]);]]></Span><Span style="Comment"><![CDATA[ (* second part of time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last write date & time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last change date & time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(sTime[1]);]]></Span><Span style="Comment"><![CDATA[ (* second part of time *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* fileSize as large_int *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of fileSize *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* file allocation size as large_int *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(0);]]></Span><Span style="Comment"><![CDATA[ (* second part of allocation size *)]]></Span><Span style="Normal"><![CDATA[
						IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
							data.RawLInt(10H);]]></Span><Span style="Comment"><![CDATA[ (* attributes *)]]></Span><Span style="Normal"><![CDATA[
						ELSE
							data.RawLInt(0);
						END;
						data.RawLInt(nl);
						data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* EA size *)]]></Span><Span style="Normal"><![CDATA[
						data.Char(CHR(0)); ]]></Span><Span style="Comment"><![CDATA[(* short Name Length *)]]></Span><Span style="Normal"><![CDATA[
						data.Char(0X); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
						data.RawLInt(0); data.RawLInt(0); data.RawLInt(0); data.RawLInt(0); data.RawLInt(0); data.RawLInt(0);]]></Span><Span style="Comment"><![CDATA[ (* 12 2b-word short name *)]]></Span><Span style="Normal"><![CDATA[
						ind := ind + 94 + nl + 1;
						WHILE i < Utilities.Length(eName) + 1 DO
							data.Char(eName[i]); INC(i);
						END;
						INC(nOfNames);
					END;
				END;
			END;
			IF LOG THEN
				AosOut.Int(nOfNames, 5); AosOut.String(" files found"); AosOut.Ln();
			END;
			IF nOfNames < 1 THEN
(* *)			SetError(ERRDOS, ERRbadfile); ]]></Span><Span style="Comment"><![CDATA[(* according to SNIA there should be returned
					an error if no file was found. The code is more or less guessed out of jCIFS, because
					there's no such error as SNIA wants: ERROR_FILE_NOT_FOUND *)]]></Span><Span style="Normal"><![CDATA[
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF enum.HasMoreEntries() THEN outParam[2] := 0; ELSE outParam[2] := 1 END; (* set endOfSearch *)
			outParam[1] := SHORT(nOfNames);
(* *)		dirHandle := 5; (* set to an intelligent value *)
			outParam[0] := dirHandle;
			outParam[3] := 0; ]]></Span><Span style="Comment"><![CDATA[(* no EA ErrorOffset *)]]></Span><Span style="Normal"><![CDATA[
(*			outParam[4] := SHORT(ind - nl); ]]></Span><Span style="Comment"><![CDATA[(* offset to last name *) ]]></Span><Span style="Normal"><![CDATA[*) (* assume name is not used for further search -> 0 *)
			outParam[4] := 0;
			wordCount := 10;
			tprCnt := 10;
			tdrCnt := SHORT(ind);
			prCnt := 10;
			prOff := 32 + 3 + 20;
			prDisp := 0;
			drCnt := SHORT(ind);
			drOff := prOff + 10;
			drDisp := 0;
			suwCnt := 0;		
		ELSIF setup = 2 THEN
			]]></Span><Span style="Comment"><![CDATA[(* findnext *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN
		ELSIF setup = 3 THEN
			]]></Span><Span style="Comment"><![CDATA[(* QFSInfo *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN;
		ELSIF setup = 4 THEN
			]]></Span><Span style="Comment"><![CDATA[(* setFSInfo *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN;
		ELSIF (setup = 5) OR (setup = 7) THEN
			]]></Span><Span style="Comment"><![CDATA[(* QPathInfo and QFileInfo *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				IF setup = 7 THEN 
					AosOut.String("**QueryFileInformation"); AosOut.Ln();
				ELSE
					AosOut.String("**QueryPathInformation"); AosOut.Ln();
				END;
			END;
			pos := 0;
			IF setup = 7 THEN
				fid := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
				pos := pos + 2;
			END;
			infoLevel := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
			c := FindConnection(packet.TID);
			IF c = NIL THEN
				SetError(ERRSRV, ERRinvtid);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF setup = 7 THEN
				sf := FindFile(fid, c);
				IF sf = NIL THEN
					SetError(ERRDOS, ERRbadfile);
					packet.Serialize(out);
					out.Update();
					RETURN;
				END;
				sf.file.GetName(name);
				fName := "nonempty";
				f := sf.file;
				IF LOG THEN
					AosOut.String("Information about FID: "); AosOut.Int(fid, 5); AosOut.Ln();
				END;
			ELSE
				f := NIL;
				WHILE (buf[pos] = "/") OR (buf[pos] = "\") DO
					INC(pos);
				END;
				i := 0;
				WHILE c.share.root[i] # 0X DO
					name[i] := c.share.root[i];
					INC(i);
				END;
				j := 0;
				WHILE buf[pos] # 0X DO
					name[i] := buf[pos];
					fName[j] := buf[pos];
					INC(i); INC(pos);INC(j);
				END;
				name[i] := 0X; INC(i);
				fName[j] := 0X;
				FlipDelimiter(name);
				IF name[i-2] = '/' THEN
					name[i-2] := 0X; DEC(i);
				END;
				IF LOG THEN
					AosOut.String("Information about '"); AosOut.String(name); AosOut.String("'."); AosOut.Ln();
				END;
			END;
			]]></Span><Span style="Comment"><![CDATA[(* 	Handle directories (especially the root one) *)]]></Span><Span style="Normal"><![CDATA[
			special := FALSE;
			IF (fName = ".") OR (fName = "") THEN ]]></Span><Span style="Comment"><![CDATA[(* info about the root is desired *)]]></Span><Span style="Normal"><![CDATA[
				IF LOG THEN
					AosOut.String("-> Info about root directory"); AosOut.Ln();
				END;
				eTime := 0; eDate := 0; eSize := 0;
				special := TRUE;
			END;
			IF special = FALSE THEN
				IF f = NIL THEN
					f := AosFS.Old(name);
				END;
				IF f = NIL THEN
					IF LOG THEN
						AosOut.String("File not Found"); AosOut.Ln();
					END;
					SetError(ERRDOS, ERRbadfile);
					packet.Serialize(out);
					out.Update();
					RETURN;
				END;
				f.GetDate(eTime, eDate);
				eSize := f.Length();
				f.GetName(eName);
				eFlags := f.flags;
			ELSE
				INCL(eFlags, AosFS.Directory);]]></Span><Span style="Comment"><![CDATA[ (* is a Directory *)]]></Span><Span style="Normal"><![CDATA[
				eDate := 0; eTime := 0; eSize := 0; COPY(name, eName);
			END;
			i := 0; j := 0;
			WHILE eName[j] # 0X DO
				IF eName[j] = '/' THEN i := j+1; END; INC(j);
			END;
			nl := Utilities.Length(eName) - i;
			IF LOG THEN
				AosOut.String("File found: "); AosOut.String(eName); AosOut.Ln();
			END;
			IF (infoLevel = 1) OR (infoLevel = 2) THEN (* INFO_STANDARD, INFO_QUERY_EA_SIZE *)
				data.RawLInt(GetDateTime(eDate, eTime)); ]]></Span><Span style="Comment"><![CDATA[(* creation date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(GetDateTime(eDate, eTime)); ]]></Span><Span style="Comment"><![CDATA[(* last access date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(GetDateTime(eDate, eTime)); ]]></Span><Span style="Comment"><![CDATA[(* last write date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* data size *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* alloc size *)]]></Span><Span style="Normal"><![CDATA[
				IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
					attr := attr + 10H;
				END;				
				IF (f # NIL) & (f IS AosFATFiles.File) THEN
					ats := f(AosFATFiles.File).GetAttributes();
					IF 0 IN ats THEN
						attr := attr + 1;
					END;
					IF 1 IN ats THEN
						attr := attr + 2;
					END;
					IF 2 IN ats THEN
						attr := attr + 4;
					END;
					IF 3 IN ats THEN
						attr := attr + 8;
					END;
					IF 5 IN ats THEN
						attr := attr + 32;
					END;
				END;
				data.RawInt(attr); ]]></Span><Span style="Comment"><![CDATA[(* attributes *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* EA size *)]]></Span><Span style="Normal"><![CDATA[
				ind := ind + 26;
			ELSIF infoLevel = 257 THEN ]]></Span><Span style="Comment"><![CDATA[(* QUERY_FILE_BASIC_INFO *)]]></Span><Span style="Normal"><![CDATA[
				GetSambaTime(Utilities.OberonToDateTime(eDate, eTime), sTime);
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* creation time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last access date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last write date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last change date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
					attr := attr + 10H;
				END;
				IF (f # NIL) & (f IS AosFATFiles.File) THEN
					ats := f(AosFATFiles.File).GetAttributes();
					IF 0 IN ats THEN
						attr := attr + 1;
					END;
					IF 1 IN ats THEN
						attr := attr + 2;
					END;
					IF 2 IN ats THEN
						attr := attr + 4;
					END;
					IF 3 IN ats THEN
						attr := attr + 8;
					END;
					IF 5 IN ats THEN
						attr := attr + 32;
					END;
				END;
				data.RawLInt(attr);
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* pad *)]]></Span><Span style="Normal"><![CDATA[
				ind := ind + 40;
			ELSIF infoLevel = 258 THEN ]]></Span><Span style="Comment"><![CDATA[(* QUERY_FILE_STANDARD_INFO *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* data size as large_int *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of data size *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(eSize);]]></Span><Span style="Comment"><![CDATA[ (* allocation Size *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of alloc size *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(1); ]]></Span><Span style="Comment"><![CDATA[(* no. of Links *)]]></Span><Span style="Normal"><![CDATA[
				data.Char(CHR(0)); ]]></Span><Span style="Comment"><![CDATA[(* no delete pending *)]]></Span><Span style="Normal"><![CDATA[
				IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
					data.Char(CHR(1));
				ELSE
					data.Char(CHR(0));
				END;
				IF (f # NIL) & (f IS AosFATFiles.File) THEN
					ats := f(AosFATFiles.File).GetAttributes();
					IF 0 IN ats THEN
						attr := attr + 1;
					END;
					IF 1 IN ats THEN
						attr := attr + 2;
					END;
					IF 2 IN ats THEN
						attr := attr + 4;
					END;
					IF 3 IN ats THEN
						attr := attr + 8;
					END;
					IF 5 IN ats THEN
						attr := attr + 32;
					END;
				END;
				ind := ind + 22;
			ELSIF infoLevel = 259 THEN]]></Span><Span style="Comment"><![CDATA[ (* QUERY_FILE_EA_INFO *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* no EA available *)]]></Span><Span style="Normal"><![CDATA[
				ind := ind + 4;
			ELSIF infoLevel = 260 THEN ]]></Span><Span style="Comment"><![CDATA[(* QUERY_FILE_NAME_INFO *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(nl);]]></Span><Span style="Comment"><![CDATA[ (* length of name *)]]></Span><Span style="Normal"><![CDATA[
				ind := ind + 4 + nl + 1;
				WHILE i < Utilities.Length(eName) + 1 DO
					data.Char(eName[i]); INC(i);
				END;
			ELSIF infoLevel = 263 THEN ]]></Span><Span style="Comment"><![CDATA[(* QUERY_FILE_ALL_INFO *)]]></Span><Span style="Normal"><![CDATA[
				GetSambaTime(Utilities.OberonToDateTime(eDate, eTime), sTime);				
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* creation time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last access date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]); ]]></Span><Span style="Comment"><![CDATA[(* last write date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[0]);]]></Span><Span style="Comment"><![CDATA[ (* last change date & time *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(sTime[1]); ]]></Span><Span style="Comment"><![CDATA[(* second part of time *)]]></Span><Span style="Normal"><![CDATA[
				IF AosFS.Directory IN eFlags THEN ]]></Span><Span style="Comment"><![CDATA[(* is directory *)]]></Span><Span style="Normal"><![CDATA[
					attr := attr + 10H;
				END;
				IF (f # NIL) & (f IS AosFATFiles.File) THEN
					ats := f(AosFATFiles.File).GetAttributes();
					IF 0 IN ats THEN
						attr := attr + 1;
					END;
					IF 1 IN ats THEN
						attr := attr + 2;
					END;
					IF 2 IN ats THEN
						attr := attr + 4;
					END;
					IF 3 IN ats THEN
						attr := attr + 8;
					END;
					IF 5 IN ats THEN
						attr := attr + 32;
					END;
				END;
(* *)	(* long ? *)		data.RawLInt(attr); ]]></Span><Span style="Comment"><![CDATA[(* attributes *)]]></Span><Span style="Normal"><![CDATA[
(* *) data.RawLInt(0); (* reserved ??? *)
				data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* alloc size as large_int *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of alloc size *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(eSize); ]]></Span><Span style="Comment"><![CDATA[(* first free byte in file (EndOfFile)  as large_int *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of eof *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(1);]]></Span><Span style="Comment"><![CDATA[ (* nr. of hard-links to this file *)]]></Span><Span style="Normal"><![CDATA[
				data.Char(CHR(0)); ]]></Span><Span style="Comment"><![CDATA[(* delete pending?: 0-> no delete pend. *)]]></Span><Span style="Normal"><![CDATA[
				IF AosFS.Directory IN eFlags THEN]]></Span><Span style="Comment"><![CDATA[ (* is directory *)]]></Span><Span style="Normal"><![CDATA[
					data.Char(CHR(1));
				ELSE
					data.Char(CHR(0));
				END;
(* *) data.RawInt(0); (* reserved ??? *)
(* *)			data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* indexNr: file system unique identifier as large_int *)]]></Span><Span style="Normal"><![CDATA[
(* *)			data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part fo indexNr *)]]></Span><Span style="Normal"><![CDATA[
 				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* EA List length *)]]></Span><Span style="Normal"><![CDATA[
 				accMode := 1H + 2H + 4H + 80H + 100H;]]></Span><Span style="Comment"><![CDATA[ (* read, write, append, read_attr, write_attr *)]]></Span><Span style="Normal"><![CDATA[
 				IF special = FALSE THEN
 					accMode := accMode + 10000H; ]]></Span><Span style="Comment"><![CDATA[(* can be deleted *)]]></Span><Span style="Normal"><![CDATA[
 				END;
 				data.RawLInt(accMode);
(* *) data.RawLInt(0); (* reserved ??? *)
(* *)			data.RawLInt(0);]]></Span><Span style="Comment"><![CDATA[ (* indexNr1]]></Span><Span style="Normal"><![CDATA[ ???????????? ]]></Span><Span style="Comment"><![CDATA[as large_int *)]]></Span><Span style="Normal"><![CDATA[
(* *)			data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of indexNr1 *)]]></Span><Span style="Normal"><![CDATA[
(* *)			data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* currentByteOffset in file as large_int *)]]></Span><Span style="Normal"><![CDATA[
(* *)			data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* second part of currentByteOffset *)]]></Span><Span style="Normal"><![CDATA[
				data.RawLInt(0); ]]></Span><Span style="Comment"><![CDATA[(* Mode SNIA p. 87 *)]]></Span><Span style="Normal"><![CDATA[
(* *)			data.RawLInt(0);]]></Span><Span style="Comment"><![CDATA[ (* alignment requrirement by device -> 0 means byte alignment *)]]></Span><Span style="Normal"><![CDATA[
				IF nl = 0 THEN
					IF LOG THEN
						AosOut.String("empty name -> /"); AosOut.Ln();
					END;
					nl := 1; eName[i] := '/'; eName[i+1] := 0X;
				END;
				data.RawLInt(nl); ]]></Span><Span style="Comment"><![CDATA[(* length of name *)]]></Span><Span style="Normal"><![CDATA[
				ind := ind +104 + nl + 1 + 8(* dontknowwhat *);
				WHILE i < Utilities.Length(eName) + 1 DO
					data.Char(eName[i]); INC(i);
				END;
			ELSE
				SetError(ERRDOS, ERRunknownlevel);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			outParam[0] := 0; outParam[1] := 0; ]]></Span><Span style="Comment"><![CDATA[(* error offset if EA error *)]]></Span><Span style="Normal"><![CDATA[
			wordCount := 10;
			tprCnt := 2;
			tdrCnt := SHORT(ind);
			prCnt := 2;
			prOff := 32 + 3 + 20;
			prDisp := 0;
			drCnt := SHORT(ind);
			drOff := prOff + 2;
			drDisp := 0;
		ELSIF setup = 6 THEN
			(* set pathInfo *)
			IF LOG THEN
				AosOut.String("**SetPathInformation"); AosOut.Ln();
			END;
			pos := 0;
			infoLevel := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			pos := pos + 4;]]></Span><Span style="Comment"><![CDATA[ (* reserved *)]]></Span><Span style="Normal"><![CDATA[
			c := FindConnection(packet.TID);
			IF c = NIL THEN
				SetError(ERRSRV, ERRinvtid);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF ~(write IN c.user.permissions) THEN
				SetError(ERRDOS, ERRnoaccess);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			WHILE (buf[pos] = "/") OR (buf[pos] = "\") DO
				INC(pos);
			END;
			i := 0;
			WHILE c.share.root[i] # 0X DO
				name[i] := c.share.root[i];
				INC(i);
			END;
			j := 0;
			WHILE buf[pos] # 0X DO
				name[i] := buf[pos];
				fName[j] := buf[pos];
				INC(i); INC(pos);INC(j);
			END;
			name[i] := 0X; fName[j] := 0X;
			FlipDelimiter(name);
			]]></Span><Span style="Comment"><![CDATA[(* look if file exists
			if yes -> read in values and set them if appropriate
			create result and return *)]]></Span><Span style="Normal"><![CDATA[
			f := AosFS.Old(name);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadfile);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF infoLevel = 1 THEN
				]]></Span><Span style="Comment"><![CDATA[(* probably adapt pos *)]]></Span><Span style="Normal"><![CDATA[
(* *)			INC(pos);]]></Span><Span style="Comment"><![CDATA[ (* pad]]></Span><Span style="Normal"><![CDATA[?????????]]></Span><Span style="Comment"><![CDATA[ *)]]></Span><Span style="Normal"><![CDATA[
				pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* ignore creation date *)]]></Span><Span style="Normal"><![CDATA[
				eTime := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H + ORD(buf[pos + 2]) * 10000H + ORD(buf[pos+3]) * 1000000H;
				pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* access time *)]]></Span><Span style="Normal"><![CDATA[
				pos := pos + 4; ]]></Span><Span style="Comment"><![CDATA[(* ignore write date *);]]></Span><Span style="Normal"><![CDATA[
				pos := pos + 4;]]></Span><Span style="Comment"><![CDATA[ (* ignore size *)]]></Span><Span style="Normal"><![CDATA[
				pos := pos + 4;]]></Span><Span style="Comment"><![CDATA[ (* ignore alloc size *)]]></Span><Span style="Normal"><![CDATA[
(* *)			attr := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
				IF f IS AosFATFiles.File THEN
					attrib := SYSTEM.VAL(SET, attr); ]]></Span><Span style="Comment"><![CDATA[(* luckily the attributes used by AosFATFiles and the one defined in CIFS are the same *)]]></Span><Span style="Normal"><![CDATA[
					IF LOG THEN
						AosOut.String("Set the following attributes "); AosOut.Bits(attrib, 0, 6); AosOut.Ln();
					END;
					f(AosFATFiles.File).SetAttributes(attrib);
				END;
				GetDTFromSmbDT(eTime, date, time);
				IF (date # 0) & (time # 0) THEN
					f.SetDate(time, date);
				END;
				pos := pos + 4;]]></Span><Span style="Comment"><![CDATA[ (* ignore EASize *)]]></Span><Span style="Normal"><![CDATA[
			ELSE
				SetError(ERRDOS, ERRunknownlevel);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			outParam[0] := 0; outParam[1] := 0; ]]></Span><Span style="Comment"><![CDATA[(* return 0 as offset into ea error list *)]]></Span><Span style="Normal"><![CDATA[
			wordCount := 10;
			tdrCnt := 0;
			tprCnt := 2;
			prCnt := 2;
			drCnt := 0;
			prOff := 32+3+20;
			drOff := 0;
			prDisp := 0;
			drDisp := 0;
		ELSIF setup = 8 THEN
			]]></Span><Span style="Comment"><![CDATA[(* SetFileInfo *)]]></Span><Span style="Normal"><![CDATA[
			IF LOG THEN
				AosOut.String("**SetFileInformation"); AosOut.Ln();
			END;
			pos := 0;
			fid := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			infoLevel := ORD(buf[pos]) + ORD(buf[pos + 1]) * 100H;
			pos := pos + 2;
			pos := pos + 2;]]></Span><Span style="Comment"><![CDATA[ (* reserved *)]]></Span><Span style="Normal"><![CDATA[
			c := FindConnection(packet.TID);
			IF c = NIL THEN
				SetError(ERRSRV, ERRinvtid);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF ~(write IN c.user.permissions) THEN
				SetError(ERRDOS, ERRnoaccess);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			sf := FindFile(fid, c);
			IF sf = NIL THEN
				SetError(ERRDOS, ERRbadfile);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			IF infoLevel = 260 THEN
				(* don't know what to do with the large_integer 'total nr . of bytes that need to be travesed fromt he beginning of the file in order to locate the end of file *)
				outParam[0] := 0; ]]></Span><Span style="Comment"><![CDATA[(* return an empty param word *)]]></Span><Span style="Normal"><![CDATA[
				prCnt := 1;
				tprCnt := 1;
			ELSIF infoLevel = 257 THEN
				]]></Span><Span style="Comment"><![CDATA[(* read in the times and so on *)]]></Span><Span style="Normal"><![CDATA[
				outParam[0] := 0;
				prCnt := 1;
				tprCnt := 1;
			ELSE
				SetError(ERRDOS, ERRunknownlevel);
				packet.Serialize(out);
				out.Update();
				RETURN;
			END;
			wordCount := 10;
			tdrCnt := 0;
			prOff := 32+3+20;
			prDisp := 0;
			drCnt := 0;
			drOff := prOff + 2;
			drDisp := 0;
		ELSIF setup = 0BH THEN
			]]></Span><Span style="Comment"><![CDATA[(* findnotifyfirst *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN
		ELSIF setup = 0CH THEN
			]]></Span><Span style="Comment"><![CDATA[(* FindNotifyNext *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN
		ELSIF setup = 0DH THEN
			]]></Span><Span style="Comment"><![CDATA[(* Mkdir *)]]></Span><Span style="Normal"><![CDATA[
			SetError(ERRSRV, ERRnosupport);
			packet.Serialize(out);
			out.Update();
			RETURN
		END;
		multiple := FALSE;
		IF tdrCnt + 32 + 20 + 3 + tprCnt > cBufSize THEN
			IF LOG THEN
				AosOut.String("returning multiple packages"); AosOut.Ln();
			END;
			multiple := TRUE;
			]]></Span><Span style="Comment"><![CDATA[(* send first packet *)]]></Span><Span style="Normal"><![CDATA[
			]]></Span><Span style="Comment"><![CDATA[(* compute possible data size *)]]></Span><Span style="Normal"><![CDATA[
			dataLength := SHORT(cBufSize - 32 -20 - 3 - tprCnt);
			dataOffset := dataLength;
			w.Char(CHR(wordCount));
			w.RawInt(tprCnt);
			w.RawInt(tdrCnt);
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
			w.RawInt(prCnt);
			w.RawInt(prOff);
			w.RawInt(prDisp);
			w.RawInt(dataLength);
			w.RawInt(drOff);
			w.RawInt(drDisp);
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* response has always suwCnt = 0 *)]]></Span><Span style="Normal"><![CDATA[
		]]></Span><Span style="Comment"><![CDATA[	(* compute byteCount *)]]></Span><Span style="Normal"><![CDATA[
			byteCount := SHORT(prCnt + dataLength + 2);
			w.RawInt(byteCount);
			i := 0;
			WHILE i < (prCnt DIV 2) DO
				w.RawInt(outParam[i]);
				INC(i);
			END;
			IF LOG THEN
				AosOut.String("tdrCnt is: "); AosOut.Int(tdrCnt, 5); AosOut.String(" and dataLength is: "); AosOut.Int(dataLength, 5); 
				AosOut.String(" and outData.GetLength() is "); AosOut.Int(outData.GetLength(), 5); AosOut.Ln();
			END;
			buf := outData.GetString();
			w.Bytes(buf^, 0, dataLength);
			packet.Serialize(out);
			out.Update();
		ELSE
			]]></Span><Span style="Comment"><![CDATA[(* send first&only packet *)]]></Span><Span style="Normal"><![CDATA[
			w.Char(CHR(wordCount));
			w.RawInt(tprCnt);
			w.RawInt(tdrCnt);
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
			w.RawInt(prCnt);
			w.RawInt(prOff);
			w.RawInt(prDisp);
			w.RawInt(drCnt);
			w.RawInt(drOff);
			w.RawInt(drDisp);
			w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* response has always suwCnt = 0 *)]]></Span><Span style="Normal"><![CDATA[
			]]></Span><Span style="Comment"><![CDATA[(* compute byteCount *)]]></Span><Span style="Normal"><![CDATA[
			byteCount := prCnt + drCnt + 2;
			w.RawInt(byteCount);
			i := 0;
			WHILE i < (prCnt DIV 2) DO
				w.RawInt(outParam[i]);
				INC(i);
			END;
			buf := outData.GetString();
			w.Bytes(buf^, 0, outData.GetLength());
			packet.Serialize(out);
			out.Update();
		END;
		IF multiple THEN
			WHILE dataOffset < tdrCnt DO
				packet.outBuf.Clear();
				w := packet.outBuf.GetWriter();
				dataLength := SHORT(cBufSize - 32 -20 - 3);
				IF dataLength > outData.GetLength() - dataOffset THEN
					dataLength := SHORT(outData.GetLength() - dataOffset);
				END;
				w.Char(CHR(wordCount));
				w.RawInt(tprCnt);
				w.RawInt(tdrCnt);
				w.RawInt(0); ]]></Span><Span style="Comment"><![CDATA[(* reserved *)]]></Span><Span style="Normal"><![CDATA[
				w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* no more params in subsequent packets *)]]></Span><Span style="Normal"><![CDATA[
				w.RawInt(0);
				w.RawInt(prDisp);
				w.RawInt(dataLength);
				w.RawInt(32 + 3 + 20);
				w.RawInt(drDisp);
				w.RawInt(0);]]></Span><Span style="Comment"><![CDATA[ (* response has always suwCnt = 0 *)]]></Span><Span style="Normal"><![CDATA[
				]]></Span><Span style="Comment"><![CDATA[(* compute byteCount *)]]></Span><Span style="Normal"><![CDATA[
				byteCount := prCnt + drCnt + 2;
				w.RawInt(byteCount);
				i := 0;
				WHILE i < (prCnt DIV 2) DO
					w.RawInt(outParam[i]);
					INC(i);
				END;
				buf := outData.GetString();
				w.Bytes(buf^, dataOffset, dataLength);
				dataOffset := dataOffset + dataLength;
				packet.Serialize(out);
				out.Update();
			END;
		END;
	END Trans2Logic;
	
	
	PROCEDURE UserValid(name, aPwd, uPwd: ARRAY OF CHAR): BOOLEAN;
	VAR s: Share; u: User;
	BEGIN
		u := FindUser(name);
		IF u # NIL THEN
			IF (u.password = aPwd) OR (u.password = uPwd) THEN
				RETURN TRUE;
			END;
		END;
		s := shares;
		RETURN FALSE;
	END UserValid;
	
	PROCEDURE UserExists(name: ARRAY OF CHAR): BOOLEAN;
	VAR s: Share;
	BEGIN
		IF FindUser(name) # NIL THEN
			RETURN TRUE;
		ELSE 
			RETURN FALSE;
		END;
	END UserExists;
	
	PROCEDURE SetError(class: CHAR; code: LONGINT);
	BEGIN
		]]></Span><Span style="Comment"><![CDATA[(* DOS error code *)]]></Span><Span style="Normal"><![CDATA[
		packet.status[0] := class;
		packet.status[1] := 0X;
		packet.status[2] := CHR(code MOD 100H);
		packet.status[3] := CHR(code DIV 100H MOD 100H);
	END SetError;
	
	PROCEDURE CreateFile(name: ARRAY OF CHAR; disposition: LONGINT): SMBFile;
	VAR smbf: SMBFile; c: Connection; f: AosFS.File; res: LONGINT;
	BEGIN
		c := FindConnection(packet.TID);
		IF c = NIL THEN
			SetError(ERRSRV, ERRinvtid);
			RETURN NIL;
		END;
		IF (disposition = 0) OR (disposition = 5) THEN
			IF ~(write IN c.user.permissions) THEN
				SetError(ERRDOS, ERRnoaccess);
				RETURN NIL;
			END;
			f := AosFS.Old(name);
			IF f # NIL THEN
				AosFS.Delete(name, res);
				IF res # 0 THEN
					(* Handle res *)
					IF LOG THEN
						AosOut.String("Error deleting the file. EC: "); AosOut.Int(res, 4); AosOut.String(" disposition: "); AosOut.Int(disposition, 2); AosOut.Ln();
					END;
					SetError(ERRDOS, ERRnoaccess);
					RETURN NIL;
				END;
			END;
			f := AosFS.New(name);
			IF f = NIL THEN
				]]></Span><Span style="Comment"><![CDATA[(* Handle Error *)]]></Span><Span style="Normal"><![CDATA[
				SetError(ERRDOS, ERRbadaccess);
				RETURN NIL;
			END;
			AosFS.Register(f);
		ELSIF disposition = 1 THEN
			f := AosFS.Old(name);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadfile);
				RETURN NIL;
			END;
		ELSIF disposition = 2 THEN
			f := AosFS.Old(name);
			IF f # NIL THEN
				SetError(ERRDOS, ERRfileexists);
				RETURN NIL;
			END;
			IF ~(write IN c.user.permissions) THEN
				SetError(ERRDOS, ERRnoaccess);
				RETURN NIL;
			END;
			f := AosFS.New(name);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadaccess);
				RETURN NIL;
			END;
			AosFS.Register(f);
		ELSIF disposition  = 3 THEN
			f := AosFS.Old(name);
			IF f = NIL THEN
				IF ~(write IN c.user.permissions) THEN
					SetError(ERRDOS, ERRnoaccess);
					RETURN NIL;
				END;
				f := AosFS.New(name);
			END;
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadaccess);
				RETURN NIL;
			END;
		ELSIF disposition = 4 THEN
			f := AosFS.Old(name);
			IF f = NIL THEN
				SetError(ERRDOS, ERRbadfile);
				RETURN NIL;
			END;
			IF ~(write IN c.user.permissions) THEN
				SetError(ERRDOS, ERRnoaccess);
				RETURN NIL;
			END;
			AosFS.Delete(name, res);
			IF res # 0 THEN
				]]></Span><Span style="Comment"><![CDATA[(* Handle res *)]]></Span><Span style="Normal"><![CDATA[
				IF LOG THEN
					AosOut.String("Error deleting the file. EC: "); AosOut.Int(res, 4); AosOut.String(" disposition: "); AosOut.Int(disposition, 2); AosOut.Ln();
				END;
				SetError(ERRDOS, ERRnoaccess);
				RETURN NIL;
			END;
			f := AosFS.New(name);
			IF f = NIL THEN
				SetError(ERRDOS, ERRnoaccess);
				RETURN NIL;
			END;
			AosFS.Register(f);
		END;	
		NEW(smbf);
		smbf.file := f;
		smbf.next := c.files;
		c.files := smbf;
		smbf.fid := c.lastFID;
		INC(c.lastFID);
		RETURN smbf;
	END CreateFile;
	
	PROCEDURE CreateConnection(UID: INTEGER; name: ARRAY OF CHAR; capabilities: LONGINT; uok: BOOLEAN);
	VAR
		c: Connection; u: User; su: SUser;
	BEGIN
		NEW(c);
		c.lastFID := 67;
		c.UID := UID;
		c.capabilities := capabilities;
		NEW(u);
		Utilities.UpperCase(name);
		COPY(name, u.name);
		NEW(su);
		su.user := u;
		c.user := su;
		c.uok := uok;
		c.next := connections;
		connections := c;
	END CreateConnection;
	
	PROCEDURE ActivateConnection(UID, TID: INTEGER; path: ARRAY OF CHAR; pwd: ARRAY OF CHAR): BOOLEAN;
	VAR c: Connection; shareName: ARRAY sharelen OF CHAR; i, start: LONGINT; su: SUser;
	BEGIN
		c := FindNewConnection(UID);
		IF c = NIL THEN
			IF LOG THEN
				AosOut.String("No connection found to activate"); AosOut.Ln();
			END;
			RETURN FALSE;
		END;
		i := 2;
		WHILE i < LEN(path) DO
			IF (path[i] = CHR(5CH)) OR (path[i] = "/") THEN
				start := i + 1; i := LEN(path);
			END;
			INC(i);
		END;
		i := start;
		WHILE path[i] # 0X DO
			shareName[i-start] := path[i];
			INC(i);
		END;
		shareName[i-start+1] := 0X;
		c.share := FindShare(shareName);
		IF c.share = NIL THEN
			IF LOG THEN
				AosOut.String("no appropriate share found"); AosOut.Ln();
				AosOut.String("Connection could not be activated: UID: "); AosOut.Int(UID, 3); AosOut.String(" TID: "); AosOut.Int(TID, 3);
				AosOut.String(" and path "); AosOut.String(path); AosOut.Ln();
			END;
			SetError(ERRSRV, ERRinvnetname);
			RETURN FALSE;
		END;
		su := c.share.users;
		WHILE (su # NIL) & (su.user.name # c.user.user.name) DO
			su := su.next;
		END;
		IF su = NIL THEN
			c.share := NIL;
			IF LOG THEN
				AosOut.String("no appriopriate user found on this share"); AosOut.Ln();
			END;
			SetError(ERRSRV, ERRerror);
			RETURN FALSE;
		END;
		c.user := su; ]]></Span><Span style="Comment"><![CDATA[(* set the right user to this connection *)]]></Span><Span style="Normal"><![CDATA[
		IF ~c.uok THEN
			]]></Span><Span style="Comment"><![CDATA[(* check user validity *)]]></Span><Span style="Normal"><![CDATA[
			IF c.user.user.password = pwd THEN
				c.uok := TRUE;
			ELSE
				IF LOG THEN
					AosOut.String("Pad password"); AosOut.Ln();
				END;
				SetError(ERRSRV, ERRbadpw);
				RETURN FALSE;
			END;
		END;
		c.TID := TID;
		RETURN TRUE;
	END ActivateConnection;
	
	PROCEDURE Dispatch(cmd: CHAR; offset, outOff, pos: LONGINT; in: AosIO.Reader; w, out: AosIO.Writer);
	BEGIN
		IF cmd = CHR(72H) THEN
			HandleNegotiate(in, w);
		ELSIF cmd = CHR(73H) THEN
			HandleSessionSetup(offset, outOff, pos, in, w, out);
(* *)	ELSIF (cmd = CHR(75H))(* OR (cmd = CHR(70H)) *) THEN
			HandleTreeConnect(offset, outOff, pos, in, w, out);
		ELSIF (cmd = CHR(31H)) OR (cmd = CHR(71H)) OR (cmd = CHR(04H)) THEN
			HandleCloseORTreeDisconnect(offset, pos, in, w);
		ELSIF cmd = CHR(10H) THEN
			HandleCheckDirectory(offset, pos, in, w);
		ELSIF cmd = CHR(74H) THEN
			HandleLogoff(offset, outOff, pos, in, w, out);
		ELSIF cmd = CHR(2BH) THEN
			HandleEcho(in, w);
		ELSIF cmd = CHR(0A2H) THEN
			HandleNTCreate(offset, outOff, pos, in, w, out);
		ELSIF cmd = CHR(2EH) THEN
			HandleReadAndX(offset, outOff, pos, in, w, out);
		ELSIF cmd = CHR(2FH) THEN
			HandleWriteAndX(offset, outOff, pos, in, w, out);
		ELSIF cmd = CHR(00H) THEN
			HandleCreateDirectory(offset, pos, in, w);
		ELSIF cmd = CHR(01H) THEN
			HandleRemoveDirectory(offset, pos, in, w);
		ELSIF cmd = CHR(02H) THEN
			HandleOpen(offset, pos, in, w);
		ELSIF (cmd = CHR(03H)) OR (cmd = CHR(0FH)) THEN
			HandleCreateORMkNew(offset, pos, in, w);
		ELSIF cmd = CHR(05H) THEN
			HandleFlush(offset, pos, in, w);
		ELSIF cmd = CHR(06H) THEN
			HandleDelete(offset, pos, in, w);
		ELSIF cmd = CHR(07H) THEN
			HandleRename(offset, pos, in, w);
		ELSIF cmd = CHR(2CH) THEN
			HandleWriteAndClose(in, w);
		ELSIF cmd = CHR(08H) THEN
			HandleQueryInformation(offset, pos, in, w);
		ELSIF cmd = CHR(09H) THEN
			HandleSetInformation(offset, pos, in, w);
		ELSIF cmd = CHR(23H) THEN
			HandleQueryInformation2(offset, pos, in, w);
		ELSIF cmd = CHR(22H) THEN
			HandleSetInformation2(offset, pos, in, w);
		ELSIF cmd = CHR(32H) THEN
			HandleTrans2(offset, pos, in, w, out);
		ELSIF cmd = CHR(2DH) THEN
			HandleOpenAndX(offset, outOff, pos, in, w, out);
		ELSIF cmd = CHR(80H) THEN
			HandleQueryInformationDisk(w);
		ELSE
			HandleNotSupported();
		END;
	END Dispatch;
	
	BEGIN {ACTIVE}
		closeRequest := FALSE;
		AosIO.OpenReader(in, client.Receive);
		AosIO.OpenWriter(out, client.Send);
		AosOut.Ln();
		WHILE ~closeRequest & (client.state IN AosTCP.OpenStates) DO
			NEW(packet);
			]]></Span><Span style="Comment"><![CDATA[(* internalize the received packet *)]]></Span><Span style="Normal"><![CDATA[
			packet.Internalize(in);
			]]></Span><Span style="Comment"><![CDATA[(* Handle packet *)]]></Span><Span style="Normal"><![CDATA[
			w := packet.outBuf.GetWriter();
			Dispatch(packet.command, 32, 32, 32, in, w, out);
			in.Reset();
			]]></Span><Span style="Comment"><![CDATA[(* send the updated packet out *)]]></Span><Span style="Normal"><![CDATA[
			packet.Serialize(out);
		END;
		IF LOG THEN
			AosOut.String("Finished Client"); AosOut.Ln();
		END;
		Terminate;
	END SambaAgent;

VAR
	samba: AosTCPServices.Service;]]></Span><Span style="Debug"><![CDATA[
]]></Span><Span style="Normal"><![CDATA[(*	nOfCon* : LONGINT;*)
	lastUID, lastTID, lastFID, rkey: INTEGER;
	connections: Connection;
	shares: Share;
	users: User;
	trans2s: Trans2;
	rg: AosRandom.Generator;
	loaded: BOOLEAN;

PROCEDURE NewSambaAgent(c: AosTCP.Connection; s: AosTCPServices.Service): AosTCPServices.Agent;
VAR a: SambaAgent;
BEGIN
	NEW(a, c, s);
	a.state := 0;
	RETURN a
END NewSambaAgent;

PROCEDURE StartSamba*(par: PTR): PTR;
VAR
	res: LONGINT;
BEGIN {EXCLUSIVE}
	IF samba = NIL THEN
		LoadShares();
		NEW(samba, 445, NewSambaAgent, res);
		IF res # AosTCPServices.Ok THEN
			AosOut.String(moduleName); AosOut.String("Could not start the Samba Server (Error ");
			AosOut.Int(res, 5); AosOut.String(")"); AosOut.Ln();
			samba := NIL;
		END; 
	ELSE
		AosOut.String(moduleName); AosOut.String("Samba Server already started"); AosOut.Ln();
	END;
	RETURN NIL;
END StartSamba;

]]></Span><Span style="Comment"><![CDATA[(* Stop the server *)]]></Span><Span style="Normal"><![CDATA[
PROCEDURE StopSamba*(par: PTR): PTR;
BEGIN {EXCLUSIVE}
	IF samba # NIL THEN
		samba.Stop(); samba := NIL;
	END;
	RETURN NIL;
END StopSamba;

PROCEDURE GetSambaTime(date: Utilities.TDateTime; VAR t: ARRAY OF LONGINT); ]]></Span><Span style="Comment"><![CDATA[(* t[0]: low, t[1] high part of time *)]]></Span><Span style="Normal"><![CDATA[
VAR
	d: LONGINT;
	s: LONGINT;
	high, low: LONGINT;
	y, w, wd: LONGINT;
	h: HUGEINT;
BEGIN
	]]></Span><Span style="Comment"><![CDATA[(* calculate seconds since 1970, jan 1st and add 11644473600 to it (seconds from 1601, jan 1st) *)]]></Span><Span style="Normal"><![CDATA[
	d := date.Year - 1970; 
	d := d + (d DIV 4);
	Utilities.WeekDate(date, y, w, wd);
	d := d + (w*7) + wd;
	s := d * 24 * 60 * 60;
	s := date.Hour*60*60 + date.Minute*60 + date.Second;
]]></Span><Span style="Comment"><![CDATA[(* more or less from samba3.0.20/lib/time.c *)]]></Span><Span style="Normal"><![CDATA[
	h := s + 11644473600;
	h := h * 10000000;
	low := SHORT(h);
	high := SHORT(AosBoot.DivH(h, 100000000H));
	t[0] := low;
	t[1] := high;
END GetSambaTime;

PROCEDURE GetTimeStamp(date, time: LONGINT;): LONGINT;
VAR
	tdate: Utilities.TDateTime;
	unixt, year, week, weekday: LONGINT;
BEGIN
	tdate := Utilities.OberonToDateTime(date, time);
	unixt := (tdate.Year - 1970);
	unixt := unixt * 365 + unixt DIV 4; ]]></Span><Span style="Comment"><![CDATA[(* leap years *)]]></Span><Span style="Normal"><![CDATA[
	Utilities.WeekDate(tdate, year, week, weekday);
	unixt := unixt + week * 7 + weekday;
	unixt := unixt * 24 * 60 * 60;
(*AosOut.String("Date is: "); AosOut.Int(tdate.Year, 5); AosOut.Int(tdate.Month, 3); AosOut.Int(tdate.Day, 3); AosOut.Ln();
AosOut.String("Unix-time is: "); AosOut.Int(unixt, 8); AosOut.Ln();*)
	RETURN unixt;
END GetTimeStamp;

PROCEDURE GetDateTime(date, time: LONGINT): LONGINT;
VAR
	tdate: Utilities.TDateTime;
	h, min, x, y, mon, d: LONGINT;
BEGIN
	IF (date = 0) & (time = 0) THEN
		RETURN 0;
	END;
	tdate := Utilities.OberonToDateTime(date, time);
	]]></Span><Span style="Comment"><![CDATA[(* date in the higher 16 bit, then time *)]]></Span><Span style="Normal"><![CDATA[
	y := ASH(tdate.Year-1980, 9);
	mon := ASH(tdate.Month, 5);
	d := tdate.Day;
	h := ASH(tdate.Hour, 27);
	min := ASH(tdate.Minute, 21);
	x := ASH(tdate.Second DIV 2, 16);
	RETURN y + mon + d + h + min + x;
END GetDateTime;

PROCEDURE GetDTFromSmbDT(smbt: LONGINT; VAR date, time: LONGINT);
VAR
	tdate: Utilities.TDateTime;
	y, mon, h, min, x: LONGINT;
BEGIN
	IF (smbt = -1) OR (smbt = 0) THEN
		date := 0;
		time := 0;
		RETURN;
	END;
	tdate.Hour := ASH(smbt, -27);
	h := ASH(tdate.Hour, 27);
	tdate.Minute := ASH(smbt - h, - 21);
	min := ASH(tdate.Minute, 21);
	tdate.Second := 2 * ASH(smbt - h - min, -16);
	x := ASH(tdate.Second, 16) DIV 2;
	tdate.Year := ASH(smbt - h - min - x, -9);
	y := ASH(tdate.Year, 9);
	tdate.Month := ASH(smbt - h - min - x - y, -5);
	mon := ASH(tdate.Month, 5);
	tdate.Day := smbt - h - min - x - y - mon;
	IF ~Utilities.ValidDateTime(tdate) THEN
		date := 0;
		time := 0;
	ELSE
		Utilities.DateTimeToOberon(tdate, date, time);
	END;
END GetDTFromSmbDT;

PROCEDURE AddShare*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	shareName, root: ARRAY namelen OF CHAR;
	share: Share;
BEGIN {EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); sr.SkipWhitespace;
	
	sr.Token(shareName); sr.SkipWhitespace;
	sr.String(root); sr.SkipWhitespace;

	IF shareName # "" THEN
		Utilities.UpperCase(shareName);
		IF FindShare(shareName) = NIL THEN
			NEW(share);
			COPY(shareName, share.name);
			COPY(root, share.root);
			share.next := shares;
			shares := share;
			StoreShares();
			AosOut.String(moduleName); AosOut.String("Share '"); AosOut.String(shareName); AosOut.String("' added. Root is '");
			AosOut.String(root); AosOut.String("'."); AosOut.Ln();
		ELSE
			AosOut.String(moduleName); AosOut.String("Share '"); AosOut.String(shareName); AosOut.String("' exists."); AosOut.Ln();			
		END;
	ELSE
		AosOut.String("AddShare: invalid parameters. Usage: AddShare shareName root~"); AosOut.Ln();
	END;
	RETURN NIL
END AddShare;

PROCEDURE RemoveShare*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	prev, s: Share; name: ARRAY namelen OF CHAR;
BEGIN {EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); 
	sr.SkipWhitespace; sr.Token(name);	
	IF (name # "") THEN
		Utilities.UpperCase(name);
		AosOut.String(moduleName); AosOut.String("Removing share '"); AosOut.String(name); AosOut.String("'."); AosOut.Ln();
		s := shares; prev := NIL;
		WHILE s # NIL DO
			IF s.name = name THEN
				IF prev = NIL THEN
					shares := s.next
				ELSE
					prev.next := s.next
				END;
			END;
			prev := s; s := s.next;
		END;
		StoreShares();
	ELSE
		AosOut.String("RemoveShare: invalid parameters. Usage RemoveShare shareName"); AosOut.Ln();
	END;
	RETURN NIL;
END RemoveShare;

PROCEDURE AddUser*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	userName: ARRAY namelen OF CHAR; password: ARRAY pwlen + 1 OF CHAR;
	user, u: User;
BEGIN{EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); sr.SkipWhitespace;
	sr.Token(userName); sr.SkipWhitespace;
	sr.Token(password); sr.SkipWhitespace;
	IF userName # "" THEN
		Utilities.UpperCase(userName);
		]]></Span><Span style="Comment"><![CDATA[(* check if user already exists *)]]></Span><Span style="Normal"><![CDATA[
		u := users;
		WHILE (u # NIL) & (u.name # userName) DO u := u.next; END;
		IF u # NIL THEN
			AosOut.String(moduleName); AosOut.String("User '"); AosOut.String(userName); AosOut.String("' already exists"); AosOut.Ln();
			RETURN NIL;
		END;
		NEW(user);
		COPY(userName, user.name);
		IF password[0] = '#' THEN password[0] := 0X; END;
		COPY(password, user.password);
		user.next := users;
		users := user;
		AosOut.String(moduleName); AosOut.String("User '"); AosOut.String(userName); AosOut.String("' added to users."); AosOut.Ln();
		StoreShares();
	ELSE
		AosOut.String(moduleName); AosOut.String("Invalid Parameter! Usage: 'AddUser username password'."); AosOut.Ln();
	END;
	RETURN NIL;
END AddUser;
	
PROCEDURE RemoveUser*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	userName: ARRAY namelen OF CHAR;
	prev, u: User; s: Share; su, suprev: SUser;
BEGIN {EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); 
	sr.SkipWhitespace; sr.Token(userName);	
	IF (userName # "") THEN
		Utilities.UpperCase(userName);
		AosOut.String(moduleName); AosOut.String("Removing user '"); AosOut.String(userName); AosOut.String("'."); AosOut.Ln();
		]]></Span><Span style="Comment"><![CDATA[(* remove from users *)]]></Span><Span style="Normal"><![CDATA[
		u := users; prev := NIL;
		WHILE u # NIL DO
			IF u.name = userName THEN
				IF prev = NIL THEN
					users := u.next;
				ELSE
					prev.next := u.next;
				END;
			END;
			prev := u; u := u.next;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* remove from all shares if available *)]]></Span><Span style="Normal"><![CDATA[
		s := shares;
		WHILE s # NIL DO
			su := s.users; suprev := NIL;
			WHILE su # NIL DO
				IF su.user.name = userName THEN
					IF suprev = NIL THEN
						s.users := su.next;
					ELSE
						suprev.next := su.next;
					END;
				END;
				suprev := su; su := su.next;
			END;
			s := s.next;
		END;
		StoreShares();
	ELSE
		AosOut.String(moduleName); AosOut.String("RemoveUser: invalid parameters. Usage RemoveUser userName"); AosOut.Ln();
	END;
	RETURN NIL;
END RemoveUser;

PROCEDURE AddUserToShare*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	shareName: ARRAY sharelen OF CHAR; userName: ARRAY namelen OF CHAR;
	permissions: ARRAY 32 OF CHAR;
	u: User; su, suser: SUser; share: Share; i: LONGINT;
BEGIN {EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); sr.SkipWhitespace;
	sr.Token(shareName); sr.SkipWhitespace;
	sr.Token(userName); sr.SkipWhitespace;
	sr.Token(permissions); sr.SkipWhitespace;
	IF (userName # "") & (permissions # "") THEN
		Utilities.UpperCase(userName);
		Utilities.UpperCase(shareName);
		share := FindShare(shareName);
		IF share # NIL THEN
			su := share.users;
			WHILE (su # NIL) & (su.user.name # userName) DO su := su.next; END;
			IF su = NIL THEN
				NEW(suser);
				u := users;
				WHILE (u # NIL) & (u.name # userName) DO u := u.next; END;
				IF u = NIL THEN
					AosOut.String(moduleName); AosOut.String("User '"); AosOut.String(userName); AosOut.String("' does not exist."); AosOut.Ln();
					RETURN NIL;
				END;
				suser.user := u;
				suser.permissions := {};
				i := 0;
				WHILE permissions[i] # 0X DO
					IF CAP(permissions[i]) = "R" THEN INCL(suser.permissions, read);
					ELSIF CAP(permissions[i]) = "W" THEN INCL(suser.permissions, write);
					END;
					INC(i);
				END;
				suser.next := share.users;
				share.users := suser;
				AosOut.String(moduleName); AosOut.String("Added user '"); AosOut.String(userName); AosOut.String("' to share '");
				AosOut.String(shareName); AosOut.String("'."); AosOut.Ln();
				StoreShares();
			ELSE
				AosOut.String(moduleName); AosOut.String("User '"); AosOut.String(userName); AosOut.String("' already belongs to share '");
				AosOut.String(shareName); AosOut.String("'."); AosOut.Ln();
			END;
		ELSE
			AosOut.String(moduleName); AosOut.String("Share '"); AosOut.String(shareName); AosOut.String("' does not exist"); AosOut.Ln();
		END;
	ELSE
		AosOut.String(moduleName); AosOut.String("AddUserToShare: wrong parameters. Usage AddUserToShare shareName userName permissions[r|w|rw]"); AosOut.Ln();
	END;
	RETURN NIL;
END AddUserToShare;

PROCEDURE RemoveUserFromShare*(par: PTR): PTR;
VAR p: AosCommands.Parameters; sr: AosIO.StringReader;
	prev, u: SUser; share: Share;
	shareName: ARRAY sharelen OF CHAR; userName: ARRAY namelen OF CHAR;
BEGIN {EXCLUSIVE}
	IF ~loaded THEN
		LoadShares();
	END;
	p := par(AosCommands.Parameters);
	NEW(sr, LEN(p.str^)); sr.Set(p.str^); 
	sr.SkipWhitespace; sr.Token(shareName);
	sr.SkipWhitespace; sr.Token(userName);
	IF (shareName  # "") & (userName # "") THEN
		Utilities.UpperCase(userName);
		Utilities.UpperCase(shareName);
		share := FindShare(shareName);
		IF share # NIL THEN
			u := share.users; prev := NIL;
			WHILE u # NIL DO
				IF u.user.name = userName THEN
					IF prev = NIL THEN share.users := u.next
					ELSE prev.next := u.next
					END;
				END;
				prev := u; u := u.next;
			END;
			AosOut.String(moduleName); AosOut.String("Removed user '"); AosOut.String(userName); AosOut.String("' from share '");
			AosOut.String(shareName); AosOut.String("'."); AosOut.Ln();
			StoreShares();
		ELSE
			AosOut.String(moduleName); AosOut.String("Share '"); AosOut.String(shareName); AosOut.String("' does not exist"); AosOut.Ln();
		END;
	ELSE
		AosOut.String(moduleName); AosOut.String("RemoveUserFromShare: invalid parameters. Usage RemoveUserFromShare shareName userName"); AosOut.Ln();
	END;
	RETURN NIL;
END RemoveUserFromShare;

PROCEDURE FindShare(name: ARRAY OF CHAR): Share;
VAR s: Share; upper: ARRAY sharelen OF CHAR;
BEGIN
	s := shares;
	Utilities.UpperCase(name);
	WHILE (s # NIL) & (s.name # name)DO s := s.next; END;
	RETURN s
END FindShare;

PROCEDURE FindUser(name: ARRAY OF CHAR): User;
VAR u: User;
BEGIN
	u := users;
	Utilities.UpperCase(name);
	WHILE (u # NIL) & (u.name # name) DO u := u.next END;
	RETURN u;
END FindUser;

PROCEDURE FindConnection(TID: INTEGER): Connection;
VAR c: Connection;
BEGIN
	c := connections;
	WHILE (c # NIL) & (c.TID # TID) DO c := c.next; END;
	RETURN c;
END FindConnection;

PROCEDURE FindNewConnection(UID: INTEGER): Connection;
VAR c: Connection;
BEGIN
	c:= connections;
	WHILE (c # NIL) & (c.UID # UID) DO 
		IF c.TID = 0 THEN RETURN c; END;
		c := c.next; 
	END;
	RETURN c;
END FindNewConnection;

PROCEDURE FindFile(FID: INTEGER; c: Connection): SMBFile;
VAR f: SMBFile;
BEGIN
	f := c.files;
	WHILE (f # NIL) & (f.fid # FID) DO f := f.next; END;
	RETURN f;
END FindFile;

PROCEDURE FlipDelimiter(VAR path: ARRAY OF CHAR);
VAR i: LONGINT;
BEGIN
	i := 0;
	WHILE path[i] # 0X DO
		IF path[i] = "\" THEN
			path[i] := "/";
		END;
		INC(i);
	END;
END FlipDelimiter;

PROCEDURE FindTrans2(tid: INTEGER): Trans2;
VAR t: Trans2;
BEGIN
	t := trans2s;
	WHILE (t # NIL) & (t.tid # tid) DO t := t.next; END;
	RETURN t;
END FindTrans2;

PROCEDURE ReleaseShare(TID, UID: INTEGER): INTEGER;
VAR c: Connection; f, old: SMBFile;
BEGIN
	c := FindConnection(TID);
	IF c = NIL THEN
		RETURN ERRinvtid;
	ELSIF c.UID # UID THEN
		RETURN ERRbaduid;
	ELSE
		c.share := NIL;
		c.TID := 0;
		f := c.files;
		WHILE f # NIL DO
			IF f.file # NIL THEN f.file.Update(); END;
			f := f.next;
		END;
		c.files := NIL;
		RETURN 0;
	END;
END ReleaseShare;

PROCEDURE ListShares*(par: PTR): PTR;
VAR s: Share; u: SUser;
BEGIN
	IF ~loaded THEN
		LoadShares();
	END;
	IF shares # NIL THEN
		AosOut.String(moduleName); AosOut.String("Available Shares:"); AosOut.Ln();
		s := shares;
		WHILE s # NIL DO
			AosOut.String("Share '"); AosOut.String(s.name); AosOut.String("' has root: '"); AosOut.String(s.root); AosOut.String("'."); AosOut.Ln();
			AosOut.String("Registered users are: ");
			u := s.users;
			WHILE u # NIL DO
				AosOut.String(u.user.name); AosOut.String(" [pw: "); AosOut.String(u.user.password); AosOut.String(" | ");
				IF read IN u.permissions THEN AosOut.String("r"); END;
				IF write IN u.permissions THEN AosOut.String("w"); END;
				AosOut.String(" ] ");
				u := u.next;
			END;
			AosOut.Ln();
			s := s.next;
		END;
	ELSE
		AosOut.String(moduleName); AosOut.String("No shares available"); AosOut.Ln();
	END;
	RETURN NIL;
END ListShares;

PROCEDURE ListConnections*(par: PTR): PTR;
VAR c: Connection;
BEGIN
	IF connections # NIL THEN
		AosOut.String(moduleName); AosOut.String("Open connections:"); AosOut.Ln();
		c := connections;
		WHILE c # NIL DO
			AosOut.String("Connection to user: "); AosOut.String(c.user.user.name); AosOut.String(" (UID ");
			AosOut.Int(c.UID, 3); AosOut.String(")");
			IF c.share # NIL THEN 
				AosOut.String(" on Share '"); AosOut.String(c.share.name); AosOut.String("' (TID "); AosOut.Int(c.TID, 4); AosOut.String(")."); AosOut.Ln();
			ELSE
				AosOut.String(". There are now shares on this connections"); AosOut.Ln();
			END;
			c := c.next;
		END
	ELSE
		AosOut.String(moduleName); AosOut.String("No connections open"); AosOut.Ln();
	END;
	RETURN NIL;
END ListConnections;

PROCEDURE LoadShares();
VAR u: User; su: SUser; s: Share; uName: ARRAY namelen OF CHAR; f: AosFS.File; r: AosFS.Reader; nOfUsers, nOfSUsers, nOfShares, i, j: INTEGER;
BEGIN
	f := AosFS.Old(shareFile);
	IF f # NIL THEN
		AosFS.OpenReader(r, f, 0);
		r.RawInt(nOfUsers);
		i := 0;
		WHILE i < nOfUsers DO
			NEW(u);
			r.RawString(u.name); r.RawString(u.password);
			u.next := users; users := u;
			INC(i);
		END;
		r.RawInt(nOfShares); j := 0;
		WHILE j < nOfShares DO
			NEW(s); i := 0;
			r.RawString(s.name); r.RawString(s.root); r.RawInt(nOfSUsers);
			WHILE i < nOfSUsers DO
				NEW(su);
				r.RawString(uName);
				su.user := FindUser(uName);
				r.RawSet(su.permissions);
				su.next := s.users; s.users := su; (* insert at the beginning *)
				INC(i);
			END;
			s.next := shares;
			shares := s;
			INC(j);
		END;
		AosOut.String(moduleName); AosOut.String("Shares loaded"); AosOut.Ln();
	ELSE
		AosOut.String(moduleName); AosOut.String("Can't read shares file"); AosOut.Ln();
	END;
	loaded := TRUE;]]></Span><Span style="Comment"><![CDATA[ (* set loaded even if not possible to declare the datastructure in the system valid! *)]]></Span><Span style="Normal"><![CDATA[
END LoadShares;

PROCEDURE StoreShares();
VAR
	f: AosFS.File; w: AosFS.Writer;
	user: User; share : Share; suser: SUser;
	nOfUsers, nOfSUsers, nOfShares: INTEGER;
	password: ARRAY pwlen + 1 OF CHAR;
BEGIN
	f := AosFS.New(shareFile);
	AosFS.Register(f);
	IF f # NIL THEN
		AosFS.OpenWriter(w, f, 0);
		]]></Span><Span style="Comment"><![CDATA[(* Compute the number of users and write it out *)]]></Span><Span style="Normal"><![CDATA[
		user := users; nOfUsers := 0;
		WHILE user # NIL DO
			INC(nOfUsers);
			user := user.next;
		END;
		w.RawInt(nOfUsers);
		]]></Span><Span style="Comment"><![CDATA[(* write all the users *)]]></Span><Span style="Normal"><![CDATA[
		user := users;
		WHILE user # NIL DO
			w.RawString(user.name);
			w.RawString(user.password);
			user := user.next;
		END;
		]]></Span><Span style="Comment"><![CDATA[(* write all shares *)]]></Span><Span style="Normal"><![CDATA[
		share := shares;
		WHILE share #  NIL DO
			INC(nOfShares);
			share := share.next;
		END;
		share := shares;
		w.RawInt(nOfShares);
		WHILE share # NIL DO
			suser := share.users; nOfSUsers := 0;
			WHILE suser # NIL DO ]]></Span><Span style="Comment"><![CDATA[(* compute number of users *)]]></Span><Span style="Normal"><![CDATA[
				INC(nOfSUsers);
				suser := suser.next;
			END;
			w.RawString(share.name);
			w.RawString(share.root);
			w.RawInt(nOfSUsers);
			suser := share.users;
			WHILE suser # NIL DO
				w.RawString(suser.user.name);
				w.RawSet(suser.permissions);
				suser := suser.next;
			END;
			share := share.next;
		END;
		w.Update();
		AosOut.String(moduleName); AosOut.String("Shares stored"); AosOut.Ln();
	ELSE
		AosOut.String(moduleName); AosOut.String("Can't write shares file"); AosOut.Ln();
	END;
END StoreShares;

BEGIN
(*	nOfCon := 0;*)
	loaded := FALSE;
	NEW(rg);
	lastUID := 42;
	lastTID := 27;
	rkey := 3;
	loaded := FALSE;
END SambaServer.

]]></Span><Span style="Bold"><![CDATA[EXAMPLES
]]></Span><Span style="Normal"><![CDATA[SambaServer.AddShare test  AOS: ~ (has to be a complete path with '/' if necessary. In this case not necessary!)
SambaServer.AddUser username password ~ (password is case sensitive, username not)
	NOTE: Use # as password for an empty password (e.g. for guest account)
SambaServer.AddUserToShare test username rw ~ (add user 'username' to share 'test' with read/write permitssions)

SambaServer.RemoveUserFromShare test username ~ (remove 'username' from the users of 'test')
SambaServer.RemoveUser username (remove 'username' from users and from all shares)
SambaServer.RemoveShare test ~ (remove the share 'test')

SambaServer.ListShares ~ (List all users and shares)

SambaServer.ListConnections ~ (List all active connections)

]]></Span><Span style="Bold"><![CDATA[START THE SERVER]]></Span><Span style="Normal"><![CDATA[
SambaServer.StartSamba ~
SambaServer.StopSamba ~

]]></Span><Span style="Bold"><![CDATA[FREE THE SERVER
]]></Span><Span style="Normal"><![CDATA[S.Free SambaServer ~

]]></Span><Span style="Bold"><![CDATA[A very short How-To]]></Span><Span style="Normal"><![CDATA[
To use the SambaServer you have to define a share, one user and add the user to the share. 
An example for user 'blue' with password 'bottle', share 'test' on 'Auto0' and w/r permissions would be:
SambaServer.AddUser blue bottle ~
SambaServer.AddShare test Auto0: ~
SambaServer.AddUserToShare test blue rw ~
]]></Span>

</Text>
