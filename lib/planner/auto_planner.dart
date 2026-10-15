import 'dart:math' as math;
import 'dart:ui';

import '../geometry/collision_rules.dart';
import '../geometry/geometry.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import '../models/planning_settings.dart';

/// Ein nicht erfüllbarer Wunsch mit Begründung.
class UnplacedWish {
  const UnplacedWish({required this.typeId, required this.reason});
  final String typeId;
  final String reason;
  String get typeName => ElementCatalog.byId(typeId)?.name ?? typeId;
}

/// Ein Planungsvorschlag.
class PlanProposal {
  const PlanProposal({
    required this.label,
    required this.elements,
    required this.score,
    required this.reasons,
    required this.fulfilled,
    required this.unplaced,
    required this.freeShare,
  });

  final String label;
  final List<GardenElement> elements;
  final double score;

  /// Kurze Begründungen der Anordnung.
  final List<String> reasons;

  /// Erfüllte Wünsche, z. B. „2 × Gemüsebeet“.
  final List<String> fulfilled;
  final List<UnplacedWish> unplaced;

  /// Anteil der Gartenfläche ohne Hindernisse (0..1).
  final double freeShare;
}

/// Gesamtergebnis einer Planung.
class PlanningResult {
  const PlanningResult({required this.proposals, required this.notes});
  final List<PlanProposal> proposals;

  /// Allgemeine Hinweise (z. B. „nur ein gültiger Vorschlag gefunden“).
  final List<String> notes;
}

/// Regelbasierte automatische Gartenplanung.
///
/// Ablauf je Kandidat:
/// 1. Fixierte Elemente (und bei „beibehalten“ alle vorhandenen) übernehmen.
/// 2. Wunschelemente nach Fläche absteigend auf einem Suchraster platzieren.
///    Für jede freie, gültige Position wird eine Bewertung berechnet
///    (Rand-Nähe für Bauten, Nähe zur Terrasse für Sitzgruppe usw.).
///    Zufälliges Rauschen je Kandidat sorgt für unterschiedliche Anordnungen.
/// 3. Rasenwünsche zuletzt: in die größte freie Rechteckfläche legen.
/// 4. Gesamtbewertung: Summe der Einzelbewertungen + zusammenhängende
///    Freifläche + Nähe zum gewünschten Freiflächenanteil.
///
/// Harte Regeln (Grenze, Kollisionsmatrix, fixierte Elemente) werden nie
/// verletzt. Das ist eine Gestaltungshilfe, keine fachliche oder rechtliche
/// Prüfung.
class AutoPlanner {
  AutoPlanner({
    this.candidateCount = 6,
    this.maxProposals = 3,
    this.timeBudget = const Duration(seconds: 3),
  });

  final int candidateCount;
  final int maxProposals;
  final Duration timeBudget;

  PlanningResult plan(GardenProject project, {int seed = 42}) {
    final settings = project.planning;
    final stopwatch = Stopwatch()..start();
    final candidates = <PlanProposal>[];
    final noiseLevels = [0.0, 0.8, 1.6, 2.5, 3.5, 5.0, 7.0, 9.0];

    for (var i = 0; i < candidateCount; i++) {
      if (i > 0 && stopwatch.elapsed > timeBudget) break;
      final noise = noiseLevels[i % noiseLevels.length];
      final rnd = math.Random(seed + i * 7919);
      candidates.add(_buildCandidate(project, settings, rnd, noise, i));
    }

    // Beste zuerst, dann Duplikate entfernen.
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final distinct = <PlanProposal>[];
    for (final c in candidates) {
      if (distinct.any((d) => _sameLayout(d, c))) continue;
      distinct.add(c);
      if (distinct.length >= maxProposals) break;
    }
    final labels = ['Vorschlag A', 'Vorschlag B', 'Vorschlag C'];
    final labeled = [
      for (var i = 0; i < distinct.length; i++)
        PlanProposal(
          label: i < labels.length ? labels[i] : 'Vorschlag ${i + 1}',
          elements: distinct[i].elements,
          score: distinct[i].score,
          reasons: distinct[i].reasons,
          fulfilled: distinct[i].fulfilled,
          unplaced: distinct[i].unplaced,
          freeShare: distinct[i].freeShare,
        ),
    ];

    final notes = <String>[];
    if (settings.wishes.isEmpty) {
      notes.add('Es wurden keine Wunschelemente angegeben.');
    }
    if (labeled.length < maxProposals && candidates.length > labeled.length) {
      notes.add(
        'Nur ${labeled.length} unterscheidbare Anordnung(en) gefunden – '
        'weitere Kandidaten waren identisch.',
      );
    }
    if (stopwatch.elapsed > timeBudget) {
      notes.add('Zeitlimit erreicht, nicht alle Kandidaten berechnet.');
    }
    return PlanningResult(proposals: labeled, notes: notes);
  }

  /// Zwei Anordnungen gelten als gleich, wenn jedes neu platzierte Element
  /// an (fast) derselben Stelle liegt.
  bool _sameLayout(PlanProposal a, PlanProposal b) {
    if (a.elements.length != b.elements.length) return false;
    final bByType = <String, List<GardenElement>>{};
    for (final e in b.elements) {
      bByType.putIfAbsent(e.typeId, () => []).add(e);
    }
    for (final e in a.elements) {
      final pool = bByType[e.typeId];
      if (pool == null) return false;
      final idx = pool.indexWhere(
        (o) =>
            (o.x - e.x).abs() < 0.26 &&
            (o.y - e.y).abs() < 0.26 &&
            (o.width - e.width).abs() < 0.26 &&
            (o.depth - e.depth).abs() < 0.26,
      );
      if (idx < 0) return false;
      pool.removeAt(idx);
    }
    return true;
  }

  PlanProposal _buildCandidate(
    GardenProject project,
    PlanningSettings settings,
    math.Random rnd,
    double noise,
    int index,
  ) {
    final gw = project.width;
    final gl = project.length;

    // 1. Basis: fixierte Elemente immer, sonstige nur wenn gewünscht.
    final placed = <GardenElement>[
      for (final e in project.elements)
        if (e.locked || settings.keepExisting) e,
    ];
    final reasons = <String>[];
    final fulfilled = <String>[];
    final unplaced = <UnplacedWish>[];
    final fulfilledCount = <String, int>{};
    var itemScore = 0.0;

    // 2. Wunschliste aufbauen; Rasen wird zuletzt behandelt.
    final items = <ElementType>[];
    var lawnWishes = 0;
    for (final entry in settings.wishes.entries) {
      final t = ElementCatalog.byId(entry.key);
      if (t == null) {
        unplaced.add(
          UnplacedWish(typeId: entry.key, reason: 'Unbekannter Elementtyp.'),
        );
        continue;
      }
      if (t.id == 'lawn') {
        lawnWishes += entry.value;
        continue;
      }
      for (var i = 0; i < entry.value; i++) {
        items.add(t);
      }
    }
    // Große Elemente zuerst; gleiche Größe zufällig gemischt (Vielfalt).
    items.shuffle(rnd);
    items.sort(
      (a, b) => (b.defaultWidth * b.defaultDepth).compareTo(
        a.defaultWidth * a.defaultDepth,
      ),
    );

    // Suchraster: 0,5 m, bei sehr großen Gärten gröber (Laufzeit).
    final step = math.max(0.5, math.max(gw, gl) / 40);

    var seq = 0;
    for (final t in items) {
      final w = t.defaultWidth;
      final d = t.shape == ElementShape.circle ? w : t.defaultDepth;
      if (w > gw && w > gl ||
          d > gl && d > gw ||
          (w > gw || d > gl) && (w > gl || d > gw)) {
        unplaced.add(
          UnplacedWish(
            typeId: t.id,
            reason:
                '${t.name} (${_fmt(w)} × ${_fmt(d)} m) ist größer als der Garten.',
          ),
        );
        continue;
      }
      final best = _bestPosition(
        t,
        w,
        d,
        placed,
        gw,
        gl,
        step,
        settings.style,
        rnd,
        noise,
      );
      if (best == null) {
        unplaced.add(
          UnplacedWish(
            typeId: t.id,
            reason:
                'Kein freier, regelkonformer Platz für ${t.name} '
                '(${_fmt(w)} × ${_fmt(d)} m) gefunden.',
          ),
        );
        continue;
      }
      seq++;
      placed.add(best.element.copyWith(id: 'plan-$index-$seq-${t.id}'));
      itemScore += best.score;
      fulfilledCount[t.id] = (fulfilledCount[t.id] ?? 0) + 1;
    }

    // 3. Rasen: größte freie Rechteckfläche (frei von anderen Flächen).
    for (var i = 0; i < lawnWishes; i++) {
      final rect = _largestFreeRect(
        placed,
        gw,
        gl,
        step,
        (e) => e.type.collisionClass == CollisionClass.ground,
      );
      if (rect == null || rect.width < 1.5 || rect.height < 1.5) {
        unplaced.add(
          const UnplacedWish(
            typeId: 'lawn',
            reason:
                'Keine zusammenhängende freie Fläche von mindestens '
                '1,5 × 1,5 m für Rasen übrig.',
          ),
        );
        continue;
      }
      seq++;
      placed.add(
        GardenElement(
          id: 'plan-$index-$seq-lawn',
          typeId: 'lawn',
          x: rect.center.dx,
          y: rect.center.dy,
          width: _round2(rect.width),
          depth: _round2(rect.height),
        ),
      );
      fulfilledCount['lawn'] = (fulfilledCount['lawn'] ?? 0) + 1;
      reasons.add(
        'Rasen füllt die größte freie Fläche '
        '(${_fmt(rect.width)} × ${_fmt(rect.height)} m).',
      );
    }

    // 4. Gesamtbewertung.
    final obstacleArea = placed
        .where((e) => e.type.collisionClass != CollisionClass.ground)
        .fold<double>(0, (s, e) => s + _footprint(e));
    final freeShare = (1 - obstacleArea / (gw * gl)).clamp(0.0, 1.0);
    final freeRect = _largestFreeRect(
      placed,
      gw,
      gl,
      step,
      (e) => e.type.collisionClass != CollisionClass.ground,
    );
    final freeRectArea = freeRect == null
        ? 0.0
        : freeRect.width * freeRect.height;
    final contiguity = freeRectArea / (gw * gl);
    final shareDiff = (freeShare - settings.targetLawnShare).abs();
    final total = itemScore + contiguity * 15 - shareDiff * 20;

    // Begründungen aus dem Ergebnis ableiten.
    reasons.addAll(_describe(placed, project, settings, freeRect));
    final pct = (freeShare * 100).round();
    final target = (settings.targetLawnShare * 100).round();
    reasons.add('Freie Fläche ohne Hindernisse: $pct % (Ziel etwa $target %).');

    for (final entry in fulfilledCount.entries) {
      final name = ElementCatalog.byId(entry.key)?.name ?? entry.key;
      fulfilled.add('${entry.value} × $name');
    }

    return PlanProposal(
      label: 'Kandidat ${index + 1}',
      elements: List.unmodifiable(placed),
      score: total,
      reasons: reasons,
      fulfilled: fulfilled,
      unplaced: unplaced,
      freeShare: freeShare,
    );
  }

  /// Sucht die bestbewertete gültige Position für ein Element.
  _Scored? _bestPosition(
    ElementType t,
    double w,
    double d,
    List<GardenElement> placed,
    double gw,
    double gl,
    double step,
    GardenStyle style,
    math.Random rnd,
    double noise,
  ) {
    _Scored? best;
    final rotations = t.shape == ElementShape.circle || (w == d)
        ? const [0.0]
        : const [0.0, 90.0];
    for (final rot in rotations) {
      final ew = rot == 90 ? d : w; // effektive Hüllbox
      final ed = rot == 90 ? w : d;
      if (ew > gw || ed > gl) continue;
      final xs = _gridPositions(ew, gw, step);
      final ys = _gridPositions(ed, gl, step);
      for (final x in xs) {
        for (final y in ys) {
          final candidate = GardenElement(
            id: '_cand',
            typeId: t.id,
            x: x,
            y: y,
            width: w,
            depth: d,
            rotation: rot,
          );
          if (!_quickFits(candidate, placed, gw, gl)) continue;
          final s =
              _positionScore(candidate, placed, gw, gl, style) +
              rnd.nextDouble() * noise;
          if (best == null || s > best.score) best = _Scored(candidate, s);
        }
      }
    }
    return best;
  }

  /// Mögliche Mittelpunkt-Koordinaten entlang einer Achse, Rand inklusive.
  List<double> _gridPositions(double size, double gardenSize, double step) {
    final half = size / 2;
    final list = <double>[];
    for (var v = half; v <= gardenSize - half + 1e-9; v += step) {
      list.add(_round2(v));
    }
    final last = _round2(gardenSize - half);
    if (list.isEmpty || (list.last - last).abs() > 1e-6) list.add(last);
    return list;
  }

  bool _quickFits(
    GardenElement c,
    List<GardenElement> placed,
    double gw,
    double gl,
  ) {
    if (!isInsideGarden(c, gw, gl)) return false;
    final cb = elementBounds(c);
    final cls = c.type.collisionClass;
    for (final o in placed) {
      if (mayOverlap(cls, o.type.collisionClass)) continue;
      // Schneller Hüllbox-Vorabtest, danach exakte Prüfung.
      if (!cb.overlaps(elementBounds(o))) continue;
      if (elementsOverlap(c, o)) return false;
    }
    return true;
  }

  /// Weiche Bewertungskriterien für eine einzelne Position.
  double _positionScore(
    GardenElement c,
    List<GardenElement> placed,
    double gw,
    double gl,
    GardenStyle style,
  ) {
    var s = 0.0;
    final t = c.type;
    final b = elementBounds(c);
    final edgeDist = [
      b.left,
      b.top,
      gw - b.right,
      gl - b.bottom,
    ].reduce(math.min);

    // Bauten bevorzugt am Rand; andere Hindernisse leicht am Rand,
    // damit die Mitte als zusammenhängende Freifläche bleibt.
    if (t.collisionClass == CollisionClass.structure) {
      s += 4 * (1 - (edgeDist / (math.max(gw, gl) / 2)).clamp(0.0, 1.0));
      if (edgeDist < 0.01) s += 1.5;
    } else if (t.collisionClass != CollisionClass.ground) {
      s += 1.5 * (1 - (edgeDist / (math.max(gw, gl) / 2)).clamp(0.0, 1.0));
    }

    // Nähe zu anderen Hindernissen: Bündelung reduziert Zerstückelung,
    // empfohlener Abstand wird aber eingehalten.
    double nearest(bool Function(GardenElement) where) {
      var min = double.infinity;
      for (final o in placed) {
        if (!where(o)) continue;
        min = math.min(min, boundsDistance(c, o));
      }
      return min;
    }

    bool isObstacle(GardenElement e) =>
        e.type.collisionClass != CollisionClass.ground &&
        e.type.collisionClass != CollisionClass.zone;

    final dObst = nearest(isObstacle);
    if (dObst.isFinite) {
      final clearance = math.max(
        t.recommendedClearance,
        placed
            .where(isObstacle)
            .map((o) => o.type.recommendedClearance)
            .fold<double>(0, math.max),
      );
      if (dObst < clearance) {
        s -= (clearance - dObst) * 2; // zu dicht
      } else {
        s += 1.5 * (1 - ((dObst - clearance) / 4).clamp(0.0, 1.0)); // kompakt
      }
    }

    // Typ-spezifische Regeln.
    switch (t.id) {
      case 'seating':
        final onTerrace = placed.any(
          (o) => o.typeId == 'terrace' && elementsOverlap(c, o),
        );
        final dT = nearest((o) => o.typeId == 'terrace');
        if (onTerrace) {
          s += 6;
        } else if (dT.isFinite) {
          s += 3 * (1 - (dT / 5).clamp(0.0, 1.0));
        }
        if (style == GardenStyle.relax) {
          final dPond = nearest((o) => o.typeId == 'pond');
          if (dPond.isFinite) s += 2 * (1 - (dPond / 4).clamp(0.0, 1.0));
        }
      case 'bbq':
        final dS = nearest(
          (o) => o.typeId == 'seating' || o.typeId == 'terrace',
        );
        if (dS.isFinite) s += 3 * (1 - (dS / 5).clamp(0.0, 1.0));
        final dPlay = nearest(
          (o) => o.typeId == 'play_area' || o.typeId == 'sandbox',
        );
        if (dPlay < 3) s -= 5;
      case 'vegetable_bed':
      case 'raised_bed':
        final dBed = nearest(
          (o) => o.typeId == 'vegetable_bed' || o.typeId == 'raised_bed',
        );
        if (dBed.isFinite) {
          s += 4 * (1 - ((dBed - 0.5).abs() / 3).clamp(0.0, 1.0));
          // Gleiche Ausrichtung bevorzugen.
          final sameRot = placed.any(
            (o) =>
                (o.typeId == 'vegetable_bed' || o.typeId == 'raised_bed') &&
                o.rotation == c.rotation,
          );
          if (sameRot) s += 1;
        }
        if (style == GardenStyle.kitchen) {
          final dG = nearest(
            (o) => o.typeId == 'greenhouse' || o.typeId == 'rain_barrel',
          );
          if (dG.isFinite) s += 2 * (1 - (dG / 6).clamp(0.0, 1.0));
        }
      case 'play_area':
      case 'sandbox':
        final dDanger = nearest((o) => o.typeId == 'pond' || o.typeId == 'bbq');
        if (dDanger < 3) s -= 6;
        if (style == GardenStyle.family) {
          final dT = nearest((o) => o.typeId == 'terrace');
          if (dT.isFinite) s += 2.5 * (1 - (dT / 8).clamp(0.0, 1.0));
        }
        if (style == GardenStyle.relax) {
          final dS = nearest((o) => o.typeId == 'seating');
          if (dS < 3) s -= 2;
        }
      case 'pond':
        final dPlay = nearest(
          (o) => o.typeId == 'play_area' || o.typeId == 'sandbox',
        );
        if (dPlay < 3) s -= 6;
        if (style == GardenStyle.relax) {
          final dS = nearest((o) => o.typeId == 'seating');
          if (dS.isFinite) s += 2 * (1 - (dS / 4).clamp(0.0, 1.0));
        }
      case 'compost':
        final dT = nearest(
          (o) => o.typeId == 'terrace' || o.typeId == 'seating',
        );
        if (dT < 3) s -= 3; // Kompost nicht direkt am Sitzplatz
        final dBed = nearest((o) => o.typeId == 'vegetable_bed');
        if (dBed.isFinite) s += 2 * (1 - (dBed / 6).clamp(0.0, 1.0));
      case 'rain_barrel':
        final dB = nearest(
          (o) => o.typeId == 'shed' || o.typeId == 'greenhouse',
        );
        if (dB.isFinite) s += 2 * (1 - (dB / 3).clamp(0.0, 1.0));
      case 'tree':
        // Bäume nicht direkt an Gewächshaus/Gemüsebeet (Schatten) – einfache
        // Heuristik ohne Sonnenstandsanalyse.
        final dG = nearest(
          (o) => o.typeId == 'greenhouse' || o.typeId == 'vegetable_bed',
        );
        if (dG < 2) s -= 2;
    }
    return s;
  }

  /// Größtes achsenparalleles Rechteck auf dem Suchraster, das von keinem
  /// Element erfasst wird, auf das [blocks] zutrifft.
  Rect? _largestFreeRect(
    List<GardenElement> placed,
    double gw,
    double gl,
    double step,
    bool Function(GardenElement) blocks,
  ) {
    final cols = math.max(1, (gw / step).floor());
    final rows = math.max(1, (gl / step).floor());
    final cw = gw / cols;
    final ch = gl / rows;
    final blockers = placed.where(blocks).toList();
    // Belegungsraster: Zelle belegt, wenn ihr Mittelpunkt in einem Hindernis
    // liegt oder die Hüllbox des Hindernisses die Zelle überlappt.
    final occupied = List.generate(rows, (_) => List.filled(cols, false));
    for (final e in blockers) {
      final b = elementBounds(e);
      final c0 = (b.left / cw).floor().clamp(0, cols - 1);
      final c1 = ((b.right / cw).ceil() - 1).clamp(0, cols - 1);
      final r0 = (b.top / ch).floor().clamp(0, rows - 1);
      final r1 = ((b.bottom / ch).ceil() - 1).clamp(0, rows - 1);
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          occupied[r][c] = true;
        }
      }
    }
    // Klassischer Histogramm-Algorithmus für das größte Rechteck.
    final heights = List.filled(cols, 0);
    var bestArea = 0;
    Rect? best;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        heights[c] = occupied[r][c] ? 0 : heights[c] + 1;
      }
      final stack = <int>[];
      for (var c = 0; c <= cols; c++) {
        final h = c == cols ? 0 : heights[c];
        while (stack.isNotEmpty && heights[stack.last] >= h) {
          final top = stack.removeLast();
          final height = heights[top];
          final left = stack.isEmpty ? 0 : stack.last + 1;
          final width = c - left;
          final area = width * height;
          if (area > bestArea && height > 0) {
            bestArea = area;
            best = Rect.fromLTWH(
              left * cw,
              (r - height + 1) * ch,
              width * cw,
              height * ch,
            );
          }
        }
        stack.add(c);
      }
    }
    return best;
  }

  List<String> _describe(
    List<GardenElement> placed,
    GardenProject project,
    PlanningSettings settings,
    Rect? freeRect,
  ) {
    final out = <String>[];
    final news = placed.where((e) => e.id.startsWith('plan-')).toList();
    if (news.isEmpty) return out;
    final gw = project.width;
    final gl = project.length;

    final structures = news
        .where((e) => e.type.collisionClass == CollisionClass.structure)
        .toList();
    if (structures.isNotEmpty) {
      final atEdge = structures.where((e) {
        final b = elementBounds(e);
        return [b.left, b.top, gw - b.right, gl - b.bottom].reduce(math.min) <
            0.6;
      }).length;
      out.add(
        '$atEdge von ${structures.length} Bauten am Grundstücksrand platziert.',
      );
    }
    final seating = news.where((e) => e.typeId == 'seating');
    for (final s in seating) {
      final onTerrace = placed.any(
        (o) => o.typeId == 'terrace' && elementsOverlap(s, o),
      );
      out.add(
        onTerrace
            ? 'Sitzgruppe steht auf der Terrasse.'
            : 'Sitzgruppe ohne Terrasse platziert.',
      );
    }
    // Neue Beete gelten als gruppiert, wenn jedes nahe an einem anderen
    // (neuen oder vorhandenen) Beet liegt.
    final newBeds = news.where((e) => e.typeId == 'vegetable_bed').toList();
    final allBeds = placed.where((e) => e.typeId == 'vegetable_bed').toList();
    if (newBeds.isNotEmpty && allBeds.length > 1) {
      var grouped = true;
      for (final b in newBeds) {
        final others = allBeds.where((o) => o.id != b.id);
        if (others.every((o) => boundsDistance(b, o) > 1.5)) grouped = false;
      }
      out.add(
        grouped
            ? 'Gemüsebeete sind gruppiert.'
            : 'Gemüsebeete konnten nicht alle gruppiert werden.',
      );
    }
    final play = news.where(
      (e) => e.typeId == 'play_area' || e.typeId == 'sandbox',
    );
    for (final p in play) {
      final danger = placed.where(
        (o) =>
            (o.typeId == 'pond' || o.typeId == 'bbq') &&
            boundsDistance(p, o) < 3,
      );
      if (danger.isNotEmpty) {
        out.add(
          '${p.type.name} liegt näher als 3 m an '
          '${danger.map((d) => d.type.name).join(', ')} (Zielkonflikt).',
        );
      } else {
        out.add('${p.type.name} hält Abstand zu Teich und Grillplatz.');
      }
    }
    if (freeRect != null) {
      out.add(
        'Größte zusammenhängende Freifläche: '
        '${_fmt(freeRect.width)} × ${_fmt(freeRect.height)} m.',
      );
    }
    out.add('Stil: ${settings.style.label}.');
    return out;
  }

  static double _footprint(GardenElement e) =>
      e.type.shape == ElementShape.circle
      ? math.pi * (e.width / 2) * (e.width / 2)
      : e.width * e.depth;

  static double _round2(double v) => (v * 100).round() / 100;

  static String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
}

class _Scored {
  const _Scored(this.element, this.score);
  final GardenElement element;
  final double score;
}
