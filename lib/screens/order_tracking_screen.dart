import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  final bool isNewOrder;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    this.isNewOrder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNewOrder
            ? AppLocalizations.of(context)!.orderConfirmedTitle
            : AppLocalizations.of(context)!.orderTrackingTitle),
        leading: isNewOrder
            ? IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              )
            : null,
      ),
      body: StreamBuilder<Order?>(
        stream: OrderService.col.doc(orderId).snapshots().map(
          (doc) => doc.exists ? Order.fromDoc(doc) : null,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snap.data;
          if (order == null) {
            return Center(child: Text(AppLocalizations.of(context)!.orderNotFound));
          }
          return _OrderBody(order: order);
        },
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  final Order order;
  const _OrderBody({required this.order});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy à HH:mm', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Bannière statut ──────────────────────────────────────────────
        _StatusBanner(statut: order.statut),

        const SizedBox(height: 20),

        // ── Numéro de commande ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_outlined, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${l.orderTrackingTitle} #${order.id.substring(0, 8).toUpperCase()}',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                    Text(fmt.format(order.createdAt),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Timeline de suivi ────────────────────────────────────────────
        Text(l.orderTrackingSection, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _TrackingTimeline(statut: order.statut),

        const SizedBox(height: 28),

        // ── Articles commandés ───────────────────────────────────────────
        Text(l.itemsWithCount(order.itemCount),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56, height: 56,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.inventory_2_outlined,
                            size: 24, color: colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nom,
                        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
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
                          fontWeight: FontWeight.bold, color: AppColors.priceColor(context))),
                ],
              ),
            ],
          ),
        )),

        Divider(height: 28, color: colorScheme.outlineVariant),

        // ── Récap livraison + paiement ───────────────────────────────────
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: l.deliveryLabel,
          value: order.adresseLivraison,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.phone_outlined,
          label: l.contactLabel,
          value: order.telephone,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.payments_outlined,
          label: l.paymentLabel,
          value: order.modePaiement == 'livraison'
              ? l.paymentCODLabel
              : 'Mobile Money',
        ),

        Divider(height: 28, color: colorScheme.outlineVariant),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l.cartTotal, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            Text('${order.total.round()} FCFA',
                style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: AppColors.priceColor(context))),
          ],
        ),

        const SizedBox(height: 24),

        // ── Annulation (seulement si en attente) ─────────────────────────
        if (order.statut == OrderStatus.enAttente)
          OutlinedButton.icon(
            onPressed: () => _confirmCancel(context, order.id),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: Text(AppLocalizations.of(context)!.cancelOrder),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context, String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l.cancelOrderDialogTitle),
          content: Text(l.irreversibleAction),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.no)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l.yesCancelOrder),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      try {
        await OrderService.cancelOrder(orderId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.orderStatusAnnulee),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }
}

// ─── Bannière statut ───────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final OrderStatus statut;
  const _StatusBanner({required this.statut});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (color, icon, bg) = _theme();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statut.label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(_subtitle(l), style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, Color) _theme() {
    switch (statut) {
      case OrderStatus.enAttente:
        return (Colors.orange.shade700, Icons.hourglass_top_outlined, Colors.orange.shade50);
      case OrderStatus.confirmee:
        return (Colors.blue.shade700, Icons.check_circle_outlined, Colors.blue.shade50);
      case OrderStatus.enLivraison:
        return (Colors.purple.shade700, Icons.delivery_dining_outlined, Colors.purple.shade50);
      case OrderStatus.livree:
        return (Colors.green.shade700, Icons.done_all, Colors.green.shade50);
      case OrderStatus.annulee:
        return (Colors.red.shade700, Icons.cancel_outlined, Colors.red.shade50);
    }
  }

  String _subtitle(AppLocalizations l) {
    switch (statut) {
      case OrderStatus.enAttente:   return l.orderStatusSubtitleEnAttente;
      case OrderStatus.confirmee:   return l.orderStatusSubtitleConfirmee;
      case OrderStatus.enLivraison: return l.orderStatusSubtitleEnLivraison;
      case OrderStatus.livree:      return l.orderStatusSubtitleLivree;
      case OrderStatus.annulee:     return l.orderStatusAnnulee;
    }
  }
}

// ─── Timeline ─────────────────────────────────────────────────────────────────

class _TrackingTimeline extends StatelessWidget {
  final OrderStatus statut;
  const _TrackingTimeline({required this.statut});

  static const _steps = [
    OrderStatus.enAttente,
    OrderStatus.confirmee,
    OrderStatus.enLivraison,
    OrderStatus.livree,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (statut == OrderStatus.annulee) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Text(AppLocalizations.of(context)!.orderStatusAnnulee, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final currentIdx = _steps.indexOf(statut);

    return Column(
      children: List.generate(_steps.length, (i) {
        final step = _steps[i];
        final isDone = i <= currentIdx;
        final isCurrent = i == currentIdx;
        final isLast = i == _steps.length - 1;

        final color = isDone ? colorScheme.primary : colorScheme.outlineVariant;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne gauche : cercle + ligne
            Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isDone ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isCurrent ? 2.5 : 1.5),
                  ),
                  child: Center(
                    child: isDone && !isCurrent
                        ? Icon(Icons.check, size: 14, color: colorScheme.onPrimary)
                        : isCurrent
                            ? Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                    color: colorScheme.primary, shape: BoxShape.circle))
                            : null,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2, height: 36,
                    color: i < currentIdx ? colorScheme.primary : colorScheme.outlineVariant,
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                step.label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isDone ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─── Widget utilitaire ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
