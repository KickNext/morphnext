# Security policy

## Supported versions

Security fixes are made on the latest published version. Users should update
to the newest release before reporting or validating a vulnerability.

## Reporting a vulnerability

Do not open a public issue containing vulnerability details. Use GitHub's
private vulnerability reporting from the repository's Security tab. If that
option is unavailable, open an issue requesting a private contact without
disclosing sensitive details.

Include the affected version, platform, minimal reproduction, impact, and any
known workaround. Please allow the maintainers time to confirm the report and
coordinate a fix before public disclosure.

Malformed bundled fonts are handled defensively, but they are still binary
inputs. Reports involving hangs, excessive resource use, out-of-bounds parsing,
or unexpected rendering from crafted fonts are in scope.
