import 'package:flutter/material.dart';

// ─── Indicateurs de saisie (dots) ────────────────────────────────────────────

class PinDots extends StatelessWidget {
  final String pin;
  final bool hasError;
  const PinDots({super.key, required this.pin, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: filled ? 18 : 16,
          height: filled ? 18 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? colorScheme.error
                : filled
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
            boxShadow: filled && !hasError
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// ─── Pavé numérique ───────────────────────────────────────────────────────────

class PinPad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(context, ['1', '2', '3']),
        const SizedBox(height: 12),
        _buildRow(context, ['4', '5', '6']),
        const SizedBox(height: 12),
        _buildRow(context, ['7', '8', '9']),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72), // espace vide à gauche
            _DigitKey(digit: '0', onTap: () => onDigit('0')),
            _BackspaceKey(onTap: onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map((d) => _DigitKey(digit: d, onTap: () => onDigit(d)))
          .toList(),
    );
  }
}

class _DigitKey extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  const _DigitKey({required this.digit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              digit,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  final VoidCallback onTap;
  const _BackspaceKey({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      child: InkWell(
        borderRadius: BorderRadius.circular(40),
        onTap: onTap,
        onLongPress: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Icon(Icons.backspace_outlined,
                size: 24, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
