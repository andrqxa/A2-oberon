~~~~ old A2 with binary object file ~~~

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2mini ~

FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/ ~

SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

Linker.Link \.Obx kernel.Bin  0100000H 100000H Kernel Traps
			UsbHubDriver UsbEhci UsbEhciPCI UsbUhci UsbInfo UsbStorageBoot 
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
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	Boot6="FoxProfiler.Report time"
	TraceModules = "1"
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show USB image build time:  ~ SystemTools.Timer elapsed ~


~~


~~~~ old A2 with generic object file ~~~

Compiler.Compile --profile --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gox --symbolFileExtension=.Syx --destPath=AOS: 
BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod 
GenericLinker.Mod GenericLoader.Mod ~

FSTools.Mount AOS RelativeFileSystem ./ ~
Release.Build A2NewObjectFile ~

FSTools.Unmount SRC ~
FSTools.Mount SRC RelativeFileSystem /a2/branches/cooperative/source/   ~

SystemTools.DoCommands


SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 300000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

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
	Diagnostics FoxProfiler BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole 
	~
				
Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 150 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
FSTools.CopyFiles -q
	*.Gox => TEMP:*.Gox
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
	ObjectFileExtension=".Gox"
	ExtMemSize="500"
	Init="114"
	Boot1="Keyboard.Install;MousePS2.Install"
	Boot2="DriverDatabase.Enable;UsbHubDriver.Install;UsbEhci.Install;UsbUhci.Install;UsbOhci.Install"
	Boot3="WindowManager.Install"
	Boot5="Autostart.Run"
	TraceModules = "1"
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show USB image build time:  ~ SystemTools.Timer elapsed ~


~~

