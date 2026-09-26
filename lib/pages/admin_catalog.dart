import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/store_state.dart';

const _adminOrange = Color(0xffE65829);

String _slugify(String value) {
  const replacements = {
    'ç': 'c',
    'ë': 'e',
    'Ç': 'c',
    'Ë': 'e',
  };
  var result = value;
  replacements.forEach((key, replacement) {
    result = result.replaceAll(key, replacement);
  });
  return result
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

String _message(Object error) {
  final text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? 'Veprimi nuk u krye. Provo përsëri.' : text;
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_message(error)),
      backgroundColor: Colors.red.shade700,
    ),
  );
}

class AdminProductsView extends StatefulWidget {
  final StoreState state;

  const AdminProductsView({super.key, required this.state});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  final searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() =>
      widget.state.service.adminProducts(search: searchController.text.trim());

  void _refresh() => setState(() => future = _load());

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const SizedBox(
                width: 280,
                child: Text(
                  'Produktet',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                ),
              ),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: searchController,
                  onSubmitted: (_) => _refresh(),
                  decoration: InputDecoration(
                    labelText: 'Kërko emrin, SKU ose brendin',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Kërko',
                      onPressed: _refresh,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Shto produkt'),
              ),
              IconButton(
                tooltip: 'Rifresko',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _CatalogError(onRetry: _refresh);
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('Nuk ka produkte për t’u shfaqur.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = rows[index];
                    return _ProductTile(
                      product: product,
                      onEdit: () => _edit(product),
                      onDelete: () => _remove(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic>? product) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductAdminDialog(
        state: widget.state,
        product: product,
      ),
    );
    if (changed == true && mounted) {
      _refresh();
      await widget.state.init();
    }
  }

  Future<void> _remove(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi produktin?'),
        content: Text(
          'Produkti “${product['name_sq'] ?? ''}” dhe galeria e tij do të fshihen. Porositë e vjetra ruajnë të dhënat historike.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.state.service.deleteProductAdmin('${product['id']}');
      if (!mounted) return;
      _refresh();
      await widget.state.init();
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final active = product['active'] == true;
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final discount = (product['discount_percentage'] as num?)?.toDouble() ?? 0;
    final images = product['product_images'];
    String? imageUrl;
    if (images is List && images.isNotEmpty) {
      final mapped = images.map((e) => Map<String, dynamic>.from(e)).toList()
        ..sort((a, b) {
          final primaryCompare = (b['is_primary'] == true ? 1 : 0)
              .compareTo(a['is_primary'] == true ? 1 : 0);
          if (primaryCompare != 0) return primaryCompare;
          return ((a['sort_order'] as num?)?.toInt() ?? 0)
              .compareTo((b['sort_order'] as num?)?.toInt() ?? 0);
        });
      imageUrl = mapped.first['image_url']?.toString();
    }
    final category = product['categories'];
    final categoryName = category is Map ? category['name']?.toString() : null;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 58,
          height: 58,
          child: imageUrl == null || imageUrl.isEmpty
              ? ColoredBox(
                  color: Colors.black12,
                  child: Icon(
                    active ? Icons.inventory_2_outlined : Icons.pause_circle,
                  ),
                )
              : Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
        title: Text(
          product['name_sq']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${product['sku'] ?? 'Pa SKU'} • ${categoryName ?? 'Pa kategori'}\n'
          '€${price.toStringAsFixed(2)}'
          '${discount > 0 ? ' • -${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 2)}%' : ''}'
          ' • Stok: ${product['stock'] ?? 0} • ${active ? 'Aktiv' : 'Joaktiv'}',
        ),
        isThreeLine: true,
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Ndrysho',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Fshi',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductAdminDialog extends StatefulWidget {
  final StoreState state;
  final Map<String, dynamic>? product;

  const ProductAdminDialog({
    super.key,
    required this.state,
    this.product,
  });

  @override
  State<ProductAdminDialog> createState() => _ProductAdminDialogState();
}

class _ProductAdminDialogState extends State<ProductAdminDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController nameEn;
  late final TextEditingController slug;
  late final TextEditingController sku;
  late final TextEditingController brand;
  late final TextEditingController price;
  late final TextEditingController discount;
  late final TextEditingController stock;
  late final TextEditingController warranty;
  late final TextEditingController shortDescription;
  late final TextEditingController description;
  late final TextEditingController sortOrder;

  bool active = true;
  bool isNew = false;
  bool featured = false;
  bool showOnHomepage = true;
  bool saving = false;
  String? categoryId;
  DateTime? discountStart;
  DateTime? discountEnd;
  late Future<List<Map<String, dynamic>>> categoriesFuture;
  late List<Map<String, dynamic>> images;
  final List<_PendingImage> pendingImages = [];

  @override
  void initState() {
    super.initState();
    final product = widget.product ?? <String, dynamic>{};
    name = TextEditingController(text: product['name_sq']?.toString() ?? '');
    nameEn = TextEditingController(text: product['name_en']?.toString() ?? '');
    slug = TextEditingController(text: product['slug']?.toString() ?? '');
    sku = TextEditingController(text: product['sku']?.toString() ?? '');
    brand = TextEditingController(text: product['brand']?.toString() ?? '');
    price = TextEditingController(text: product['price']?.toString() ?? '');
    discount = TextEditingController(
      text: product['discount_percentage']?.toString() ?? '0',
    );
    stock = TextEditingController(text: product['stock']?.toString() ?? '0');
    warranty = TextEditingController(
      text: product['warranty']?.toString() ?? 'Pa garanci',
    );
    shortDescription = TextEditingController(
      text: product['short_description_sq']?.toString() ?? '',
    );
    description = TextEditingController(
      text: product['description_sq']?.toString() ?? '',
    );
    sortOrder = TextEditingController(
      text: product['sort_order']?.toString() ?? '0',
    );
    categoryId = product['category_id']?.toString();
    active = product['active'] as bool? ?? true;
    isNew = product['is_new'] as bool? ?? false;
    featured = product['is_featured'] as bool? ?? false;
    showOnHomepage = product['show_on_homepage'] as bool? ?? true;
    discountStart = _parseDate(product['discount_start']);
    discountEnd = _parseDate(product['discount_end']);
    final rawImages = product['product_images'];
    images = rawImages is List
        ? rawImages.map((e) => Map<String, dynamic>.from(e)).toList()
        : [];
    _sortImages();
    categoriesFuture = widget.state.service.adminCategories();
  }

  DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  void _sortImages() {
    images.sort((a, b) {
      final primaryCompare = (b['is_primary'] == true ? 1 : 0)
          .compareTo(a['is_primary'] == true ? 1 : 0);
      if (primaryCompare != 0) return primaryCompare;
      return ((a['sort_order'] as num?)?.toInt() ?? 0)
          .compareTo((b['sort_order'] as num?)?.toInt() ?? 0);
    });
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      nameEn,
      slug,
      sku,
      brand,
      price,
      discount,
      stock,
      warranty,
      shortDescription,
      description,
      sortOrder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return AlertDialog(
      title:
          Text(widget.product == null ? 'Shto produkt' : 'Ndrysho produktin'),
      content: SizedBox(
        width: screenWidth > 760 ? 720 : screenWidth * .92,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Të dhënat bazë'),
                _responsiveFields([
                  TextFormField(
                    controller: name,
                    validator: _required,
                    onChanged: (value) {
                      if (widget.product == null) slug.text = _slugify(value);
                    },
                    decoration:
                        const InputDecoration(labelText: 'Emri shqip *'),
                  ),
                  TextFormField(
                    controller: nameEn,
                    decoration:
                        const InputDecoration(labelText: 'Emri anglisht'),
                  ),
                ]),
                _responsiveFields([
                  TextFormField(
                    controller: slug,
                    validator: _slugValidator,
                    decoration: const InputDecoration(labelText: 'Slug *'),
                  ),
                  TextFormField(
                    controller: sku,
                    validator: _required,
                    decoration: const InputDecoration(labelText: 'SKU *'),
                  ),
                ]),
                _responsiveFields([
                  TextFormField(
                    controller: brand,
                    decoration: const InputDecoration(labelText: 'Brendi'),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: categoriesFuture,
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? [];
                      final validValue = categories.any(
                        (category) => '${category['id']}' == categoryId,
                      )
                          ? categoryId
                          : null;
                      return DropdownButtonFormField<String>(
                        value: validValue,
                        validator: (value) =>
                            value == null ? 'Zgjidh një kategori.' : null,
                        decoration:
                            const InputDecoration(labelText: 'Kategoria *'),
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: '${category['id']}',
                                child: Text(category['name']?.toString() ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged:
                            snapshot.connectionState == ConnectionState.done
                                ? (value) => setState(() => categoryId = value)
                                : null,
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 20),
                const _SectionTitle('Çmimi, zbritja dhe stoku'),
                _responsiveFields([
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _positiveNumber,
                    decoration: const InputDecoration(labelText: 'Çmimi (€) *'),
                  ),
                  TextFormField(
                    controller: discount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _percentage,
                    decoration: const InputDecoration(labelText: 'Zbritja (%)'),
                  ),
                  TextFormField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    validator: _nonNegativeInteger,
                    decoration: const InputDecoration(labelText: 'Stoku *'),
                  ),
                ]),
                _responsiveFields([
                  _DateField(
                    label: 'Fillimi i zbritjes',
                    value: discountStart,
                    onChanged: (value) => setState(() => discountStart = value),
                  ),
                  _DateField(
                    label: 'Fundi i zbritjes',
                    value: discountEnd,
                    onChanged: (value) => setState(() => discountEnd = value),
                  ),
                ]),
                _responsiveFields([
                  DropdownButtonFormField<String>(
                    value: _warrantyOptions.contains(warranty.text)
                        ? warranty.text
                        : 'Tjetër',
                    decoration: const InputDecoration(labelText: 'Garancia'),
                    items: _warrantyOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null && value != 'Tjetër') {
                        warranty.text = value;
                      }
                      setState(() {});
                    },
                  ),
                  TextFormField(
                    controller: warranty,
                    decoration: const InputDecoration(
                      labelText: 'Garanci e personalizuar',
                    ),
                  ),
                  TextFormField(
                    controller: sortOrder,
                    keyboardType: TextInputType.number,
                    validator: _integer,
                    decoration: const InputDecoration(labelText: 'Renditja'),
                  ),
                ]),
                TextFormField(
                  controller: shortDescription,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Përshkrimi i shkurtër',
                  ),
                ),
                TextFormField(
                  controller: description,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Përshkrimi'),
                ),
                const SizedBox(height: 20),
                const _SectionTitle('Shfaqja'),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      selected: active,
                      onSelected: (value) => setState(() => active = value),
                      label: const Text('Aktiv'),
                    ),
                    FilterChip(
                      selected: isNew,
                      onSelected: (value) => setState(() => isNew = value),
                      label: const Text('Produkt i ri'),
                    ),
                    FilterChip(
                      selected: featured,
                      onSelected: (value) => setState(() => featured = value),
                      label: const Text('I zgjedhur'),
                    ),
                    FilterChip(
                      selected: showOnHomepage,
                      onSelected: (value) =>
                          setState(() => showOnHomepage = value),
                      label: const Text('Shfaq në ballinë'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildGallery(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Duke ruajtur…' : 'Ruaj'),
        ),
      ],
    );
  }

  Widget _responsiveFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620 || children.length == 1) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: children[index]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGallery() {
    final cards = <Widget>[
      ...images.map(
        (image) => _GalleryCard(
          imageUrl: image['image_url']?.toString(),
          primary: image['is_primary'] == true,
          onPrimary: saving ? null : () => _setPrimary(image),
          onDelete: saving ? null : () => _deleteImage(image),
        ),
      ),
      ...pendingImages.asMap().entries.map(
            (entry) => _GalleryCard(
              bytes: entry.value.bytes,
              primary: images.isEmpty && entry.key == 0,
              pending: true,
              onDelete: saving
                  ? null
                  : () => setState(() => pendingImages.removeAt(entry.key)),
            ),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionTitle('Galeria e produktit')),
            OutlinedButton.icon(
              onPressed: saving ? null : _pickProductImages,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Ngarko imazhe'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Formatet: JPG, PNG ose WEBP. Maksimumi 25 MB për skedar.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xffF5F5F5)),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined),
                  SizedBox(width: 10),
                  Text('Ende nuk ka imazhe.'),
                ],
              ),
            ),
          )
        else
          Wrap(spacing: 12, runSpacing: 12, children: cards),
      ],
    );
  }

  Future<void> _pickProductImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null) return;
    final picked = <_PendingImage>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      if (bytes.length > 25 * 1024 * 1024) {
        if (mounted) {
          _showError(
              context, Exception('${file.name} është më i madh se 25 MB.'));
        }
        continue;
      }
      picked.add(
        _PendingImage(
          name: file.name,
          bytes: bytes,
          contentType: _contentType(file.extension),
        ),
      );
    }
    if (mounted) setState(() => pendingImages.addAll(picked));
  }

  String _contentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> image) async {
    try {
      await widget.state.service.setPrimaryProductImage(
        '${widget.product!['id']}',
        '${image['id']}',
      );
      setState(() {
        for (final item in images) {
          item['is_primary'] = item['id'] == image['id'];
        }
        _sortImages();
      });
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    try {
      await widget.state.service.deleteProductImage(
        '${image['id']}',
        image['image_url']?.toString() ?? '',
      );
      if (mounted) {
        setState(() {
          images.removeWhere((item) => item['id'] == image['id']);
          if (images.isNotEmpty &&
              !images.any((item) => item['is_primary'] == true)) {
            images.first['is_primary'] = true;
          }
        });
        if (images.isNotEmpty && images.first['is_primary'] == true) {
          await widget.state.service.setPrimaryProductImage(
            '${widget.product!['id']}',
            '${images.first['id']}',
          );
        }
      }
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Fusha është e detyrueshme.' : null;

  String? _slugValidator(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return 'Fusha është e detyrueshme.';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(normalized)) {
      return 'Përdor vetëm shkronja të vogla, numra dhe viza.';
    }
    return null;
  }

  String? _positiveNumber(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed <= 0 ? 'Vendos një vlerë mbi 0.' : null;
  }

  String? _percentage(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed < 0 || parsed > 100
        ? 'Përdor një vlerë nga 0 deri në 100.'
        : null;
  }

  String? _integer(String? value) =>
      int.tryParse(value ?? '') == null ? 'Vendos një numër të plotë.' : null;

  String? _nonNegativeInteger(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed == null || parsed < 0
        ? 'Vendos një numër të plotë jo negativ.'
        : null;
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (discountStart != null &&
        discountEnd != null &&
        !discountEnd!.isAfter(discountStart!)) {
      _showError(
        context,
        Exception('Fundi i zbritjes duhet të jetë pas fillimit.'),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final selectedCategory = (await categoriesFuture).firstWhere(
        (category) => '${category['id']}' == categoryId,
      );
      final data = <String, dynamic>{
        'name_sq': name.text.trim(),
        'name_en':
            nameEn.text.trim().isEmpty ? name.text.trim() : nameEn.text.trim(),
        'slug': slug.text.trim(),
        'sku': sku.text.trim(),
        'brand': brand.text.trim(),
        'category_id': categoryId,
        'category': selectedCategory['slug']?.toString() ?? '',
        'price': double.parse(price.text.replaceAll(',', '.')),
        'discount_percentage': double.parse(discount.text.replaceAll(',', '.')),
        'discount_amount': 0,
        'discount_start': discountStart?.toUtc().toIso8601String(),
        'discount_end': discountEnd?.toUtc().toIso8601String(),
        'stock': int.parse(stock.text),
        'warranty':
            warranty.text.trim().isEmpty ? 'Pa garanci' : warranty.text.trim(),
        'short_description_sq': shortDescription.text.trim(),
        'short_description_en': shortDescription.text.trim(),
        'description_sq': description.text.trim(),
        'description_en': description.text.trim(),
        'active': active,
        'is_new': isNew,
        'is_featured': featured,
        'show_on_homepage': showOnHomepage,
        'sort_order': int.parse(sortOrder.text),
        'image_key': widget.product?['image_key'] ?? 'shooe_tilt_1.png',
      };
      final saved = await widget.state.service.saveProductAdmin(
        widget.product?['id']?.toString(),
        data,
      );
      final productId = '${saved['id']}';
      var order = images.length;
      for (final pending in pendingImages) {
        final url = await widget.state.service.uploadMedia(
          bytes: pending.bytes,
          fileName: pending.name,
          contentType: pending.contentType,
          folder: 'products/$productId',
        );
        await widget.state.service.addProductImage(
          productId: productId,
          imageUrl: url,
          altText: name.text.trim(),
          sortOrder: order,
          isPrimary: images.isEmpty && order == 0,
        );
        order++;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        _showError(context, error);
      }
    }
  }
}

const _warrantyOptions = [
  'Pa garanci',
  '3 muaj',
  '6 muaj',
  '12 muaj',
  '24 muaj',
  'Tjetër',
];

class _PendingImage {
  final String name;
  final Uint8List bytes;
  final String contentType;

  const _PendingImage({
    required this.name,
    required this.bytes,
    required this.contentType,
  });
}

class _GalleryCard extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final bool primary;
  final bool pending;
  final VoidCallback? onPrimary;
  final VoidCallback? onDelete;

  const _GalleryCard({
    this.imageUrl,
    this.bytes,
    this.primary = false,
    this.pending = false,
    this.onPrimary,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            SizedBox(
              width: 132,
              height: 100,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : Image.network(
                      imageUrl ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  if (pending)
                    const Expanded(
                      child: Text(
                        'Në pritje',
                        style: TextStyle(fontSize: 11),
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: primary ? null : onPrimary,
                        child: Text(primary ? 'Kryesor' : 'Bëj kryesor'),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Fshi imazhin',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 19),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminCategoriesView extends StatefulWidget {
  final StoreState state;

  const AdminCategoriesView({super.key, required this.state});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.service.adminCategories();
  }

  void _refresh() => setState(
        () => future = widget.state.service.adminCategories(),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Kategoritë',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: const Text('Shto kategori'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rifresko',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _CatalogError(onRetry: _refresh);
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('Nuk ka kategori për t’u shfaqur.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final category = rows[index];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: _CategoryImage(
                          imageUrl: category['image_url']?.toString(),
                        ),
                        title: Text(
                          category['name']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${category['description'] ?? ''}\n'
                          '${category['product_count'] ?? 0} produkte • '
                          '${category['is_active'] == true ? 'Aktive' : 'Joaktive'}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          children: [
                            IconButton(
                              tooltip: 'Ndrysho',
                              onPressed: () => _edit(category),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Fshi',
                              onPressed: () => _delete(category),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic>? category) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CategoryAdminDialog(
        state: widget.state,
        category: category,
      ),
    );
    if (changed == true && mounted) {
      _refresh();
      await widget.state.init();
    }
  }

  Future<void> _delete(Map<String, dynamic> category) async {
    final productCount = (category['product_count'] as num?)?.toInt() ?? 0;
    if (productCount > 0) {
      _showError(
        context,
        Exception(
          'Kategoria ka $productCount produkte. Zhvendosi produktet në një kategori tjetër para fshirjes.',
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Fshi kategorinë?'),
        content: Text('Kategoria “${category['name'] ?? ''}” do të fshihet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.state.service.deleteCategory(
        '${category['id']}',
        category['image_url']?.toString(),
      );
      if (!mounted) return;
      _refresh();
      await widget.state.init();
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

class CategoryAdminDialog extends StatefulWidget {
  final StoreState state;
  final Map<String, dynamic>? category;

  const CategoryAdminDialog({
    super.key,
    required this.state,
    this.category,
  });

  @override
  State<CategoryAdminDialog> createState() => _CategoryAdminDialogState();
}

class _CategoryAdminDialogState extends State<CategoryAdminDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController slug;
  late final TextEditingController description;
  late final TextEditingController sortOrder;
  bool active = true;
  bool showOnHomepage = true;
  bool saving = false;
  _PendingImage? pendingImage;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    final category = widget.category ?? <String, dynamic>{};
    name = TextEditingController(text: category['name']?.toString() ?? '');
    slug = TextEditingController(text: category['slug']?.toString() ?? '');
    description = TextEditingController(
      text: category['description']?.toString() ?? '',
    );
    sortOrder = TextEditingController(
      text: category['sort_order']?.toString() ?? '0',
    );
    active = category['is_active'] as bool? ?? true;
    showOnHomepage = category['show_on_homepage'] as bool? ?? true;
    imageUrl = category['image_url']?.toString();
  }

  @override
  void dispose() {
    name.dispose();
    slug.dispose();
    description.dispose();
    sortOrder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.category == null ? 'Shto kategori' : 'Ndrysho kategorinë'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  validator: _required,
                  onChanged: (value) {
                    if (widget.category == null) slug.text = _slugify(value);
                  },
                  decoration: const InputDecoration(labelText: 'Emri *'),
                ),
                TextFormField(
                  controller: slug,
                  validator: _slugValidator,
                  decoration: const InputDecoration(labelText: 'Slug *'),
                ),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Përshkrimi'),
                ),
                TextFormField(
                  controller: sortOrder,
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? 'Vendos një numër të plotë.'
                      : null,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Renditja'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                  title: const Text('Aktive'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: showOnHomepage,
                  onChanged: (value) => setState(() => showOnHomepage = value),
                  title: const Text('Shfaq në ballinë'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _CategoryImage(
                      imageUrl: imageUrl,
                      bytes: pendingImage?.bytes,
                      size: 92,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedButton.icon(
                            onPressed: saving ? null : _pickImage,
                            icon: const Icon(Icons.upload_outlined),
                            label: const Text('Ngarko imazh'),
                          ),
                          if (imageUrl != null || pendingImage != null)
                            TextButton.icon(
                              onPressed: saving
                                  ? null
                                  : () => setState(() {
                                        imageUrl = null;
                                        pendingImage = null;
                                      }),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Hiq imazhin'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Duke ruajtur…' : 'Ruaj'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > 25 * 1024 * 1024) {
      if (mounted) {
        _showError(context, Exception('Imazhi është më i madh se 25 MB.'));
      }
      return;
    }
    setState(() {
      pendingImage = _PendingImage(
        name: file.name,
        bytes: file.bytes!,
        contentType: _categoryContentType(file.extension),
      );
    });
  }

  String _categoryContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Fusha është e detyrueshme.' : null;

  String? _slugValidator(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return 'Fusha është e detyrueshme.';
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(normalized)) {
      return 'Përdor vetëm shkronja të vogla, numra dhe viza.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    String? newImageUrl = imageUrl;
    try {
      if (pendingImage != null) {
        newImageUrl = await widget.state.service.uploadMedia(
          bytes: pendingImage!.bytes,
          fileName: pendingImage!.name,
          contentType: pendingImage!.contentType,
          folder: 'categories',
        );
      }
      final oldImage = widget.category?['image_url']?.toString();
      await widget.state.service.saveCategory(
        widget.category?['id']?.toString(),
        {
          'name': name.text.trim(),
          'slug': slug.text.trim(),
          'description': description.text.trim(),
          'image_url': newImageUrl,
          'is_active': active,
          'show_on_homepage': showOnHomepage,
          'sort_order': int.parse(sortOrder.text),
        },
      );
      if (oldImage != null && oldImage.isNotEmpty && oldImage != newImageUrl) {
        await widget.state.service.deleteMedia(oldImage);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (pendingImage != null &&
          newImageUrl != null &&
          newImageUrl != imageUrl) {
        await widget.state.service.deleteMedia(newImageUrl);
      }
      if (mounted) {
        setState(() => saving = false);
        _showError(context, error);
      }
    }
  }
}

class _CategoryImage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? bytes;
  final double size;

  const _CategoryImage({this.imageUrl, this.bytes, this.size = 58});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      child = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
      );
    } else {
      child = const Icon(Icons.category_outlined);
    }
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xffF0F0F0)),
        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: child),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Pastro datën',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null
              ? 'Pa kufizim'
              : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
      );
}

class _CatalogError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CatalogError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42, color: Colors.red),
            const SizedBox(height: 12),
            const Text('Të dhënat nuk mund të ngarkohen.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Provo përsëri'),
            ),
          ],
        ),
      );
}
