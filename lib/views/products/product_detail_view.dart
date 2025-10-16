import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:mh_beauty/controllers/user.dart';

class ProductDetailView extends StatefulWidget {
  final String productId;
  const ProductDetailView({super.key, required this.productId});

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  bool _loading = true;
  Map<String, dynamic>? _product;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pc = Provider.of<ProductController>(context, listen: false);
    final id = int.tryParse(widget.productId);
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identifiant produit invalide')),
      );
      setState(() => _loading = false);
      return;
    }
    final resp = await pc.fetchProduct(id);
    if (resp['success'] == true && resp['data'] != null) {
      final data = resp['data'] as Map<String, dynamic>;
      _product = data['product'] ?? data;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['message'] ?? 'Erreur chargement')),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteProduct() async {
    final uc = Provider.of<UserController>(context, listen: false);
    if (!uc.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accès refusé : action réservée aux administrateurs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final pc = Provider.of<ProductController>(context, listen: false);
    final id = int.tryParse(widget.productId);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: const Text('Voulez-vous vraiment supprimer ce produit ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final ok = await pc.deleteProduct(id);
    if (ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produit supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/products');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la suppression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _isLowStock() {
    if (_product == null) return false;
    final stock = _product!['stock'];
    final alertThreshold = _product!['alert_threshold'] ?? 10;

    if (stock is num && alertThreshold is num) {
      return stock <= alertThreshold;
    }

    final stockInt = int.tryParse(stock?.toString() ?? '0');
    final thresholdInt = int.tryParse(alertThreshold?.toString() ?? '10');

    return stockInt != null && thresholdInt != null && stockInt <= thresholdInt;
  }

  @override
  Widget build(BuildContext context) {
    final uc = Provider.of<UserController>(context);
    final isAdmin = uc.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails produit'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _product == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Produit introuvable',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/products'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour aux produits'),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Contenu
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom et prix
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _product!['name']?.toString() ?? 'Produit',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '\$${_product!['price']?.toString() ?? '0'}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Informations principales
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'Catégorie',
                        value: _product!['category'] is Map
                            ? _product!['category']['name']?.toString() ?? 'Non définie'
                            : 'Non définie',
                      ),
                      const Divider(height: 24),
                      _InfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock disponible',
                        value: _product!['stock']?.toString() ?? '0',
                        valueColor: _isLowStock() ? Colors.red : Colors.green,
                        trailing: _isLowStock()
                            ? const Chip(
                          label: Text('Stock faible', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.red,
                          labelStyle: TextStyle(color: Colors.white),
                          visualDensity: VisualDensity.compact,
                        )
                            : null,
                      ),
                      if (_product!['alert_threshold'] != null) ...[
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.warning_amber_outlined,
                          label: 'Seuil d\'alerte',
                          value: _product!['alert_threshold']?.toString() ?? '0',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  if (_product!['description'] != null && _product!['description'].toString().isNotEmpty) ...[
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _product!['description']?.toString() ?? 'Aucune description',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Boutons d'action (uniquement pour admin)
                  if (isAdmin) ...[
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              if (_product != null && _product!['id'] != null) {
                                context.push('/products/edit/${_product!['id'].toString()}');
                              }
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Modifier'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _deleteProduct,
                            icon: const Icon(Icons.delete),
                            label: const Text('Supprimer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget pour une carte d'informations
class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

// Widget pour une ligne d'information
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}