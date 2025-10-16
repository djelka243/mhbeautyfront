class Sale {
  final String id;
  final DateTime date;
  final double total;
  final String customerName;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.date,
    required this.total,
    required this.customerName,
    required this.items,
  });
}


class SaleItem {
  final String productName;
  final int quantity;
  final double price;

  SaleItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });
}