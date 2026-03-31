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
    if (_profile.hasGmail) _loadMessages();
  }

  ApiService get _api => context.read<AuthProvider>().api;

  Future<void> _loadMessages() async {
    setState(() { _loadingMessages = true; _error = null; });
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
      if (mounted) {
        setState(() => _profile = updated);
        if (_profile.hasGmail) _loadMessages();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
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
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.white12,
              child: Text(
                _profile.name[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold),
              ),
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
              Text(_error!,
                  style: const TextStyle(color: Colors.redAccent))
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
