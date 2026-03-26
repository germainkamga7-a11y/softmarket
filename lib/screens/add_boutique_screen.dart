import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../services/commerce_service.dart';
import '../services/map_service.dart';

// ─── Point d'entrée ────────────────────────────────────────────────────────────
// Si boutique != null → édition directe sur le formulaire
// Sinon → écran de sélection du type, puis formulaire dans une route séparée

class AddBoutiqueScreen extends StatelessWidget {
  final Commerce? boutique;
  const AddBoutiqueScreen({super.key, this.boutique});

  @override
  Widget build(BuildContext context) {
    if (boutique != null) {
      return _BoutiqueFormScreen(type: boutique!.type, boutique: boutique);
    }
    return const _TypeSelectionScreen();
  }
}

// ─── Écran 1 : choix du type ───────────────────────────────────────────────────

class _TypeSelectionScreen extends StatelessWidget {
  const _TypeSelectionScreen();

  void _goToForm(BuildContext context, CommerceType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _BoutiqueFormScreen(type: type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon espace'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Quel type d\'espace\nvoulez-vous créer ?',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Choisissez selon votre activité',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 48),

              _TypeCard(
                icon: Icons.storefront,
                title: 'Boutique',
                subtitle: 'Pour vendre des produits physiques',
                features: const [
                  'Catalogue de produits',
                  'Gestion des stocks',
                  'Alimentation, Mode, Électronique...',
                ],
                color: colorScheme.primary,
                onTap: () => _goToForm(context, CommerceType.boutique),
              ),
              const SizedBox(height: 20),

              _TypeCard(
                icon: Icons.business_center,
                title: 'Établissement',
                subtitle: 'Pour proposer des services',
                features: const [
                  'Liste de services',
                  'Santé, Restauration, Formation...',
                  'Réservations & contacts',
                ],
                color: colorScheme.secondary,
                onTap: () => _goToForm(context, CommerceType.etablissement),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Écran 2 : formulaire (route séparée) ─────────────────────────────────────
// GoogleMap vit ici, géré par le lifecycle de la route Flutter → pas de crash

class _BoutiqueFormScreen extends StatefulWidget {
  final CommerceType type;
  final Commerce? boutique;

  const _BoutiqueFormScreen({required this.type, this.boutique});

  @override
  State<_BoutiqueFormScreen> createState() => _BoutiqueFormScreenState();
}

class _BoutiqueFormScreenState extends State<_BoutiqueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _momoCtrl = TextEditingController();
  final _autreCtrl = TextEditingController();
  late String _categorie;
  String _operateurMomo = ''; // '' | 'MTN' | 'Orange'
  bool _loading = false;
  bool _is3D = false;
  bool _locating = false;
  LatLng? _position;
  LatLng? _gpsPosition;
  GoogleMapController? _mapController;
  final _mapService = MapService();

  // Logo
  XFile? _logoFile;
  Uint8List? _logoBytes;
  String? _logoUrl;

  bool get _isEditing => widget.boutique != null;
  bool get _isBoutique => widget.type == CommerceType.boutique;

  List<String> get _categories =>
      _isBoutique ? Commerce.categoriesBoutique : Commerce.categoriesEtablissement;

  bool get _isAutreSelected =>
      _categorie == 'Autre' || _categorie == 'Autres services';

  String get _categorieFinale =>
      _isAutreSelected && _autreCtrl.text.trim().isNotEmpty
          ? _autreCtrl.text.trim()
          : _categorie;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nomCtrl.text = widget.boutique!.nomBoutique;
      _descCtrl.text = widget.boutique!.description;
      _telCtrl.text = widget.boutique!.telephone;
      _momoCtrl.text = widget.boutique!.numeroMobileMoney;
      _operateurMomo = widget.boutique!.operateurMobileMoney;
      _categorie = _categories.contains(widget.boutique!.categorie)
          ? widget.boutique!.categorie
          : _categories.first;
      _position = widget.boutique!.position;
      _logoUrl = widget.boutique!.logoUrl;
    } else {
      _categorie = _categories.first;
      _detectLocation();
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoFile = file;
      _logoBytes = bytes;
    });
  }

  Future<String?> _uploadLogo(String commerceId) async {
    if (_logoFile == null) return _logoUrl;
    try {
      final ref = FirebaseStorage.instance
          .ref('commerces/$commerceId/logo.jpg');
      if (kIsWeb) {
        await ref.putData(_logoBytes!,
            SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(
          // ignore: avoid_slow_async_io
          File(_logoFile!.path),
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('[AddBoutique] Erreur upload logo : $e');
      return _logoUrl;
    }
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _telCtrl.dispose();
    _momoCtrl.dispose();
    _autreCtrl.dispose();
    // Ne pas appeler _mapController?.dispose() — géré en interne par GoogleMap
    super.dispose();
  }

  Future<void> _detectLocation() async {
    setState(() => _locating = true);
    try {
      final pos = await _mapService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _position = pos;
        _gpsPosition = pos;
        _locating = false;
      });
      _animateTo(pos);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'obtenir la position : $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _goToGpsPosition() {
    if (_gpsPosition == null) {
      _detectLocation();
      return;
    }
    setState(() => _position = _gpsPosition);
    _animateTo(_gpsPosition!);
  }

  void _animateTo(LatLng pos) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pos,
            zoom: _is3D ? 19 : 17,
            tilt: _is3D ? 60 : 0,
            bearing: _is3D ? 30 : 0,
          ),
        ),
      );
    });
  }

  void _toggle3D() {
    setState(() => _is3D = !_is3D);
    if (_position != null) _animateTo(_position!);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Localisation en cours, veuillez patienter...')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final service = CommerceService();
      final user = FirebaseAuth.instance.currentUser!;

      if (_isEditing) {
        final logoUrl = await _uploadLogo(widget.boutique!.id!);
        await service.updateBoutique(
          widget.boutique!.id!,
          nomBoutique: _nomCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          categorie: _categorieFinale,
          telephone: _telCtrl.text.trim(),
          logoUrl: logoUrl,
          numeroMobileMoney: _momoCtrl.text.trim(),
          operateurMobileMoney: _operateurMomo,
        );
      } else {
        final id = await service.saveBoutique(
          nomBoutique: _nomCtrl.text.trim(),
          nomCommercant: user.displayName ?? user.phoneNumber ?? '',
          description: _descCtrl.text.trim(),
          categorie: _categorieFinale,
          telephone: _telCtrl.text.trim(),
          userId: user.uid,
          type: widget.type,
          position: _position!,
        );
        // Upload logo + mobile money après création (on a besoin de l'ID)
        if (_logoFile != null || _momoCtrl.text.trim().isNotEmpty) {
          final logoUrl = _logoFile != null ? await _uploadLogo(id) : null;
          await service.updateBoutique(id,
            nomBoutique: _nomCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            categorie: _categorieFinale,
            telephone: _telCtrl.text.trim(),
            logoUrl: logoUrl,
            numeroMobileMoney: _momoCtrl.text.trim(),
            operateurMobileMoney: _operateurMomo,
          );
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        final msg = e.toString().contains('TimeoutException')
            ? 'Connexion trop lente. Vérifiez votre réseau et réessayez.'
            : e.toString().contains('permission-denied')
                ? 'Accès refusé. Publiez vos règles Firestore.'
                : 'Erreur : $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = _isBoutique ? colorScheme.primary : colorScheme.secondary;
    final typeLabel = _isBoutique ? 'Boutique' : 'Établissement';
    final typeIcon = _isBoutique ? Icons.storefront : Icons.business_center;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier · $typeLabel' : 'Nouvelle $typeLabel'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Badge type
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 18, color: typeColor),
                    const SizedBox(width: 8),
                    Text(
                      typeLabel,
                      style: TextStyle(
                          color: typeColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Logo de la boutique ──────────────────────────────────────
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: typeColor.withValues(alpha: 0.12),
                          backgroundImage: _logoBytes != null
                              ? MemoryImage(_logoBytes!)
                              : (_logoUrl != null
                                  ? NetworkImage(_logoUrl!) as ImageProvider
                                  : null),
                          child: (_logoBytes == null && _logoUrl == null)
                              ? Icon(typeIcon, size: 40, color: typeColor)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _logoBytes != null || _logoUrl != null
                        ? 'Appuyez pour changer le logo'
                        : 'Ajouter un logo (optionnel)',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Nom
            TextFormField(
              controller: _nomCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText:
                    'Nom ${_isBoutique ? 'de la boutique' : 'de l\'établissement'} *',
                hintText: _isBoutique
                    ? 'Ex: Boutique Kamga'
                    : 'Ex: Salon Excellence',
                prefixIcon: Icon(typeIcon),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ce champ est obligatoire' : null,
            ),
            const SizedBox(height: 16),

            // Catégorie
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_categorie) ? _categorie : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Catégorie *',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _categorie = v!;
                  if (!_isAutreSelected) _autreCtrl.clear();
                });
              },
              validator: (v) =>
                  v == null ? 'Veuillez choisir une catégorie' : null,
            ),

            // Champ custom si "Autre"
            if (_isAutreSelected) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _autreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Précisez votre catégorie *',
                  hintText: _isBoutique
                      ? 'Ex: Vente de pagnes, Artisanat...'
                      : 'Ex: Soudure, Décoration intérieure...',
                  prefixIcon: const Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor:
                      colorScheme.primaryContainer.withValues(alpha: 0.15),
                ),
                validator: (v) => _isAutreSelected &&
                        (v == null || v.trim().isEmpty)
                    ? 'Veuillez préciser votre catégorie'
                    : null,
              ),
            ],
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: _isBoutique
                    ? 'Description des produits'
                    : 'Description des services',
                hintText: _isBoutique
                    ? 'Décrivez vos produits, vos spécialités...'
                    : 'Décrivez vos services, vos tarifs...',
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Téléphone
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Téléphone',
                hintText: '+237 6XX XXX XXX',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Mobile Money ──────────────────────────────────────────────
            Text('Mobile Money (optionnel)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
            const SizedBox(height: 8),
            Row(
              children: [
                // Sélecteur opérateur
                for (final op in ['MTN', 'Orange'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(op),
                      selected: _operateurMomo == op,
                      selectedColor: op == 'MTN'
                          ? const Color(0xFFFFB300)
                          : Colors.orange,
                      onSelected: (sel) => setState(() =>
                          _operateurMomo = sel ? op : ''),
                    ),
                  ),
              ],
            ),
            if (_operateurMomo.isNotEmpty) ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _momoCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro $_operateurMomo MoMo',
                  hintText: '6XX XXX XXX',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ─── Localisation ──────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: typeColor),
                const SizedBox(width: 8),
                Text(
                  'Localisation',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface),
                ),
                const Spacer(),
                if (_position != null) ...[
                  // Bouton 3D
                  GestureDetector(
                    onTap: _toggle3D,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _is3D
                            ? typeColor
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _is3D
                              ? typeColor
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.view_in_ar,
                            size: 14,
                            color: _is3D
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '3D',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _is3D
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton ma position
                  IconButton(
                    onPressed: _locating ? null : _goToGpsPosition,
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    tooltip: 'Ma position GPS',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(32, 32),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Carte
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _position == null
                    ? Container(
                        color: colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Détection de la position...',
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _locating ? null : _detectLocation,
                                child: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _position!,
                              zoom: 17,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('boutique'),
                                position: _position!,
                                infoWindow: InfoWindow(
                                  title: _nomCtrl.text.trim().isEmpty
                                      ? typeLabel
                                      : _nomCtrl.text.trim(),
                                  snippet: 'Appuyez pour ajuster',
                                ),
                                icon:
                                    BitmapDescriptor.defaultMarkerWithHue(
                                  _isBoutique
                                      ? BitmapDescriptor.hueOrange
                                      : BitmapDescriptor.hueViolet,
                                ),
                              ),
                            },
                            onMapCreated: (ctrl) {
                              if (mounted) _mapController = ctrl;
                            },
                            onTap: (latLng) =>
                                setState(() => _position = latLng),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            buildingsEnabled: true,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            mapType:
                                _is3D ? MapType.hybrid : MapType.normal,
                          ),
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Appuyez sur la carte pour ajuster la position',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (_position != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.pin_drop_outlined,
                      size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${_position!.latitude.toStringAsFixed(5)}, '
                    '${_position!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isEditing ? Icons.save_outlined : typeIcon),
              label: Text(
                _loading
                    ? 'Enregistrement...'
                    : _isEditing
                        ? 'Enregistrer les modifications'
                        : 'Créer ${_isBoutique ? 'la boutique' : 'l\'établissement'}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: typeColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Widget carte de type ─────────────────────────────────────────────────────

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final Color color;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: 10),
                    ...features.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 14, color: color),
                              const SizedBox(width: 6),
                              Text(f,
                                  style: textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
