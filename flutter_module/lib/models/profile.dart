class ClashProfile {
  final int id;
  String name;
  String url;
  String yamlContent;
  bool selected;
  int lastUpdated;
  int tx;
  int rx;
  String selectedProxy;

  ClashProfile({
    this.id = 0,
    this.name = '',
    this.url = '',
    this.yamlContent = '',
    this.selected = false,
    this.lastUpdated = 0,
    this.tx = 0,
    this.rx = 0,
    this.selectedProxy = '',
  });

  factory ClashProfile.fromMap(Map<dynamic, dynamic> map) => ClashProfile(
        id: map['id'] as int? ?? 0,
        name: map['name'] as String? ?? '',
        url: map['url'] as String? ?? '',
        yamlContent: map['yamlContent'] as String? ?? '',
        selected: map['selected'] as bool? ?? false,
        lastUpdated: map['lastUpdated'] as int? ?? 0,
        tx: map['tx'] as int? ?? 0,
        rx: map['rx'] as int? ?? 0,
        selectedProxy: map['selectedProxy'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'yamlContent': yamlContent,
        'selected': selected,
        'lastUpdated': lastUpdated,
        'tx': tx,
        'rx': rx,
        'selectedProxy': selectedProxy,
      };

  /// Parse proxy names from the YAML content
  List<String> get proxyNames {
    final names = <String>[];
    final lines = yamlContent.split('\n');
    var inProxies = false;
    for (final line in lines) {
      if (line.trim() == 'proxies:') {
        inProxies = true;
        continue;
      }
      if (inProxies) {
        if (line.startsWith('  - name:') || line.startsWith('  - {name:')) {
          final match = RegExp(r'name:\s*(.+?)(?:,|\s*$)').firstMatch(line);
          if (match != null) names.add(match.group(1)!.trim());
        } else if (!line.startsWith('  ') && !line.startsWith('    ') && line.trim().isNotEmpty) {
          inProxies = false;
        }
      }
    }
    return names;
  }
}
