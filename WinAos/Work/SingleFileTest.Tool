

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
	ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod Test.Mod ~

PCAAMD64.Assemble OBLUnreal.Asm ~
PartitionsLib.SetBootLoaderFile OBLUnreal.Bin ~

FSTools.DeleteFiles hd.img ~

VirtualDisks.Create hd.img 160000 512 ~
VirtualDisks.Install -b=512 VDISK0 hd.img ~

StaticLinker.Link --fileName=kernel.bin --extension=Gof --displacement=100000H --path="./" 
	Trace CPU Runtime Counters APIC Processors Queues BaseTypes Activities ExclusiveBlocks HeapManager Interrupts Environment Mutexes Machine Heaps Modules GarbageCollector Objects Kernel KernelLog 
	Streams Reflection TrapWriters Traps Test ~

Partitions.WriteMBR VDISK0#0 OBEMBR.BIN ~
Partitions.Create VDISK0#1 76 80 ~
Partitions.Activate VDISK0#1 ~

Partitions.Format VDISK0#1 AosFS -1 kernel.bin ~

Partitions.SetConfig VDISK0#1
	TraceMode="5" TracePort="1" TraceBPS="115200"
	BootVol1="AOS AosFS IDE0#1"
	Boot="DisplayLinear.Install"
	AosFS="DiskVolumes.New DiskFS.NewFS"
	ExtMemSize="200"
	Init=""
	~
VirtualDisks.Uninstall VDISK0 ~

FSTools.CloseFiles hd.img ~
