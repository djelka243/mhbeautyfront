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
  List<Map<String, dynamic>> sales = [];
  bool loading = false;
  bool loadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? searchError;
  double totalRevenue = 0.0;
  int totalCount = 0;

  Timer? _searchDebounce;
  String _lastQuery = '';

  bool get hasMore => _hasMore;

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

  int get salesToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return sales.where((sale) {
      try {
        final dString = sale['sale_date'] ?? sale['created_at'];
        if (dString == null) return false;
        final saleDate = DateTime.parse(dString);
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
        return js.where((e) => e != null).map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();
      }
      if (js is Map && js['data'] is List) {
        return (js['data'] as List)
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('parse list error: $e');
    }
    return [];
  }

  Future<void> fetchSalesHistory({
    bool refresh = false,
    String? date,
    int? month,
    int? year,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      sales = [];
      totalRevenue = 0.0;
      totalCount = 0;
      loading = true;
      notifyListeners();
    } else {
      if (!_hasMore || loadingMore) return;
      loadingMore = true;
      notifyListeners();
    }

    try {
      const perPage = 20;
      var urlStr =
          '${UserController.apiBaseUrl}/sales?page=$_currentPage&per_page=$perPage';
      if (date != null) urlStr += '&date=$date';
      if (month != null) urlStr += '&month=$month';
      if (year != null) urlStr += '&year=$year';

      final url = Uri.parse(urlStr);
      final resp = await http.get(url, headers: getAuthHeaders());

      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);

        // CA et count total retournés par le backend (stables, avant pagination)
        if (js is Map) {
          totalRevenue =
              double.tryParse(js['total_revenue']?.toString() ?? '0') ?? 0.0;
          totalCount =
              int.tryParse(js['total_count']?.toString() ?? '0') ?? 0;
        }

        final pageData = _listFromJson(js);
        if (pageData.isEmpty) {
          _hasMore = false;
        } else {
          sales.addAll(pageData);
          _currentPage++;
          if (pageData.length < perPage) _hasMore = false;
        }
      } else {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('fetchSalesHistory exception: $e');
      _hasMore = false;
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> fetchSaleDetail(String saleId) async {
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/sales/$saleId');
      final resp = await http.get(url, headers: getAuthHeaders());
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        final sale = js['data'];
        if (sale == null) return null;
        final products = (sale['products'] as List?) ?? [];
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
          'products': products.map((p) => {
            'id': p['id'],
            'name': p['name'],
            'quantity': p['quantity'],
            'unit_price': p['unit_price'],
            'subtotal': p['subtotal'],
          }).toList(),
        };
      }
      return null;
    } catch (e) {
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
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final q = _lastQuery;
      if (q.trim().isEmpty) return;
      loading = true;
      notifyListeners();
      try {
        final url = Uri.parse(
            '${UserController.apiBaseUrl}/products/search?q=${Uri.encodeComponent(q)}');
        final resp = await http.get(url, headers: getAuthHeaders());
        if (resp.statusCode == 200) {
          searchResults = _listFromJson(jsonDecode(resp.body));
          searchError = searchResults.isEmpty ? 'Aucun produit trouvé' : null;
        }
      } catch (e) {
        searchError = 'Erreur réseau';
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
    final available = (product['stock'] is num)
        ? (product['stock'] as num).toInt()
        : int.tryParse(product['stock']?.toString() ?? '') ?? -1;
    final idx = cart.indexWhere((c) => c['id'] == id);
    final currentQty = idx >= 0 ? (cart[idx]['quantity'] as int) : 0;
    if (available >= 0 && (currentQty + quantity) > available) return false;
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
      final available = (item['stock'] is num)
          ? (item['stock'] as num).toInt()
          : int.tryParse(item['stock']?.toString() ?? '') ?? -1;
      final current = (item['quantity'] ?? 0) as int;
      if (available >= 0 && (current + 1) > available) return false;
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

  void increaseQuantity(dynamic productId) {
    final index = cart.indexWhere((item) => item['id'] == productId);
    if (index != -1) {
      final stock =
          int.tryParse(cart[index]['stock']?.toString() ?? '0') ?? 0;
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

  double get total {
    double t = 0.0;
    for (final it in cart) {
      final price = (it['price'] is num)
          ? (it['price'] as num).toDouble()
          : double.tryParse(it['price']?.toString() ?? '0') ?? 0.0;
      final qty = (it['quantity'] is num)
          ? (it['quantity'] as num).toDouble()
          : double.tryParse(it['quantity']?.toString() ?? '0') ?? 0.0;
      t += price * qty;
    }
    return t;
  }

  Future<double> fetchExchangeRate() async {
    try {
      final url =
      Uri.parse('${UserController.apiBaseUrl}/exchange-rates/latest');
      final resp = await http.get(url, headers: getAuthHeaders());
      if (resp.statusCode == 200) {
        final js = jsonDecode(resp.body);
        if (js is Map && js['data'] != null && js['data']['rate'] is num) {
          return js['data']['rate'].toDouble();
        }
      }
    } catch (e) {}
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
    if (cart.isEmpty) return {'success': false, 'message': 'Panier vide'};
    try {
      final url = Uri.parse('${UserController.apiBaseUrl}/sales');
      final items = cart
          .map((c) => {
        'product_id': c['id'] is int
            ? c['id']
            : int.tryParse(c['id'].toString()),
        'quantity': c['quantity'],
      })
          .toList();
      double deliveryInUsd =
      (deliveryFee != null && deliveryFee > 0)
          ? deliveryFee / (exchangeRate ?? 1)
          : 0.0;
      final body = jsonEncode({
        if (clientName != null && clientName.isNotEmpty)
          'customer_name': clientName,
        if (clientPhone != null && clientPhone.isNotEmpty)
          'customer_phone': clientPhone,
        'products': items,
        if (deliveryInUsd > 0) 'delivery_fee': deliveryInUsd,
        if (currency != null) 'payment_currency': currency,
        if (amountGiven != null && amountGiven > 0) 'amount_given': amountGiven,
        if (exchangeRate != null) 'exchange_rate': exchangeRate,
      });
      final resp =
      await http.post(url, headers: getAuthHeaders(), body: body);
      final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        cart.clear();
        searchResults.clear();
        notifyListeners();
        return {'success': true, 'data': js};
      }
      return {
        'success': false,
        'message': js['message'] ?? 'Erreur lors de la vente'
      };
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }
}