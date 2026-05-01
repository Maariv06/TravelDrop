import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerMap extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerMap({super.key, this.initialLocation});

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  List<Placemark> _searchSuggestions = [];

  @override
  void initState() {
    super.initState();
    _selectedLocation =
        widget.initialLocation ?? const LatLng(13.0827, 80.2707);
    _updateMarker(_selectedLocation!);
  }

  ///  Update marker only if location is inside Tamil Nadu
  void _updateMarker(LatLng location) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;

        if (placemark.administrativeArea != "Tamil Nadu") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Parcel service is not available outside Tamil Nadu.",
              ),
              backgroundColor: Colors.red,
            ),
          );
          return; // Don't update marker
        }

        setState(() {
          _selectedLocation = location;
          _markers.clear();
          _markers.add(
            Marker(
              markerId: const MarkerId('selected_location'),
              position: location,
              draggable: true,
              onDragEnd: (newPosition) => _updateMarker(newPosition),
            ),
          );
        });
      }
    } catch (e) {
      print("Error validating location: $e");
    }
  }

  ///  Search location using geocoding
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => _searchSuggestions = []);
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );
        setState(() => _searchSuggestions = placemarks);
      } else {
        setState(() => _searchSuggestions = []);
      }
    } catch (e) {
      print("Search error: $e");
      setState(() => _searchSuggestions = []);
    }
  }

  ///  Confirm selection from search
  void _confirmSelection(Placemark placemark) async {
    List<Location> locations = await locationFromAddress(
      '${placemark.name}, ${placemark.locality}, ${placemark.country}',
    );

    if (locations.isNotEmpty) {
      LatLng newLatLng = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );

      // Validate Tamil Nadu
      if (placemark.administrativeArea != "Tamil Nadu") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Parcel service is not available outside Tamil Nadu.",
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _updateMarker(newLatLng);
      _mapController.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 14));

      setState(() {
        _searchController.text = '${placemark.name}, ${placemark.locality}';
        _searchSuggestions = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E4ABF),
        title: const Text(
          "Select Location",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLocation!,
              zoom: 10,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            onTap: (LatLng location) {
              _updateMarker(location);
              _mapController.animateCamera(CameraUpdate.newLatLng(location));
              setState(() => _searchSuggestions = []);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),

          // Search Bar Overlay
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
              elevation: 4,
              child: TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search location (e.g., Tenkasi)',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(15),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchSuggestions = []);
                          },
                        )
                      : null,
                ),
                onChanged: _searchLocation,
                onFieldSubmitted: (query) => _searchLocation(query),
              ),
            ),
          ),

          // Search Suggestions List
          if (_searchSuggestions.isNotEmpty)
            Positioned(
              top: 75,
              left: 12,
              right: 12,
              child: Card(
                elevation: 4,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchSuggestions.length,
                  itemBuilder: (context, index) {
                    final p = _searchSuggestions[index];
                    String address =
                        '${p.name}, ${p.locality ?? p.subLocality}, ${p.country}';
                    return ListTile(
                      title: Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const Icon(Icons.location_on),
                      onTap: () => _confirmSelection(p),
                    );
                  },
                ),
              ),
            ),

          // Confirm Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _selectedLocation == null
                  ? null
                  : () {
                      Navigator.pop(context, _selectedLocation);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E4ABF),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                "Confirm Selected Location",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
