import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/user.dart';
import 'package:go_router/go_router.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}


_logout(BuildContext context) {
  final userCtrl = Provider.of<UserController>(context, listen: false);
  userCtrl.logout();
  context.go('/');
}

class _MyDrawerState extends State<MyDrawer> {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Consumer<UserController>(builder: (context, userCtrl, _) {
            final user = userCtrl.user;
            final name = user?['name'] ?? 'Utilisateur';
            final email = user?['email'] ?? 'email@exemple.com';
            return DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 35,
                    child: Icon(Icons.person, size: 60),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            );
          }),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Accueil'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('Produits'),
            onTap: () {
              Navigator.pop(context);
              context.push('/products');
            },
          ),
          ListTile(
            leading: const Icon(Icons.point_of_sale),
            title: const Text('Nouvelle vente'),
            onTap: () {
              Navigator.pop(context);
              context.push('/sales/new');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historique ventes'),
            onTap: () {
              Navigator.pop(context);
              context.push('/sales/history');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              context.push('/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
