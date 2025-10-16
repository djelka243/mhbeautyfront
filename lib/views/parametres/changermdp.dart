import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';

class ChangeMdpView extends StatefulWidget {
	const ChangeMdpView({super.key});

	@override
	State<ChangeMdpView> createState() => _ChangeMdpViewState();
}

class _ChangeMdpViewState extends State<ChangeMdpView> {
	final _formKey = GlobalKey<FormState>();
	final _currentCtrl = TextEditingController();
	final _newCtrl = TextEditingController();
	final _confirmCtrl = TextEditingController();

	bool _loading = false;
	bool _showCurrent = false;
	bool _showNew = false;
	bool _showConfirm = false;

	@override
	void dispose() {
		_currentCtrl.dispose();
		_newCtrl.dispose();
		_confirmCtrl.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;
		print("new: ${_newCtrl.text.trim()} != confirm: ${_confirmCtrl.text.trim()}");
		if (_newCtrl.text.trim() != _confirmCtrl.text.trim()) {

			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text(
						'Les nouveaux mots de passe ne correspondent pas',
						style: TextStyle(color: Colors.white),
					),
					backgroundColor: Colors.redAccent,
				),
			);
			return;
		}

		setState(() => _loading = true);

		final res = await context.read<UserController>().changePassword(
			_currentCtrl.text.trim(),
			_newCtrl.text.trim(),
			_confirmCtrl.text.trim(),
		);

		setState(() => _loading = false);

		if (res['success'] == true) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('Mot de passe changé avec succès',style: TextStyle(color: Colors.white),),
					backgroundColor: Colors.green,
				),
			);
			Navigator.of(context).pop();
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(res['message'] ?? 'Erreur', style: const TextStyle(color: Colors.white)),
					backgroundColor: Colors.redAccent,

				),
			);
		}
	}


	Widget _buildPasswordField({
		required TextEditingController controller,
		required String label,
		required IconData icon,
		required bool visible,
		required VoidCallback onToggle,
		bool required = false,
	}) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 15),
			child: TextFormField(
				controller: controller,
				obscureText: !visible,
				decoration: InputDecoration(
					labelText: label,
					prefixIcon: Icon(icon),
					suffixIcon: IconButton(
						icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
						onPressed: onToggle,
					),
					border: const OutlineInputBorder(),
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
				title: const Text('Changer le mot de passe'),
				centerTitle: true,
				elevation: 0,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
			),
			body: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
				child: Form(
					key: _formKey,
					child: ListView(
						children: [
							const Text(
								"Sécurité du compte",
								style: TextStyle(
									fontSize: 20,
									fontWeight: FontWeight.w600,
								),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 25),

							// Mot de passe actuel
							_buildPasswordField(
								controller: _currentCtrl,
								label: "Mot de passe actuel",
								icon: Icons.lock_outline,
								visible: _showCurrent,
								onToggle: () => setState(() => _showCurrent = !_showCurrent),
								required: true,
							),

							// Nouveau mot de passe
							_buildPasswordField(
								controller: _newCtrl,
								label: "Nouveau mot de passe",
								icon: Icons.vpn_key_outlined,
								visible: _showNew,
								onToggle: () => setState(() => _showNew = !_showNew),
								required: true,
							),

							// Confirmer mot de passe
							_buildPasswordField(
								controller: _confirmCtrl,
								label: "Confirmer le mot de passe",
								icon: Icons.check_circle_outline,
								visible: _showConfirm,
								onToggle: () => setState(() => _showConfirm = !_showConfirm),
								required: true,
							),

							const SizedBox(height: 30),

							// Bouton Valider
							SizedBox(
								width: double.infinity,
								height: 50,
								child: ElevatedButton.icon(
									onPressed: _loading ? null : _submit,
									icon: _loading
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
										_loading ? "Changement..." : "Valider",
										style: const TextStyle(fontSize: 16),
									),
									style: ElevatedButton.styleFrom(
										backgroundColor: Colors.redAccent,
										foregroundColor: Colors.white,
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(8),
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
