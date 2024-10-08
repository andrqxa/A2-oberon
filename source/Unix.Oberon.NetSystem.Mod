(* ETH Oberon, Copyright 2000 ETH Zürich Institut für Computersysteme, ETH Zentrum, CH-8092 Zürich.
Refer to the general ETH Oberon System license contract available at: http://www.oberon.ethz.ch/ *)

MODULE NetSystem IN Oberon;

IMPORT S := SYSTEM, IP IN A2, DNS := DNS IN A2, TCP := TCP IN A2,  UDP := UDP IN A2,
		Texts, Oberon, Input, Fonts, Strings, Out;

	CONST
		CR = 0DX; LF = 0AX; 

		(* res values *)
		done* = 0;	(*everything went ok*)
		error* = 1;	(*failure occured*)
		timeout* = 2;	(*opening a connection is timed out*)

		(* return values of procedure State *)
		closed* = 0;	(*connection is closed (neither sending nor receiving)*)
		listening* = 1;	(*passive connection is listening for a request*)
		in* = 2;	(*receiving only*)
		out* = 3;	(*sending only*)
		inout* = 4;	(*sending and receiving is possible*)
		waitCon* = 5; (** still waiting for beeing connected *)
		errorCon* = 6; (** connecting failed *)
		undef = -1; (** unknown state *)

		IPAdrLen = 4;

		(* any port value *)
		anyport* = 0;

	TYPE

		IPAdr* = IP.Adr;

		Connection* = TCP.Connection; 	(* TCP-Connection *)

		HostInfo* = POINTER TO HostInfoDesc;  (** handle for asyncrouns GetIP and GetName *)
		HostInfoDesc* = RECORD
			next: HostInfo;
			ip-: IPAdr; (** the ip-number of host name *)
			name-: ARRAY 64 OF CHAR; (** the host name for ip-number *)
			done-, err-, getip: BOOLEAN (** indicating success or failure *)
		END;

		Socket*= UDP.Socket; 	(* UDP-Connection *)

		Password = POINTER TO PasswordDesc;
		PasswordDesc = RECORD
			service, user, host, passwd: ARRAY 64 OF CHAR;
			next: Password
		END;
		
		Bytes = ARRAY MAX( SIGNED32 ) OF CHAR;

	VAR
		hostIP* : IPAdr;	(** the ip-number of host name *)
		anyIP*, allIP*: IPAdr;
		hostName*: ARRAY 65 OF CHAR;	(** own machine name *)

		hostInfos: HostInfo;
		W: Texts.Writer;
		passwords: Password;

	PROCEDURE Start*;
	VAR res: INTEGER;
	BEGIN
		DNS.GetHostName( hostName, res );
		IF res = DNS.Ok  THEN
			DNS.HostByName( hostName, hostIP, res );
		END
	END Start;

	PROCEDURE Stop*;
	BEGIN
	END Stop;

	PROCEDURE ToHost* ( CONST num: ARRAY OF CHAR; VAR adr: IPAdr; VAR done: BOOLEAN );
	BEGIN
		adr := IP.StrToAdr(num);
		done := ~(IP.IsNilAdr(adr))
	END ToHost;

	PROCEDURE ToNum*( adr: IPAdr; VAR num: ARRAY OF CHAR );
	BEGIN
		IP.AdrToStr(adr, num)
	END ToNum;

	PROCEDURE AsyncGetIP*( VAR hostInfo: HostInfo; name: ARRAY OF CHAR );
	VAR res: INTEGER;
	BEGIN
		NEW( hostInfo ); Strings.Lower( name, name );
		hostInfo.next := NIL; COPY( name, hostInfo.name );
		hostInfo.done := FALSE; hostInfo.err := FALSE; 
		IF (name[0] >= "0") & (name[0] <= "9") THEN
			DNS.HostByNumber( hostInfo.ip, name, res );
			hostInfo.err := res # DNS.Ok; hostInfo.done := TRUE
		ELSE
			DNS.HostByName( name, hostInfo.ip, res );	(* human name *)
			IF res = DNS.Ok THEN
				hostInfo.err := FALSE; hostInfo.done := TRUE;
				hostInfo.next := hostInfos;  hostInfos := hostInfo
			ELSE
				hostInfo.err := TRUE
			END
		END;
	END AsyncGetIP;

	PROCEDURE GetIP* ( CONST name: ARRAY OF CHAR;  VAR IP: IPAdr );
	VAR hostInfo: HostInfo;
	BEGIN
		IP := anyIP;
		AsyncGetIP( hostInfo, name );
		IF ~hostInfo.err THEN
			IP := hostInfo.ip
		END
	END GetIP;

	PROCEDURE AsyncGetName*( VAR hostInfo: HostInfo; IP: IPAdr );
	VAR res: INTEGER;
	BEGIN
			NEW( hostInfo );
			hostInfo.getip := FALSE; hostInfo.next := NIL;
			S.MOVE( ADDRESSOF( IP ), ADDRESSOF( hostInfo.ip ), IPAdrLen );
			hostInfo.done := FALSE; hostInfo.err := FALSE; 
			DNS.HostByNumber( hostInfo.ip, hostInfo.name, res );
			IF res = DNS.Ok THEN
				hostInfo.err := FALSE; hostInfo.done := TRUE;
				hostInfo.next := hostInfos; hostInfos := hostInfo
			ELSE
				hostInfo.err := TRUE; hostInfo.name[0]:= 0X
			END
	END AsyncGetName;

	PROCEDURE GetName* ( IP: IPAdr; VAR name: ARRAY OF CHAR );
	VAR hostInfo: HostInfo;
	BEGIN
		COPY("", name);
		AsyncGetName( hostInfo, IP );
		IF ~hostInfo.err THEN
			COPY( hostInfo.name, name )
		END
	END GetName;

	(** Passwords *)

	PROCEDURE WriteURL( CONST service, user, host: ARRAY OF CHAR );
	BEGIN
		Out.String("NetSystem.SetUser ");  Out.String(service);
		Out.Char(":");  Out.String(user);  Out.Char("@");
		Out.String(host);  Out.String(" ~"); Out.Ln
	END WriteURL;

	(** Retrieve the password for user using service on host.  Parameters service, host and user must be specified.
	Parameter user is in/out.  If empty, it returns the first (user,password) pair found, otherwise it returns the
	specified user's password. *)

	PROCEDURE GetPassword*(service, host: ARRAY OF CHAR;  VAR user, password: ARRAY OF CHAR);
	VAR pass: Password;  r: Texts.Reader;  ch: CHAR;
	BEGIN
		Strings.Lower(service, service);  Strings.Lower(host, host);
		pass := passwords;
		WHILE (pass # NIL) & ~((pass.service = service) & (pass.host = host) & ((user = "") OR (pass.user = user))) DO
			pass := pass.next
		END;
		IF pass # NIL THEN
			COPY(pass.user, user);  COPY(pass.passwd, password)
		ELSE
			IF (service # "") & (user # "") THEN
				IF Oberon.Log.len > 0 THEN
					Texts.OpenReader(r, Oberon.Log, Oberon.Log.len-1);
					Texts.Read(r, ch);
					IF ch # CHR(13) THEN Out.Ln END
				END;
				WriteURL(service, user, host);
			END;
			COPY("", user); COPY("", password)
		END
	END GetPassword;

	(** Remove password for user using service on host. *)
	PROCEDURE DelPassword*( CONST pservice, user, phost: ARRAY OF CHAR);
	VAR ppass, pass: Password;
		service, host: ARRAY 64 OF CHAR;
	BEGIN
		Strings.Lower( pservice, service );  Strings.Lower( phost, host );
		ppass := NIL; pass := passwords;
		WHILE (pass # NIL) & ((pass.service # service) & (pass.host # host) & (pass.user # user)) DO
			ppass := pass; pass := pass.next
		END;
		IF pass # NIL THEN
			IF ppass # NIL THEN
				ppass.next := pass.next
			ELSE
				passwords := pass.next
			END
		END
	END DelPassword;

	(** NetSystem.SetUser {"\v" | credential0 | credential1} "~".
		credential0 = service ":" ["//"] user [":" password] "@" host [ "/" ].
		credential1 = (service ":" ["//"] user "@" host [ "/" ]) ... password.
		If password is not specified in-line (credential0), enter the password interactively (credential1).
		The (service, host, user, password) 4-tuple is stored in memory for retrieval with GetPassword.
		"@" can occur anywhere in a credential and host begins after the last @. *)
	PROCEDURE SetUser*;
		VAR
			R: Texts.Reader;
			service, usr, host, pwd: ARRAY 64 OF CHAR; (* Components of a credential. *)
			credential: ARRAY 256 OF CHAR;
			j: SIGNED32; (* Index in credential. *)
			ati: SIGNED32; (* Index of the last "@" in the credential. *)
			pass, list: Password;
			ok, verbose: BOOLEAN;
			ch: CHAR;

	(* A credential is delimited by whitespace or "~" or a non-font entity. *)
		PROCEDURE ReadCredential(): BOOLEAN;
		VAR j: SIGNED32;
		BEGIN
			j := 0; ati := -1;
			Texts.Read(R, credential[0]);
			WHILE ~R.eot & ((credential[0] <= " ") OR ~(R.lib IS Fonts.Font)) DO
				Texts.Read(R, credential[0]);
			END;
			WHILE ~R.eot & (credential[j] > " ") & (credential[j] # "~") & (R.lib IS Fonts.Font) DO
				IF credential[j] = "@" THEN ati := j END;
				INC(j);
				Texts.Read(R, credential[j])
			END;
			credential[j] := 0X;
			RETURN 0 < j
		END ReadCredential;

	(* Next component of a credential. *)
		PROCEDURE Next(VAR str: ARRAY OF CHAR);
		VAR i: SIGNED32;
		BEGIN
			i := 0;
			WHILE (credential[j] # 0X) & (credential[j] > " ") & (credential[j] # ":") & (j # ati) 
					& (credential[j] # "/") & (credential[j] # "~") & (R.lib IS Fonts.Font) DO
				str[i] := credential[j];
				INC(i); INC(j)
			END;
			str[i] := 0X
		END Next;

		PROCEDURE ReadPwd;
		VAR i: SIGNED32;
		BEGIN
			Texts.SetColor(W, 1); Texts.WriteString(W, "Enter password for "); (* Texts.SetColor(W, 15); *)
			Texts.WriteString(W, list.service); Texts.WriteString(W, "://"); 
			Texts.WriteString(W, list.user); Texts.Write(W, "@");
			Texts.WriteString(W, list.host); Texts.WriteString(W, ": "); (* Texts.WriteLn(W); *)
			Texts.SetColor(W, 15);
			Texts.Append(Oberon.Log, W.buf);
			Input.Read(ch); i := 0;
			WHILE ch > " " DO
				IF ch = 7FX (* Delete *) THEN
					IF i > 0 THEN
						Texts.Delete(Oberon.Log, Oberon.Log.len-1, Oberon.Log.len);
						DEC(i)
					END
				ELSE
					Texts.Write(W, "*"); Texts.Append(Oberon.Log, W.buf);
					pwd[i] := ch;  INC(i)
				END;
				Input.Read(ch)
			END;
			pwd[i] := 0X;
			Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
		END ReadPwd;

		(* p contains a credential with new password.  If a match to p is found in passwords, 
			the password is replaced.  Otherwise p is prepended to passwords. *)
		PROCEDURE Replace(p: Password);
		VAR q: Password;
		BEGIN
			q := passwords;
			WHILE (q # NIL) & ~((q.service = p.service) & (q.host = p.host) & (q.user = p.user)) DO
				q := q.next
			END;
			IF verbose THEN
				Out.String(p.service); Out.Char(":");
				Out.String(p.user); Out.Char("@"); Out.String(p.host)
			END;
			IF q = NIL THEN (* Matching credential not found.  Add p to head of passwords list. *)
				p.next := passwords;  passwords := p;
				IF verbose THEN Out.String(" password set") END
			ELSE
				COPY(p.passwd, q.passwd);
				IF verbose THEN Out.String(" password replaced") END
			END;
			IF verbose THEN Out.Ln() END
		END Replace;

	BEGIN
		Texts.OpenReader(R, Oberon.Par.text, Oberon.Par.pos);
		verbose := FALSE; list := NIL;
		WHILE ReadCredential() DO
			IF credential = "\v" THEN
				verbose := TRUE
			ELSE
				ok := TRUE; j := 0;
				WHILE (credential[j] # 0X) & ok DO
					ok := FALSE; Next(service);
					Strings.Lower(service, service);
					IF credential[j] = ":" THEN
						INC(j);
						Next(usr);
						IF credential[j] = "@" THEN	(* no password specified, prompt for password later *)
							ASSERT(j = ati);
							INC(j);
							Next(host);  Strings.Lower(host, host);
							IF host # "" THEN
								NEW(pass);  pass.next := list; list := pass;	(* add to temp list *)
								COPY(service, pass.service); COPY(host, pass.host); COPY(usr, pass.user);
								ok := TRUE
							END
						ELSIF credential[j] = ":" THEN	(* password specified in-line *)
							INC(j);
							Next(pwd);
							IF credential[j] = "@" THEN
								ASSERT(j = ati);
								INC(j);
								Next(host);
								IF host # "" THEN
									NEW(pass); COPY(service, pass.service); COPY(host, pass.host);
									COPY(usr, pass.user); COPY(pwd, pass.passwd);
									Replace(pass); ok := TRUE
								END
							END
						END
					END
				END (* WHILE (credential[j] # 0X) & ok *)
			END (* IF credential = "\v" *)
		END; (* WHILE ReadCredential() *)
		WHILE list # NIL DO (* Read password and apply to the incomplete credential. *)
			ReadPwd;
			IF ch = CR THEN	(* password entered *)
				pass := list; list := list.next; COPY(pwd, pass.passwd); Replace(pass)
			END
		END;
		Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
	END SetUser;

	(** clears all passwords from memory *)
	PROCEDURE ClearUser*;
	BEGIN
		passwords := NIL
	END ClearUser;

(************************************** TCP ****************************************)

	PROCEDURE Available* (conn: Connection): SIGNED32;
	BEGIN
		RETURN conn.Available()
	END Available;

	PROCEDURE OpenConnection* ( VAR conn: Connection; locPort: UNSIGNED16; remIP: IPAdr; remPort: UNSIGNED16;
													VAR res: SIGNED16 );
	VAR r: SIGNED32;
	BEGIN
		IF remPort = anyport THEN remIP := anyIP END;
		NEW( conn );
		conn.Open( locPort, remIP, LONG(remPort) MOD 10000H, r );
		IF r = TCP.Ok THEN res := done  ELSE  res := error  END
	END OpenConnection;

	PROCEDURE AsyncOpenConnection* (  VAR conn: Connection; locPort: UNSIGNED16; remIP: IPAdr; remPort: UNSIGNED16;
																 VAR res: SIGNED16 );
	BEGIN
		OpenConnection( conn, locPort, remIP, remPort, res )
	END AsyncOpenConnection;


	PROCEDURE CloseConnection* ( conn: Connection );
	BEGIN
		IF conn # NIL THEN conn.Close() END
	END CloseConnection;

	PROCEDURE Requested* ( conn: Connection ): BOOLEAN;
	BEGIN
		RETURN (conn.state = listening) & conn.Requested() 
	END Requested;

	PROCEDURE Accept* ( conn: Connection; VAR newC: Connection; VAR res: SIGNED16 );
	VAR r: SIGNED32;
	BEGIN
		conn.Accept( newC, r );
		IF r = TCP.Ok THEN res := done  ELSE  res := error  END
	END Accept;

	PROCEDURE State* (conn: Connection): SIGNED16;
	BEGIN
		CASE conn.state OF
		| TCP.Closed:		RETURN closed
		| TCP.Listen:			RETURN listening  
		| TCP.Established:	RETURN inout
		ELSE
			RETURN undef
		END
	END State;

	PROCEDURE GetPartner* (conn:Connection; VAR remIP: IPAdr; VAR remPort: UNSIGNED16);
	BEGIN
		remIP := conn.fip;
		remPort := SHORT( conn.fport )
	END GetPartner;

	(*----- Read -----*)

	PROCEDURE Read* (conn: Connection; VAR ch: CHAR);
	VAR l: SIZE; r: INTEGER; bytes: ARRAY 1 OF CHAR;
	BEGIN 
		conn.Receive( bytes, 0, 1, 1, l, r );
		ch := bytes[0]
	END Read;

	PROCEDURE ReadBytes* ( conn: Connection; pos, len: SIGNED32; VAR buf: ARRAY OF S.BYTE );
	VAR l: SIZE; r: INTEGER;
	BEGIN 
		conn.Receive( S.VAL( Bytes, buf ), pos, len, len, l, r );
	END ReadBytes;

	PROCEDURE ReadBool* (conn: Connection; VAR b: BOOLEAN);
	VAR l: SIZE; r: INTEGER; bytes: ARRAY 1 OF CHAR;
	BEGIN 
		conn.Receive(bytes, 0, 1, 1, l, r );
		b := ODD(ORD(bytes[0]));
	END ReadBool;

	PROCEDURE ReadInt* ( conn: Connection; VAR x: SIGNED16 );
	VAR buf: ARRAY 4 OF CHAR; len: SIZE; res: INTEGER;
	BEGIN 
		conn.Receive( buf, 0, 2, 2, len, res ); 
		IF (res = 0) & (len = 2) THEN
			x := ORD(buf[0])*100H + ORD(buf[1])
		ELSE
			x := 0
		END
	END ReadInt;

	PROCEDURE ReadLInt* (conn: Connection; VAR x: SIGNED32);
	VAR buf: ARRAY 4 OF CHAR; len: SIZE; res: INTEGER;
	BEGIN 
		conn.Receive( buf, 0, 4, 4, len, res ); 
		IF (res = 0) & (len = 4) THEN
		x := ORD(buf[0])*1000000H + ORD(buf[1])*10000H + ORD(buf[2])*100H + ORD(buf[3])
		ELSE
			x := 0
		END
	END ReadLInt;

	(** Blocking read a string terminated by ( [CR]LF | 0X ). *)
	PROCEDURE ReadString* (conn: Connection; VAR s: ARRAY OF CHAR);
	VAR
		ch, ch0: CHAR;
		i, l: SIZE; r: INTEGER;
		bytes: ARRAY 1 OF CHAR;
	BEGIN
		i := -1; ch := 0X;
		REPEAT
			INC( i );
			ch0 := ch; 
			conn.Receive( bytes, 0, 1, 1, l, r );
			ch := bytes[0];
			s[i] := ch;
		UNTIL ( r # TCP.Ok) OR (ch = 0X) OR (ch = LF);
		IF (ch = LF) & (ch0 = CR) THEN
			s[i - 1] := 0X
		ELSE s
			[i] := 0X
		END
	END ReadString;

	(*----- Write -----*)

	PROCEDURE Write* (conn: Connection; ch: CHAR);
	VAR r: SIGNED32; bytes: ARRAY 1 OF CHAR;
	BEGIN
		bytes[0] := ch;
		conn.Send( bytes, 0, 1, TRUE, r )
	END Write;

	PROCEDURE WriteBytes* (conn: Connection; pos, len: SIGNED32; CONST buf: ARRAY OF S.BYTE );
	VAR r: SIGNED32;
	BEGIN 
		conn.Send( S.VAL( Bytes, buf ), pos, len, TRUE, r)
	END WriteBytes;

	PROCEDURE WriteBool* (conn: Connection; b: BOOLEAN);
	VAR r: SIGNED32; bytes: ARRAY 1 OF CHAR;
	BEGIN
		IF b THEN bytes[0] := 1X ELSE bytes[0] := 0X END;
		conn.Send( bytes, 0, 1, TRUE, r )
	END WriteBool;

	PROCEDURE WriteInt* (conn: Connection; x: SIGNED16);
	VAR buf: ARRAY 2 OF CHAR; r: SIGNED32;
	BEGIN
		buf[0] := CHR(x DIV 100H MOD 100H);
		buf[1] := CHR(x MOD 100H);
		conn.Send( buf, 0, 2, TRUE, r )
	END WriteInt;

	PROCEDURE WriteLInt* (conn: Connection; x: SIGNED32);
	VAR buf: ARRAY 4 OF CHAR; r: SIGNED32;
	BEGIN
		buf[0] := CHR(x DIV 1000000H MOD 100H);
		buf[1] := CHR(x DIV 10000H MOD 100H);
		buf[2] := CHR(x DIV 100H MOD 100H);
		buf[3] := CHR(x MOD 100H);
		conn.Send( buf, 0, 4, TRUE, r )
	END WriteLInt;

	PROCEDURE WriteString* (conn: Connection; CONST s: ARRAY OF CHAR);
	VAR
		cs: ARRAY 2 OF CHAR;
		i, r: SIGNED32;
	BEGIN  i := 0;
		WHILE s[i] # 0X DO  INC( i )  END;
		conn.Send( s, 0, i, FALSE, r);
		cs[0] := CR; cs[1] := LF;
		conn.Send( cs, 0, 2, TRUE, r )
	END WriteString;

(******************************** UDP **************************************)

	PROCEDURE OpenSocket* ( VAR soc: Socket; locPort: UNSIGNED16; VAR res: SIGNED16 );
	VAR r: SIGNED32;
	BEGIN
		NEW( soc, LONG( locPort ) MOD 10000H, r );
		IF r = UDP.Ok THEN res := done  ELSE  res := error  END
	END OpenSocket;

	PROCEDURE CloseSocket* (S: Socket);
	BEGIN
		S.Close();
	END CloseSocket;

	PROCEDURE AvailableDG* (soc: Socket): SIGNED32;
	BEGIN
		RETURN 0
	END AvailableDG;

	PROCEDURE SendDG* ( soc: Socket; remIP: IPAdr; remport: UNSIGNED16; pos, len: SIGNED32; CONST buf: ARRAY OF S.BYTE );
	VAR res: INTEGER;
	BEGIN
		soc.Send( remIP, LONG(remport) MOD 10000H, S.VAL( Bytes, buf ), pos, len, res )
	END SendDG;

	PROCEDURE ReceiveDG* ( soc: Socket; VAR remIP: IPAdr; VAR remport: UNSIGNED16; 
							pos: SIGNED32; VAR len: SIGNED32; VAR buf: ARRAY OF S.BYTE );
	VAR res: SIGNED32; port: UNSIGNED32; length: SIZE;
	BEGIN
		soc.Receive( S.VAL( Bytes, buf ), pos, len, 0, remIP, port, length, res );
		len := length(SIGNED32);
		remport := SHORT( port) 
	END ReceiveDG;

	(** Write 2 bytes in network byte ordering to buf[pos]. *)

	PROCEDURE PutInt* (VAR buf: ARRAY OF S.BYTE; pos: SIGNED16; x: SIGNED16);
	BEGIN
		buf[pos] := CHR(x DIV 100H MOD 100H);
		buf[pos+1] := CHR(x MOD 100H)
	END PutInt;

	(** Write 4 bytes in network byte ordering to buf[pos]. *)

	PROCEDURE PutLInt* (VAR buf: ARRAY OF S.BYTE; pos: SIGNED16; x: SIGNED32);
	BEGIN
		buf[pos] := CHR(x DIV 1000000H MOD 100H);
		buf[pos+1] := CHR(x DIV 10000H MOD 100H);
		buf[pos+2] := CHR(x DIV 100H MOD 100H);
		buf[pos+3] := CHR(x MOD 100H)
	END PutLInt;

	(** Read 2 bytes in network byte ordering from buf[pos]. *)

	PROCEDURE GetInt* (CONST buf: ARRAY OF S.BYTE; pos: SIGNED16; VAR x: SIGNED16);
	BEGIN
		x := ORD(buf[pos])*100H + 
			ORD(buf[pos+1])
	END GetInt;

	(** Read 4 bytes in network byte ordering from buf[pos]. *)

	PROCEDURE GetLInt* (CONST buf: ARRAY OF S.BYTE; pos: SIGNED16; VAR x: SIGNED32);
	BEGIN
		x := ORD( buf[pos] )*1000000H + 
			ORD( buf[pos+1] )*10000H + 
			ORD( buf[pos+2] )*100H + 
			ORD( buf[pos+3] )
	END GetLInt;

	PROCEDURE Show*;
	VAR p: Password;
	BEGIN
		p := passwords; 
		WHILE p # NIL DO WriteURL(p.service, p.user, p.host); p := p.next END;
		Texts.WriteLn(W);
		Texts.Append(Oberon.Log, W.buf)
	END Show;

BEGIN
	anyIP := IP.NilAdr;
	allIP := IP.NilAdr;
	allIP.usedProtocol := IP.IPv4;
	allIP.ipv4Adr := SIGNED32( 0FFFFFFFFH );

	Texts.OpenWriter(W);

	passwords := NIL;
	Start
END NetSystem.
