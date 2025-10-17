import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../controllers/user.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool isLogin = true;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _isFormValid = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeviceDate();
    });
  }

  Future<void> _checkDeviceDate() async {
    try {
      final response = await http.get(
        Uri.parse('https://worldtimeapi.org/api/timezone/Etc/UTC'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final serverDateTime = DateTime.parse(data['datetime']);
        final deviceDateTime = DateTime.now();

        // Calculer la différence en heures
        final difference = deviceDateTime.difference(serverDateTime).inHours.abs();

        // Si la différence est supérieure à 24 heures, afficher l'alerte
        if (difference > 24) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Date incorrecte'),
                ],
              ),
              content: Text(
                'La date de votre appareil semble incorrecte.\n\n'
                    'Date du serveur: ${serverDateTime.day}/${serverDateTime.month}/${serverDateTime.year}\n'
                    'Date de votre appareil: ${deviceDateTime.day}/${deviceDateTime.month}/${deviceDateTime.year}\n\n'
                    'Veuillez corriger la date et l\'heure dans les paramètres de votre téléphone pour continuer.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Compris'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // En cas d'erreur (pas de connexion internet, etc.), on ne bloque pas l'utilisateur
      print('Erreur lors de la vérification de la date: $e');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currentYear = DateTime.now().year;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1B5E20), // couleur de fond contrastante
              Colors.indigo.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  SizedBox(
                    height: size.height * 0.3,
                    child: Image.asset(
                      'assets/images/1.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.storefront,
                          size: 500,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(Icons.email),
                        prefixIconColor: Colors.grey.shade700,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1B5E20),
                            width: 2,
                          ),
                        ),
                      ),
                      controller: _emailCtrl,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir un email';
                        }
                        if (!RegExp(r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$').hasMatch(value)) {
                          return 'Veuillez saisir un email valide';
                        }
                        return null;
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        labelStyle: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.w600,
                        ),
                        prefixIcon: const Icon(Icons.lock),
                        prefixIconColor: Colors.grey.shade700,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1B5E20),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez saisir un mot de passe';
                        }
                        if (value.length < 6) {
                          return 'Le mot de passe doit comporter au moins 6 caractères';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Bouton principal
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _loading = true);
                          final email = _emailCtrl.text.trim();
                          final password = _passwordCtrl.text;
                          final name = _nameCtrl.text.trim();
                          bool ok = false;
                          try {
                            final result = await context
                                .read<UserController>()
                                .login(email, password);

                            if (result['success'] == true) {
                              context.go('/home');
                            } else {
                              final msg = result['message'];
                              if (msg != null && msg.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(msg),
                                      backgroundColor: Colors.red),
                                );
                              } else {}
                            }
                          } finally {
                            print('finally');
                            setState(() => _loading = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                        'Connexion',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Padding(
                    padding: const EdgeInsets.only(top: 32.0),
                    child: Text(
                      '© $currentYear MH Beauty & Création. Tous droits réservés.',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
