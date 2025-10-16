import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:mh_beauty/controllers/user.dart';

class ProductFormView extends StatefulWidget {
  final String? productId;

  const ProductFormView({super.key, this.productId});

  @override
  State<ProductFormView> createState() => _ProductFormViewState();
}

class _ProductFormViewState extends State<ProductFormView> {
  int? _selectedCategory;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();
  final TextEditingController _alertCtrl = TextEditingController();
  final TextEditingController _imageCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Charger catégories et, si édition, charger le produit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pc = Provider.of<ProductController>(context, listen: false);
      pc.fetchCategories();
      // Vérifier le rôle : si pas admin, on bloque l'accès à ce formulaire
      final uc = Provider.of<UserController>(context, listen: false);
      if (!uc.isAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accès refusé : action réservée aux administrateurs')));
        // Revenir à la liste
        Future.microtask(() => Navigator.of(context).pop());
        return;
      }
      if (widget.productId != null) {
        _loadProduct(widget.productId!);
      }
    });
  }

  Future<void> _loadProduct(String idStr) async {
    setState(() => _loading = true);
    final pc = Provider.of<ProductController>(context, listen: false);
    int? id = int.tryParse(idStr);
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    final resp = await pc.fetchProduct(id);
    if (resp['success'] == true && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      // Certaines APIs enveloppent l'objet dans 'product' ou 'data', gère quelques variantes
      final prod = data['product'] ?? data;
      if (prod is Map<String, dynamic>) {
        _nameCtrl.text = prod['name']?.toString() ?? '';
        _descCtrl.text = prod['description']?.toString() ?? '';
        _priceCtrl.text = prod['price']?.toString() ?? '';
        _stockCtrl.text = prod['stock']?.toString() ?? '';
        _alertCtrl.text = prod['alert_threshold']?.toString() ?? '';
        // category_id peut être présent directement ou comme objet
        final cat = prod['category_id'] ?? prod['category'] ?? prod['categorie'];
        if (cat is int) {
          _selectedCategory = cat;
        } else if (cat is String) {
          _selectedCategory = int.tryParse(cat);
        } else if (cat is Map) {
          _selectedCategory = cat['id'] is int ? cat['id'] : int.tryParse(cat['id']?.toString() ?? '');
        }
      }
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _alertCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uc = Provider.of<UserController>(context, listen: false);
    if (!uc.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accès refusé : action réservée aux administrateurs')));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    final pc = Provider.of<ProductController>(context, listen: false);
    final payload = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'price': double.tryParse(_priceCtrl.text.trim()) ?? 0.0,
      'stock': int.tryParse(_stockCtrl.text.trim()) ?? 0,
      'alert_threshold': _alertCtrl.text.trim().isEmpty ? null : int.tryParse(_alertCtrl.text.trim()),
      'category_id': _selectedCategory,
    };

    setState(() => _saving = true);
    late Map<String, dynamic> resp;
    if (widget.productId != null) {
      final id = int.tryParse(widget.productId!);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Identifiant invalide')));
        setState(() => _saving = false);
        return;
      }
      resp = await pc.updateProduct(id, payload);
    } else {
      resp = await pc.createProduct(payload);
    }

    setState(() => _saving = false);

    if (resp['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Opération réussie')));
      // Retour à la liste des produits
      context.push('/products');
    } else {
      final msg = resp['message'] ?? 'Erreur';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.productId != null;
    final pc = Provider.of<ProductController>(context);
    final uc = Provider.of<UserController>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier produit' : 'Nouveau produit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nom du produit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nom requis';
                        if (v.trim().length > 255) return 'Max 255 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: pc.categories
                          .map((cat) => DropdownMenuItem<int>(
                                value: (cat['id'] is int) ? cat['id'] : int.tryParse(cat['id']?.toString() ?? ''),
                                child: Text(cat['name']?.toString() ?? cat['title']?.toString() ?? 'Catégorie'),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value),
                      validator: (v) => v == null ? 'Choisissez une catégorie' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Prix (\$)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Prix requis';
                              final d = double.tryParse(v.replaceAll(',', '.'));
                              if (d == null) return 'Prix invalide';
                              if (d < 0) return 'Doit être >= 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Stock',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Stock requis';
                              final i = int.tryParse(v);
                              if (i == null) return 'Stock invalide';
                              if (i < 0) return 'Doit être >= 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description (optionnel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _alertCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Seuil d\'alerte (optionnel)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final i = int.tryParse(v);
                        if (i == null) return 'Entier invalide';
                        if (i < 0) return 'Doit être >= 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _saving ? const CircularProgressIndicator() : Text(isEditing ? 'Enregistrer' : 'Ajouter'),
                    ),
                    if (isEditing && uc.isAdmin) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () async {
                          final id = int.tryParse(widget.productId!);
                          if (id == null) return;
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Supprimer'),
                              content: const Text('Confirmer la suppression ?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Supprimer')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            final ok = await pc.deleteProduct(id);
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supprimé')));
                              context.push('/products');
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur suppression')));
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
