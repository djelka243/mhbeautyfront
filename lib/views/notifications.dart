import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:provider/provider.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final productCtrl = Provider.of<ProductController>(context);
    final lowStockProducts = productCtrl.lowStockProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications de stock faible'),
      ),
      body: lowStockProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'Aucune notification',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[600]),
                  ),
                  const Text(
                    'Tous vos produits ont un stock suffisant.',
                    style: TextStyle(color: Colors.grey),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              itemCount: lowStockProducts.length,
              itemBuilder: (context, index) {
                final product = lowStockProducts[index];
                final stock = product['stock'] ?? 0;
                final alertThreshold = product['alert_threshold'] ?? 10;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: Colors.red[100],
                      child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                    ),
                    title: Text(
                      product['name'] ?? 'Produit sans nom',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('Stock actuel : $stock'),
                        Text('Seuil d\'alerte : $alertThreshold'),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      // Optionnel : naviguer vers la page de détail du produit
                       if (product.containsKey('id')) {
                         context.push('/products/detail/${product['id']}');
                       }
                    },
                  ),
                );
              },
            ),
    );
  }
}
