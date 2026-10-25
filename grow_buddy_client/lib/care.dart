import 'format.dart';
import 'models.dart';

/// Care schedule for a plant the user is growing. The numbers come from the plant's guide
/// unless the user overrode the watering interval.
extension PlantCare on MyPlant {
  int? wateringInterval(PlantGuide? g) => waterEveryDays ?? g?.waterEveryDays;

  /// Null once sold, or if the guide is unknown and no interval was set.
  WateringStatus? watering(PlantGuide? g, String today) {
    final every = wateringInterval(g);
    if (status == 'sold' || every == null) return null;
    return wateringStatus(lastWatered ?? plantedOn.substring(0, 10), every, today);
  }

  /// Only while still growing; once marked ready or sold the estimate no longer matters.
  ReadyEstimate? readyIn(PlantGuide? g, String today) {
    if (status != 'growing' || g == null) return null;
    return readyEstimate(plantedOn.substring(0, 10), g.daysToSellMin, g.daysToSellMax, today);
  }
}

/// Short badge text for the My plants list.
String waterBadge(WateringStatus w) => switch (w.state) {
      WaterState.overdue => 'Overdue ${-w.daysUntil}d',
      WaterState.today => 'Water today',
      WaterState.ok => 'Water in ${w.daysUntil}d',
    };

/// Longer text for the plant detail page.
String waterSentence(WateringStatus w) => switch (w.state) {
      WaterState.overdue =>
        '${-w.daysUntil} ${-w.daysUntil == 1 ? 'day' : 'days'} overdue (was due ${shortDate(w.dueOn)})',
      WaterState.today => 'Due today',
      WaterState.ok => 'In ${w.daysUntil} ${w.daysUntil == 1 ? 'day' : 'days'} (${shortDate(w.dueOn)})',
    };

String readyLabel(ReadyEstimate r) => switch (r.phase) {
      ReadyPhase.notYet => 'Ready ~${shortDate(r.earliest)} to ${shortDate(r.latest)}',
      ReadyPhase.window => 'Could be ready now (usually by ${shortDate(r.latest)})',
      ReadyPhase.late => 'Past the usual time. Check if it is ready or stuck.',
    };
