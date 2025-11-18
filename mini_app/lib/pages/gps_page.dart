import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../services/location_service.dart'; // serviço centralizado para GPS/localização

class GpsPage extends StatefulWidget {
  const GpsPage({super.key});

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage>
    with AutomaticKeepAliveClientMixin<GpsPage> {
  mbx.MapboxMap? _mapboxMap; // referência ao mapa
  mbx.Point? _currentLocation; // posição actual do utilizador
  bool _isLoading = true; // a carregar localização inicial
  bool _isMapAlive = false; // protege chamadas depois de dispose
  String? _error; // mensagem de erro (se existir)

  mbx.CircleAnnotationManager? _userCircleManager; // gestor de anotações (círculos)
  mbx.CircleAnnotation? _userCircle; // círculo central (ponto do user)
  mbx.CircleAnnotation? _userHalo; // “halo” em volta do user
  StreamSubscription<Position>? _posSub; // subscrição de updates de posição

  static const _ecoMint = Color(0xFF3CD4A0); // cor base para o indicador do user

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init(); // arranque: pedir permissões e obter posição inicial
  }

  Future<void> _init() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _error = 'Permissões/GPS não disponíveis. '
            'Ativa a localização e dá permissão à app.';
        _currentLocation = null;
        _isLoading = false;
      });
      return;
    }

    // posição inicial – agora tentamos algo rápido, sem forçar stream lento
    final p =
        await LocationService.instance.getCurrentLocation(forceFresh: false);
    if (!mounted) return;

    setState(() {
      if (p == null) {
        _error = 'Não foi possível obter a tua localização inicial.';
        _currentLocation = null;
      } else {
        _error = null;
        _currentLocation =
            mbx.Point(coordinates: mbx.Position(p.longitude, p.latitude));
      }
      _isLoading = false;
    });
  }

  /// Chamado quando o widget do mapa está pronto
  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _mapboxMap = map;
    _isMapAlive = true;

    try {
      // desactiva o "ponto azul" nativo e usamos apenas o nosso indicador custom
      await _mapboxMap!.location
          .updateSettings(mbx.LocationComponentSettings(enabled: false));
    } catch (_) {}

    await _ensureUserIndicator();

    // centra a câmara na localização inicial, se existir
    if (_currentLocation != null) {
      await _moveCameraTo(_currentLocation!, animated: false);
    }

    // fluxo contínuo de updates de GPS
    _posSub ??=
        LocationService.instance.getLocationUpdates().listen((pos) async {
      if (!_isMapAlive) return;
      final pt =
          mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));
      _currentLocation = pt;
      await _updateUserIndicator(pt);
    });
  }

  /// Cria o círculo/hâlo do utilizador (apenas se ainda não existir)
  Future<void> _ensureUserIndicator() async {
    if (!_isMapAlive || _mapboxMap == null || _currentLocation == null) return;

    try {
      _userCircleManager ??=
          await _mapboxMap!.annotations.createCircleAnnotationManager();

      // halo com menos opacidade
      _userHalo ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 22.0,
          circleColor: _ecoMint.toARGB32(),
          circleOpacity: 0.25,
        ),
      );

      // círculo central
      _userCircle ??= await _userCircleManager!.create(
        mbx.CircleAnnotationOptions(
          geometry: _currentLocation!,
          circleRadius: 8.0,
          circleColor: _ecoMint.toARGB32(),
          circleStrokeColor: const Color(0xFFFFFFFF).toARGB32(),
          circleStrokeWidth: 2.5,
        ),
      );
    } catch (_) {}
  }

  /// Actualiza a posição do indicador do utilizador no mapa
  Future<void> _updateUserIndicator(mbx.Point pt) async {
    if (!_isMapAlive) return;

    try {
      if (_userCircleManager == null ||
          _userHalo == null ||
          _userCircle == null) {
        await _ensureUserIndicator();
        return;
      }

      _userHalo!.geometry = pt;
      _userCircle!.geometry = pt;
      await _userCircleManager!.update(_userHalo!);
      await _userCircleManager!.update(_userCircle!);
    } catch (_) {}
  }

  /// Move a câmara para um ponto (com ou sem animação)
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
      padding: mbx.MbxEdgeInsets(
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
      ),
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

  /// Handler do botão "Obter / ir para a minha localização"
  Future<void> _goToUser() async {
    final ok = await LocationService.instance.checkPermissions();
    if (!ok) {
      if (!mounted) return;
      setState(() {
        _error =
            'GPS desligado ou sem permissões. Ativa nas definições do sistema.';
      });
      return;
    }

    // aqui tentamos 1º algo rápido, e só depois forçamos "fresh" se precisar
    final pos =
        await LocationService.instance.getCurrentLocation(forceFresh: true);
    if (pos == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Não consegui obter a tua localização agora.';
      });
      return;
    }

    final target =
        mbx.Point(coordinates: mbx.Position(pos.longitude, pos.latitude));

    setState(() {
      _error = null;
      _currentLocation = target;
    });

    await _ensureUserIndicator();
    await _moveCameraTo(target, animated: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final padding = MediaQuery.of(context).padding;
    final safeTop = padding.top;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // mapa principal
        Positioned.fill(
          child: mbx.MapWidget(
            key: const ValueKey('gps-map'), // ajuda a manter estado estável
            onMapCreated: _onMapCreated,
            cameraOptions: mbx.CameraOptions(
              center: _currentLocation,
              zoom: 14.0,
            ),
          ),
        ),

        // barra de erro no topo, se existir algum erro de GPS/permissões
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            top: safeTop + 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

        // botão para recentrar no utilizador
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
