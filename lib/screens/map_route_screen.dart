import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class MapRouteScreen extends StatefulWidget {
  final double bankLat;
  final double bankLng;
  final String bankName;

  const MapRouteScreen({
    Key? key,
    required this.bankLat,
    required this.bankLng,
    required this.bankName,
  }) : super(key: key);

  @override
  State<MapRouteScreen> createState() => _MapRouteScreenState();
}

class _MapRouteScreenState extends State<MapRouteScreen> {
  final MapController _mapController = MapController();
  Position? currentPosition;
  List<LatLng> routePoints = [];
  bool isLoadingRoute = false;

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied.')));
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      currentPosition = position;
    });

    await _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (currentPosition == null) return;
    setState(() => isLoadingRoute = true);

    try {
      final startLat = currentPosition!.latitude;
      final startLng = currentPosition!.longitude;
      final endLat = widget.bankLat;
      final endLng = widget.bankLng;

      final url = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          setState(() {
            routePoints = coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
    } finally {
      if (mounted) setState(() => isLoadingRoute = false);
      _fitMapBounds();
    }
  }

  void _fitMapBounds() {
    if (currentPosition == null) return;
    
    final userPos = LatLng(currentPosition!.latitude, currentPosition!.longitude);
    final bankPos = LatLng(widget.bankLat, widget.bankLng);

    final bounds = LatLngBounds.fromPoints([userPos, bankPos, ...routePoints]);
    
    // Animate or fit camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50.0),
        ),
      );
    });
  }

  Future<void> _launchExternalNavigation() async {
    if (currentPosition == null) return;
    final Uri url = Uri.parse(
        'https://www.openstreetmap.org/directions?engine=fossgis_osrm_car&route=${currentPosition!.latitude}%2C${currentPosition!.longitude}%3B${widget.bankLat}%2C${widget.bankLng}');
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open map URL')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Route to ${widget.bankName}')),
      body: currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bloodnow.app',
                    ),
                    if (routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routePoints,
                            strokeWidth: 4.0,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // User Location Marker
                        Marker(
                          point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                        ),
                        // Blood Bank Location Marker
                        Marker(
                          point: LatLng(widget.bankLat, widget.bankLng),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isLoadingRoute)
                  const Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text('Calculating route...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: _launchExternalNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Open External Map', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              ],
            ),
    );
  }
}
