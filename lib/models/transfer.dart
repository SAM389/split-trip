class Transfer {
  final String from;
  final String to;
  final double amount;

  const Transfer(this.from, this.to, this.amount);

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'amount': amount,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    return Transfer(
      map['from'] as String,
      map['to'] as String,
      (map['amount'] as num).toDouble(),
    );
  }
}
