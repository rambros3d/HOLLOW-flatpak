/// Rust FFI mock utilities for widget tests.
///
/// We mock at the Riverpod provider level (see test_app.dart), NOT at the
/// FFI level. This avoids needing to construct RustLibApiImplPlatform or
/// load native libraries. The providers that call FFI are all overridden
/// with mock notifiers that return static test data.
///
/// If a future test needs actual FFI mock mode, use:
///   `RustLib.initMock(api: concreteRustLibApiImpl)`
/// But for widget tests, provider-level mocking is simpler and faster.
library;
