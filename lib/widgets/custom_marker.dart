import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMarker {
  final LatLng position;
  final String label;

  CustomMarker({required this.position, required this.label});

  Marker buildMarker() {
    return Marker(
      markerId: MarkerId(label),
      position: position,
      infoWindow: InfoWindow(title: label),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
  }
}
