## What changed

<!-- Describe your changes in 1-3 sentences. -->

## Why

<!-- What problem does this solve? Link to an issue if one exists (e.g., Fixes #123). -->

## How it was tested

<!-- How did you verify this works? (e.g., ran cargo test, tested manually on Windows, etc.) -->

## Checklist

- [ ] `cargo test --lib` passes (if Rust was changed)
- [ ] `cargo clippy` has no new warnings (if Rust was changed)
- [ ] `flutter analyze` passes (if Dart was changed)
- [ ] FFI bindings regenerated (if `rust/hollow_core/src/api/` was changed)
- [ ] New persisted struct fields have `#[serde(default)]`
