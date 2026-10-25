# Security policy

## Supported versions

Fixes land on the latest minor release only.

| Version | Supported |
|---|---|
| 0.1.x | Yes |
| Older | No |

`imaji_rebuild_budget` runs inside `flutter test` and has no runtime
dependencies beyond `flutter` and `flutter_test`, so its attack surface is
small. If you find a problem anyway, please report it as described below.

## Reporting a vulnerability

Please report privately: open this repository's **Security** tab and choose
**Report a vulnerability**. This creates a private advisory that only you and
the maintainer can see.

Do **not** open a public issue, pull request or discussion for a
vulnerability.

Useful things to include:

- the package version and `flutter --version`
- what the problem is and what an attacker could achieve with it
- a minimal reproduction, such as a `testWidgets` that shows it
- any fix you have in mind

## What to expect

You will usually get a first reply within a week. Once the issue is
confirmed, a fix is prepared in the private advisory, released, and the
advisory is published with credit to you unless you prefer otherwise.
