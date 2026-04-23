import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/supabase_backend.dart';

class CloudLedgerService {
  static const _table = 'ledger_snapshots';

  SupabaseClient? get _client => SupabaseBackend.client;

  bool get isAvailable => _client != null;

  Future<bool> ensureSession() async {
    final client = _client;
    if (client == null) return false;
    if (client.auth.currentSession != null) return true;

    try {
      await client.auth.signInAnonymously();
      return client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<Map<String, dynamic>?> readSnapshot() async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) return null;

    final row = await client
        .from(_table)
        .select('payload')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;
    final payload = row['payload'];
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    return null;
  }

  Future<void> saveSnapshot(Map<String, dynamic> payload) async {
    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) return;

    await client.from(_table).upsert({
      'user_id': userId,
      'payload': payload,
    }, onConflict: 'user_id');
  }
}
