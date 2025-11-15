import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();

  static LocationService get instance => _instance;

  /// Verifica e pede permissões de localização
  Future<bool> checkPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Posição actual (opcionalmente força um fix “fresco” via stream)
  Future<Position?> getCurrentLocation({bool forceFresh = false}) async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) return null;

    try {
      if (!forceFresh) {
        // leitura "normal"
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      // força um fix novo, lendo o primeiro valor do stream
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      return await Geolocator.getPositionStream(
        locationSettings: settings,
      ).first.timeout(const Duration(seconds: 10));
    } catch (e) {
      // ignore: avoid_print
      print('Error getting current location: $e');
      return null;
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
