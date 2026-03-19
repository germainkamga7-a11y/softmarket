import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/commerce_service.dart';
import 'boutique_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  List<Commerce> _allCommerces = [];
  List<Commerce> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadCommerces();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCommerces() async {
    final snap = await FirebaseFirestore.instance
        .collection('commercants')
        .orderBy('created_at', descending: true)
        .get();
    setState(() {
      _allCommerces = snap.docs.map(Commerce.fromDoc).toList();
      _loading = false;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _query = query.toLowerCase().trim();
      if (_query.isEmpty) {
        _results = [];
      } else {
        _results = _allCommerces
            .where((c) =>
                c.nomBoutique.toLowerCase().contains(_query) ||
                c.nomCommercant.toLowerCase().contains(_query) ||
                c.categorie.toLowerCase().contains(_query) ||
                c.description.toLowerCase().contains(_query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchCtrl,
          focusNode: _focusNode,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: 'Rechercher un commerçant, un produit...',
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _buildSuggestions(colorScheme, textTheme)
              : _results.isEmpty
                  ? _buildEmpty(colorScheme, textTheme)
                  : _buildResults(colorScheme, textTheme),
    );
  }

  // ─── Suggestions (avant recherche) ────────────────────────────────────────

  Widget _buildSuggestions(ColorScheme colorScheme, TextTheme textTheme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Commerçants récents',
            style: textTheme.titleSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        ..._allCommerces.take(5).map((c) => _CommerceListTile(
              commerce: c,
              query: '',
              onTap: () => _openBoutique(c),
            )),
        if (_allCommerces.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Aucun commerçant enregistré',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            ),
          ),
      ],
    );
  }

  // ─── Aucun résultat ────────────────────────────────────────────────────────

  Widget _buildEmpty(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Aucun résultat pour "$_query"',
              style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Essayez un autre nom, catégorie ou description',
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ─── Résultats ─────────────────────────────────────────────────────────────

  Widget _buildResults(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '${_results.length} résultat${_results.length > 1 ? 's' : ''}',
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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BoutiqueScreen(commerce: commerce)),
    );
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
