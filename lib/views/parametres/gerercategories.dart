import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';

class GererCategoriesView extends StatefulWidget {
	const GererCategoriesView({super.key});

	@override
	State<GererCategoriesView> createState() => _GererCategoriesViewState();
}

class _GererCategoriesViewState extends State<GererCategoriesView> {
	final _nameCtrl = TextEditingController();
	final _descCtrl = TextEditingController();
	final _formKey = GlobalKey<FormState>();
	bool _loading = false;
	bool _isLoading = false;

	@override
	void initState() {
		super.initState();
		_loadCategories();
	}

	Future<void> _loadCategories() async {
		setState(() => _isLoading = true);
		await context.read<UserController>().fetchCategories();
		setState(() => _isLoading = false);
	}

	Future<void> _addCategory(BuildContext context) async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _loading = true);
		final controller = context.read<UserController>();
		final result = await controller.createCategory(
			_nameCtrl.text.trim(),
			_descCtrl.text.trim(),
		);
		setState(() => _loading = false);

		if (result['success'] == true) {
			if (mounted) {
				Navigator.pop(context); // ferme le modal
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Catégorie ajoutée avec succès ✅')),
				);
			}
			_nameCtrl.clear();
			_descCtrl.clear();
			_loadCategories();
		} else {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text(result['message'] ?? 'Erreur inconnue'),
					backgroundColor: Colors.red,
				),
			);
		}
	}

	Future<void> _confirmDelete(BuildContext context, int id) async {
		final controller = context.read<UserController>();
		final result = await showDialog<bool>(
			context: context,
			builder: (ctx) => AlertDialog(
				title: const Text('Confirmer la suppression'),
				content:
				const Text('Voulez-vous vraiment supprimer cette catégorie ?'),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(ctx, false),
						child: const Text('Annuler'),
					),
					ElevatedButton(
						onPressed: () => Navigator.pop(ctx, true),
						style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
						child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
					),
				],
			),
		);

		if (result == true) {
			// à implémenter dans UserController si pas encore fait
			final resp = await controller.deleteCategory(id);
			if (mounted) {
				if (resp) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(content: Text('Catégorie supprimée ✅')),
					);
					_loadCategories();
				} else {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
								content: Text('Erreur lors de la suppression'),
								backgroundColor: Colors.red),
					);
				}
			}
		}
	}

	void _openAddModal() {
		showModalBottomSheet(
			context: context,
			isScrollControlled: true,
			shape: const RoundedRectangleBorder(
					borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
			builder: (ctx) => Padding(
				padding: EdgeInsets.only(
					bottom: MediaQuery.of(ctx).viewInsets.bottom,
					left: 16,
					right: 16,
					top: 24,
				),
				child: Form(
					key: _formKey,
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							const Text(
								'Ajouter une catégorie',
								style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
							),
							const SizedBox(height: 16),
							TextFormField(
								controller: _nameCtrl,
								decoration: const InputDecoration(
									labelText: 'Nom de la catégorie',
									border: OutlineInputBorder(),
								),
								validator: (v) =>
								v == null || v.isEmpty ? 'Veuillez entrer un nom' : null,
							),
							const SizedBox(height: 12),
							TextFormField(
								controller: _descCtrl,
								decoration: const InputDecoration(
									labelText: 'Description',
									border: OutlineInputBorder(),
								),
								maxLines: 2,
							),
							const SizedBox(height: 20),
							SizedBox(
								width: double.infinity,
								child: ElevatedButton.icon(
									icon: _loading
											? const SizedBox(
										height: 16,
										width: 16,
										child: CircularProgressIndicator(
												strokeWidth: 2, color: Colors.white),
									)
											: const Icon(Icons.add),
									label: Text(_loading ? 'Ajout...' : 'Ajouter'),
									onPressed: _loading ? null : () => _addCategory(ctx),
								),
							),
							const SizedBox(height: 16),
						],
					),
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final controller = context.watch<UserController>();
		final categories = controller.categories;

		return Scaffold(
			appBar: AppBar(
					title: const Text('Gérer les catégories'),
				centerTitle: true,
				elevation: 0,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
			),
			body: _isLoading
					? const Center(child: CircularProgressIndicator())
					: categories.isEmpty
					? const Center(child: Text('Aucune catégorie disponible'))
					: ListView.builder(
				itemCount: categories.length,
				itemBuilder: (context, index) {
					final cat = categories[index];
					return Card(
						margin: const EdgeInsets.symmetric(
								vertical: 6, horizontal: 12),
						child: ListTile(
							title: Text(cat['name'] ?? 'Sans nom'),
							subtitle:
							Text(cat['description'] ?? 'Aucune description'),
							trailing: IconButton(
								icon: const Icon(Icons.delete, color: Colors.red),
								onPressed: () =>
										_confirmDelete(context, cat['id'] as int),
							),
						),
					);
				},
			),
			floatingActionButton: FloatingActionButton(
				onPressed: _openAddModal,
				child: const Icon(Icons.add),
			),
		);
	}
}
