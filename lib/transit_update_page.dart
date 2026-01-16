import 'package:flutter/material.dart';

class TransitUpdatePage extends StatefulWidget {
  const TransitUpdatePage({super.key});

  @override
  State<TransitUpdatePage> createState() => _TransitUpdatePageState();
}

class _TransitUpdatePageState extends State<TransitUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _lineController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<String> _issueTypes = const [
    'Train malfunction',
    'Power outage',
    'Station closure',
    'Crowding',
    'Security concern',
    'Other',
  ];
  String _selectedIssue = 'Train malfunction';
  double _severity = 2;
  bool _shareContact = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    _lineController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you!')),
    );
    _formKey.currentState!.reset();
    setState(() {
      _selectedIssue = _issueTypes.first;
      _severity = 2;
      _shareContact = false;
    });
    _titleController.clear();
    _detailsController.clear();
    _lineController.clear();
    _locationController.clear();
    // Future: send payload to Firebase Firestore/Functions once backend is ready.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report transit update'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Text(
                'Let fellow riders know about sudden issues, similar to community-driven alerts in navigation apps.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedIssue),
                initialValue: _selectedIssue,
                decoration: const InputDecoration(
                  labelText: 'Issue type',
                  border: OutlineInputBorder(),
                ),
                items: _issueTypes
                    .map(
                      (issue) => DropdownMenuItem<String>(
                        value: issue,
                        child: Text(issue),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedIssue = value);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Short title',
                  hintText: 'e.g., Blue Line train stuck at Hua Lamphong',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Share what happened, expected delay, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) =>
                    (value == null || value.trim().length < 10)
                        ? 'Please provide at least 10 characters'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lineController,
                decoration: const InputDecoration(
                  labelText: 'Line / service',
                  hintText: 'e.g., MRT Blue Line',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Nearest station',
                  hintText: 'e.g., Sukhumvit (E4)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text('Severity: ${_severity.round()}/5'),
              Slider(
                value: _severity,
                min: 1,
                max: 5,
                divisions: 4,
                label: _severity.round().toString(),
                onChanged: (value) => setState(() => _severity = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _shareContact,
                onChanged: (value) => setState(() => _shareContact = value),
                title: const Text('Share contact info'),
                subtitle: const Text('Allow staff to reach out if more info needed'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitReport,
                icon: const Icon(Icons.send),
                label: const Text('Submit report'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // Future: integrate with Firebase Storage for photo uploads.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo attachments coming soon.')),
                  );
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Attach photo (coming soon)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
