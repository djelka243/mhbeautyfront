import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mh_beauty/controllers/user.dart';

class ProductController extends ChangeNotifier {
  final GetStorage _storage = GetStorage();

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> categories = [];

  // Getter pour les produits avec un stock faible
  List<Map<String, dynamic>> get lowStockProducts {
    return products.where((p) {
      final stock = p['stock'];
      final alertThreshold = p['alert_threshold'] ?? 10;
      if (stock is num) {
        return stock <= alertThreshold;
      }
      if (stock is String) {
        final stockInt = int.tryParse(stock);
        return stockInt != null && stockInt < alertThreshold;
      }
      return false;
    }).toList();
  }

  int get lowStockProductsCount => lowStockProducts.length;

  Map<String, String> getAuthHeaders() {
    final token = _storage.read('jwt_token');
    if (token == null) return {'Accept': 'application/json'};
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // utilitaire pour parser une réponse JSON en List<Map<String,dynamic>>
  List<Map<String, dynamic>> _listFromJson(dynamic js) {
    if (js == null) return [];
    try {
      if (js is List) {
        return js
            .where((e) => e != null)
            .map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).where((m) => m.isNotEmpty).toList();
      }
      if (js is Map) {
        final inner = js['data'];
        if (inner is List) {
          return inner
              .where((e) => e != null)
              .map<Map<String, dynamic>>((e) {
            if (e is Map<String, dynamic>) return e;
            if (e is Map) return Map<String, dynamic>.from(e);
            return <String, dynamic>{};
          }).where((m) => m.isNotEmpty).toList();
        }
        // parfois la liste peut être directement sous une clé différente
      }
    } catch (e) {
      debugPrint('parse list error: $e');
    }
    return [];
  }

  Future<void> fetchCategories() async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/categories');
      final resp = await http.get(url, headers: getAuthHeaders());
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        categories = _listFromJson(js);
        notifyListeners();
      } else {
        debugPrint('fetchCategories failed: ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchCategories exception: $e');
    }
  }

  Future<void> fetchProducts() async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/products');
      final resp = await http.get(url, headers: getAuthHeaders());
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        products = _listFromJson(js);
        notifyListeners();
      } else {
        debugPrint('fetchProducts failed: ${resp.body}');
      }
    } catch (e) {
      debugPrint('fetchProducts exception: $e');
    }
  }

  Future<Map<String, dynamic>> fetchProduct(int id) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/products/$id');
      final resp = await http.get(url, headers: getAuthHeaders());
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        // gérer plusieurs formes de réponse : {data: {...}} ou {...} ou [ ... ]
        if (js is Map && js.containsKey('data')) {
          return {'success': true, 'data': js['data']};
        }
        // si le backend renvoie directement l'objet produit
        if (js is Map) return {'success': true, 'data': js};
        // improbable mais gérer le cas d'une liste contenant un seul élément
        if (js is List && js.isNotEmpty) {
          final first = js.first;
          if (first is Map) return {'success': true, 'data': Map<String, dynamic>.from(first)};
        }
        return {'success': false, 'message': 'Réponse inattendue du serveur'};
      }
      return {'success': false, 'message': resp.body};
    } catch (e) {
      debugPrint('fetchProduct exception: $e');
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/products');
      final resp = await http.post(url, headers: getAuthHeaders(), body: jsonEncode(payload));
      final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      if (resp.statusCode == 201 || resp.statusCode == 200) {
        // Optionnel: ajouter au cache local
        final newProd = (js is Map && js.containsKey('data')) ? js['data'] : js;
        if (newProd is Map<String, dynamic>) products.add(newProd);
        notifyListeners();
        return {'success': true, 'data': newProd};
      }
      return {'success': false, 'message': js is Map ? (js['message'] ?? resp.body) : resp.body};
    } catch (e) {
      debugPrint('createProduct exception: $e');
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }

  Future<Map<String, dynamic>> updateProduct(int id, Map<String, dynamic> payload) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/products/$id');
      final resp = await http.put(url, headers: getAuthHeaders(), body: jsonEncode(payload));
      final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      if (resp.statusCode == 200) {
        final updated = (js is Map && js.containsKey('data')) ? js['data'] : js;
        // Mettre à jour cache local
        final idx = products.indexWhere((p) => p['id'] == id);
        if (idx >= 0 && updated is Map<String, dynamic>) {
          products[idx] = Map<String, dynamic>.from(updated);
          notifyListeners();
        }
        return {'success': true, 'data': updated};
      }
      return {'success': false, 'message': js is Map ? (js['message'] ?? resp.body) : resp.body};
    } catch (e) {
      debugPrint('updateProduct exception: $e');
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/products/$id');
      final resp = await http.delete(url, headers: getAuthHeaders());
      if (resp.statusCode == 200 || resp.statusCode == 204) {
        products.removeWhere((p) => p['id'] == id);
        notifyListeners();
        return true;
      }
      debugPrint('deleteProduct failed: ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('deleteProduct exception: $e');
      return false;
    }
  }





  // -------------------- 🔥 GESTION DES NOTIFS --------------------

  // Liste des notifications non lues
  List<Map<String, dynamic>> get unreadLowStockProducts =>
      lowStockProducts.where((p) => !isProductRead(p)).toList();

// Nombre de notifications non lues
  int get unreadLowStockCount => unreadLowStockProducts.length;


  bool isProductRead(Map<String, dynamic> product) {
    final updatedAt = DateTime.tryParse(product['updated_at']?.toString() ?? '');
    if (updatedAt == null) return true;

    final key = 'notif_read_${product['id']}';
    final lastReadAt = DateTime.tryParse(_storage.read(key)?.toString() ?? '');
    return lastReadAt != null && lastReadAt.isAfter(updatedAt);
  }

  void markProductAsRead(int productId) {
    final key = 'notif_read_$productId';
    _storage.write(key, DateTime.now().toIso8601String());
    notifyListeners();
  }

  void markAllAsRead() {
    for (var p in lowStockProducts) {
      final key = 'notif_read_${p['id']}';
      _storage.write(key, DateTime.now().toIso8601String());
    }
    notifyListeners();
  }






}