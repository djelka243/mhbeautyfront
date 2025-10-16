import 'package:flutter/material.dart';

class ConduseView extends StatelessWidget {
	const ConduseView({super.key});

	@override
	Widget build(BuildContext context) {
		final Color mainColor = const Color(0xFF1B5E20); // Vert foncé
		final Color accentColor = Colors.indigo.shade100; // Bleu clair

		return Scaffold(
			appBar: AppBar(
				title: const Text("Conditions d'utilisation"),
				centerTitle: true,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
				elevation: 0,
			),
			body: Container(

				child: ListView(
					padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
					children: [
						const SizedBox(height: 20),
						const Icon(Icons.rule, size: 60, color: Color(0xFF1B5E20)),
						const SizedBox(height: 10),
						const Text(
							'Conditions d’utilisation',
							textAlign: TextAlign.center,
							style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 16),
						Card(
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
							elevation: 2,
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: const [
										Text(
											'En utilisant cette application, vous acceptez les conditions générales suivantes :',
											style: TextStyle(fontSize: 16, height: 1.5),
										),
										SizedBox(height: 12),
										Text(
											'1. L’application est fournie "telle quelle" sans garantie de disponibilité.',
											style: TextStyle(fontSize: 16, height: 1.5),
										),
										SizedBox(height: 8),
										Text(
											'2. Vous êtes responsable de vos informations personnelles et de leur confidentialité.',
											style: TextStyle(fontSize: 16, height: 1.5),
										),
										SizedBox(height: 8),
										Text(
											'3. Toute utilisation abusive ou frauduleuse peut entraîner la suspension de votre compte.',
											style: TextStyle(fontSize: 16, height: 1.5),
										),
										SizedBox(height: 8),
										Text(
											'4. Pour toute question, contactez le support via l’application.',
											style: TextStyle(fontSize: 16, height: 1.5),
										),
									],
								),
							),
						),
						const SizedBox(height: 20),
					],
				),
			),
		);
	}
}
