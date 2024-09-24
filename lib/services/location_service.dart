import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  final Location _location = Location();

  Future<LatLng?> requestAndFetchLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw Exception('Location permission denied.');
      }
    }

    var locationData = await _location.getLocation();
    if (locationData.latitude == null || locationData.longitude == null) {
      throw Exception('Failed to get location coordinates.');
    }

    return LatLng(locationData.latitude!, locationData.longitude!);
  }
}
