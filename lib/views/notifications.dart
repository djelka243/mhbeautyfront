import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final productCtrl = Provider.of<ProductController>(context);
    final lowStockProducts = productCtrl.lowStockProducts;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (lowStockProducts.isNotEmpty)
            TextButton(
              onPressed: productCtrl.markAllAsRead,
              child: const Text(
                'Marquer comme lu',
               // style: TextStyle(color: Colors.white),
              ),
            )
        ],
      ),
      body: lowStockProducts.isEmpty
          ? const Center(
        child: Text(
          'Aucune notification de stock faible',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: lowStockProducts.length,
        itemBuilder: (context, index) {
          final product = lowStockProducts[index];
          final isRead = productCtrl.isProductRead(product);
          final updatedAt = DateTime.tryParse(product['updated_at'] ?? '');
          final formattedDate =
          updatedAt != null ? dateFormat.format(updatedAt) : '-';

          return Card(
         //   color: isRead ? Colors.grey[100] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                isRead ? Colors.grey[300] : Colors.red[100],
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: isRead ? Colors.grey[600] : Colors.red,
                  size: 26,
                ),
              ),
              title: Text(
                product['name'] ?? 'Produit sans nom',
                style: TextStyle(
                  fontWeight:
                  isRead ? FontWeight.normal : FontWeight.bold,
             //     color: isRead ? Colors.grey[700] : Colors.black,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stock actuel : ${product['stock']}'),
                  Text('Seuil : ${product['alert_threshold']}'),
                  const SizedBox(height: 4),
                  Text(
                    "Mis à jour le $formattedDate",
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                productCtrl.markProductAsRead(product['id']);
                context.push('/products/detail/${product['id']}');
              },
            ),
          );
        },
      ),
    );
  }
}
