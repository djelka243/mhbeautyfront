import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mh_beauty/controllers/closing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ClotureView extends StatefulWidget {
  const ClotureView({super.key});

  @override
  State<ClotureView> createState() => _ClotureViewState();
}

class _ClotureViewState extends State<ClotureView> {
  final TextEditingController _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final closingCtrl = Provider.of<ClosingController>(context, listen: false);
    await closingCtrl.checkTodayClosing();
    if (!closingCtrl.isClosed) {
      await closingCtrl.fetchTodaySummary();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _performClosing() async {
    final closingCtrl = Provider.of<ClosingController>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la clôture'),
        content: const Text(
          'Voulez-vous vraiment clôturer la caisse ? Cette action empêchera toute nouvelle vente jusqu\'à demain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final resp = await closingCtrl.performClosing(notes: _notesCtrl.text.trim());

    if (mounted) {
      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Caisse clôturée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _notesCtrl.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resp['message'] ?? 'Erreur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _printClosingReport() async {
    final closingCtrl = Provider.of<ClosingController>(context, listen: false);
    final summary = closingCtrl.todaySummary;

    if (summary == null) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RAPPORT DE CLÔTURE DE CAISSE',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${summary['date']}'),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // Résumé financier
              pw.Text(
                'RÉSUMÉ FINANCIER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total des ventes:'),
                  pw.Text(
                    '\$${(summary['total_sales'] ?? 0).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nombre de transactions:'),
                  pw.Text('${summary['total_transactions'] ?? 0}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Espèces (CDF):'),
                  pw.Text('\$${(summary['cash_amount'] ?? 0).toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Carte/Mobile (USD):'),
                  pw.Text('\$${(summary['card_amount'] ?? 0).toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 20),

              // Ventes par catégorie
              pw.Text(
                'VENTES PAR CATÉGORIE',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...((summary['sales_by_category'] as Map? ?? {}).entries.map((e) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(e.key),
                    pw.Text('\$${(e.value as num).toStringAsFixed(2)}'),
                  ],
                );
              }).toList()),
              pw.SizedBox(height: 20),

              // Produits vendus
              pw.Text(
                'PRODUITS VENDUS',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              ...((summary['products_sold'] as List? ?? []).map((p) {
                return pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text('${p['product_name']} (x${p['quantity']})'),
                    ),
                    pw.Text('\$${(p['total_price'] as num).toStringAsFixed(2)}'),
                  ],
                );
              }).toList()),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final closingCtrl = Provider.of<ClosingController>(context); // 🔹 utilise le même contrôleur

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clôture de caisse'),
        centerTitle: true,
        actions: [
          if (!closingCtrl.isClosed && closingCtrl.todaySummary != null)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printClosingReport,
              tooltip: 'Imprimer le rapport',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: closingCtrl.loading
          ? const Center(child: CircularProgressIndicator())
          : closingCtrl.isClosed
          ? _buildClosedView(closingCtrl.currentClosing)
          : _buildOpenView(closingCtrl.todaySummary),
    );
  }


  Widget _buildClosedView(Map<String, dynamic>? closing) {
    if (closing == null) {
      return const Center(
        child: Text('Aucune information de clôture disponible'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(
            Icons.lock,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Caisse clôturée',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La caisse a été clôturée le ${DateFormat.yMd().format(DateTime.parse(closing['created_at']))} à ${DateTime.tryParse(closing['created_at'])?.hour}:${DateTime.tryParse(closing['created_at'])?.minute}.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryRow('Total des ventes', '${closing['total_sales']}\$'),
                  _buildSummaryRow('Transactions', '${closing['total_transactions']}'),
                  /*_buildSummaryRow('Franc (CDF)', '${closing['cash_amount']}'),*/
                  _buildSummaryRow('Dollar (USD)', '${closing['card_amount']}\$'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Les ventes seront à nouveau autorisées demain.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenView(Map<String, dynamic>? summary) {
    if (summary == null) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    final totalSales = summary['total_sales'] ?? 0;
    final totalTransactions = summary['total_transactions'] ?? 0;
    final cashAmount = summary['cash_amount'] ?? 0;
    final cardAmount = summary['card_amount'] ?? 0;
    final salesByCategory = summary['sales_by_category'] as Map? ?? {};
    final productsSold = summary['products_sold'] as List? ?? [];

    if (totalTransactions == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucune vente aujourd\'hui',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Ajoutez des ventes avant de clôturer la caisse.'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé du ${DateFormat.yMd().format(DateTime.now())}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Résumé financier principal
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total des ventes',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${totalSales.toStringAsFixed(2)}\$',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildSummaryRow('Transactions', '$totalTransactions'),
                /*  _buildSummaryRow('Franc (CDF)', '${cashAmount/sale['payment_currency']}'),
                  _buildSummaryRow('Dollar (USD)', '${cardAmount.toStringAsFixed(2)}'),*/
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Ventes par catégorie
          if (salesByCategory.isNotEmpty) ...[
            Text(
              'Ventes par catégorie',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: salesByCategory.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          Text(
                            '${(entry.value as num).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Produits vendus
          if (productsSold.isNotEmpty) ...[
            Text(
              'Produits vendus (${productsSold.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: productsSold.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = productsSold[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      product['product_name'] ?? 'Produit',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${product['category'] ?? 'Non catégorisé'} • Qté: ${product['quantity']}',
                    ),
                    trailing: Text(
                      '${(product['total_price'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Détails des ventes
          if (summary['sales_details'] != null) ...[
            Text(
              'Détails des transactions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (summary['sales_details'] as List).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final sale = (summary['sales_details'] as List)[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      sale['invoice_number'] ?? 'N/A',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${sale['customer_name'] ?? 'Client anonyme'} • ${DateFormat.Hm().format(DateTime.parse(sale['sale_date']))}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(sale['total'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          sale['payment_currency'] ?? 'USD',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Notes
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Notes (optionnel)',
              hintText: 'Ajoutez des remarques sur la journée...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton de clôture
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _performClosing,
              icon: const Icon(Icons.lock),
              label: const Text('Clôturer la caisse'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: Colors.red,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '⚠️ Attention : Après la clôture, aucune vente ne pourra être enregistrée jusqu\'à demain.',
            style: TextStyle(
              color: Colors.orange,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Texte de gauche tronqué si trop long
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // 🔹 Texte de droite aligné à droite et tronqué si nécessaire
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

}