# Define variables
# TARGETS := Linux64 Linux32 LinuxARM Win32 Win64
TARGETS := Linux64 #Linux32 LinuxARM Win32 Win64
CURRENT_DIR := $(shell pwd)
CONFIGS := $(CURRENT_DIR)/configs
DATA := $(CURRENT_DIR)/data
# RES := $(CURRENT_DIR)/resources
SRC := $(CURRENT_DIR)/source

# Define default value for binary files
BIN := $(CURRENT_DIR)/compilers/Linux64/bin
# Override path to binary files if the OS is Windows
ifeq ($(OS),Windows_NT)
    BIN := $(CURRENT_DIR)/compilers/Win64/bin
endif

# Define default value for COMPILER
COMPILER := $(CURRENT_DIR)/compilers/Linux64/oberon
# Override COMPILER if the OS is Windows
ifeq ($(OS),Windows_NT)
    COMPILER := $(CURRENT_DIR)/compilers/Win64/oberon
endif

BUILD_DIR := $(CURRENT_DIR)/target

# Main rule to build all targets
.PHONY: all
all: clean dirs $(TARGETS)

# Rule to build each architecture separately
.PHONY: $(TARGETS)
$(TARGETS): %: dirs
	@echo "Building $@"
	@mkdir -p $(BUILD_DIR)/$@

	# Dynamic generate file content for each type of OS
	@echo "Release.Build --build --path=bin/ $@ ~" > $(BUILD_DIR)/$@/dynamic.txt
	@if [ "$@" = "Linux64" ] || [ "$@" = "Linux32" ] || [ "$@" = "LinuxARM" ]; then \
		echo "Linker.Link -p=$@ --path=bin/" >> $(BUILD_DIR)/$@/dynamic.txt; \
		cat $(BUILD_DIR)/$@/dynamic.txt $(CONFIGS)/moduleListLinux.txt > $(BUILD_DIR)/$@/combined.txt; \
	elif [ "$@" = "Win32" ]; then \
		echo "Linker.Link --path=bin/ --fileFormat=PE32CUI --fileName=oberon.exe --extension=GofW --displacement=401000H" >> $(BUILD_DIR)/$@/dynamic.txt; \
		cat $(BUILD_DIR)/$@/dynamic.txt $(CONFIGS)/moduleListWin.txt > $(BUILD_DIR)/$@/combined.txt; \
	elif [ "$@" = "Win64" ]; then \
		echo "Linker.Link --path=bin/ --fileFormat=PE64CUI --fileName=oberon.exe --extension=GofWw --displacement=401000H" >> $(BUILD_DIR)/$@/dynamic.txt; \
		cat $(BUILD_DIR)/$@/dynamic.txt $(CONFIGS)/moduleListWin.txt > $(BUILD_DIR)/$@/combined.txt; \
	fi

	# Create necessary files: a2.sh, a2.txt, oberon.ini for each target
	@if [ "$@" = "Linux64" ] || [ "$@" = "Linux32" ] || [ "$@" = "LinuxARM" ]; then \
		echo './oberon run a2.txt' > $(BUILD_DIR)/$@/a2.sh; \
		chmod +x $(BUILD_DIR)/$@/a2.sh; \
		cat $(CONFIGS)/a2General.txt $(CONFIGS)/a2LinuxSpecific.txt > $(BUILD_DIR)/$@/a2.txt; \
		cat $(CONFIGS)/oberonGeneral.ini $(CONFIGS)/oberonResources.ini $(CONFIGS)/oberonGeneralLast.ini > $(BUILD_DIR)/$@/oberon.ini; \
	elif [ "$@" = "Win32" ] || [ "$@" = "Win64" ]; then \
		echo 'oberon run a2.txt' > $(BUILD_DIR)/$@/a2.bat; \
		cp $(CONFIGS)/a2General.txt $(BUILD_DIR)/$@/a2.txt; \
		cat $(CONFIGS)/oberonGeneral.ini $(CONFIGS)/oberonResources.ini $(CONFIGS)/oberonGeneralLast.ini $(CONFIGS)/oberonWindowsSpecific.ini > $(BUILD_DIR)/$@/oberon.ini; \
	fi

	@mkdir -p $(BUILD_DIR)/$@/work
	@mkdir -p $(BUILD_DIR)/$@/bin

	# Create oberon.ini for compilation
	@echo Heaps.SetMetaData~ > $(BUILD_DIR)/$@/oberonCompile.ini
	@echo Files.AddSearchPath $(BIN)~ >> $(BUILD_DIR)/$@/oberonCompile.ini
	@cat $(CONFIGS)/oberonResources.ini >> $(BUILD_DIR)/$@/oberonCompile.ini
	@echo Configuration.Init~ >> $(BUILD_DIR)/$@/oberonCompile.ini

	# Compile new architecture
	@cd $(BUILD_DIR)/$@; \
	$(COMPILER) do " \
		System.DoFile oberonCompile.ini ~ \
		Files.SetWorkPath $(BUILD_DIR)/$@ ~ \
		System.DoFile $(BUILD_DIR)/$@/combined.txt ~ \
	"
	@result=$$?; \
	if [ $$result -eq 0 ]; then \
		rm -f $(BUILD_DIR)/$@/bin/CompileCommand.Tool; \
		rm -f $(BUILD_DIR)/$@/oberon.log; \
		rm -f oberon.ini; \
		chmod +x $(BUILD_DIR)/$@/oberon*; \
	else \
		rm -rf $(BUILD_DIR)/$@; \
		echo "Build not successful!!!"; \
		exit 1; \
	fi
	
# Removed generated files
	@rm -f $(BUILD_DIR)/$@/dynamic.txt
	# @rm -f $(BUILD_DIR)/$@/combined.txt
	# @rm -f $(BUILD_DIR)/$@/oberonCompile.ini

# Remove all generated files
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@rm -rf $(BUILD_DIR)
	@echo "Directory $(BUILD_DIR) has been removed"

# Create necessary directories
.PHONY: dirs
dirs:
	@if [ ! -d $(BUILD_DIR) ]; then \
		mkdir -p $(BUILD_DIR); \
		echo "Directory created: $(BUILD_DIR)"; \
	else \
		echo "Directory already exists: $(BUILD_DIR)"; \
	fi

# Test rule
.PHONY: test
test:
	@echo "Tests have started:"
	@cd $(BUILD_DIR)/Linux64; \
	./oberon do " \
		System.DoFile oberon.ini ~ \
		FoxTest.Compile --verbose -l=TestCompilation.Log Oberon.Compilation.Test Oberon.Compilation.AMD64TestDiff ~ \
		FoxTest.Compile --verbose -l=TestExecution.Log Oberon.Execution.Test Oberon.Execution.AMD64TestDiff ~ \
	"
	@rm -f $(BUILD_DIR)/Linux64/work/*.SymUu
	@rm -f $(BUILD_DIR)/Linux64/work/*.GofUu
	@rm -f $(BUILD_DIR)/Linux64/work/*.txt
	@echo "All Tests have finished"