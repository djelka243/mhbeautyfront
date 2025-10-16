import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';

class EditProfilView extends StatefulWidget {
	const EditProfilView({super.key});

	@override
	State<EditProfilView> createState() => _EditProfilViewState();
}

class _EditProfilViewState extends State<EditProfilView> {
	final _formKey = GlobalKey<FormState>();
	late TextEditingController _nameCtrl;
	late TextEditingController _emailCtrl;
	bool _saving = false;

	@override
	void initState() {
		super.initState();
		final user = context.read<UserController>().user;
		_nameCtrl = TextEditingController(text: user?['name'] ?? '');
		_emailCtrl = TextEditingController(text: user?['email'] ?? '');
	}

	@override
	void dispose() {
		_nameCtrl.dispose();
		_emailCtrl.dispose();
		super.dispose();
	}

	Future<void> _save() async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _saving = true);

		final res = await context
				.read<UserController>()
				.updateProfile(_nameCtrl.text.trim(), _emailCtrl.text.trim());

		setState(() => _saving = false);

		if (res['success'] == true) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('✅ Profil mis à jour avec succès')),
			);
			Navigator.of(context).pop();
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(res['message'] ?? 'Erreur')),
			);
		}
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
					border: OutlineInputBorder(
						borderRadius: BorderRadius.circular(10),
					),
				),
				validator: required
						? (v) =>
				v == null || v.trim().isEmpty ? '$label est requis' : null
						: null,
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Modifier le profil'),
				centerTitle: true,
				elevation: 0,
			),
			body: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
				child: Form(
					key: _formKey,
					child: ListView(
						children: [
							const Text(
								"Informations du compte",
								style: TextStyle(
									fontSize: 20,
									fontWeight: FontWeight.w600,
								),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 25),

							// Champ nom
							_buildTextField(
								controller: _nameCtrl,
								label: 'Nom complet',
								icon: Icons.person_outline,
								required: true,
							),

							// Champ email
							_buildTextField(
								controller: _emailCtrl,
								label: 'Adresse e-mail',
								icon: Icons.email_outlined,
								keyboardType: TextInputType.emailAddress,
								required: true,
							),

							const SizedBox(height: 30),

							// Bouton sauvegarde
							SizedBox(
								width: double.infinity,
								height: 50,
								child: ElevatedButton.icon(
									onPressed: _saving ? null : _save,
									icon: _saving
											? const SizedBox(
										width: 20,
										height: 20,
										child: CircularProgressIndicator(
											color: Colors.white,
											strokeWidth: 2,
										),
									)
											: const Icon(Icons.save_outlined),
									label: Text(
										_saving ? "Sauvegarde..." : "Enregistrer les modifications",
										style: const TextStyle(fontSize: 16),
									),
									style: ElevatedButton.styleFrom(
										backgroundColor: Colors.blueAccent,
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(10),
										),
										elevation: 3,
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
