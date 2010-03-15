MODULE EFITest;

IMPORT EFI, Trace;
BEGIN
	EFI.table.BS.Stall(1000000);
	Trace.Blue;
	Trace.String ("Hello ");
	Trace.Red;
	Trace.String ("World!");
END EFITest.

Compiler.Compile  --objectFile=Generic --symbolFile=Textual --extensions Runtime.Mod Trace.Mod EFI.Mod EFITrace.Mod EFITest.Mod EFIFileProtocol.Mod EFISimpleFS.Mod ~
StaticLinker.Link --fileName=test.efi --fileFormat=EFI32 --displacement=401000H Runtime Trace EFI EFITrace EFITest ~
