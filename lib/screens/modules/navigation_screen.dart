import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

// To render a real interactive map, add:
//   import 'package:google_maps_flutter/google_maps_flutter.dart';
// and swap the placeholder Container below for a GoogleMap widget fed by
// `venues` (see the comment near _buildMapArea).

/// Smart Navigation (Student/Faculty) — search a venue and get directions.
/// Also backs Admin's "Drop New Location Pin" (§6.1) since both read/write
/// the same CampusDataService.venues list.
class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _searchController = TextEditingController();
  VenueLocation? _selected;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<CampusDataService>();
    final results = data.searchVenues(_searchController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Navigation')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(kPad),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search a venue (e.g. Library, Seminar Hall)',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildMapArea(
                _selected ?? (results.isNotEmpty ? results.first : null)),
          ),
          Expanded(
            flex: 3,
            child: results.isEmpty
                ? const EmptyState(
                    message: 'No matching venues found.',
                    icon: Icons.location_off_outlined)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: kPad),
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final v = results[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.primary),
                          title: Text(v.name),
                          subtitle: Text(v.block),
                          trailing: const Icon(Icons.directions_outlined),
                          onTap: () => setState(() => _selected = v),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Placeholder map surface. Real implementation:
  ///
  /// GoogleMap(
  ///   initialCameraPosition: CameraPosition(
  ///     target: LatLng(venue.lat, venue.lng), zoom: 17,
  ///   ),
  ///   markers: venues.map((v) => Marker(
  ///     markerId: MarkerId(v.id),
  ///     position: LatLng(v.lat, v.lng),
  ///     infoWindow: InfoWindow(title: v.name),
  ///   )).toSet(),
  /// )
  Widget _buildMapArea(VenueLocation? venue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kPad),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Center(
        child: venue == null
            ? const Text('Search or select a venue to preview it on the map.',
                style: TextStyle(color: AppColors.textSecondary))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(venue.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Lat: ${venue.lat}, Lng: ${venue.lng}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  const Text('(google_maps_flutter renders here)',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
      ),
    );
  }
}
