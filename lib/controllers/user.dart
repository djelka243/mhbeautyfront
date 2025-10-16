import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as p;
import 'package:printing/printing.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'package:pdf/pdf.dart';

class UserController extends ChangeNotifier {
	// Instance de stockage persistante
	final GetStorage _storage = GetStorage();

	// Clés utilisées dans le stockage
	static const String _tokenKey = 'jwt_token';
	static const String _userKey = 'user';
	static const String _darkModeKey = 'dark_mode';

static const String apiBaseUrl = 'http://mhbeautyprod.eu-north-1.elasticbeanstalk.com/api/v1';

	// État interne
	String? _token;
	Map<String, dynamic>? _user;
	bool _darkMode = false;
	List<Map<String, dynamic>> categories = [];

	// Getter utilitaire pour savoir si l'utilisateur est admin
	bool get isAdmin {
		final user = _user;
		if (user == null) return false;
		final dynamic roleField = user['role'] ?? user['roles'];
		if (roleField == null) return false;
		if (roleField is String) {
			return roleField.toLowerCase() == 'admin';
		} else if (roleField is Map) {
			final name = roleField['name'] ?? roleField['role'];
			return name is String && name.toLowerCase() == 'admin';
		} else if (roleField is List) {
			return roleField.map((e) => e.toString().toLowerCase()).contains('admin');
		}
		return false;
	}

	UserController() {
		_init();
	}

	// ===================== INIT =====================
	Future<void> _init() async {
		try {
			await GetStorage.init();
			_token = _storage.read(_tokenKey);
			final savedUser = _storage.read(_userKey);
			if (savedUser is Map) {
				_user = Map<String, dynamic>.from(savedUser);
			}

			final savedDarkMode = _storage.read(_darkModeKey);
			if (savedDarkMode is bool) _darkMode = savedDarkMode;

			notifyListeners();
		} catch (e) {
			debugPrint('Erreur init storage: $e');
		}
	}

	// ===================== AUTH =====================
	bool get isAuthenticated => _token != null;
	Map<String, dynamic>? get user => _user;
	bool get darkMode => _darkMode;

	Future<String?> _getToken() async => _storage.read(_tokenKey);

	Map<String, String> getAuthHeaders() {
		final token = _storage.read(_tokenKey);
		if (token == null) return {'Accept': 'application/json'};
		return {
			'Content-Type': 'application/json',
			'Accept': 'application/json',
			'Authorization': 'Bearer $token',
		};
	}

	Future<Map<String, dynamic>> login(String email, String password) async {

		final url = Uri.parse("$apiBaseUrl/login");
		try {
			final resp = await http.post(
				url,
				body: jsonEncode({'email': email, 'password': password}),
				headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
			);

			final js = jsonDecode(resp.body) as Map<String, dynamic>;
			if (resp.statusCode == 200 && js['token'] != null) {
				_token = js['token'];
				_user = js['user'];

				await _storage.write(_tokenKey, _token);
				if (_user != null) await _storage.write(_userKey, _user);

				notifyListeners();
				return {'success': true};
				print(js['message']);
			} else {
				print(js['message']);
				return {'success': false, 'message': js['message'] ?? 'Échec de connexion'};
			}
		} catch (e) {

			debugPrint('Login exception: $e');
			return {'success': false, 'message': 'Erreur réseau : $e'};
		}
	}


	Future<bool> register(String name, String email, String password, {String? passwordConfirmation}) async {
		final url = Uri.parse("$apiBaseUrl/register");
		try {
			final body = { 'name': name, 'email': email, 'password': password, };
			if (passwordConfirmation != null)
				body['password_confirmation'] = passwordConfirmation;
			final resp = await http.post(url, body: convert.jsonEncode(body),
					headers: {
						'Content-Type': 'application/json',
						'Accept': 'application/json'
			});
			if (resp.statusCode == 200 || resp.statusCode == 201) {
				final js = convert.jsonDecode(resp.body) as Map<String, dynamic>;
				_token = js['token'] ?? js['access_token'] ?? js['data']?['token'];
				_user = js['user'] ?? js['data']?['user'] ?? js['data'];
				if (_token != null) { if (_storage != null) {
					await _storage!.write(_tokenKey, _token);
					if (_user != null) await _storage!.write(_userKey, _user);
				}
				notifyListeners();
					return true;
				}
			}
		} catch (e) { }
		return false;
	}

	Future<void> logout() async {
		_token = null;
		_user = null;
		await _storage.remove(_tokenKey);
		await _storage.remove(_userKey);
		notifyListeners();
	}

	// ===================== CATEGORIES =====================
	Future<Map<String, dynamic>> createCategory(String name, String description) async {
		final url = Uri.parse("$apiBaseUrl/categories");
		try {
			final resp = await http.post(
				url,
				headers: getAuthHeaders(),
				body: jsonEncode({'name': name, 'description': description}),
			);

			final js = jsonDecode(resp.body);
			if (resp.statusCode == 201 || resp.statusCode == 200) {
				await fetchCategories();
				return {'success': true, 'message': js['message'] ?? 'Catégorie créée'};
			} else {
				return {'success': false, 'message': js['message'] ?? 'Erreur lors de la création'};
			}
		} catch (e) {
			debugPrint('Erreur createCategory: $e');
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}

	Future<void> fetchCategories() async {
		try {
			final resp = await http.get(
				Uri.parse("$apiBaseUrl/categories"),
				headers: getAuthHeaders(),
			);

			if (resp.statusCode == 200) {
				final js = jsonDecode(resp.body);
				categories = List<Map<String, dynamic>>.from(js['data'] ?? []);
				notifyListeners();
			} else {
				debugPrint('Erreur fetchCategories: ${resp.body}');
			}
		} catch (e) {
			debugPrint('Erreur réseau fetchCategories: $e');
		}
	}

	Future<bool> deleteCategory(int id) async {
		try {
			final resp = await http.delete(
				Uri.parse("$apiBaseUrl/categories/$id"),
				headers: getAuthHeaders(),
			);

			if (resp.statusCode == 200 || resp.statusCode == 204) {
				categories.removeWhere((c) => c['id'] == id);
				notifyListeners();
				return true;
			} else {
				debugPrint('Erreur delete: ${resp.body}');
				return false;
			}
		} catch (e) {
			debugPrint('Erreur deleteCategory: $e');
			return false;
		}
	}

	// ===================== UTILISATEUR =====================
	Future<Map<String, dynamic>> updateProfile(String name, String email) async {
		final url = Uri.parse("$apiBaseUrl/update-profile");
		//diff  entre put et patch
		try {
			final resp = await http.patch(
				url,
				headers: getAuthHeaders(),
				body: jsonEncode({'name': name, 'email': email}),
			);
			final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
			if (resp.statusCode == 200) {
				_user = js['user'] ?? js['data'] ?? _user ?? {};
				await _storage.write(_userKey, _user);
				notifyListeners();
				return {'success': true};
			} else {
				return {'success': false, 'message': js['message'] ?? 'Erreur mise à jour'};
			}
		} catch (e) {
			debugPrint('updateProfile: $e');
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}

	Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword, String confirmPassword) async {
		  final url = Uri.parse("$apiBaseUrl/update-password");
		try {
			final resp = await http.put(
				url,
				headers: getAuthHeaders(),
				body: jsonEncode({
					'current_password': currentPassword,
					'new_password': newPassword,
					'new_password_confirmation': confirmPassword,
				}),
			);
			final js = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
			if (resp.statusCode == 200) {
				return {'success': true};
			} else {
				return {'success': false, 'message': js['message'] ?? 'Erreur changement de mot de passe'};
			}
		} catch (e) {
			debugPrint('changePassword: $e');
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}



	// ===================== IMPRESSION PDF =====================



	Future<void> printInvoice(BuildContext context, Map<String, dynamic> sale) async {
		final doc = pw.Document();

		final items = (sale['products'] as List<dynamic>?) ?? [];

		final dateStr = sale['sale_date'] ?? sale['created_at'] ?? DateTime.now().toString();
		DateTime parsedDate;
		try {
			parsedDate = DateTime.parse(dateStr).toLocal();
		} catch (_) {
			parsedDate = DateTime.now();
		}
		final formattedDate = '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2,'0')}:${parsedDate.minute.toString().padLeft(2,'0')}';

		final currency = sale['currency'] ?? '';
		final amountGiven = sale['amount']?.toStringAsFixed(2) ?? '0.00';
		final changeReturned = sale['returned']?.toStringAsFixed(2) ?? '0.00';
		final deliveryFee = sale['delivery_fee']?.toStringAsFixed(2) ?? '0.00';
		final subtotal = sale['subtotal']?.toStringAsFixed(2) ?? '0.00';
		final total = sale['total']?.toStringAsFixed(2) ?? '0.00';

		doc.addPage(
			pw.Page(
				pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 5),
				build: (pw.Context context) {
					return pw.Column(
						crossAxisAlignment: pw.CrossAxisAlignment.start,
						children: [
							pw.Center(
								child: pw.Text('MH Beauty & Création', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
							),
							pw.SizedBox(height: 2),
							pw.Divider(),
							pw.Text('Facture #: ${sale['invoice_number']}', style: pw.TextStyle(fontSize: 8)),
							pw.Text('Vendu par: ${sale['user']?['name'] ?? 'Inconnu'}', style: pw.TextStyle(fontSize: 8)),
							pw.Text('Client: ${sale['client'] ?? '-'}', style: pw.TextStyle(fontSize: 8)),
							pw.Text('Téléphone: ${sale['phone'] ?? '-'}', style: pw.TextStyle(fontSize: 8)),
							pw.Text('Date: $formattedDate', style: pw.TextStyle(fontSize: 8)),
							pw.Divider(),

							// Articles
							...items.map((it) {
								final name = it['name'] ?? '';
								final qty = it['quantity'] ?? 0;
								final unitPrice = it['unit_price']?.toStringAsFixed(2) ?? '0.00';
								final totalItem = (it['quantity'] != null && it['unit_price'] != null)
										? (it['quantity'] * it['unit_price']).toStringAsFixed(2)
										: '0.00';

								return pw.Column(
									crossAxisAlignment: pw.CrossAxisAlignment.start,
									children: [
										pw.Row(
											mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
											children: [
												pw.Expanded(child: pw.Text(name, style: pw.TextStyle(fontSize: 9))),
												pw.Text(totalItem, style: pw.TextStyle(fontSize: 9)),
											],
										),
										pw.Text('$qty x $unitPrice', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
									],
								);
							}),

							pw.Divider(),
							pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
								pw.Text('Sous-total:', style: pw.TextStyle(fontSize: 9)),
								pw.Text('$subtotal \$', style: pw.TextStyle(fontSize: 9)),
							]),
							if (double.tryParse(deliveryFee) != null && double.parse(deliveryFee) > 0)
								pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
									pw.Text('Livraison:', style: pw.TextStyle(fontSize: 9)),
									pw.Text('$deliveryFee Fc', style: pw.TextStyle(fontSize: 9)),
								]),
							pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
								pw.Text('Montant donné:', style: pw.TextStyle(fontSize: 9)),
								pw.Text('$amountGiven $currency', style: pw.TextStyle(fontSize: 9)),
							]),
							pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
								pw.Text('Monnaie rendue:', style: pw.TextStyle(fontSize: 9)),
								pw.Text('$changeReturned $currency', style: pw.TextStyle(fontSize: 9)),
							]),
							pw.Divider(),
							pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
								pw.Text('Total TTC:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
								pw.Text('$total \$', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
							]),
							pw.SizedBox(height: 10),
							pw.Center(child: pw.Text('Merci pour votre achat', style: pw.TextStyle(fontSize: 8))),
						],
					);
				},
			),
		);

		try {
			await Printing.layoutPdf(onLayout: (format) => doc.save());
		} catch (e) {
			ScaffoldMessenger.of(context)
					.showSnackBar(SnackBar(content: Text('Erreur d\'impression: $e')));
		}
	}


// ===================== DEVISE =====================

	Future<Map<String, dynamic>> fetchCurrencyRate() async {
		final url = Uri.parse("$apiBaseUrl/taux");
		try {
			final resp = await http.get(url, headers: getAuthHeaders());
			if (resp.statusCode == 200) {
				final js = convert.jsonDecode(resp.body) as Map<String, dynamic>;
				// On récupère "taux" depuis data
				final tauxData = js['data'] as Map<String, dynamic>;
				return {'success': true, 'valeur': tauxData['valeur']};
			}
			return {'success': false, 'message': resp.body};
		} catch (e) {
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}

	Future<Map<String, dynamic>> saveCurrencyRate(double rate) async {
		final url = Uri.parse("$apiBaseUrl/taux");
		try {
			final resp = await http.post(
				url,
				headers: getAuthHeaders(),
				body: convert.jsonEncode({'valeur': rate}),
			);
			if (resp.statusCode == 200 || resp.statusCode == 201) {
				final js = convert.jsonDecode(resp.body);
				return {'success': true, 'message': js['message'] ?? 'Taux enregistré'};
			} else {
				final js = convert.jsonDecode(resp.body);
				print(js['message']);
				return {'success': false, 'message': js['message'] ?? 'Erreur lors de l\'enregistrement'};
			}
		} catch (e) {
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}


// ===================== INFO MAGASIN =====================

	Future<Map<String, dynamic>> saveInfoMagasin(nom, adresse, telephone, email, rccm, nif) async {
		final url = Uri.parse("$apiBaseUrl/info");

		print("Mon tpken: $_token");
		try {
			final resp = await http.post(
				url,
				headers: getAuthHeaders(),
				body: convert.jsonEncode({
					'nom': nom,
					'adresse': adresse,
					'telephone': telephone,
					'email': email,
					'rccm': rccm,
					'nif': nif,
				}),
			);
			if (resp.statusCode == 200 || resp.statusCode == 201) {
				final js = convert.jsonDecode(resp.body);
				return {'success': true, 'message': js['message'] ?? 'Information du magasin enregistrée'};
			} else {
				final js = convert.jsonDecode(resp.body);
				print(js['message']);
				return {'success': false, 'message': js['message'] ?? 'Erreur lors de l\'enregistrement'};
			}
		} catch (e) {
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}

	Future<Map<String, dynamic>> getInfoMagasin() async {
		final url = Uri.parse("$apiBaseUrl/info");
		try {
			final resp = await http.get(url, headers: getAuthHeaders());
			if (resp.statusCode == 200) {
				final js = convert.jsonDecode(resp.body);
				return {'success': true, 'data': js['data']};
			}
			return {'success': false, 'message': 'Erreur de récupération'};
		} catch (e) {
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}

	Future<Map<String, dynamic>> updateInfoMagasin(int? id,String name,String address,String phone,String? email,String? rccm,String? nif) async {

		final url = Uri.parse("$apiBaseUrl/info/edit/$id");
		try {
			final resp = await http.put(
				url,
				headers: getAuthHeaders(),
				body: convert.jsonEncode({
					'nom': name,
					'adresse': address,
					'telephone': phone,
					'email': email,
					'rccm': rccm,
					'nif': nif,
				}),
			);
			if (resp.statusCode == 200) {
				final js = convert.jsonDecode(resp.body);
				return {'success': true, 'message': js['message']};
			}
			final js = convert.jsonDecode(resp.body);
			print(js['message']);
			return {'success': false, 'message': 'Erreur de mise à jour'};
		} catch (e) {
			return {'success': false, 'message': 'Erreur réseau'};
		}
	}


	// ===================== DARK MODE =====================
	Future<void> setDarkMode(bool value) async {
		_darkMode = value;
		await _storage.write(_darkModeKey, value);
		notifyListeners();
	}

	Future<void> toggleDarkMode() async => setDarkMode(!_darkMode);












}
