import '../config/constants.dart';

class AppUser {
  final String id;
  final String name;
  final UserRole role;
  final String? department;

  AppUser({
    required this.id,
    required this.name,
    required this.role,
    this.department,
  });
}

class TimetableSlot {
  final String day; // e.g. Monday
  final String hour; // e.g. "9:00 - 10:00"
  final String subject;
  final String faculty;
  final String room;

  TimetableSlot({
    required this.day,
    required this.hour,
    required this.subject,
    required this.faculty,
    required this.room,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'hour': hour,
        'subject': subject,
        'faculty': faculty,
        'room': room,
      };

  factory TimetableSlot.fromJson(Map<String, dynamic> j) => TimetableSlot(
        day: j['day'] as String,
        hour: j['hour'] as String,
        subject: j['subject'] as String,
        faculty: j['faculty'] as String,
        room: j['room'] as String,
      );
}

class AttendanceRecord {
  final String studentId;
  final DateTime date;
  final bool present;
  final String subject;

  AttendanceRecord({
    required this.studentId,
    required this.date,
    required this.present,
    required this.subject,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'date': date.toIso8601String(),
        'present': present,
        'subject': subject,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        studentId: j['studentId'] as String,
        date: DateTime.parse(j['date'] as String),
        present: j['present'] as bool,
        subject: j['subject'] as String,
      );
}

class AssignmentItem {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final String postedBy;
  bool submitted;

  AssignmentItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.postedBy,
    this.submitted = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'dueDate': dueDate.toIso8601String(),
        'postedBy': postedBy,
        'submitted': submitted,
      };

  factory AssignmentItem.fromJson(Map<String, dynamic> j) => AssignmentItem(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String,
        dueDate: DateTime.parse(j['dueDate'] as String),
        postedBy: j['postedBy'] as String,
        submitted: j['submitted'] as bool? ?? false,
      );
}

class MaterialItem {
  final String id;
  final String title;
  final String subject;
  final String fileName;
  final DateTime postedOn;

  MaterialItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.fileName,
    required this.postedOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'fileName': fileName,
        'postedOn': postedOn.toIso8601String(),
      };

  factory MaterialItem.fromJson(Map<String, dynamic> j) => MaterialItem(
        id: j['id'] as String,
        title: j['title'] as String,
        subject: j['subject'] as String,
        fileName: j['fileName'] as String,
        postedOn: DateTime.parse(j['postedOn'] as String),
      );
}

class FeeStatus {
  final String studentId;
  bool paid;
  final double amountDue;
  final DateTime? reminderSentOn;

  FeeStatus({
    required this.studentId,
    required this.paid,
    required this.amountDue,
    this.reminderSentOn,
  });

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'paid': paid,
        'amountDue': amountDue,
        'reminderSentOn': reminderSentOn?.toIso8601String(),
      };

  factory FeeStatus.fromJson(Map<String, dynamic> j) => FeeStatus(
        studentId: j['studentId'] as String,
        paid: j['paid'] as bool,
        amountDue: (j['amountDue'] as num).toDouble(),
        reminderSentOn: j['reminderSentOn'] == null
            ? null
            : DateTime.parse(j['reminderSentOn'] as String),
      );
}

class CampusEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String venue;

  CampusEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.venue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'venue': venue,
      };

  factory CampusEvent.fromJson(Map<String, dynamic> j) => CampusEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        date: DateTime.parse(j['date'] as String),
        venue: j['venue'] as String,
      );
}

class NoticeItem {
  final String id;
  final String title;
  final String body;
  final String postedBy;
  final String scope; // "global" or a department name
  final DateTime postedOn;

  NoticeItem({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    required this.scope,
    required this.postedOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'postedBy': postedBy,
        'scope': scope,
        'postedOn': postedOn.toIso8601String(),
      };

  factory NoticeItem.fromJson(Map<String, dynamic> j) => NoticeItem(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        postedBy: j['postedBy'] as String,
        scope: j['scope'] as String,
        postedOn: DateTime.parse(j['postedOn'] as String),
      );
}

class ChatMessage {
  final String text;
  final bool fromUser;
  final DateTime time;

  ChatMessage({required this.text, required this.fromUser, required this.time});

  // Chat history is intentionally NOT persisted (see CampusDataService) —
  // it's conversational/session data, not one of the stored record types
  // (timetables, events, locations, student details, attendance) that
  // need to survive an app restart. toJson/fromJson kept minimal in case
  // that changes later.
  Map<String, dynamic> toJson() => {
        'text': text,
        'fromUser': fromUser,
        'time': time.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        text: j['text'] as String,
        fromUser: j['fromUser'] as bool,
        time: DateTime.parse(j['time'] as String),
      );
}

class VenueLocation {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String block;

  VenueLocation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.block,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lng': lng,
        'block': block,
      };

  factory VenueLocation.fromJson(Map<String, dynamic> j) => VenueLocation(
        id: j['id'] as String,
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        block: j['block'] as String,
      );
}

enum HazardLevel { safe, careful, hazardous }

class ChemicalInfo {
  final String name;
  final String formula;
  final HazardLevel hazard;
  final String usage;
  final String firstAid;

  ChemicalInfo({
    required this.name,
    required this.formula,
    required this.hazard,
    required this.usage,
    required this.firstAid,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'formula': formula,
        'hazard': hazard.name,
        'usage': usage,
        'firstAid': firstAid,
      };

  factory ChemicalInfo.fromJson(Map<String, dynamic> j) => ChemicalInfo(
        name: j['name'] as String,
        formula: j['formula'] as String,
        hazard: HazardLevel.values.byName(j['hazard'] as String),
        usage: j['usage'] as String,
        firstAid: j['firstAid'] as String,
      );
}

class StudentProfile {
  final String
      rollNumber; // unique identifier used across attendance/notifications
  final String name;
  final String year; // e.g. "3rd Year"
  final String department;
  final String studentMobile;
  final String parentMobile;

  StudentProfile({
    required this.rollNumber,
    required this.name,
    required this.year,
    required this.department,
    required this.studentMobile,
    required this.parentMobile,
  });

  Map<String, dynamic> toJson() => {
        'rollNumber': rollNumber,
        'name': name,
        'year': year,
        'department': department,
        'studentMobile': studentMobile,
        'parentMobile': parentMobile,
      };

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        rollNumber: j['rollNumber'] as String,
        name: j['name'] as String,
        year: j['year'] as String,
        department: j['department'] as String,
        studentMobile: j['studentMobile'] as String,
        parentMobile: j['parentMobile'] as String,
      );
}

class NotificationLog {
  final String id;
  final String recipient; // e.g. "Student — 98765xxxxx"
  final String message;
  final DateTime sentOn;

  NotificationLog({
    required this.id,
    required this.recipient,
    required this.message,
    required this.sentOn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient': recipient,
        'message': message,
        'sentOn': sentOn.toIso8601String(),
      };

  factory NotificationLog.fromJson(Map<String, dynamic> j) => NotificationLog(
        id: j['id'] as String,
        recipient: j['recipient'] as String,
        message: j['message'] as String,
        sentOn: DateTime.parse(j['sentOn'] as String),
      );
}

class GeoPoint {
  final double lat;
  final double lng;

  GeoPoint({required this.lat, required this.lng});

  Map<String, dynamic> toJson() => {
        'type': 'Point',
        'coordinates': [lng, lat], // GeoJSON format: [longitude, latitude]
      };

  factory GeoPoint.fromJson(Map<String, dynamic> j) {
    final coords = j['coordinates'] as List;
    return GeoPoint(
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
    );
  }
}

enum IncidentStatus { triggered, inProgress, resolved }

class Incident {
  final String id;
  final String userId;
  final GeoPoint location;
  final DateTime timestamp;
  final IncidentStatus status;
  final List<String> photoUrls;
  
  final String? matchedVenueId;
  final String? routedToFacultyId;
  final String? routedToLabel;
  final DateTime? acknowledgedAt;
  final int? etaMinutes;

  Incident({
    required this.id,
    required this.userId,
    required this.location,
    required this.timestamp,
    required this.status,
    this.photoUrls = const [],
    this.matchedVenueId,
    this.routedToFacultyId,
    this.routedToLabel,
    this.acknowledgedAt,
    this.etaMinutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'location': location.toJson(),
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'photoUrls': photoUrls,
        'matchedVenueId': matchedVenueId,
        'routedToFacultyId': routedToFacultyId,
        'routedToLabel': routedToLabel,
        'acknowledgedAt': acknowledgedAt?.toIso8601String(),
        'etaMinutes': etaMinutes,
      };

  factory Incident.fromJson(Map<String, dynamic> j) => Incident(
        id: j['id'] as String,
        userId: j['userId'] as String,
        location: GeoPoint.fromJson(j['location'] as Map<String, dynamic>),
        timestamp: DateTime.parse(j['timestamp'] as String),
        status: IncidentStatus.values.byName(j['status'] as String),
        photoUrls: (j['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
        matchedVenueId: j['matchedVenueId'] as String?,
        routedToFacultyId: j['routedToFacultyId'] as String?,
        routedToLabel: j['routedToLabel'] as String?,
        acknowledgedAt: j['acknowledgedAt'] == null ? null : DateTime.parse(j['acknowledgedAt'] as String),
        etaMinutes: j['etaMinutes'] as int?,
      );
}
