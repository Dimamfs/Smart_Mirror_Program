import 'dart:io';
import 'package:flutter/services.dart';

/// Platform abstraction for joining the SmartMirror-Setup AP.
///
/// Android (API ≥ 29): uses WifiNetworkSpecifier + bindProcessToNetwork via a
/// MethodChannel so all subsequent HTTP to 192.168.42.1 routes over the AP
/// rather than escaping to cellular.
///
/// iOS: returns false from join() — the caller shows manual-join instructions
/// instead (NEHotspotConfiguration requires a paid-account entitlement).
class MirrorHotspot {
  static const _channel = MethodChannel('com.smartmirror/hotspot');

  static const ssid = 'SmartMirror-Setup';
  static const passphrase = 'SmartMirror1';

  static Future<bool> get canAutoJoin async {
    if (!Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('canAutoJoin');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Joins the setup AP. Android: triggers OS dialog + binds process to that
  /// network. Returns true once the network is bound. iOS: always false.
  static Future<bool> join() async {
    if (!Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('join', {
        'ssid': ssid,
        'passphrase': passphrase,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Unbinds the process from the AP network so subsequent calls use normal
  /// connectivity. Call after POST /connect. iOS: no-op.
  static Future<void> leave() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('leave');
    } catch (_) {}
  }
}
