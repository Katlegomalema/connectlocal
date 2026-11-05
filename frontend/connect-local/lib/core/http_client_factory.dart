import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.io) 'http_client_factory_io.dart'
    if (dart.library.js_interop) 'http_client_factory_web.dart' as impl;

/// The HTTP client the app uses: on Android/iOS a 10 s connect timeout and idle connections closed after
/// 10 s (before the server's 65 s, so a pooled connection is never reused after the server dropped it).
/// In the browser, the browser manages connections.
http.Client createHttpClient() => impl.createHttpClient();
