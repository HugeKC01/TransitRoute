import os

widget_code = """
class _GtfsVersionTile extends StatefulWidget {
  const _GtfsVersionTile();

  @override
  State<_GtfsVersionTile> createState() => _GtfsVersionTileState();
}

class _GtfsVersionTileState extends State<_GtfsVersionTile> {
  int _currentVersion = 0;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final ver = await gtfsSyncService.getLocalVersion();
    if (mounted) {
      setState(() {
        _currentVersion = ver;
      });
    }
  }

  Future<void> _handleCheckUpdates() async {
    if (_isChecking) return;
    setState(() {
      _isChecking = true;
    });

    final message = await gtfsSyncService.manualUpdateCheck();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() {
        _isChecking = false;
      });
      await _loadVersion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update_alt_outlined),
      title: const Text('Transit Data Package'),
      subtitle: Text('Local version: $_currentVersion (Tap to check)'),
      trailing: _isChecking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: _handleCheckUpdates,
    );
  }
}
"""

with open("lib/pages/more_page.dart", "a") as f:
    f.write("\\n")
    f.write(widget_code)
