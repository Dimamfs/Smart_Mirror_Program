// Backend base URL. Override per environment without editing code:
//   flutter run --dart-define=API_URL=http://10.0.2.2:3000/api      (Android emulator)
//   flutter run --dart-define=API_URL=http://localhost:3000/api     (desktop/web)
//   flutter run --dart-define=API_URL=http://192.168.1.x:3000/api   (physical device)
// Defaults to the LAN IP used for physical-device testing.
const String kBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://192.168.1.6:3000/api',
);
