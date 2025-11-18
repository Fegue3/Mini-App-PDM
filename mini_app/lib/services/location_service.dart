import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();

  static LocationService get instance => _instance;

  /// Flag interno: true quando a permissão foi ACABADA de ser dada.
  bool _justGrantedPermission = false;

  /// Verifica e pede permissões de localização
  ///
  /// 1. Primeiro trata das permissões (popup do sistema).
  /// 2. Só depois verifica se o serviço de localização está ligado.
  /// 3. Se a permissão foi concedida agora, marca `_justGrantedPermission = true`.
  Future<bool> checkPermissions() async {
    // estado inicial da permissão
    final initialPermission = await Geolocator.checkPermission();
    var permission = initialPermission;

    // 1) PERMISSÕES
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      // user recusou ou bloqueou
      return false;
    }

    // se antes era denied/deniedForever e agora é whileInUse/always,
    // significa que o user ACABOU de dar permissão
    final isNowGranted = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
    final wasDeniedBefore = initialPermission == LocationPermission.denied ||
        initialPermission == LocationPermission.deniedForever;

    if (isNowGranted && wasDeniedBefore) {
      _justGrantedPermission = true;
    }

    // 2) SERVIÇO DE LOCALIZAÇÃO (GPS / network)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // opcional: podes abrir diretamente as settings
      // await Geolocator.openLocationSettings();
      return false;
    }

    return true;
  }

  /// Posição actual
  ///
  /// Estratégia normal:
  /// 1. Tenta obter posição "rápida" (getCurrentPosition com timeLimit).
  /// 2. Se der timeout, tenta lastKnownPosition.
  /// 3. Se forceFresh == true, como fallback tenta stream com timeout pequeno.
  ///
  /// EXTRA:
  /// - Se `_justGrantedPermission == true`, nesta chamada faz SEMPRE
  ///   um fix "fresco" pelo stream com timeout maior (10s) e depois limpa o flag.
  Future<Position?> getCurrentLocation({bool forceFresh = false}) async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    // Caso especial: ACABÁMOS de ganhar permissão → garantir 1ª localização "a sério"
    if (_justGrantedPermission) {
      _justGrantedPermission = false;

      try {
        const settings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );

        final freshPos = await Geolocator.getPositionStream(
          locationSettings: settings,
        ).first.timeout(const Duration(seconds: 10));

        return freshPos;
      } on TimeoutException {
        // se mesmo assim não vier nada, caímos no fluxo normal abaixo
      } catch (e) {
        // ignore: avoid_print
        print('Error getting first fresh location after permission: $e');
      }
    }

    // Fluxo normal
    try {
      // tentativa rápida (normalmente quase instantâneo se o SO tiver fix recente)
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      return pos;
    } on TimeoutException {
      // se demorar demais, tentamos o último ponto conhecido
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && !forceFresh) {
        return last;
      }

      if (!forceFresh) {
        return last; // pode ser null
      }

      // caller pediu "fresco": tentamos stream mas com timeout curto
      try {
        const settings = LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );

        return await Geolocator.getPositionStream(
          locationSettings: settings,
        ).first.timeout(const Duration(seconds: 5));
      } catch (e) {
        // ignore: avoid_print
        print('Error getting fresh location from stream: $e');
        return last;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting current location: $e');
      final last = await Geolocator.getLastKnownPosition();
      return last;
    }
  }

  /// Stream de updates de localização contínuos
  Stream<Position> getLocationUpdates() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metros
      ),
    );
  }

  /// Morada (string) a partir de coordenadas
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        return "${place.street}, ${place.locality}, "
            "${place.administrativeArea}, ${place.country}";
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Error getting address from coordinates: $e');
      return null;
    }
  }

  /// Coordenadas a partir de uma morada (usa geocoding -> devolve Position)
  Future<Position?> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations[0];
        return Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error getting coordinates from address: $e');
      return null;
    }
    return null;
  }
}
