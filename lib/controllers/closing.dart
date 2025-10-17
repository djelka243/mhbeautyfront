import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mh_beauty/controllers/user.dart';

class ClosingController extends ChangeNotifier {
  final GetStorage _storage = GetStorage();

  bool isClosed = false;
  bool loading = false;
  Map<String, dynamic>? todaySummary;
  Map<String, dynamic>? currentClosing;

  Map<String, String> getAuthHeaders() {
    final token = _storage.read('jwt_token');
    if (token == null) {
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Vérifier si la caisse a déjà été clôturée aujourd'hui
  Future<void> checkTodayClosing() async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/closings/check-today');
      final resp = await http.get(url, headers: getAuthHeaders());

      debugPrint('checkTodayClosing response -> status: ${resp.statusCode}, body: ${resp.body}');

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        isClosed = js['is_closed'] ?? false;
        currentClosing = js['closing'];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('checkTodayClosing exception: $e');
    }
  }

  /// Obtenir le résumé des ventes du jour
  Future<void> fetchTodaySummary() async {
    loading = true;
    notifyListeners();

    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/closings/today-summary');
      final resp = await http.get(url, headers: getAuthHeaders());

      debugPrint('fetchTodaySummary response -> status: ${resp.statusCode}, body: ${resp.body}');

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        todaySummary = js['data'];
      }
    } catch (e) {
      debugPrint('fetchTodaySummary exception: $e');
    }

    loading = false;
    notifyListeners();
  }

  /// Effectuer la clôture de caisse
  Future<Map<String, dynamic>> performClosing({String? notes}) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/closings/perform');
      final body = jsonEncode({
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });

      debugPrint('performClosing request -> $url, body: $body');
      final resp = await http.post(url, headers: getAuthHeaders(), body: body);
      debugPrint('performClosing response -> status: ${resp.statusCode}, body: ${resp.body}');

      final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};

      if (resp.statusCode == 201) {
        isClosed = true;
        currentClosing = js['data'];
        notifyListeners();
        return {'success': true, 'data': js['data']};
      }

      return {
        'success': false,
        'message': js is Map ? (js['message'] ?? resp.body) : resp.body,
      };
    } catch (e) {
      debugPrint('performClosing exception: $e');
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }

  /// Obtenir l'historique des clôtures
  Future<List<Map<String, dynamic>>> fetchClosingsHistory({
    String? startDate,
    String? endDate,
  }) async {
    try {
      var url = '${UserController.apiBaseUrl}/closings';
      if (startDate != null || endDate != null) {
        final params = <String, String>{};
        if (startDate != null) params['start_date'] = startDate;
        if (endDate != null) params['end_date'] = endDate;
        url += '?${Uri(queryParameters: params).query}';
      }

      final resp = await http.get(Uri.parse(url), headers: getAuthHeaders());
      debugPrint('fetchClosingsHistory response -> status: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        if (js['data'] is List) {
          return List<Map<String, dynamic>>.from(js['data']);
        }
      }
    } catch (e) {
      debugPrint('fetchClosingsHistory exception: $e');
    }

    return [];
  }
}