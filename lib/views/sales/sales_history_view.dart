import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mh_beauty/controllers/sale.dart';
import 'package:mh_beauty/controllers/user.dart';
import 'package:table_calendar/table_calendar.dart';

class SalesHistoryView extends StatefulWidget {
  const SalesHistoryView({super.key});

  @override
  State<SalesHistoryView> createState() => _SalesHistoryViewState();
}

class _SalesHistoryViewState extends State<SalesHistoryView> {
  String _selectedFilter = "Aujourd'hui";
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  DateTime? _selectedMonth;
  bool _showCalendar = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSales(refresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final sc = Provider.of<SaleController>(context, listen: false);
      if (sc.hasMore && !sc.loadingMore && !sc.loading) {
        _loadSales();
      }
    }
  }

  Future<void> _loadSales({bool refresh = false}) async {
    if (!mounted) return;
    final sc = Provider.of<SaleController>(context, listen: false);

    String? dateParam;
    int? monthParam;
    int? yearParam;

    if (_selectedDay != null) {
      // Priorité au jour sélectionné (tous filtres confondus)
      dateParam = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    } else if (_selectedFilter == "Aujourd'hui") {
      dateParam = DateFormat('yyyy-MM-dd').format(DateTime.now());
    } else if (_selectedFilter == "Mois") {
      monthParam = DateTime.now().month;
      yearParam = DateTime.now().year;
    } else if (_selectedFilter == "Toutes" && _selectedMonth != null) {
      monthParam = _selectedMonth!.month;
      yearParam = _selectedMonth!.year;
    }
    // else "Toutes" sans filtre → pas de params → toutes les ventes

    await sc.fetchSalesHistory(
      refresh: refresh,
      date: dateParam,
      month: monthParam,
      year: yearParam,
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _selectedMonth = null;
      _focusedDay = focusedDay;
      _showCalendar = false;
    });
    _loadSales(refresh: true);
  }

  void _onMonthSelected(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _selectedDay = null;
      _focusedDay = month;
      _showCalendar = false;
    });
    _loadSales(refresh: true);
  }

  String _getSummaryLabel() {
    if (_selectedDay != null) return 'Ventes du jour';
    if (_selectedFilter == "Aujourd'hui") return 'Ventes du jour';
    if (_selectedFilter == 'Mois') return 'Ventes du mois';
    if (_selectedMonth != null) return 'Ventes du mois';
    return 'Toutes les ventes';
  }

  Widget _buildSaleCard(BuildContext context, Map<String, dynamic> sale, int index) {
    final dString = sale['sale_date'] ?? sale['created_at'];
    final date = dString != null ? DateTime.parse(dString) : DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(date);
    final client = sale['customer_name']?.toString().isNotEmpty == true
        ? sale['customer_name']
        : 'Client inconnu';
    final total = (sale['total'] ?? 0).toStringAsFixed(2);
    final itemsCount = (sale['products'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text('${index + 1}'),
        ),
        title: Text(
          client,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(dateStr),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$total \$',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('$itemsCount articles',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        onTap: () => context.push('/sales/${sale['id']}'),
      ),
    );
  }

  Widget _buildSalesList(
      BuildContext context,
      List<Map<String, dynamic>> sales,
      bool loadingMore,
      ) {
    if (sales.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('Aucune vente trouvée',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sales.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == sales.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildSaleCard(context, sales[index], index);
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupSalesByYearMonth(
      List<Map<String, dynamic>> sales) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final sale in sales) {
      final dString = sale['sale_date'] ?? sale['created_at'];
      if (dString == null) continue;
      final d = DateTime.parse(dString);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(sale);
    }
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  Widget _buildGroupedSalesList(
      BuildContext context,
      List<Map<String, dynamic>> sales,
      bool loadingMore,
      ) {
    if (sales.isEmpty) {
      return Center(
        child: Text('Aucune vente trouvée',
            style: Theme.of(context).textTheme.titleMedium),
      );
    }

    final groupedSales = _groupSalesByYearMonth(sales);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedSales.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, groupIndex) {
        if (groupIndex == groupedSales.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final monthYear = groupedSales.keys.elementAt(groupIndex);
        final monthlySales = groupedSales[monthYear]!;
        final parts = monthYear.split('-');
        final year = parts[0];
        final month = int.parse(parts[1]);
        final monthName =
        DateFormat('MMMM').format(DateTime(int.parse(year), month));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '$monthName $year',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...monthlySales.asMap().entries.map(
                  (entry) => _buildSaleCard(context, entry.value, entry.key),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarToggle() {
    final String label = _selectedDay != null
        ? 'Jour : ${DateFormat('dd/MM/yyyy').format(_selectedDay!)}'
        : _selectedMonth != null
        ? 'Mois : ${DateFormat('MMMM yyyy').format(_selectedMonth!)}'
        : _selectedFilter == 'Mois'
        ? 'Mois : ${DateFormat('MMMM yyyy').format(DateTime.now())}'
        : 'Filtrer par date';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => setState(() => _showCalendar = !_showCalendar),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border:
            Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Icon(_showCalendar
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sc = Provider.of<SaleController>(context);
    final uc = Provider.of<UserController>(context);
    final isAdmin = uc.isAdmin;

    // CA stable venant du backend, pas recalculé à chaque page
    final totalAmount = sc.totalRevenue;
    final totalSalesCount =
    sc.totalCount > 0 ? sc.totalCount : sc.sales.length;

    // Afficher le CA dès qu'un filtre est actif, ou si admin
    final bool showCA = isAdmin ||
        _selectedFilter != 'Toutes' ||
        _selectedDay != null ||
        _selectedMonth != null;

    // Dans "Toutes" sans filtre : liste groupée par mois
    final bool showGrouped = _selectedFilter == 'Toutes' &&
        _selectedDay == null &&
        _selectedMonth == null;

    // Bornes du calendrier
    final now = DateTime.now();
    final firstDay = _selectedFilter == 'Mois'
        ? DateTime(now.year, now.month, 1)
        : DateTime.utc(2020, 1, 1);
    final lastDay = _selectedFilter == 'Mois'
        ? DateTime(now.year, now.month + 1, 0)
        : DateTime.utc(2030, 12, 31);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des ventes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadSales(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre principal
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: "Aujourd'hui", label: Text("Aujourd'hui")),
                ButtonSegment(value: 'Mois', label: Text('Ce mois')),
                ButtonSegment(value: 'Toutes', label: Text('Toutes')),
              ],
              selected: {_selectedFilter},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedFilter = newSelection.first;
                  _selectedDay = null;
                  _selectedMonth = null;
                  _showCalendar = false;
                  _focusedDay = DateTime.now();
                });
                _loadSales(refresh: true);
              },
            ),
          ),

          // Carte résumé
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getSummaryLabel(),
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          '$totalSalesCount',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (showCA)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Chiffre d'affaires",
                              style: Theme.of(context).textTheme.bodySmall),
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

          // Toggle calendrier (masqué pour "Aujourd'hui")
          if (_selectedFilter != "Aujourd'hui") _buildCalendarToggle(),

          // Calendrier
          if (_showCalendar)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Column(
                  children: [
                    TableCalendar(
                      firstDay: firstDay,
                      lastDay: lastDay,
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: _onDaySelected,
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDay = focusedDay);
                      },
                      calendarFormat: CalendarFormat.month,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        leftChevronVisible: _selectedFilter != 'Mois',
                        rightChevronVisible: _selectedFilter != 'Mois',
                      ),
                    ),
                    // Bouton sélection mois uniquement dans "Toutes"
                    if (_selectedFilter == 'Toutes')
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: OutlinedButton.icon(
                          onPressed: () => _onMonthSelected(
                            DateTime(_focusedDay.year, _focusedDay.month),
                          ),
                          icon: const Icon(Icons.calendar_view_month),
                          label: Text(
                            'Sélectionner ${DateFormat('MMMM yyyy').format(_focusedDay)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Liste des ventes
          Expanded(
            child: sc.loading && sc.sales.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : showGrouped
                ? _buildGroupedSalesList(
                context, sc.sales, sc.loadingMore)
                : _buildSalesList(context, sc.sales, sc.loadingMore),
          ),
        ],
      ),
    );
  }
}