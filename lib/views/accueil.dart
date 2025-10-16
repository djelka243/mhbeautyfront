import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mh_beauty/controllers/product.dart';
import 'package:mh_beauty/controllers/sale.dart';
import 'package:mh_beauty/views/widgets/MyDrawer.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/controllers/user.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    // Use addPostFrameCallback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    // Utiliser listen: false dans initState pour éviter les rebuilds inutiles
    final productCtrl = Provider.of<ProductController>(context, listen: false);
    final saleCtrl = Provider.of<SaleController>(context, listen: false);

    await Future.wait([
      productCtrl.fetchProducts(),
      productCtrl.fetchCategories(),
      saleCtrl.fetchSalesHistory(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Get controllers from Provider
    final userCtrl = Provider.of<UserController>(context);
    final productCtrl = Provider.of<ProductController>(context);
    final saleCtrl = Provider.of<SaleController>(context);
    final bool isAdmin = userCtrl.isAdmin;
    final lowStockCount = productCtrl.lowStockProductsCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: Badge(
              label: Text(lowStockCount.toString()),
              isLabelVisible: lowStockCount > 0,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      drawer: MyDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vue d\'ensemble',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _DashboardCard(
                  title: 'Produits',
                  value: productCtrl.products.length.toString(),
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                  onTap: () => context.push('/products'),
                ),
                _DashboardCard(
                  title: 'Ventes du jour',
                  value: saleCtrl.salesToday.toString(),
                  icon: Icons.shopping_cart,
                  color: Colors.green,
                  onTap: () => context.push('/sales/history'),
                ),
                _DashboardCard(
                  title: 'Catégories',
                  value: productCtrl.categories.length.toString(),
                  icon: Icons.category,
                  color: Colors.orange,
                  onTap: () => context.push('/products'), // Or a dedicated categories page
                ),
                if (isAdmin)
                  _DashboardCard(
                    title: 'Utilisateurs',
                    value: 'N/A', // Placeholder, needs a way to get user count
                    icon: Icons.people,
                    color: Colors.purple,
                    onTap: () => context.push('/users'), // Assuming a /users route
                  )
                else
                  _DashboardCard(
                    title: 'Mon Compte',
                    value: '',
                    icon: Icons.person,
                    color: Colors.purple,
                    onTap: () => context.push('/profile'), // Assuming a /profile route
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_shopping_cart),
                title: const Text('Nouvelle vente'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.push('/sales/new'),
              ),
            ),
            const SizedBox(height: 8),
            if (isAdmin)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.add_box),
                  title: const Text('Ajouter un produit'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => context.push('/products/add'),
                ),
              ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Historique des ventes'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => context.push('/sales/history'),
              ),
            ),
            if (isAdmin)
              const SizedBox(height: 8),
            if (isAdmin)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Paramètres'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => context.push('/settings'), // Assuming a /settings route
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          switch (index) {
            case 0:
            // Already on home, do nothing or context.go('/home');
              break;
            case 1:
              context.push('/products');
              break;
            case 2:
              context.push('/sales/new');
              break;
            case 3:
              context.push('/sales/history');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produits',
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Vendre',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}