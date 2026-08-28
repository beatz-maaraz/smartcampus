import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../services/campus_data_service.dart';
import '../../services/ai_service.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

/// Chemical Hub — scan a chemical label or search a name to view safety
/// info (Application Flow §3.2, §7). Faculty/Admin variants add storage
/// notes / stock management on top of this same lookup (see dashboards).
///
/// Image scanning: AiService.scanChemicalImage tries Groq's vision model
/// first, and falls back to Hugging Face image classification (see
/// ApiConfig for how the three API keys are supplied).
class ChemicalHubScreen extends StatefulWidget {
  const ChemicalHubScreen({super.key});

  @override
  State<ChemicalHubScreen> createState() => _ChemicalHubScreenState();
}

class _ChemicalHubScreenState extends State<ChemicalHubScreen> {
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  bool _loading = false;
  ChemicalInfo? _result;
  late final AiService _ai;

  @override
  void initState() {
    super.initState();
    _ai = AiService(context.read<CampusDataService>());
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    final info = await _ai.lookupChemicalSafety(query.trim());
    if (!mounted) return;
    setState(() {
      _result = info;
      _loading = false;
    });
  }

  Future<void> _scanLabel() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    // maxWidth/imageQuality keep the upload small — a full-resolution
    // phone photo can be several MB, which is slow over mobile data and
    // can get rejected by the vision API outright.
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _loading = true);
    try {
      final info = await _ai.scanChemicalImage(File(picked.path));
      if (!mounted) return;
      setState(() {
        _result = info;
        _searchController.text = info.name;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chemical Hub')),
      body: Padding(
        padding: const EdgeInsets.all(kPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _search,
                    decoration: const InputDecoration(
                      hintText: 'Search chemical name (e.g. Ethanol, HCl)',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _scanLabel,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Scan'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _result != null) _buildResultCard(_result!),
            if (!_loading && _result == null)
              const Expanded(
                child: EmptyState(
                  message:
                      'Search a chemical name or scan a label to view its safety brief.',
                  icon: Icons.science_outlined,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ChemicalInfo info) {
    final isScanFailure = info.name == 'Scan failed';
    final (color, label) = isScanFailure
        ? (AppColors.danger, '⚠️ Scan Error')
        : switch (info.hazard) {
            HazardLevel.safe => (AppColors.safe, '🟢 Safe'),
            HazardLevel.careful => (AppColors.warning, '🟡 Handle with Care'),
            HazardLevel.hazardous => (AppColors.danger, '🔴 Highly Hazardous'),
          };

    return Expanded(
      child: SingleChildScrollView(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(info.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    StatusChip(label: label, color: color),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Formula: ${info.formula}',
                    style: const TextStyle(color: AppColors.textSecondary)),
                const Divider(height: 28),
                const Text('Usage',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(info.usage),
                const SizedBox(height: 16),
                const Text('First Aid',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(info.firstAid),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
