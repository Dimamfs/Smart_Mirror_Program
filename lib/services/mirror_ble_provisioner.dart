import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Shared GATT UUIDs — must match provisioning/ble-setup.py on the Pi.
const _kServiceUuid     = '4fafc201-1fb5-459e-8fcc-c5c9c3319143';
const _kNetworksUuid    = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const _kCredentialsUuid = 'a9b1c2d3-e4f5-6789-abcd-ef0123456789';
const _kStatusUuid      = 'c0d1e2f3-a4b5-6789-cdef-012345678901';

class BleNetwork {
  final String ssid;
  final bool secured;
  const BleNetwork({required this.ssid, required this.secured});

  static List<BleNetwork> fromJson(List<dynamic> list) => list
      .map((e) => BleNetwork(ssid: e['ssid'] as String, secured: e['secured'] as bool))
      .toList();
}

class BleStatus {
  final String state;  // idle | scanning | connecting | connected | failed
  final String ip;
  final String apiBaseUrl;

  const BleStatus({required this.state, this.ip = '', this.apiBaseUrl = ''});

  static BleStatus fromJson(Map<String, dynamic> m) => BleStatus(
        state:      m['state'] as String? ?? 'idle',
        ip:         m['ip'] as String? ?? '',
        apiBaseUrl: m['apiBaseUrl'] as String? ?? '',
      );

  bool get isConnected => state == 'connected';
  bool get isFailed    => state == 'failed';
}

class MirrorBleProvisioner {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _networks;
  BluetoothCharacteristic? _credentials;
  BluetoothCharacteristic? _status;

  static final Guid _svcGuid  = Guid(_kServiceUuid);
  static final Guid _netGuid  = Guid(_kNetworksUuid);
  static final Guid _credGuid = Guid(_kCredentialsUuid);
  static final Guid _statGuid = Guid(_kStatusUuid);

  /// Scan for the Smart Mirror BLE service. Returns the first result found.
  /// Throws [TimeoutException] if none found within [timeout].
  Future<BluetoothDevice> scanForMirror({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final completer = Completer<BluetoothDevice>();
    StreamSubscription? sub;

    await FlutterBluePlus.startScan(
      withServices: [_svcGuid],
      timeout: timeout,
    );

    sub = FlutterBluePlus.scanResults.listen((results) {
      if (results.isNotEmpty && !completer.isCompleted) {
        completer.complete(results.first.device);
      }
    });

    FlutterBluePlus.isScanning.where((s) => !s).first.then((_) {
      sub?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('No Smart Mirror found nearby.'),
        );
      }
    });

    return completer.future;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// Connect to [device] and discover the provisioning service characteristics.
  Future<void> connectAndDiscover(BluetoothDevice device) async {
    _device = device;
    await device.connect(timeout: const Duration(seconds: 15));
    final services = await device.discoverServices();
    final svc = services.firstWhere(
      (s) => s.serviceUuid == _svcGuid,
      orElse: () => throw StateError('Smart Mirror provisioning service not found.'),
    );
    _networks    = _charFor(svc, _netGuid);
    _credentials = _charFor(svc, _credGuid);
    _status      = _charFor(svc, _statGuid);
  }

  BluetoothCharacteristic _charFor(BluetoothService svc, Guid uuid) =>
      svc.characteristics.firstWhere(
        (c) => c.characteristicUuid == uuid,
        orElse: () => throw StateError('Characteristic $uuid not found.'),
      );

  /// Read the Networks characteristic and return parsed list.
  Future<List<BleNetwork>> readNetworks() async {
    final raw = await _networks!.read();
    final decoded = jsonDecode(utf8.decode(raw)) as List<dynamic>;
    return BleNetwork.fromJson(decoded);
  }

  /// Subscribe to Status notifications. Emits [BleStatus] on every change.
  Stream<BleStatus> statusStream() {
    return _status!.lastValueStream
        .where((v) => v.isNotEmpty)
        .map((v) => BleStatus.fromJson(jsonDecode(utf8.decode(v)) as Map<String, dynamic>));
  }

  Future<void> subscribeStatus() => _status!.setNotifyValue(true);

  /// Write WiFi credentials to the mirror.
  Future<void> submitCredentials({required String ssid, required String password}) async {
    final payload = jsonEncode({'ssid': ssid, 'password': password});
    await _credentials!.write(utf8.encode(payload), withoutResponse: false);
  }

  Future<void> disconnect() async {
    await _status?.setNotifyValue(false).catchError((_) => false);
    await _device?.disconnect();
    _device = null;
    _networks = _credentials = _status = null;
  }
}
