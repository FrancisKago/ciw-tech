import 'package:flutter/material.dart';
import '../models/task.dart';

typedef SiteOption = ({String id, String name});
typedef TechOption = ({String id, String name});

class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({
    super.key, required this.sites, required this.technicians,
    required this.onCreate, this.isOnline = true,
  });
  final List<SiteOption> sites;
  final List<TechOption> technicians;
  final bool isOnline;
  final Future<void> Function(
    String title, String description, String siteId, String assigneeId,
    TaskPriority priority, DateTime? dueAt) onCreate;

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _siteId, _assigneeId;
  TaskPriority _priority = TaskPriority.normal;
  DateTime? _dueAt;
  String? _error;
  bool _busy = false;

  bool get _canSubmit =>
      !_busy && widget.sites.isNotEmpty && widget.technicians.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.sites.isNotEmpty) _siteId = widget.sites.first.id;
    if (widget.technicians.isNotEmpty) _assigneeId = widget.technicians.first.id;
  }

  Future<void> _submit() async {
    if (!widget.isOnline) {
      setState(() => _error = 'Vous devez être en ligne pour créer une tâche.');
      return;
    }
    if (_title.text.trim().isEmpty || _siteId == null || _assigneeId == null) {
      setState(() => _error = 'Titre, site et technicien sont requis.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    await widget.onCreate(
      _title.text.trim(), _desc.text.trim(), _siteId!, _assigneeId!, _priority, _dueAt);
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle tâche')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          TextField(
            key: const Key('task_title'), controller: _title,
            decoration: const InputDecoration(labelText: 'Titre')),
          const SizedBox(height: 12),
          TextField(
            controller: _desc, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 12),
          if (widget.sites.isEmpty)
            const ListTile(
              leading: Icon(Icons.location_off, color: Colors.orange),
              title: Text('Aucun site disponible'),
              subtitle: Text('Créez d\'abord un site dans le backoffice.'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _siteId,
              decoration: const InputDecoration(labelText: 'Site'),
              items: widget.sites
                  .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _siteId = v)),
          const SizedBox(height: 12),
          if (widget.technicians.isEmpty)
            const ListTile(
              leading: Icon(Icons.person_off, color: Colors.orange),
              title: Text('Aucun technicien disponible'),
              subtitle: Text('Un technicien doit s\'être connecté au moins une fois.'),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Technicien'),
              items: widget.technicians
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                  .toList(),
              onChanged: (v) => setState(() => _assigneeId = v)),
          const SizedBox(height: 12),
          DropdownButtonFormField<TaskPriority>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: TaskPriority.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? TaskPriority.normal)),
          const SizedBox(height: 24),
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ElevatedButton(
            key: const Key('create_submit'),
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Créer et assigner')),
        ]),
      ),
    );
  }
}
