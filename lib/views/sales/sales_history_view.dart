import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mh_beauty/controllers/sale.dart';

class SalesHistoryView extends StatefulWidget {
  const SalesHistoryView({super.key});

  @override
  State<SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<SalesHistoryView> {
  String _selectedFilter = 'Aujourd\'hui';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    final sc = Provider.of<SaleController>(context, listen: false);
    setState(() => _loading = true);
    await sc.fetchSalesHistory();
    setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _getFilteredSales(List<Map<String, dynamic>> sales) {
    final now = DateTime.now();

    if (_selectedFilter == "Aujourd'hui") {
      return sales.where((s) {
        final d = DateTime.parse(s['sale_date']);
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList();
    } else if (_selectedFilter == "Mois") {
      return sales.where((s) {
        final d = DateTime.parse(s['sale_date']);
        return d.year == now.year && d.month == now.month;
      }).toList();
    }
    return sales;
  }

  @override
  Widget build(BuildContext context) {

        final sc = Provider.of<SaleController>(context);
        final filteredSales = _getFilteredSales(sc.sales);
        final totalAmount = filteredSales.fold<double>(
          0.0,
              (sum, s) => sum + (s['total'] is num
              ? (s['total'] as num).toDouble()
              : double.tryParse(s['total'].toString()) ?? 0),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Historique des ventes'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadSales,
              ),
            ],
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Aujourd\'hui', label: Text('Aujourd\'hui')),
                          ButtonSegment(value: 'Mois', label: Text('Ce mois')),
                          ButtonSegment(value: 'Toutes', label: Text('Toutes')),
                        ],
                        selected: {_selectedFilter},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedFilter = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // --- Résumé des ventes ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total des ventes',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${filteredSales.length} ventes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Chiffre d\'affaires',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${totalAmount.toStringAsFixed(2)} \$',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --- Liste des ventes ---
              Expanded(
                child: filteredSales.isEmpty
                    ? Center(
                  child: Text(
                    'Aucune vente trouvée',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSales.length,
                  itemBuilder: (context, index) {
                    final sale = filteredSales[index];
                    final date = DateTime.parse(sale['sale_date']);
                    final dateStr =
                    DateFormat('dd/MM/yyyy HH:mm').format(date);
                    final client =
                    sale['customer_name']?.toString().isNotEmpty == true
                        ? sale['customer_name']
                        : 'Client inconnu';
                    final total =
                    (sale['total'] ?? 0).toStringAsFixed(2);
                    final itemsCount = (sale['products'] as List?)?.length ?? 0;


                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          client,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(dateStr),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment:
                          CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$total \$',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${itemsCount ?? 0} articles',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                          ],
                        ),
                        onTap: () => context.push('/sales/${sale['id']}'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );

  }
}
