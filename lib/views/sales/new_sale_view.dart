import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mh_beauty/controllers/sale.dart';

class NewSaleView extends StatefulWidget {
  const NewSaleView({super.key});

  @override
  State<NewSaleView> createState() => _NewSaleViewState();
}

class _NewSaleViewState extends State<NewSaleView> {
  final _searchCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _deliveryCtrl = TextEditingController();
  final _amountGivenCtrl = TextEditingController();

  bool _hasDelivery = false;
  String _selectedCurrency = 'USD';
  double _exchangeRate = 1.0;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadExchangeRate(SaleController sc) async {
    final rate = await sc.fetchExchangeRate();
    if (mounted) setState(() => _exchangeRate = rate);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _clientCtrl.dispose();
    _phoneCtrl.dispose();
    _deliveryCtrl.dispose();
    _amountGivenCtrl.dispose();
    super.dispose();
  }

  double get _deliveryAmount => !_hasDelivery ? 0.0 : double.tryParse(_deliveryCtrl.text) ?? 0.0;
  double get _amountGiven => double.tryParse(_amountGivenCtrl.text) ?? 0.0;

  /// Calcule le total (en USD de référence) sans double conversion
  double _getTotalWithDelivery(double cartTotal) {
    if (!_hasDelivery) return cartTotal;

    // La livraison est toujours saisie en CDF → convertir en USD avant addition
    double deliveryUsd = _deliveryAmount / _exchangeRate;
    return cartTotal + deliveryUsd;
  }

  /// Calcule la monnaie à rendre selon la devise du paiement
  double _getChange(double totalUsdWithDelivery) {
    double totalInPaymentCurrency;

    if (_selectedCurrency == 'CDF') {
      // Total converti en CDF
      totalInPaymentCurrency = totalUsdWithDelivery * _exchangeRate;
    } else {
      // Paiement en USD
      totalInPaymentCurrency = totalUsdWithDelivery;
    }

    return _amountGiven - totalInPaymentCurrency;
  }
  


  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SaleController(),
      child: Consumer<SaleController>(
        builder: (context, sc, _) {
          if (_exchangeRate == 1.0) _loadExchangeRate(sc);

          final totalWithDelivery = _getTotalWithDelivery(sc.total);
          final change = _getChange(totalWithDelivery);

          return Scaffold(
            appBar: AppBar(
              title: const Text('Nouvelle vente'),
              centerTitle: true,
              elevation: 0,
            ),
            body: Column(
              children: [
                // --- Barre d'étapes moderne ---
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: List.generate(4, (index) {
                      final active = _currentStep == index;
                      final done = _currentStep > index;
                      final steps = ["Produits", "Paiement", "Client", "Résumé"];
                      return Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: done
                                      ? Colors.green
                                      : active
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade300,
                                  child: Icon(
                                    done
                                        ? Icons.check
                                        : index == 0
                                        ? Icons.shopping_cart
                                        : index == 1
                                        ? Icons.payments
                                        : index == 2
                                        ? Icons.person
                                        : Icons.receipt,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                if (index < 3)
                                  Expanded(
                                    child: Container(
                                      height: 2,
                                      color: _currentStep > index
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              steps[index],
                              style: TextStyle(
                                fontSize: 12,
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                const Divider(height: 1),

                // --- Contenu dynamique ---
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(sc, totalWithDelivery, change),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        child: const Text('Précédent'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        if (_currentStep == 0 && sc.cart.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Ajoutez des produits avant de continuer'),
                            ),
                          );
                          return;
                        }
                        if (_currentStep == 1 && (_amountGiven > 0 && change < 0)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Montant donné insuffisant')),
                          );
                          return;
                        }
                        if (_currentStep == 1) {
                          if (_hasDelivery && (_deliveryCtrl.text.trim().isEmpty || double.tryParse(_deliveryCtrl.text) == null)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Veuillez indiquer les frais de livraison')),
                            );
                            return;
                          }
                        }

                        if (_currentStep == 2 && _clientCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Le nom du client est obligatoire')),
                          );
                          return;
                        }

                        if (_currentStep < 3) {
                          setState(() => _currentStep++);
                        } else {
                          _submitSale(sc, totalWithDelivery, change);
                        }

                      },
                      child: Text(_currentStep == 3 ? 'Valider la vente' : 'Suivant'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Contenu des étapes ---
  Widget _buildStepContent(SaleController sc, double totalWithDelivery, double change) {
    switch (_currentStep) {
      case 0:
        return _buildStepProducts(sc);
      case 1:
        return _buildStepPayment(sc, totalWithDelivery, change);
      case 2:
        return _buildStepClient();
      case 3:
      default:
        return _buildStepSummary(sc, totalWithDelivery, change);
    }
  }

  // ÉTAPE 1 : PRODUITS
  Widget _buildStepProducts(SaleController sc) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => sc.searchProducts(v),
            decoration: InputDecoration(
              hintText: 'Rechercher un produit...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: sc.loading
                  ? const Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : (_searchCtrl.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchCtrl.clear();
                  sc.searchProducts('');
                },
              )
                  : null),
            ),
          ),
          const SizedBox(height: 10),
        if (sc.searchResults.isNotEmpty)
    Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: sc.searchResults.length,
        itemBuilder: (context, i) {
          final p = sc.searchResults[i];
          final name = p['name']?.toString() ?? 'Produit';
          final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0.0;

          // Vérifie si ce produit est déjà dans le panier
          final existing = sc.cart.firstWhere(
                (e) => e['id'] == p['id'],
            orElse: () => {},
          );

          final isInCart = existing.isNotEmpty;
          final qty = isInCart ? (existing['quantity'] ?? 0) : 0;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
             // color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.black,
                            fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text('\$${price.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: Colors.grey.shade900, fontSize: 13)),
                    ],
                  ),
                ),
                isInCart
                    ? Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.redAccent,
                      onPressed: () {
                        sc.decreaseQuantity(p['id']);
                      },
                    ),
                    Text('$qty',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      onPressed: () {
                        sc.increaseQuantity(p['id']);
                      },
                    ),
                  ],
                )
                    : ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 10),
                  ),
                  onPressed: () {
                    sc.addProductToCart(p, quantity: 1);
                  },
                ),
              ],
            ),
          );
        },
      ),
    )

    else if (sc.cart.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: sc.cart.length,
                itemBuilder: (context, i) {
                  final item = sc.cart[i];
                  final name = item['name'];
                  final qty = item['quantity'];
                  final price = double.tryParse(item['price'].toString()) ?? 0;
                  return Card(
                    child: ListTile(
                      title: Text(name),
                      subtitle: Text('$qty × \$${price.toStringAsFixed(2)}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => sc.removeProductFromCart(item['id']),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text('Panier vide. Recherchez un produit.'),
              ),
            ),
        ],
      ),
    );
  }

// ÉTAPE 2 : PAIEMENT (MODERNE + MULTIDEVISE)
  Widget _buildStepPayment(SaleController sc, double totalWithDelivery, double change) {
    final totalUsd = sc.total;
    final totalCdf = totalUsd * _exchangeRate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
       // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Sous-total ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
             // color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sous-total",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("\$${totalUsd.toStringAsFixed(2)}"),
                    Text("≈ ${totalCdf.toStringAsFixed(0)} CDF",
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Livraison ---
          SwitchListTile(
            title: const Text("Frais de livraison"),
            subtitle: const Text("Saisissez le montant si livraison"),
            value: _hasDelivery,
            onChanged: (v) => setState(() {
              _hasDelivery = v;
              if (!_hasDelivery) _deliveryCtrl.clear();
            }),
          ),
          if (_hasDelivery)
            _modernTextField(
              controller: _deliveryCtrl,
              label: "Frais de livraison (CDF)",
              prefixIcon: Icons.local_shipping_outlined,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),

          const SizedBox(height: 20),

          // --- Devise du paiement ---
          DropdownButtonFormField<String>(
            decoration: _modernInputDecoration("Devise du paiement", Icons.currency_exchange),
            value: _selectedCurrency,
            onChanged: (v) => setState(() => _selectedCurrency = v ?? 'USD'),
            items: const [
              DropdownMenuItem(value: "USD", child: Text("Dollar américain (USD)")),
              DropdownMenuItem(value: "CDF", child: Text("Franc congolais (CDF)")),
            ],
          ),

          const SizedBox(height: 16),

          // --- Montant donné ---
          _modernTextField(
            controller: _amountGivenCtrl,
            label: "Montant donné ($_selectedCurrency)",
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 16),

          // --- Conversion automatique du montant donné ---
          if (_amountGiven > 0)
            Builder(builder: (context) {
              final amountGivenCdf = _selectedCurrency == "USD"
                  ? _amountGiven * _exchangeRate
                  : _amountGiven;
              final amountGivenUsd = _selectedCurrency == "CDF"
                  ? _amountGiven / _exchangeRate
                  : _amountGiven;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("≈ \$${amountGivenUsd.toStringAsFixed(2)}  |  ${amountGivenCdf.toStringAsFixed(0)} CDF",
                      style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 12),
                  _buildChangeCard(change),
                ],
              );
            }),
        ],
      ),
    );
  }

// Carte d'affichage du rendu/insuffisance
  Widget _buildChangeCard(double change) {
    // Conversion dans les deux devises
    double changeUsd, changeCdf;

    if (_selectedCurrency == "USD") {
      changeUsd = change;
      changeCdf = change * _exchangeRate;
    } else {
      changeCdf = change;
      changeUsd = change / _exchangeRate;
    }

    final isPositive = change >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Libellé
          Text(
            isPositive ? "Monnaie à rendre" : "Montant insuffisant",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),

          // Montants (alignés à droite)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${change.abs().toStringAsFixed(2)} $_selectedCurrency",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
              if (isPositive)
                Text(
                  _selectedCurrency == "USD"
                      ? "≈ ${changeCdf.toStringAsFixed(0)} CDF"
                      : "≈ \$${changeUsd.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ÉTAPE 3 : CLIENT
// ÉTAPE 3 : INFORMATIONS CLIENT (moderne)
  Widget _buildStepClient() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Informations client",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _modernTextField(
            controller: _clientCtrl,
            label: "Nom du client *",
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 16),

          _modernTextField(
            controller: _phoneCtrl,
            label: "Téléphone (optionnel)",
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  // ÉTAPE 4 : RÉSUMÉ (avec prix unitaire + sous-total)
  Widget _buildStepSummary(SaleController sc, double totalWithDelivery, double change) {
    // totalWithDelivery est TOUJOURS en USD (c'est votre référence)
    final totalUsd = totalWithDelivery;
    final totalCdf = totalWithDelivery * _exchangeRate;

    // Frais de livraison
    final deliveryUsd = _hasDelivery ? (_deliveryAmount / _exchangeRate) : 0.0;
    final deliveryCdf = _hasDelivery ? _deliveryAmount : 0.0;

    // Monnaie à rendre (change est déjà calculé dans la devise de paiement)
    double changeUsd, changeCdf;
    if (_selectedCurrency == "USD") {
      changeUsd = change;
      changeCdf = change * _exchangeRate;
    } else {
      changeCdf = change;
      changeUsd = change / _exchangeRate;
    }

    // Montant donné converti
    double amountGivenUsd, amountGivenCdf;
    if (_selectedCurrency == "USD") {
      amountGivenUsd = _amountGiven;
      amountGivenCdf = _amountGiven * _exchangeRate;
    } else {
      amountGivenCdf = _amountGiven;
      amountGivenUsd = _amountGiven / _exchangeRate;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            "Résumé de la vente",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(),

          // Liste des produits
          ...sc.cart.map((item) {
            final name = item['name'] ?? 'Produit';
            final qty = int.tryParse(item['quantity'].toString()) ?? 0;
            final price = double.tryParse(item['price'].toString()) ?? 0.0;
            final subtotal = qty * price;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "$name  × $qty",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    "\$${subtotal.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),

          const Divider(),

          // Détails financiers
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Sous-total", style: TextStyle(fontWeight: FontWeight.w600)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("\$${sc.total.toStringAsFixed(2)}"),
                  Text("≈ ${(sc.total * _exchangeRate).toStringAsFixed(0)} CDF",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),

          if (_hasDelivery) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Frais de livraison",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("\$${deliveryUsd.toStringAsFixed(2)}"),
                    Text("≈ ${deliveryCdf.toStringAsFixed(0)} CDF",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ],

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total à payer",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _selectedCurrency == "USD"
                        ? "\$${totalUsd.toStringAsFixed(2)}"
                        : "${totalCdf.toStringAsFixed(0)} CDF", // affiche correctement CDF
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _selectedCurrency == "CDF"
                        ? "≈ \$${totalUsd.toStringAsFixed(2)}" // version USD en "≈"
                        : "≈ ${totalCdf.toStringAsFixed(0)} CDF",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),

          const Divider(height: 24),

          // Montant donné
          if (_amountGiven > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Montant donné"),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${_amountGiven.toStringAsFixed(2)} $_selectedCurrency"),
                    Text(
                      _selectedCurrency == "USD"
                          ? "≈ ${( _amountGiven * _exchangeRate ).toStringAsFixed(0)} CDF"
                          : "≈ \$${( _amountGiven / _exchangeRate ).toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 6),

          // Monnaie à rendre
          if (_amountGiven > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Monnaie à rendre",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${change.abs().toStringAsFixed(2)} $_selectedCurrency",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      _selectedCurrency == "USD"
                          ? "≈ ${changeCdf.abs().toStringAsFixed(0)} CDF"
                          : "≈ \$${changeUsd.abs().toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 12),
          const Divider(),

          // Détails supplémentaires
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Devise du paiement"),
              Text(_selectedCurrency,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Taux d’échange"),
              Text("1 USD = ${_exchangeRate.toStringAsFixed(0)} CDF",
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitSale(SaleController sc, double totalWithDelivery, double change) async {
    final resp = await sc.submitSale(
      clientName: _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim(),
      deliveryFee: _hasDelivery ? _deliveryAmount : null,
      currency: _selectedCurrency,
      amountGiven: _amountGiven > 0 ? _amountGiven : null,
      exchangeRate: _exchangeRate,
      clientPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );

    if (resp['success'] == true) {
      // 🔍 Vérifions toutes les possibilités d'où peut se trouver l'ID
      final data = resp['data'];
      String? saleId;

      if (data is Map) {
        saleId = data['id']?.toString() ??
            data['sale']?['id']?.toString() ??
            data['data']?['id']?.toString();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vente enregistrée avec succès')),
      );

      setState(() {
        _currentStep = 0;
        _clientCtrl.clear();
        _phoneCtrl.clear();
        _deliveryCtrl.clear();
        _amountGivenCtrl.clear();
        _hasDelivery = false;
        // sc.clearCart();
      });
      if (context.mounted && saleId != null) {
        context.push('/sales/$saleId');
      } else {
        debugPrint('⚠️ Impossible de trouver saleId dans la réponse: $data');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp['message'] ?? 'Erreur lors de l’enregistrement'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }




  InputDecoration _modernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
      ),
    );
  }

  Widget _modernTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: _modernInputDecoration(label, prefixIcon),
    );
  }



}
