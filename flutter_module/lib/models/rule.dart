class Rule {
  final String type;
  final String payload;
  final String proxy;

  const Rule({required this.type, required this.payload, required this.proxy});

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
        type: json['type'] as String? ?? '',
        payload: json['payload'] as String? ?? '',
        proxy: json['proxy'] as String? ?? '',
      );
}
