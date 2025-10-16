import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:mh_beauty/controllers/user.dart';


class ProductsListView extends StatefulWidget {
  const ProductsListView({super.key});

  @override
  State<ProductsListView> createState() => _ProductsListViewState();
}

class _ProductsListViewState extends State<ProductsListView> {
  String _searchQuery = '';
  int? _selectedCategoryId; // null => toutes
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pc = Provider.of<ProductController>(context, listen: false);
      await Future.wait([pc.fetchCategories(), pc.fetchProducts()]);
      setState(() => _loading = false);
    });
  }

  String _categoryNameForProduct(Map<String, dynamic> product, List<Map<String, dynamic>> categories) {
    // Cherche d'abord dans product['category']
    final catField = product['category'] ?? product['category_id'] ?? product['categorie'];
    if (catField is Map) {
      return catField['name']?.toString() ?? catField['title']?.toString() ?? 'Sans catégorie';
    }
    int? catId;
    if (catField is int) catId = catField;
    else if (catField is String) catId = int.tryParse(catField);
    if (catId != null) {
      final found = categories.firstWhere(
        (c) => (c['id'] is int ? c['id'] : int.tryParse(c['id']?.toString() ?? '')) == catId,
        orElse: () => {},
      );
      if (found.isNotEmpty) return found['name']?.toString() ?? 'Sans catégorie';
    }
    return 'Sans catégorie';
  }

  int? _categoryIdFromProduct(Map<String, dynamic> product) {
    final catField = product['category'] ?? product['category_id'] ?? product['categorie'];
    if (catField is int) return catField;
    if (catField is String) return int.tryParse(catField);
    if (catField is Map) {
      final id = catField['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pc = Provider.of<ProductController>(context);
    final uc = Provider.of<UserController>(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Produits & Stock')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Applique le filtrage et le tri
    List<Map<String, dynamic>> shown = List<Map<String, dynamic>>.from(pc.products);

    // Filtre par catégorie si selectionnée
    if (_selectedCategoryId != null) {
      shown = shown.where((p) {
        final pid = _categoryIdFromProduct(p);
        return pid == _selectedCategoryId;
      }).toList();
    } else {
      // Tri par nom de catégorie puis nom de produit
      shown.sort((a, b) {
        final ca = _categoryNameForProduct(a, pc.categories);
        final cb = _categoryNameForProduct(b, pc.categories);
        final cmp = ca.toLowerCase().compareTo(cb.toLowerCase());
        if (cmp != 0) return cmp;
        final na = (a['name'] ?? '').toString();
        final nb = (b['name'] ?? '').toString();
        return na.toLowerCase().compareTo(nb.toLowerCase());
      });
    }

    // Applique la recherche texte
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      shown = shown.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final cat = _categoryNameForProduct(p, pc.categories).toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }

    // Créer une copie triée des catégories pour un affichage stable
    final sortedCategories = List<Map<String, dynamic>>.from(pc.categories);
    sortedCategories.sort((a, b) {
      final na = (a['name'] ?? a['title'] ?? '').toString().toLowerCase();
      final nb = (b['name'] ?? b['title'] ?? '').toString().toLowerCase();
      return na.compareTo(nb);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits & Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int?>(
                  value: _selectedCategoryId,
                  hint: const Text('Catégorie'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Toutes')),
                    ...sortedCategories.map((cat) {
                      final id = (cat['id'] is int) ? cat['id'] : int.tryParse(cat['id']?.toString() ?? '');
                      final name = cat['name']?.toString() ?? cat['title']?.toString() ?? 'Catégorie';
                      return DropdownMenuItem<int?>(value: id, child: Text(name));
                    }).toList()
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([pc.fetchCategories(), pc.fetchProducts()]);
                setState(() {});
              },
              child: Builder(builder: (context) {
                if (shown.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 60),
                      Center(child: Text('Aucun produit trouvé', style: Theme.of(context).textTheme.titleMedium)),
                    ],
                  );
                }

                // Si aucune catégorie sélectionnée => affichage groupé par catégories
                if (_selectedCategoryId == null) {
                  final List<Widget> grouped = [];

                  for (final cat in sortedCategories) {
                    final catId = (cat['id'] is int) ? cat['id'] : int.tryParse(cat['id']?.toString() ?? '');
                    final catName = cat['name']?.toString() ?? cat['title']?.toString() ?? 'Catégorie';
                    final itemsInCat = shown.where((p) => _categoryIdFromProduct(p) == catId).toList();
                    if (itemsInCat.isEmpty) continue;

                    grouped.add(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(catName, style: Theme.of(context).textTheme.titleMedium),
                    ));

                    for (final p in itemsInCat) {
                      final prodId = p['id']?.toString() ?? UniqueKey().toString();
                      final price = p['price']?.toString() ?? '';
                      final stock = p['stock']?.toString() ?? '';
                      final isLowStock = (p['alert_threshold'] != null && p['stock'] != null) &&
                          (int.tryParse(p['stock']?.toString() ?? '0')! <= int.tryParse(p['alert_threshold']?.toString() ?? '0')!);

                      grouped.add(Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: p['image_url'] != null && p['image_url'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      p['image_url'].toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image),
                                    ),
                                  )
                                : const Icon(Icons.checkroom),
                          ),
                          title: Text(p['name']?.toString() ?? 'Produit'),
                          subtitle: Text('$catName • Stock: $stock'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                price.isNotEmpty ? '\$${price}' : '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (isLowStock)
                                const Text(
                                  'Stock faible',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                            ],
                          ),
                          onTap: () => context.push('/products/detail/$prodId'),
                        ),
                      ));
                    }
                  }

                  // Produits sans catégorie
                  final uncategorized = shown.where((p) => _categoryIdFromProduct(p) == null).toList();
                  if (uncategorized.isNotEmpty) {
                    grouped.add(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Sans catégorie', style: Theme.of(context).textTheme.titleMedium),
                    ));
                    for (final p in uncategorized) {
                      final prodId = p['id']?.toString() ?? UniqueKey().toString();
                      final price = p['price']?.toString() ?? '';
                      final stock = p['stock']?.toString() ?? '';
                      final isLowStock = (p['alert_threshold'] != null && p['stock'] != null) &&
                          (int.tryParse(p['stock']?.toString() ?? '0')! <= int.tryParse(p['alert_threshold']?.toString() ?? '0')!);

                      grouped.add(Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: p['image_url'] != null && p['image_url'].toString().isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      p['image_url'].toString(),
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image),
                                    ),
                                  )
                                : const Icon(Icons.checkroom),
                          ),
                          title: Text(p['name']?.toString() ?? 'Produit'),
                          subtitle: Text('Sans catégorie • Stock: $stock'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                price.isNotEmpty ? '\$${price}' : '',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (isLowStock)
                                const Text(
                                  'Stock faible',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                            ],
                          ),
                          onTap: () => context.push('/products/detail/$prodId'),
                        ),
                      ));
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: grouped,
                  );
                }

                // Si une catégorie est sélectionnée => liste simple
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final p = shown[index];
                    final prodId = p['id']?.toString() ?? index.toString();
                    final price = p['price']?.toString() ?? '';
                    final stock = p['stock']?.toString() ?? '';
                    final catName = _categoryNameForProduct(p, pc.categories);
                    final isLowStock = (p['alert_threshold'] != null && p['stock'] != null) &&
                        (int.tryParse(p['stock']?.toString() ?? '0')! <= int.tryParse(p['alert_threshold']?.toString() ?? '0')!);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: p['image_url'] != null && p['image_url'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p['image_url'].toString(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, st) => const Icon(Icons.broken_image),
                                  ),
                                )
                              : const Icon(Icons.checkroom),
                        ),
                        title: Text(p['name']?.toString() ?? 'Produit'),
                        subtitle: Text('$catName • Stock: $stock'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              price.isNotEmpty ? '\$${price}' : '',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (isLowStock)
                              const Text(
                                'Stock faible',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                          ],
                        ),
                        onTap: () => context.push('/products/detail/$prodId'),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: uc.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/products/add'),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau produit'),
            )
          : null,
    );
  }
}
