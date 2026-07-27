import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> clearAppBadge() async {
  web.window.navigator.serviceWorker.controller?.postMessage(
    <String, Object?>{'type': 'CLEAR_APP_BADGE'}.jsify(),
  );
}
