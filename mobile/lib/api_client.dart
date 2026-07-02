import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Expenza backend REST istemcisi.
///
/// Taban URL platforma göre seçilir:
/// - Android emülatör: 10.0.2.2 (host makineye köprü)
/// - Web/masaüstü/iOS sim: localhost
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  bool get isLoggedIn => _token != null;

  // Backend portu. (8000 bu makinede başka bir süreç tarafından kullanıldığı
  // için 8010 seçildi — uvicorn'u bu portla başlat.)
  static const int port = 8010;

  static String get baseUrl {
    // Web'de dart:io yok; foundation'ın platform bilgisini kullanıyoruz.
    if (kIsWeb) {
      // Sayfanın sunulduğu host üzerinden API'ye bağlan. Böylece hem PC'de
      // (localhost) hem de telefonda (PC'nin LAN IP'si) ek ayar gerekmeden çalışır.
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:$port';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port'; // Android emülatör host köprüsü
    }
    return 'http://localhost:$port';
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<void> register(String email, String password, String name) async {
    final r = await http.post(_u('/auth/register'),
        headers: _headers,
        body: jsonEncode(
            {'email': email, 'password': password, 'display_name': name}));
    if (r.statusCode >= 400) {
      throw _err(r);
    }
  }

  Future<void> login(String email, String password) async {
    // OAuth2 password flow form-encoded bekler.
    final r = await http.post(
      _u('/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );
    if (r.statusCode >= 400) throw _err(r);
    _token = jsonDecode(r.body)['access_token'];
  }

  void logout() => _token = null;

  Future<({String email, String displayName})> getMe() async {
    final r = await http.get(_u('/auth/me'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    final j = jsonDecode(r.body);
    return (email: j['email'] as String, displayName: j['display_name'] as String);
  }

  Future<List<TransactionModel>> getTransactions({
    String? category,
    String? type,
    String? month,
    String? q,
    int limit = 200,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (category != null) params['category'] = category;
    if (type != null) params['type'] = type;
    if (month != null) params['month'] = month;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: params);
    final r = await http.get(uri, headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return (jsonDecode(r.body) as List)
        .map((e) => TransactionModel.fromJson(e))
        .toList();
  }

  Future<void> updateTransaction(
    int id, {
    double? amount,
    String? type,
    String? category,
    String? note,
    String? occurredOn,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    if (type != null) body['type'] = type;
    if (category != null) body['category'] = category;
    if (note != null) body['note'] = note;
    if (occurredOn != null) body['occurred_on'] = occurredOn;
    final r = await http.put(_u('/transactions/$id'),
        headers: _headers, body: jsonEncode(body));
    if (r.statusCode >= 400) throw _err(r);
  }

  Future<TransactionModel> addTransaction({
    required double amount,
    required String type,
    String? category,
    String note = '',
    String? occurredOn,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'type': type,
      'note': note,
    };
    if (category != null) body['category'] = category;
    if (occurredOn != null) body['occurred_on'] = occurredOn;
    final r = await http.post(_u('/transactions'),
        headers: _headers, body: jsonEncode(body));
    if (r.statusCode >= 400) throw _err(r);
    return TransactionModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteTransaction(int id) async {
    final r = await http.delete(_u('/transactions/$id'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
  }

  Future<List<BudgetModel>> getBudgets() async {
    final r = await http.get(_u('/budgets'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return (jsonDecode(r.body) as List)
        .map((e) => BudgetModel.fromJson(e))
        .toList();
  }

  Future<BudgetModel> upsertBudget(String category, double limit) async {
    final r = await http.post(_u('/budgets'),
        headers: _headers,
        body: jsonEncode({'category': category, 'monthly_limit': limit}));
    if (r.statusCode >= 400) throw _err(r);
    return BudgetModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteBudget(int id) async {
    final r = await http.delete(_u('/budgets/$id'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
  }

  Future<ForecastModel> getForecast() async {
    final r = await http.get(_u('/analytics/forecast'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return ForecastModel.fromJson(jsonDecode(r.body));
  }

  Future<List<AnomalyModel>> getAnomalies() async {
    final r = await http.get(_u('/analytics/anomalies'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return (jsonDecode(r.body) as List)
        .map((e) => AnomalyModel.fromJson(e))
        .toList();
  }

  Future<List<InsightModel>> getInsights() async {
    final r = await http.get(_u('/analytics/insights'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return (jsonDecode(r.body) as List)
        .map((e) => InsightModel.fromJson(e))
        .toList();
  }

  // ---- Tasarruf hedefleri ----
  Future<List<GoalModel>> getGoals() async {
    final r = await http.get(_u('/goals'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
    return (jsonDecode(r.body) as List)
        .map((e) => GoalModel.fromJson(e))
        .toList();
  }

  Future<GoalModel> createGoal(String title, double target,
      {String? deadline}) async {
    final body = <String, dynamic>{'title': title, 'target_amount': target};
    if (deadline != null) body['deadline'] = deadline;
    final r = await http.post(_u('/goals'),
        headers: _headers, body: jsonEncode(body));
    if (r.statusCode >= 400) throw _err(r);
    return GoalModel.fromJson(jsonDecode(r.body));
  }

  Future<GoalModel> contributeGoal(int id, double amount) async {
    final r = await http.post(_u('/goals/$id/contribute'),
        headers: _headers, body: jsonEncode({'amount': amount}));
    if (r.statusCode >= 400) throw _err(r);
    return GoalModel.fromJson(jsonDecode(r.body));
  }

  Future<void> deleteGoal(int id) async {
    final r = await http.delete(_u('/goals/$id'), headers: _headers);
    if (r.statusCode >= 400) throw _err(r);
  }

  /// Hero model: not metninden kategori önerisi (canlı).
  Future<CategorySuggestion> categorize(String text) async {
    final r = await http.post(_u('/ml/categorize'),
        headers: _headers, body: jsonEncode({'text': text}));
    if (r.statusCode >= 400) throw _err(r);
    return CategorySuggestion.fromJson(jsonDecode(r.body));
  }

  /// AI Chatbot: Gemini asistanı ile sohbet.
  Future<String> sendChatMessage(String message) async {
    final r = await http.post(_u('/chat'),
        headers: _headers, body: jsonEncode({'message': message}));
    if (r.statusCode >= 400) throw _err(r);
    return jsonDecode(r.body)['reply'] as String;
  }

  Exception _err(http.Response r) {
    try {
      final d = jsonDecode(r.body);
      return Exception(d['detail']?.toString() ?? 'Hata ${r.statusCode}');
    } catch (_) {
      return Exception('Hata ${r.statusCode}');
    }
  }
}
