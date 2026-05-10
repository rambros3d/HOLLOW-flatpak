import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerRustLicenses() {
  LicenseRegistry.addLicense(() async* {
    final data = await rootBundle.loadString('assets/rust_licenses.txt');
    final entries = data.split('====LICENSE_START====');

    for (final entry in entries) {
      if (!entry.contains('---TEXT---')) continue;

      final headerAndText = entry.split('---TEXT---');
      if (headerAndText.length < 2) continue;

      final header = headerAndText[0];
      final text = headerAndText[1]
          .replaceFirst('====LICENSE_END====', '')
          .trim();

      if (text.isEmpty) continue;

      final packages = <String>[];
      for (final line in header.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !trimmed.startsWith('License:') &&
            !trimmed.startsWith('Used by:')) {
          packages.add(trimmed);
        }
      }

      if (packages.isEmpty) continue;

      yield LicenseEntryWithLineBreaks(packages, text);
    }
  });
}
