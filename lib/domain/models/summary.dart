class Summary {
  final double income;  // >= 0
  final double expense; // <= 0 (negatif)
  final double net;     // income + expense
  const Summary({required this.income, required this.expense, required this.net});
}
