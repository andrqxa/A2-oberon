# if you changed the sources, do not forget to compile below
FSTools.Unmount SRC ~
FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/ ~

SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

StaticLinker.Link --fileName=kernel.bin --extension=Gof --displacement=100000H --path="./" Trace CPU Runtime Counters APIC Processors Queues BaseTypes Activities ExclusiveBlocks HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Reflection TrapWriters Traps Plugins Disks PCI ATADisks Caches Commands Files DiskVolumes Clock DiskFS Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole ~

Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 150 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
FSTools.CopyFiles -q
	*.Gof => TEMP:*.Gof
	*.Sym => TEMP:*.Sym ~
FSTools.CopyFiles -o -q 
	SRC:*.* => TEMP:*.* 
	Test.Tool => TEMP:Test.Tool
	T.Mod => TEMP:T.Mod
	~
FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="4" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS IDE0#1"
	Boot="DisplayLinear.Install"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	ExtMemSize="200"
	Init="114"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	TraceModules = "1"
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show HDD image build time:  ~ SystemTools.Timer elapsed ~


~~~~ ----------------------------------- U S B --------------------------------

Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --traceModule=Trace
	FoxProfiler.Mod ~
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --traceModule=Trace
	--profile 
	BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod 
	~

SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

StaticLinker.Link --fileName=kernel.bin --extension=Gof --displacement=100000H --path="./" 
	Trace CPU ACPI Timer Runtime Counters APIC Processors Queues BaseTypes Activities ExclusiveBlocks 
	HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel 
	KernelLog Streams Reflection  TrapWriters Traps  Plugins
	UsbDriverLoader Usbdi UsbDebug UsbHcdi UsbUtilities Usb UsbHubDriver UsbEhci PCI UsbEhciPCI UsbUhci UsbInfo 
	Disks Commands
	UsbStorageBase UsbStorageBot UsbStorageBoot
	Reals Clock Dates Strings Caches Files DiskVolumes DiskFS 
	Diagnostics FoxProfiler BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole 
	~


Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 150 ~	
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
FSTools.CopyFiles -q
	*.Gof => TEMP:*.Gof
~
FSTools.CopyFiles -o -q 
	SRC:*.* => TEMP:*.* 
~
FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="5" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS USB0#1"
	Boot="DisplayLinear.Install"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	ObjectFileExtension=".Gof"
	ExtMemSize="1000"
	Init="114"
	Boot1="FoxProfiler.Report time"
	Boot2="Keyboard.Install;MousePS2.Install"
	Boot3="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot4="WindowManager.Install"
	Boot5="FoxProfiler.Report time"	
	Boot6="Autostart.Run"
	Boot7="FoxProfiler.Report time"
	TraceModules = "1"
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show USB image build time:  ~ SystemTools.Timer elapsed ~


~~


WinDisks.Install "PhysicalDrive2" RW ~

~
*** CAUTION: check that drive is not a local drive !!!! ***
SystemTools.DoCommands
Partitions.FileToPartition PhysicalDrive2#0 hd.img 0 300000  ~
WinDisks.Uninstall "PhysicalDrive2" ~
~

(* compile the kernel *)
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --traceModule=Trace
I386.CPU.Mod BIOS.ACPI.Mod ACPI.Timer.Mod Trace.Mod Counters.Mod I386.APIC.Mod APIC.Processors.Mod Queues.Mod 
BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod HeapManager.Mod 
BIOS.Environment.Mod Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod 
I386.Reals.Mod Coop.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod 
Locks.Mod I386.PCI.Mod Clock.Mod Coop.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod 
ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod I386.ATADisks.Mod 
~



(* compile the kernel *)
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod Trace.Mod Counters.Mod I386.APIC.Mod APIC.Processors.Mod Queues.Mod 
BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod HeapManager.Mod 
BIOS.Environment.Mod Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod 
I386.Reals.Mod Coop.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod 
Locks.Mod I386.PCI.Mod Clock.Mod Coop.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod 
ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod I386.ATADisks.Mod 
~

Release.Build  --path="./" A2Cooperative ~

SystemTools.FreeDownTo FoxIntermediateBackend  FoxAMDBackend ~

Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod BIOS.ACPI.Mod ACPI.Timer.Mod Trace.Mod Counters.Mod I386.APIC.Mod APIC.Processors.Mod Queues.Mod 
BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod HeapManager.Mod 
BIOS.Environment.Mod Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod 
I386.Reals.Mod Coop.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod 
Locks.Mod BiosFreePCI.Mod Clock.Mod Coop.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod 
ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 

Displays.Mod Inputs.Mod 
Options.Mod Events.Mod EventsUtils.Mod EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod 
DynamicStrings.Mod XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod 
FileHandlers.Mod BootShell.Mod I386.Network.Mod NetworkMii.Mod ActiveTimers.Mod I386.IP.Mod 
I386.IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod DNS.Mod TCP.Mod DHCP.Mod InitNetwork.Mod MinInitNetwork.Mod 
Ping.Mod TraceRoute.Mod TCPPortLog.Mod Serials.Mod SoundDevices.Mod Joysticks.Mod TVDriver.Mod 
VirtualDisks.Mod DisplayNull.Mod V24.Mod Beep.Mod SCSI.Mod I386.ATADisks.Mod I386.Adaptec7Script.Mod 
Adaptec7.Mod NCRScript.Mod SymbiosASPI.Mod SymbiosDisks.Mod NCR810Disks.Mod I386.Keyboard.Mod 
MousePS2.Mod MouseSerial.Mod DisplayLinear.Mod Loopback.Mod Ethernet3Com90x.Mod RTL8139.Mod 
RTL8169.Mod Intel8255x.Mod AM79C970.Mod EnsoniqSound.Mod YMF754.Mod i810Sound.Mod BT848.Mod 
UsbDebug.Mod Usbdi.Mod UsbHcdi.Mod UsbUhci.Mod UsbOhci.Mod UsbEhci.Mod UsbEhciPCI.Mod UsbDriverLoader.Mod 
UsbUtilities.Mod Usb.Mod UsbHubDriver.Mod UsbStorageBase.Mod UsbStorageBot.Mod UsbStorageCbi.Mod 
UsbStorageScm.Mod UsbStorageBoot.Mod UsbStorage.Mod UsbHid.Mod UsbMouse.Mod UsbFTDI.Mod 
I386.UsbKeyboard.Mod UsbHidUP.Mod UsbHidErrors.Mod UsbHidReport.Mod UsbHidParserExt.Mod UsbHidParser.Mod 
UsbHidDriver.Mod UsbNetwork.Mod UsbNetworkUSB200M.Mod UsbPrinter.Mod UsbGarminGPS18.Mod 
UsbTouchscreen.Mod Bluetooth.Mod BluetoothUART.Mod UsbBluetooth.Mod BluetoothUSB.Mod BluetoothHCI.Mod 
BluetoothL2CAP.Mod BluetoothRFCOMM.Mod StringPool.Mod Diagnostics.Mod Debugging.Mod BitSets.Mod 
ObjectFile.Mod GenericLinker.Mod StaticLinker.Mod FoxBasic.Mod FoxProgTools.Mod FoxScanner.Mod 
FoxSyntaxTree.Mod FoxGlobal.Mod FoxActiveCells.Mod FoxHardware.Mod FoxFormats.Mod FoxPrintout.Mod 
FoxParser.Mod FoxSemanticChecker.Mod FoxBackend.Mod FoxSections.Mod FoxBinaryCode.Mod 
FoxFrontend.Mod FoxOberonFrontend.Mod FoxCompiler.Mod FoxFingerPrinter.Mod 
FoxInterfaceComparison.Mod FoxTextualSymbolFile.Mod FoxBinarySymbolFile.Mod FoxIntermediateCode.Mod 
FoxIntermediateBackend.Mod FoxCodeGenerators.Mod FoxBinaryObjectFile.Mod FoxGenericObjectFile.Mod 
FoxAMD64InstructionSet.Mod FoxAMD64Assembler.Mod FoxAMDBackend.Mod FoxProfiler.Mod XMM.I386.Math.Mod 
XMM.I386.MathL.Mod FoxArrayBase.Mod I386.FoxArrayBaseOptimized.Mod Errors.Mod ProcessInfo0.Mod 
ProcessInfo.Mod SystemTools.Mod Reboot.Mod DriverDatabase.Mod PCITools.Mod XMM.I386.Math.Mod 
XMM.I386.MathL.Mod Random.Mod Drand48.Mod SerialsVirtual.Mod Autostart.Mod FSTools.Mod UpTime.Mod 
CLUTs.Mod I386.Raster.Mod Localization.Mod Archives.Mod WMRectangles.Mod WMEvents.Mod 
Repositories.Mod FP1616.Mod Texts.Mod UndoManager.Mod CRC.Mod Inflate.Mod Unzip.Mod ZipFS.Mod Codecs.Mod 
UnicodeProperties.Mod ContextualDependency.Mod UnicodeBidirectionality.Mod I386.WMRasterScale.Mod 
WMGraphics.Mod TextUtilities.Mod Types.Mod Models.Mod WMProperties.Mod WMMessages.Mod 
WMWindowManager.Mod WMGraphicUtilities.Mod WMDropTarget.Mod WMComponents.Mod KernelLogger.Mod 
CompilerInterface.Mod FoxTextCompiler.Mod PCDebug.Mod PCM.Mod PCS.Mod PCT.Mod PCBT.Mod PCLIR.Mod PCO.Mod 
PCG386.Mod PCC.Mod PCV.Mod PCArrays.Mod PCB.Mod PCP.Mod PCA386.Mod PCOM.Mod PCOF.Mod PCOFPE.Mod 
PC.Mod ArrayBase.Mod I386.ArrayBaseOptimized.Mod PCOARM.Mod PCARMCP.Mod PCARMRegisters.Mod 
PCAARM.Mod PCGARM.Mod ASMAMD64.Mod PCAAMD64.Mod PCGAMD64.Mod WhitespaceRemover.Mod 
HostClipboard.Mod Tar.Mod Zlib.Mod ZlibBuffers.Mod ZlibDeflate.Mod ZlibInflate.Mod ZlibWriters.Mod 
ZlibReaders.Mod Zip.Mod ZipTool.Mod BIT.Mod PNGDecoder.Mod BMPCodec.Mod GIFCodec.Mod JPEGDecoder.Mod 
AnimationCodec.Mod UsbInfo.Mod UsbSkeleton.Mod UsbTools.Mod PartitionsLib.Mod FATScavenger.Mod 
Partitions.Mod DiskTests.Mod DiskBenchmark.Mod PartitionEditorTable.Mod FTPClient.Mod XYModem.Mod 
Shell.Mod ShellSerial.Mod Installer.Mod CryptoBigNumbers.Mod CryptoBase64.Mod CryptoUtils.Mod 
CryptoCiphers.Mod CryptoARC4.Mod CryptoDES.Mod CryptoDES3.Mod CryptoHashes.Mod CryptoMD5.Mod 
CryptoSHA1.Mod CryptoSHA256.Mod CryptoKeccakF1600.Mod CryptoKeccakSponge.Mod CryptoSHA3.Mod 
CryptoPrimes.Mod CryptoDSA.Mod CryptoDiffieHellman.Mod CryptoAES.Mod CryptoBlowfish.Mod 
CryptoTwofish.Mod CryptoCAST.Mod CryptoHMAC.Mod CryptoIDEA.Mod CryptoRSA.Mod Fido.Mod I386.CPUID.Mod 
A2Sequencers.Mod PictImages.Mod V24Tracer.Mod XMLGeneratorSchema.Mod CSS2.Mod CSS2Scanner.Mod 
CSS2Parser.Mod RAWPrinter.Mod LPR.Mod TLS.Mod TCPServices.Mod TestServer.Mod TCPTools.Mod 
Win32.Performance.Mod Bin2Hex.Mod BinToCode.Mod Base64.Mod DisplayGTF.Mod GZip.Mod ShellCommands.Mod 
Telnet.Mod Info.Mod TFClasses.Mod Mail.Mod SMTPClient.Mod TFLog.Mod WebHTTP.Mod WebHTTPClient.Mod 
WebHTTPTools.Mod WebHTTPServer.Mod WebHTTPServerTools.Mod WebSSMPPlugin.Mod WebDefaultSSMP.Mod 
WebHTTPServerStatistics.Mod WebWormWatch.Mod POP3Client.Mod RFC865Client.Mod QuoteServer.Mod RfsConnection.Mod 
RfsClientProxy.Mod RfsFS.Mod TFTP.Mod TFTPServer.Mod TFTPFS.Mod FTPFS.Mod WebFTPServer.Mod XModem.Mod 
SearchTools.Mod DiffLib.Mod TextConverter.Mod TaskScheduler.Mod OSC.Mod OSCRegistry.Mod OSCQueue.Mod 
OSCService.Mod OSCNet.Mod OSCEval.Mod OSCExample.Mod FTP.Mod DES.Mod VNCServer.Mod WAVCodec.Mod 
MP3Decoder.Mod I386.IDCT.Mod AVI.Mod DivXTypes.Mod I386.DivXHelper.Mod I386.DivXDecoder.Mod 
MPEGTables.Mod I386.MPEGUtilities.Mod MPEGVideoDecoder.Mod JPEG2000DecoderUtil.Mod 
JPEG2000DecoderCS.Mod JPEG2000Decoder.Mod MD5.Mod HTTPSupport.Mod HTTPSession.Mod DynamicWebpage.Mod 
DynamicWebpagePlugin.Mod PrevalenceSystem.Mod WMDropTarget.Mod GenericSort.Mod WebStd.Mod WebComplex.Mod 
WMCharCodes.Mod HTMLScanner.Mod HTMLParser.Mod NewHTTPClient.Mod UnihanParser.Mod CSV.Mod 
ColorModels.Mod WMDefaultWindows.Mod WMDefaultFont.Mod WMFontManager.Mod WMOberonFonts.Mod 
WMCCGFonts.Mod WMBitmapFont.Mod OpenTypeInt.Mod OpenTypeScan.Mod OpenType.Mod OpenTypeFonts.Mod 
WMOTFonts.Mod WindowManager.Mod Attributes.Mod WMStandardComponents.Mod WMProgressComponents.Mod 
WMShapes.Mod WMFigures.Mod WMScrollableComponents.Mod WMPieMenu.Mod WMPopups.Mod 
PositionDebugging.Mod SyntaxHighlighter.Mod WMTextView.Mod WMInputMethods.Mod WMEditors.Mod 
WMSearchComponents.Mod WMMacros.Mod WMGrids.Mod WMStringGrids.Mod WMTrees.Mod WMMixer.Mod 
WMTabComponents.Mod WMColorComponents.Mod WMAnimations.Mod WMDropDownLists.Mod WMRestorable.Mod 
WMApplications.Mod WMDialogs.Mod WMDocumentEditor.Mod WMErrors.Mod WMOSD.Mod WMArchives.Mod 
WMCharMap.Mod WMUnicodeMarkerTool.Mod ModuleParser.Mod ModuleTrees.Mod WMXMLTree.Mod 
WMDiagnostics.Mod PETTrees.Mod PETModuleTree.Mod PETXMLTree.Mod PET.Mod WMArabicIME.Mod 
WMArmenianIME.Mod WMHebrewIME.Mod WMPinyinIME.Mod WMRussianIME.Mod WMUkrainianIME.Mod WMUnicodeIME.Mod 
WMInputMethodTool.Mod WMUtilities.Mod WMTrapWriter.Mod FoxA2Interface.Mod WMMenus.Mod 
WMDiagramComponents.Mod MainMenu.Mod StartMenu.Mod HotKeys.Mod WMNavigate.Mod WMNavigator.Mod WMDesktops.Mod 
WMSystemComponents.Mod WMFileManager.Mod WMSearchTool.Mod WMFTPClient.Mod WMUsbInfo.Mod SkinLanguage.Mod 
FNHistories.Mod SkinEngine.Mod Notepad.Mod WMProcessInfo.Mod WMObjectTracker.Mod WMTCPTracker.Mod 
WMKernelLog.Mod 

WMEventLog.Mod WMPartitionsComponents.Mod WMPartitions.Mod 
PartitionEditorComponents.Mod PartitionEditor.Mod MultiLogger.Mod MemoryReader.Mod Decoder.Mod I386Decoder.Mod 
ARMDecoder.Mod AMD64Decoder.Mod WMTextTool.Mod WMPerfMonPlugins.Mod WMPerfMonAlerts.Mod 
WMPerfMonAlertsUtils.Mod WMPerfMonPluginModVars.Mod WMPerfMonPluginHeap.Mod WMPerfMonPluginProcesses.Mod 
WMPerfMonPluginSerials.Mod WMPerfMonPluginNetwork.Mod WMPerfMonPluginDisks.Mod WMPerfMonPluginPerfMon.Mod 
WMPerfMonPluginEvents.Mod WMPerfMonPluginMessages.Mod WMPerfMonComponents.Mod WMPerfMonTabSystem.Mod 
WMPerfMonTabAlerts.Mod WMClock.Mod WMCalendar.Mod WMV24Component.Mod WMShell.Mod SSHGlobals.Mod SSHKeys.Mod 
SSHTransport.Mod SSHAuthorize.Mod SSH.Mod SSHClient.Mod TFStringPool.Mod BimboScanner.Mod 
TFTypeSys.Mod TFDumpTS.Mod TFScopeTools.Mod TFCheck.Mod TFAOParser.Mod TFModuleTrees.Mod TFPET.Mod 
TFClasses.Mod TFDocGenerator.Mod TFXRef.Mod CharacterLineup.Mod WMDesktopIcons.Mod 
WMTextStyleTool.Mod WMVNCView.Mod VNC.Mod WMVT100.Mod SkinEditor.Mod Looks.Mod WMSkinLoader.Mod 
WMBackdropLoader.Mod WMInspectionComponents.Mod WMInspector.Mod WMRepositories.Mod WMBuilder.Mod 
WMBuilderTransformer.Mod CyberbitNetInstall.Mod WMDiff.Mod WMTaskScheduler.Mod IMAPUtilities.Mod IMAP.Mod 
IMAPClient.Mod RMSMTP.Mod IMAPGUI.Mod WMPerfMonPluginFTPServer.Mod WMPerfMonPluginHTTPServer.Mod 
WMPerfMonPluginQuoteServer.Mod WMPerfMonPluginVNCServer.Mod WMPerfMonPluginExample.Mod WMModuleState.Mod 
WMKeyCode.Mod WMPicView.Mod ComponentViewer.Mod WMScreenShot.Mod WMBackdrop.Mod WMInstaller.Mod 
CDRecordUtils.Mod CDRecordLib.Mod MakeIsoImages.Mod CDRecord.Mod WMCDRecorder.Mod HotKeysCommands.Mod 
I386.VMWareTools.Mod SynergyClient.Mod TVChannels.Mod TeletextDecoder.Mod TV.Mod TeletextFont.Mod 
TeletextBrowser.Mod TeletextViewer.Mod TVRemoteControl.Mod I386.WMTransitions.Mod MediaPlayer.Mod 
Presentation.Mod MP3Player.Mod WMPlayer.Mod WAVRecorder.Mod OGGUtilities.Mod OGGVorbisPlayer.Mod 
WMOGGPlayer.Mod DTPData.Mod DTPUtilities.Mod DTPView.Mod DTPEditor.Mod DTPText.Mod DTPRect.Mod 
DTPImage.Mod GfxMatrix.Mod GfxImages.Mod GfxPaths.Mod GfxRegions.Mod GfxFonts.Mod Gfx.Mod 
GfxRaster.Mod GfxBuffer.Mod CSS2Properties.Mod XMLComponents.Mod XMLStyle.Mod XMLLoader.Mod 
SVGUtilities.Mod SVGColors.Mod SVGMatrix.Mod SVG.Mod SVGGradients.Mod SVGFilters.Mod SVGRenderer.Mod 
SVGLoader.Mod SVGDecoder.Mod WebBrowserComponents.Mod XMLTransformer.Mod HTMLTransformer.Mod 
WebBrowserPanel.Mod WebBrowser.Mod MailStorage.Mod BimboMail.Mod DebugLog.Mod WMJoysticks.Mod 
WMTetris.Mod VNCTetrisServer.Mod Bimso.Mod WMScribble.Mod WMGraphicsDemo.Mod SortDemo.Mod 
FractalDemo.Mod WMBunny.Mod TuringCoatWnd.Mod W3dVectors.Mod W3dMatrix.Mod W3dGeometry.Mod 
W3dAbstractWorld.Mod W3dObjectGenerator.Mod W3dRasterizer.Mod W3dWorld.Mod W3dExplorer.Mod W3dMenu.Mod 
CATServer.Mod W3dClusterWatch.Mod WMSlideshow.Mod Snow.Mod MenuEdit.Mod PresentViewer.Mod 
TestSuite.Mod PCTest.Mod Versioning.Mod FoxTest.Mod TestFiles.Mod BenchTCP.Mod TestDates.Mod 
TestStrings.Mod BenchXML.Mod BenchSyntaxHighlighter.Mod CryptoTestBigNumbers.Mod 
CryptoTestCiphers.Mod CryptoTestDH.Mod CryptoTestDSA.Mod CryptoTestHMAC.Mod CryptoTestHashes.Mod 
CryptoTestRSA.Mod BeepTest.Mod JoysticksTest.Mod TestMenu.Mod PieTest.Mod TestTrees.Mod 
TestComponentDragDrop.Mod ComponentInfo.Mod TestComponents.Mod TestXMLPlugins.Mod SSFS.Mod HelloWorld.Mod 
HelloWorld1.Mod HelloWorld2.Mod HelloWorld3.Mod Example1.Mod Example2.Mod Example3.Mod Example4.Mod 
Example5.Mod Example6.Mod Example7.Mod Example8.Mod ExampleTextWriter.Mod JavaLocks.Mod 
WebAccounts.Mod WebForum.Mod ExerciseGroups.Mod IsoImages.Mod ReleaseThreadPool.Mod Release.Mod 
PETReleaseTree.Mod Linker0.Mod Linker1.Mod Linker.Mod BootManager.Mod EFI.Mod I386.EFIMachine.Mod 
EFIBlockIO.Mod EFIDiskIO.Mod EFIFileProtocol.Mod EFISimpleFS.Mod EFILoadedImage.Mod 
EFIGraphicsOutput.Mod EFITrace.Mod EFILib.Mod EFITest.Mod EFIGraphicalConsole.Mod EFIA2Loader.Mod 
Sage.UDPChatBase.Mod Sage.UDPChatServer.Mod Sage.UDPChatClient.Mod CyrillicUtilities.Mod YMF754Util.Mod 
SambaClient.Mod SambaServer.Mod srBase.Mod srRayEngine.Mod srMath.Mod I386.srE.Mod srGL.Mod srHex.Mod 
srImage.Mod srVoxel.Mod srVoxel2.Mod srVoxel3.Mod srVolShader.Mod srVoxel4.Mod srVoxel5.Mod 
srM2Space.Mod srM3Space.Mod srM5Space.Mod srM6Space.Mod srRastermovie.Mod srTexVox.Mod 
srThermoCell.Mod srTree.Mod sr3DTexture.Mod srLifeVox.Mod srRotaVox.Mod srvoxels.Mod srRender.Mod 
MenuPages.Mod WMOverlay.Mod PrettyPrint.Mod NbrInt8.Mod NbrInt16.Mod NbrInt32.Mod I386.NbrInt64.Mod 
NbrInt.Mod NbrRat.Mod I386.NbrRe32.Mod I386.NbrRe64.Mod NbrRe.Mod NbrCplx.Mod NbrStrings.Mod 
DataErrors.Mod DataIO.Mod Data.Mod DataStacks.Mod DataQueues.Mod DataLists.Mod DataTrees.Mod 
MathInt.Mod MathRat.Mod MathReSeries.Mod MathRe.Mod MathCplxSeries.Mod MathCplx.Mod MathCbrt.Mod 
MathErf.Mod MathGamma.Mod CalcFn.Mod CalcD1.Mod CalcD2.Mod CalcD3.Mod CalcD4.Mod CalcGauss.Mod 
MathMitLef.Mod CalcConvolution.Mod CalcGrunwald.Mod CalcDiethelm.Mod I386.Array1dBytes.Mod 
Array1dInt.Mod Array1dRat.Mod Array1dRe.Mod Array1dCplx.Mod I386.ArrayXdBytes.Mod ArrayXdInt.Mod 
ArrayXdRat.Mod ArrayXdRe.Mod ArrayXdCplx.Mod Array2dInt.Mod Array2dRat.Mod Array2dRe.Mod 
Array2dCplx.Mod VecInt.Mod VecRat.Mod VecRe.Mod VecCplx.Mod MtxInt.Mod MtxRat.Mod MtxRe.Mod MtxCplx.Mod 
CubeInt.Mod CubeRat.Mod CubeRe.Mod CubeCplx.Mod LinEqRe.Mod LinEqLU.Mod LinEqCholesky.Mod 
LinEqSVD.Mod HCubeInt.Mod HCubeRat.Mod HCubeRe.Mod HCubeCplx.Mod WPM.Mod AlmSmtpReceiver.Mod 
TFSMTPServer.Mod WMFontCCGConverter.Mod WebCGI.Mod RegisterRFW.Mod WebBimbodot.Mod TFWebForum.Mod 
PDF.Mod AFM.Mod PDFExample.Mod Visualizer.Mod ReleaseVisualizerScanner.Mod 
ReleaseVisualizer.Mod OdUtil.Mod OdXml.Mod OdCond.Mod OdAuthBase.Mod OdAuth.Mod OdClient.Mod OdVCSBase.Mod 
SVNArgument.Mod SVNOutput.Mod SVNUtil.Mod SVNAdmin.Mod OdSvn.Mod SVNWebDAV.Mod SVN.Mod UsbRS232.Mod 
FirewireLowUtil.Mod FirewireLow.Mod FirewireSBP2.Mod 
~


SystemTools.DoCommands
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod Trace.Mod Counters.Mod I386.APIC.Mod APIC.Processors.Mod Queues.Mod 
BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod HeapManager.Mod 
BIOS.Environment.Mod Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod 
I386.Reals.Mod Coop.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod 
Locks.Mod I386.PCI.Mod Clock.Mod Coop.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod 
UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod 
DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod 
ISO9660Files.Mod RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod 
ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod
~

SystemTools.DoCommands
StaticLinker.Link --fileFormat=PE32 --fileName=a2.exe --extension=Gof --displacement=401000H --path="./" Trace CPU Runtime Counters Kernel32 Processors Queues Activities ExclusiveBlocks Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader BootConsole ~
FSTools.CloseFiles a2.exe ~
~

Release.Build --path="./" A2Cooperative ~
Release.Build --path="./" WinAosCooperative ~

