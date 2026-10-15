# Developer commands for numo. Run everything from the repository root.
#   just                list the recipes
#   just test           run the NumoCore logic tests
#   just run            build and launch numo
#   just self-sign      build a Release app signed with your own local certificate
#
# Signing modes for `run` and `install`:
#   adhoc (default)  ad-hoc signed: sandbox and calendar entitlements apply, no Apple account needed
#   self             signed with the local certificate from `just self-sign-setup`; macOS then
#                    remembers the calendar permission across rebuilds
#   none             not signed: runs unsandboxed, fine for a quick try

set shell := ["bash", "-uc"]

# `xcrun swift` always picks the toolchain from Xcode, even if another `swift` (for example a stale
# Homebrew shim) comes first on PATH.
swift := env("SWIFT", "xcrun swift")
core := "Numo/Packages/NumoCore"
xcodeproj := "Numo/Numo.xcodeproj"
derived := "build"
debug_app := derived / "Build/Products/Debug/numo.app"
release_app := derived / "Build/Products/Release/numo.app"
cert_name := env("NUMO_CERT_NAME", "numo Local Signing")
keychain := env("HOME") / "Library/Keychains/login.keychain-db"

# List the recipes
default:
    @{{ just_executable() }} --list --unsorted

# --- Setup -------------------------------------------------------------------------------------

# Check that the tools numo needs are installed
[group('setup')]
doctor:
    @echo "xcode-select : $(xcode-select -p 2>&1)  <- must be inside Xcode.app, not CommandLineTools"
    @echo "swift (Xcode): $({{ swift }} --version 2>&1 | head -1)"
    @echo "swift (PATH) : $(command -v swift || echo none)  <- if this is not /usr/bin/swift, use the just recipes"
    @echo "xcodebuild   : $(xcodebuild -version 2>&1 | head -1)"
    @echo "xcodegen     : $(command -v xcodegen || echo 'missing (brew install xcodegen)')"
    @echo "pnpm         : $(command -v pnpm || echo 'missing (only needed for the docs)')"
    @if security find-identity -p codesigning '{{ keychain }}' 2>/dev/null | grep '"{{ cert_name }}"' >/dev/null; then echo "signing cert : '{{ cert_name }}' present"; else echo "signing cert : none (optional: just self-sign-setup)"; fi

[private]
check-xcode:
    #!/usr/bin/env bash
    if xcode-select -p 2>/dev/null | grep -q CommandLineTools; then
        echo "error: the active developer directory is the Command Line Tools, not Xcode." >&2
        echo "  Install Xcode 26, then run:" >&2
        echo "    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
        echo "    sudo xcodebuild -license accept && sudo xcodebuild -runFirstLaunch" >&2
        echo "  (adjust the path if your Xcode app has another name; 'just doctor' shows the current state)" >&2
        exit 1
    fi

# --- Build and run -----------------------------------------------------------------------------

# Generate Numo/Numo.xcodeproj from Numo/project.yml
[group('build')]
project:
    cd Numo && xcodegen generate

# Generate the project and open it in Xcode
[group('build')]
open: project
    open '{{ xcodeproj }}'

# Compile the app without signing (checks that it builds)
[group('build')]
build: check-xcode project (_xcodebuild "Debug" "none")

# Build and launch numo (signing: adhoc, self or none)
[group('build')]
run signing='adhoc': check-xcode project (_xcodebuild "Debug" signing)
    open '{{ debug_app }}'
    @echo "numo is running in the menu bar (top right). 'just stop' quits it."

# Quit the running numo
[group('build')]
stop:
    -pkill -x numo

# Build a Release app and copy it to /Applications (signing: adhoc, self or none)
[group('build')]
install signing='adhoc': check-xcode project (_xcodebuild "Release" signing)
    -pkill -x numo
    rm -rf /Applications/numo.app
    cp -R '{{ release_app }}' /Applications/numo.app
    @echo "Installed /Applications/numo.app. Open it from Launchpad/Finder, or: open -a numo"

# Quit numo and remove it from /Applications (settings are kept; see the README)
[group('build')]
uninstall:
    -pkill -x numo
    rm -rf /Applications/numo.app

# The one place that calls xcodebuild, so every recipe signs the same way
[private]
_xcodebuild config signing:
    #!/usr/bin/env bash
    set -euo pipefail
    case '{{ signing }}' in
        none)
            flags=(CODE_SIGNING_ALLOWED=NO)
            ;;
        adhoc)
            flags=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
            ;;
        self)
            if ! security find-identity -p codesigning '{{ keychain }}' | grep '"{{ cert_name }}"' >/dev/null; then
                echo "error: no '{{ cert_name }}' certificate in the login keychain. Run: just self-sign-setup" >&2
                exit 1
            fi
            flags=("CODE_SIGN_IDENTITY={{ cert_name }}" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
            ;;
        *)
            echo "error: unknown signing mode '{{ signing }}'. Use adhoc, self or none." >&2
            exit 2
            ;;
    esac
    set -x
    xcodebuild -project '{{ xcodeproj }}' -scheme Numo -configuration '{{ config }}' \
        -destination 'platform=macOS' -derivedDataPath '{{ derived }}' "${flags[@]}" build

# --- Self-signing ------------------------------------------------------------------------------

# Create a local self-signed code-signing certificate in the login keychain (once; safe to re-run)
[group('signing')]
self-sign-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if security find-identity -p codesigning '{{ keychain }}' | grep '"{{ cert_name }}"' >/dev/null; then
        echo "'{{ cert_name }}' is already in the login keychain."
        exit 0
    fi
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    cat >"$work/openssl.cnf" <<'EOF'
    [req]
    distinguished_name = dn
    x509_extensions = ext
    prompt = no
    [dn]
    CN = {{ cert_name }}
    [ext]
    basicConstraints = critical,CA:false
    keyUsage = critical,digitalSignature
    extendedKeyUsage = critical,codeSigning
    EOF
    # Apple's LibreSSL writes a PKCS#12 file that `security import` accepts; Homebrew's OpenSSL 3 does not.
    /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$work/openssl.cnf" \
        -keyout "$work/key.pem" -out "$work/cert.pem"
    /usr/bin/openssl pkcs12 -export -inkey "$work/key.pem" -in "$work/cert.pem" \
        -name '{{ cert_name }}' -passout pass:numo -out "$work/identity.p12"
    security import "$work/identity.p12" -k '{{ keychain }}' -P numo -T /usr/bin/codesign
    echo "Trusting the certificate for code signing. macOS asks for your login password."
    security add-trusted-cert -r trustRoot -p codeSign -k '{{ keychain }}' "$work/cert.pem"
    security find-identity -v -p codesigning '{{ keychain }}' | grep '"{{ cert_name }}"' \
        || { echo "error: the certificate was created but is not valid for code signing yet." >&2; exit 1; }
    echo "Done. Use it with: just self-sign, just run self, just install self"

# Build a Release app signed with the local certificate and check the signature
[group('signing')]
self-sign: self-sign-setup check-xcode project (_xcodebuild "Release" "self") self-sign-verify
    @echo "Signed app: {{ release_app }}  (install it with: just install self)"

# Show how the Release app is signed
[group('signing')]
self-sign-verify:
    codesign --verify --deep --strict --verbose=2 '{{ release_app }}'
    @codesign -dvv '{{ release_app }}' 2>&1 | grep -E '^(Identifier|Authority|Signature|TeamIdentifier)'
    @codesign -d --entitlements - '{{ release_app }}' 2>/dev/null | grep -E 'sandbox|calendars' || true

# Delete the local signing certificate and its key from the login keychain
[confirm("Delete the '" + cert_name + "' certificate and key from the login keychain?")]
[group('signing')]
self-sign-reset:
    security delete-identity -c '{{ cert_name }}' '{{ keychain }}'

# --- Tests and docs ----------------------------------------------------------------------------

# Run the NumoCore logic tests
[group('test')]
test: check-xcode
    {{ swift }} test --package-path {{ core }}

# Install the docs dependencies
[group('docs')]
docs-install:
    pnpm install

# Serve the docs at http://localhost:5173
[group('docs')]
docs-dev:
    pnpm docs:dev

# Build the static docs site
[group('docs')]
docs-build:
    pnpm docs:build

# --- Housekeeping ------------------------------------------------------------------------------

# Remove generated files
clean:
    rm -rf {{ xcodeproj }} {{ derived }} {{ core }}/.build docs/.vitepress/dist docs/.vitepress/cache
