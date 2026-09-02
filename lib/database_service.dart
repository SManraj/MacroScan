import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'services/cache_service.dart';

class ServingSize {
  final String id;
  final String description;
  final double? calories;
  final double? carbs;
  final double? fat;
  final double? protein;
  // Raw metric fields — used by FoodDetail to derive per-unit servings
  final double? metricServingAmount;
  final String? metricServingUnit;

  ServingSize({
    required this.id,
    required this.description,
    this.calories,
    this.carbs,
    this.fat,
    this.protein,
    this.metricServingAmount,
    this.metricServingUnit,
  });

  factory ServingSize.fromJson(Map<String, dynamic> json) => ServingSize(
    id: json['serving_id'] ?? '',
    description: json['serving_description'] ?? '',
    calories: (json['calories'] as num?)?.toDouble(),
    carbs: (json['carbs'] as num?)?.toDouble(),
    fat: (json['fat'] as num?)?.toDouble(),
    protein: (json['protein'] as num?)?.toDouble(),
    metricServingAmount: (json['metric_serving_amount'] as num?)?.toDouble(),
    metricServingUnit: json['metric_serving_unit'] as String?,
  );

  /// Creates a derived per-unit serving by dividing this serving's macros by [amount].
  ServingSize perUnit(String unit, double amount) => ServingSize(
    id: 'per_$unit',
    description: '1 $unit',
    calories: calories != null ? calories! / amount : null,
    carbs: carbs != null ? carbs! / amount : null,
    fat: fat != null ? fat! / amount : null,
    protein: protein != null ? protein! / amount : null,
  );
}

class FoodDetail {
  final String id;
  final String name;
  final String? brandName;
  final List<ServingSize> servings;

  FoodDetail({
    required this.id,
    required this.name,
    this.brandName,
    required this.servings,
  });

  String get displayName => brandName != null ? '$name ($brandName)' : name;

  factory FoodDetail.fromJson(Map<String, dynamic> json) {
    final rawServings = (json['servings'] as List<dynamic>? ?? [])
        .map((s) => ServingSize.fromJson(s as Map<String, dynamic>))
        .toList();

    final derived = _deriveUnitServings(rawServings);

    return FoodDetail(
      id: json['food_id'] ?? '',
      name: json['food_name'] ?? '',
      brandName: json['brand_name'] as String?,
      servings: [...derived, ...rawServings],
    );
  }

  /// Derives per-unit servings (1 g, 1 oz, 1 ml, 1 fl oz, etc.) from [servings].
  /// Declared outside the loop to avoid closure-capture bugs.
  static List<ServingSize> _deriveUnitServings(List<ServingSize> servings) {
    // Normalise raw unit strings to a consistent display label
    String label(String raw) {
      final key = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (key == 'floz') return 'fl oz';
      return key;
    }

    // Pre-scan: mark every unit that already has a "1 <unit>" serving in the
    // API data so we never add a duplicate derived option.
    final seenUnits = <String>{};

    final unitPattern = RegExp(
      r'^([\d.]+)\s*(fl\s*oz|oz|cup|tbsp|tsp|lb|g|ml)\b',
      caseSensitive: false,
    );

    for (final s in servings) {
      // Check metric fields (g / ml)
      final mUnit = s.metricServingUnit?.toLowerCase();
      final mAmt = s.metricServingAmount;
      if ((mUnit == 'g' || mUnit == 'ml') && mAmt == 1.0) {
        seenUnits.add(mUnit!);
      }

      // Check description
      final m = unitPattern.firstMatch(s.description);
      if (m != null) {
        final amt = double.tryParse(m.group(1)!);
        final unit = label(m.group(2)!);
        if (amt == 1.0) seenUnits.add(unit);
      }
    }

    // Derive "1 <unit>" servings for any unit not already present
    final derived = <ServingSize>[];

    void tryDerive(ServingSize s, String unit, double? amount) {
      final displayUnit = label(unit);
      if (seenUnits.contains(displayUnit)) return;
      if (amount == null || amount <= 0) return;
      if (s.calories == null &&
          s.carbs == null &&
          s.fat == null &&
          s.protein == null) {
        return;
      }
      seenUnits.add(displayUnit);
      derived.add(s.perUnit(displayUnit, amount));
    }

    for (final s in servings) {
      // From metric_serving_unit (g or ml)
      final mUnit = s.metricServingUnit?.toLowerCase();
      if (mUnit == 'g' || mUnit == 'ml') {
        tryDerive(s, mUnit!, s.metricServingAmount);
      }

      // From description (oz, fl oz, cup, tbsp, tsp, lb)
      final m = RegExp(
        r'^([\d.]+)\s*(fl\s*oz|oz|cup|tbsp|tsp|lb)\b',
        caseSensitive: false,
      ).firstMatch(s.description);

      if (m != null) {
        final amount = double.tryParse(m.group(1)!);
        tryDerive(s, m.group(2)!, amount);
      }
    }

    return derived;
  }
}

class FoodLogEntry {
  final int id;
  final String uid;
  final String foodName;
  final String meal;
  final double servingQty;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  FoodLogEntry({
    required this.id,
    required this.uid,
    required this.foodName,
    required this.meal,
    required this.servingQty,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  // Per-unit macros — used by the edit screen to recalculate on qty change
  double get caloriesPerUnit => servingQty > 0 ? calories / servingQty : 0;
  double get proteinPerUnit => servingQty > 0 ? protein / servingQty : 0;
  double get carbsPerUnit => servingQty > 0 ? carbs / servingQty : 0;
  double get fatsPerUnit => servingQty > 0 ? fats / servingQty : 0;

  static double _d(dynamic v) => double.parse(v.toString());

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) => FoodLogEntry(
    id: json['id'] as int,
    uid: json['uid'] ?? '',
    foodName: json['food_name'] ?? '',
    meal: json['meal'] ?? '',
    servingQty: _d(json['serving_qty']),
    servingUnit: json['serving_unit'] ?? '',
    calories: _d(json['calories']),
    protein: _d(json['protein']),
    carbs: _d(json['carbs']),
    fats: _d(json['fats']),
  );
}

class FoodResult {
  final String id;
  final String name;
  final String? brandName;
  final String? servingDesc;
  final double? calories;
  final double? fat;
  final double? carbs;
  final double? protein;

  FoodResult({
    required this.id,
    required this.name,
    this.brandName,
    this.servingDesc,
    this.calories,
    this.fat,
    this.carbs,
    this.protein,
  });

  String get displayName => brandName != null ? '$name ($brandName)' : name;

  factory FoodResult.fromJson(Map<String, dynamic> json) => FoodResult(
    id: json['food_id'] ?? '',
    name: json['food_name'] ?? '',
    brandName: json['brand_name'],
    servingDesc: json['serving_desc'],
    calories: (json['calories'] as num?)?.toDouble(),
    fat: (json['fat'] as num?)?.toDouble(),
    carbs: (json['carbs'] as num?)?.toDouble(),
    protein: (json['protein'] as num?)?.toDouble(),
  );
}

/// Thrown by [DatabaseService.recognizeFoodImage] when the backend returns 422,
/// meaning the photo was accepted but no food could be detected.
class NoFoodDetectedException implements Exception {
  const NoFoodDetectedException();
  @override
  String toString() => 'No food detected in the photo.';
}

/// One entry in the `food_response` array returned by `/food/recognize`.
///
/// Carries the suggested serving + preview macros for the results list, plus
/// an optional parsed [FoodDetail] (when the backend includes the full `food`
/// block) so the user can adjust serving / quantity through the normal
/// [FoodDetailScreen] flow.
class RecognizedFood {
  final int foodId;
  final String name;
  final String suggestedServingId;
  final double suggestedUnits;
  final String suggestedServingDescription;

  // Preview macros from `eaten.total_nutritional_content`, used in the
  // results list and as the logFood payload when no [detail] is available.
  final double? previewCalories;
  final double? previewProtein;
  final double? previewCarbs;
  final double? previewFat;

  /// Parsed from the inline `food` block when present.
  final FoodDetail? detail;

  /// `serving_id` of the entry marked `is_default == "1"` in [detail].
  /// Used as a fallback when the suggested serving has no per-serving macros
  /// (e.g. non-standard restaurant servings).
  final String? defaultServingId;

  RecognizedFood({
    required this.foodId,
    required this.name,
    required this.suggestedServingId,
    required this.suggestedUnits,
    required this.suggestedServingDescription,
    this.previewCalories,
    this.previewProtein,
    this.previewCarbs,
    this.previewFat,
    this.detail,
    this.defaultServingId,
  });

  static double? _d(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());
  static int _i(dynamic v) => v == null ? 0 : (int.tryParse(v.toString()) ?? 0);

  factory RecognizedFood.fromJson(Map<String, dynamic> json) {
    final suggested =
        (json['suggested_serving'] as Map<String, dynamic>?) ?? const {};
    final eaten = json['eaten'];
    final total = eaten is Map ? eaten['total_nutritional_content'] : null;

    // Reshape the optional `food` block — `servings.serving[]` in the recognize
    // payload, flat List in the shape FoodDetail.fromJson expects — and let the
    // existing parsing handle derived per-unit servings the same way.
    FoodDetail? detail;
    String? defaultServingId;
    final foodBlock = json['food'];
    if (foodBlock is Map<String, dynamic>) {
      final servingsWrapper = foodBlock['servings'];
      final rawServing = servingsWrapper is Map
          ? servingsWrapper['serving']
          : null;
      final List<dynamic> servings;
      if (rawServing is List) {
        servings = rawServing;
      } else if (rawServing is Map) {
        servings = [rawServing];
      } else {
        servings = const [];
      }
      for (final s in servings) {
        if (s is Map && s['is_default']?.toString() == '1') {
          defaultServingId = s['serving_id']?.toString();
          break;
        }
      }
      detail = FoodDetail.fromJson({
        'food_id': foodBlock['food_id']?.toString() ?? '',
        'food_name': foodBlock['food_name'] ?? '',
        'brand_name': foodBlock['brand_name'],
        'servings': servings,
      });
    }

    return RecognizedFood(
      foodId: _i(json['food_id']),
      name: (json['food_entry_name'] ?? '').toString(),
      suggestedServingId: (suggested['serving_id'] ?? '').toString(),
      suggestedUnits: _d(suggested['number_of_units']) ?? 1.0,
      suggestedServingDescription: (suggested['serving_description'] ?? '')
          .toString(),
      previewCalories: total is Map ? _d(total['calories']) : null,
      previewProtein: total is Map ? _d(total['protein']) : null,
      previewCarbs: total is Map ? _d(total['carbs']) : null,
      previewFat: total is Map ? _d(total['fat']) : null,
      detail: detail,
      defaultServingId: defaultServingId,
    );
  }
}

class UserGoals {
  final double? currentWeightLbs;
  final double? goalWeightLbs;
  final String? weeklyGoal;
  final String? activityLevel;
  final int? calorieGoal;
  final int? proteinGoal;
  final int? carbsGoal;
  final int? fatGoal;

  UserGoals({
    this.currentWeightLbs,
    this.goalWeightLbs,
    this.weeklyGoal,
    this.activityLevel,
    this.calorieGoal,
    this.proteinGoal,
    this.carbsGoal,
    this.fatGoal,
  });

  static int? _i(dynamic v) => v == null ? null : int.tryParse(v.toString());
  static double? _d(dynamic v) =>
      v == null ? null : double.tryParse(v.toString());

  factory UserGoals.fromJson(Map<String, dynamic> json) => UserGoals(
    currentWeightLbs: _d(json['weight_lbs']),
    goalWeightLbs: _d(json['goal_weight']),
    weeklyGoal: json['weekly_goal'] as String?,
    activityLevel: json['activity_level'] as String?,
    calorieGoal: _i(json['calorie_goal']),
    proteinGoal: _i(json['protein_goal']),
    carbsGoal: _i(json['carbs_goal']),
    fatGoal: _i(json['fat_goal']),
  );
}

class DatabaseService {
  /// Base URL for your REST API.
  ///
  /// Notes:
  /// - `localhost` works for iOS simulator (runs on the Mac).
  /// - For Android emulator, the Mac can be reached via `10.0.2.2`.
  /// - On a real Android device, `localhost`/`10.0.2.2` will NOT reach your Mac;
  ///   you must use your Mac's LAN IP.
  static String get baseUrl {
    // Optional override — useful for local development.
    // Usage: flutter run --dart-define=API_BASE_URL=http://<MAC_IP>:3000/api
    final configuredBaseUrl = const String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    // Production Railway backend
    return 'https://railway-dietingapp-production.up.railway.app/api';
  }

  // Create user profile after sign up
  static Future<void> createUserProfile({
    required String uid,
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/user/create'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'uid': uid, 'email': email}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Is your backend server running on $baseUrl?',
              );
            },
          );

      if (response.statusCode != 201) {
        throw Exception('Failed to create user: ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to backend server at $baseUrl.\n'
        'Make sure your server is running on port 3000.\n'
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error connecting to $baseUrl.\n'
        'Make sure your backend server is running.\n'
        'Error: ${e.message}',
      );
    }
  }

  static Future<void> updateUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String sex,
    required int weightLbs,
    required int heightFt,
    required int heightIn,
    required double bmi,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl/user/update'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': uid,
              'f_name': firstName,
              'l_name': lastName,
              'date_of_birth': dateOfBirth.toIso8601String(),
              'sex': sex,
              'weight_lbs': weightLbs,
              'height_ft': heightFt,
              'height_in': heightIn,
              'bmi': bmi,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                'Connection timeout. Is your backend server running on $baseUrl?',
              );
            },
          );

      if (response.statusCode != 200) {
        throw Exception('Failed to update profile: ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception(
        'Cannot connect to backend server at $baseUrl.\n'
        'Make sure your server is running on port 3000.\n'
        'Error: ${e.message}',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Network error connecting to $baseUrl.\n'
        'Make sure your backend server is running.\n'
        'Error: ${e.message}',
      );
    }
  }

  // Fetch today's food log for a user (served from the on-disk cache)
  static Future<List<FoodLogEntry>> getFoodLog(
    String uid, {
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final day = date ?? DateTime.now();
    final d = day.toIso8601String().split('T')[0];
    final data = await CacheService.instance.getJson(
      '$baseUrl/food/log/$uid?date=$d',
      cacheKey: CacheService.logsKey(uid, day),
      forceRefresh: forceRefresh,
    );
    return (data['entries'] as List<dynamic>)
        .map((e) => FoodLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Warm the on-disk cache with the previous [days] days of food log so
  // navigating to past dates is instant. Best-effort and non-blocking.
  static Future<void> preloadFoodLogs(String uid, {int days = 10}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futures = <Future<void>>[];
    for (var i = 1; i <= days; i++) {
      final day = today.subtract(Duration(days: i));
      final d = day.toIso8601String().split('T')[0];
      futures.add(
        CacheService.instance.prefetch(
          '$baseUrl/food/log/$uid?date=$d',
          cacheKey: CacheService.logsKey(uid, day),
        ),
      );
    }
    await Future.wait(futures);
  }

  // Warm the on-disk cache with the previous [days] days of daily summary so
  // the Home macro chart is instant when navigating to past dates.
  static Future<void> preloadDailySummaries(String uid, {int days = 10}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futures = <Future<void>>[];
    for (var i = 1; i <= days; i++) {
      final day = today.subtract(Duration(days: i));
      final d = day.toIso8601String().split('T')[0];
      futures.add(
        CacheService.instance.prefetch(
          '$baseUrl/daily-summary/$uid?date=$d',
          cacheKey: CacheService.summaryKey(uid, day),
        ),
      );
    }
    await Future.wait(futures);
  }

  // Update an existing food log entry
  static Future<void> updateFoodLogEntry({
    required int id,
    required double servingQty,
    required String servingUnit,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/food/log/$id'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'serving_qty': servingQty,
            'serving_unit': servingUnit,
            'calories': calories.round(),
            'protein': protein.round(),
            'carbs': carbs.round(),
            'fats': fats.round(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to update entry: ${response.body}');
    }
  }

  // Delete a food log entry
  static Future<void> deleteFoodLogEntry(int id) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/food/log/$id'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete entry: ${response.body}');
    }
  }

  // Log a food entry for the current user
  static Future<void> logFood({
    required String uid,
    required String meal,
    required String foodName,
    required double servingQty,
    required String servingUnit,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    DateTime? date,
  }) async {
    final logDate = (date ?? DateTime.now()).toIso8601String().split('T')[0];

    final response = await http
        .post(
          Uri.parse('$baseUrl/food/log'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': uid,
            'date': logDate,
            'meal': meal.toLowerCase(),
            'food_name': foodName,
            'serving_qty': servingQty,
            'serving_unit': servingUnit,
            'calories': calories.round(),
            'protein': protein.round(),
            'carbs': carbs.round(),
            'fats': fats.round(),
          }),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Request timed out. Is the backend running?'),
        );

    if (response.statusCode != 201) {
      throw Exception('Failed to log food: ${response.body}');
    }
  }

  // Full food detail with all servings by food ID
  static Future<FoodDetail> getFoodDetail(String foodId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/food/$foodId'))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Request timed out. Is the backend running?'),
        );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    return FoodDetail.fromJson(jsonDecode(response.body));
  }

  // Food search — returns up to 10 results with nutrition details
  static Future<List<FoodResult>> searchFoods(String query) async {
    if (query.isEmpty) return [];

    final response = await http
        .get(Uri.parse('$baseUrl/food/search?q=${Uri.encodeComponent(query)}'))
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Search timed out. Is the backend running?'),
        );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final foods = data['foods'] as List<dynamic>? ?? [];
    return foods
        .map((f) => FoodResult.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  // Barcode lookup — returns null if not found (404), throws on error
  static Future<FoodResult?> lookupBarcode(String barcode) async {
    final gtin13 = barcode.padLeft(13, '0');
    final response = await http
        .get(Uri.parse('$baseUrl/barcode/$gtin13'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Barcode lookup failed: ${response.body}');
    }
    return FoodResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // Meal photo recognition — posts a base64 image to FatSecret (proxied via
  // the backend) and returns the detected foods. Throws
  // [NoFoodDetectedException] for 422; other failures throw a readable
  // [Exception]. Not cached.
  static Future<List<RecognizedFood>> recognizeFoodImage(
    String imageB64,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/food/recognize'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image_b64': imageB64,
            'include_food_data': true,
            'region': 'US',
            'language': 'en',
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () =>
              throw Exception('Recognition timed out. Please try again.'),
        );

    if (response.statusCode == 422) {
      throw const NoFoodDetectedException();
    }
    if (response.statusCode != 200) {
      String message;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = (body['message'] ?? body['error'] ?? 'Recognition failed')
            .toString();
      } catch (_) {
        message = 'Recognition failed (HTTP ${response.statusCode})';
      }
      throw Exception(message);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['food_response'] as List<dynamic>? ?? const [];
    return list
        .map((e) => RecognizedFood.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Autocomplete food search — returns up to 10 suggestions
  static Future<List<String>> autocompleteFood(String query) async {
    if (query.isEmpty) return [];

    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/food/autocomplete?q=${Uri.encodeComponent(query)}',
          ),
        )
        .timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw Exception('Search timed out. Is the backend running?'),
        );

    if (response.statusCode != 200) {
      throw Exception('Server error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    // FatSecret v2 autocomplete returns { "suggestions": { "suggestion": [...] } }
    final outer = data['suggestions'];
    if (outer == null) return [];
    final inner = outer['suggestion'];
    if (inner == null) return [];
    if (inner is List) return inner.map((s) => s.toString()).toList();
    return [inner.toString()];
  }

  // Fetch macro summary (goals + consumed) for the given date (served from cache)
  static Future<Map<String, dynamic>> getDailySummary(
    String uid, {
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final day = date ?? DateTime.now();
    final d = day.toIso8601String().split('T')[0];
    return CacheService.instance.getJson(
      '$baseUrl/daily-summary/$uid?date=$d',
      cacheKey: CacheService.summaryKey(uid, day),
      forceRefresh: forceRefresh,
    );
  }

  // Fetch goals for a user (served from the on-disk cache)
  static Future<UserGoals> getGoals(
    String uid, {
    bool forceRefresh = false,
  }) async {
    final data = await CacheService.instance.getJson(
      '$baseUrl/goals/$uid',
      cacheKey: CacheService.goalsKey(uid),
      forceRefresh: forceRefresh,
    );
    return UserGoals.fromJson(data);
  }

  // Save goals and return calculated calorie/macro targets
  static Future<UserGoals> saveGoals({
    required String uid,
    required double goalWeight,
    required String weeklyGoal,
    required String activityLevel,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/goals/$uid'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'goal_weight': goalWeight,
            'weekly_goal': weeklyGoal,
            'activity_level': activityLevel,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to save goals: ${response.body}');
    }
    return UserGoals.fromJson(jsonDecode(response.body));
  }

  // Get user profile (served from the on-disk cache)
  static Future<Map<String, dynamic>> getUserProfile({
    required String uid,
    bool forceRefresh = false,
  }) async {
    return CacheService.instance.getJson(
      '$baseUrl/user/$uid',
      cacheKey: CacheService.profileKey(uid),
      forceRefresh: forceRefresh,
    );
  }
}
