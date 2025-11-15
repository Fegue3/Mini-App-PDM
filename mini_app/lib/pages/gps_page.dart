import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../services/location_service.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  mbx.MapboxMap? _mapboxMap;
  mbx.Point? _currentLocation;
  bool _isLoading = true;
  bool _isMapAlive = false;
  String? _error;

  mbx.CircleAnnotationManager? _userCircleManager;
  mbx.CircleAnnotation? _userCircle;
  mbx.CircleAnnotation? _userHalo;
  StreamSubscription<Position>? _posSub;

  static const _ecoMint = Color(0xFF3CD4A0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _error = 'Permissões ou serviços de localização não disponíveis.';
        _currentLocation = null;
        _isLoading = false;
      });
      return;
    }

    final p = await LocationService.instance.getCurrentLocation();
    if (!mounted) return;

    setState(() {
      _currentLocation = (p != null)
          ? mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude))
          : null;
      _isLoading = false;
    });
  }

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;
    _isMapAlive = true;

    try {
      // desligamos o "ponto azul" nativo para usar o nosso indicador custom
      await _mapboxMap!.location
          .updateSettings(mbx.LocationComponentSettings(enabled: false));
    } catch (_) {}

    await _ensureUserIndicator();

    if (_currentLocation != null) {
      await _moveCameraTo(_currentLocation!, animated: false);
    }

    _posSub ??=
        LocationService.instance.getLocationUpdates().listen((pos) async {
      if (!_isMapAlive) return;
      final pt =
          mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
      _currentLocation = pt;
      await _updateUserIndicator(pt);
    });
  }

  Future<void> _ensureUserIndicator() async {
    if (!_isMapAlive || _mapboxMap == null || _currentLocation == null) return;

    try {
      _userCircleManager ??=
          await _mapboxMap!.annotations.createCircleAnnotationManager();

      _userHalo ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 22.0,
          circleColor: _ecoMint.withOpacity(0.25).value,
        ),
      );

      _userCircle ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 8.0,
          circleColor: _ecoMint.value,
          circleStrokeColor: 0xFFFFFFFF,
          circleStrokeWidth: 2.5,
        ),
      );
    } catch (_) {}
  }

  Future<void> _updateUserIndicator(mbx.Point pt) async {
    if (!_isMapAlive) return;

    try {
      if (_userCircleManager == null) {
        await _ensureUserIndicator();
        return;
      }
      if (_userHalo == null || _userCircle == null) {
        await _ensureUserIndicator();
        return;
      }

      _userHalo!.geometry = pt;
      _userCircle!.geometry = pt;
      await _userCircleManager!.update(_userHalo!);
      await _userCircleManager!.update(_userCircle!);
    } catch (_) {}
  }

  Future<void> _moveCameraTo(
    mbx.Point target, {
    bool animated = true,
  }) async {
    if (!_isMapAlive || _mapboxMap == null) return;

    final camera = mbx.CameraOptions(
      center: target,
      zoom: 15,
      bearing: 0,
      pitch: 0,
      padding: mbx.MbxEdgeInsets(top: 0, left: 0, right: 0, bottom: 0),
    );

    try {
      if (animated) {
        await _mapboxMap!
            .easeTo(camera, mbx.MapAnimationOptions(duration: 900));
      } else {
        await _mapboxMap!.setCamera(camera);
      }
    } catch (_) {}
  }

  Future<void> _goToUser() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!ok) return;

    final pos = await LocationService.instance.getCurrentLocation();
    if (pos == null) return;

    final target =
        mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
    _currentLocation = target;

    await _ensureUserIndicator();
    await _moveCameraTo(target, animated: true);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;
    final safeTop = padding.top;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // MAPA (sem styleUri -> default da Mapbox)
        Positioned.fill(
          child: mbx.MapWidget(
            onMapCreated: _onMapCreated,
            cameraOptions: mbx.CameraOptions(
              center: _currentLocation,
              zoom: 14.0,
            ),
          ),
        ),

        // Mensagem de erro (se houver)
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            top: safeTop + 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

        // Botão "Obter localização" em cima
        Positioned(
          left: 16,
          right: 16,
          top: safeTop + 10 + (_error != null ? 50 : 0),
          child: ElevatedButton.icon(
            onPressed: _goToUser,
            icon: const Icon(Icons.my_location),
            label: const Text('Obter / ir para a minha localização'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _isMapAlive = false;
    _posSub?.cancel();
    _posSub = null;
    _userCircleManager?.deleteAll().catchError((_) {});
    _userCircleManager = null;
    _userCircle = null;
    _userHalo = null;
    _mapboxMap = null;
    super.dispose();
  }
}
