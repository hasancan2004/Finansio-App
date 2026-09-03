enum TxSortBy { date, amount }
enum SortOrder { asc, desc }

class TxFilter {
  final DateTime? startDate;    // dahil
  final DateTime? endDate;      // dahil
  final String? category;       // null => tümü
  final double? minAmount;
  final double? maxAmount;
  final TxSortBy sortBy;
  final SortOrder sortOrder;

  const TxFilter({
    this.startDate,
    this.endDate,
    this.category,
    this.minAmount,
    this.maxAmount,
    this.sortBy = TxSortBy.date,
    this.sortOrder = SortOrder.desc,
  });

  TxFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    double? minAmount,
    double? maxAmount,
    TxSortBy? sortBy,
    SortOrder? sortOrder,
  }) {
    return TxFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static const defaultFilter = TxFilter();
}
