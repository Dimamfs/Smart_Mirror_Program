import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/profile.dart';
import '../models/email_message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Profile _profile;
  List<EmailMessage> _messages = [];
  bool _loadingMessages = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    // Always refresh from backend so stale list data never hides Gmail state
    _refreshProfile();
  }

  ApiService get _api => context.read<AuthProvider>().api;

  Future<void> _deleteProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete profile', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${_profile.name}"? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteProfile(_profile.id);
      if (mounted) Navigator.of(context).pop(true); // return true = deleted
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loadingMessages = true;
      _error = null;
    });
    try {
      final msgs = await _api.getMessages(_profile.id);
      if (mounted) setState(() => _messages = msgs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final updated = await _api.getProfile(_profile.id);
      debugPrint(
          '[Profile] refreshed id=${updated.id} email=${updated.email} googleSub=${updated.googleSub} hasGmail=${updated.hasGmail}');
      if (mounted) {
        setState(() => _profile = updated);
        if (_profile.hasGmail) _loadMessages();
      }
    } on ApiException catch (e) {
      debugPrint(
          '[Profile] refresh ApiException: ${e.message} (${e.statusCode})');
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[Profile] refresh error: $e');
    }
  }

  Future<void> _connectGmail() async {
    try {
      final url = await _api.getGmailConnectUrl(_profile.id);
      if (!mounted) return;

      // Open the Google consent page in the system browser
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open browser', 0);
      }

      // Show a dialog — user comes back here after finishing in the browser
      if (!mounted) return;
      final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Connect Gmail',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Complete the sign-in in your browser, then tap "Done" to continue.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (done == true) await _refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disconnectGmail() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Disconnect Gmail',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove Gmail access for this profile.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.disconnectGmail(_profile.id);
      await _refreshProfile();
      if (mounted) setState(() => _messages = []);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(_profile.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete profile',
            onPressed: _deleteProfile,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white12,
              backgroundImage: _profile.faceUrl != null
                  ? NetworkImage(_profile.faceUrl!)
                  : null,
              child: _profile.faceUrl == null
                  ? Text(
                      _profile.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _profile.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),

          // Mirror ID section
          _MirrorIdSection(
            profile: _profile,
            api: _api,
            onUpdated: (updated) => setState(() => _profile = updated),
          ),
          const SizedBox(height: 16),

          // Spotify section
          _SpotifySection(
            profile: _profile,
            api: _api,
            onUpdated: (updated) => setState(() => _profile = updated),
          ),
          const SizedBox(height: 16),

          // Gmail section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mail_outline,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text('Gmail',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_profile.hasGmail)
                      TextButton(
                        onPressed: _disconnectGmail,
                        child: const Text('Disconnect',
                            style: TextStyle(
                                color: Colors.redAccent, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_profile.hasGmail)
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _profile.email!,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  )
                else ...[
                  const Text(
                    'Connect Gmail to show unread emails on the mirror.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _connectGmail,
                      icon: const Icon(Icons.add_link),
                      label: const Text('Connect Gmail'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Inbox preview
          if (_profile.hasGmail) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Unread inbox',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh,
                      color: Colors.white54, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingMessages)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Colors.white),
              ))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent))
            else if (_messages.isEmpty)
              const Text('No unread messages.',
                  style: TextStyle(color: Colors.white54))
            else
              ...(_messages.map((m) => _MessageTile(message: m))),
          ],
        ],
      ),
    );
  }
}

class _MirrorIdSection extends StatefulWidget {
  final Profile profile;
  final ApiService api;
  final void Function(Profile) onUpdated;

  const _MirrorIdSection({
    required this.profile,
    required this.api,
    required this.onUpdated,
  });

  @override
  State<_MirrorIdSection> createState() => _MirrorIdSectionState();
}

class _MirrorIdSectionState extends State<_MirrorIdSection> {
  late TextEditingController _controller;
  bool _editing = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.profile.mirrorId ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mirrorId = _controller.text.trim();
    final profileId = widget.profile.id;

    debugPrint(
        '[MirrorLink] Save pressed — profileId=$profileId mirrorId="$mirrorId"');

    if (mirrorId.isEmpty) {
      setState(() => _error = 'Mirror ID cannot be empty');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugPrint('[MirrorLink] Sending PATCH /api/profiles/$profileId/mirror');
      final updated = await widget.api.setMirrorId(profileId, mirrorId);
      debugPrint('[MirrorLink] Success — profile updated: ${updated.mirrorId}');
      widget.onUpdated(updated);
      if (mounted) {
        setState(() {
          _editing = false;
        });
      }
    } on ApiException catch (e) {
      debugPrint('[MirrorLink] ApiException: ${e.message} (${e.statusCode})');
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[MirrorLink] Unexpected error: $e');
      if (mounted) {
        setState(() => _error = 'Connection error — is the backend running?');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tv_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Mirror',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!_editing)
                TextButton(
                  onPressed: () => setState(() => _editing = true),
                  child: Text(
                    widget.profile.hasMirror ? 'Change' : 'Link',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
            ],
          ),
          if (!_editing) ...[
            const SizedBox(height: 6),
            if (widget.profile.hasMirror)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.profile.mirrorId!,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'No mirror linked. Tap Link and enter the Mirror ID shown on your mirror.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
          ] else ...[
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Paste Mirror ID here',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed:
                      _loading ? null : () => setState(() => _editing = false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white54)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Spotify Section ──────────────────────────────────────────────────────────

class _SpotifySection extends StatefulWidget {
  final Profile profile;
  final ApiService api;
  final void Function(Profile) onUpdated;

  const _SpotifySection({
    required this.profile,
    required this.api,
    required this.onUpdated,
  });

  @override
  State<_SpotifySection> createState() => _SpotifySectionState();
}

class _SpotifySectionState extends State<_SpotifySection> {
  bool _loading = false;
  String? _error;

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profileId = widget.profile.id;
      debugPrint('[Spotify] connecting profileId=$profileId');

      final url = await widget.api.getSpotifyConnectUrl(profileId);
      if (!mounted) return;

      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw ApiException('Could not open browser', 0);
      }

      if (!mounted) return;
      final done = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Connect Spotify',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'Sign in with Spotify in your browser, then tap "Done" to continue.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (done == true) {
        // Reload profile to pick up spotify_connected + spotify_display_name
        final updated = await widget.api.getProfile(widget.profile.id);
        debugPrint(
            '[Spotify] profile reload: spotifyConnected=${updated.spotifyConnected} displayName=${updated.spotifyDisplayName}');
        if (mounted) widget.onUpdated(updated);
      }
    } on ApiException catch (e) {
      debugPrint('[Spotify] ApiException: ${e.message} (${e.statusCode})');
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('[Spotify] error: $e');
      if (mounted) {
        setState(() => _error = 'Connection error — is the backend running?');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Disconnect Spotify',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove Spotify access for this profile.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.disconnectSpotify(widget.profile.id);
      final updated = await widget.api.getProfile(widget.profile.id);
      if (mounted) widget.onUpdated(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.profile.hasSpotify;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Spotify logo colour dot
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.music_note, color: Colors.white, size: 13),
              ),
              const SizedBox(width: 8),
              const Text('Spotify',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (_loading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54))
              else if (connected)
                TextButton(
                  onPressed: _disconnect,
                  child: const Text('Disconnect',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (connected) ...[
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.profile.spotifyDisplayName ?? 'Connected',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Connect Spotify to show what\'s playing on the mirror.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style:
                      const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _connect,
                icon: const Icon(Icons.music_note),
                label: const Text('Connect Spotify'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Message Tile ─────────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  final EmailMessage message;
  const _MessageTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.subject,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            message.from,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            message.snippet,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
