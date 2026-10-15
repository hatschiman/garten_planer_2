import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../editor/editor_controller.dart';
import '../models/element_type.dart';
import '../models/garden_element.dart';
import '../models/garden_project.dart';
import '../models/planning_settings.dart';
import '../planner/auto_planner.dart';
import 'plan_preview.dart';

/// Läuft in einem Isolate, damit die Oberfläche bedienbar bleibt.
PlanningResult _runPlanner((GardenProject, int) args) =>
    AutoPlanner().plan(args.$1, seed: args.$2);

/// Eingabe der Planungswünsche und Anzeige der Vorschläge.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key, required this.controller});

  final EditorController controller;

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late PlanningSettings _settings;
  PlanningResult? _result;
  bool _running = false;
  int _seed = 42;

  @override
  void initState() {
    super.initState();
    _settings = widget.controller.project.planning;
  }

  void _setWish(String typeId, int count) {
    final wishes = Map<String, int>.from(_settings.wishes);
    if (count <= 0) {
      wishes.remove(typeId);
    } else {
      wishes[typeId] = count.clamp(0, 20);
    }
    setState(() => _settings = _settings.copyWith(wishes: wishes));
  }

  Future<void> _run({bool newSeed = false}) async {
    if (newSeed) _seed += 1;
    widget.controller.updatePlanningSettings(_settings);
    final project = widget.controller.project;
    setState(() {
      _running = true;
      _result = null;
    });
    PlanningResult result;
    try {
      result = await compute(_runPlanner, (project, _seed));
    } catch (e) {
      result = PlanningResult(
        proposals: const [],
        notes: ['Die Planung ist fehlgeschlagen: $e'],
      );
    }
    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });
  }

  void _apply(PlanProposal p) {
    widget.controller.replaceAllElements(p.elements);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = widget.controller.project;
    final totalWishes = _settings.wishes.values.fold<int>(0, (a, b) => a + b);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatische Planung'),
        actions: [
          if (_result != null)
            TextButton(
              onPressed: _running ? null : () => _run(newSeed: true),
              child: const Text('Neue Varianten'),
            ),
        ],
      ),
      body: _running
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Anordnungen werden berechnet …'),
                ],
              ),
            )
          : _result != null
          ? _ResultsView(
              project: project,
              result: _result!,
              onApply: _apply,
              onBack: () => setState(() => _result = null),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Card(
                  color: theme.colorScheme.surfaceContainerLow,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Regelbasierte Planung: Wunschelemente werden auf einem '
                      'Raster so angeordnet, dass Grenzen und Kollisionsregeln '
                      'eingehalten werden. Das ist eine Gestaltungshilfe, keine '
                      'Prüfung von Sicherheit, Pflanzeneignung oder Baurecht.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Gartenstil', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<GardenStyle>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in GardenStyle.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {_settings.style},
                  onSelectionChanged: (sel) => setState(
                    () => _settings = _settings.copyWith(style: sel.first),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gewünschte freie Fläche: ${(_settings.targetLawnShare * 100).round()} %',
                  style: theme.textTheme.titleMedium,
                ),
                Slider(
                  value: _settings.targetLawnShare,
                  min: 0,
                  max: 0.9,
                  divisions: 18,
                  label: '${(_settings.targetLawnShare * 100).round()} %',
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(targetLawnShare: v),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bereits platzierte Elemente beibehalten'),
                  subtitle: const Text(
                    'Fixierte Elemente bleiben in jedem Fall unverändert.',
                  ),
                  value: _settings.keepExisting,
                  onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(keepExisting: v),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gewünschte Elemente ($totalWishes)',
                  style: theme.textTheme.titleMedium,
                ),
                for (final cat in ElementCategory.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      cat.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final t in ElementCatalog.byCategory(cat))
                    _WishRow(
                      type: t,
                      count: _settings.wishes[t.id] ?? 0,
                      onChanged: (n) => _setWish(t.id, n),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: _result != null || _running
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: totalWishes == 0 ? null : () => _run(),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                    totalWishes == 0
                        ? 'Bitte mindestens ein Element wünschen'
                        : 'Vorschläge berechnen',
                  ),
                ),
              ),
            ),
    );
  }
}

class _WishRow extends StatelessWidget {
  const _WishRow({
    required this.type,
    required this.count,
    required this.onChanged,
  });

  final ElementType type;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(type.icon, color: type.strokeColor),
        const SizedBox(width: 12),
        Expanded(child: Text(type.name)),
        IconButton(
          tooltip: 'Weniger ${type.name}',
          onPressed: count > 0 ? () => onChanged(count - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Mehr ${type.name}',
          onPressed: () => onChanged(count + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.project,
    required this.result,
    required this.onApply,
    required this.onBack,
  });

  final GardenProject project;
  final PlanningResult result;
  final void Function(PlanProposal) onApply;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposals = result.proposals;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Wünsche ändern'),
            ),
            const Spacer(),
            Text(
              proposals.length == 1
                  ? '1 Vorschlag'
                  : '${proposals.length} Vorschläge',
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        for (final note in result.notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(note)),
              ],
            ),
          ),
        if (proposals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Es konnte keine gültige Anordnung gefunden werden. Prüfe die '
              'Gartenmaße und die Anzahl der Wünsche.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final p in proposals) ...[
          _ProposalCard(
            project: project,
            proposal: p,
            onApply: () => onApply(p),
          ),
          const SizedBox(height: 16),
        ],
        const Text(
          'Ein Vorschlag verändert den Plan erst nach „Übernehmen“. Die '
          'Übernahme kann im Editor rückgängig gemacht werden.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.project,
    required this.proposal,
    required this.onApply,
  });

  final GardenProject project;
  final PlanProposal proposal;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final newIds = proposal.elements
        .where((e) => e.id.startsWith('plan-'))
        .map((e) => e.id)
        .toSet();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(proposal.label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: const Color(0xFFF2EDE2),
                padding: const EdgeInsets.all(8),
                child: PlanPreview(
                  project: project,
                  elements: _ordered(proposal.elements),
                  highlightIds: newIds,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Blau gestrichelt: neu platzierte Elemente.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text('Begründung', style: theme.textTheme.titleSmall),
            for (final r in proposal.reasons)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $r'),
              ),
            const SizedBox(height: 12),
            if (proposal.fulfilled.isNotEmpty) ...[
              Text('Erfüllt', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in proposal.fulfilled)
                    Chip(
                      avatar: Icon(
                        Icons.check,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text(f),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
            if (proposal.unplaced.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Nicht erfüllt',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              for (final u in proposal.unplaced)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${u.typeName}: ${u.reason}')),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onApply,
                  icon: const Icon(Icons.check),
                  label: Text('${proposal.label} übernehmen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static List<GardenElement> _ordered(List<GardenElement> els) {
    int rank(GardenElement e) => switch (e.type.collisionClass) {
      CollisionClass.ground => 0,
      CollisionClass.zone => 1,
      CollisionClass.furniture => 2,
      CollisionClass.structure => 3,
      CollisionClass.plant => 4,
    };
    final list = List<GardenElement>.from(els);
    final indexed = list.asMap().entries.toList()
      ..sort((a, b) {
        final r = rank(a.value).compareTo(rank(b.value));
        return r != 0 ? r : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }
}
