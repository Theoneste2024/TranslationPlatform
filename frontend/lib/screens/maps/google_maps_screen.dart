import 'dart:async';
import 'dart:math';
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_nominatim/flutter_nominatim.dart';
import '../../l10n/app_localizations_extensions.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/app_header.dart';

class GoogleMapsScreen extends StatefulWidget {
  const GoogleMapsScreen({super.key});

  @override
  State<GoogleMapsScreen> createState() => _GoogleMapsScreenState();
}

class _GoogleMapsScreenState extends State<GoogleMapsScreen> {
  // Map Controller
  final MapController _mapController = MapController();

  // Location & Navigation
  ll.LatLng? _currentPosition;
  ll.LatLng? _destinationPosition;
  String? _destinationAddress;

  // UI States
  bool _isLoading = true;
  bool _isNavigating = false;
  bool _showDestinationInput = false;
  bool _isNearbyPlacesVisible = false;
  String? _selectedPlaceType;

  // Travel Mode
  String _travelMode = 'driving';
  final List<Map<String, dynamic>> _travelModes = [
    {
      'mode': 'driving',
      'icon': Icons.directions_car,
      'label': 'Car',
      'color': Colors.blue
    },
    {
      'mode': 'walking',
      'icon': Icons.directions_walk,
      'label': 'Walk',
      'color': Colors.green
    },
    {
      'mode': 'cycling',
      'icon': Icons.directions_bike,
      'label': 'Motor',
      'color': Colors.orange
    },
  ];

  // Markers & Routes
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];

  // Route Info
  double _totalDistance = 0.0;
  double _totalDuration = 0.0;
  String _routeSummary = '';

  // Zoom level
  double _currentZoom = 12.0;
  final double _minZoom = 3.0;
  final double _maxZoom = 19.0;

  // Destination Text Controller
  final TextEditingController _destinationController = TextEditingController();

  // GEOCODING SERVICE
  late final Nominatim _nominatim;

  // SEARCH RESULTS
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final FocusNode _searchFocusNode = FocusNode();

  // Kigali, Rwanda center
  final ll.LatLng _kigaliCenter = const ll.LatLng(-1.9441, 30.0619);

  // Stream subscription for live location
  StreamSubscription<Position>? _positionStreamSubscription;

  // Nearby Places Data
  final List<Map<String, dynamic>> _nearbyPlaceTypes = [
    {
      'type': 'hospital',
      'icon': Icons.local_hospital,
      'label': 'Hospitals',
      'color': Colors.red
    },
    {
      'type': 'hotel',
      'icon': Icons.hotel,
      'label': 'Hotels',
      'color': Colors.purple
    },
    {
      'type': 'restaurant',
      'icon': Icons.restaurant,
      'label': 'Restaurants',
      'color': Colors.orange
    },
    {
      'type': 'cafe',
      'icon': Icons.local_cafe,
      'label': 'Coffee Shops',
      'color': Colors.brown
    },
    {
      'type': 'bar',
      'icon': Icons.local_bar,
      'label': 'Bars',
      'color': Colors.indigo
    },
  ];

  // Sample nearby places in Kigali
  final Map<String, List<Map<String, dynamic>>> _nearbyPlaces = {
    'hospital': [
      {
        'name': 'King Faisal Hospital',
        'lat': -1.9653,
        'lng': 30.1086,
        'phone': '+250 788 384 100'
      },
      {
        'name': 'CHUK - Kigali',
        'lat': -1.9361,
        'lng': 30.0567,
        'phone': '+250 788 384 200'
      },
      {
        'name': 'Kibagabaga Hospital',
        'lat': -1.9258,
        'lng': 30.0983,
        'phone': '+250 788 384 300'
      },
    ],
    'hotel': [
      {
        'name': 'Marriott Hotel Kigali',
        'lat': -1.9456,
        'lng': 30.0628,
        'phone': '+250 788 123 456'
      },
      {
        'name': 'Radisson Blu Kigali',
        'lat': -1.9497,
        'lng': 30.0919,
        'phone': '+250 788 123 457'
      },
      {
        'name': 'Kigali Serena Hotel',
        'lat': -1.9528,
        'lng': 30.0997,
        'phone': '+250 788 123 458'
      },
    ],
    'restaurant': [
      {
        'name': 'The Hut Restaurant',
        'lat': -1.9472,
        'lng': 30.0914,
        'phone': '+250 788 234 567'
      },
      {
        'name': 'Sole Luna',
        'lat': -1.9458,
        'lng': 30.0642,
        'phone': '+250 788 234 568'
      },
      {
        'name': 'Repub Lounge',
        'lat': -1.9483,
        'lng': 30.0581,
        'phone': '+250 788 234 569'
      },
    ],
    'cafe': [
      {
        'name': 'Bourbon Coffee - KG220',
        'lat': -1.9447,
        'lng': 30.0639,
        'phone': '+250 788 345 678'
      },
      {
        'name': 'Java House Kigali',
        'lat': -1.9469,
        'lng': 30.0625,
        'phone': '+250 788 345 679'
      },
      {
        'name': 'Question Coffee',
        'lat': -1.9522,
        'lng': 30.0967,
        'phone': '+250 788 345 680'
      },
    ],
    'bar': [
      {
        'name': 'Papyrus Bar',
        'lat': -1.9453,
        'lng': 30.0614,
        'phone': '+250 788 456 789'
      },
      {
        'name': 'Cava Bar',
        'lat': -1.9478,
        'lng': 30.0631,
        'phone': '+250 788 456 790'
      },
      {
        'name': 'The Green Bar',
        'lat': -1.9519,
        'lng': 30.0994,
        'phone': '+250 788 456 791'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _nominatim = Nominatim.instance;
    _initLocation();
    _addRwandanMarkers();
    _startLiveLocation();
  }

  @override
  void dispose() {
    _destinationController.dispose();
    _searchFocusNode.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // Live Location Tracking
  void _startLiveLocation() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = ll.LatLng(position.latitude, position.longitude);
          _updateCurrentLocationMarker();
        });
      }
    });
  }

  // Location Services
  Future<void> _initLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(context.l10n.enableLocationServices, Colors.orange);
        _setDefaultLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar(context.l10n.locationPermissionDenied, Colors.red);
          _setDefaultLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar(
          context.l10n.locationPermissionPermanentlyDenied,
          Colors.red,
        );
        _setDefaultLocation();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = ll.LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _mapController.move(_currentPosition!, _currentZoom);
      _updateCurrentLocationMarker();
      _showSnackBar(context.l10n.liveLocationActive, Colors.green);
    } catch (e) {
      debugPrint('Location error: $e');
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentPosition = _kigaliCenter;
      _isLoading = false;
    });
    _mapController.move(_kigaliCenter, _currentZoom);
    _addDefaultLocationMarker();
    _showSnackBar(context.l10n.showingKigaliCenter, Colors.orange);
  }

  // Markers
  void _updateCurrentLocationMarker() {
    setState(() {
      _markers.removeWhere((m) => m.key == const ValueKey('current_location'));
      _markers.add(
        Marker(
          key: const ValueKey('current_location'),
          point: _currentPosition!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 20),
          ),
        ),
      );
    });
  }

  void _addDefaultLocationMarker() {
    setState(() {
      _markers.removeWhere((m) => m.key == const ValueKey('current_location'));
      _markers.add(
        Marker(
          key: const ValueKey('current_location'),
          point: _currentPosition!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 20),
          ),
        ),
      );
    });
  }

  void _addDestinationMarker() {
    if (_destinationPosition == null) return;

    setState(() {
      _markers.removeWhere((m) => m.key == const ValueKey('destination'));
      _markers.add(
        Marker(
          key: const ValueKey('destination'),
          point: _destinationPosition!,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
        ),
      );
    });
  }

  // ============ ✅ FIXED GEOCODING - NO 'type' PROPERTY ============
  Future<void> _searchLocation(String query) async {
    if (query.length < 3) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      // ✅ FREE GEOCODING - NO API KEY! - ONLY query parameter
      final results = await _nominatim.search(query);

      setState(() {
        _searchResults = results.map((place) {
          // Extract city name from display name
          String displayName = place.displayName;
          String shortName = displayName.split(',').first;

          return {
            'display_name': displayName,
            'lat': place.latitude, // ✅ Use latitude
            'lon': place.longitude, // ✅ Use longitude
            'type': shortName.contains('Hotel')
                ? 'hotel'
                : shortName.contains('Hospital')
                    ? 'hospital'
                    : shortName.contains('Restaurant')
                        ? 'restaurant'
                        : shortName.contains('Cafe') ||
                                shortName.contains('Coffee')
                            ? 'cafe'
                            : shortName.contains('Bar')
                                ? 'bar'
                                : 'place',
          };
        }).toList();
        _isSearching = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearching = false);
      _showSnackBar(context.l10n.placeSearchFailed, Colors.red);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    setState(() {
      _searchResults = [];
      _searchFocusNode.unfocus();
    });

    final position = LatLng(result['lat'], result['lon']);
    _setDestination(position, result['display_name']);

    _showSnackBar(
      context.l10n.destinationSetTo(
        result['display_name'].toString().split(',').first,
      ),
      Colors.green,
    );
  }

  // Nearby Places
  void _toggleNearbyPlaces(String placeType) {
    setState(() {
      if (_selectedPlaceType == placeType && _isNearbyPlacesVisible) {
        _isNearbyPlacesVisible = false;
        _selectedPlaceType = null;
        _markers.removeWhere((m) => m.key.toString().contains('nearby_'));
      } else {
        _isNearbyPlacesVisible = true;
        _selectedPlaceType = placeType;
        _markers.removeWhere((m) => m.key.toString().contains('nearby_'));

        final places = _nearbyPlaces[placeType] ?? [];
        final placeColor = _nearbyPlaceTypes.firstWhere(
          (p) => p['type'] == placeType,
          orElse: () => {'color': Colors.grey},
        )['color'];

        for (var place in places) {
          final uniqueKey =
              'nearby_${placeType}_${place['name'].replaceAll(' ', '_')}';

          _markers.add(
            Marker(
              key: ValueKey(uniqueKey),
              point: ll.LatLng(place['lat'], place['lng']),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showPlaceInfo(place, placeType, placeColor),
                child: Container(
                  decoration: BoxDecoration(
                    color: placeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: placeColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _nearbyPlaceTypes
                        .firstWhere((p) => p['type'] == placeType)['icon'],
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          );
        }

        if (places.isNotEmpty) {
          final firstPlace = places.first;
          _mapController.move(
              ll.LatLng(firstPlace['lat'], firstPlace['lng']), 14.0);
        }
      }
    });
  }

  void _hideNearbyPlaces() {
    setState(() {
      _isNearbyPlacesVisible = false;
      _selectedPlaceType = null;
      _markers.removeWhere((m) => m.key.toString().contains('nearby_'));
    });
  }

  void _showPlaceInfo(
      Map<String, dynamic> place, String placeType, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _nearbyPlaceTypes
                  .firstWhere((p) => p['type'] == placeType)['icon'],
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(place['name'])),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 ${context.l10n.placeCategory(_nearbyPlaceLabel(context, placeType))}',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(place['phone'] ?? context.l10n.noPhoneAvailable),
              ],
            ),
            const Divider(),
            const Text(
              'OpenStreetMap Nominatim',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
            Text(
              '✅ ${context.l10n.freeGeocodingNoApiKey}',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
          if (_currentPosition != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _setDestination(
                  LatLng(place['lat'], place['lng']),
                  place['name'],
                );
              },
              child: Text(context.l10n.navigateHere),
            ),
        ],
      ),
    );
  }

  void _addRwandanMarkers() {
    setState(() {
      _markers.addAll([
        Marker(
          key: const ValueKey('kigali_city'),
          point: _kigaliCenter,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _setDestinationFromLandmark(
                _kigaliCenter, 'Kigali City Center'),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00A1DE),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00A1DE).withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.location_city,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
        Marker(
          key: const ValueKey('bk_arena'),
          point: const ll.LatLng(-1.9501, 30.0588),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _setDestinationFromLandmark(
                const ll.LatLng(-1.9501, 30.0588), 'BK Arena'),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF20603D),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20603D).withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.sports_basketball,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
        Marker(
          key: const ValueKey('convention_centre'),
          point: const ll.LatLng(-1.9393, 30.0475),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _setDestinationFromLandmark(
                const ll.LatLng(-1.9393, 30.0475), 'Kigali Convention Centre'),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE1BD00),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE1BD00).withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.business, color: Colors.white, size: 20),
            ),
          ),
        ),
        Marker(
          key: const ValueKey('airport'),
          point: const ll.LatLng(-1.9686, 30.1145),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _setDestinationFromLandmark(
                const ll.LatLng(-1.9686, 30.1145),
                'Kigali International Airport'),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.flight, color: Colors.white, size: 20),
            ),
          ),
        ),
      ]);
    });
  }

  void _setDestinationFromLandmark(ll.LatLng position, String name) {
    final nomPosition = LatLng(position.latitude, position.longitude);
    _setDestination(nomPosition, name);
  }

  // Destination & Routing
  void _setDestination(LatLng position, [String? address]) {
    setState(() {
      _destinationPosition = ll.LatLng(position.latitude, position.longitude);
      _destinationAddress = address ?? context.l10n.selectedLocation;
      _destinationController.text = _destinationAddress!;
      _showDestinationInput = false;
      _isNavigating = false;
      _polylines.clear();
      _searchResults = [];
    });

    _addDestinationMarker();
    _mapController.move(_destinationPosition!, 15.0);
    _showSnackBar(context.l10n.destinationSet, Colors.green);
  }

  void _clearDestination() {
    setState(() {
      _destinationPosition = null;
      _destinationAddress = null;
      _destinationController.clear();
      _polylines.clear();
      _isNavigating = false;
      _totalDistance = 0.0;
      _totalDuration = 0.0;
      _routeSummary = '';
      _searchResults = [];
      _markers.removeWhere((m) => m.key == const ValueKey('destination'));
    });

    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _currentZoom);
    }
  }

  // Route Calculation
  Future<void> _getRoute() async {
    if (_currentPosition == null || _destinationPosition == null) {
      _showSnackBar(context.l10n.setDestinationFirst, Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _isNavigating = true;
    });

    try {
      final String profile = _travelMode == 'walking'
          ? 'foot'
          : _travelMode == 'cycling'
              ? 'bike'
              : 'driving';

      final url = Uri.parse('http://router.project-osrm.org/route/v1/$profile/'
          '${_currentPosition!.longitude},${_currentPosition!.latitude};'
          '${_destinationPosition!.longitude},${_destinationPosition!.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=true');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok') {
          final List<dynamic> routes = data['routes'];

          _polylines.clear();

          for (int i = 0; i < routes.length; i++) {
            final route = routes[i];
            final geometry = route['geometry'];
            final distance = route['distance'] / 1000;
            final duration = route['duration'] / 60;

            List<ll.LatLng> points = [];
            for (var coord in geometry['coordinates']) {
              points.add(ll.LatLng(coord[1], coord[0]));
            }

            Color routeColor =
                i == 0 ? const Color(0xFF00A1DE) : Colors.grey.shade400;

            double strokeWidth = i == 0 ? 6.0 : 4.0;

            _polylines.add(
              Polyline(
                points: points,
                color: routeColor,
                strokeWidth: strokeWidth,
                borderColor: i == 0 ? Colors.white : null,
                borderStrokeWidth: i == 0 ? 2.0 : 0.0,
              ),
            );

            if (i == 0) {
              _totalDistance = distance;
              _totalDuration = duration;

              if (route['legs'] != null && route['legs'].isNotEmpty) {
                final leg = route['legs'][0];
                if (leg['steps'] != null) {
                  _routeSummary = _getRouteSummary(leg['steps']);
                }
              }
            }
          }

          setState(() => _isLoading = false);

          _showSnackBar(
            context.l10n.bestRouteSummary(
              _totalDistance.toStringAsFixed(1),
              _totalDuration.toStringAsFixed(0),
            ),
            Colors.green,
          );
        } else {
          throw Exception('Routing failed');
        }
      } else {
        throw Exception('Routing API error');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _offlineRoute();
      debugPrint('Routing error: $e');
    }
  }

  String _getRouteSummary(List<dynamic> steps) {
    if (steps.isEmpty) return '';

    final firstStep = steps[0];
    String instruction = firstStep['maneuver']?['type'] ?? '';
    String modifier = firstStep['maneuver']?['modifier'] ?? '';

    if (instruction == 'depart') {
      return context.l10n.headDirection(_getDirectionText(modifier));
    }

    return _capitalize('$instruction $modifier');
  }

  String _getDirectionText(String modifier) {
    switch (modifier) {
      case 'north':
        return context.l10n.north;
      case 'south':
        return context.l10n.south;
      case 'east':
        return context.l10n.east;
      case 'west':
        return context.l10n.west;
      case 'northeast':
        return context.l10n.northeast;
      case 'northwest':
        return context.l10n.northwest;
      case 'southeast':
        return context.l10n.southeast;
      case 'southwest':
        return context.l10n.southwest;
      default:
        return modifier;
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  void _offlineRoute() {
    if (_currentPosition == null || _destinationPosition == null) return;

    setState(() {
      _polylines.clear();
      _polylines.add(
        Polyline(
          points: [_currentPosition!, _destinationPosition!],
          color: const Color(0xFF00A1DE).withValues(alpha: 0.7),
          strokeWidth: 4.0,
        ),
      );

      _totalDistance =
          _calculateDistance(_currentPosition!, _destinationPosition!);
      _totalDuration = _totalDistance *
          (_travelMode == 'walking'
              ? 12
              : _travelMode == 'cycling'
                  ? 4
                  : 2);
      _routeSummary = context.l10n.offlineDirectRoute;
    });

    _showSnackBar(context.l10n.offlineDirectLine, Colors.orange);
  }

  double _calculateDistance(ll.LatLng start, ll.LatLng end) {
    const R = 6371;
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final deltaLat = (end.latitude - start.latitude) * pi / 180;
    final deltaLng = (end.longitude - start.longitude) * pi / 180;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  // Zoom Controls
  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(_minZoom, _maxZoom);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  // UI Helpers
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleDestinationInput() {
    setState(() {
      _showDestinationInput = !_showDestinationInput;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.freeMapsRwanda,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(context.l10n.liveLocationFreeGeocoding,
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: const Color(0xFF00A1DE),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: [
            if (_isNearbyPlacesVisible)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _hideNearbyPlaces,
                tooltip: context.l10n.hideNearbyPlaces,
              ),
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _initLocation,
              tooltip: context.l10n.myLocation,
            ),
            const AppBrandControls(),
          ],
        ),
        body: Stack(
          children: [
            if (_currentPosition != null)
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPosition!,
                  initialZoom: _currentZoom,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  onTap: (tapPosition, point) {
                    _setDestination(
                      LatLng(point.latitude, point.longitude),
                      context.l10n.selectedLocation,
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.translation.platform',
                  ),
                  MarkerLayer(markers: _markers),
                  PolylineLayer(polylines: _polylines),
                  if (_currentPosition != null)
                    CurrentLocationLayer(
                      style: LocationMarkerStyle(
                        marker: const DefaultLocationMarker(
                          child: Icon(Icons.navigation,
                              color: Colors.white, size: 16),
                        ),
                        markerSize: const Size(40, 40),
                        accuracyCircleColor: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                ],
              )
            else if (_isLoading)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(context.l10n.gettingLiveLocation),
                  ],
                ),
              ),

            // Zoom Controls
            Positioned(
              right: 16,
              top: 16,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: _zoomIn,
                          tooltip: context.l10n.zoomIn,
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.blue),
                          onPressed: _zoomOut,
                          tooltip: context.l10n.zoomOut,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Working Search Bar
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _destinationController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: context.l10n.searchPlaceHint,
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.blue),
                        suffixIcon: _destinationPosition != null
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear, color: Colors.red),
                                onPressed: _clearDestination,
                              )
                            : _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: _searchLocation,
                      onSubmitted: _searchLocation,
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            leading: Icon(
                              result['type'] == 'city'
                                  ? Icons.location_city
                                  : result['type'] == 'restaurant'
                                      ? Icons.restaurant
                                      : result['type'] == 'hotel'
                                          ? Icons.hotel
                                          : result['type'] == 'hospital'
                                              ? Icons.local_hospital
                                              : result['type'] == 'cafe'
                                                  ? Icons.local_cafe
                                                  : result['type'] == 'bar'
                                                      ? Icons.local_bar
                                                      : Icons.place,
                              color: Colors.blue,
                            ),
                            title: Text(
                              result['display_name']
                                  .toString()
                                  .split(',')
                                  .first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              result['display_name']
                                  .toString()
                                  .split(',')
                                  .skip(1)
                                  .join(','),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Nearby Places Buttons
            Positioned(
              top: _searchResults.isNotEmpty ? 380 : 80,
              left: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        context.l10n.nearbyPlaces,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const Divider(height: 1),
                    ..._nearbyPlaceTypes.map((place) => InkWell(
                          onTap: () => _toggleNearbyPlaces(place['type']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedPlaceType == place['type'] &&
                                      _isNearbyPlacesVisible
                                  ? place['color'].withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  place['icon'],
                                  color: _selectedPlaceType == place['type'] &&
                                          _isNearbyPlacesVisible
                                      ? place['color']
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _nearbyPlaceLabel(context, place['type']),
                                  style: TextStyle(
                                    color:
                                        _selectedPlaceType == place['type'] &&
                                                _isNearbyPlacesVisible
                                            ? place['color']
                                            : Colors.grey,
                                    fontWeight:
                                        _selectedPlaceType == place['type'] &&
                                                _isNearbyPlacesVisible
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                                if (_selectedPlaceType == place['type'] &&
                                    _isNearbyPlacesVisible)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.check,
                                      color: place['color'],
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ),

            // Travel Modes
            if (!_isNearbyPlacesVisible)
              Positioned(
                bottom: 200,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: _travelModes.map((mode) {
                      bool isSelected = _travelMode == mode['mode'];
                      return InkWell(
                        onTap: () {
                          setState(() => _travelMode = mode['mode']);
                          if (_destinationPosition != null) {
                            _getRoute();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? mode['color'].withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                mode['icon'],
                                color: isSelected ? mode['color'] : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _travelModeLabel(context, mode['mode']),
                                style: TextStyle(
                                  color:
                                      isSelected ? mode['color'] : Colors.grey,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            // Route Info Card
            if (_isNavigating && _totalDistance > 0)
              Positioned(
                bottom: 100,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child:
                                  const Icon(Icons.route, color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.l10n.bestRoute,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    _destinationAddress ??
                                        context.l10n.destination,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.timer,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.l10n.minutesAbbreviation(
                                      _totalDuration.toStringAsFixed(0),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildRouteInfoItem(
                              Icons.speed,
                              context.l10n.distance,
                              '${_totalDistance.toStringAsFixed(1)} km',
                            ),
                            _buildRouteInfoItem(
                              Icons.directions,
                              context.l10n.travelMode,
                              _travelModeLabel(context, _travelMode),
                            ),
                            _buildRouteInfoItem(
                              Icons.info_outline,
                              context.l10n.summary,
                              _routeSummary.isNotEmpty
                                  ? _routeSummary
                                  : context.l10n.routeReady,
                            ),
                          ],
                        ),
                        if (_routeSummary.isNotEmpty) ...[
                          const Divider(height: 24),
                          Row(
                            children: [
                              const Icon(Icons.lightbulb,
                                  color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _routeSummary,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Destination Button
            if (_destinationPosition == null)
              Positioned(
                bottom: 40,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _toggleDestinationInput,
                  label: Text(context.l10n.setDestination),
                  icon: const Icon(Icons.add_location),
                  backgroundColor: Colors.red,
                ),
              )
            else if (!_isNavigating)
              Positioned(
                bottom: 40,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _getRoute,
                  label: Text(context.l10n.getDirections),
                  icon: const Icon(Icons.directions),
                  backgroundColor: Colors.green,
                ),
              )
            else
              Positioned(
                bottom: 40,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _clearDestination,
                  label: Text(context.l10n.clearRoute),
                  icon: const Icon(Icons.clear),
                  backgroundColor: Colors.orange,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _nearbyPlaceLabel(BuildContext context, String type) {
    switch (type) {
      case 'hospital':
        return context.l10n.hospitals;
      case 'hotel':
        return context.l10n.hotels;
      case 'restaurant':
        return context.l10n.restaurants;
      case 'cafe':
        return context.l10n.coffeeShops;
      case 'bar':
        return context.l10n.bars;
      default:
        return type;
    }
  }

  String _travelModeLabel(BuildContext context, String mode) {
    switch (mode) {
      case 'driving':
        return context.l10n.car;
      case 'walking':
        return context.l10n.walk;
      case 'cycling':
        return context.l10n.bicycle;
      default:
        return mode;
    }
  }

  Widget _buildRouteInfoItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
