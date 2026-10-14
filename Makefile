# Developer commands. Run everything from the repository root.
#   make            list targets
#   make test       run the NumoCore logic tests
#   make open       generate the Xcode project and open it

# `xcrun swift` always picks the toolchain from Xcode, even if another `swift` (e.g. a stale
# Homebrew shim) comes first on PATH.
SWIFT   ?= xcrun swift
CORE    := Numo/Packages/NumoCore
PROJECT := Numo/Numo.xcodeproj
DERIVED := build
APP     := $(DERIVED)/Build/Products/Debug/numo.app

# make run                 ad-hoc signed: sandbox + calendar entitlements applied, no Apple account needed
# make run SIGNING=none    skip signing: runs unsandboxed (fine for a quick try, not the shipped setup)
ifeq ($(SIGNING),none)
SIGN_FLAGS := CODE_SIGNING_ALLOWED=NO
else
SIGN_FLAGS := CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
endif

.DEFAULT_GOAL := help
.PHONY: help doctor check-xcode project open build run stop install uninstall test docs-install docs-dev docs-build clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

doctor: ## Check that the tools numo needs are installed
	@echo "xcode-select : $$(xcode-select -p 2>&1)  <- must be inside Xcode.app, not CommandLineTools"
	@echo "swift (Xcode): $$($(SWIFT) --version 2>&1 | head -1)"
	@echo "swift (PATH) : $$(command -v swift || echo none)  <- if this is not /usr/bin/swift, prefer 'make' targets"
	@echo "xcodebuild   : $$(xcodebuild -version 2>&1 | head -1)"
	@echo "xcodegen     : $$(command -v xcodegen || echo 'missing (brew install xcodegen)')"
	@echo "pnpm         : $$(command -v pnpm || echo 'missing (only needed for the docs)')"

check-xcode:
	@if xcode-select -p 2>/dev/null | grep -q CommandLineTools; then \
		echo "error: the active developer directory is the Command Line Tools, not Xcode."; \
		echo "  Install Xcode 26, then run:"; \
		echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"; \
		echo "    sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch"; \
		echo "  (adjust the path if your Xcode app has another name; 'make doctor' shows the current state)"; \
		exit 1; \
	fi

project: ## Generate Numo/Numo.xcodeproj from Numo/project.yml
	cd Numo && xcodegen generate

open: project ## Generate the project and open it in Xcode
	open $(PROJECT)

build: check-xcode project ## Compile the app without signing (checks that it builds)
	xcodebuild -project $(PROJECT) -scheme Numo -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

run: check-xcode project ## Build and launch numo (ad-hoc signed; SIGNING=none skips signing)
	xcodebuild -project $(PROJECT) -scheme Numo -configuration Debug -destination 'platform=macOS' -derivedDataPath $(DERIVED) $(SIGN_FLAGS) build
	open $(APP)
	@echo "numo is running in the menu bar (top right). 'make stop' quits it."

stop: ## Quit the running numo
	-pkill -x numo

install: check-xcode project ## Build a Release app and copy it to /Applications (ad-hoc signed)
	xcodebuild -project $(PROJECT) -scheme Numo -configuration Release -destination 'platform=macOS' -derivedDataPath $(DERIVED) $(SIGN_FLAGS) build
	-pkill -x numo
	rm -rf /Applications/numo.app
	cp -R $(DERIVED)/Build/Products/Release/numo.app /Applications/numo.app
	@echo "Installed /Applications/numo.app. Open it from Launchpad/Finder, or: open -a numo"

uninstall: ## Quit numo and remove it from /Applications (settings are kept; see README)
	-pkill -x numo
	rm -rf /Applications/numo.app

test: check-xcode ## Run the NumoCore logic tests
	$(SWIFT) test --package-path $(CORE)

docs-install: ## Install the docs dependencies
	pnpm install

docs-dev: ## Serve the docs at http://localhost:5173
	pnpm docs:dev

docs-build: ## Build the static docs site
	pnpm docs:build

clean: ## Remove generated files
	rm -rf $(PROJECT) $(DERIVED) $(CORE)/.build docs/.vitepress/dist docs/.vitepress/cache
