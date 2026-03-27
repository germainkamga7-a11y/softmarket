import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _notifMessages = true;
  bool _notifProduits = true;
  bool _notifPromos = false;
  bool _notifAvis = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('notifications')
          .get();
      if (doc.exists && mounted) {
        final d = doc.data()!;
        setState(() {
          _notifMessages = d['messages'] as bool? ?? true;
          _notifProduits = d['nouveaux_produits'] as bool? ?? true;
          _notifPromos   = d['promotions'] as bool? ?? false;
          _notifAvis     = d['avis'] as bool? ?? true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('notifications')
        .set({
      'messages': _notifMessages,
      'nouveaux_produits': _notifProduits,
      'promotions': _notifPromos,
      'avis': _notifAvis,
      'updated_at': Timestamp.now(),
    });
  }

  void _toggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'messages': _notifMessages = value; break;
        case 'produits': _notifProduits = value; break;
        case 'promos':   _notifPromos = value; break;
        case 'avis':     _notifAvis = value; break;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                _SectionHeader(l.notifSectionActivity),
                _NotifTile(
                  icon: Icons.chat_outlined,
                  title: l.messages,
                  subtitle: l.notifMessagesSubtitle,
                  value: _notifMessages,
                  onChanged: (v) => _toggle('messages', v),
                  colorScheme: colorScheme,
                ),
                _NotifTile(
                  icon: Icons.shopping_bag_outlined,
                  title: l.notifNewProducts,
                  subtitle: l.notifNewProductsSubtitle,
                  value: _notifProduits,
                  onChanged: (v) => _toggle('produits', v),
                  colorScheme: colorScheme,
                ),
                _NotifTile(
                  icon: Icons.star_outline,
                  title: l.notifReviews,
                  subtitle: l.notifReviewsSubtitle,
                  value: _notifAvis,
                  onChanged: (v) => _toggle('avis', v),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 8),
                _SectionHeader(l.notifSectionMarketing),
                _NotifTile(
                  icon: Icons.local_offer_outlined,
                  title: l.notifPromos,
                  subtitle: l.notifPromosSubtitle,
                  value: _notifPromos,
                  onChanged: (v) => _toggle('promos', v),
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l.notifSystemNote,
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.5)),
      );
}

class _NotifTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ColorScheme colorScheme;

  const _NotifTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFCC0000).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFFCC0000), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      value: value,
      activeThumbColor: const Color(0xFFCC0000),
      onChanged: onChanged,
    );
  }
}
