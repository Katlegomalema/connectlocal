import 'package:flutter/material.dart';

/// Shown when the app was built without `--dart-define=API_BASE_URL=...`: there is no offline mode,
/// so instead of an empty app the person sees how to fix the build.
class NotConfiguredApp extends StatelessWidget {
  final String target;
  const NotConfiguredApp({super.key, required this.target});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ConnectLocal',
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 48),
                      const SizedBox(height: 16),
                      const Text('This build is not connected to the ConnectLocal server',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      const Text('Build or run the app with the API address, for example:'),
                      const SizedBox(height: 8),
                      SelectableText(
                        'flutter run -t $target --dart-define=API_BASE_URL=https://<codespace>-3000.app.github.dev',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      const Text('See SETUP.md in the project for the full steps.'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
