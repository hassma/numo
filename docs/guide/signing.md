# Signing the app

macOS only runs code that is signed, and it identifies an app's permissions (such as Calendar access) by its signature. How you sign numo therefore decides whether macOS remembers the calendar permission across rebuilds.

## Which mode should I use?

| Mode | Command | Needs | Calendar permission after a rebuild | Use it for |
| --- | --- | --- | --- | --- |
| **Ad hoc** (default) | `just install`, `just run` | nothing | May be asked for again, because an ad-hoc signature changes with every build | Trying numo out |
| **Self-signed** | `just install self`, `just run self` | a one-time `just self-sign-setup` | Kept: the signing identity stays the same | Daily use on your own Mac |
| **Unsigned** | `just run none` | nothing | Not applicable: the app runs unsandboxed | A quick look; not for daily use |
| **Your Apple team** | `just open`, then ⌘R in Xcode | a (free) Apple ID in Xcode | Kept | Debugging with breakpoints |
| **Developer ID** | not set up yet | a paid Developer Program membership | Kept | Distributing to other Macs |

The ad-hoc and self-signed apps are both sandboxed and carry the calendar entitlement, so they behave the same apart from how macOS remembers them.

## Self-signing

A self-signed certificate gives numo a stable identity, so macOS keeps the calendar permission when you rebuild. It is free, needs no Apple account and works only on your own Mac.

```sh
just self-sign-setup     # once: creates "numo Local Signing" in your login keychain
just self-sign           # builds a Release app signed with it and checks the signature
just install self        # installs the app signed that way (use `just run self` for a Debug build)
```

`self-sign-setup` is safe to run again: it does nothing if the certificate already exists. It performs these steps, using only the tools macOS ships:

1. Creates a 10-year certificate for code signing with Apple's `/usr/bin/openssl`.
2. Imports the certificate and its private key into your **login keychain**, allowing `/usr/bin/codesign` to use the key.
3. Marks the certificate as trusted for code signing, with `security add-trusted-cert`.

### What to expect

- **A password prompt.** macOS asks for your login password once to change the trust settings.
- **A keychain prompt.** The first signing may ask whether `codesign` may use the key. Choose **Always Allow**.
- **One more calendar prompt.** The first time you switch from ad-hoc to self-signed, macOS sees a different app. Grant calendar access to numo once more; after that it sticks.

### Check the result

```sh
just self-sign-verify
```

It verifies the signature of the Release app and prints its authority, identifier and entitlements. You should see `Authority=numo Local Signing` and the `app-sandbox` and `personal-information.calendars` entitlements.

`just doctor` also reports whether the certificate is present.

### Use another certificate name

Set `NUMO_CERT_NAME` before running any of the commands:

```sh
export NUMO_CERT_NAME="My Local Signing"
just self-sign-setup && just install self
```

### Remove the certificate

```sh
just self-sign-reset
```

After confirming, this deletes the certificate and its private key from the login keychain.

### Limits

- A self-signed app is **not notarized**. Gatekeeper still blocks it on another Mac. Sharing numo needs a Developer ID certificate and notarization ([decision 3](/decisions)).
- Rebuilding with a different mode (ad hoc after self-signed) makes macOS treat the app as new again.
- If `self-sign-setup` fails at the trust step, open **Keychain Access**, find *numo Local Signing* in the login keychain, and set *Trust → Code Signing* to *Always Trust*.
