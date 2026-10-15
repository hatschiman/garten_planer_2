import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/garden_project.dart';
import 'editor_screen.dart';
import 'project_dialogs.dart';
import 'theme.dart';

/// Übersicht aller gespeicherten Gartenprojekte.
class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key, required this.store});

  final ProjectStore store;

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStore);
    if (!widget.store.isLoaded) widget.store.load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (!mounted) return;
    setState(() {});
    final corrupt = widget.store.corruptFiles;
    if (corrupt.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${corrupt.length} beschädigte Projektdatei(en) wurden '
              'übersprungen und als „.defekt“ gesichert.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        widget.store.clearCorruptNotice();
      });
    }
  }

  Future<void> _createProject() async {
    final result = await showProjectFormDialog(context);
    if (result == null || !mounted) return;
    final project = await widget.store.create(
      name: result.name,
      width: result.width,
      length: result.length,
    );
    if (!mounted) return;
    _open(project);
  }

  void _open(GardenProject project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EditorScreen(store: widget.store, projectId: project.id),
      ),
    );
  }

  Future<void> _rename(GardenProject p) async {
    final result = await showProjectFormDialog(
      context,
      title: 'Garten bearbeiten',
      confirmLabel: 'Speichern',
      initialName: p.name,
      initialWidth: p.width,
      initialLength: p.length,
    );
    if (result == null || !mounted) return;
    if (result.width != p.width || result.length != p.length) {
      // Elemente außerhalb des neuen Grundstücks? Dann warnen.
      final latest = widget.store.byId(p.id) ?? p;
      final outside = latest.elements.where((e) {
        return e.x + e.width / 2 > result.width + 1e-6 ||
            e.y + e.depth / 2 > result.length + 1e-6;
      }).length;
      if (outside > 0) {
        final ok = await confirmDialog(
          context,
          title: 'Maße verkleinern?',
          message:
              '$outside Element(e) würden außerhalb der neuen Grenzen liegen '
              'und müssen danach verschoben werden.',
          confirmLabel: 'Trotzdem ändern',
        );
        if (!ok || !mounted) return;
      }
      await widget.store.resize(p.id, result.width, result.length);
    }
    await widget.store.rename(p.id, result.name);
  }

  Future<void> _delete(GardenProject p) async {
    final ok = await confirmDialog(
      context,
      title: 'Garten löschen?',
      message: '„${p.name}“ wird dauerhaft gelöscht.',
    );
    if (!ok) return;
    await widget.store.delete(p.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final projects = store.projects;
    return Scaffold(
      appBar: AppBar(
        title: const Text('GartenPlan'),
        actions: [
          IconButton(
            tooltip: 'Über die App',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'GartenPlan',
              applicationVersion: '0.1.0 (Entwicklungsstand)',
              children: const [
                Text(
                  'Maßstabsgetreuer 2D-Gartenplaner mit regelbasierter '
                  'automatischer Planung. Alle Daten bleiben lokal auf dem Gerät.',
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createProject,
        icon: const Icon(Icons.add),
        label: const Text('Neuer Garten'),
      ),
      body: !store.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : store.loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(store.loadError!, textAlign: TextAlign.center),
              ),
            )
          : projects.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: projects.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = projects[i];
                return _ProjectCard(
                  project: p,
                  onOpen: () => _open(p),
                  onRename: () => _rename(p),
                  onDelete: () => _delete(p),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.yard_outlined, size: 64, color: kForestGreen),
            const SizedBox(height: 16),
            Text(
              'Noch kein Garten angelegt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Lege mit „Neuer Garten“ dein erstes Grundstück an.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final GardenProject project;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modified = project.modifiedAt;
    final dateText =
        '${modified.day.toString().padLeft(2, '0')}.'
        '${modified.month.toString().padLeft(2, '0')}.${modified.year}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.grass,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            project.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (project.isSample) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Beispiel',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtMeters(project.width)} × ${fmtMeters(project.length)}'
                      ' · ${project.elements.length} Elemente · $dateText',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Weitere Aktionen',
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Umbenennen / Maße'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Löschen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
