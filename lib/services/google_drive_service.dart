import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../config/env_keys.dart';

/// File Share Options a faculty/student picks at upload time. Stored as a
/// Drive `appProperties` value on the file itself (small, private,
/// per-file key/value metadata — not visible in Drive's UI), so no
/// separate database is needed to remember who a file is meant for.
enum MaterialVisibility { everyone, facultyOnly }

extension MaterialVisibilityX on MaterialVisibility {
  String get storageValue =>
      this == MaterialVisibility.facultyOnly ? 'faculty_only' : 'everyone';

  String get label => this == MaterialVisibility.facultyOnly
      ? 'Faculty only'
      : 'Everyone (Students & Faculty)';

  static MaterialVisibility fromStorage(String? value) =>
      value == 'faculty_only'
          ? MaterialVisibility.facultyOnly
          : MaterialVisibility.everyone;
}

/// A single file entry as returned by Drive — used purely for display in
/// the Study Materials screen. Not persisted anywhere ourselves: the
/// shared Drive folder itself is the source of truth, queried live every
/// time the screen opens, so every signed-in user (faculty or student)
/// sees the same up-to-date list without needing our own sync layer.
class DriveFileInfo {
  final String id;
  final String name;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime? createdOn;
  final String? uploaderName;
  final String webViewLink;
  final MaterialVisibility visibility;

  DriveFileInfo({
    required this.id,
    required this.name,
    required this.webViewLink,
    this.mimeType,
    this.sizeBytes,
    this.createdOn,
    this.uploaderName,
    this.visibility = MaterialVisibility.everyone,
  });
}

/// Two responsibilities:
///   1. App data sync (existing) — a hidden per-account JSON file via the
///      `drive.appdata` scope. See save()/load() below.
///   2. Study Materials (new) — real file upload/download/share against
///      ONE shared Drive folder that faculty + students all have access
///      to, via the broader `drive` scope. See uploadFile / listFiles /
///      downloadFile / copyToMyDrive below.
///
/// The shared folder itself is NOT created by this app — see
/// StudyMaterialsConfig in env_keys.dart for how to set it up and where
/// its folder ID goes.
class GoogleDriveService {
  static const _appDataFileName = 'campus_assistant_data.json';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveAppdataScope,
      // Full Drive access — needed to list/upload into a shared folder
      // this app didn't create itself. drive.file scope alone only
      // covers files the app created, which isn't enough for a folder
      // shared in from outside the app.
      drive.DriveApi.driveScope,
    ],
  );

  GoogleSignInAccount? _account;

  bool get isSignedIn => _account != null;
  String? get signedInEmail => _account?.email;

  /// Tries silent sign-in first (an existing session, no UI shown);
  /// falls back to the interactive Google account picker if needed.
  Future<bool> signIn({bool interactive = true}) async {
    _account = await _googleSignIn.signInSilently();
    _account ??= interactive ? await _googleSignIn.signIn() : null;
    return _account != null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
  }

  Future<drive.DriveApi> _driveApi() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Not signed in to Google — call signIn() first.');
    }
    return drive.DriveApi(client);
  }

  // -----------------------------------------------------------------
  // App data sync (unchanged from before)
  // -----------------------------------------------------------------

  Future<void> save(String jsonContent) async {
    final api = await _driveApi();
    final bytes = Uint8List.fromList(utf8.encode(jsonContent));
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existingId = await _findAppDataFileId(api);
    if (existingId == null) {
      final file = drive.File()
        ..name = _appDataFileName
        ..parents = ['appDataFolder'];
      await api.files.create(file, uploadMedia: media);
    } else {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    }
  }

  Future<String?> load() async {
    final api = await _driveApi();
    final fileId = await _findAppDataFileId(api);
    if (fileId == null) return null;
    final bytes = await _downloadBytes(api, fileId);
    return utf8.decode(bytes);
  }

  Future<String?> _findAppDataFileId(drive.DriveApi api) async {
    final result = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_appDataFileName'",
      $fields: 'files(id, name)',
    );
    if (result.files == null || result.files!.isEmpty) return null;
    return result.files!.first.id;
  }

  // -----------------------------------------------------------------
  // Study Materials — shared folder file operations
  // -----------------------------------------------------------------

  /// Lists every file in the shared materials folder, newest first.
  /// This IS the source of truth for the Study Materials screen — no
  /// local caching, so faculty and student uploads both show up for
  /// everyone immediately.
  Future<List<DriveFileInfo>> listFilesInFolder(String folderId) async {
    final api = await _driveApi();
    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      $fields:
          'files(id, name, mimeType, size, createdTime, webViewLink, owners, appProperties)',
    );
    return (result.files ?? []).map((f) {
      return DriveFileInfo(
        id: f.id!,
        name: f.name ?? 'Untitled',
        mimeType: f.mimeType,
        sizeBytes: f.size != null ? int.tryParse(f.size!) : null,
        createdOn: f.createdTime,
        uploaderName: f.owners != null && f.owners!.isNotEmpty
            ? f.owners!.first.displayName
            : null,
        webViewLink:
            f.webViewLink ?? 'https://drive.google.com/file/d/${f.id}/view',
        visibility:
            MaterialVisibilityX.fromStorage(f.appProperties?['visibility']),
      );
    }).toList();
  }

  /// Uploads a local file (e.g. picked via file_picker) into the shared
  /// materials folder. Used by both faculty (syllabus/material) and
  /// students (their own materials/event brochures) — same folder, same
  /// method, per the feature spec.
  Future<DriveFileInfo> uploadFile({
    required String folderId,
    required File localFile,
    required String fileName,
    String mimeType = 'application/octet-stream',
    MaterialVisibility visibility = MaterialVisibility.everyone,
  }) async {
    final api = await _driveApi();
    final bytes = await localFile.readAsBytes();
    final media =
        drive.Media(Stream.value(bytes), bytes.length, contentType: mimeType);

    final metadata = drive.File()
      ..name = fileName
      ..parents = [folderId]
      // File Share Option chosen at upload time. Read back on list() so
      // the Student screen can filter "Faculty only" materials out —
      // enforced app-side on every read, not just at upload.
      ..appProperties = {'visibility': visibility.storageValue};

    final created = await api.files.create(
      metadata,
      uploadMedia: media,
      $fields:
          'id, name, mimeType, size, createdTime, webViewLink, owners, appProperties',
    );

    return DriveFileInfo(
      id: created.id!,
      name: created.name ?? fileName,
      mimeType: created.mimeType,
      sizeBytes: bytes.length,
      createdOn: created.createdTime,
      uploaderName: created.owners != null && created.owners!.isNotEmpty
          ? created.owners!.first.displayName
          : signedInEmail,
      webViewLink: created.webViewLink ??
          'https://drive.google.com/file/d/${created.id}/view',
      visibility: visibility,
    );
  }

  /// Downloads a file's bytes and writes them to [savePath] on the
  /// device (e.g. the Downloads folder — see study_materials_screen.dart
  /// for how that path is resolved via path_provider).
  Future<void> downloadFile(
      {required String fileId, required String savePath}) async {
    final api = await _driveApi();
    final bytes = await _downloadBytes(api, fileId);
    await File(savePath).writeAsBytes(bytes);
  }

  /// "Save to Drive" — copies a file from the shared folder directly
  /// into the signed-in user's own My Drive (root), so they get their
  /// own permanent copy without downloading+re-uploading manually.
  Future<void> copyToMyDrive(
      {required String fileId, required String fileName}) async {
    final api = await _driveApi();
    final copy = drive.File()
      ..name = fileName; // no parents = lands in My Drive root
    await api.files.copy(copy, fileId);
  }

  Future<List<int>> _downloadBytes(drive.DriveApi api, String fileId) async {
    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    return media.stream.fold<List<int>>(
      <int>[],
      (previous, chunk) => previous..addAll(chunk),
    );
  }

  Future<String> createSosFolder(String userId, DateTime timestamp) async {
    final api = await _driveApi();
    
    // First, ensure SOS_Alerts folder exists in the shared folder
    final alertsFolderId = await _getOrCreateFolder(api, 'SOS_Alerts', EnvKeys.studyMaterialsFolderId);
    
    // Then create the specific user's folder
    final timeStr = timestamp.toIso8601String().replaceAll(':', '-').split('.').first;
    final folderName = '${userId}_$timeStr';
    
    return await _getOrCreateFolder(api, folderName, alertsFolderId);
  }

  Future<String> _getOrCreateFolder(drive.DriveApi api, String folderName, String parentId) async {
    final result = await api.files.list(
      q: "name = '$folderName' and '$parentId' in parents and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id)',
    );
    
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }
    
    final metadata = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];
      
    final created = await api.files.create(metadata, $fields: 'id');
    return created.id!;
  }

  /// Uploads a photo to the user's Drive and makes it publicly viewable.
  /// Returns a direct image URL that can be used in Image.network().
  Future<String?> uploadPublicPhoto(File localFile, String fileName, {String? folderId}) async {
    int retries = 3;
    while (retries > 0) {
      try {
        final api = await _driveApi();
        final bytes = await localFile.readAsBytes();
        final media = drive.Media(Stream.value(bytes), bytes.length, contentType: 'image/jpeg');

        final metadata = drive.File()
          ..name = fileName
          ..parents = [folderId ?? EnvKeys.studyMaterialsFolderId];

        final created = await api.files.create(
          metadata,
          uploadMedia: media,
          $fields: 'id',
        );

        if (created.id != null) {
          // Set permission so anyone with the link can view
          final permission = drive.Permission()
            ..type = 'anyone'
            ..role = 'reader';
          await api.permissions.create(permission, created.id!);

          // Return a direct link suitable for Image.network()
          return 'https://drive.google.com/uc?export=view&id=${created.id}';
        }
        return null;
      } catch (e) {
        retries--;
        if (retries == 0) return null;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }
}
