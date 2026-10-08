import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pet_health_tracker/core/app_version.dart';

void main() {
  test('is the version and build number', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Pet Health Tracker',
      packageName: 'com.pootzandboogie.pet_health_tracker',
      version: '0.0.1',
      buildNumber: '31',
      buildSignature: '',
    );
    final container = ProviderContainer.test();

    expect(await container.read(appVersionProvider.future), '0.0.1 (31)');
  });
}
