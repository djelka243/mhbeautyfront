import 'package:flutter/material.dart';
import 'package:mh_beauty/controllers/closing.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/routes/appRouter.dart';
import 'package:mh_beauty/controllers/user.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mh_beauty/controllers/product.dart';

import 'controllers/sale.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  final userController = UserController();
  final productController = ProductController();
  final saleController = SaleController();
  final closingController = ClosingController();
  final appRouter = AppRouter(userController: userController);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userController),
        ChangeNotifierProvider.value(value: productController),
        ChangeNotifierProvider.value(value: saleController),
        ChangeNotifierProvider.value(value: closingController)
      ],
      child: MyApp(appRouter: appRouter),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;
  const MyApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    final darkMode = context.watch<UserController>().darkMode;

    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.white,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.dark,

      ),
      useMaterial3: true,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    final currentTheme = darkMode ? darkTheme : lightTheme;

    return AnimatedTheme(
      data: currentTheme,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: MaterialApp.router(
        title: 'MH Beauty & Création',
        debugShowCheckedModeBanner: false,
        theme: currentTheme,
        routerConfig: appRouter.router,
      ),
    );
  }
}