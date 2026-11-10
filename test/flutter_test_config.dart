import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs before every test file: each test starts with an empty fake vault, the way the
/// phone's encrypted storage behaves, so the saved login session is tested for real.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  await testMain();
}
