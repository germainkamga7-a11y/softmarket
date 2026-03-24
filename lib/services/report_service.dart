import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum ReportTargetType { commerce, produit, utilisateur }

enum ReportReason {
  arnaqueEscroquerie,
  informationsFausses,
  produitIllegal,
  contenuInapproprie,
  autre,
}

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
        ReportReason.arnaqueEscroquerie => 'Arnaque / Escroquerie',
        ReportReason.informationsFausses => 'Informations fausses',
        ReportReason.produitIllegal => 'Produit ou service illégal',
        ReportReason.contenuInapproprie => 'Contenu inapproprié',
        ReportReason.autre => 'Autre',
      };

  IconData get icon => switch (this) {
        ReportReason.arnaqueEscroquerie => Icons.warning_amber_outlined,
        ReportReason.informationsFausses => Icons.info_outline,
        ReportReason.produitIllegal => Icons.block_outlined,
        ReportReason.contenuInapproprie => Icons.report_gmailerrorred_outlined,
        ReportReason.autre => Icons.more_horiz,
      };
}

class ReportService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> report({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String details = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Non connecté');

    await _db.collection('reports').add({
      'reporter_uid': user.uid,
      'target_type': targetType.name,
      'target_id': targetId,
      'reason': reason.label,
      'details': details,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    }).timeout(const Duration(seconds: 10));
  }
}

// ─── Dialog de signalement réutilisable ───────────────────────────────────────

Future<void> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  String targetName = '',
}) async {
  ReportReason? selectedReason;
  final detailsCtrl = TextEditingController();
  bool sending = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20, 16, 20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Titre
            Row(
              children: [
                const Icon(Icons.flag_outlined, color: Colors.red),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Signaler',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (targetName.isNotEmpty)
                      Text(
                        targetName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Raisons
            Text(
              'Motif du signalement',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ...ReportReason.values.map((reason) => InkWell(
                  onTap: () => setModalState(() => selectedReason = reason),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // ignore: deprecated_member_use
                        Radio<ReportReason>(
                          value: reason,
                          // ignore: deprecated_member_use
                          groupValue: selectedReason,
                          // ignore: deprecated_member_use
                          onChanged: (v) => setModalState(() => selectedReason = v),
                          activeColor: Colors.red,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        Icon(reason.icon, size: 18,
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(reason.label, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                )),

            // Détails (si "Autre")
            if (selectedReason == ReportReason.autre) ...[
              const SizedBox(height: 8),
              TextField(
                controller: detailsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Décrivez le problème...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selectedReason == null || sending
                    ? null
                    : () async {
                        setModalState(() => sending = true);
                        try {
                          await ReportService.report(
                            targetType: targetType,
                            targetId: targetId,
                            reason: selectedReason!,
                            details: detailsCtrl.text.trim(),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signalement envoyé. Merci pour votre vigilance.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setModalState(() => sending = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur : $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                icon: sending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_outlined, size: 18),
                label: const Text('Envoyer le signalement'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  detailsCtrl.dispose();
}
