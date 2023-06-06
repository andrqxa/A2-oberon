MODULE DisplayLinear;

IMPORT SYSTEM, Displays, Plugins, Machine, Kernel, Commands, Options,
	Platform, PsConfig, Channels, Video := AcStreamVideoOut, AcAxiDma, Trace;

#IF UNIX THEN

IMPORT Unix, Modules;

CONST FrameBufDevName* = "/dev/disp_dma_buf"; (** display DMA buffer device name *)

#END

CONST
	(*
		Video settings for 1024 x 768 @ 62 Hz
	*)
	Width* = 1024;
	Height* = 768;

	PlClkDiv0* = 10;
	PlClkDiv1* = 15;
	PlClkDiv2* = 3;

	HorizFrontPorch* = 24;
	HorizSyncWidth* = 136;
	HorizBackPorch* = 160;
	HorizSyncPolarity* = TRUE;

	VertFrontPorch* = 3;
	VertSyncWidth* = 6;
	VertBackPorch* = 29;
	VertSyncPolarity* = TRUE;

(*
	(*
		Video settings for 800 x 480 @ 65 Hz
	*)
	Width* = 800;
	Height* = 480;

	PlClkDiv0* = 10;
	PlClkDiv1* = 15*2;
	PlClkDiv2* = 3*2;

	HorizFrontPorch* = 40;
	HorizSyncWidth* = 48;
	HorizBackPorch* = 88;
	HorizSyncPolarity* = TRUE;

	VertFrontPorch* = 13;
	VertSyncWidth* = 3;
	VertBackPorch* = 32;
	VertSyncPolarity* = TRUE;
*)

	DefaultColor* = SIGNED32(0FFFFFFFFH); (** the color of the booting screen  *)

	FrameBufSize = Height * Width * 4; (* frame buffer size in bytes *)

TYPE

	Display = OBJECT(Displays.Display)
	CONST
		Format = 4;

		(** Transfer a block of pixels in "raw" display format to (op = set) or from (op = get) the display.  Pixels in the rectangular area are transferred from left to right and top to bottom.  The pixels are transferred to or from "buf", starting at "ofs".  The line byte increment is "stride", which may be positive, negative or zero. *)
		PROCEDURE { OVERRIDE } Transfer*(VAR buf: ARRAY OF CHAR; ofs, stride, x, y, w, h: SIZE; op: INTEGER);
		VAR bufadr, buflow, bufhigh, dispadr,w0,b,d: ADDRESS;
		BEGIN

			IF w > 0 THEN
				ASSERT(fbadr # 0);
				bufadr := ADDRESSOF(buf[ofs]);
				dispadr := fbadr + y * fbstride + x * Format;
				IF Displays.reverse THEN
					dispadr := fbadr + (height-y-1) * fbstride + (width-x-1) * Format;
				END;

				ASSERT((dispadr >= fbadr) & ((y+h-1)*fbstride + (x+w-1)*Format <=  fbsize));	(* display index check *)
				w := w * Format;	(* convert to bytes *)
				CASE op OF
					Displays.set:
						IF Displays.reverse THEN
							WHILE h > 0 DO
								w0 := w DIV Format; b:= bufadr; d := dispadr;
								WHILE w0 > 0 DO
									SYSTEM.MOVE(b, d, Format);
									INC(b,Format);
									DEC(d, Format);
									DEC(w0);
								END;
								INC(bufadr, stride); DEC(dispadr, fbstride);
								DEC(h)
							END
						ELSE
							w0 := w DIV Format;
							WHILE h > 0 DO
								Copy32(bufadr,dispadr,w0); (*SYSTEM.MOVE(bufadr, dispadr, w);*)
							#IF ~UNIX THEN
								Machine.FlushDCacheRange(dispadr, w);
							#END;
								INC(bufadr, stride); INC(dispadr, fbstride);
								DEC(h)
							END
						END;
					|Displays.get:
						IF Displays.reverse THEN
							buflow := ADDRESSOF(buf[0]); bufhigh := buflow + LEN(buf);
							WHILE h > 0 DO
								ASSERT((bufadr >= buflow) & (bufadr+w <= bufhigh));	(* index check *)
								w0 := w DIV Format; b:= bufadr; d := dispadr;
								WHILE w0 > 0 DO
									SYSTEM.MOVE(d, b, Format);
									INC(b,Format);
									DEC(d, Format);
									DEC(w0);
								END;
								INC(bufadr, stride); DEC(dispadr, fbstride);
								DEC(h)
							END;
						ELSE
							buflow := ADDRESSOF(buf[0]); bufhigh := buflow + LEN(buf);
							WHILE h > 0 DO
								ASSERT((bufadr >= buflow) & (bufadr+w <= bufhigh));	(* index check *)
								SYSTEM.MOVE(dispadr, bufadr, w);
								INC(bufadr, stride); INC(dispadr, fbstride);
								DEC(h)
							END;
						END;
					ELSE (* skip *)
				END
			END
		END Transfer;

	END Display;

VAR
	display: Display;
	vout: Video.Controller;

	pixelClock: FLOAT32; (* pixel clock in Hz *)

#IF UNIX THEN
	frameBufFid: INTEGER;
	frameBufMap: ADDRESS;
#ELSE
	frameBuf: POINTER TO ARRAY OF CHAR;
#END

	rCfgCmd, rCfgData: PORT OUT;
	rStatus: PORT IN;
	videoCfg: PORT OUT;
	rdma: AcAxiDma.ReadController;

	(*
		Reset programming logic

		polarity: reset signal polarity, TRUE for active high and FALSE for active low
	*)
	PROCEDURE ResetPl(polarity: BOOLEAN);
	VAR res, t: SIGNED32;
	BEGIN
		IF polarity THEN (* active high *)
			ASSERT(PsConfig.SetPlResets({},res));
			t := Kernel.GetTicks();
			WHILE Kernel.GetTicks() - t < 1 DO END;
			ASSERT(PsConfig.SetPlResets({0..3},res));
		ELSE (* active low *)
			ASSERT(PsConfig.SetPlResets({0..3},res));
			t := Kernel.GetTicks();
			WHILE Kernel.GetTicks() - t < 1 DO END;
			ASSERT(PsConfig.SetPlResets({},res));
		END;
	END ResetPl;

	(*
		Setup clocks required for video streaming
	*)
	PROCEDURE SetupClocks;
	VAR
		res: SIGNED32;
		freq: SIGNED64;
	BEGIN
		(*
			Setup DMA frequency
		*)
		freq := PsConfig.GetPllClockFrequency(PsConfig.IoPll,res);
		Trace.String("IO PLL frequency is "); Trace.Int(freq,0); Trace.String(" Hz"); Trace.Ln;
		ASSERT(PsConfig.SetPlResets({0,1,2,3},res));
		IF PsConfig.SetPlClock(0,PsConfig.IoPll,PlClkDiv0,1,res) THEN
			Trace.String("FPGA clock 0 frequency has been changed to "); Trace.Int(PsConfig.GetPlClockFrequency(0,res),0); Trace.String(" Hz"); Trace.Ln;
		ELSE Trace.String("Error while setting FPGA clock 0 frequency, res="); Trace.Int(res,0); Trace.Ln;
		END;

		(*
			Setup display clocks
		*)
		(* pixel clock *)
		pixelClock := FLOAT32(freq)/PlClkDiv1;
		IF PsConfig.SetPlClock(1,PsConfig.IoPll,PlClkDiv1,1,res) THEN
			Trace.String("FPGA clock 1 frequency has been changed to "); Trace.Int(PsConfig.GetPlClockFrequency(1,res),0); Trace.String(" Hz"); Trace.Ln;
		ELSE Trace.String("Error while setting FPGA clock 1 frequency, res="); Trace.Int(res,0); Trace.Ln;
		END;
		(* clock used for serialization *)
		IF PsConfig.SetPlClock(2,PsConfig.IoPll,PlClkDiv2,1,res) THEN
			Trace.String("FPGA clock 2 frequency has been changed to "); Trace.Int(PsConfig.GetPlClockFrequency(2,res),0); Trace.String(" Hz"); Trace.Ln;
		ELSE Trace.String("Error while setting FPGA clock 2 frequency, res="); Trace.Int(res,0); Trace.Ln;
		END;
	END SetupClocks;

#IF UNIX THEN

CONST
	IOCTL_GET_PHYS_ADDR = SIGNED32(0x80085000);

	PROCEDURE AllocateFrameBuffer(VAR frameBufAddr, frameBufPhysAddr: ADDRESS);
	BEGIN
		frameBufFid := Unix.open(ADDRESSOF(FrameBufDevName[0]), INTEGERSET(Unix.O_RDWR+Unix.O_SYNC), 0);
		ASSERT(frameBufFid >= 0);
		frameBufMap := Unix.mmap(NIL, FrameBufSize, Unix.PROT_READ+Unix.PROT_WRITE, Unix.MAP_SHARED, frameBufFid, 0);
		ASSERT(frameBufMap > 0);
		VAR res := Unix.ioctl(frameBufFid, IOCTL_GET_PHYS_ADDR, ADDRESSOF(frameBufPhysAddr));
		ASSERT(res = 0);
		ASSERT(frameBufPhysAddr > 0);

		frameBufAddr := frameBufMap;

		Modules.InstallTermHandler(Cleanup);

		RETURN;
	FINALLY
		Cleanup;
	END AllocateFrameBuffer;

	PROCEDURE Cleanup;
	BEGIN
		IF frameBufMap > 0 THEN
			IGNORE Unix.munmap(frameBufMap, FrameBufSize);
		END;
		IF frameBufFid >= 0 THEN
			IGNORE Unix.close(frameBufFid);
		END;
	END Cleanup;

#ELSE

	PROCEDURE AllocateFrameBuffer(VAR frameBufAddr, frameBufPhysAddr: ADDRESS);
	CONST
		CacheLineSize = 32; (* cache line size in bytes *)
	BEGIN
		NEW(frameBuf,CacheLineSize*((Height*Width*4+CacheLineSize-1) DIV CacheLineSize)+CacheLineSize);
		frameBufAddr := ADDRESSOF(frameBuf[0]);
		frameBufAddr := frameBufAddr + (CacheLineSize - frameBufAddr MOD CacheLineSize); (* align to cache line size boundary *)
		ASSERT(frameBufAddr MOD CacheLineSize = 0);
		ASSERT(ADDRESSOF(frameBuf[LEN(frameBuf)-1]) >= frameBufAddr+Height*Width*4-1);
		frameBufPhysAddr := frameBufAddr;
	END AllocateFrameBuffer;

#END

	PROCEDURE Init;
	CONST
		DmaBurstLen = 16; (* AXI DMA burst length in transfers *)
	VAR
		res: INTEGER;
	BEGIN
		SetupClocks;

		(*
			Reset the programming logic
		*)
		ResetPl(FALSE);

		(*
			Setup ActiveCells components ports
		*)
		ASSERT(Channels.GetOutput(0,0, rCfgCmd));
		ASSERT(Channels.GetOutput(0,1, rCfgData));
		ASSERT(Channels.GetInput(0,0, rStatus));
		ASSERT(Channels.GetOutput(0,2, videoCfg));

		(*
			Allocate frame buffer
		*)
		VAR frameBufAddr, frameBufPhysAddr: ADDRESS;
		AllocateFrameBuffer(frameBufAddr, frameBufPhysAddr);

		Machine.Fill32(frameBufAddr, FrameBufSize, DefaultColor); (* fill the framebuffer with the default color *)

#IF ~UNIX THEN
		Machine.FlushDCacheRange(frameBufAddr, FrameBufSize);
#END

		(*
			Setup video streaming
		*)
		Video.InitController(vout,videoCfg,pixelClock);

		Video.SetHorizActiveSize(vout,Width);
		Video.SetHorizFrontPorch(vout,HorizFrontPorch);
		Video.SetHorizSyncWidth(vout,HorizSyncWidth);
		Video.SetHorizBackPorch(vout,HorizBackPorch);
		Video.SetHorizSyncPolarity(vout,HorizSyncPolarity);

		Video.SetVertActiveSize(vout,Height);
		Video.SetVertFrontPorch(vout,VertFrontPorch);
		Video.SetVertSyncWidth(vout,VertSyncWidth);
		Video.SetVertBackPorch(vout,VertBackPorch);
		Video.SetVertSyncPolarity(vout,VertSyncPolarity);

		(*
			Setup AXI DMA for transfering data from the frame buffer to the video output
		*)
		(* configure read channel of S_AXI_HP0 as a 32-bit interface *)
		(*VAR d := SYSTEM.GET32(0xF8008000); SYSTEM.PUT32(0xF8008000,SYSTEM.MSK(d,0xFFFFFFFE)+1);*)
		Platform.axihp[0].AFI_RDCHAN_CTRL := SYSTEM.MSK(Platform.axihp[0].AFI_RDCHAN_CTRL,SIGNED32(0xFFFFFFFE))+1;

		NEW(rdma,rCfgCmd,rCfgData,rStatus,4,16);
		rdma.SetBurstLen(DmaBurstLen);

		(* configure read DMA transfer *)
		rdma.SetAddr(SIZE(frameBufPhysAddr));
		rdma.SetCount(Width*Height);
		rdma.SetWrap(TRUE); (* recurring transfer *)

		(*
			Enable video output
		*)
		Video.Enable(vout,TRUE);
		rdma.Start;

		(*
			Install the display
		*)
		NEW(display);
		display.width := Width;
		display.height := Height;
		display.offscreen := 0;
		display.format := 4;
		display.unit := 10000;
		display.InitFrameBuffer(frameBufAddr,FrameBufSize,Width*4);
		display.desc := "Linear framebuffer driver for Zynq";
		display.Update;
		Displays.registry.Add(display,res);
		ASSERT(res = Plugins.Ok);
	END Init;

	PROCEDURE Install*(context: Commands.Context);
	VAR options: Options.Options;
	BEGIN
		IF context # NIL THEN
			NEW(options);
			options.Add("r", "reverse", Options.Flag);
			IF options.Parse(context.arg, context.error) THEN
				IF options.GetFlag("r") THEN Displays.Reverse() END;
			END;
		END;
	END Install;

	PROCEDURE -Copy32(sadr: ADDRESS; dadr: ADDRESS; len: SIGNED32);
	CODE
		LDR	R0, [SP, #dadr]
		LDR	R1, [SP, #len]
		LDR	R2, [SP, #sadr]
		MOV	R3, #0
	loop:
		CMP	R3, R1
		BGE	end
		LDR	R4, [R2, #0]
		STR	R4, [R0, #0]
		ADD	R0, R0, #4
		ADD	R2, R2, #4
		ADD	R3, R3, #1
		B loop
	end:
		ADD SP, SP, 12
	(*BEGIN
		SYSTEM.MOVE(sadr, dadr, 4*len)*)
	END Copy32;

BEGIN
	Init;
END DisplayLinear.

