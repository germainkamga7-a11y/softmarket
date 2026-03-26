import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../router/app_router.dart';
import '../services/analytics_service.dart';
import '../services/cart_service.dart';
import '../theme/app_colors.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cart = context.watch<CartService>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.cartTitle),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child: Text(l.cartClearShort, style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 72,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(l.cartEmpty, style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    l.cartEmptySubtitle,
                    style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) =>
                        _CartItemTile(item: cart.items[i]),
                  ),
                ),
                _CartSummary(cart: cart),
              ],
            ),
    );
  }

  void _confirmClear(BuildContext context, CartService cart) {
    final l = AppLocalizations.of(context)!;
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cartClear),
        content: Text(l.cartClearConfirmMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              cart.clear();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.cartClearShort),
          ),
        ],
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(item.productId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cart.removeItem(item.productId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 64,
                        height: 64,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.inventory_2_outlined,
                            size: 28,
                            color: colorScheme.onSurfaceVariant),
                      ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(item.commerceNom,
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Text(
                      '${(item.prix * item.quantite).round()} FCFA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.priceColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Quantité
              _QuantityControl(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final CartItem item;
  const _QuantityControl({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CtrlBtn(
          icon: item.quantite == 1 ? Icons.delete_outline : Icons.remove,
          color: item.quantite == 1 ? Colors.red : colorScheme.primary,
          onTap: () {
            if (item.quantite == 1) {
              cart.removeItem(item.productId);
            } else {
              cart.updateQuantity(item.productId, -1);
            }
          },
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${item.quantite}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        _CtrlBtn(
          icon: Icons.add,
          color: colorScheme.primary,
          onTap: () => cart.updateQuantity(item.productId, 1),
        ),
      ],
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CtrlBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _CartSummary extends StatelessWidget {
  final CartService cart;
  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l.cartTotal} (${cart.itemCount} ${l.cartItemWord}${cart.itemCount > 1 ? 's' : ''})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${cart.totalAmount.round()} FCFA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.priceColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                AnalyticsService.logBeginCheckout(total: cart.totalAmount);
                context.push(
                  Routes.checkout,
                  extra: CheckoutArgs(
                    items: List.of(cart.items),
                    total: cart.totalAmount,
                  ),
                );
              },
              icon: const Icon(Icons.local_shipping_outlined, size: 18),
              label: Text(l.checkoutButtonCOD),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
