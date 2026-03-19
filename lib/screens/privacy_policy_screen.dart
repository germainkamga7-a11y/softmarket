import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Politique de confidentialité'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('CamerMarket – Politique de confidentialité',
              style: textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Dernière mise à jour : mars 2025',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),

          const _Section(
            title: '1. Données collectées',
            body:
                'Nous collectons les informations suivantes :\n'
                '• Numéro de téléphone ou adresse e-mail (authentification)\n'
                '• Nom d\'utilisateur et ville (profil)\n'
                '• Localisation GPS (affichage de la carte, facultatif)\n'
                '• Photos de boutique et de produits (contenu publié)\n'
                '• Messages échangés entre utilisateurs (messagerie)',
          ),

          const _Section(
            title: '2. Utilisation des données',
            body:
                'Vos données sont utilisées pour :\n'
                '• Fournir les fonctionnalités de l\'application\n'
                '• Afficher les boutiques et produits sur la carte\n'
                '• Permettre la communication entre acheteurs et commerçants\n'
                '• Envoyer des notifications push (si activées)',
          ),

          const _Section(
            title: '3. Stockage et sécurité',
            body:
                'Vos données sont stockées sur les serveurs sécurisés de '
                'Google Firebase (Firestore, Storage, Authentication), '
                'conformément aux normes ISO 27001. Aucune donnée bancaire '
                'n\'est collectée ni stockée.',
          ),

          const _Section(
            title: '4. Partage des données',
            body:
                'Nous ne vendons ni ne louons vos données personnelles. '
                'Les données de profil public (nom de boutique, localisation, '
                'produits) sont visibles par tous les utilisateurs de l\'application. '
                'Les messages sont visibles uniquement par les participants à la conversation.',
          ),

          const _Section(
            title: '5. Localisation',
            body:
                'L\'accès à votre position GPS est demandé uniquement pour '
                'afficher les boutiques à proximité. Vous pouvez refuser cette '
                'permission sans perdre l\'accès aux autres fonctionnalités.',
          ),

          const _Section(
            title: '6. Vos droits',
            body:
                'Conformément à la loi camerounaise n°2010/012 sur la '
                'cybersécurité et à la réglementation en vigueur, vous disposez '
                'd\'un droit d\'accès, de rectification et de suppression de vos '
                'données. Pour exercer ces droits, contactez-nous à :\n'
                'support@camermarket.cm',
          ),

          const _Section(
            title: '7. Suppression du compte',
            body:
                'Vous pouvez supprimer votre compte et toutes vos données '
                'depuis l\'application via Profil → Sécurité → Supprimer mon compte. '
                'La suppression est définitive et irréversible.',
          ),

          const _Section(
            title: '8. Modifications',
            body:
                'Cette politique peut être mise à jour. Vous serez informé '
                'de tout changement significatif via une notification dans '
                'l\'application.',
          ),

          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Contact : support@camermarket.cm\nCamerMarket – Yaoundé, Cameroun',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onPrimaryContainer),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(body,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.6)),
        ],
      ),
    );
  }
}
