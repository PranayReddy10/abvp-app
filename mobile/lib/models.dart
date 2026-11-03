class OrgUnit {
  OrgUnit({required this.id, required this.name, required this.type, this.childrenCount = 0});
  final int id;
  final String name;
  final String type;
  final int childrenCount;

  factory OrgUnit.fromJson(Map<String, dynamic> j) => OrgUnit(
        id: j['id'] as int,
        name: j['name'] as String,
        type: j['type'] as String,
        childrenCount: (j['children_count'] as int?) ?? 0,
      );
}

class Vibhag {
  Vibhag({required this.id, required this.name, required this.code});
  final int id;
  final String name;
  final String code;

  factory Vibhag.fromJson(Map<String, dynamic> j) =>
      Vibhag(id: j['id'] as int, name: j['name'] as String, code: j['code'] as String);
}

class Responsibility {
  Responsibility({required this.title, this.place, required this.startsOn, this.endsOn});
  final String title;
  final String? place;
  final String startsOn;
  final String? endsOn;

  String get years => '${startsOn.substring(0, 4)}–${endsOn?.substring(0, 4) ?? ''}';

  factory Responsibility.fromJson(Map<String, dynamic> j) => Responsibility(
        title: j['title'] as String,
        place: (j['org_unit'] as Map<String, dynamic>?)?['name'] as String?,
        startsOn: j['starts_on'] as String,
        endsOn: j['ends_on'] as String?,
      );
}

class Profile {
  Profile(this.json);
  final Map<String, dynamic> json;

  String? get memberId => json['member_id'] as String?;
  String get fullName => json['full_name'] as String? ?? '';
  String? get gender => json['gender'] as String?;
  String? get dateOfBirth => json['date_of_birth'] as String?;
  String? get photoUrl => json['photo_url'] as String?;
  String? get institution => json['institution'] as String?;
  String? get course => json['course'] as String?;
  String? get studyYear => json['study_year'] as String?;
  String? get bio => json['bio'] as String?;
  String get status => json['membership_status'] as String? ?? 'draft';
  int? get orgUnitId => (json['org_unit'] as Map<String, dynamic>?)?['id'] as int?;
  String? get orgUnitLabel => (json['org_unit'] as Map<String, dynamic>?)?['label'] as String?;
  List<String> get skills => List<String>.from(json['skills'] as List? ?? []);
  List<String> get languages => List<String>.from(json['languages'] as List? ?? []);
  Map<String, String> get privacy => Map<String, String>.from(json['privacy'] as Map? ?? {});
  List<Vibhag> get vibhags =>
      (json['vibhags'] as List? ?? []).map((v) => Vibhag.fromJson(v as Map<String, dynamic>)).toList();
  List<Responsibility> get responsibilities => (json['responsibilities'] as List? ?? [])
      .map((r) => Responsibility.fromJson(r as Map<String, dynamic>))
      .toList();
}

class HistoryItem {
  HistoryItem({required this.action, this.note, required this.at});
  final String action;
  final String? note;
  final DateTime at;
}

class Application {
  Application(this.json);
  final Map<String, dynamic> json;

  String get status => json['status'] as String;
  String? get decisionNote => json['decision_note'] as String?;
  String? get reviewingOffice => json['reviewing_office'] as String?;
  List<HistoryItem> get history => (json['history'] as List? ?? [])
      .map((h) => HistoryItem(
            action: h['action'] as String,
            note: h['note'] as String?,
            at: DateTime.parse(h['at'] as String).toLocal(),
          ))
      .toList();
}

class Me {
  Me(this.json);
  final Map<String, dynamic> json;

  String get mobile => json['mobile'] as String;
  String? get name => json['name'] as String?;
  Profile? get profile => json['profile'] == null ? null : Profile(json['profile'] as Map<String, dynamic>);
  Application? get application =>
      json['application'] == null ? null : Application(json['application'] as Map<String, dynamic>);
  bool get isMember => profile?.status == 'approved';
}
