import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../config/constants.dart';
import '../../config/env_keys.dart';
import '../../widgets/widgets.dart';

/// Study Materials — simplified flow:
///   • Faculty/Student fill Title + Subject, pick a file, and "post" it —
///     this just saves the Title/Subject/file name on THIS device
///     (shared_preferences — no backend), then opens the one shared
///     Google Drive folder in the browser so the actual file can be
///     dropped in there.
///   • Everyone else sees the list of posted Title + Subject entries;
///     tapping any entry opens that SAME shared Drive folder link.
/// There's no real Drive API upload/list here on purpose — it's a thin
/// "metadata card that deep-links to the folder" rather than a full
/// Drive integration.
class StudyMaterialsScreen extends StatefulWidget {
  const StudyMaterialsScreen({super.key});

  @override
  State<StudyMaterialsScreen> createState() => _StudyMaterialsScreenState();
}

/// File Share Options a faculty/student picks at post time. Only
/// affects what students see in the list below — everything still
/// lives in the same one shared Drive folder.
enum MaterialVisibility { everyone, facultyOnly }

extension MaterialVisibilityX on MaterialVisibility {
  String get label => this == MaterialVisibility.facultyOnly
      ? 'Faculty only'
      : 'Everyone (Students & Faculty)';

  String get storageValue =>
      this == MaterialVisibility.facultyOnly ? 'faculty_only' : 'everyone';

  static MaterialVisibility fromStorage(String? value) =>
      value == 'faculty_only'
          ? MaterialVisibility.facultyOnly
          : MaterialVisibility.everyone;
}

/// One posted entry — Title + Subject + the picked file's name, plus who
/// posted it. Persisted as JSON in shared_preferences under
/// [_StudyMaterialsScreenState._prefsKey].
class _MaterialEntry {
  final String id;
  final String title;
  final String subject;
  final String fileName;
  final MaterialVisibility visibility;
  final String uploaderName;
  final DateTime createdOn;

  _MaterialEntry({
    required this.id,
    required this.title,
    required this.subject,
    required this.fileName,
    required this.visibility,
    required this.uploaderName,
    required this.createdOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'fileName': fileName,
        'visibility': visibility.storageValue,
        'uploaderName': uploaderName,
        'createdOn': createdOn.toIso8601String(),
      };

  factory _MaterialEntry.fromJson(Map<String, dynamic> json) => _MaterialEntry(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        subject: json['subject'] as String? ?? '',
        fileName: json['fileName'] as String? ?? '',
        visibility:
            MaterialVisibilityX.fromStorage(json['visibility'] as String?),
        uploaderName: json['uploaderName'] as String? ?? '',
        createdOn: DateTime.tryParse(json['createdOn'] as String? ?? '') ??
            DateTime.now(),
      );
}

class _StudyMaterialsScreenState extends State<StudyMaterialsScreen> {
  static const _prefsKey = 'study_materials_entries_v1';

  bool _loading = true;
  List<_MaterialEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  bool get _isFaculty =>
      context.read<AuthService>().currentUser?.role == UserRole.faculty;

  String get _driveFolderUrl =>
      'https://drive.google.com/drive/folders/${EnvKeys.studyMaterialsFolderId}';

  Future<void> _loadEntries() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    var entries = raw
        .map((s) =>
            _MaterialEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdOn.compareTo(a.createdOn));
    // Students never see "Faculty only" materials, no matter what.
    if (!_isFaculty) {
      entries = entries
          .where((e) => e.visibility != MaterialVisibility.facultyOnly)
          .toList();
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _saveEntry(_MaterialEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? [];
    raw.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_prefsKey, raw);
  }

  Future<void> _openDriveFolder() async {
    final uri = Uri.parse(_driveFolderUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _toast('Could not open the Drive folder.');
  }

  Future<void> _postMaterial() async {
    final details = await _showPostDialog();
    if (details == null) return; // cancelled

    final user = context.read<AuthService>().currentUser;
    final entry = _MaterialEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: details.title,
      subject: details.subject,
      fileName: details.fileName,
      visibility: details.visibility,
      uploaderName: user?.name ?? 'Unknown',
      createdOn: DateTime.now(),
    );

    await _saveEntry(entry);
    if (!mounted) return;
    _toast('Posted "${details.title}".');
    await _loadEntries();
  }

  Future<_PostDetails?> _showPostDialog() {
    final titleController = TextEditingController();
    final subjectController = TextEditingController();
    final fileNameController = TextEditingController();
    var driveOpened = false;
    var visibility = MaterialVisibility.everyone;
    final isFaculty = _isFaculty;

    return showDialog<_PostDetails>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Post Study Material'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  // "Choose File" opens the shared Drive folder directly —
                  // that's where the actual file gets dropped in, since
                  // this app doesn't do its own file upload.
                  onPressed: () async {
                    await _openDriveFolder();
                    setDialogState(() => driveOpened = true);
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(driveOpened
                      ? 'Drive folder opened ✓ (tap to open again)'
                      : 'Choose File'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fileNameController,
                  decoration: const InputDecoration(
                    labelText: 'File name (optional)',
                    hintText: 'e.g. Unit 3 Notes.pdf',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('File Share Options',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                RadioListTile<MaterialVisibility>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: MaterialVisibility.everyone,
                  groupValue: visibility,
                  title: const Text('Everyone (Students & Faculty)'),
                  onChanged: (v) => setDialogState(() => visibility = v!),
                ),
                RadioListTile<MaterialVisibility>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: MaterialVisibility.facultyOnly,
                  groupValue: visibility,
                  title: const Text('Faculty only'),
                  onChanged: isFaculty
                      ? (v) => setDialogState(() => visibility = v!)
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleController.text.trim();
                final subject = subjectController.text.trim();
                if (title.isEmpty || subject.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Fill Title and Subject first.')));
                  return;
                }
                final fileName = fileNameController.text.trim();
                Navigator.pop(
                  ctx,
                  _PostDetails(
                    title: title,
                    subject: subject,
                    fileName:
                        fileName.isEmpty ? '(see Drive folder)' : fileName,
                    visibility: visibility,
                  ),
                );
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Materials')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _postMaterial,
        icon: const Icon(Icons.upload_file),
        label: const Text('Post Material'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadEntries,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return const EmptyState(
        message: 'No materials posted yet. Tap "Post Material" to add a title, '
            'subject and file.',
        icon: Icons.folder_open_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 90),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final e = _entries[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.primary),
            title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Wrap(
              spacing: 6,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  [
                    e.subject,
                    e.uploaderName,
                    e.createdOn.toLocal().toString().split(' ').first,
                  ].where((s) => s.isNotEmpty).join(' • '),
                ),
                if (e.visibility == MaterialVisibility.facultyOnly)
                  const Chip(
                    label: Text('Faculty only', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
            onTap: _openDriveFolder,
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: 'Open Drive folder',
              onPressed: _openDriveFolder,
            ),
          ),
        );
      },
    );
  }
}

/// What the Post dialog (Title + Subject + File Share Options) collects
/// before the entry is saved and the Drive folder is opened.
class _PostDetails {
  final String title;
  final String subject;
  final String fileName;
  final MaterialVisibility visibility;
  const _PostDetails({
    required this.title,
    required this.subject,
    required this.fileName,
    required this.visibility,
  });
}
