import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum MobileMoneyOperator { mtn, orange }

extension MobileMoneyOperatorLabel on MobileMoneyOperator {
  String get name => this == MobileMoneyOperator.mtn ? 'MTN MoMo' : 'Orange Money';
  Color get color => this == MobileMoneyOperator.mtn
      ? const Color(0xFFFFCC00)
      : const Color(0xFFFF6600);
  String get logo => this == MobileMoneyOperator.mtn ? '🟡' : '🟠';
}

class MobileMoneyService {
  /// Ouvre l'app ou le code USSD MTN Mobile Money
  static Future<void> launchMtn({
    required String recipientNumber,
    required double amount,
  }) async {
    final number = _normalize(recipientNumber);
    final amountInt = amount.round();
    // USSD MTN Cameroun : *126*1*NUMERO*MONTANT#
    final ussd = Uri.encodeFull('tel:*126*1*$number*$amountInt#');
    final uri = Uri.parse(ussd);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Ouvre l'app ou le code USSD Orange Money
  static Future<void> launchOrange({
    required String recipientNumber,
    required double amount,
  }) async {
    final number = _normalize(recipientNumber);
    final amountInt = amount.round();
    // USSD Orange Cameroun : #150*1*NUMERO*MONTANT#
    final ussd = Uri.encodeFull('tel:#150*1*$number*$amountInt#');
    final uri = Uri.parse(ussd);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static String _normalize(String phone) {
    var n = phone.replaceAll(' ', '').replaceAll('-', '');
    if (n.startsWith('+237')) n = n.substring(4);
    if (n.startsWith('237')) n = n.substring(3);
    return n;
  }
}

// ─── Bottom sheet Mobile Money ────────────────────────────────────────────────

Future<void> showMobileMoneySheet(
  BuildContext context, {
  required dynamic commerce, // Commerce
  double? amount,
  String? productName,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _MobileMoneySheet(
      commerce: commerce,
      amount: amount,
      productName: productName,
    ),
  );
}

class _MobileMoneySheet extends StatefulWidget {
  final dynamic commerce;
  final double? amount;
  final String? productName;

  const _MobileMoneySheet({
    required this.commerce,
    this.amount,
    this.productName,
  });

  @override
  State<_MobileMoneySheet> createState() => _MobileMoneySheetState();
}

class _MobileMoneySheetState extends State<_MobileMoneySheet> {
  final _amountCtrl = TextEditingController();
  MobileMoneyOperator _operator = MobileMoneyOperator.mtn;

  @override
  void initState() {
    super.initState();
    if (widget.amount != null) {
      _amountCtrl.text = widget.amount!.round().toString();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  String get _phone => widget.commerce.telephone as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amountVal = double.tryParse(_amountCtrl.text) ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Titre
          Row(
            children: [
              const Icon(Icons.mobile_friendly, color: Color(0xFFFFB300)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payer en Mobile Money',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (widget.productName != null)
                    Text(
                      widget.productName!,
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Numéro du vendeur
          if (_phone.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Envoyer à',
                      style: TextStyle(
                          fontSize: 11, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    widget.commerce.nomBoutique as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '+237 $_phone',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sélection opérateur
          Text('Opérateur',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: MobileMoneyOperator.values.map((op) {
              final selected = _operator == op;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _operator = op),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: EdgeInsets.only(
                        right: op == MobileMoneyOperator.mtn ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? op.color.withValues(alpha: 0.15)
                          : colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color: selected ? op.color : Colors.transparent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(op.logo, style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          op.name,
                          style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                            color: selected ? op.color : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Montant
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Montant (FCFA)',
              suffixText: 'FCFA',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Bouton payer
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: amountVal <= 0 || _phone.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      if (_operator == MobileMoneyOperator.mtn) {
                        await MobileMoneyService.launchMtn(
                          recipientNumber: _phone,
                          amount: amountVal,
                        );
                      } else {
                        await MobileMoneyService.launchOrange(
                          recipientNumber: _phone,
                          amount: amountVal,
                        );
                      }
                    },
              icon: const Icon(Icons.send_to_mobile_outlined, size: 18),
              label: Text(
                amountVal > 0
                    ? 'Payer ${amountVal.round()} FCFA via ${_operator.name}'
                    : 'Entrez un montant',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _operator.color,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Aide
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Votre application Mobile Money ou un code USSD\ns\'ouvrira pour confirmer le paiement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
