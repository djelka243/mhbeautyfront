import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AProposView extends StatelessWidget {
	const AProposView({super.key});

	Future<void> _launchUrl(String url) async {
		final Uri uri = Uri.parse(url);
		if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
			throw Exception('Impossible d’ouvrir $url');
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('À propos'),
				centerTitle: true,
				elevation: 0,
				foregroundColor: Theme.of(context).brightness == Brightness.light
						? Colors.black
						: Colors.white,
			),
				body: SingleChildScrollView(
				padding: const EdgeInsets.all(20.0),
				child: Column(
					children: [
						// Logo ou icône principale
						/*CircleAvatar(
						//	backgroundImage: Image.asset("assets/images/1.png"),
							radius: 50,
							backgroundColor: Colors.pink.shade50,
							child: const Icon(Icons.spa_rounded, size: 60, color: Color(0xFF1B5E20)),
						),*/
						const SizedBox(height: 20),

						const Text(
							'MH Beauty & Création',
							style: TextStyle(
								fontSize: 24,
								fontWeight: FontWeight.bold,
								letterSpacing: 0.8,
							),
							textAlign: TextAlign.center,
						),
						const SizedBox(height: 6),
						const Text(
							'Version 1.0.1',
							style: TextStyle(fontSize: 14, color: Colors.grey),
						),
						const Divider(height: 30, thickness: 1.2),

						Container(
							padding: const EdgeInsets.all(16),
							child: const Text(
								'Est une pplication de gestion complète pour la boutique de beauté du même nom. '
										'Elle permet de gérer les ventes, les stocks, les catégories de produits, '
										'les factures et le suivi des clients, tout en offrant une interface simple et élégante.',
								style: TextStyle(fontSize: 16, height: 1.5),
								textAlign: TextAlign.justify,
							),
						),
					//	const SizedBox(height: 20),

						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Theme.of(context).colorScheme.onPrimary,
								borderRadius: BorderRadius.circular(16),
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: const [
									Text('Conception et développement',
											style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
									SizedBox(height: 8),
									Text(
										'Développé par Jessy Djonga, ingénieur informaticien',
										style: TextStyle(fontSize: 16, height: 1.5),
									),
								],
							),
						),
						const SizedBox(height: 25),

						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Theme.of(context).colorScheme.onPrimary,
								borderRadius: BorderRadius.circular(16),
							),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									const Text('Contacter le développeur',
											style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
									const SizedBox(height: 8),
									ListTile(
										leading: const Icon(Icons.email_outlined),
										title: const Text('Email'),
										subtitle: const Text('jessydjonga23@gmail.com'),
										onTap: () => _launchUrl('mailto:jessydjonga23@gmail.com'),
									),
									ListTile(
										leading: const Icon(Icons.language),
										title: const Text('Site Web'),
										subtitle: const Text('https://jessydjonga.site'),
										onTap: () => _launchUrl('https://jessydjonga.site'),
									),
									ListTile(
										leading: const Icon(Icons.phone_outlined),
										title: const Text('Téléphone'),
										subtitle: const Text('+243 977 196 639'),
										onTap: () => _launchUrl('tel:+243977196639'),
									),
								],
							),
						),
						const SizedBox(height: 30),

						const Text(
							'© 2025 MH Beauty & Création — Tous droits réservés.',
							style: TextStyle(color: Colors.grey, fontSize: 13),
							textAlign: TextAlign.center,
						),
					],
				),
			),
		);
	}
}
