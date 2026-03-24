import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cgu_screen.dart';
import 'forgot_password_screen.dart';
import 'privacy_policy_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  Future<void> _deleteAccount() async {
    // Étape 1 : confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: const Text(
          'Cette action est définitive et irréversible.\n\n'
          'Seront supprimés :\n'
          '• Votre profil\n'
          '• Vos boutiques et produits\n'
          '• Vos favoris\n\n'
          'Vos messages resteront dans les conversations existantes.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Étape 2 : ré-authentification si nécessaire
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Affichage du loader
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // Supprimer les boutiques et leurs produits
      final boutiquesSnap = await db
          .collection('commercants')
          .where('user_id', isEqualTo: uid)
          .get();
      for (final boutiqueDoc in boutiquesSnap.docs) {
        // Supprimer les produits de cette boutique
        final produitsSnap = await db
            .collection('produits')
            .where('commerce_id', isEqualTo: boutiqueDoc.id)
            .get();
        final batch = db.batch();
        for (final p in produitsSnap.docs) {
          batch.delete(p.reference);
        }
        batch.delete(boutiqueDoc.reference);
        await batch.commit();
      }

      // Supprimer les favoris
      await db.collection('favorites').doc(uid).delete();

      // Supprimer le profil utilisateur
      await db.collection('users').doc(uid).delete();

      // Supprimer le compte Firebase Auth
      await user.delete();

      // Fermer le loader — l'AuthGate redirige automatiquement vers WelcomeScreen
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context); // ferme loader
      if (e.code == 'requires-recent-login') {
        if (mounted) _showReauthDialog(user);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Erreur : ${e.message}'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // ferme loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Demande le mot de passe pour ré-authentifier avant suppression
  Future<void> _showReauthDialog(User user) async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer votre identité'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Pour supprimer votre compte, veuillez entrer votre mot de passe.'),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    pwCtrl.dispose();
    if (confirmed != true) return;

    try {
      final email = user.email;
      if (email == null) return;
      final cred = EmailAuthProvider.credential(
          email: email, password: pwCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await _deleteAccount(); // Relance après ré-auth
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Authentification échouée : $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sécurité'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          // ─── Mot de passe ────────────────────────────────────────────────
          const _SectionHeader('Mot de passe'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline, color: Color(0xFFCC0000), size: 20),
              ),
              title: const Text('Changer le mot de passe', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                'Modifiez votre mot de passe de connexion',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ─── Confidentialité ────────────────────────────────────────────
          const _SectionHeader('Confidentialité & Légal'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: Color(0xFFCC0000), size: 20),
                  ),
                  title: const Text('Politique de confidentialité',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.gavel_outlined,
                        color: Color(0xFFCC0000), size: 20),
                  ),
                  title: const Text("Conditions d'utilisation (CGU)",
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CguScreen()),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ─── Zone danger ────────────────────────────────────────────────
          const _SectionHeader('Zone dangereuse'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever,
                    color: Colors.red, size: 20),
              ),
              title: const Text('Supprimer mon compte',
                  style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w500)),
              subtitle: Text('Action irréversible',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right,
                  color: Colors.red),
              onTap: _deleteAccount,
            ),
          ),
          const SizedBox(height: 24),
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
