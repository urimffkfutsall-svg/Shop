class ProductImageModel {
  final String id;
  final String imageUrl;
  final String altText;
  final int sortOrder;
  final bool isPrimary;
  const ProductImageModel(
      {required this.id,
      required this.imageUrl,
      this.altText = '',
      this.sortOrder = 0,
      this.isPrimary = false});
  factory ProductImageModel.fromMap(Map<String, dynamic> m) =>
      ProductImageModel(
          id: m['id'].toString(),
          imageUrl: m['image_url'] ?? '',
          altText: m['alt_text'] ?? '',
          sortOrder: m['sort_order'] ?? 0,
          isPrimary: m['is_primary'] ?? false);
}

class Product {
  final String id,
      nameSq,
      nameEn,
      category,
      imageKey,
      descriptionSq,
      descriptionEn;
  final String? categoryId;
  final String slug,
      sku,
      brand,
      shortDescriptionSq,
      shortDescriptionEn,
      warranty;
  final double price, discountPercentage, discountAmount;
  final int stock, sortOrder;
  final bool active, isNew, isFeatured, showOnHomepage;
  final DateTime? discountStart, discountEnd, createdAt, updatedAt;
  final List<ProductImageModel> images;
  const Product(
      {required this.id,
      required this.nameSq,
      required this.nameEn,
      required this.category,
      required this.imageKey,
      required this.descriptionSq,
      required this.descriptionEn,
      required this.price,
      this.categoryId,
      this.slug = '',
      this.sku = '',
      this.brand = '',
      this.shortDescriptionSq = '',
      this.shortDescriptionEn = '',
      this.warranty = 'Pa garanci',
      this.discountPercentage = 0,
      this.discountAmount = 0,
      this.stock = 0,
      this.sortOrder = 0,
      this.active = true,
      this.isNew = false,
      this.isFeatured = false,
      this.showOnHomepage = true,
      this.discountStart,
      this.discountEnd,
      this.createdAt,
      this.updatedAt,
      this.images = const []});
  factory Product.fromMap(Map<String, dynamic> m) {
    final raw = m['product_images'];
    final gallery = <ProductImageModel>[];
    if (raw is List) {
      gallery.addAll(raw
          .map((e) => ProductImageModel.fromMap(Map<String, dynamic>.from(e))));
      gallery.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    DateTime? dt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    return Product(
        id: m['id'].toString(),
        nameSq: m['name_sq'] ?? '',
        nameEn: m['name_en'] ?? m['name_sq'] ?? '',
        category: m['category'] ?? 'sneakers',
        categoryId: m['category_id']?.toString(),
        imageKey: m['image_key'] ?? 'shooe_tilt_1.png',
        descriptionSq: m['description_sq'] ?? '',
        descriptionEn: m['description_en'] ?? m['description_sq'] ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        slug: m['slug'] ?? '',
        sku: m['sku'] ?? '',
        brand: m['brand'] ?? '',
        shortDescriptionSq: m['short_description_sq'] ?? '',
        shortDescriptionEn: m['short_description_en'] ?? '',
        warranty: m['warranty'] ?? 'Pa garanci',
        discountPercentage: (m['discount_percentage'] as num?)?.toDouble() ?? 0,
        discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
        stock: m['stock'] ?? 0,
        sortOrder: m['sort_order'] ?? 0,
        active: m['active'] ?? true,
        isNew: m['is_new'] ?? false,
        isFeatured: m['is_featured'] ?? false,
        showOnHomepage: m['show_on_homepage'] ?? true,
        discountStart: dt(m['discount_start']),
        discountEnd: dt(m['discount_end']),
        createdAt: dt(m['created_at']),
        updatedAt: dt(m['updated_at']),
        images: gallery);
  }
  bool get discountActive {
    final n = DateTime.now();
    return (discountPercentage > 0 || discountAmount > 0) &&
        (discountStart == null || !n.isBefore(discountStart!)) &&
        (discountEnd == null || n.isBefore(discountEnd!));
  }

  double get finalPrice {
    if (!discountActive) return price;
    if (discountPercentage > 0)
      return double.parse((price * (1 - discountPercentage / 100))
          .clamp(0, price)
          .toStringAsFixed(2));
    return (price - discountAmount).clamp(0, price).toDouble();
  }

  double get savings => price - finalPrice;
  bool get inStock => stock > 0;
  String get primaryImageUrl {
    if (images.isNotEmpty) {
      final p = images.where((x) => x.isPrimary);
      return (p.isNotEmpty ? p.first : images.first).imageUrl;
    }
    return imageKey.startsWith('http') ? imageKey : 'assets/$imageKey';
  }

  Product copyWith(
          {String? nameSq,
          String? nameEn,
          String? category,
          String? categoryId,
          String? imageKey,
          String? descriptionSq,
          String? descriptionEn,
          double? price,
          String? slug,
          String? sku,
          String? brand,
          String? shortDescriptionSq,
          String? shortDescriptionEn,
          String? warranty,
          double? discountPercentage,
          double? discountAmount,
          int? stock,
          int? sortOrder,
          bool? active,
          bool? isNew,
          bool? isFeatured,
          bool? showOnHomepage,
          DateTime? discountStart,
          DateTime? discountEnd,
          List<ProductImageModel>? images}) =>
      Product(
          id: id,
          nameSq: nameSq ?? this.nameSq,
          nameEn: nameEn ?? this.nameEn,
          category: category ?? this.category,
          categoryId: categoryId ?? this.categoryId,
          imageKey: imageKey ?? this.imageKey,
          descriptionSq: descriptionSq ?? this.descriptionSq,
          descriptionEn: descriptionEn ?? this.descriptionEn,
          price: price ?? this.price,
          slug: slug ?? this.slug,
          sku: sku ?? this.sku,
          brand: brand ?? this.brand,
          shortDescriptionSq: shortDescriptionSq ?? this.shortDescriptionSq,
          shortDescriptionEn: shortDescriptionEn ?? this.shortDescriptionEn,
          warranty: warranty ?? this.warranty,
          discountPercentage: discountPercentage ?? this.discountPercentage,
          discountAmount: discountAmount ?? this.discountAmount,
          stock: stock ?? this.stock,
          sortOrder: sortOrder ?? this.sortOrder,
          active: active ?? this.active,
          isNew: isNew ?? this.isNew,
          isFeatured: isFeatured ?? this.isFeatured,
          showOnHomepage: showOnHomepage ?? this.showOnHomepage,
          discountStart: discountStart ?? this.discountStart,
          discountEnd: discountEnd ?? this.discountEnd,
          createdAt: createdAt,
          updatedAt: updatedAt,
          images: images ?? this.images);
  String name(bool sq) => sq ? nameSq : nameEn;
  String description(bool sq) => sq ? descriptionSq : descriptionEn;
  Map<String, dynamic> toMap() => {
        'name_sq': nameSq,
        'name_en': nameEn,
        'category': category,
        'category_id': categoryId,
        'image_key': imageKey,
        'description_sq': descriptionSq,
        'description_en': descriptionEn,
        'price': price,
        'slug': slug,
        'sku': sku,
        'brand': brand,
        'short_description_sq': shortDescriptionSq,
        'short_description_en': shortDescriptionEn,
        'warranty': warranty,
        'discount_percentage': discountPercentage,
        'discount_amount': discountAmount,
        'stock': stock,
        'sort_order': sortOrder,
        'active': active,
        'is_new': isNew,
        'is_featured': isFeatured,
        'show_on_homepage': showOnHomepage
      };
}

class CategoryModel {
  final String id, name, slug, description;
  final String? imageUrl;
  final bool showOnHomepage, isActive;
  final int sortOrder;
  const CategoryModel(
      {required this.id,
      required this.name,
      required this.slug,
      this.description = '',
      this.imageUrl,
      this.showOnHomepage = true,
      this.isActive = true,
      this.sortOrder = 0});
  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
      id: m['id'].toString(),
      name: m['name'] ?? '',
      slug: m['slug'] ?? '',
      description: m['description'] ?? '',
      imageUrl: m['image_url'],
      showOnHomepage: m['show_on_homepage'] ?? true,
      isActive: m['is_active'] ?? true,
      sortOrder: m['sort_order'] ?? 0);
}

class HomepageSectionModel {
  final String key, title;
  final bool visible;
  final int sortOrder;
  final Map<String, dynamic> config;
  const HomepageSectionModel(
      {required this.key,
      required this.title,
      required this.visible,
      required this.sortOrder,
      this.config = const {}});
  factory HomepageSectionModel.fromMap(Map<String, dynamic> m) =>
      HomepageSectionModel(
          key: m['section_key'],
          title: m['title'] ?? '',
          visible: m['is_visible'] ?? true,
          sortOrder: m['sort_order'] ?? 0,
          config: Map<String, dynamic>.from(m['config'] ?? {}));
}

const demoProducts = <Product>[
  Product(
      id: 'demo-1',
      nameSq: 'Nike Air Max 200',
      nameEn: 'Nike Air Max 200',
      category: 'sneakers',
      imageKey: 'shooe_tilt_1.png',
      price: 240,
      stock: 100,
      descriptionSq:
          'Linja të pastra, stil i gjithanshëm dhe amortizim Max Air për rehati në çdo hap.',
      descriptionEn:
          'Clean lines, versatile style and Max Air cushioning for comfort in every step.'),
  Product(
      id: 'demo-2',
      nameSq: 'Nike Air Max 97',
      nameEn: 'Nike Air Max 97',
      category: 'sneakers',
      imageKey: 'shoe_tilt_2.png',
      price: 220,
      stock: 100,
      descriptionSq:
          'Dizajn sportiv dhe komoditet i përditshëm me pamje ikonike.',
      descriptionEn: 'Sporty design and everyday comfort with an iconic look.'),
];
