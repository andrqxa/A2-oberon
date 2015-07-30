
# if you changed the sources, do not forget to compile below
FSTools.Unmount SRC ~
FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/ ~

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2Cooperative ~

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

Compiler.Compile  BitSets.Mod ObjectFile.Mod GenericLinker.Mod StaticLinker.Mod  ~
FoxProfiler.Reset
FoxProfiler.Report time ~
SystemTools.FreeDownTo ObjectFile ~
SystemTools.FreeDownTo FoxIntermediateBackend ~

SystemTools.DoCommands
SystemTools.Timer start ~
StaticLinker.Link
	--fileName=kernel.Bin
	--extension=Gox
	--displacement=0100000H
	--path="./"
	Runtime Trace Machine Heaps Modules Objects Kernel 
	KernelLog Streams Reflection  TrapWriters Traps  Plugins
	UsbDriverLoader Usbdi UsbDebug UsbHcdi UsbUtilities Usb UsbHubDriver UsbEhci PCI UsbEhciPCI UsbUhci UsbInfo
	Disks Commands
	UsbStorageBase UsbStorageBot UsbStorageBoot
	Reals Clock Dates Strings  Caches Files DiskVolumes DiskFS 
	Diagnostics BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole 
	~
SystemTools.Timer elapsed ~

~~~~ ----------------------------------- U S B --------------------------------

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2Cooperative ~

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
	Diagnostics BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole 
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
	ExtMemSize="512"
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

