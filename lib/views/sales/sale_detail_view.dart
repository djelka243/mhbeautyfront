import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/sale.dart';
import '../../controllers/user.dart';

class SaleDetailView extends StatefulWidget {
  final String saleId;

  const SaleDetailView({super.key, required this.saleId});

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  Map<String, dynamic>? sale;
  bool loading = true;
  bool error = false;

  @override
  void initState() {
    super.initState();
    _loadSaleDetail();
  }

  Future<void> _loadSaleDetail() async {
    try {
      final sc = Provider.of<SaleController>(context, listen: false);
      final data = await sc.fetchSaleDetail(widget.saleId);
      if (mounted) {
        setState(() {
          sale = data;
          loading = false;
          error = data == null;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadSaleDetail: $e');
      setState(() {
        loading = false;
        error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error || sale == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erreur')),
        body: const Center(
          child: Text('Impossible de charger les détails de la facture.'),
        ),
      );
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    // ===== DONNÉES DE LA VENTE =====
    final items = (sale!['products'] as List?) ?? [];
    final subtotal = parseDouble(sale!['subtotal']);
    final total = parseDouble(sale!['total']);
    final deliveryUsd = parseDouble(sale!['delivery']); // Stocké en USD dans la BD

    final client = (sale!['client'] ?? 'Client inconnu').toString();
    final phone = (sale!['phone'] ?? '-').toString();
    final userName = (sale!['user']?['name'] ?? 'Inconnu').toString();
    final status = (sale!['status'] ?? 'En attente').toString();
    final date = (sale!['date'] ?? sale!['created_at']).toString();

    // ===== INFORMATIONS DE PAIEMENT =====
    final currency = (sale!['currency'] ?? 'USD').toString();
    final exchangeRate = parseDouble(sale!['exchange']);
    final amountGiven = parseDouble(sale!['amount']); // Dans la devise de paiement
    final changeReturned = parseDouble(sale!['returned']); // Dans la devise de paiement

    // ===== CONVERSIONS =====
    // Livraison : toujours stockée en USD, on convertit si nécessaire
    final deliveryCdf = deliveryUsd * exchangeRate;

    // Sous-total des produits (sans livraison ni taxe)
    double productSubtotal = 0.0;
    for (var item in items) {
      final qty = item['quantity'] ?? 0;
      final unitPrice = parseDouble(item['unit_price']);
      productSubtotal += qty * unitPrice;
    }

    // Date formatée
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(date).toLocal();
    } catch (_) {
      parsedDate = DateTime.now();
    }
    final formattedDate = DateFormat('dd/MM/yyyy – HH:mm').format(parsedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Facture #${sale!['invoice_number']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final controller = context.read<UserController>();
              await controller.printInvoice(context, sale!);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Informations générales
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Numéro de facture', sale!['invoice_number']),
                    _infoRow('Vendu par', userName),
                    const Divider(),
                    _infoRow('Client', client),
                    _infoRow('Téléphone', phone),
                    _infoRow('Date', formattedDate),
                    _infoRow(
                      'Statut',
                      status == 'completed' ? 'Payée' : 'En attente',
                      valueColor: status == 'completed'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Détails du paiement
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informations de paiement',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Devise', currency),
                    _infoRow(
                      'Taux de change',
                      '1 USD = ${exchangeRate.toStringAsFixed(0)} CDF',
                    ),
                    if (amountGiven > 0) ...[
                      _infoRow(
                        'Montant donné',
                        currency == 'USD'
                            ? '\$${amountGiven.toStringAsFixed(2)}'
                            : '${amountGiven.toStringAsFixed(0)} FC',
                      ),
                      _infoRow(
                        'Monnaie rendue',
                        currency == 'USD'
                            ? '\$${changeReturned.toStringAsFixed(2)}'
                            : '${changeReturned.toStringAsFixed(0)} FC',
                        valueColor: changeReturned >= 0 ? Colors.green : Colors.red,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🔹 Articles
            Text('Articles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            ...items.map((item) {
              final qty = item['quantity'] ?? 0;
              final unitPrice = parseDouble(item['unit_price']);
              final itemSubtotal = qty * unitPrice;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'] ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('Prix unitaire : \$${unitPrice.toStringAsFixed(2)}'),
                            Text('Quantité : $qty'),
                            Text('Sous-total : \$${itemSubtotal.toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // 🔹 Résumé total
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _summaryRow(
                      'Sous-total produits',
                      '\$${productSubtotal.toStringAsFixed(2)}',
                    ),
                    if (deliveryUsd > 0) ...[
                      _summaryRow(
                        'Livraison',
                        currency == 'USD'
                            ? '\$${deliveryUsd.toStringAsFixed(2)}'
                            : '${deliveryCdf.toStringAsFixed(0)} FC',
                      ),
                      _summaryRow(
                        'Livraison (équivalent)',
                        currency == 'USD'
                            ? '≈ ${deliveryCdf.toStringAsFixed(0)} FC'
                            : '≈ \$${deliveryUsd.toStringAsFixed(2)}',
                        isSecondary: true,
                      ),
                    ],
                    const Divider(height: 24),
                    _summaryRow(
                      'TOTAL PAYÉ',
                      '\$${total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                   /* _summaryRow(
                      'Total en ${currency == 'USD' ? 'CDF' : 'USD'}',
                      currency == 'USD'
                          ? '≈ ${(total * exchangeRate).toStringAsFixed(0)} FC'
                          : '≈ \$${(total / exchangeRate).toStringAsFixed(2)}',
                      isSecondary: true,
                    ),*/
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 🔹 Impression
            FilledButton.icon(
              onPressed: () async {
                final controller = context.read<UserController>();
                await controller.printInvoice(context, sale!);
              },
              icon: const Icon(Icons.print),
              label: const Text('Imprimer la facture'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, bool isSecondary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isSecondary ? Colors.grey.shade600 : null,
              fontSize: isSecondary ? 13 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isSecondary ? Colors.grey.shade600 : null,
              fontSize: isSecondary ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }
}