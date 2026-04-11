class LogEntry {
  final String type;    // INFO | WARN | ERROR | DEBUG | SILENT
  final String payload;
  final String time;

  const LogEntry({required this.type, required this.payload, required this.time});

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        type: json['type'] as String? ?? '',
        payload: json['payload'] as String? ?? '',
        time: json['time'] as String? ?? '',
      );
}
