class Site {
  Site({required this.id, required this.name, required this.lat, required this.lng, required this.radiusMeters});
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusMeters;

  factory Site.fromFirestore(String id, Map<String, dynamic> d) => Site(
        id: id,
        name: d['name'] as String,
        lat: (d['geo']['lat'] as num).toDouble(),
        lng: (d['geo']['lng'] as num).toDouble(),
        radiusMeters: (d['radiusMeters'] as num).toDouble(),
      );
}
