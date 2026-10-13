# Developer commands. Run everything from the repository root.
#   make            list targets
#   make test       run the NumoCore logic tests
#   make open       generate the Xcode project and open it

# `xcrun swift` always picks the toolchain from Xcode, even if another `swift` (e.g. a stale
# Homebrew shim) comes first on PATH.
SWIFT   ?= xcrun swift
CORE    := Numo/Packages/NumoCore
PROJECT := Numo/Numo.xcodeproj

.DEFAULT_GOAL := help
.PHONY: help doctor project open build test docs-install docs-dev docs-build clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-13s %s\n", $$1, $$2}'

doctor: ## Check that the tools numo needs are installed
	@echo "xcode-select : $$(xcode-select -p 2>&1)"
	@echo "swift (Xcode): $$($(SWIFT) --version 2>&1 | head -1)"
	@echo "swift (PATH) : $$(command -v swift || echo none)  <- if this is not /usr/bin/swift, prefer 'make' targets"
	@echo "xcodebuild   : $$(xcodebuild -version 2>&1 | head -1)"
	@echo "xcodegen     : $$(command -v xcodegen || echo 'missing (brew install xcodegen)')"
	@echo "pnpm         : $$(command -v pnpm || echo 'missing (only needed for the docs)')"

project: ## Generate Numo/Numo.xcodeproj from Numo/project.yml
	cd Numo && xcodegen generate

open: project ## Generate the project and open it in Xcode
	open $(PROJECT)

build: project ## Compile the app without signing (checks that it builds)
	xcodebuild -project $(PROJECT) -scheme Numo -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

test: ## Run the NumoCore logic tests
	$(SWIFT) test --package-path $(CORE)

docs-install: ## Install the docs dependencies
	pnpm install

docs-dev: ## Serve the docs at http://localhost:5173
	pnpm docs:dev

docs-build: ## Build the static docs site
	pnpm docs:build

clean: ## Remove generated files
	rm -rf $(PROJECT) $(CORE)/.build docs/.vitepress/dist docs/.vitepress/cache
