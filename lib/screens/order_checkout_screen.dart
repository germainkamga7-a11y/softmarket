import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/analytics_service.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';

class OrderCheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
  final double total;

  const OrderCheckoutScreen({
    super.key,
    required this.items,
    required this.total,
  });

  @override
  State<OrderCheckoutScreen> createState() => _OrderCheckoutScreenState();
}

class _OrderCheckoutScreenState extends State<OrderCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adresseCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Pré-remplir le numéro depuis le profil Firebase si disponible
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    _telCtrl.text = phone;
  }

  @override
  void dispose() {
    _adresseCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final orderItems = widget.items
          .map((c) => OrderItem(
                productId:   c.productId,
                nom:         c.nom,
                prix:        c.prix,
                quantite:    c.quantite,
                imageUrl:    c.imageUrl,
                commerceId:  c.commerceId,
                commerceNom: c.commerceNom,
              ))
          .toList();

      final orderId = await OrderService.createOrder(
        items:            orderItems,
        total:            widget.total,
        adresseLivraison: _adresseCtrl.text.trim(),
        telephone:        _telCtrl.text.trim(),
        modePaiement:     'livraison',
      );

      if (!mounted) return;

      AnalyticsService.logPurchase(
        orderId: orderId,
        total: widget.total,
        modePaiement: 'livraison',
      );

      // Vider le panier
      context.read<CartService>().clear();

      // pushReplacement → context.go pour remplacer le stack
      context.go(Routes.orderPath(orderId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.checkoutFinalizeTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Récapitulatif commande ───────────────────────────────────
            Text(l.checkoutSummary,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...widget.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      image: item.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(item.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: item.imageUrl == null
                        ? Icon(Icons.inventory_2_outlined,
                            size: 22, color: colorScheme.onSurfaceVariant)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.nom,
                            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(item.commerceNom,
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('x${item.quantite}',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                      Text('${(item.prix * item.quantite).round()} FCFA',
                          style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.priceColor(context))),
                    ],
                  ),
                ],
              ),
            )),

            Divider(height: 28, color: colorScheme.outlineVariant),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('${widget.total.round()} FCFA',
                    style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.priceColor(context))),
              ],
            ),

            const SizedBox(height: 28),

            // ── Mode de paiement ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.payments_outlined, color: Colors.green.shade700, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.checkoutPayCash,
                            style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800)),
                        Text(l.checkoutPayCashSubtitle,
                            style: textTheme.bodySmall?.copyWith(color: Colors.green.shade700)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Informations de livraison ─────────────────────────────────
            Text(l.checkoutDeliveryInfo,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),

            TextFormField(
              controller: _adresseCtrl,
              decoration: InputDecoration(
                labelText: l.checkoutAddress,
                hintText: l.checkoutAddressHint,
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l.checkoutAddressRequired;
                if (v.trim().length < 10) return l.checkoutAddressTooShort;
                return null;
              },
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _telCtrl,
              decoration: InputDecoration(
                labelText: l.checkoutPhone,
                hintText: '6XXXXXXXX',
                prefixIcon: const Icon(Icons.phone_outlined),
                prefixText: '+237 ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return l.checkoutPhoneRequired;
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 8) return l.checkoutPhoneInvalid;
                return null;
              },
            ),

            const SizedBox(height: 32),

            // ── Bouton commander ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _confirmer,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 20),
                label: Text(_loading ? l.processing : l.checkoutConfirm),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              l.checkoutTermsNote,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
