import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Global singleton — access from any screen without passing through the tree,
// the same pattern used by themeNotifier and authService in this codebase.
final waterService = WaterService();

/// Display units. Storage is *always* millilitres — this only affects what the
/// user reads and types, and it is what the future `water_log.amount_ml` column
/// expects, so moving to the backend is a data move rather than a conversion.
enum WaterUnit { ml, flOz, cup }

extension WaterUnitX on WaterUnit {
  // US customary.
  double get mlPerUnit => switch (this) {
    WaterUnit.ml => 1,
    WaterUnit.flOz => 29.5735,
    WaterUnit.cup => 236.588,
  };

  String get label => switch (this) {
    WaterUnit.ml => 'ml',
    WaterUnit.flOz => 'fl oz',
    WaterUnit.cup => 'cups',
  };

  // Stored form of the enum, mirroring how ThemeNotifier persists ThemeMode.
  String get storageValue => switch (this) {
    WaterUnit.ml => 'ml',
    WaterUnit.flOz => 'floz',
    WaterUnit.cup => 'cup',
  };

  /// Converts a display value to whole millilitres, clamped to a range that
  /// can't overflow an int. `round()` is undefined for infinities, and
  /// `double.tryParse` happily returns one for something like "9e999" typed
  /// into a text field — so clamp before converting rather than after.
  int toMl(num value) {
    final ml = value * mlPerUnit;
    if (ml.isNaN) return 0;
    return ml.clamp(0, WaterService.maxEntryMl).round();
  }

  double fromMl(int ml) => ml / mlPerUnit;

  /// Drops the decimal when the value is effectively whole, so millilitres read
  /// as "2000" rather than "2000.0" while cups still read as "8.5".
  String format(num value) {
    final d = value.toDouble();
    if ((d - d.roundToDouble()).abs() < 0.05) return d.round().toString();
    return d.toStringAsFixed(1);
  }

  /// The same value rendered with its unit, e.g. "8.5 cups".
  String formatWithLabel(num value) => '${format(value)} $label';
}

/// One add. [clientEntryId] is generated on-device the instant the user taps and
/// never changes; the Phase 2 upload dedupes on it, so a retried sync can't
/// double-count. [serverId] stays null until this entry exists on the backend.
class WaterEntry {
  final String clientEntryId;
  final int ml;
  final DateTime at;
  final int? serverId;

  const WaterEntry({
    required this.clientEntryId,
    required this.ml,
    required this.at,
    this.serverId,
  });

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
    clientEntryId: (json['client_entry_id'] ?? '').toString(),
    ml: (json['ml'] as num?)?.round() ?? 0,
    at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
    serverId: json['id'] as int?,
  );

  // On-disk shape today, wire shape in Phase 2 — deliberately the same map so
  // the backfill payload needs no translation layer.
  Map<String, dynamic> toJson() => {
    'client_entry_id': clientEntryId,
    'ml': ml,
    'at': at.toIso8601String(),
    'id': serverId,
  };
}

/// One day's entries. The total is derived, never stored — a persisted total
/// that can disagree with its entry list is a bug waiting to happen.
class WaterDay {
  final List<WaterEntry> entries;

  const WaterDay(this.entries);

  static const empty = WaterDay(<WaterEntry>[]);

  int get totalMl => entries.fold(0, (sum, e) => sum + e.ml);
}

/// Owns every preferences key and all the JSON. Private so key construction
/// can't leak into the UI, where a typo would silently orphan a day of data.
class _WaterLocalStore {
  static const _prefix = 'water:v1';
  static const _unitKey = 'water_unit';
  static const historyDays = 90;

  static final _dateSegment = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static String ymd(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String().split('T')[0];

  static String _dayKey(String uid, DateTime date) =>
      '$_prefix:$uid:${ymd(date)}';

  static String _goalKey(String uid) => '$_prefix:$uid:goal_ml';

  Future<WaterDay> readDay(String uid, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dayKey(uid, date));
    if (raw == null || raw.isEmpty) return WaterDay.empty;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return WaterDay.empty;
      final list = decoded['entries'] as List<dynamic>? ?? const [];
      return WaterDay(
        list
            .whereType<Map<String, dynamic>>()
            .map(WaterEntry.fromJson)
            .toList(),
      );
    } catch (_) {
      // A corrupt value is dropped rather than crashing the home screen.
      return WaterDay.empty;
    }
  }

  Future<void> writeDay(String uid, DateTime date, WaterDay day) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _dayKey(uid, date);
    if (day.entries.isEmpty) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(
      key,
      json.encode({'entries': day.entries.map((e) => e.toJson()).toList()}),
    );
  }

  Future<int?> readGoalMl(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalKey(uid));
  }

  Future<void> writeGoalMl(String uid, int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalKey(uid), ml);
  }

  Future<WaterUnit?> readUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_unitKey)) {
      'floz' => WaterUnit.flOz,
      'cup' => WaterUnit.cup,
      'ml' => WaterUnit.ml,
      _ => null,
    };
  }

  Future<void> writeUnit(WaterUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_unitKey, unit.storageValue);
  }

  /// Drops day keys older than [historyDays], matching how far back the home
  /// screen's date navigator lets the user go.
  Future<void> pruneOldDays(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoff = ymd(
      DateTime.now().subtract(const Duration(days: historyDays)),
    );
    final userPrefix = '$_prefix:$uid:';
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(userPrefix)) continue;
      final segment = key.substring(userPrefix.length);
      if (!_dateSegment.hasMatch(segment)) continue; // goal_ml and friends
      if (segment.compareTo(cutoff) < 0) await prefs.remove(key);
    }
  }
}

/// Water logging, currently backed entirely by [SharedPreferences].
///
/// The card listens to this object directly rather than going through
/// [CacheService]'s revision bus: that bus exists because the source of truth is
/// the network and a write on one tab can't reach a kept-alive screen on
/// another. Here the source of truth is this object, so a plain
/// `ListenableBuilder` is both simpler and correct.
///
/// In Phase 2 the network calls land inside these same methods — `add` gains a
/// `DatabaseService.logWater` call and an id stamp — so no UI call site changes.
class WaterService extends ChangeNotifier {
  static const defaultGoalMl = 2000;
  static const minEntryMl = 1;

  /// Hard ceiling on a single entry. Not a realistic drink — it's the bound
  /// that keeps every conversion well inside int range, so a huge number typed
  /// into the amount field can't overflow. Amounts at or above it are rejected
  /// outright rather than clamped.
  static const maxEntryMl = 10001;
  static const minGoalMl = 100;
  static const maxGoalMl = 10000;

  final _WaterLocalStore _store = _WaterLocalStore();

  // Hydrated days, keyed '<uid>:<yyyy-mm-dd>', so the card can render
  // synchronously once a day has been read off disk.
  final Map<String, WaterDay> _days = {};
  final Set<String> _loadingDays = {};

  String? _loadedUid;
  int _goalMl = defaultGoalMl;
  WaterUnit _unit = WaterUnit.ml;

  int get goalMl => _goalMl;
  WaterUnit get unit => _unit;

  static String _key(String uid, DateTime date) =>
      '$uid:${_WaterLocalStore.ymd(date)}';

  static String _newClientEntryId(String uid) {
    final random = Random();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '$uid-${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  /// Loads the goal and unit for [uid]. Cheap to call repeatedly — it only does
  /// work when the signed-in user changes, which also clears another account's
  /// days out of memory.
  Future<void> loadFor(String uid) async {
    if (_loadedUid == uid) return;
    _loadedUid = uid;
    _days.clear();
    _unit = await _store.readUnit() ?? WaterUnit.ml;
    _goalMl = await _store.readGoalMl(uid) ?? defaultGoalMl;
    notifyListeners();
    await _store.pruneOldDays(uid);
  }

  /// Synchronous read of an already-hydrated day; null until [ensureLoaded] has
  /// run for that day.
  WaterDay? peek(String uid, DateTime date) => _days[_key(uid, date)];

  Future<void> ensureLoaded(String uid, DateTime date) async {
    await loadFor(uid);
    final key = _key(uid, date);
    if (_days.containsKey(key) || _loadingDays.contains(key)) return;
    _loadingDays.add(key);
    try {
      _days[key] = await _store.readDay(uid, date);
    } finally {
      _loadingDays.remove(key);
    }
    notifyListeners();
  }

  Future<void> add(String uid, DateTime date, int ml) async {
    if (ml < minEntryMl) return;
    await ensureLoaded(uid, date);
    final key = _key(uid, date);
    final day = WaterDay([
      ...(_days[key] ?? WaterDay.empty).entries,
      WaterEntry(
        clientEntryId: _newClientEntryId(uid),
        ml: ml.clamp(minEntryMl, maxEntryMl),
        at: DateTime.now(),
      ),
    ]);
    _days[key] = day;
    notifyListeners(); // paint before touching disk — the tap must feel instant
    await _store.writeDay(uid, date, day);
  }

  Future<void> undoLast(String uid, DateTime date) async {
    await ensureLoaded(uid, date);
    final key = _key(uid, date);
    final current = _days[key];
    if (current == null || current.entries.isEmpty) return;
    final day = WaterDay(
      current.entries.sublist(0, current.entries.length - 1),
    );
    _days[key] = day;
    notifyListeners();
    await _store.writeDay(uid, date, day);
  }

  Future<void> setGoalMl(String uid, int ml) async {
    _goalMl = ml.clamp(minGoalMl, maxGoalMl);
    notifyListeners();
    await _store.writeGoalMl(uid, _goalMl);
  }

  Future<void> setUnit(WaterUnit unit) async {
    _unit = unit;
    notifyListeners();
    await _store.writeUnit(unit);
  }
}
