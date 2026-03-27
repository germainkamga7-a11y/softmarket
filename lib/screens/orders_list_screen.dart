import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/order_service.dart';
import '../theme/app_colors.dart';

class OrdersListScreen extends StatelessWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 80,
          floating: true,
          pinned: true,
          elevation: 0,
          scrolledUnderElevation: 2,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            title: Text(
              l.ordersListTitle,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                ),
              ),
            ),
          ),
        ),
        StreamBuilder<List<Order>>(
          stream: OrderService.streamUserOrders(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final orders = snap.data ?? [];
            if (orders.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 72,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(l.ordersEmpty, style: textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        l.ordersEmptySubtitle,
                        style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _OrderCard(order: orders[i]),
                  childCount: orders.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy', 'fr_FR');
    final (chipColor, chipBg) = _statusColors(order.statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: () => context.push(Routes.orderPath(order.id)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : numéro + statut
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${order.id.substring(0, 8).toUpperCase()}',
                      style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(order.statut.label,
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: chipColor)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Ligne 2 : date + article count
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(fmt.format(order.createdAt),
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 12),
                  Icon(Icons.inventory_2_outlined,
                      size: 13, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${order.itemCount} article${order.itemCount > 1 ? 's' : ''}',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              // Aperçu des noms de produits
              Text(
                order.items.map((i) => i.nom).join(', '),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Ligne 3 : total + flèche
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 16, color: AppColors.priceColor(context)),
                  const SizedBox(width: 6),
                  Text('${order.total.round()} FCFA',
                      style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: AppColors.priceColor(context))),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_outlined,
                      size: 14, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _statusColors(OrderStatus s) {
    switch (s) {
      case OrderStatus.enAttente:   return (Colors.orange.shade800, Colors.orange.shade50);
      case OrderStatus.confirmee:   return (Colors.blue.shade800,   Colors.blue.shade50);
      case OrderStatus.enLivraison: return (Colors.purple.shade800, Colors.purple.shade50);
      case OrderStatus.livree:      return (Colors.green.shade800,  Colors.green.shade50);
      case OrderStatus.annulee:     return (Colors.red.shade800,    Colors.red.shade50);
    }
  }
}
