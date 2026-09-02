import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// On-disk cache for GET API responses, layered on top of [flutter_cache_manager].
///
/// Honours the backend's `Cache-Control` + `ETag` headers when present
/// (flutter_cache_manager revalidates with `If-None-Match` and serves the
/// cached copy on a 304). When those headers are absent it falls back to the
/// [Config.stalePeriod] configured below.
///
/// Only GETs are cached here — writes stay on the normal http client and call
/// the invalidation helpers afterwards.
class CacheService {
  CacheService._();
  static final CacheService instance = CacheService._();

  static const _cacheStoreKey = 'dietingAppApiCache';

  final CacheManager _manager = CacheManager(
    Config(
      _cacheStoreKey,
      stalePeriod: const Duration(hours: 6),
      maxNrOfCacheObjects: 200,
    ),
  );

  /// Bumped whenever a day's cached data is invalidated. Kept-alive screens
  /// (which don't refetch on tab switch) listen to this and reload when
  /// [lastInvalidatedDate] matches the day they're showing.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  DateTime? _lastInvalidatedDate;
  DateTime? get lastInvalidatedDate => _lastInvalidatedDate;

  // ── Cache keys ─────────────────────────────────────────────────────────────
  // Always scoped to the signed-in user so two accounts on the same device can
  // never read each other's cached data.

  static String _ymd(DateTime date) => date.toIso8601String().split('T')[0];

  static String summaryKey(String uid, DateTime date) =>
      '$uid:summary:${_ymd(date)}';

  static String logsKey(String uid, DateTime date) =>
      '$uid:logs:${_ymd(date)}';

  static String profileKey(String uid) => '$uid:profile';

  static String goalsKey(String uid) => '$uid:goals';

  // ── Auth ─────────────────────────────────────────────────────────────────
  // Single source for the Firebase ID token sent on every cached GET.

  Future<Map<String, String>> _authHeaders(Map<String, String>? extra) async {
    final headers = <String, String>{...?extra};
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches [url], serving from disk when a fresh copy is cached under
  /// [cacheKey]. Pass [forceRefresh] to drop the cached copy and re-download.
  Future<Map<String, dynamic>> getJson(
    String url, {
    required String cacheKey,
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    try {
      if (forceRefresh) {
        await _manager.removeFile(cacheKey);
      }

      final file = await _manager.getSingleFile(
        url,
        key: cacheKey,
        headers: await _authHeaders(headers),
      );

      final decoded = json.decode(utf8.decode(await file.readAsBytes()));
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('Expected a JSON object response');
    } catch (e) {
      throw Exception('Failed to load "$cacheKey" from $url: $e');
    }
  }

  /// Warms the cache for [url] under [cacheKey] without throwing. A no-op on
  /// the network when a fresh copy is already cached. Used for background
  /// preloading where individual failures should be ignored.
  Future<void> prefetch(
    String url, {
    required String cacheKey,
    Map<String, String>? headers,
  }) async {
    try {
      await _manager.getSingleFile(
        url,
        key: cacheKey,
        headers: await _authHeaders(headers),
      );
    } catch (_) {
      // Best-effort warm-up — ignore failures (offline, 404, etc.).
    }
  }

  // ── Invalidation ─────────────────────────────────────────────────────────────

  /// Drops a single cached entry.
  Future<void> invalidateKey(String cacheKey) async {
    await _manager.removeFile(cacheKey);
  }

  /// Drops the summary + log entries cached for [uid] on [date], then notifies
  /// listeners so any kept-alive screen showing that day can refetch.
  Future<void> invalidateDate(String uid, DateTime date) async {
    await invalidateKey(summaryKey(uid, date));
    await invalidateKey(logsKey(uid, date));
    _lastInvalidatedDate = DateTime(date.year, date.month, date.day);
    revision.value++;
  }

  /// Drops the cached profile for [uid].
  Future<void> invalidateProfile(String uid) async {
    await invalidateKey(profileKey(uid));
  }

  /// Drops the cached goals for [uid].
  Future<void> invalidateGoals(String uid) async {
    await invalidateKey(goalsKey(uid));
  }
}
