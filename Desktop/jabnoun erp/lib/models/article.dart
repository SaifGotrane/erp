import 'package:equatable/equatable.dart';

class ArticleCategory extends Equatable {
  final String id;
  final String name;
  final bool active;

  const ArticleCategory({required this.id, required this.name, this.active = true});

  factory ArticleCategory.fromMap(Map<String, dynamic> map) => ArticleCategory(
        id: map['id'] as String,
        name: map['name'] as String,
        active: map['active'] as bool? ?? true,
      );

  Map<String, dynamic> toInsertMap() => {'name': name, 'active': active};

  @override
  List<Object?> get props => [id, name, active];
}

class ArticleUnit extends Equatable {
  final String id;
  final String name;
  final String symbol;

  const ArticleUnit({required this.id, required this.name, required this.symbol});

  factory ArticleUnit.fromMap(Map<String, dynamic> map) => ArticleUnit(
        id: map['id'] as String,
        name: map['name'] as String,
        symbol: map['symbol'] as String,
      );

  Map<String, dynamic> toInsertMap() => {'name': name, 'symbol': symbol};

  @override
  List<Object?> get props => [id, name, symbol];
}

class TaxRate extends Equatable {
  final String id;
  final String label;
  final double ratePercent;
  final bool active;
  final bool isDefault;

  const TaxRate({
    required this.id,
    required this.label,
    required this.ratePercent,
    this.active = true,
    this.isDefault = false,
  });

  factory TaxRate.fromMap(Map<String, dynamic> map) => TaxRate(
        id: map['id'] as String,
        label: map['label'] as String,
        ratePercent: (map['rate_percent'] as num).toDouble(),
        active: map['active'] as bool? ?? true,
        isDefault: map['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toInsertMap() => {
        'label': label,
        'rate_percent': ratePercent,
        'active': active,
        'is_default': isDefault,
      };

  @override
  List<Object?> get props => [id, label, ratePercent, active, isDefault];
}

class Article extends Equatable {
  final String id;
  final String reference;
  final String designation;
  final String? categoryId;
  final String? unitId;
  final String? description;
  final String? barcode;
  final double minStock;
  final double purchasePriceHt;
  final String taxRateId;
  final double taxRatePercent;
  final double marginPercent;
  final double sellingPriceHt;
  final double sellingPriceTtc;
  final bool active;
  final DateTime createdAt;

  const Article({
    required this.id,
    required this.reference,
    required this.designation,
    this.categoryId,
    this.unitId,
    this.description,
    this.barcode,
    required this.minStock,
    required this.purchasePriceHt,
    required this.taxRateId,
    required this.taxRatePercent,
    required this.marginPercent,
    required this.sellingPriceHt,
    required this.sellingPriceTtc,
    required this.active,
    required this.createdAt,
  });

  factory Article.fromMap(Map<String, dynamic> map) => Article(
        id: map['id'] as String,
        reference: map['reference'] as String,
        designation: map['designation'] as String,
        categoryId: map['category_id'] as String?,
        unitId: map['unit_id'] as String?,
        description: map['description'] as String?,
        barcode: map['barcode'] as String?,
        minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
        purchasePriceHt: (map['purchase_price_ht'] as num?)?.toDouble() ?? 0,
        taxRateId: map['tax_rate_id'] as String? ?? '',
        taxRatePercent: (map['tax_rate_percent'] as num?)?.toDouble() ?? 0,
        marginPercent: (map['margin_percent'] as num?)?.toDouble() ?? 0,
        sellingPriceHt: (map['selling_price_ht'] as num?)?.toDouble() ?? 0,
        sellingPriceTtc: (map['selling_price_ttc'] as num?)?.toDouble() ?? 0,
        active: map['active'] as bool? ?? true,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toInsertMap() => {
        'reference': reference,
        'designation': designation,
        'category_id': categoryId,
        'unit_id': unitId,
        'description': description,
        'barcode': barcode,
        'min_stock': minStock,
        'purchase_price_ht': purchasePriceHt,
        'tax_rate_id': taxRateId,
        'tax_rate_percent': taxRatePercent,
        'margin_percent': marginPercent,
        'selling_price_ht': sellingPriceHt,
        'selling_price_ttc': sellingPriceTtc,
        'active': active,
      };

  /// Calcule prix de vente HT/TTC à partir du prix d'achat, de la marge et
  /// du taux de TVA. Utilisé côté UI pour prévisualisation ; le calcul
  /// définitif est revalidé côté serveur.
  static ({double sellingHt, double sellingTtc}) computeSellingPrice({
    required double purchasePriceHt,
    required double marginPercent,
    required double taxRatePercent,
  }) {
    final sellingHt = purchasePriceHt * (1 + marginPercent / 100);
    final sellingTtc = sellingHt * (1 + taxRatePercent / 100);
    return (sellingHt: sellingHt, sellingTtc: sellingTtc);
  }

  @override
  List<Object?> get props => [id, reference, designation, active];
}
