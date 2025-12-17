import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;

class UserController extends ChangeNotifier {
	// Instance de stockage persistante
	final GetStorage _storage = GetStorage();

	// Clés utilisées dans le stockage
	static const String _tokenKey = 'jwt_token';
	static const String _userKey = 'user';
	static const String _darkModeKey = 'dark_mode';

	static const String apiBaseUrl = 'http://mhbeautyprod.eu-north-1.elasticbeanstalk.com/api/v1';
	//static const String apiBaseUrl = 'http://192.168.11.101:8000/api/v1';

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
			} else {
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
				if (_token != null) {
					await _storage.write(_tokenKey, _token);
					if (_user != null) await _storage.write(_userKey, _user);
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
			final resp = await http.put(
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
				print(js);
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



	// ===================== IMPRESSION PDF =====================

	Future<void> printInvoice2(BuildContext context, Map<String, dynamic> sale) async {
		final doc = pw.Document();

		// Récupérer les informations du magasin via callback
		Map<String, dynamic> storeData = {
			'nom': 'MH Beauty & Création',
			'adresse': '',
			'telephone': '',
			'email': '',
			'rccm': '',
			'nif': '',
		};

		try {
			final storeInfo = await getInfoMagasin();
			if (storeInfo['success'] == true && storeInfo['data'] != null) {
				storeData = {
					'nom': storeInfo['data']['nom'] ?? 'MH Beauty & Création',
					'adresse': storeInfo['data']['adresse'] ?? '',
					'telephone': storeInfo['data']['telephone'] ?? '',
					'email': storeInfo['data']['email'] ?? '',
					'rccm': storeInfo['data']['rccm'] ?? '',
					'nif': storeInfo['data']['nif'] ?? '',
				};
			}
		} catch (e) {
			print('Erreur récupération info magasin: $e');
		}

		// Charger le logo
		pw.ImageProvider? logo;
		try {
			final imageData = await rootBundle.load('assets/images/1.png');
			logo = pw.MemoryImage(imageData.buffer.asUint8List());
		} catch (e) {
			print('Logo non trouvé: $e');
		}

		final items = (sale['products'] as List<dynamic>?) ?? [];

		final dateStr = sale['sale_date'] ?? sale['created_at'] ?? DateTime.now().toString();
		DateTime parsedDate;
		try {
			parsedDate = DateTime.parse(dateStr).toLocal();
		} catch (_) {
			parsedDate = DateTime.now();
		}
		final formattedDate = '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
		final formattedTime = '${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';

		final currency = sale['currency'] ?? '\$';
		final amountGiven = sale['amount']?.toStringAsFixed(2) ?? '0.00';
		final changeReturned = sale['returned']?.toStringAsFixed(2) ?? '0.00';
		final deliveryFee = sale['delivery']?.toStringAsFixed(2) ?? '0.00';
		final subtotal = sale['subtotal']?.toStringAsFixed(2) ?? '0.00';
		final total = sale['total']?.toStringAsFixed(2) ?? '0.00';

		// Récupérer le taux de conversion si la devise est CDF
		final conversionRate = sale['exchange'];
		final isCDF = currency.toUpperCase() == 'CDF' || currency.toUpperCase() == 'FC';

		// Calculer les équivalences en CDF si nécessaire
		String? subtotalCDF;
		String? deliveryFeeCDF;
		String? totalCDF;

		if (isCDF && conversionRate != null) {
			final rate = conversionRate is double ? conversionRate : double.tryParse(conversionRate.toString()) ?? 0;
			if (rate > 0) {
				subtotalCDF = (double.parse(subtotal) * rate).toStringAsFixed(0);
				if (double.tryParse(deliveryFee) != null && double.parse(deliveryFee) > 0) {
					deliveryFeeCDF = (double.parse(deliveryFee) * rate).toStringAsFixed(0);
				}
				totalCDF = (double.parse(total) * rate).toStringAsFixed(0);
			}
		}

		doc.addPage(
			pw.Page(
				pageFormat: PdfPageFormat(210 * PdfPageFormat.mm, double.infinity, marginAll: 2.0),
				build: (pw.Context context) {
					return pw.Column(
						crossAxisAlignment: pw.CrossAxisAlignment.center,
						children: [
							// Logo et nom du magasin
							if (logo != null) ...[
								pw.Image(logo, width: 200, height: 200),
								pw.SizedBox(height: 10),
							],
							pw.Text(
								storeData['nom']!,
								style: pw.TextStyle(
									fontSize: 45,
									fontWeight: pw.FontWeight.bold,
									letterSpacing: 0.5,
								),
								textAlign: pw.TextAlign.center,
							),

							// Informations du magasin
							if (storeData['adresse']!.isNotEmpty) ...[
								pw.SizedBox(height: 5),
								pw.Text(
									storeData['adresse']!,
									style: pw.TextStyle(fontSize: 30, color: PdfColors.grey800),
									textAlign: pw.TextAlign.center,
								),
							],
							if (storeData['email']!.isNotEmpty) ...[
								pw.SizedBox(height: 3),
								pw.Text(
									'Email: ${storeData['email']!}',
									style: pw.TextStyle(fontSize: 30, color: PdfColors.grey800),
									textAlign: pw.TextAlign.center,
								),
							],
							if (storeData['telephone']!.isNotEmpty) ...[
								pw.SizedBox(height: 2),
								pw.Text(
									'Tél: ${storeData['telephone']!}',
									style: pw.TextStyle(fontSize: 30, color: PdfColors.grey800),
									textAlign: pw.TextAlign.center,
								),
							],
							if (storeData['rccm']!.isNotEmpty) ...[
								pw.SizedBox(height: 3),
								pw.Text(
									'RCCM: ${storeData['rccm']!}',
									style: pw.TextStyle(fontSize: 30, color: PdfColors.grey600),
									textAlign: pw.TextAlign.center,
								),
							],
							if (storeData['nif']!.isNotEmpty) ...[
								pw.SizedBox(height: 2),
								pw.Text(
									'NIF: ${storeData['nif']!}',
									style: pw.TextStyle(fontSize: 30, color: PdfColors.grey600),
									textAlign: pw.TextAlign.center,
								),
							],

							pw.SizedBox(height: 3),
							pw.Text(
								'Kinshasa / RDC',
								style: pw.TextStyle(fontSize: 30, color: PdfColors.grey800),
								textAlign: pw.TextAlign.center,
							),
							pw.SizedBox(height: 2),
							pw.Text(
								'Du Lundi au Samedi: 9h - 18h',
								style: pw.TextStyle(fontSize: 30, color: PdfColors.grey800),
								textAlign: pw.TextAlign.center,
							),

							pw.SizedBox(height: 100),

							// Informations facture
							pw.Container(
								width: double.infinity,
								child: pw.Column(
									crossAxisAlignment: pw.CrossAxisAlignment.start,
									children: [
										pw.Row(
											mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
											children: [
												pw.Text(
													'Facture N°',
													style: pw.TextStyle(fontSize: 30, color: PdfColors.grey700),
												),
												pw.Text(
													'${sale['invoice_number'] ?? 'N/A'}',
													style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold),
												),
											],
										),
										pw.SizedBox(height: 5),
										pw.Row(
											mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
											children: [
												pw.Text(
													'Date',
													style: pw.TextStyle(fontSize: 30, color: PdfColors.grey700),
												),
												pw.Text(
													'$formattedDate à $formattedTime',
													style: pw.TextStyle(fontSize: 30),
												),
											],
										),
										pw.SizedBox(height: 5),
										pw.Row(
											mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
											children: [
												pw.Text(
													'Vendeuse',
													style: pw.TextStyle(fontSize: 30, color: PdfColors.grey700),
												),
												pw.Text(
													'${sale['user']?['name'] ?? 'N/A'}',
													style: pw.TextStyle(fontSize: 30),
												),
											],
										),
									],
								),
							),

							// Informations client si présentes
							if (sale['client'] != null &&
									sale['client'].toString().trim() != '-' &&
									sale['client'].toString().isNotEmpty) ...[
								pw.SizedBox(height: 50),
								pw.Container(
									width: double.infinity,
									padding: pw.EdgeInsets.all(8),
									decoration: pw.BoxDecoration(
										color: PdfColors.grey100,
										borderRadius: pw.BorderRadius.circular(4),
									),
									child: pw.Row(
										mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
										//crossAxisAlignment: pw.C,
										children: [
											pw.Text(
												'CLIENT',
												style: pw.TextStyle(
													fontSize: 28,
													fontWeight: pw.FontWeight.bold,
													color: PdfColors.grey700,
												),
											),
											pw.SizedBox(height: 4),
											pw.Text(
												'${sale['client']}',
												style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
											),
											if (sale['phone'] != null &&
													sale['phone'].toString() != '-' &&
													sale['phone'].toString().isNotEmpty) ...[
												pw.SizedBox(height: 2),
												pw.Text(
													'Tél: ${sale['phone']}',
													style: pw.TextStyle(fontSize: 28, color: PdfColors.grey700),
												),
											],
										],
									),
								),
							],

							pw.SizedBox(height: 100),

							// Articles - Prix toujours en USD
							pw.Container(
								width: double.infinity,
								child: pw.Column(
									children: items.map((it) {
										final name = it['name'] ?? 'Article';
										final qty = it['quantity'] ?? 0;
										final unitPrice = it['unit_price']?.toStringAsFixed(2) ?? '0.00';
										final totalItem = (it['quantity'] != null && it['unit_price'] != null)
												? (it['quantity'] * it['unit_price']).toStringAsFixed(2)
												: '0.00';

										return pw.Container(
											margin: pw.EdgeInsets.only(bottom: 10),
											child: pw.Column(
												crossAxisAlignment: pw.CrossAxisAlignment.start,
												children: [
													pw.Row(
														mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
														crossAxisAlignment: pw.CrossAxisAlignment.start,
														children: [
															pw.Expanded(
																child: pw.Text(
																	name,
																	style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
																),
															),
															pw.SizedBox(width: 10),
															pw.Text(
																'$totalItem \$',
																style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
															),
														],
													),
													pw.SizedBox(height: 4),
													pw.Row(
														children: [
															pw.Container(
																padding: pw.EdgeInsets.symmetric(horizontal: 30, vertical: 2),
																decoration: pw.BoxDecoration(
																	color: PdfColors.grey200,
																	borderRadius: pw.BorderRadius.circular(3),
																),
																child: pw.Text(
																	'x$qty',
																	style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
																),
															),
															pw.SizedBox(width: 6),
															pw.Text(
																'$unitPrice \$',
																style: pw.TextStyle(fontSize: 28, color: PdfColors.grey600),
															),
														],
													),
												],
											),
										);
									}).toList(),
								),
							),

							pw.SizedBox(height: 100),

							// Totaux avec équivalence CDF si applicable
							pw.Container(
								width: double.infinity,
								child: pw.Column(
									children: [
										// Sous-total
										pw.Column(
											children: [
												pw.Row(
													mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
													children: [
														pw.Text('Sous-total', style: pw.TextStyle(fontSize: 32)),
														pw.Text('$subtotal \$', style: pw.TextStyle(fontSize: 32)),
													],
												),
												if (subtotalCDF != null) ...[
													pw.SizedBox(height: 2),
													pw.Row(
														mainAxisAlignment: pw.MainAxisAlignment.end,
														children: [
															pw.Text(
																'$subtotalCDF CDF',
																style: pw.TextStyle(
																	fontSize: 26,
																//	color: PdfColors.blue700,
																	fontStyle: pw.FontStyle.italic,
																),
															),
														],
													),
												],
											],
										),

										// Frais de livraison
										if (double.tryParse(deliveryFee) != null && double.parse(deliveryFee) > 0) ...[
											pw.SizedBox(height: 5),
											pw.Column(
												children: [
													pw.Row(
														mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
														children: [
															pw.Text('Frais de livraison', style: pw.TextStyle(fontSize: 32)),
															pw.Text('$deliveryFee \$', style: pw.TextStyle(fontSize: 32)),
														],
													),
													if (deliveryFeeCDF != null) ...[
														pw.SizedBox(height: 2),
														pw.Row(
															mainAxisAlignment: pw.MainAxisAlignment.end,
															children: [
																pw.Text(
																	'$deliveryFeeCDF CDF',
																	style: pw.TextStyle(
																		fontSize: 26,
																		//color: PdfColors.blue700,
																		fontStyle: pw.FontStyle.italic,
																	),
																),
															],
														),
													],
												],
											),
										],

										pw.SizedBox(height: 50),

										// Total
										pw.Column(
											children: [
												pw.Container(
													padding: pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
													decoration: pw.BoxDecoration(
														color: PdfColors.grey900,
														borderRadius: pw.BorderRadius.circular(4),
													),
													child: pw.Row(
														mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
														children: [
															pw.Text(
																'TOTAL',
																style: pw.TextStyle(
																	fontSize: 36,
																	fontWeight: pw.FontWeight.bold,
																	color: PdfColors.white,
																),
															),
															pw.Text(
																'$total \$',
																style: pw.TextStyle(
																	fontSize: 36,
																	fontWeight: pw.FontWeight.bold,
																	color: PdfColors.white,
																),
															),
														],
													),
												),
												if (totalCDF != null) ...[
													pw.SizedBox(height: 5),
													pw.Row(
														mainAxisAlignment: pw.MainAxisAlignment.end,
														children: [
															pw.Text(
																'$totalCDF CDF',
																style: pw.TextStyle(
																	fontSize: 30,
																	fontWeight: pw.FontWeight.bold,
																),
															),
														],
													),
												],
											],
										),
									],
								),
							),

							pw.SizedBox(height: 50),

							// Paiement
							pw.Container(
								width: double.infinity,
								child: pw.Column(
									children: [
										pw.Row(
											mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
											children: [
												pw.Text('Montant reçu', style: pw.TextStyle(fontSize: 32, color: PdfColors.grey700)),
												pw.Text('$amountGiven $currency', style: pw.TextStyle(fontSize: 32)),
											],
										),
										// Taux de change (affiché en bas)
										if (isCDF && conversionRate != null) ...[
											pw.SizedBox(height: 5),
											pw.Container(
												width: double.infinity,
												child: pw.Row(
													mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
													children: [
														pw.Text(
															'Taux appliqué: ',
															style: pw.TextStyle(
																fontSize: 28,
																color: PdfColors.grey700,
															),
														),
														pw.Text(
															'1 \$ = ${conversionRate.toStringAsFixed(0)} CDF',
															style: pw.TextStyle(
																fontSize: 28,
																fontWeight: pw.FontWeight.bold,
															),
														),
													],
												),
											),
										],
										if (double.tryParse(changeReturned) != null && double.parse(changeReturned) > 0) ...[
											pw.SizedBox(height: 5),
											pw.Row(
												mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
												children: [
													pw.Text('Monnaie rendue', style: pw.TextStyle(fontSize: 32, color: PdfColors.grey700)),
													pw.Text('$changeReturned $currency', style: pw.TextStyle(fontSize: 32)),
												],
											),
										],
									],
								),
							),



							pw.SizedBox(height: 100),

							// Message de remerciement
							pw.Text(
								'Merci pour votre visite !',
								style: pw.TextStyle(
									fontSize: 35,
									fontWeight: pw.FontWeight.bold,
									letterSpacing: 1,
								),
							),
							pw.SizedBox(height: 8),
							pw.Text(
								'À bientôt chez MH Beauty & Création',
								style: pw.TextStyle(fontSize: 26, color: PdfColors.grey600),
							),

							pw.SizedBox(height: 10),
						],
					);
				},
			),
		);

		try {
			await Printing.layoutPdf(onLayout: (format) => doc.save());
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Erreur d\'impression: $e')),
				);
			}
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



	// ===================== DARK MODE =====================
	Future<void> setDarkMode(bool value) async {
		_darkMode = value;
		await _storage.write(_darkModeKey, value);
		notifyListeners();
	}

	Future<void> toggleDarkMode() async => setDarkMode(!_darkMode);




}
