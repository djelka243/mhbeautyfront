import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mh_beauty/views/notifications.dart';
import 'package:provider/provider.dart';
import '../controllers/sale.dart';
import '../controllers/user.dart';
import '../views/accueil.dart';
import '../views/login_view.dart';
import '../views/products/products_list_view.dart';
import '../views/products/product_form_view.dart';
import '../views/sales/new_sale_view.dart';
import '../views/sales/sales_history_view.dart';
import '../views/sales/sale_detail_view.dart';
import '../views/settings_view.dart';
import '../views/parametres/editprofil.dart';
import '../views/parametres/changermdp.dart';
import '../views/parametres/infomagasin.dart';
import '../views/parametres/gerercategories.dart';
import '../views/parametres/confiprix.dart';
import '../views/parametres/aide.dart';
import '../views/parametres/apropo.dart';
import '../views/parametres/conduse.dart';
import '../views/products/product_detail_view.dart';

class AppRouter {
  final UserController userController;

  AppRouter({required this.userController});

  late final GoRouter router = GoRouter(
    refreshListenable: userController,
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsListView(),
      ),
      GoRoute(
        path: '/products/add',
        builder: (context, state) => const ProductFormView(),
      ),
      GoRoute(
        path: '/products/edit/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return ProductFormView(productId: id);
        },
      ),
      GoRoute(
        path: '/products/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return ProductDetailView(productId: id ?? '');
        },
      ),
      GoRoute(
        path: '/sales/new',
        builder: (context, state) => const NewSaleView(),
      ),
      GoRoute(
        path: '/sales/history',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => SaleController(),
          child: const SalesHistoryView(),
        ),
      //  builder: (context, state) => const SalesHistoryView(),
      ),
      GoRoute(
        path: '/sales/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return SaleDetailView(saleId: id ?? '1');
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: '/settings/edit-profil',
        builder: (context, state) => const EditProfilView(),
      ),
      GoRoute(
        path: '/settings/change-password',
        builder: (context, state) => const ChangeMdpView(),
      ),
      GoRoute(
        path: '/settings/info-magasin',
        builder: (context, state) => const InfoMagasinView(),
      ),
      GoRoute(
        path: '/settings/categories',
        builder: (context, state) => const GererCategoriesView(),
      ),
      GoRoute(
        path: '/settings/pricing',
        builder: (context, state) => const ConfigPrixView(),
      ),
      GoRoute(
        path: '/settings/help',
        builder: (context, state) => const AideView(),
      ),
      GoRoute(
        path: '/settings/about',
        builder: (context, state) => const AProposView(),
      ),
      GoRoute(
        path: '/settings/terms',
        builder: (context, state) => const ConduseView(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsView(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
      final bool loggedIn = userController.isAuthenticated;
      final bool loggingIn = state.matchedLocation == '/';

      if (!loggedIn) {
        return loggingIn ? null : '/';
      }

      if (loggingIn) {
        return '/home';
      }

      return null;
    },
  );
}