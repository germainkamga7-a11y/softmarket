import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _cniCtrl = TextEditingController();

  XFile? _cniFront;
  XFile? _selfie;

  bool _loading = false;
  bool _submitting = false;

  // Statut actuel depuis Firestore
  String? _status;       // 'pending' | 'verified' | 'rejected' | null
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cniCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentStatus() async {
    setState(() => _loading = true);
    try {
      // Charger les données du profil pour pré-remplir le nom
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      if (userDoc.exists) {
        final name = userDoc.data()?['username'] as String? ?? '';
        _nameCtrl.text = name;
      }

      // Charger la demande de vérification existante
      final reqDoc = await FirebaseFirestore.instance
          .collection('verification_requests')
          .doc(_uid)
          .get();
      if (reqDoc.exists) {
        final d = reqDoc.data()!;
        _status = d['status'] as String?;
        _rejectionReason = d['rejection_reason'] as String?;
      }
    } catch (e) {
      debugPrint('[VerificationScreen] Erreur chargement statut : $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickImage(bool isSelfie) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: isSelfie ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() {
      if (isSelfie) {
        _selfie = file;
      } else {
        _cniFront = file;
      }
    });
  }

  Future<String> _uploadFile(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    } else {
      await ref.putFile(File(file.path));
    }
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cniFront == null) {
      _showSnack('Veuillez ajouter la photo de votre CNI recto.', isError: true);
      return;
    }
    if (_selfie == null) {
      _showSnack('Veuillez prendre un selfie.', isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final cniFrontUrl = await _uploadFile(
        _cniFront!,
        'verifications/$_uid/cni_front.jpg',
      );
      final selfieUrl = await _uploadFile(
        _selfie!,
        'verifications/$_uid/selfie.jpg',
      );

      final batch = FirebaseFirestore.instance.batch();

      // Créer/remplacer la demande de vérification
      batch.set(
        FirebaseFirestore.instance
            .collection('verification_requests')
            .doc(_uid),
        {
          'uid': _uid,
          'full_name': _nameCtrl.text.trim(),
          'cni_number': _cniCtrl.text.trim().toUpperCase(),
          'cni_front_url': cniFrontUrl,
          'selfie_url': selfieUrl,
          'status': 'pending',
          'submitted_at': Timestamp.now(),
          'reviewed_at': null,
          'rejection_reason': null,
        },
      );

      // Mettre à jour le statut dans le profil utilisateur
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(_uid),
        {'verification_status': 'pending'},
      );

      await batch.commit();
      if (mounted) setState(() => _status = 'pending');
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Vérification d\'identité')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _status == 'verified'
              ? _buildVerifiedState(colorScheme, textTheme)
              : _status == 'pending'
                  ? _buildPendingState(colorScheme, textTheme)
                  : _buildForm(colorScheme, textTheme),
    );
  }

  // ─── État : vérifié ──────────────────────────────────────────────────────

  Widget _buildVerifiedState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user,
                  color: Colors.green, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Identité vérifiée',
                style: tt.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Votre identité a été confirmée par notre équipe. '
              'Votre profil affiche maintenant le badge vérifié.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ─── État : en attente ───────────────────────────────────────────────────

  Widget _buildPendingState(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top,
                  color: Colors.orange.shade700, size: 44),
            ),
            const SizedBox(height: 20),
            Text('Vérification en cours',
                style: tt.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Votre demande a bien été reçue. '
              'Notre équipe l\'examine et vous notifiera sous 24–48h.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vous recevrez une notification dès que la revue sera terminée.',
                      style: TextStyle(
                          color: Colors.orange.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Formulaire ──────────────────────────────────────────────────────────

  Widget _buildForm(ColorScheme cs, TextTheme tt) {
    final isRejected = _status == 'rejected';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: cs.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Votre CNI ne sera utilisée que pour confirmer votre identité '
                      'et ne sera jamais partagée publiquement.',
                      style: TextStyle(
                          color: cs.onPrimaryContainer, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Motif de refus (si applicable)
            if (isRejected && _rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cancel_outlined,
                        color: cs.onErrorContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vérification refusée',
                              style: TextStyle(
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(_rejectionReason!,
                              style: TextStyle(
                                  color: cs.onErrorContainer, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Nom complet ──
            Text('Nom complet (comme sur la CNI)',
                style: tt.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Prénom NOM',
                prefixIcon: const Icon(Icons.person_outline),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              validator: (v) => v == null || v.trim().length < 3
                  ? 'Nom trop court (min 3 caractères)'
                  : null,
            ),

            const SizedBox(height: 16),

            // ── Numéro CNI ──
            Text('Numéro CNI camerounaise',
                style: tt.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _cniCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: InputDecoration(
                hintText: 'Ex : 12345678AB',
                prefixIcon: const Icon(Icons.badge_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
              validator: (v) => v == null || v.trim().length < 5
                  ? 'Numéro CNI invalide'
                  : null,
            ),

            const SizedBox(height: 24),

            // ── Photo CNI recto ──
            Text('Photo CNI recto',
                style: tt.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Prenez une photo claire de votre CNI en couleur, en entier.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _PhotoPicker(
              file: _cniFront,
              label: 'Ajouter CNI recto',
              icon: Icons.credit_card,
              onPick: () => _pickImage(false),
            ),

            const SizedBox(height: 20),

            // ── Selfie ──
            Text('Selfie (photo de vous)',
                style: tt.labelMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'Tenez votre CNI à côté de votre visage et prenez une photo.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            _PhotoPicker(
              file: _selfie,
              label: 'Prendre un selfie',
              icon: Icons.face_outlined,
              onPick: () => _pickImage(true),
              preferCamera: true,
            ),

            const SizedBox(height: 32),

            // ── Bouton soumettre ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _submitting
                      ? 'Envoi en cours…'
                      : isRejected
                          ? 'Resoumettre ma demande'
                          : 'Envoyer ma demande',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Traitement sous 24–48h • Données sécurisées',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Widget sélecteur photo ───────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final XFile? file;
  final String label;
  final IconData icon;
  final VoidCallback onPick;
  final bool preferCamera;

  const _PhotoPicker({
    required this.file,
    required this.label,
    required this.icon,
    required this.onPick,
    this.preferCamera = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: file != null ? 160 : 100,
        decoration: BoxDecoration(
          color: file != null
              ? Colors.transparent
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? cs.primary : cs.outline.withValues(alpha: 0.5),
            width: file != null ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: file != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    kIsWeb
                        ? Image.network(file!.path, fit: BoxFit.cover)
                        : Image.file(File(file!.path), fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text('Modifier',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 32, color: cs.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                    if (preferCamera) ...[
                      const SizedBox(height: 2),
                      Text('Caméra recommandée',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
