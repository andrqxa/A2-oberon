# Define variables
PLATFORMS = Bios32 Bios64 Zynq Win32 Win64 Linux32 Linux64 LinuxARM Darwin32 Darwin64 Solaris32 Solaris64 \
	Bios32C RPiC ZynqC Win32C Linux32C Linux64C
CURRENT_DIR := $(shell pwd)
CONFIGS := $(CURRENT_DIR)/configs
DATA := $(CURRENT_DIR)/data
SRC := $(CURRENT_DIR)/source

# Define default value for COMPILER
COMPILER := $(CURRENT_DIR)/compiler/oberon
ifeq ($(OS),Windows_NT)
    COMPILER := $(CURRENT_DIR)/compiler/oberon.exe
endif

BUILD_DIR := $(CURRENT_DIR)/target

all: oberon
commit: Self-Compilation Compilation-Tests Execution-Tests builds

.PHONY: all commit Self-Compilation Compilation-Tests Execution-Tests builds build clean
MAKEFLAGS += --no-builtin-rules --no-builtin-variables
.SUFFIXES: # delete the default suffixes

TARGET = Linux64
PLTFRM = Unix64
OBJECT = .GofUu
SYMBOL = .SymUu

# module dependencies

modules: $(SRC)/Release.Tool
	@AOSPATH=$(SRC) $(COMPILER) Release.Build --list $(SRC) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' ' > $@

dependencies: modules $(SRC)/*.Mod
	@$(COMPILER) DependencyWalker.Walk --define=UNIX,AMD64 --fileExtension=$(OBJECT) $(addprefix $(SRC)/, $(shell sort -u modules)) DependencyWalker.Mod | tr -d '\r' | grep "^.\+\$(OBJECT):" > $@

-include dependencies
FoxArrayBase$(OBJECT): ComplexNumbers$(OBJECT)

%$(OBJECT):
	@$(COMPILER) Compiler.Compile -p=$(PLTFRM) --OBJECTFileExtension=$(OBJECT) --SYMBOLFileExtension=$(SYMBOL) $(if $<, $<, $(error no TARGET for $@))

# Fox Compiler

oberon: $(addsuffix $(OBJECT), Builtins Trace Glue Unix Machine Heaps Modules Objects RealConversions Streams Kernel Reflection KernelLog TrapWriters Commands Pipes StdIO Traps Files UnixFiles BitSets StringPool Diagnostics Reals Clock Strings Dates ObjectFile GenericLinker Loader WMRectangles CLUTs Plugins Displays Raster UTF8Strings WMRasterScale SoundDevices XMLObjects DynamicStrings XML XMLScanner XMLParser Configuration Inflate CRC Unzip WMEvents Locks FP1616 Texts Archives Codecs WMGraphics WMDefaultFont Options StdIOShell Shell ProcessInfo0 ProcessInfo SystemVersion System Debugging FoxBasic FoxScanner FoxSyntaxTree FoxGlobal FoxParser FoxFingerprinter FoxPrintout FoxFormats FoxSemanticChecker FoxSections FoxBinaryCode FoxBackend FoxFrontend Compiler FoxOberonFrontend FoxIntermediateCode FoxInterfaceComparison FoxTextualSymbolFile FoxIntermediateBackend FoxAMD64InstructionSet FoxAMD64Assembler FoxGenericObjectFile FoxCodeGenerators FoxAMDBackend FoxDisassembler FoxARMInstructionSet FoxAssembler FoxARMAssembler FoxARMBackend FoxTestBackend MathL Math ComplexNumbers FoxArrayBase FoxArrayBaseOptimized Localization Repositories UnicodeProperties TextUtilities TestSuite Versioning CompilerInterface FoxTest Linker DependencyWalker ReleaseThreadPool Zlib ZlibBuffers ZlibInflate ZlibReaders ZlibDeflate ZlibWriters Zip Release)
	@$(COMPILER) Linker.Link -p=$(TARGET) --extension=$(OBJECT) --fileName=$@ $+ && chmod +x $@
# grep ":processing\s$" oberon.log | grep "^[^:]\+" -o | tr '\n' ' '


# Self-Compilation: $(addsuffix $(OBJECT), Compiler CompilerInterface FoxA2Interface FoxActiveCells FoxAMD64Assembler FoxAMD64InstructionSet FoxAMDBackend FoxARMAssembler FoxARMBackend FoxARMInstructionSet FoxArrayBase FoxArrayBaseOptimized FoxAssembler FoxBackend FoxBasic FoxBinaryCode FoxCodeGenerators FoxCSharpFrontend FoxCSharpParser FoxCSharpScanner FoxDisassembler FoxDocumentationBackend FoxDocumentationHtml FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationScanner FoxDocumentationTree FoxFingerprinter FoxFormats FoxFrontend FoxGenericObjectFile FoxGlobal FoxHardware FoxInterfaceComparison FoxIntermediateAssembler FoxIntermediateBackend FoxIntermediateCode FoxIntermediateLinker FoxIntermediateObjectFile FoxIntermediateParser FoxInterpreter FoxInterpreterBackend FoxInterpreterSymbols FoxMinosObjectFile FoxOberonFrontend FoxParser FoxPrintout FoxProfiler FoxProgTools FoxScanner FoxSections FoxSemanticChecker FoxSyntaxTree FoxTest FoxTestBackend FoxTextualSymbolFile FoxTranspilerBackend FoxTRMAssembler FoxTRMBackend FoxTRMInstructionSet TextCompiler)
# grep "^\(Fox\|Compiler\|TextCompiler\)" modules | sed 's/\.Mod//g' | sort | tr '\n' ' '


Self-Compilation: $(addsuffix $(OBJECT), Compiler CompilerInterface FoxA2Interface FoxAMD64Assembler FoxAMD64InstructionSet FoxAMDBackend FoxARMAssembler FoxARMBackend FoxARMInstructionSet FoxActiveCells FoxArrayBase FoxAssembler FoxBackend FoxBasic FoxBinaryCode FoxCSharpFrontend FoxCSharpParser FoxCSharpScanner FoxCodeGenerators FoxDisassembler FoxDocumentationBackend FoxDocumentationHtml FoxDocumentationParser FoxDocumentationPrinter FoxDocumentationScanner FoxDocumentationTree FoxFingerprinter FoxFormats FoxFrontend FoxGenericObjectFile FoxGlobal FoxHardware FoxInterfaceComparison FoxIntermediateAssembler FoxIntermediateBackend FoxIntermediateCode FoxIntermediateLinker FoxIntermediateObjectFile FoxIntermediateParser FoxInterpreter FoxInterpreterBackend FoxInterpreterSymbols FoxMinosObjectFile FoxMinosObjectFile_mine FoxMinosObjectFile_r1906 FoxMinosObjectFile_r8718 FoxOberonFrontend FoxParser FoxPrintout FoxProfiler FoxProgTools FoxScanner FoxSections FoxSemanticChecker FoxSyntaxTree FoxTRMAssembler FoxTRMBackend FoxTRMInstructionSet FoxTRMTools FoxTest FoxTestBackend FoxTextualSymbolFile FoxTranspilerBackend TextCompiler)
# find source -type f -name "*.Mod" | grep "^\(source\/Fox\|source\/Compiler\|source\/TextCompiler\)" | sed 's/\.Mod//g' | sed 's/source\///g' | sort | tr '\n' ' '

Compilation-Tests: Oberon.Compilation.Test.Diff

Oberon.Compilation.Test.Diff: oberon $(SRC)/Oberon.Compilation.Test
	@$(COMPILER) FoxTest.Compile $(SRC)/Oberon.Compilation.Test

Execution-Tests: Oberon.Execution.Test.Diff

Oberon.Execution.Test.Diff: oberon $(SRC)/Oberon.Execution.Test
	@$(COMPILER) FoxTest.Compile --prolog=\"Compiler.Compile --SYMBOLFileExtension=$(SYMBOL) TesterInput.txt\" $(SRC)/Oberon.Execution.Test

# A2 Builds

builds:
	@make $(foreach platform,$(PLATFORMS),&& make build platform=$(platform))

ifdef platform

build: $(if $(filter $(PLATFORMS), $(platform)), $(platform), $(error invalid platform))

$(platform): oberon $(SRC)/Release.Tool $(addprefix $(SRC)/, $(shell AOSPATH=$(SRC) $(COMPILER) Release.Build --list $(platform) | tr -d '\r' | grep "^[^ ]\+\.Mod\s" | tr -d ' '))
	@rm -rf $@ && mkdir $@
	@AOSPATH=$(SRC) ./oberon Release.Build --path=$@/ --build $(platform) || (rm -rf $@ && false)

else

build:
	$(error undefined platform)

endif

# utilities

original: oberon
	@cp oberon $@

clean:
	@rm -f modules dependencies oberon *$(SYMBOL) *$(OBJECT) *.Log *.log
	@rm -rf $(PLATFORMS)
