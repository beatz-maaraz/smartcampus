import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/constants.dart';
import '../models/models.dart';
import 'google_drive_service.dart';

/// Single shared data layer for the whole app.
///
/// This is written as an in-memory ChangeNotifier so the whole prototype
/// runs standalone (no Firebase project required to demo it). Every method
/// below is a drop-in point for the matching cloud_firestore call — e.g.
/// swap `_attendance.add(...)` for
/// `FirebaseFirestore.instance.collection('attendance').add({...})`.
///
/// Keeping ALL cross-role data in one provider is what makes §5 of the
/// Application Flow doc work: Faculty writes here, notifyListeners() fires,
/// and every widget listening (Student dashboard, Admin dashboard) rebuilds
/// with the new value automatically — same effect cloud_firestore's realtime
/// snapshots give you for free.
class CampusDataService extends ChangeNotifier {
  // ---------------------------------------------------------------------
  // PERSISTENCE — two layers:
  //   1. LOCAL (shared_preferences) — unconditional. Works with no
  //      account, no internet, no setup. This alone guarantees data
  //      survives closing/reopening the app, which is the actual
  //      requirement — Google sign-in is a bonus on top, not a
  //      dependency of it.
  //   2. GOOGLE DRIVE (google_drive_service.dart) — optional. Only
  //      active once the user has signed in (needs the Cloud Console
  //      setup described earlier). Adds cross-device sync when present.
  // ---------------------------------------------------------------------
  static const _localStorageKey = 'campus_data_v1';

  final GoogleDriveService _drive = GoogleDriveService();
  bool _driveReady = false;

  bool get isSignedInToDrive => _drive.isSignedIn;
  String? get driveAccountEmail => _drive.signedInEmail;

  /// Call once at app startup (see main.dart).
  ///
  /// Order matters: local load happens FIRST and unconditionally, so the
  /// app always has last-saved data the instant it opens, regardless of
  /// network or Google sign-in status. Drive sign-in/load is then tried
  /// as a second, optional step — if the user has signed in before and
  /// Drive has newer data, it overlays on top of the local copy. If
  /// Drive isn't set up yet or fails (no internet, first run, setup not
  /// finished), the app carries on fine with just the local copy.
  Future<void> init() async {
    // ignore: avoid_print
    print('[Persistence] App starting — loading local data...');
    await _loadLocal();

    try {
      final signedIn = await _drive.signIn();
      if (signedIn) {
        final json = await _drive.load();
        if (json != null && json.trim().isNotEmpty) {
          _loadFromJson(jsonDecode(json) as Map<String, dynamic>);
        }
        _driveReady = true;
      }
    } catch (e) {
      // ignore: avoid_print
      print(
          '[Persistence] Google Drive init failed (local data still loaded fine): $e');
    }

    // ignore: avoid_print
    print('[Persistence] Startup complete — currently holding '
        '${_students.length} students, ${_attendance.length} attendance records.');
    notifyListeners();
  }

  /// Manually pulls the latest data from Drive (or Local) and updates the UI.
  Future<void> refresh() async {
    try {
      if (_driveReady) {
        final json = await _drive.load();
        if (json != null && json.trim().isNotEmpty) {
          _loadFromJson(jsonDecode(json) as Map<String, dynamic>);
        }
      } else {
        await _loadLocal();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Persistence] Refresh failed: $e');
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_localStorageKey);
      if (json == null || json.trim().isEmpty) {
        // ignore: avoid_print
        print(
            '[Persistence] No local save found yet (first run, or nothing saved before).');
        return;
      }
      _loadFromJson(jsonDecode(json) as Map<String, dynamic>);
      // ignore: avoid_print
      print('[Persistence] Loaded local save: ${json.length} characters.');
    } catch (e) {
      // ignore: avoid_print
      print('[Persistence] Local load FAILED: $e');
    }
  }

  /// Called after every mutation below. Local save is awaited-in-background
  /// but always attempted (this is the guarantee that data survives an
  /// app restart). Drive save layers on top only if signed in. Neither
  /// blocks the UI — notifyListeners() already fired before this runs.
  void _persist() {
    final encoded = jsonEncode(toJson());
    // ignore: avoid_print
    print(
        '[Persistence] _persist() called — attempting to save ${encoded.length} characters locally.');

    unawaited(SharedPreferences.getInstance().then((prefs) {
      return prefs.setString(_localStorageKey, encoded);
    }).then((success) {
      // ignore: avoid_print
      print(
          '[Persistence] Local save ${success ? 'SUCCEEDED' : 'FAILED (setString returned false)'}.');
    }).catchError((e) {
      // ignore: avoid_print
      print('[Persistence] Local save threw an ERROR: $e');
    }));

    if (_driveReady) {
      unawaited(_drive.save(encoded).catchError((e) {
        // ignore: avoid_print
        print('[CampusDataService] Google Drive save failed: $e');
      }));
    }
  }

  Map<String, dynamic> toJson() => {
        'attendance': _attendance.map((a) => a.toJson()).toList(),
        'timetable': _timetable.map((t) => t.toJson()).toList(),
        'assignments': _assignments.map((a) => a.toJson()).toList(),
        'materials': _materials.map((m) => m.toJson()).toList(),
        'fees': _fees.map((k, v) => MapEntry(k, v.toJson())),
        'events': _events.map((e) => e.toJson()).toList(),
        'notices': _notices.map((n) => n.toJson()).toList(),
        'venues': _venues.map((v) => v.toJson()).toList(),
        'chemicals': _chemicalDb.map((k, v) => MapEntry(k, v.toJson())),
        'students': _students.map((s) => s.toJson()).toList(),
        'notifications': _notifications.map((n) => n.toJson()).toList(),
        'incidents': _incidents.map((i) => i.toJson()).toList(),
      };

  void _loadFromJson(Map<String, dynamic> j) {
    _incidents
      ..clear()
      ..addAll((j['incidents'] as List? ?? [])
          .map((e) => Incident.fromJson(e as Map<String, dynamic>)));
    _attendance
      ..clear()
      ..addAll((j['attendance'] as List? ?? [])
          .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)));
    _timetable
      ..clear()
      ..addAll((j['timetable'] as List? ?? [])
          .map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>)));
    _assignments
      ..clear()
      ..addAll((j['assignments'] as List? ?? [])
          .map((e) => AssignmentItem.fromJson(e as Map<String, dynamic>)));
    _materials
      ..clear()
      ..addAll((j['materials'] as List? ?? [])
          .map((e) => MaterialItem.fromJson(e as Map<String, dynamic>)));
    _fees
      ..clear()
      ..addAll((j['fees'] as Map? ?? {}).map((k, v) => MapEntry(
          k as String, FeeStatus.fromJson(v as Map<String, dynamic>))));
    _events
      ..clear()
      ..addAll((j['events'] as List? ?? [])
          .map((e) => CampusEvent.fromJson(e as Map<String, dynamic>)));
    _notices
      ..clear()
      ..addAll((j['notices'] as List? ?? [])
          .map((e) => NoticeItem.fromJson(e as Map<String, dynamic>)));
    _venues
      ..clear()
      ..addAll((j['venues'] as List? ?? [])
          .map((e) => VenueLocation.fromJson(e as Map<String, dynamic>)));
    _chemicalDb
      ..clear()
      ..addAll((j['chemicals'] as Map? ?? {}).map((k, v) => MapEntry(
          k as String, ChemicalInfo.fromJson(v as Map<String, dynamic>))));
    _students
      ..clear()
      ..addAll((j['students'] as List? ?? [])
          .map((e) => StudentProfile.fromJson(e as Map<String, dynamic>)));
    _notifications
      ..clear()
      ..addAll((j['notifications'] as List? ?? [])
          .map((e) => NotificationLog.fromJson(e as Map<String, dynamic>)));
  }

  // ---------------------------------------------------------------------
  // INCIDENTS  (SOS / Emergencies)
  // ---------------------------------------------------------------------
  final List<Incident> _incidents = [];
  List<Incident> get incidents => List.unmodifiable(_incidents);

  void addOrUpdateIncident(Incident incident) {
    final idx = _incidents.indexWhere((i) => i.id == incident.id);
    if (idx == -1) {
      _incidents.insert(0, incident); // Newest first
    } else {
      _incidents[idx] = incident;
    }
    notifyListeners();
    _persist();
  }

  Future<String?> createSosFolder(String userId, DateTime timestamp) async {
    if (!_driveReady) return null;
    return await _drive.createSosFolder(userId, timestamp);
  }

  Future<String?> uploadSOSPhoto(File localFile, String fileName, {String? folderId}) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      
      final Map<String, String> paramsToSign = {
        'timestamp': timestamp,
      };
      
      if (folderId != null) {
        paramsToSign['folder'] = folderId;
      }
      
      final sortedKeys = paramsToSign.keys.toList()..sort();
      final paramsString = sortedKeys.map((key) => '$key=${paramsToSign[key]}').join('&');
      final strToSign = '$paramsString${CloudinaryConfig.apiSecret}';
      final signature = sha1.convert(utf8.encode(strToSign)).toString();

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['api_key'] = CloudinaryConfig.apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..files.add(await http.MultipartFile.fromPath('file', localFile.path));
        
      if (folderId != null) {
        request.fields['folder'] = folderId; // Optionally organize in Cloudinary
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['secure_url']; // Return the direct image URL
      } else {
        debugPrint('Cloudinary upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // ATTENDANCE  (Faculty marks -> Student % recalculated, Admin global view)
  // ---------------------------------------------------------------------
  final List<AttendanceRecord> _attendance = [
    AttendanceRecord(
        studentId: 'student',
        date: DateTime.now().subtract(const Duration(days: 1)),
        present: true,
        subject: 'Data Structures'),
    AttendanceRecord(
        studentId: 'student',
        date: DateTime.now().subtract(const Duration(days: 2)),
        present: true,
        subject: 'DBMS'),
    AttendanceRecord(
        studentId: 'student',
        date: DateTime.now().subtract(const Duration(days: 3)),
        present: false,
        subject: 'OS'),
    AttendanceRecord(
        studentId: 'student',
        date: DateTime.now().subtract(const Duration(days: 4)),
        present: true,
        subject: 'Networks'),
  ];

  List<AttendanceRecord> attendanceFor(String studentId) =>
      _attendance.where((a) => a.studentId == studentId).toList();

  double attendancePercentFor(String studentId) {
    final recs = attendanceFor(studentId);
    if (recs.isEmpty) return 0;
    final present = recs.where((r) => r.present).length;
    return (present / recs.length) * 100;
  }

  /// Faculty action: Mark / Edit Daily Attendance (§4.2)
  void markAttendance({
    required String studentId,
    required String subject,
    required bool present,
  }) {
    _attendance.add(AttendanceRecord(
      studentId: studentId,
      date: DateTime.now(),
      present: present,
      subject: subject,
    ));
    notifyListeners();
    _persist(); // -> Student dashboard % recalculates immediately
  }

  /// Admin: global analytical attendance report (§6.1)
  Map<String, double> globalAttendanceReport() {
    final ids = _attendance.map((a) => a.studentId).toSet();
    return {for (final id in ids) id: attendancePercentFor(id)};
  }

  // ---------------------------------------------------------------------
  // TIMETABLE  (Admin creates master schedule, Faculty modifies own slot)
  // ---------------------------------------------------------------------
  final List<TimetableSlot> _timetable = [
    TimetableSlot(
        day: 'Monday',
        hour: '9:00-10:00',
        subject: 'Data Structures',
        faculty: 'Dr. Chandru',
        room: 'CSE-101'),
    TimetableSlot(
        day: 'Monday',
        hour: '10:00-11:00',
        subject: 'DBMS',
        faculty: 'Dr. Elavarasi',
        room: 'CSE-102'),
    TimetableSlot(
        day: 'Monday',
        hour: '11:15-12:15',
        subject: 'Operating Systems',
        faculty: 'Dr. Santhiya',
        room: 'CSE-103'),
    TimetableSlot(
        day: 'Tuesday',
        hour: '9:00-10:00',
        subject: 'Computer Networks',
        faculty: 'Dr. Chandru',
        room: 'CSE-101'),
  ];

  List<TimetableSlot> get fullTimetable => List.unmodifiable(_timetable);

  List<TimetableSlot> todaysTimetable() {
    final weekday = _weekdayName(DateTime.now().weekday);
    return _timetable.where((t) => t.day == weekday).toList();
  }

  List<TimetableSlot> timetableForFaculty(String facultyName) =>
      _timetable.where((t) => t.faculty == facultyName).toList();

  /// Faculty action: Modify Assigned Time Slot (§4.2)
  void modifySlot(TimetableSlot oldSlot, TimetableSlot newSlot) {
    final idx = _timetable.indexOf(oldSlot);
    if (idx != -1) _timetable[idx] = newSlot;
    notifyListeners();
    _persist();
  }

  /// Admin action: Edit Class Schedule / Create Full-Year Master Schedule (§6.1)
  void addOrUpdateMasterSlot(TimetableSlot slot) {
    _timetable.add(slot);
    notifyListeners();
    _persist();
  }

  String _weekdayName(int weekday) => const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][weekday - 1];

  // ---------------------------------------------------------------------
  // ASSIGNMENTS  (Faculty posts -> appears in Student list)
  // ---------------------------------------------------------------------
  final List<AssignmentItem> _assignments = [
    AssignmentItem(
        id: 'a1',
        title: 'B-Tree Implementation',
        subject: 'Data Structures',
        dueDate: DateTime.now().add(const Duration(days: 3)),
        postedBy: 'Dr. Chandru'),
    AssignmentItem(
        id: 'a2',
        title: 'Normalization Worksheet',
        subject: 'DBMS',
        dueDate: DateTime.now().add(const Duration(days: 5)),
        postedBy: 'Dr. Elavarasi'),
  ];

  List<AssignmentItem> get assignments => List.unmodifiable(_assignments);
  int get pendingAssignmentCount =>
      _assignments.where((a) => !a.submitted).length;

  /// Faculty action: Post Assignment (§4.2)
  void postAssignment(AssignmentItem item) {
    _assignments.add(item);
    notifyListeners();
    _persist();
  }

  void markAssignmentSubmitted(String id) {
    final a = _assignments.firstWhere((a) => a.id == id);
    a.submitted = true;
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // MATERIAL / SYLLABUS  (Faculty posts -> downloadable by Student)
  // ---------------------------------------------------------------------
  final List<MaterialItem> _materials = [
    MaterialItem(
        id: 'm1',
        title: 'Unit 3 - Trees & Graphs',
        subject: 'Data Structures',
        fileName: 'unit3_trees_graphs.pdf',
        postedOn: DateTime.now().subtract(const Duration(days: 2))),
  ];

  List<MaterialItem> get materials => List.unmodifiable(_materials);

  /// Faculty action: Post Material / Syllabus (§4.2)
  void postMaterial(MaterialItem item) {
    _materials.add(item);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // FEES  (Faculty marks/remarks -> Student sees notice + "SMS" reminder)
  // ---------------------------------------------------------------------
  final Map<String, FeeStatus> _fees = {
    'student': FeeStatus(studentId: 'student', paid: false, amountDue: 12500),
  };

  FeeStatus? feeStatusFor(String studentId) => _fees[studentId];

  /// Faculty action: Mark / Remark Fees Status (§4.2)
  /// NOTE: real SMS delivery needs an external gateway (flagged in §8.2 of
  /// the Application Flow doc). Here we just stamp `reminderSentOn` to
  /// represent "reminder dispatched" — swap in the SMS/push call for real use.
  void setFeeStatus(String studentId, {required bool paid, double? amountDue}) {
    final current = _fees[studentId];
    _fees[studentId] = FeeStatus(
      studentId: studentId,
      paid: paid,
      amountDue: amountDue ?? current?.amountDue ?? 0,
      reminderSentOn: paid ? null : DateTime.now(),
    );
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // EVENTS  (browsable by Student)
  // ---------------------------------------------------------------------
  final List<CampusEvent> _events = [
    CampusEvent(
        id: 'e1',
        title: 'Tech Symposium - Artemis 2026',
        description: 'Annual inter-college tech fest with project expo.',
        date: DateTime.now().add(const Duration(days: 10)),
        venue: 'Main Auditorium'),
    CampusEvent(
        id: 'e2',
        title: 'Hackathon Finals',
        description: 'Final round presentations and judging.',
        date: DateTime.now().add(const Duration(days: 2)),
        venue: 'Seminar Hall B'),
  ];

  List<CampusEvent> get events => List.unmodifiable(_events);

  // ---------------------------------------------------------------------
  // NOTICES  (Faculty: department-specific, Admin: campus-wide broadcast)
  // ---------------------------------------------------------------------
  final List<NoticeItem> _notices = [
    NoticeItem(
        id: 'n1',
        title: 'Fee Payment Deadline Extended',
        body: 'Last date extended to next Friday.',
        postedBy: 'Admin Office',
        scope: 'global',
        postedOn: DateTime.now().subtract(const Duration(hours: 5))),
  ];

  List<NoticeItem> get notices => List.unmodifiable(_notices);

  /// Faculty action: Post Department-Specific Notice (§4.2)
  void postDepartmentNotice(NoticeItem item) {
    _notices.insert(0, item);
    notifyListeners();
    _persist();
  }

  /// Admin action: Write & Broadcast Notice to Entire Campus (§6.1)
  void broadcastNotice(NoticeItem item) {
    _notices.insert(0, item);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // VENUES / CAMPUS MAP  (Admin drops pins -> searchable in navigation)
  // ---------------------------------------------------------------------
  final List<VenueLocation> _venues = [
    VenueLocation(
        id: 'v1',
        name: 'Main Library',
        lat: 11.0168,
        lng: 76.9558,
        block: 'Block A'),
    VenueLocation(
        id: 'v2',
        name: 'Seminar Hall B',
        lat: 11.0170,
        lng: 76.9562,
        block: 'Block B'),
    VenueLocation(
        id: 'v3',
        name: 'Chemistry Lab',
        lat: 11.0172,
        lng: 76.9550,
        block: 'Block C'),
    VenueLocation(
        id: 'v4',
        name: 'Main Auditorium',
        lat: 11.0165,
        lng: 76.9545,
        block: 'Block A'),
  ];

  List<VenueLocation> get venues => List.unmodifiable(_venues);

  List<VenueLocation> searchVenues(String query) {
    if (query.trim().isEmpty) return venues;
    final q = query.toLowerCase();
    return _venues.where((v) => v.name.toLowerCase().contains(q)).toList();
  }

  /// Admin action: Drop New Location Pin / Edit Coordinate Data (§6.1)
  void addVenue(VenueLocation venue) {
    _venues.add(venue);
    notifyListeners();
    _persist();
  }

  // ---------------------------------------------------------------------
  // CHEMICAL HUB  (Admin manages restricted list / safety notes)
  // ---------------------------------------------------------------------
  final Map<String, ChemicalInfo> _chemicalDb = {
    'ethanol': ChemicalInfo(
      name: 'Ethanol',
      formula: 'C2H5OH',
      hazard: HazardLevel.careful,
      usage: 'Common solvent, used in extraction and cleaning glassware.',
      firstAid:
          'Flush skin/eyes with water for 15 min. If ingested, seek medical help immediately.',
    ),
    'hcl': ChemicalInfo(
      name: 'Hydrochloric Acid',
      formula: 'HCl',
      hazard: HazardLevel.hazardous,
      usage: 'Used in titrations and cleaning metal surfaces.',
      firstAid:
          'Corrosive — flush with water for 20 min, remove contaminated clothing, get medical help.',
    ),
    'water': ChemicalInfo(
      name: 'Water',
      formula: 'H2O',
      hazard: HazardLevel.safe,
      usage: 'Universal solvent, used for dilution and cleaning.',
      firstAid: 'Not hazardous.',
    ),
  };

  ChemicalInfo? lookupChemical(String name) =>
      _chemicalDb[name.trim().toLowerCase()];

  /// Admin action: Manage / Flag Chemical Safety Notes & Restricted List (§6.1)
  void upsertChemical(ChemicalInfo info) {
    _chemicalDb[info.name.trim().toLowerCase()] = info;
    notifyListeners();
    _persist();
  }

  List<ChemicalInfo> get restrictedChemicals => _chemicalDb.values
      .where((c) => c.hazard == HazardLevel.hazardous)
      .toList();

  // ---------------------------------------------------------------------
  // STUDENT MANAGEMENT  (Faculty inputs/views student records; daily
  // attendance marking automatically notifies the student + parent)
  // ---------------------------------------------------------------------
  final List<StudentProfile> _students = [
    StudentProfile(
        rollNumber: '21CS101',
        name: 'Arun Kumar',
        year: '3rd Year',
        department: 'CSE',
        studentMobile: '9876543210',
        parentMobile: '9876500000'),
    StudentProfile(
        rollNumber: '21CS102',
        name: 'Divya S',
        year: '3rd Year',
        department: 'CSE',
        studentMobile: '9876543211',
        parentMobile: '9876500001'),
  ];

  List<StudentProfile> get students => List.unmodifiable(_students);

  StudentProfile? studentByRollNumber(String rollNumber) {
    for (final s in _students) {
      if (s.rollNumber == rollNumber) return s;
    }
    return null;
  }

  /// Faculty action: Add / Update Student Record (§1 — name, year,
  /// department, roll number, student + parent mobile).
  void addOrUpdateStudent(StudentProfile profile) {
    final idx = _students.indexWhere((s) => s.rollNumber == profile.rollNumber);
    if (idx == -1) {
      _students.add(profile);
    } else {
      _students[idx] = profile;
    }
    notifyListeners();
    _persist();
  }

  /// Notification outbox — simulated in-app "sent messages" log so the
  /// automated notification feature is demoable without a real SMS/push
  /// gateway wired up yet. See _sendNotification below for the swap-in
  /// point, same pattern as the fee-reminder flow above.
  final List<NotificationLog> _notifications = [];

  List<NotificationLog> get notifications => List.unmodifiable(_notifications);

  /// Faculty action: Daily Attendance Marking (§2), tied to a specific
  /// student's roll number. Marking a student ABSENT automatically
  /// triggers §3 — a notification to both the student and their parent.
  void markDailyAttendance({
    required String rollNumber,
    required String subject,
    required bool present,
  }) {
    markAttendance(studentId: rollNumber, subject: subject, present: present);

    if (!present) {
      final student = studentByRollNumber(rollNumber);
      if (student != null) {
        final dateStr = DateTime.now().toLocal().toString().split(' ').first;
        final message =
            '${student.name} (${student.rollNumber}) was marked ABSENT for '
            '$subject on $dateStr.';
        _sendNotification(
            recipient: 'Student — ${student.studentMobile}', message: message);
        _sendNotification(
            recipient: 'Parent — ${student.parentMobile}', message: message);
      }
    }
  }

  /// NOTE: this only appends to the in-app outbox below. Swap this body
  /// for a real SMS/push gateway call (Twilio, Firebase Cloud Messaging,
  /// etc.) to actually deliver notifications — flagged the same way the
  /// fee-reminder flow above is.
  void _sendNotification({required String recipient, required String message}) {
    _notifications.insert(
      0,
      NotificationLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        recipient: recipient,
        message: message,
        sentOn: DateTime.now(),
      ),
    );
    notifyListeners();
    _persist();
  }
}
