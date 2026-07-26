import 'package:landgrab/api/landgrab_api.dart';
import 'package:landgrab/models/draft.dart';
import 'package:landgrab/models/region.dart';
import 'package:landgrab/viewer/viewer_dataset.dart';

/// Builds a [ViewerDataset] from the supervisor content endpoints.
///
/// The app, signed in as a supervisor/author (the "bootstrap" machine), is the
/// only party that can read instructions + answers in bulk — players never do —
/// so this is where the browsable dataset is minted, before it's handed out
/// device-to-device as an encrypted bundle. No dedicated endpoint is needed:
/// it composes the existing `/supervision/poles`, `/supervision/puzzlets` and
/// `/regions` responses, which already carry the full content.
class ViewerExport {
  /// Fetch everything and assemble. [status] narrows poles/puzzlets (e.g.
  /// 'validated'); null pulls everything the supervisor can see.
  static Future<ViewerDataset> fetch(LandgrabApi api, {String? status}) async {
    final poles = await api.supervisionListPoles(status: status);
    final puzzlets = await api.supervisionListPuzzlets(status: status);
    final regions = await api.searchRegions();
    return build(poles: poles, puzzlets: puzzlets, regions: regions);
  }

  /// Pure mapping from the app's supervisor models to the transport dataset —
  /// separated out so it's testable without a live API.
  static ViewerDataset build({
    required List<DraftPole> poles,
    required List<DraftPuzzlet> puzzlets,
    required List<Region> regions,
  }) =>
      ViewerDataset(
        poles: poles.map(poleToViewer).toList(growable: false),
        regions: regions.map(regionToViewer).toList(growable: false),
        puzzlets: puzzlets.map(puzzletToViewer).toList(growable: false),
      );

  static ViewerPole poleToViewer(DraftPole p) => ViewerPole(
        id: p.id,
        // Poles carry a human label; fall back to the id so a nameless stake
        // still renders as *something* rather than a blank.
        name: (p.label != null && p.label!.trim().isNotEmpty) ? p.label! : p.id,
        latitude: p.latitude,
        longitude: p.longitude,
        accessibilityTags: p.accessibilityTags,
        accessibilityNotes: p.accessibilityNotes,
      );

  static ViewerRegion regionToViewer(Region r) => ViewerRegion(
        id: r.id,
        name: r.name,
        parentRegionId: r.parentRegionId,
        entryInstructions: r.entryInstructions,
        accessibilityTags: r.accessibilityTags,
        accessibilityNotes: r.accessibilityNotes,
      );

  static ViewerPuzzlet puzzletToViewer(DraftPuzzlet p) => ViewerPuzzlet(
        id: p.id,
        poleId: p.poleId,
        // Prefer the explicit region_id; fall back to the embedded summary.
        regionId: p.regionId ?? p.region?.id,
        instructions: p.instructions,
        answer: p.answer,
        answerType: answerTypeToString(p.answerType),
        difficulty: p.difficulty,
      );
}
