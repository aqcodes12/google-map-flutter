import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../services/location_service.dart';
import '../utils/dialog_utils.dart';

class MapScreen extends StatefulWidget {
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {}; // Polyline set

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  PolylinePoints polylinePoints = PolylinePoints(); // For calculating polyline

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      LatLng? location = await _locationService.requestAndFetchLocation();
      if (location != null) {
        setState(() {
          _currentLocation = location;
          _pickupLocation = location;
          _pickupController.text =
              'Current Location'; // Set pickup as current location
          _addMarker(location, 'Pickup Location');
        });
      }
    } catch (e) {
      showErrorDialog(
          context, 'Location Error', 'Unable to get your location. $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _moveCameraToLocation(_currentLocation!);
    }
  }

  void _moveCameraToLocation(LatLng location) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, 15),
    );
  }

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(title),
          position: position,
          infoWindow: InfoWindow(title: title),
        ),
      );
    });
  }

  Future<void> _handlePickupLocation(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        LatLng pickupLatLng =
            LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _pickupLocation = pickupLatLng;
          _addMarker(pickupLatLng, 'Pickup Location');
          _moveCameraToLocation(pickupLatLng);
        });
        _drawPolyline(); // Draw polyline if both locations are set
      }
    } catch (e) {
      showErrorDialog(
          context, 'Address Error', 'Unable to get pickup location. $e');
    }
  }

  Future<void> _handleDropLocation(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        LatLng dropLatLng =
            LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _dropLocation = dropLatLng;
          _addMarker(dropLatLng, 'Drop Location');
          _moveCameraToLocation(dropLatLng);
        });
        _drawPolyline(); // Draw polyline if both locations are set
      }
    } catch (e) {
      showErrorDialog(
          context, 'Address Error', 'Unable to get drop location. $e');
    }
  }

  void _drawPolyline() async {
    if (_pickupLocation != null && _dropLocation != null) {
      List<LatLng> polylineCoordinates = [];

      PolylineRequest request = PolylineRequest(
        origin:
            PointLatLng(_pickupLocation!.latitude, _pickupLocation!.longitude),
        destination:
            PointLatLng(_dropLocation!.latitude, _dropLocation!.longitude),
        mode: TravelMode.driving,
        wayPoints: [], // You can add waypoints if needed
      );

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey:
            "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA", // Replace with your API key
        request: request,
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        setState(() {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('pickup_drop_route'),
              width: 5,
              color: Colors.blue,
              points: polylineCoordinates,
            ),
          );
        });

        // Move the camera to show the entire polyline
        _moveCameraToShowPolyline(polylineCoordinates);
      } else {
        print('No polyline points found.');
      }
    } else {
      print('Pickup or Drop location is null.');
    }
  }

  void _moveCameraToShowPolyline(List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds;

      if (polylineCoordinates.length == 1) {
        // If there's only one point, set the bounds to that point
        bounds = LatLngBounds(
          southwest: polylineCoordinates[0],
          northeast: polylineCoordinates[0],
        );
      } else {
        double southWestLat = polylineCoordinates[0].latitude;
        double southWestLng = polylineCoordinates[0].longitude;
        double northEastLat = polylineCoordinates[0].latitude;
        double northEastLng = polylineCoordinates[0].longitude;

        for (LatLng point in polylineCoordinates) {
          southWestLat =
              southWestLat < point.latitude ? southWestLat : point.latitude;
          southWestLng =
              southWestLng < point.longitude ? southWestLng : point.longitude;
          northEastLat =
              northEastLat > point.latitude ? northEastLat : point.latitude;
          northEastLng =
              northEastLng > point.longitude ? northEastLng : point.longitude;
        }

        bounds = LatLngBounds(
          southwest: LatLng(southWestLat, southWestLng),
          northeast: LatLng(northEastLat, northEastLng),
        );
      }

      _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100)); // Add padding
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Google Map'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeMap,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pickup Location Field
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: _pickupController,
                    googleAPIKey:
                        "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA", // Add your Google API key here
                    inputDecoration: InputDecoration(
                      labelText: 'Pickup Location',
                      hintText: 'Enter Pickup Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    debounceTime: 800, // Default 600 ms
                    countries: ["in", "fr"], // Optional countries
                    isLatLngRequired: true, // If you require coordinates
                    getPlaceDetailWithLatLng: (Prediction prediction) {
                      // Method returns latlng with place detail
                      print(
                          "Place Details: Lat: ${prediction.lat}, Lng: ${prediction.lng}");
                    },
                    itemClick: (Prediction prediction) {
                      _pickupController.text = prediction.description!;
                      _handlePickupLocation(prediction.description!);
                    },
                    itemBuilder: (context, index, Prediction prediction) {
                      return Container(
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(Icons.location_on),
                            SizedBox(width: 7),
                            Expanded(
                                child: Text("${prediction.description ?? ""}")),
                          ],
                        ),
                      );
                    },
                    seperatedBuilder: Divider(),
                    isCrossBtnShown: true,
                    containerHorizontalPadding: 10,
                    placeType: PlaceType.geocode,
                  ),

                  SizedBox(height: 16), // Space between pickup and drop fields

                  // Drop Location Field
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: _dropController,
                    googleAPIKey:
                        "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA", // Add your Google API key here
                    inputDecoration: InputDecoration(
                      labelText: 'Drop Location',
                      hintText: 'Enter Drop Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    debounceTime: 800, // Default 600 ms
                    countries: ["in", "fr"], // Optional countries
                    isLatLngRequired: true, // If you require coordinates
                    getPlaceDetailWithLatLng: (Prediction prediction) {
                      // Method returns latlng with place detail
                      print(
                          "Place Details: Lat: ${prediction.lat}, Lng: ${prediction.lng}");
                    },
                    itemClick: (Prediction prediction) {
                      _dropController.text = prediction.description!;
                      _handleDropLocation(prediction.description!);
                    },
                    itemBuilder: (context, index, Prediction prediction) {
                      return Container(
                        padding: EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(Icons.location_on),
                            SizedBox(width: 7),
                            Expanded(
                                child: Text("${prediction.description ?? ""}")),
                          ],
                        ),
                      );
                    },
                    seperatedBuilder: Divider(),
                    isCrossBtnShown: true,
                    containerHorizontalPadding: 10,
                    placeType: PlaceType.geocode,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _currentLocation == null
                  ? Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation!,
                        zoom: 15,
                      ),
                      markers: _markers,
                      polylines: _polylines, // Add polylines here
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
