# Verification Gate

## Default check

```bash
./tool/verify.sh
```

The default path checks project migrations, `flutter pub get`, `flutter analyze`, the full Flutter unit/widget suite, and the existing execution contract. It does not build an APK and it does not start a device integration run.

## Targeted Flutter tests

```bash
./tool/verify.sh --test test/core/ui/adaptive_layout_test.dart
./tool/verify.sh --test test/chat/example_test.dart --test test/navigation/example_test.dart
```

Use targeted tests when the change is isolated to a feature. Keep the paths that actually exist in the repository.

## Supabase contracts

For a remote database connection:

```bash
SUPABASE_DB_URL='postgresql://...' ./tool/verify.sh --skip-flutter --require-supabase
```

The database contract suite lives in `supabase/tests/database/` and is built around pgTAP.

## Device-level verification

Only after the earlier gates pass:

```bash
./tool/verify.sh --integration
```

The repository currently does not contain an `integration_test/` directory, so the command reports that layer as skipped until real device scenarios are added.

## CI

`.github/workflows/verification.yml` runs the Flutter/project gate on pushes and pull requests. The Supabase job is enabled when the repository secret `SUPABASE_DB_URL` is configured.

The release workflow remains separate: verification does not trigger an APK/AAB build.
