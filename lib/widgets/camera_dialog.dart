import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraHelper {
  static Future<XFile?> captureWithCamera(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found on this device.')),
        );
        return null;
      }

      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (!context.mounted) return null;

      final XFile? result = await showDialog<XFile>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CameraDialog(controller: controller),
      );

      await controller.dispose();
      return result;
    } catch (e) {
      debugPrint('Camera Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      return null;
    }
  }
}

class CameraDialog extends StatelessWidget {
  final CameraController controller;

  const CameraDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF5D4037),
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),

          // Header
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              onPressed: () => Navigator.pop(context, null),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            ),
          ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      final image = await controller.takePicture();
                      if (context.mounted) {
                        Navigator.pop(context, image);
                      }
                    } catch (e) {
                      debugPrint('Error taking picture: $e');
                    }
                  },
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
