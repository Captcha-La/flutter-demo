// Captchala Flutter demo.
//
// A simple panel that lets you pick action / lang / theme and run the
// full verify flow. In a real integration:
//   1. Your backend issues a one-time server_token
//      (see https://captcha.la/docs).
//   2. Pass it to CaptchalaConfig.serverToken.
//   3. Call client.verify() — native captcha UI opens.
//   4. On success, send result.passToken back to your backend for
//      validation.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:captchala/captchala.dart';
import 'package:http/http.dart' as http;

// -------- Demo configuration --------------------------------------------
// Replace with your own appKey from https://dash.captcha.la.
const String kDemoAppKey = 'demo_app';
// Demo backend that issues server_token and validates pass_token.
// In production these endpoints live on YOUR backend.
const String kDemoApiServer = 'https://demo-v1.captcha.la';
// Integrator business UID — comes from your authenticated session.
const String kDemoUid = 'demo-user-12345';

// -------- Picker option lists (match Android / iOS demos) --------------


const List<String> _actions = ['login', 'register', 'pay'];

const List<({String label, String value})> _languages = [
  (label: 'Auto (system)',    value: ''),
  (label: '简体中文',         value: 'zh-CN'),
  (label: '繁體中文',         value: 'zh-TW'),
  (label: 'English',          value: 'en'),
  (label: '日本語',           value: 'ja'),
  (label: '한국어',           value: 'ko'),
  (label: 'Bahasa Melayu',    value: 'ms'),
  (label: 'Tiếng Việt',       value: 'vi'),
  (label: 'Bahasa Indonesia', value: 'id'),
];

const List<String> _themes = ['light', 'dark', 'system'];

// -------- Demo backend helpers ------------------------------------------

/// Fetch a one-time server_token from the integrator backend (demo backend used here).
Future<String?> fetchServerToken({required String appKey, required String action}) async {
  try {
    final uri = Uri.parse(
      '$kDemoApiServer/demo/issue-captcha-token'
      '?app_key=$appKey&action=$action&uid=$kDemoUid',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    final data = body?['data'] as Map<String, dynamic>?;
    final token = data?['server_token'] as String?;
    return (token != null && token.isNotEmpty) ? token : null;
  } catch (_) {
    return null;
  }
}

/// Simulates integrator backend validating the pass_token.
Future<String> validatePassToken({required String appKey, required String passToken}) async {
  try {
    final uri = Uri.parse('$kDemoApiServer/demo/validate-pass-token');
    final res = await http.post(uri, body: {
      'app_key': appKey,
      'pass_token': passToken,
      'expected_uid': kDemoUid,
    }).timeout(const Duration(seconds: 8));
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    final data = body?['data'] as Map<String, dynamic>?;
    if (data == null) return 'validate failed: no data';
    final valid = data['valid'] == true;
    if (!valid) return 'validate: invalid — ${data['error'] ?? 'unknown'}';
    final uid = (data['uid'] as String?) ?? '(null)';
    final match = data['uid_match'] == true;
    return 'validate: valid=true, uid=$uid, match=${match ? "✓" : "✗"}';
  } catch (e) {
    return 'validate failed: $e';
  }
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'captchala example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  // -------- Settings state (mirrors Android / iOS demos) ----------------

  String _action = 'login';
  String _lang = ''; // Auto (system) by default
  String _theme = 'light';
  bool _enableVoice = true;
  bool _enableOfflineMode = false;
  bool _maskClosable = false;

  // -------- Result state ------------------------------------------------

  String _status = 'Configure settings, then tap Verify.';
  bool _isVerifying = false;

  // -------- MethodChannel path ------------------------------------------

  Future<void> _runVerify() async {
    setState(() {
      _isVerifying = true;
      _status = 'Fetching server_token...';
    });

    try {
      // 1) Pull a one-shot server_token from the integrator backend.
      final initialToken = await fetchServerToken(appKey: kDemoAppKey, action: _action);
      if (!mounted) return;
      setState(() => _status = initialToken != null
          ? 'Got server_token, starting verify()...'
          : '⚠︎ server_token missing, continuing without bind (prod should abort)');

      // 2) Build config from current panel state.
      final config = CaptchalaConfig(
        appKey: kDemoAppKey,
        action: _action,
        lang: _lang,
        theme: _theme,
        enableVoice: _enableVoice,
        enableOfflineMode: _enableOfflineMode,
        maskClosable: _maskClosable,
        serverToken: initialToken,
      );

      final client = await CaptchalaClient.instance.initialize(config);
      debugPrint('[demo] verify() invoked');
      client.setCallbacks(
        onSuccess: (r) async {
          debugPrint('[demo] onSuccess fired'
              ' isOffline=${r.isOffline}'
              ' isClientOnly=${r.isClientOnly}'
              ' passToken=${r.passToken}'
              ' challengeId=${r.challengeId}');
          if (!mounted) return;
          final flags = <String>[
            if (r.isOffline) 'OFFLINE',
            if (r.isClientOnly) 'CLIENT-ONLY',
          ];
          final tag = flags.isEmpty ? '' : ' [${flags.join(', ')}]';
          setState(() => _status =
              'onSuccess$tag: token=${r.passToken}\n(validating with backend...)');
          final info = await validatePassToken(appKey: kDemoAppKey, passToken: r.passToken);
          if (!mounted) return;
          setState(() {
            _status = 'onSuccess$tag: token=${r.passToken}\n$info';
            _isVerifying = false;
          });
        },
        onFail: (e) {
          debugPrint('[demo] onFail fired code=${e.code} message=${e.message}');
          if (!mounted) return;
          setState(() {
            _status = 'onFail: ${e.code} ${e.message}';
            _isVerifying = false;
          });
        },
        onError: (e) {
          debugPrint('[demo] onError fired code=${e.code} message=${e.message}');
          if (!mounted) return;
          setState(() {
            _status = 'onError: ${e.code} ${e.message}';
            _isVerifying = false;
          });
        },
        onClose: () {
          debugPrint('[demo] onClose fired (was _isVerifying=$_isVerifying)');
          if (!mounted) return;
          setState(() {
            if (_isVerifying) {
              _status = 'onClose (closed before completion)';
            }
            _isVerifying = false;
          });
        },
        onServerTokenExpired: () {
          debugPrint('[demo] onServerTokenExpired fired — fetching new token');
          return fetchServerToken(appKey: kDemoAppKey, action: _action);
        },
      );
      debugPrint('[demo] calling client.verify()...');
      await client.verify();
      debugPrint('[demo] client.verify() returned (waiting for callbacks)');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'exception: $e';
        _isVerifying = false;
      });
    }
  }

  // -------- UI ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Captchala Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Captcha settings -------------------------------------------
          const Text('Captcha Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          _buildLabeledPicker(
            label: 'Action',
            value: _action,
            options: _actions.map((e) => (label: e, value: e)).toList(),
            onChanged: (v) => setState(() => _action = v),
          ),
          _buildLabeledPicker(
            label: 'Language',
            value: _lang,
            options: _languages.map((e) => (label: e.label, value: e.value)).toList(),
            onChanged: (v) => setState(() => _lang = v),
          ),
          _buildLabeledPicker(
            label: 'Theme',
            value: _theme,
            options: _themes.map((e) => (label: e, value: e)).toList(),
            onChanged: (v) => setState(() => _theme = v),
          ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),

          // --- Toggles ---------------------------------------------------
          const Text('Toggles',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SwitchListTile(
            title: const Text('Enable voice fallback'),
            value: _enableVoice,
            onChanged: (v) => setState(() => _enableVoice = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Allow offline mode'),
            value: _enableOfflineMode,
            onChanged: (v) => setState(() => _enableOfflineMode = v),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Mask click closes'),
            value: _maskClosable,
            onChanged: (v) => setState(() => _maskClosable = v),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),

          // --- Verify button --------------------------------------------
          ElevatedButton.icon(
            onPressed: _isVerifying ? null : _runVerify,
            icon: _isVerifying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.verified_user),
            label: Text(_isVerifying ? 'Verifying…' : 'Verify with Captcha'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_status, style: const TextStyle(fontFamily: 'monospace')),
          ),

          const SizedBox(height: 24),

          // --- Build info -----------------------------------------------
          const Text('Build Info',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildInfoRow('appKey', kDemoAppKey),
          _buildInfoRow('uid',    kDemoUid),
          _buildInfoRow('apiServer', kDemoApiServer),
        ],
      ),
    );
  }

  Widget _buildLabeledPicker({
    required String label,
    required String value,
    required List<({String label, String value})> options,
    required void Function(String) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              isDense: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: options
                  .map((o) =>
                      DropdownMenuItem(value: o.value, child: Text(o.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 80,
              child:
                  Text(key, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
