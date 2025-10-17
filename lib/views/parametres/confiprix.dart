import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';

class ConfigPrixView extends StatefulWidget {
	const ConfigPrixView({super.key});

	@override
	State<ConfigPrixView> createState() => _ConfigPrixViewState();
}

class _ConfigPrixViewState extends State<ConfigPrixView> {
	final _rateCtrl = TextEditingController();
	bool _loading = false;
	double? _currentRate;

	@override
	void initState() {
		super.initState();
		_loadRate();
	}

	Future<void> _loadRate() async {
		final controller = context.read<UserController>();
		final result = await controller.fetchCurrencyRate();
		if (result['success'] == true && result['valeur'] != null) {
			setState(() {
				_currentRate = double.tryParse(result['valeur'].toString());
				_rateCtrl.text = _currentRate?.toStringAsFixed(2) ?? '';
			});
		}
	}

	Future<void> _saveRate() async {
		final rateText = _rateCtrl.text.trim();
		if (rateText.isEmpty || double.tryParse(rateText) == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Veuillez entrer un taux valide'),
					backgroundColor: Colors.red,
				),
			);
			return;
		}

		setState(() => _loading = true);
		final controller = context.read<UserController>();
		final result =
		await controller.saveCurrencyRate(double.parse(rateText));
		setState(() => _loading = false);

		if (result['success'] == true) {
			setState(() => _currentRate = double.parse(rateText));
		}

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					result['success'] == true
							? 'Taux enregistré avec succès ✅'
							: result['message'] ?? 'Erreur inconnue',
				),
				backgroundColor: result['success'] == true ? Colors.green : Colors.red,
			),
		);
	}

	@override
	void dispose() {
		_rateCtrl.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final gradient = const LinearGradient(
			colors: [Color(0xFF1B5E20), Color(0xFF9FA8DA)],
			begin: Alignment.topLeft,
			end: Alignment.bottomRight,
		);

		return Scaffold(
			appBar: AppBar(
				title: const Text('Taux du jour'),
				centerTitle: true,
				elevation: 0,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
			),
			body: SingleChildScrollView(
					padding: const EdgeInsets.all(20),
					child: Container(
						padding: const EdgeInsets.all(20),
						decoration: BoxDecoration(
							gradient: gradient,
							borderRadius: BorderRadius.circular(16),
							boxShadow: [
								BoxShadow(
									color: Colors.black.withOpacity(0.1),
									blurRadius: 10,
									offset: const Offset(0, 4),
								),
							],
						),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								const Text(
									'Taux de conversion actuel',
									style: TextStyle(
										color: Colors.white,
										fontSize: 20,
										fontWeight: FontWeight.w600,
									),
								),
								const SizedBox(height: 20),
								Row(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										const Text(
											'1\$ = ',
											style: TextStyle(fontSize: 22, color: Colors.white),
										),
										Text(
											_currentRate != null
													? '${_currentRate!.toStringAsFixed(2)} FC'
													: '—',
											style: const TextStyle(
												fontSize: 22,
												fontWeight: FontWeight.bold,
												color: Colors.amberAccent,
											),
										),
									],
								),
								const SizedBox(height: 25),
								Card(
									elevation: 4,
									shape: RoundedRectangleBorder(
										borderRadius: BorderRadius.circular(12),
									),
									child: Padding(
										padding: const EdgeInsets.all(16.0),
										child: Column(
											children: [
												const Text(
													'Mettre à jour le taux',
													style: TextStyle(
														fontSize: 18,
														fontWeight: FontWeight.w500,
													),
												),
												const SizedBox(height: 15),
												TextField(
													controller: _rateCtrl,
													textAlign: TextAlign.center,
													keyboardType: TextInputType.number,
													decoration: const InputDecoration(
														labelText: 'Nouveau taux en FC',
														border: OutlineInputBorder(),
														prefixIcon: Icon(Icons.currency_exchange),
													),
												),
												const SizedBox(height: 20),
												SizedBox(
													width: double.infinity,
													child: ElevatedButton.icon(
														onPressed: _loading ? null : _saveRate,
														icon: _loading
																? const SizedBox(
															width: 18,
															height: 18,
															child: CircularProgressIndicator(
																color: Colors.white,
																strokeWidth: 2,
															),
														)
																: const Icon(Icons.save_rounded),
														label: Text(
															_loading ? 'Enregistrement...' : 'Enregistrer',
															style: const TextStyle(fontSize: 16),
														),
														style: ElevatedButton.styleFrom(
															backgroundColor: Colors.amber.shade700,
															foregroundColor: Colors.white,
															padding: const EdgeInsets.symmetric(vertical: 14),
															shape: RoundedRectangleBorder(
																borderRadius: BorderRadius.circular(10),
															),
														),
													),
												),
											],
										),
									),
								),
							],
						),
					),
				),
		);
	}
}
