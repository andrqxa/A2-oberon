## initial remarks / caveats
	TextUtilities imports WMGraphics, 
	WMGraphics can block when WMDefaultFont is not loaded. Make sure to link WMDefaultFont into images requiring WMGraphics that should work without module loading
	Modules that must be loaded during startup must be linked before IOShell / Bootconsole, respectively

WIN32 -- 32-bit windows a2
=================================

	## Compile all files ##
		Release.Build  --path=NewAos/ Win32~
	
	## Link A2.exe (bootconsole for graphical OS) ##
		StaticLinker.Link --path=NewAos/ --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~		

	## command line shell 
	StaticLinker.Link  --path=NewAos/ --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
		Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings 
		Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace StdIO  
		Traps RelativeFileSystem WMDefaultFont SystemTools StdIOShell ~

	## Command line shell including compiler (and linker) ##
		StaticLinker.Link --path=NewAos/  --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H 
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files  WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker Reflection GenericLoader WinTrace 
			StdIO  Traps RelativeFileSystem SystemTools FSTools StdIOShell Shell StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~

FSTools.CloseFiles oberon.exe ~

Compiler.Compile -p=Win32
Runtime.Mod Trace.Mod Generic.Win32.Kernel32.Mod Win32.Machine.Mod Heaps.Mod 
Generic.Modules.Mod Win32.Objects.Mod Win32.Kernel.Mod KernelLog.Mod Plugins.Mod Streams.Mod Pipes.Mod 
Commands.Mod In.Mod Out.Mod I386.Reals.Mod Generic.Reflection.Mod TrapWriters.Mod CRC.Mod 
SystemVersion.Mod Win32.Traps.Mod Win32.WinTrace.Mod Win32.StdIO.Mod Locks.Mod Win32.Clock.Mod 
Disks.Mod Files.Mod Dates.Mod Strings.Mod UTF8Strings.Mod FileTrapWriter.Mod Caches.Mod 
DiskVolumes.Mod OldDiskVolumes.Mod RAMVolumes.Mod DiskFS.Mod OldDiskFS.Mod OberonFS.Mod 
FATVolumes.Mod FATFiles.Mod ISO9660Volumes.Mod ISO9660Files.Mod Win32.User32.Mod Win32.WinTrace.Mod 
Win32.ODBC.Mod Win32.Shell32.Mod Win32.SQL.Mod Win32.WinFS.Mod RelativeFileSystem.Mod BitSets.Mod 
Diagnostics.Mod StringPool.Mod ObjectFile.Mod GenericLinker.Mod GenericLoader.Mod BootConsole.Mod 
Shell.Mod StdIOShell.Mod ~

SystemTools.FreeDownTo FoxIntermediateBackend ~

LINUX32 -- 32 bit linux a2
================================

	Release.Build --path=NewAos/ Linux32 ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Linux32 --path=NewAos/ 
		Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel 
		KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates 
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		StaticLinker.Link -p=Linux32 --path=NewAos/
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell ~  StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


LINUX64 -- 64 bit linux a2
================================

	Release.Build --path=NewAos/ Linux64 ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Linux64 --path=NewAos/ 
		Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel 
		KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection Traps Files UnixFiles Clock Dates 
		Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
	
	## Command line shell including compiler (and linker) ##
		StaticLinker.Link -p=Linux64 --path=NewAos/
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell ~ StaticLinker Compiler FoxOberonFrontend FoxARMBackend FoxAMDBackend ~


DARWIN32 -- 32 bit darwin a2
================================

	Release.Build -b Darwin32 ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Darwin32  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


SOLARIS32 -- 32 bit solaris a2
================================

	Release.Build -b Solaris32 ~
	
	## X11 bootconsole ##
		StaticLinker.Link -p=Solaris32  --path=./NewAos/
				Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO TrapWriters Reflection 
				Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  BootConsole ~
		UnixBinary.Build  oberon.bin  ->  A2Core ~


WIN64 -- 64-bit windows a2
================
	
	Release.Build --path=NewAos/ Win64 ~

	StaticLinker.Link  --fileFormat=PE64CUI --fileName=oberon.exe --extension=GofWw --displacement=401000H  
		Runtime Trace Kernel32 
		Heaps Modules Objects Kernel
		KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets 
		StringPool ObjectFile GenericLinker Reflection  GenericLoader Shell  StdIOShell Traps SystemTools ~

	FSTools.CloseFiles oberon.exe  ~
	~
	
	
-----

	SystemTools.DoCommands	
		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Linux64 ~
		StaticLinker.Link -p=Linux64 --path=NewAos/
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell ~ 
		FSTools.CopyFiles -oq NewAos/*.* => ../../Linux64/bin/*.* ~ 
		FSTools.CopyFiles -o oberon => ../../Linux64/oberon ~ 

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Linux32 ~
		StaticLinker.Link -p=Linux32 --path=NewAos/
			Runtime Trace Glue Unix Machine Heaps Modules Objects Kernel KernelLog  Streams Commands Pipes StdIO 
			TrapWriters Reflection Traps Files UnixFiles Clock Dates Reals Strings Diagnostics BitSets StringPool ObjectFile GenericLinker   GenericLoader  SystemTools StdIOShell 
			Shell ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Linux32/bin/*.* ~ 
		FSTools.CopyFiles -o oberon => ../../Linux32/oberon ~ 

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Win32 ~
		StaticLinker.Link --path=NewAos/ --fileFormat=PE32 --fileName=A2.exe --extension=GofW --displacement=401000H  
			Runtime Trace Kernel32 Machine Heaps Modules Objects Kernel KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets StringPool 
			ObjectFile GenericLinker Reflection  GenericLoader  BootConsole ~		
		FSTools.CopyFiles -oq NewAos/*.* => ../../WinAos/obg/*.* ~ 
		FSTools.CopyFiles -o A2.exe => ../../WinAos/A2.exe ~ 

		FSTools.DeleteFiles -s NewAos/* ~
		Release.Build --build --path=NewAos/ Win64 ~
		StaticLinker.Link --path=NewAos/  --fileFormat=PE64CUI --fileName=oberon.exe --extension=GofWw --displacement=401000H  
			Runtime Trace Kernel32 
			Heaps Modules Objects Kernel
			KernelLog Streams Commands Files WinFS Clock Dates Reals Strings Diagnostics BitSets 
			StringPool ObjectFile GenericLinker Reflection  GenericLoader Shell  StdIOShell Traps SystemTools ~
		FSTools.CopyFiles -oq NewAos/*.* => ../../Win64/bin/*.* ~ 
		FSTools.CopyFiles -o oberon.exe => ../../Win64/oberon.exe ~ 

		FSTools.DeleteFiles -s NewAos/* ~
		~ 
