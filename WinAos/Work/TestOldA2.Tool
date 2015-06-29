~~~~ old A2 with binary object file ~~~

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2 ~

FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/ ~

SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

Linker.Link \.Obx kernel.Bin  0100000H 100000H Kernel Traps
			UsbHubDriver UsbEhci UsbUhci UsbStorageBoot UsbInfo
			DiskVolumes DiskFS 
			Loader BootConsole ~
			
Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 150 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
FSTools.CopyFiles -q
	*.Obx => TEMP:*.Obx
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
	ExtMemSize="500"
	Init="114"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	TraceModules = "1"
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show USB image build time:  ~ SystemTools.Timer elapsed ~


~~


~~~~ old A2 with generic object file ~~~

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2NewObjectFile ~

FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/ ~

SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

StaticLinker.Link
	--fileName=kernel.Bin
	--extension=GofX
	--displacement=0100000H
	--path="./"
	Runtime Trace Machine Heaps Modules Objects Kernel 
	KernelLog Plugins Streams Commands Reals 
	Reflection TrapWriters Traps Locks PCI Clock MemCache Disks Files Caches 
	UsbDebug  Usbdi UsbHcdi UsbUhci UsbEhci UsbEhciPCI UsbUtilities UsbDriverLoader Usb UsbHubDriver UsbStorageBase UsbStorageBot UsbStorageBoot
	DiskVolumes DiskFS Dates Strings Diagnostics BitSets StringPool ObjectFile GenericLinker 
	GenericLoader BootConsole 
	~
				
Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 150 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
FSTools.CopyFiles -q
	*.GofX => TEMP:*.GofX
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
	ObjectFileExtension=".GofX"
	ExtMemSize="500"
	Init="114"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
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
Partitions.FileToPartition PhysicalDrive2#0 hd.img 0 160000  ~
WinDisks.Uninstall "PhysicalDrive2" ~
~
