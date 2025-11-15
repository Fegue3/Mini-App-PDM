import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;

  bool _loading = true;
  bool _showCamera = false;
  bool _flashOn = false;

  int _cameraIndex = 0; // só usamos a câmara [0]
  XFile? _lastPicture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      // Permissão da câmara
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          setState(() {
            _error = 'Permissão da câmara recusada.';
            _loading = false;
          });
          return;
        }
      }

      // Obter câmaras disponíveis
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _error = 'Nenhuma câmara encontrada.';
          _loading = false;
        });
        return;
      }

      // usa simplesmente a primeira câmara disponível
      _cameraIndex = 0;

      await _initController();
    } catch (e) {
      setState(() {
        _error = 'Erro ao inicializar a câmara: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _initController() async {
    final cam = _cameras[_cameraIndex];

    final old = _controller;
    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    await _controller!.setFlashMode(FlashMode.off);
    _flashOn = false;

    await old?.dispose();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFlash() async {
    if (!(_controller?.value.isInitialized ?? false)) return;
    _flashOn = !_flashOn;

    await _controller!.setFlashMode(
      _flashOn ? FlashMode.always : FlashMode.off,
    );

    setState(() {});
  }

  Future<void> _takePicture() async {
    if (!(_controller?.value.isInitialized ?? false)) return;

    try {
      final pic = await _controller!.takePicture();
      setState(() {
        _lastPicture = pic;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao tirar foto: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }

    final hasCamera = _controller?.value.isInitialized ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Botão abrir/fechar câmara
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasCamera
                  ? () {
                      setState(() => _showCamera = !_showCamera);
                    }
                  : null,
              icon: const Icon(Icons.camera_alt),
              label: Text(_showCamera ? 'Fechar câmara' : 'Ir para a câmara'),
            ),
          ),
          const SizedBox(height: 12),

          // Preview + controlos
          if (_showCamera && hasCamera) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 380,
                width: double.infinity,
                child: CameraPreview(_controller!),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _takePicture,
                  child: const Icon(Icons.camera),
                ),
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                  tooltip: 'Flash',
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: Text(
                'Carrega em "Ir para a câmara" para abrir a pré-visualização.',
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Última foto tirada:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),

          if (_lastPicture != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_lastPicture!.path),
                width: double.infinity,
                fit: BoxFit.contain, // mostra a foto inteira, sem cortar
              ),
            )
          else
            const Text('Ainda não tiraste nenhuma foto.'),
        ],
      ),
    );
  }
}
