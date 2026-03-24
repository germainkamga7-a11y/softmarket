import 'package:flutter/material.dart';

class CguScreen extends StatelessWidget {
  const CguScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Conditions Générales d'Utilisation"),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "CamerMarket – CGU",
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Dernière mise à jour : mars 2025',
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          const _Section(
            title: '1. Objet',
            body: 'CamerMarket est une marketplace en ligne permettant aux '
                'commerçants et entrepreneurs camerounais de présenter leurs '
                'boutiques, produits et services, et aux acheteurs de les '
                'découvrir et de les contacter directement.',
          ),

          const _Section(
            title: '2. Accès au service',
            body: 'L\'accès à CamerMarket est gratuit. Toute personne physique '
                'âgée d\'au moins 16 ans peut créer un compte. '
                'En créant un compte, vous déclarez accepter les présentes CGU '
                'et notre Politique de confidentialité.',
          ),

          const _Section(
            title: '3. Inscription et compte',
            body: 'Vous êtes responsable de la confidentialité de vos '
                'identifiants. Toute activité effectuée depuis votre compte '
                'vous est attribuée. En cas de compromission, informez-nous '
                'immédiatement à support@camermarket.cm.',
          ),

          const _Section(
            title: '4. Règles de publication',
            body: 'Les contenus publiés (boutiques, produits, messages) doivent '
                'être :\n'
                '• Véridiques et conformes à la réalité\n'
                '• Légaux (pas de produits ou services interdits au Cameroun)\n'
                '• Respectueux (pas de contenu offensant, trompeur ou frauduleux)\n\n'
                'CamerMarket se réserve le droit de supprimer tout contenu '
                'ne respectant pas ces règles et de suspendre les comptes contrevenants.',
          ),

          const _Section(
            title: '5. Transactions',
            body: 'CamerMarket est une plateforme de mise en relation. Les '
                'transactions financières (Mobile Money, espèces, etc.) se '
                'font directement entre acheteurs et vendeurs. '
                'CamerMarket n\'est pas partie aux transactions et décline '
                'toute responsabilité en cas de litige commercial.',
          ),

          const _Section(
            title: '6. Signalements',
            body: 'Tout utilisateur peut signaler un contenu inapproprié via '
                'le bouton de signalement. Nous traitons chaque signalement '
                'dans les meilleurs délais et nous réservons le droit de '
                'suspendre ou supprimer les comptes signalés de manière répétée.',
          ),

          const _Section(
            title: '7. Propriété intellectuelle',
            body: 'L\'application CamerMarket et son code source sont protégés '
                'par le droit camerounais de la propriété intellectuelle. '
                'Les contenus publiés par les utilisateurs (photos, textes) '
                'restent leur propriété, mais ils accordent à CamerMarket une '
                'licence non exclusive d\'affichage dans l\'application.',
          ),

          const _Section(
            title: '8. Responsabilité',
            body: 'CamerMarket s\'efforce d\'assurer la disponibilité du service '
                'mais ne peut garantir une disponibilité sans interruption. '
                'Nous déclinons toute responsabilité pour les dommages résultant '
                'd\'une interruption de service, d\'une perte de données ou '
                'd\'une transaction frauduleuse entre utilisateurs.',
          ),

          const _Section(
            title: '9. Résiliation',
            body: 'Vous pouvez supprimer votre compte à tout moment depuis '
                'Profil → Sécurité → Supprimer mon compte. '
                'CamerMarket peut suspendre ou résilier un compte en cas de '
                'violation des présentes CGU.',
          ),

          const _Section(
            title: '10. Droit applicable',
            body: 'Les présentes CGU sont régies par le droit camerounais. '
                'En cas de litige, les parties s\'engagent à rechercher '
                'une solution amiable avant tout recours judiciaire. '
                'À défaut, les tribunaux de Yaoundé seront seuls compétents.',
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
              style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant, height: 1.6)),
        ],
      ),
    );
  }
}
