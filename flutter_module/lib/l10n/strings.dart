import 'package:flutter/widgets.dart';

class S {
  static S of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'zh' ? _Zh() : S();
  }

  // App
  String get appName => 'Meow';

  // Home
  String get home => 'Home';
  String get notConnected => 'Not Connected';
  String get connecting => 'Connecting...';
  String get connected => 'Connected';
  String get disconnecting => 'Disconnecting...';
  String get disconnected => 'Disconnected';
  String get proxyNodes => 'Proxy Nodes';
  String get active => 'Active';
  String get upload => 'Upload';
  String get download => 'Download';
  String get noSubscriptionHint => 'No subscription selected.\nGo to Subscribe tab to add one.';

  // Subscriptions
  String get subscribe => 'Subscribe';
  String get subscriptions => 'Subscriptions';
  String get noSubscriptions => 'No subscriptions';
  String get addSubscription => 'Add Subscription';
  String get editSubscription => 'Edit Subscription';
  String get deleteSubscription => 'Delete Subscription';
  String deleteConfirm(String name) => 'Delete "$name"?';
  String get name => 'Name';
  String get subscriptionUrl => 'Subscription URL';
  String get cancel => 'Cancel';
  String get save => 'Save';
  String get add => 'Add';
  String get delete => 'Delete';
  String get select => 'Select';
  String get edit => 'Edit';
  String get refresh => 'Refresh';
  String updated(String name) => '$name updated';
  String refreshFailed(String err) => 'Refresh failed: $err';
  String get proxies => 'proxies';

  // Traffic
  String get traffic => 'Traffic';
  String get currentSession => 'Current Session';
  String get total => 'Total';
  String get speedChart => 'Speed Chart';
  String get sessionSummary => 'Session Summary';
  String get collectingData => 'Collecting data...';
  String get connectToSeeTraffic => 'Connect VPN to see traffic';
  String get dataUsage => 'Data Usage';
  String get today => 'Today';
  String get thisMonth => 'This Month';
  String get dailyHistory => 'Daily History (30 days)';
  String get noHistoryData => 'No traffic history yet';

  // Settings
  String get settings => 'Settings';
  String get general => 'General';
  String get version => 'Version';
  String get network => 'Network';
  String get dnsServer => 'DNS Server';
  String get dnsBuiltIn => 'DoH via tun2socks';
  String get mixedPort => 'Mixed Port';
  String get mixedPortDesc => '7890 (SOCKS5 + HTTP)';
  String get apiController => 'API Controller';
  String get apiAddr => '127.0.0.1:9090';
  String get about => 'About';
  String get sourceCode => 'Source Code';
  String get sourceCodeUrl => 'github.com/madeye/mihomo-android';
}

class _Zh extends S {
  @override String get appName => 'Meow';

  // Home
  @override String get home => '首页';
  @override String get notConnected => '未连接';
  @override String get connecting => '连接中...';
  @override String get connected => '已连接';
  @override String get disconnecting => '断开中...';
  @override String get disconnected => '已断开';
  @override String get proxyNodes => '代理节点';
  @override String get active => '使用中';
  @override String get upload => '上传';
  @override String get download => '下载';
  @override String get noSubscriptionHint => '未选择订阅\n请前往订阅页面添加';

  // Subscriptions
  @override String get subscribe => '订阅';
  @override String get subscriptions => '订阅管理';
  @override String get noSubscriptions => '暂无订阅';
  @override String get addSubscription => '添加订阅';
  @override String get editSubscription => '编辑订阅';
  @override String get deleteSubscription => '删除订阅';
  @override String deleteConfirm(String name) => '确定删除 "$name"？';
  @override String get name => '名称';
  @override String get subscriptionUrl => '订阅链接';
  @override String get cancel => '取消';
  @override String get save => '保存';
  @override String get add => '添加';
  @override String get delete => '删除';
  @override String get select => '选择';
  @override String get edit => '编辑';
  @override String get refresh => '刷新';
  @override String updated(String name) => '$name 已更新';
  @override String refreshFailed(String err) => '刷新失败：$err';
  @override String get proxies => '个节点';

  // Traffic
  @override String get traffic => '流量';
  @override String get currentSession => '当前会话';
  @override String get total => '合计';
  @override String get speedChart => '速度图表';
  @override String get sessionSummary => '会话统计';
  @override String get collectingData => '正在收集数据...';
  @override String get connectToSeeTraffic => '连接 VPN 查看流量';
  @override String get dataUsage => '流量统计';
  @override String get today => '今日';
  @override String get thisMonth => '本月';
  @override String get dailyHistory => '每日流量（30 天）';
  @override String get noHistoryData => '暂无流量记录';

  // Settings
  @override String get settings => '设置';
  @override String get general => '通用';
  @override String get version => '版本';
  @override String get network => '网络';
  @override String get dnsServer => 'DNS 服务器';
  @override String get dnsBuiltIn => '通过 tun2socks DoH 转发';
  @override String get mixedPort => '混合端口';
  @override String get mixedPortDesc => '7890（SOCKS5 + HTTP）';
  @override String get apiController => 'API 控制器';
  @override String get apiAddr => '127.0.0.1:9090';
  @override String get about => '关于';
  @override String get sourceCode => '源代码';
  @override String get sourceCodeUrl => 'github.com/madeye/mihomo-android';
}
