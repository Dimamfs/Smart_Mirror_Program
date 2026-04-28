import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
// Note: In a real app, you'd pass the active Profile into this screen so you know the profileId.
// For now, we assume you'll pass it in the constructor or fetch it from a provider.

class FaceSetupScreen extends StatefulWidget {
  // Ideally, require the profile ID here:
  // final int profileId;
  // const FaceSetupScreen({super.key, required this.profileId});

  const FaceSetupScreen({super.key});

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen> {
  CameraController? _cameraController;
  bool _isScanning = false;
  bool _isRegistered = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get list of available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found on device.');
        return;
      }

      // Try to find the front-facing camera
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() => _error = 'Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized)
      return;

    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      // 1. Take the picture
      final XFile image = await _cameraController!.takePicture();

      // 2. Upload to backend (Assuming profile ID is 1 for testing. You MUST pass the actual profile ID here)
      final api = context.read<AuthProvider>().api;
      await api.uploadFace(
          1, image.path); // TODO: Replace '1' with actual profile.id

      if (!mounted) return;
      setState(() {
        _isRegistered = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Biometric Setup',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register your face to load your personalized mirror profile and bypass security alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 48),

          // 1. The Camera View area
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _isRegistered ? Colors.green : Colors.white24,
                  width: 2),
            ),
            clipBehavior: Clip
                .hardEdge, // ensures camera preview respects rounded corners
            child: Center(
              child: _buildCameraPreview(),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center),
          ],

          const SizedBox(height: 32),

          // 2. The Action Button
          ElevatedButton.icon(
            onPressed: _isScanning || _isRegistered || _cameraController == null
                ? null
                : _startScan,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(_isScanning
                ? 'Uploading Face...'
                : _isRegistered
                    ? 'Registration Complete'
                    : 'Start Camera Scan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              textStyle:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // 3. Reset button
          if (_isRegistered) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRegistered = false;
                });
              },
              child: const Text('Retake Scan',
                  style: TextStyle(color: Colors.white54)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isRegistered) {
      return const Icon(Icons.check_circle, size: 80, color: Colors.green);
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    if (_isScanning) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    // Embed the live camera view
    return CameraPreview(_cameraController!);
  }
}
