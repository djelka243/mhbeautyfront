import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';

class InfoMagasinView extends StatefulWidget {
	const InfoMagasinView({super.key});

	@override
	State<InfoMagasinView> createState() => _InfoMagasinViewState();
}

class _InfoMagasinViewState extends State<InfoMagasinView> {
	final _formKey = GlobalKey<FormState>();
	final _nameCtrl = TextEditingController();
	final _addressCtrl = TextEditingController();
	final _phoneCtrl = TextEditingController();
	final _emailCtrl = TextEditingController();
	final _rccmCtrl = TextEditingController();
	final _nifCtrl = TextEditingController();
	int? _magasinId;

	bool _saving = false;
	bool _loading = true;
	bool _hasData = false; // indique si on a déjà un enregistrement

	@override
	void initState() {
		super.initState();
		_loadMagasinInfo();
	}

	Future<void> _loadMagasinInfo() async {
		final controller = context.read<UserController>();
		final result = await controller.getInfoMagasin();

		if (result['success'] == true && result['data'] != null) {
			final data = result['data'];

			setState(() {
				_magasinId = data['id'];
				_nameCtrl.text = data['nom'] ?? '';
				_addressCtrl.text = data['adresse'] ?? '';
				_phoneCtrl.text = data['telephone'] ?? '';
				_emailCtrl.text = data['email'] ?? '';
				_rccmCtrl.text = data['rccm'] ?? '';
				_nifCtrl.text = data['nif'] ?? '';
				_hasData = true;
			});
		}

		setState(() => _loading = false);
	}

	Future<void> _saveOrUpdate() async {
		if (!_formKey.currentState!.validate()) return;
		setState(() => _saving = true);

		final controller = context.read<UserController>();
		final result = _hasData
				? await controller.updateInfoMagasin(
			_magasinId,
			_nameCtrl.text.trim(),
			_addressCtrl.text.trim(),
			_phoneCtrl.text.trim(),
			_emailCtrl.text.trim(),
			_rccmCtrl.text.trim(),
			_nifCtrl.text.trim(),
		)
				: await controller.saveInfoMagasin(
			_nameCtrl.text.trim(),
			_addressCtrl.text.trim(),
			_phoneCtrl.text.trim(),
			_emailCtrl.text.trim(),
			_rccmCtrl.text.trim(),
			_nifCtrl.text.trim(),
		);

		setState(() => _saving = false);

		final success = result['success'] == true;
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					result['message'] ??
							(success
									? (_hasData
									? 'Informations modifiées ✅'
									: 'Informations enregistrées ✅')
									: 'Erreur lors de la sauvegarde ❌'),
				),
				backgroundColor: success ? Colors.green : Colors.red,
			),
		);

		if (success && !_hasData) {
			setState(() => _hasData = true);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Informations du magasin'),
				centerTitle: true,
			),
			body: _loading
					? const Center(child: CircularProgressIndicator())
					: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
				child: Form(
					key: _formKey,
					child: ListView(
						children: [
							const Text(
								'Configurer les informations du magasin',
								style: TextStyle(
									fontSize: 20,
									fontWeight: FontWeight.w600,
								),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 30),

							// Champs
							_buildTextField(
								controller: _nameCtrl,
								label: 'Nom du magasin',
								icon: Icons.store,
								required: true,
							),
							_buildTextField(
								controller: _addressCtrl,
								label: 'Adresse',
								icon: Icons.location_on_outlined,
								required: true,
							),
							_buildTextField(
								controller: _phoneCtrl,
								label: 'Téléphone',
								icon: Icons.phone,
								keyboardType: TextInputType.phone,
								required: true,
							),
							_buildTextField(
								controller: _emailCtrl,
								label: 'Email (optionnel)',
								icon: Icons.email_outlined,
								keyboardType: TextInputType.emailAddress,
							),
							_buildTextField(
								controller: _rccmCtrl,
								label: 'RCCM (optionnel)',
								icon: Icons.business_center_outlined,
							),
							_buildTextField(
								controller: _nifCtrl,
								label: 'NIF (optionnel)',
								icon: Icons.confirmation_number_outlined,
							),
							const SizedBox(height: 30),

							// Bouton enregistrer ou modifier
							SizedBox(
								width: double.infinity,
								height: 50,
								child: ElevatedButton.icon(
									onPressed: _saving ? null : _saveOrUpdate,
									icon: _saving
											? const SizedBox(
										width: 20,
										height: 20,
										child: CircularProgressIndicator(
											color: Colors.white,
											strokeWidth: 2,
										),
									)
											: Icon(_hasData
											? Icons.edit_outlined
											: Icons.save_outlined),
									label: Text(
										_saving
												? 'Traitement...'
												: _hasData
												? 'Modifier les informations'
												: 'Enregistrer les informations',
										style: const TextStyle(fontSize: 16),
									),
									style: ElevatedButton.styleFrom(
										backgroundColor: _hasData
												? Colors.indigo.shade700
												: Colors.green.shade800,
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
										),
									),
								),
							),
						],
					),
				),
			),
		);
	}

	Widget _buildTextField({
		required TextEditingController controller,
		required String label,
		required IconData icon,
		TextInputType? keyboardType,
		bool required = false,
	}) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 15),
			child: TextFormField(
				controller: controller,
				keyboardType: keyboardType,
				decoration: InputDecoration(
					labelText: label,
					prefixIcon: Icon(icon),
					border: const OutlineInputBorder(),
				),
				validator: required
						? (v) =>
				v == null || v.trim().isEmpty ? '$label est requis' : null
						: null,
			),
		);
	}
}
