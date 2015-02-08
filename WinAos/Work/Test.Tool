SystemTools.DoCommands

SystemTools.Timer start ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 8000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

StaticLinker.Link --fileName=kernel.bin --extension=Gof --displacement=100000H --path="./" Trace CPU Runtime Counters APIC Processors Queues BaseTypes Activities ExclusiveBlocks HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Reflection TrapWriters Traps Plugins Disks PCI ATADisks Caches Commands Files DiskVolumes Clock DiskFS Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker GenericLoader BootConsole ~

Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 4 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

FSTools.Mount TEMP AosFS VDISK0#1 ~
FSTools.Unsafe ~
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace TestLoad.Mod ~
FSTools.CopyFiles TestLoad.Gof => TEMP:TestLoad.Gof ~
FSTools.Watch TEMP ~
FSTools.Unmount TEMP ~

Partitions.SetConfig VDISK0#1
	TraceMode="5" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS IDE0#1"
	Boot="TestLoad."
	AosFS="DiskVolumes.New DiskFS.NewFS"
	ExtMemSize="120"
	Init=""
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~

SystemTools.Show HDD image build time:  ~ SystemTools.Timer elapsed ~

~

SystemTools.FreeDownTo FoxIntermediateBackend  FoxAMDBackend ~

Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod Trace.Mod Counters.Mod I386.APIC.Mod APIC.Processors.Mod Queues.Mod 
BaseTypes.Mod Activities.Mod ExclusiveBlocks.Mod Interrupts.Mod Coop.Runtime.Mod HeapManager.Mod 
BIOS.Environment.Mod Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod 
I386.Reals.Mod Coop.Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod Locks.Mod
I386.PCI.Mod Clock.Mod Coop.MemCache.Mod Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod 
FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod 
OberonFS.Mod FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod 
RelativeFileSystem.Mod Loader.Mod BitSets.Mod Diagnostics.Mod StringPool.Mod ObjectFile.Mod 
GenericLinker.Mod GenericLoader.Mod BootConsole.Mod Displays.Mod Inputs.Mod Options.Mod Events.Mod
EventsUtils.Mod EventsKernelLog.Mod EventsFileLog.Mod EventsMemoryLog.Mod DynamicStrings.Mod 
XMLObjects.Mod XML.Mod XMLScanner.Mod XMLParser.Mod Configuration.Mod FileHandlers.Mod BootShell.Mod 
I386.Network.Mod NetworkMii.Mod ActiveTimers.Mod I386.IP.Mod I386.IPv4.Mod IPv6.Mod ICMP.Mod UDP.Mod 
DNS.Mod TCP.Mod DHCP.Mod InitNetwork.Mod MinInitNetwork.Mod Ping.Mod TraceRoute.Mod 
TCPPortLog.Mod Serials.Mod SoundDevices.Mod Joysticks.Mod TVDriver.Mod VirtualDisks.Mod 
DisplayNull.Mod V24.Mod Beep.Mod SCSI.Mod I386.ATADisks.Mod I386.Adaptec7Script.Mod Adaptec7.Mod 
NCRScript.Mod SymbiosASPI.Mod SymbiosDisks.Mod NCR810Disks.Mod I386.Keyboard.Mod MousePS2.Mod 
MouseSerial.Mod DisplayLinear.Mod Loopback.Mod Ethernet3Com90x.Mod RTL8139.Mod RTL8169.Mod 
Intel8255x.Mod AM79C970.Mod EnsoniqSound.Mod YMF754.Mod i810Sound.Mod BT848.Mod UsbDebug.Mod 
Usbdi.Mod UsbHcdi.Mod UsbUhci.Mod UsbOhci.Mod UsbEhci.Mod UsbDriverLoader.Mod UsbUtilities.Mod 
Usb.Mod UsbHubDriver.Mod UsbStorageBase.Mod UsbStorageBot.Mod UsbStorageCbi.Mod ~


Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod Trace.Mod Coop.Runtime.Mod Counters.Mod I386.APIC.Mod 
APIC.Processors.Mod Queues.Mod Activities.Mod ExclusiveBlocks.Mod HeapManager.Mod Interrupts.Mod BIOS.Environment.Mod 
Mutexes.Mod Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod 
Coop.Objects.Mod Coop.Kernel.Mod KernelLog.Mod Plugins.Mod  ~


SystemTools.DoCommands
Compiler.Compile --cooperative --objectFile=Generic --newObjectFile -b=AMD --objectFileExtension=.Gof --symbolFileExtension=.Sym --destPath=./ --traceModule=Trace
I386.CPU.Mod Trace.Mod Coop.Runtime.Mod Counters.Mod Coop.Win32.Kernel32.Mod 
Win32.Processors.Mod Queues.Mod Activities.Mod ExclusiveBlocks.Mod Win32.Environment.Mod Mutexes.Mod 
Coop.Machine.Mod Coop.Heaps.Mod Coop.Modules.Mod GarbageCollector.Mod Coop.Objects.Mod 
Coop.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod Commands.Mod I386.Reals.Mod 
Reflection.Mod TrapWriters.Mod CRC.Mod SystemVersion.Mod Coop.Traps.Mod Locks.Mod Win32.Clock.Mod Disks.Mod 
Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod DiskVolumes.Mod 
OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod FATVolumes.Mod FATFiles.Mod 
ISO9660Volumes.Mod ISO9660Files.Mod Win32.User32.Mod Win32.WinTrace.Mod Win32.ODBC.Mod 
Win32.Shell32.Mod Win32.SQL.Mod Win32.WinFS.Mod RelativeFileSystem.Mod Loader.Mod BitSets.Mod 
Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod ~

SystemTools.DoCommands
StaticLinker.Link --fileFormat=PE32 --fileName=a2.exe --extension=Gof --displacement=401000H --path="./" Trace CPU Runtime Counters Kernel32 Processors Queues Activities ExclusiveBlocks Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog Streams Commands FIles WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader BootConsole ~
FSTools.CloseFiles a2.exe ~
~


Release.Build --path="./" A2Cooperative ~
Release.Build --path="./" WinAosCooperative ~

