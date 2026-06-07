import 'package:flutter/material.dart';

class TaskReportScreen extends StatefulWidget {
  const TaskReportScreen({super.key, required this.pickPhoto, required this.onSubmit});
  final Future<String?> Function() pickPhoto;
  final Future<void> Function(String text, int minutes, List<String> photoPaths) onSubmit;

  @override
  State<TaskReportScreen> createState() => _TaskReportScreenState();
}

class _TaskReportScreenState extends State<TaskReportScreen> {
  final _text = TextEditingController();
  final _minutes = TextEditingController();
  final List<String> _photos = [];
  bool _busy = false;

  Future<void> _addPhoto() async {
    final path = await widget.pickPhoto();
    if (path != null) setState(() => _photos.add(path));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    await widget.onSubmit(_text.text, int.tryParse(_minutes.text) ?? 0, List.of(_photos));
    if (mounted) {
      setState(() => _busy = false);
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(children: [
          TextField(
            key: const Key('report_text'),
            controller: _text,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Compte-rendu'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('report_minutes'),
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Temps passé (minutes)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('add_photo'),
            onPressed: _busy ? null : _addPhoto,
            icon: const Icon(Icons.photo_camera),
            label: Text('Ajouter une photo (${_photos.length})'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            key: const Key('submit_report'),
            onPressed: _busy ? null : _submit,
            child: const Text('Envoyer le rapport'),
          ),
        ]),
      ),
    );
  }
}
