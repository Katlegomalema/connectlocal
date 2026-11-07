// Real uploads with the app's own code against a RUNNING backend + Supabase Storage. Skipped unless
// E2E_EMAIL is given (a confirmed account with role "provider" and no business yet):
//   flutter test test/e2e/provider_upload_e2e_test.dart --dart-define=API_BASE_URL=http://localhost:3000 \
//     --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=... --dart-define=E2E_REG=2019/123456/07
import 'dart:typed_data';

import 'package:connect_local/core/api_client.dart';
import 'package:connect_local/core/connect_local_repository.dart';
import 'package:connect_local/features/auth/api_auth_service.dart';
import 'package:connect_local/features/community/models/models.dart';
import 'package:connect_local/features/shared/photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const email = String.fromEnvironment('E2E_EMAIL');
const password = String.fromEnvironment('E2E_PASSWORD');
const reg = String.fromEnvironment('E2E_REG', defaultValue: '2019/123456/07');

Uint8List jpeg(int size) => Uint8List(size)..setAll(0, [0xFF, 0xD8, 0xFF, 0xE0]);
Uint8List pdf(int size) => Uint8List(size)..setAll(0, '%PDF-1.4\n'.codeUnits);

void main() {
  if (email.isEmpty) {
    test('provider upload e2e (skipped: pass E2E_EMAIL / E2E_PASSWORD)', () {}, skip: true);
    return;
  }
  late ConnectLocalRepository repo;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient();
    await ApiAuthService(api).login(email: email, password: password);
    repo = ConnectLocalRepository(api);
  });

  test('a file that is too big is refused with a clear message (before uploading)', () async {
    await expectLater(
        repo.upload(PhotoRef(bytes: pdf(11 * 1024 * 1024), name: 'big.pdf'), document: true),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('too big'))));
    await expectLater(
        repo.upload(PhotoRef(bytes: jpeg(6 * 1024 * 1024), name: 'big.jpg'), document: false),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('too big'))));
  });

  test('a file type that is not allowed is refused with a clear message', () async {
    await expectLater(
        repo.upload(PhotoRef(bytes: pdf(1000), name: 'cv.pdf'), document: false), // PDF as a photo
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('File type not allowed'))));
  });

  test('application with a photo ID (JPEG), a PDF certificate and a portfolio photo is submitted', () async {
    final steps = <String>[];
    final result = await repo.submitApplication(
      businessName: "Pat's Plumbing (Pty) Ltd",
      category: 'Plumbing',
      description: 'Leaks, geysers and drains in Pretoria east.',
      address: '12 Church Street, Pretoria',
      registrationNumber: reg,
      latitude: -25.7461,
      longitude: 28.1881,
      registrationDoc: PhotoRef(bytes: pdf(200 * 1024), name: 'certificate.pdf'),
      idDoc: PhotoRef(bytes: jpeg(300 * 1024), name: 'id.jpg'),
      photos: [PhotoRef(bytes: jpeg(150 * 1024), name: 'van.jpg')],
      onProgress: (step, done, total) => steps.add('$done/$total $step'),
    );
    expect(result.status, 'submitted');
    expect(steps.last, startsWith('5/5'));
    // ignore: avoid_print
    print('progress: ${steps.join(' | ')}');
  });

  test('Add service with a photo is saved (after the admin approved)', () async {
    // The test approves the business itself (service role) before this runs: see the runner script.
    final id = await repo.saveService(
      name: 'Geyser repair',
      category: 'Plumbing',
      price: 650,
      description: 'Fix or replace a geyser element or thermostat.',
      pricingType: PricingType.fixed,
      photos: [PhotoRef(bytes: jpeg(120 * 1024), name: 'geyser.jpg')],
    );
    expect(id, isNotEmpty);
  });
}
