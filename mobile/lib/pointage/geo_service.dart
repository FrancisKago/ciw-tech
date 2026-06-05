import 'package:geolocator/geolocator.dart';

class GeoDenied implements Exception { const GeoDenied(); }

class GeoFix {
  GeoFix(this.lat, this.lng, this.accuracy);
  final double lat, lng, accuracy;
}

class GeoService {
  /// Lève [GeoDenied] si la permission est refusée — le pointage est alors bloqué.
  Future<GeoFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const GeoDenied();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw const GeoDenied();
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return GeoFix(pos.latitude, pos.longitude, pos.accuracy);
  }
}
