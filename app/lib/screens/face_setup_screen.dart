import 'package:flutter/material.dart';

class FaceSetupScreen extends StatefulWidget {
  const FaceSetupScreen({super.key});

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen> {
  bool _isScanning = false;
  bool _isRegistered = false;

  void _startScan() {
    setState(() {
      _isScanning = true;
    });

    // We fake a 3-second scanning process so you can see the UI change!
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        _isScanning = false;
        _isRegistered = true;
      });
    });
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Register your face to load your personalized mirror profile and bypass security alerts.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 48),

          // 1. The Camera Placeholder area
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRegistered ? Colors.green : Colors.grey, 
                width: 2
              ),
            ),
            child: Center(
              child: _isScanning
                  ? const CircularProgressIndicator() // Shows a loading spinner
                  : Icon(
                      _isRegistered ? Icons.check_circle : Icons.camera_alt,
                      size: 80,
                      color: _isRegistered ? Colors.green : Colors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 32),

          // 2. The Action Button
          ElevatedButton.icon(
            // If it's currently scanning OR already registered, disable the button (null)
            onPressed: _isScanning || _isRegistered ? null : _startScan,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(_isScanning
                ? 'Scanning Face...'
                : _isRegistered
                    ? 'Registration Complete'
                    : 'Start Camera Scan'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
          ),

          // 3. A reset button that only shows up AFTER you register
          if (_isRegistered) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isRegistered = false;
                });
              },
              child: const Text('Retake Scan'),
            )
          ]
        ],
      ),
    );
  }
}