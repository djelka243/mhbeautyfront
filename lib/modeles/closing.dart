class Closing {
  final String id;
  final DateTime date;
  final double totalSales;
  final Map<String, double> salesByCategory;
  final List<Map<String, dynamic>> productsSold;

  Closing({
    required this.id,
    required this.date,
    required this.totalSales,
    required this.salesByCategory,
    required this.productsSold,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'totalSales': totalSales,
      'salesByCategory': salesByCategory,
      'productsSold': productsSold,
    };
  }
}
