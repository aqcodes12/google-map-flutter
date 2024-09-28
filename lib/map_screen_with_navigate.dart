import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:google_places_flutter/model/prediction.dart';
import '../services/location_service.dart';
import '../utils/dialog_utils.dart';

class MapScreenWithNavigate extends StatefulWidget {
  @override
  State<MapScreenWithNavigate> createState() => _MapScreenWithNavigateState();
}

class _MapScreenWithNavigateState extends State<MapScreenWithNavigate> {
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _dropLocation;
  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _dropController = TextEditingController();
  PolylinePoints polylinePoints = PolylinePoints();

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
          _pickupController.text = 'Current Location';
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
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers.add(Marker(
        markerId: MarkerId(title),
        position: position,
        infoWindow: InfoWindow(title: title),
      ));
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
        _drawPolyline();
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
        _drawPolyline();
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
      );

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA",
        request: request,
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });

        setState(() {
          _polylines.add(Polyline(
            polylineId: PolylineId('pickup_drop_route'),
            width: 5,
            color: Colors.blue,
            points: polylineCoordinates,
          ));
        });

        _moveCameraToShowPolyline(polylineCoordinates);
      }
    }
  }

  void _moveCameraToShowPolyline(List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isNotEmpty) {
      LatLngBounds bounds;
      if (polylineCoordinates.length == 1) {
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

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
    }
  }

  void _navigateToNextPage() {
    if (_pickupLocation != null && _dropLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NextPage(
            pickupLocation: _pickupLocation!,
            dropLocation: _dropLocation!,
          ),
        ),
      );
    } else {
      showErrorDialog(
          context, 'Error', 'Please select both pickup and drop locations.');
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
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: _pickupController,
                    googleAPIKey: "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA",
                    inputDecoration: InputDecoration(
                      labelText: 'Pickup Location',
                      hintText: 'Enter Pickup Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    debounceTime: 800,
                    countries: ["in", "fr"],
                    isLatLngRequired: true,
                    getPlaceDetailWithLatLng: (Prediction prediction) {},
                    itemClick: (Prediction prediction) {
                      _pickupController.text = prediction.description!;
                      _handlePickupLocation(prediction.description!);
                    },
                    itemBuilder: (context, index, Prediction prediction) {
                      return ListTile(
                        leading: Icon(Icons.location_on),
                        title: Text(prediction.description ?? ""),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  GooglePlaceAutoCompleteTextField(
                    textEditingController: _dropController,
                    googleAPIKey: "AIzaSyBR74fwmZcozpqZLeIdUc9ecTAT1TWDEEA",
                    inputDecoration: InputDecoration(
                      labelText: 'Drop Location',
                      hintText: 'Enter Drop Location',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    debounceTime: 800,
                    countries: ["in", "fr"],
                    isLatLngRequired: true,
                    getPlaceDetailWithLatLng: (Prediction prediction) {},
                    itemClick: (Prediction prediction) {
                      _dropController.text = prediction.description!;
                      _handleDropLocation(prediction.description!);
                    },
                    itemBuilder: (context, index, Prediction prediction) {
                      return ListTile(
                        leading: Icon(Icons.location_on),
                        title: Text(prediction.description ?? ""),
                      );
                    },
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
                      polylines: _polylines,
                    ),
            ),
            ElevatedButton(
              onPressed: _navigateToNextPage,
              child: Text('Proceed with Pickup & Drop'),
            ),
          ],
        ),
      ),
    );
  }
}

class NextPage extends StatelessWidget {
  final LatLng pickupLocation;
  final LatLng dropLocation;

  const NextPage({
    Key? key,
    required this.pickupLocation,
    required this.dropLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pickup & Drop Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Pickup Location: ${pickupLocation.latitude}, ${pickupLocation.longitude}'),
            SizedBox(height: 16),
            Text(
                'Drop Location: ${dropLocation.latitude}, ${dropLocation.longitude}'),
          ],
        ),
      ),
    );
  }
}
