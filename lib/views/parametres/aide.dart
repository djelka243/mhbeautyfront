import 'package:flutter/material.dart';

class AideView extends StatelessWidget {
	const AideView({super.key});

	final List<Map<String, String>> faqItems = const [
		{
			'question': 'Comment ajouter un produit ?',
			'answer': 'Allez dans le menu "Produits", puis appuyez sur le bouton "+ Ajouter".',
		},
		{
			'question': 'Comment créer une catégorie ?',
			'answer': 'Rendez-vous dans "Catégories" > cliquez sur "+" et remplissez le formulaire.',
		},
		{
			'question': 'Puis-je modifier une vente enregistrée ?',
			'answer': 'Oui, accédez à "Historique des ventes", puis sélectionnez la vente à modifier.',
		},
		{
			'question': 'Comment changer mon mot de passe ?',
			'answer': 'Allez dans "Profil" > "Changer le mot de passe" et suivez les instructions.',
		},
	];

	@override
	Widget build(BuildContext context) {
		final Color mainColor = const Color(0xFF1B5E20);
		final Color accentColor = Colors.indigo.shade100;

		return Scaffold(
			appBar: AppBar(
				title: const Text('Aide & Support'),
				centerTitle: true,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
				elevation: 0,
			),
			body: Container(
				decoration: BoxDecoration(

				),
				child: ListView(
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
					children: [
						const SizedBox(height: 10),
						const Icon(Icons.help_outline_rounded, size: 60, color: Color(0xFF1B5E20)),
						const SizedBox(height: 10),
						const Text(
							'Besoin d’aide ?',
							textAlign: TextAlign.center,
							style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 8),
						const Text(
							'Consultez la FAQ ou contactez notre équipe de support.',
							textAlign: TextAlign.center,
							style: TextStyle(color: Colors.black87, fontSize: 15),
						),
						const SizedBox(height: 25),

						// Liste des questions
						...faqItems.map((item) {
							return Card(
								margin: const EdgeInsets.symmetric(vertical: 8),
								shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
								elevation: 2,
								child: ExpansionTile(
									iconColor: mainColor,
									collapsedIconColor: mainColor,
									title: Text(
										item['question']!,
										style: TextStyle(fontWeight: FontWeight.bold, color: mainColor),
									),
									children: [
										Container(
											width: double.infinity,
											padding: const EdgeInsets.all(16),
											color: accentColor.withOpacity(0.2),
											child: Text(
												item['answer']!,
												style: const TextStyle(fontSize: 15, height: 1.5),
											),
										),
									],
								),
							);
						}).toList(),
					],
				),
			),
		);
	}
}
