import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/profile.dart';

class FaceSetupScreen extends StatefulWidget {
  final bool isActive;
  final Profile? initialProfile;
  const FaceSetupScreen({super.key, required this.isActive, this.initialProfile});

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen> {
  CameraController? _cameraController;
  bool _isScanning = false;
  bool _isRegistered = false;
  String? _error;

  // State variables for profile selection
  List<Profile> _profiles = [];
  Profile? _selectedProfile;
  bool _isLoadingProfiles = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    if (widget.isActive) _initializeCamera();
  }

  @override
  void didUpdateWidget(FaceSetupScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initializeCamera();
    } else if (!widget.isActive && oldWidget.isActive) {
      _cameraController?.dispose();
      _cameraController = null;
    }
  }

  Future<void> _loadProfiles() async {
    try {
      final api = context.read<AuthProvider>().api;
      final profiles = await api.listProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _selectedProfile = (widget.initialProfile != null
                  ? profiles
                      .where((p) => p.id == widget.initialProfile!.id)
                      .firstOrNull
                  : null) ??
              (profiles.isNotEmpty ? profiles.first : null);
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load profiles: $e';
          _isLoadingProfiles = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found on device.');
        return;
      }

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
      if (mounted) setState(() => _error = 'Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _selectedProfile == null) {
      return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      // Read api before the await to avoid using context across an async gap.
      final api = context.read<AuthProvider>().api;
      final XFile image = await _cameraController!.takePicture();

      // Upload using the dynamically selected profile ID
      await api.uploadFace(_selectedProfile!.id, image.path);

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
            'Select your profile and register your face to personalize the mirror and bypass security alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),

          // Profile Selector Dropdown
          if (_isLoadingProfiles)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_profiles.isEmpty)
            const Text('No profiles found. Please create one first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent))
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Profile>(
                  value: _selectedProfile,
                  dropdownColor: Colors.grey[900],
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  items: _profiles.map((profile) {
                    return DropdownMenuItem<Profile>(
                      value: profile,
                      child: Text(profile.name),
                    );
                  }).toList(),
                  onChanged: (Profile? newValue) {
                    setState(() {
                      _selectedProfile = newValue;
                      _isRegistered = false; // Reset status if profile changes
                    });
                  },
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Camera View area
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _isRegistered ? Colors.green : Colors.white24,
                  width: 2),
            ),
            clipBehavior: Clip.hardEdge,
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

          ElevatedButton.icon(
            onPressed: _isScanning ||
                    _isRegistered ||
                    _cameraController == null ||
                    _selectedProfile == null
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

    return CameraPreview(_cameraController!);
  }
}
