import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/commerce_provider.dart';
import '../router/app_router.dart';
import '../services/analytics_service.dart';
import '../services/commerce_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Commerce> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final allCommerces = context.read<CommerceProvider>().commerces;
    setState(() {
      _query = query.toLowerCase().trim();
      if (_query.isEmpty) {
        _results = [];
      } else {
        _results = allCommerces
            .where((c) =>
                c.nomBoutique.toLowerCase().contains(_query) ||
                c.nomCommercant.toLowerCase().contains(_query) ||
                c.categorie.toLowerCase().contains(_query) ||
                c.description.toLowerCase().contains(_query))
            .toList();
      }
    });
    // Log uniquement à partir de 3 caractères pour éviter de tracker chaque touche
    if (_query.length >= 3) {
      AnalyticsService.logSearch(_query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final commerceProvider = context.watch<CommerceProvider>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: l.searchBarHint,
            border: InputBorder.none,
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchCtrl.clear();
                      _onSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: commerceProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _buildSuggestions(l, colorScheme, textTheme, commerceProvider.commerces)
              : _results.isEmpty
                  ? _buildEmpty(l, colorScheme, textTheme)
                  : _buildResults(l, colorScheme, textTheme),
    );
  }

  // ─── Suggestions (avant recherche) ────────────────────────────────────────

  Widget _buildSuggestions(AppLocalizations l,
      ColorScheme colorScheme, TextTheme textTheme, List<Commerce> all) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.searchRecentMerchants,
            style: textTheme.titleSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ...all.take(5).map((c) => _CommerceListTile(
              commerce: c,
              query: '',
              onTap: () => _openBoutique(c),
            )),
        if (all.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.searchNoMerchant,
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  // ─── Aucun résultat ────────────────────────────────────────────────────────

  Widget _buildEmpty(AppLocalizations l, ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(l.searchNoResultFor(_query), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(l.searchNoResultHint,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ─── Résultats ─────────────────────────────────────────────────────────────

  Widget _buildResults(AppLocalizations l, ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            l.searchResultCount(_results.length, _results.length > 1 ? 's' : ''),
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            itemBuilder: (_, i) => _CommerceListTile(
              commerce: _results[i],
              query: _query,
              onTap: () => _openBoutique(_results[i]),
            ),
          ),
        ),
      ],
    );
  }

  void _openBoutique(Commerce commerce) {
    context.push(Routes.boutique, extra: commerce);
  }
}

// ─── Tuile commerçant ─────────────────────────────────────────────────────────

class _CommerceListTile extends StatelessWidget {
  final Commerce commerce;
  final String query;
  final VoidCallback onTap;

  const _CommerceListTile({
    required this.commerce,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(Icons.store, color: colorScheme.primary),
        ),
        title: _HighlightText(
          text: commerce.nomBoutique,
          query: query,
          style: textTheme.titleSmall!
              .copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          commerce.categorie,
          style: textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 12, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('Vérifié',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Surbrillance du texte recherché ─────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _HighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lower = text.toLowerCase();
    final idx = lower.indexOf(query);
    if (idx == -1) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(
              backgroundColor: Colors.yellow.shade200,
              color: Colors.black,
            ),
          ),
          TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
