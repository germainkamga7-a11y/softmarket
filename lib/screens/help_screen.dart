import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  int? _openIndex;

  static const _faqs = [
    (
      q: 'Comment créer une boutique ?',
      a: 'Allez dans l\'onglet Carte, appuyez sur "Ajouter un commerce", remplissez le formulaire avec les infos de votre boutique et définissez votre position sur la carte.',
    ),
    (
      q: 'Comment ajouter des produits ?',
      a: 'Ouvrez votre boutique, puis appuyez sur le bouton "Ajouter un produit" en bas à droite. Ajoutez des photos, un nom, une description et un prix.',
    ),
    (
      q: 'Comment modifier ou supprimer un produit ?',
      a: 'Dans votre boutique, chaque carte produit dispose d\'un bouton crayon (modifier) et d\'un bouton corbeille (supprimer) visibles en haut de la carte.',
    ),
    (
      q: 'Comment contacter un commerçant ?',
      a: 'Ouvrez la fiche d\'un commerce ou d\'un produit et appuyez sur "Contacter". Vous pouvez envoyer un message directement via la messagerie intégrée.',
    ),
    (
      q: 'Comment activer les notifications ?',
      a: 'Allez dans Profil → Notifications et activez les types de notifications souhaités. Assurez-vous que les notifications sont autorisées dans les paramètres de votre téléphone.',
    ),
    (
      q: 'Comment configurer un PIN de connexion ?',
      a: 'Allez dans Profil → Sécurité & PIN → Configurer un PIN. Ce PIN à 4 chiffres vous permettra de vous connecter sans recevoir de SMS.',
    ),
    (
      q: 'Comment supprimer mon compte ?',
      a: 'Allez dans Profil → Sécurité & PIN → Zone dangereuse → Supprimer mon compte. Cette action est irréversible et supprime toutes vos données.',
    ),
    (
      q: 'L\'application ne trouve pas ma position, que faire ?',
      a: 'Vérifiez que la localisation est autorisée pour CamerMarket dans les paramètres de votre téléphone. Assurez-vous que le GPS est activé.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aide & Support'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // ─── Header ───────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFCC0000), Color(0xFF8B0000)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.support_agent, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                const Text(
                  'Comment pouvons-nous vous aider ?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Retrouvez les réponses aux questions fréquentes ci-dessous',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ─── FAQ ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Questions fréquentes',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colorScheme.onSurface)),
          ),

          ...List.generate(_faqs.length, (i) {
            final faq = _faqs[i];
            final isOpen = _openIndex == i;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(
                    () => _openIndex = isOpen ? null : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(faq.q,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isOpen
                                        ? const Color(0xFFCC0000)
                                        : colorScheme.onSurface)),
                          ),
                          Icon(
                            isOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: isOpen
                                ? const Color(0xFFCC0000)
                                : colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (isOpen) ...[
                        const SizedBox(height: 8),
                        Text(faq.a,
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5)),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ─── Contact ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Nous contacter',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colorScheme.onSurface)),
          ),

          _ContactTile(
            icon: Icons.chat,
            iconColor: const Color(0xFF25D366),
            title: 'WhatsApp',
            subtitle: 'Réponse en moins d\'1h',
            onTap: () => launchUrl(Uri.parse('https://wa.me/237000000000')),
          ),
          _ContactTile(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFCC0000),
            title: 'Email',
            subtitle: 'support@camermarket.cm',
            onTap: () => launchUrl(
                Uri.parse('mailto:support@camermarket.cm?subject=Support CamerMarket')),
          ),
          _ContactTile(
            icon: Icons.phone_outlined,
            iconColor: Colors.blue,
            title: 'Téléphone',
            subtitle: '+237 000 000 000',
            onTap: () => launchUrl(Uri.parse('tel:+237000000000')),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text('CamerMarket v1.0.0',
                style: TextStyle(
                    fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
