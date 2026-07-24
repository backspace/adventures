import 'package:latlong2/latlong.dart';
import 'package:landgrab/models/liberation_status.dart';
import 'package:landgrab/models/pole.dart' show PuzzletRegion;

/// One pole+puzzlet a team is actively working (a `team_puzzlets` row), as the
/// supervisor board sees it.
class ActiveWork {
  final String? poleId;
  final String? poleLabel;
  final String? poleBarcode;
  final double? poleLat;
  final double? poleLng;
  final String? poleStatus;
  final String? puzzletId;
  final int? puzzletDifficulty;
  final String? puzzletInstructions;
  final String? puzzletAnswer;
  final PuzzletRegion? region;
  final double? puzzletLat;
  final double? puzzletLng;

  ActiveWork({
    this.poleId,
    this.poleLabel,
    this.poleBarcode,
    this.poleLat,
    this.poleLng,
    this.poleStatus,
    this.puzzletId,
    this.puzzletDifficulty,
    this.puzzletInstructions,
    this.puzzletAnswer,
    this.region,
    this.puzzletLat,
    this.puzzletLng,
  });

  /// The pole's map position, if it has coordinates. Poles require coords
  /// server-side, so this is normally non-null.
  LatLng? get polePosition =>
      (poleLat != null && poleLng != null) ? LatLng(poleLat!, poleLng!) : null;

  /// A short human label for the pole — its author label, else its barcode.
  String get poleDisplay {
    final l = poleLabel?.trim();
    if (l != null && l.isNotEmpty) return l;
    final b = poleBarcode?.trim();
    if (b != null && b.isNotEmpty) return b;
    return 'pole';
  }

  factory ActiveWork.fromJson(Map<String, dynamic> json) {
    final pole = (json['pole'] as Map?)?.cast<String, dynamic>();
    final puzzlet = (json['puzzlet'] as Map?)?.cast<String, dynamic>();
    double? d(dynamic v) => (v as num?)?.toDouble();
    final region = (puzzlet?['region'] as Map?)?.cast<String, dynamic>();
    return ActiveWork(
      poleId: pole?['id'] as String?,
      poleLabel: pole?['label'] as String?,
      poleLat: d(pole?['latitude']),
      poleLng: d(pole?['longitude']),
      poleStatus: pole?['status'] as String?,
      poleBarcode: pole?['barcode'] as String?,
      puzzletId: puzzlet?['id'] as String?,
      puzzletDifficulty: (puzzlet?['difficulty'] as num?)?.toInt(),
      puzzletInstructions: puzzlet?['instructions'] as String?,
      puzzletAnswer: puzzlet?['answer'] as String?,
      region: region == null ? null : PuzzletRegion.fromJson(region),
      puzzletLat: d(puzzlet?['latitude']),
      puzzletLng: d(puzzlet?['longitude']),
    );
  }
}

/// The last pole a team claimed (captured or took by accommodation) — the
/// stale anchor an idle team is stranded on.
class ClaimedPole {
  final String id;
  final String? label;
  final String? barcode;
  final double? lat;
  final double? lng;
  final DateTime? at;

  ClaimedPole(
      {required this.id, this.label, this.barcode, this.lat, this.lng, this.at});

  LatLng? get position =>
      (lat != null && lng != null) ? LatLng(lat!, lng!) : null;

  String get display {
    final l = label?.trim();
    if (l != null && l.isNotEmpty) return l;
    final b = barcode?.trim();
    if (b != null && b.isNotEmpty) return b;
    return 'pole';
  }

  factory ClaimedPole.fromJson(Map<String, dynamic> json) => ClaimedPole(
        id: '${json['id']}',
        label: json['label'] as String?,
        barcode: json['barcode'] as String?,
        lat: (json['latitude'] as num?)?.toDouble(),
        lng: (json['longitude'] as num?)?.toDouble(),
        at: json['at'] == null ? null : DateTime.tryParse('${json['at']}'),
      );
}

/// A team on the supervisor board: its roster, the work it's currently on, and
/// (for idle teams) the last stake it held.
class BoardTeam {
  final String id;
  final String name;
  final List<LiberationMember> members;
  final List<ActiveWork> active;
  final ClaimedPole? lastClaimed;

  BoardTeam({
    required this.id,
    required this.name,
    this.members = const [],
    this.active = const [],
    this.lastClaimed,
  });

  bool get isIdle => active.isEmpty;

  factory BoardTeam.fromJson(Map<String, dynamic> json) => BoardTeam(
        id: '${json['id']}',
        name: '${json['name']}',
        members: ((json['members'] as List?) ?? const [])
            .map((m) => LiberationMember.fromJson(m as Map<String, dynamic>))
            .toList(),
        active: ((json['active'] as List?) ?? const [])
            .map((w) => ActiveWork.fromJson(w as Map<String, dynamic>))
            .toList(),
        lastClaimed: json['last_claimed'] == null
            ? null
            : ClaimedPole.fromJson(
                (json['last_claimed'] as Map).cast<String, dynamic>()),
      );
}

/// The whole board: every team with members, split by the UI into those
/// working a puzzlet and those idle.
class TeamBoard {
  final List<BoardTeam> teams;

  TeamBoard({this.teams = const []});

  List<BoardTeam> get activeTeams =>
      teams.where((t) => !t.isIdle).toList(growable: false);
  List<BoardTeam> get idleTeams =>
      teams.where((t) => t.isIdle).toList(growable: false);

  factory TeamBoard.fromJson(Map<String, dynamic> json) => TeamBoard(
        teams: ((json['teams'] as List?) ?? const [])
            .map((t) => BoardTeam.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
