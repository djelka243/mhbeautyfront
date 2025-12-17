import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mh_beauty/controllers/user.dart';

class SaleController extends ChangeNotifier {
  final GetStorage _storage = GetStorage();

  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> sales = []; // Historique des ventes
  bool loading = false;
  String? searchError;

  Timer? _searchDebounce;
  String _lastQuery = '';

  Map<String, String> getAuthHeaders() {
    final token = _storage.read('jwt_token');
    if (token == null) {
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Getter pour calculer le nombre de ventes du jour
  int get salesToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return sales.where((sale) {
      try {
        final saleDate = DateTime.parse(sale['created_at']);
        return saleDate.isAfter(today);
      } catch (e) {
        return false;
      }
    }).length;
  }

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
            })
            .where((m) => m.isNotEmpty)
            .toList();
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
              })
              .where((m) => m.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('parse list error: $e');
    }
    return [];
  }

   Future<void> fetchSalesHistory() async {
    try {
      // Récupérer toutes les ventes avec pagination
      final allSales = <Map<String, dynamic>>[];
      int page = 1;
      int perPage = 100; // Récupérer 100 ventes par page
      bool hasMore = true;

      while (hasMore) {
        final url = Uri.parse(
          '${UserController.apiBaseUrl}/sales?page=$page&per_page=$perPage',
        );
        final resp = await http.get(url, headers: getAuthHeaders());
        debugPrint(
          'fetchSalesHistory response -> page: $page, status: ${resp.statusCode}',
        );

        if (resp.statusCode == 200) {
          final js = jsonDecode(resp.body);
          final pageData = _listFromJson(js['data']);

          if (pageData.isEmpty) {
            hasMore = false;
          } else {
            allSales.addAll(pageData);
            page++;
          }
        } else {
          // Gérer les erreurs
          hasMore = false;
        }
      }

      sales = allSales;
      debugPrint('fetchSalesHistory total sales: ${sales.length}');
    } catch (e) {
      debugPrint('fetchSalesHistory exception: $e');
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> fetchSaleDetail(String saleId) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/sales/$saleId');
      final resp = await http.get(url, headers: getAuthHeaders());

      debugPrint('fetchSaleDetail response -> status: ${resp.statusCode}, body: ${resp.body}');

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        final sale = js['data'];

        if (sale == null) return null;

        final products = (sale['products'] as List?) ?? [];

        // Fonction utilitaire pour un parsing plus sûr
        double parseDouble(dynamic value) {
          if (value == null) return 0.0;
          if (value is num) return value.toDouble();
          return double.tryParse(value.toString()) ?? 0.0;
        }

        return {
          'id': sale['id'],
          'invoice_number': sale['invoice_number'],
          'client': sale['customer_name'] ?? 'Client inconnu',
          'phone': sale['customer_phone'] ?? '-',
          'amount': parseDouble(sale['amount_given']),
          'currency': sale['payment_currency'],
          'exchange': parseDouble(sale['exchange_rate']),
          'delivery': parseDouble(sale['delivery_fee']),
          'returned': parseDouble(sale['change_returned']),
          'date': sale['sale_date'] ?? sale['created_at'],
          'status': sale['status'],
          'subtotal': parseDouble(sale['subtotal']),
          'total': parseDouble(sale['total']),
          'user': sale['user'],
          'products': products.map((p) {
            return {
              'id': p['id'],
              'name': p['name'],
              'quantity': p['quantity'],
              'unit_price': p['unit_price'],
              'subtotal': p['subtotal'],
            };
          }).toList(),
        };
      } else {
        debugPrint('Erreur lors du chargement du détail: ${resp.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('fetchSaleDetail exception: $e');
      return null;
    }
  }

  Future<void> searchProducts(String query) async {
    _lastQuery = query;
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      searchResults = [];
      searchError = null;
      notifyListeners();
      return;
    }

    // Debounce: attendre 350ms avant de lancer la recherche
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _lastQuery;
      if (q.trim().isEmpty) {
        searchResults = [];
        loading = false;
        searchError = null;
        notifyListeners();
        return;
      }

      loading = true;
      searchError = null;
      notifyListeners();

      try {
        // Utiliser la route de recherche dédiée
        final url = Uri.parse(
          '${UserController.apiBaseUrl}/products/search?q=${Uri.encodeComponent(q)}',
        );
        final headers = getAuthHeaders();

        debugPrint('searchProducts -> $url');
        final resp = await http.get(url, headers: headers);
        debugPrint(
          'searchProducts response -> status: ${resp.statusCode}, body: ${resp.body}',
        );

        if (resp.statusCode == 200) {
          final js = jsonDecode(resp.body);
          searchResults = _listFromJson(js);
          searchError = null;

          if (searchResults.isEmpty) {
            searchError = 'Aucun produit trouvé';
          }
        } else if (resp.statusCode == 401 || resp.statusCode == 403) {
          searchError = 'Session expirée, reconnectez-vous';
        } else {
          searchError = 'Erreur de recherche (${resp.statusCode})';
        }
      } catch (e) {
        debugPrint('searchProducts exception: $e');
        searchError = 'Erreur réseau: $e';
        searchResults = [];
      }

      loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  bool addProductToCart(Map<String, dynamic> product, {int quantity = 1}) {
    final id = product['id'];
    if (id == null) return false;

    // Vérifier le stock
    final available =
        (product['stock'] is num)
            ? (product['stock'] as num).toInt()
            : int.tryParse(product['stock']?.toString() ?? '') ?? -1;

    final idx = cart.indexWhere((c) => c['id'] == id);
    final currentQty = idx >= 0 ? ((cart[idx]['quantity'] ?? 0) as int) : 0;

    if (available >= 0 && (currentQty + quantity) > available) {
      return false; // Stock insuffisant
    }

    if (idx >= 0) {
      cart[idx]['quantity'] = currentQty + quantity;
    } else {
      final item = Map<String, dynamic>.from(product);
      item['quantity'] = quantity;
      cart.add(item);
    }

    notifyListeners();
    return true;
  }

  void removeProductFromCart(dynamic productId) {
    cart.removeWhere((c) => c['id'] == productId);
    notifyListeners();
  }

  bool incrementQuantity(dynamic productId) {
    final idx = cart.indexWhere((c) => c['id'] == productId);
    if (idx >= 0) {
      final item = cart[idx];
      final available =
          (item['stock'] is num)
              ? (item['stock'] as num).toInt()
              : int.tryParse(item['stock']?.toString() ?? '') ?? -1;
      final current = (item['quantity'] ?? 0) as int;

      if (available >= 0 && (current + 1) > available) {
        return false;
      }

      cart[idx]['quantity'] = current + 1;
      notifyListeners();
      return true;
    }
    return false;
  }

  void decrementQuantity(dynamic productId) {
    final idx = cart.indexWhere((c) => c['id'] == productId);
    if (idx >= 0) {
      final q = (cart[idx]['quantity'] ?? 1) - 1;
      if (q <= 0) {
        cart.removeAt(idx);
      } else {
        cart[idx]['quantity'] = q;
      }
      notifyListeners();
    }
  }

  double get total {
    double t = 0.0;
    for (final it in cart) {
      final price =
          (it['price'] is num)
              ? (it['price'] as num).toDouble()
              : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
      final qty =
          (it['quantity'] is num)
              ? (it['quantity'] as num).toDouble()
              : double.tryParse(it['quantity']?.toString() ?? '0') ?? 0.0;
      t += price * qty;
    }
    return t;
  }

  // Récupérer le taux de change depuis l'API
  Future<double> fetchExchangeRate() async {
    try {
      final url = Uri.parse(
        '${UserController.apiBaseUrl}/exchange-rates/latest',
      );
      final resp = await http.get(url, headers: getAuthHeaders());

      debugPrint(
        'fetchExchangeRate response -> status: ${resp.statusCode}, body: ${resp.body}',
      );

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        // Supposons que l'API retourne: {"data": {"rate": 2500, "currency": "CDF"}}
        if (js is Map && js['data'] != null) {
          final rate = js['data']['rate'];
          if (rate is num) {
            return rate.toDouble();
          }
        }
      }
    } catch (e) {
      debugPrint('fetchExchangeRate exception: $e');
    }

    return 2000.0;
  }

  Future<Map<String, dynamic>> submitSale({
    String? clientName,
    String? clientPhone,
    double? deliveryFee,
    String? currency,
    double? amountGiven,
    double? exchangeRate,
  }) async {
    if (cart.isEmpty) {
      return {'success': false, 'message': 'Panier vide'};
    }

    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/sales');

      final items = cart.map((c) {
        final rawId = c['id'];
        final intId = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        return {
          'product_id': intId ?? rawId,
          'quantity': c['quantity'],
        };
      }).toList();

      // ✅ La livraison est TOUJOURS saisie en CDF dans l'app
      // On la convertit en USD pour l'envoyer au backend
      double deliveryInUsd = 0.0;
      if (deliveryFee != null && deliveryFee > 0) {
        deliveryInUsd = deliveryFee / (exchangeRate ?? 1);
      }

      final body = jsonEncode({
        if (clientName != null && clientName.isNotEmpty) 'customer_name': clientName,
        if (clientPhone != null && clientPhone.isNotEmpty) 'customer_phone': clientPhone,
        'products': items,
        if (deliveryInUsd > 0) 'delivery_fee': deliveryInUsd,
        if (currency != null) 'payment_currency': currency,
        if (amountGiven != null && amountGiven > 0) 'amount_given': amountGiven,
        if (exchangeRate != null) 'exchange_rate': exchangeRate,
      });

      debugPrint('submitSale request -> $url, body: $body');
      final resp = await http.post(url, headers: getAuthHeaders(), body: body);
      debugPrint('submitSale response -> status: ${resp.statusCode}, body: ${resp.body}');

      final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        // Vider le panier après succès
        cart.clear();
        searchResults.clear();
        notifyListeners();
        return {'success': true, 'data': js};
      }

      // Gérer spécifiquement l'erreur de caisse clôturée
      if (resp.statusCode == 403) {
        return {
          'success': false,
          'message': js is Map
              ? (js['message'] ?? 'La caisse a été clôturée. Ventes suspendues jusqu\'à demain.')
              : 'La caisse a été clôturée. Ventes suspendues jusqu\'à demain.',
          'is_closed': true,
        };
      }

      return {
        'success': false,
        'message': js is Map ? (js['message'] ?? resp.body) : resp.body
      };
    } catch (e) {
      debugPrint('submitSale exception: $e');
      return {'success': false, 'message': 'Erreur réseau: $e'};
    }
  }




  void increaseQuantity(dynamic productId) {
    final index = cart.indexWhere((item) => item['id'] == productId);
    if (index != -1) {
      // Vérifie que le stock n’est pas dépassé
      final stock = int.tryParse(cart[index]['stock']?.toString() ?? '0') ?? 0;
      final currentQty =
          int.tryParse(cart[index]['quantity']?.toString() ?? '0') ?? 0;

      if (currentQty < stock) {
        cart[index]['quantity'] = currentQty + 1;
        notifyListeners();
      }
    }
  }

  void decreaseQuantity(dynamic productId) {
    final index = cart.indexWhere((item) => item['id'] == productId);
    if (index != -1) {
      final currentQty =
          int.tryParse(cart[index]['quantity']?.toString() ?? '0') ?? 0;
      if (currentQty > 1) {
        cart[index]['quantity'] = currentQty - 1;
      } else {
        cart.removeAt(index);
      }
      notifyListeners();
    }
  }
}
