# Contributing

Thanks for helping. Issues and pull requests are both welcome.

## Reporting a bug

Please include:

- `flutter --version`
- the smallest test that shows the problem (a `testWidgets` with an inline
  widget is ideal)
- what you expected, and the full failure output

## Making a change

```sh
flutter pub get
dart format .
flutter analyze
flutter test
(cd example && flutter pub get && flutter analyze && flutter test)
```

CI runs the package steps on the oldest supported Flutter (3.27, with
`flutter pub get --no-example`) and on the current stable. The example needs
Flutter 3.32 (Dart 3.8) or newer for `flutter_riverpod` 3, so CI runs it on
the current stable only.

Some ground rules:

- **No runtime dependencies** beyond `flutter` and `flutter_test`. State
  libraries belong in `example/`.
- **Every public API has dartdoc**, enforced by `public_member_api_docs`.
- **Failure messages are part of the API.** If you change one, change the test
  that pins it, and keep it telling the reader *what* rebuilt.
- Keep commits small, with messages that say why.

## AI-assisted contributions

Using AI tools is fine; please just be open about it.

- Say in the PR description which AI tools you used, if any: none, some or
  most, plus the tool or agent and the model (for example "Claude Code,
  Opus 5.5" or "Copilot, GPT-5").
- Write the PR description and any issues yourself, in your own words. Short,
  plain descriptions are welcome; please don't paste generated text.
- Read, run and test every line you submit, and be ready to explain it in
  review.
- PRs without the disclosure may be closed.

## Releasing

1. Update `version` in `pubspec.yaml` and add a `CHANGELOG.md` entry.
2. `dart pub publish --dry-run` must report zero warnings.
3. Tag `vX.Y.Z` and publish.

## Stay in touch

Don't forget to follow [@saimskywalker](https://github.com/saimskywalker) on
GitHub to see new releases and other open-source projects as they come out.
