// Web NFC API bindings (dart:js_interop) — lets Chrome on Android read an
// NFC card's hardware UID directly from the browser, so students don't
// have to install a separate NFC-reader app and copy-paste a hex string
// during signup. Only supported on Chrome for Android: Safari/Chrome on
// iOS both run on WebKit (Apple requires it for every iOS browser), and
// WebKit has never implemented Web NFC — there is no browser-based
// workaround for iOS. Desktop browsers also don't support it (no NFC
// hardware). Callers must feature-detect with [isWebNfcSupported] and
// fall back to manual entry everywhere else.
//
// Spec: https://w3c.github.io/web-nfc/
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('NDEFReader')
extension type _NDEFReader._(JSObject _) implements JSObject {
  external factory _NDEFReader();
  external JSPromise<JSAny?> scan();
  external set onreading(JSFunction? handler);
  external set onreadingerror(JSFunction? handler);
}

extension type _NDEFReadingEvent._(JSObject _) implements JSObject {
  external String get serialNumber;
}

/// True if this browser exposes the Web NFC `NDEFReader` API at all.
/// Does not guarantee the device actually has NFC hardware — a scan can
/// still fail at runtime (e.g. NFC turned off in device settings).
bool get isWebNfcSupported {
  try {
    return globalContext.has('NDEFReader');
  } catch (_) {
    return false;
  }
}

/// Starts a Web NFC scan and resolves with the first card's serial number
/// (colon-separated hex, e.g. "04:80:7D:CA:C5:78:80" — same format the
/// app already normalizes to), or null if the user didn't tap a card
/// within [timeout]. Throws if permission is denied or the browser
/// rejects the scan (e.g. NFC is off, or unsupported despite the
/// feature-detect passing).
Future<String?> scanNfcCard({Duration timeout = const Duration(seconds: 20)}) async {
  final reader = _NDEFReader();
  final completer = Completer<String?>();

  void onReading(JSAny event) {
    if (completer.isCompleted) return;
    final reading = event as _NDEFReadingEvent;
    completer.complete(reading.serialNumber);
  }

  void onReadingError(JSAny event) {
    if (completer.isCompleted) return;
    completer.completeError(Exception('NFC reading error'));
  }

  reader.onreading = onReading.toJS;
  reader.onreadingerror = onReadingError.toJS;

  // scan() itself can reject (permission denied, NFC unsupported/off).
  await reader.scan().toDart;

  return completer.future.timeout(
    timeout,
    onTimeout: () => null,
  );
}
