PREFIX ?= $(HOME)/.local
BINARY := browsers

# Swift Testing ships with the Command Line Tools but SwiftPM does not wire up
# its search paths there, so add them when full Xcode is not the active developer dir.
DEVELOPER_DIR_PATH := $(shell xcode-select -p 2>/dev/null)
ifneq (,$(findstring CommandLineTools,$(DEVELOPER_DIR_PATH)))
CLT_FRAMEWORKS := $(DEVELOPER_DIR_PATH)/Library/Developer/Frameworks
CLT_LIBS := $(DEVELOPER_DIR_PATH)/Library/Developer/usr/lib
TEST_FLAGS := --enable-swift-testing --disable-xctest \
	-Xswiftc -F$(CLT_FRAMEWORKS) -Xlinker -F$(CLT_FRAMEWORKS) \
	-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS) -Xlinker -rpath -Xlinker $(CLT_LIBS)
endif

.PHONY: help build test run clean install uninstall release

help: ## Display available targets
	@awk 'BEGIN {FS = ":.*## "}; /^[a-zA-Z0-9_-]+:.*## / {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: test install ## Run test, install the binary, and operate the CLI
	browsers --version
	browsers --help
	browsers
	browsers --id
	browsers --markdown
	browsers --markdown --id
	browsers --json
	browsers --json --id
	browsers list-profiles
	browsers list-profiles --markdown
	browsers list-profiles --json

build: ## Build the debug binary
	swift build

test: ## Run the test suite
	swift test $(TEST_FLAGS)

run: ## Run the CLI (pass ARGS="list-profiles --canary")
	swift run $(BINARY) $(ARGS)

clean: ## Remove build artifacts and release output
	swift package clean
	rm -rf dist

install: ## Install the release binary into PREFIX/bin
	swift build -c release
	install -d "$(PREFIX)/bin"
	install -m 755 "$$(swift build -c release --show-bin-path)/$(BINARY)" "$(PREFIX)/bin/$(BINARY)"
	@echo "Installed $(PREFIX)/bin/$(BINARY)"

uninstall: ## Remove the binary from PREFIX/bin
	rm -f "$(PREFIX)/bin/$(BINARY)"

release: ## Build the universal release tarball in dist/
	./scripts/release.sh
