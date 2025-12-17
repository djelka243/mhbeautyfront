import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mh_beauty/controllers/sale.dart';
import 'package:table_calendar/table_calendar.dart';

class SalesHistoryView extends StatefulWidget {
  const SalesHistoryView({super.key});

  @override
  State<SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<SalesHistoryView> {
  String _selectedFilter = 'Aujourd\'hui';
  bool _loading = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showCalendar = true; // Contrôle l'affichage du calendrier en mode "Mois" et "Toutes"

  @override
  void initState() {
    super.initState();
    _loadSales();
    _selectedDay = _focusedDay;
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
      // Retourner TOUTES les ventes du mois en cours
      return sales.where((s) {
        final d = DateTime.parse(s['sale_date']);
        return d.year == now.year && d.month == now.month;
      }).toList();
    }
    // Pour "Toutes", retourner toutes les ventes
    return sales;
  }

  List<Map<String, dynamic>> _getFilteredSalesByDay(List<Map<String, dynamic>> sales) {
    if (_selectedDay == null) return [];
    return sales.where((s) {
      final d = DateTime.parse(s['sale_date']);
      return d.year == _selectedDay!.year &&
          d.month == _selectedDay!.month &&
          d.day == _selectedDay!.day;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupSalesByYearMonth(
      List<Map<String, dynamic>> sales) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final sale in sales) {
      final d = DateTime.parse(sale['sale_date']);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(sale);
    }
    return Map.fromEntries(
      grouped.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _showCalendar = false; // Masquer le calendrier après sélection
      });
    }
  }

  Widget _buildSalesList(BuildContext context, List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return Center(
        child: Text(
          'Aucune vente trouvée',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        final date = DateTime.parse(sale['sale_date']);
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
        final client = sale['customer_name']?.toString().isNotEmpty == true
            ? sale['customer_name']
            : 'Client inconnu';
        final total = (sale['total'] ?? 0).toStringAsFixed(2);
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
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text('${index + 1}'),
            ),
            title: Text(
              client,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: Text(dateStr),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total \$',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '$itemsCount articles',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            onTap: () => context.push('/sales/${sale['id']}'),
          ),
        );
      },
    );
  }

  Widget _buildGroupedSalesList(
      BuildContext context, List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return Center(
        child: Text(
          'Aucune vente trouvée',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    final groupedSales = _groupSalesByYearMonth(sales);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedSales.length,
      itemBuilder: (context, groupIndex) {
        final monthYear = groupedSales.keys.elementAt(groupIndex);
        final monthlySales = groupedSales[monthYear]!;
        final parts = monthYear.split('-');
        final year = parts[0];
        final month = int.parse(parts[1]);
        final monthName = DateFormat('MMMM').format(DateTime(int.parse(year), month));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '$monthName $year',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ...monthlySales.asMap().entries.map((entry) {
              final index = entry.key;
              final sale = entry.value;
              final date = DateTime.parse(sale['sale_date']);
              final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
              final client = sale['customer_name']?.toString().isNotEmpty == true
                  ? sale['customer_name']
                  : 'Client inconnu';
              final total = (sale['total'] ?? 0).toStringAsFixed(2);
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
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(
                    client,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  subtitle: Text(dateStr),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$total \$',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '$itemsCount articles',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => context.push('/sales/${sale['id']}'),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildContentByFilter(
      BuildContext context,
      List<Map<String, dynamic>> sales,
      List<Map<String, dynamic>> allSales) {
    if (_selectedFilter == 'Aujourd\'hui') {
      return _buildSalesList(context, sales);
    } else if (_selectedFilter == 'Mois') {
      return Column(
        children: [
          // Afficher le calendrier ou un bouton pour le rouvrir
          if (_showCalendar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar(
                    firstDay: DateTime(_focusedDay.year, _focusedDay.month, 1),
                    lastDay: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: Theme.of(context).textTheme.titleMedium!,
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: Theme.of(context).textTheme.bodyMedium!,
                      defaultTextStyle: Theme.of(context).textTheme.bodyMedium!,
                    ),
                  ),
                ),
              ),
            )
          else if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Changer la date (${DateFormat('dd/MM/yyyy').format(_selectedDay!)})',
                ),
                onPressed: () {
                  setState(() {
                    _showCalendar = true;
                  });
                },
              ),
            ),
          const SizedBox(height: 12),
          // Liste des ventes du jour sélectionné ou du mois
          Expanded(
            child: _buildSalesList(
              context,
              _showCalendar ? sales : _getFilteredSalesByDay(sales),
            ),
          ),
        ],
      );
    } else {
      // "Toutes" - afficher avec groupement par mois
      return Column(
        children: [
          // Afficher le calendrier ou un bouton pour le rouvrir
          if (_showCalendar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: _onDaySelected,
                    onPageChanged: (focusedDay) {
                      setState(() {
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: Theme.of(context).textTheme.titleMedium!,
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: Theme.of(context).textTheme.bodyMedium!,
                      defaultTextStyle: Theme.of(context).textTheme.bodyMedium!,
                    ),
                  ),
                ),
              ),
            )
          else if (_selectedDay != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  'Changer la date (${DateFormat('dd/MM/yyyy').format(_selectedDay!)})',
                ),
                onPressed: () {
                  setState(() {
                    _showCalendar = true;
                  });
                },
              ),
            ),
          const SizedBox(height: 12),
          // Liste groupée par année/mois ou ventes du jour sélectionné
          Expanded(
            child: _showCalendar
                ? _buildGroupedSalesList(context, allSales)
                : _buildSalesList(context, _getFilteredSalesByDay(allSales)),
          ),
        ],
      );
    }
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

    // Calcul des totaux du jour sélectionné en mode "Mois" et "Toutes"
    List<Map<String, dynamic>> daySales = [];
    double dayAmount = 0.0;
    if (_selectedDay != null && !_showCalendar && (_selectedFilter == 'Mois' || _selectedFilter == 'Toutes')) {
      daySales = _getFilteredSalesByDay(sc.sales);
      dayAmount = daySales.fold<double>(
        0.0,
        (sum, s) => sum + (s['total'] is num
            ? (s['total'] as num).toDouble()
            : double.tryParse(s['total'].toString()) ?? 0),
      );
    }

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
                // --- Sélecteur de filtre ---
                Padding(
                  padding: const EdgeInsets.all(16),
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
                        _showCalendar = true;
                        if (_selectedFilter == 'Mois') {
                          _focusedDay = DateTime.now();
                          _selectedDay = null;
                        }
                      });
                    },
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
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFilter == 'Aujourd\'hui'
                                        ? 'Ventes du jour'
                                        : _selectedFilter == 'Mois'
                                            ? 'Ventes du mois'
                                            : 'Toutes les ventes',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${filteredSales.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Chiffre d\'affaires',
                                    style: Theme.of(context).textTheme.bodySmall,
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
                          // Sous-totaux du jour sélectionné
                          if (_selectedDay != null && !_showCalendar && (_selectedFilter == 'Mois' || _selectedFilter == 'Toutes'))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                children: [
                                  Divider(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Jour sélectionné (${DateFormat('dd/MM/yyyy').format(_selectedDay!)})',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${daySales.length}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '',
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${dayAmount.toStringAsFixed(2)} \$',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Contenu selon le filtre ---
                Expanded(
                  child: _buildContentByFilter(context, filteredSales, sc.sales),
                ),
              ],
            ),
    );
  }
}
