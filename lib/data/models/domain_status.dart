class DomainStatus {
  final String id;
  final String domainId;
  final String? resolvedIp;
  final String? finalUrl;
  final int? finalStatusCode;
  final List<RedirectHop>? redirectChain;
  final DateTime lastCheckedAt;

  DomainStatus({
    required this.id,
    required this.domainId,
    this.resolvedIp,
    this.finalUrl,
    this.finalStatusCode,
    this.redirectChain,
    required this.lastCheckedAt,
  });

  factory DomainStatus.fromJson(Map<String, dynamic> json) {
    List<RedirectHop>? chain;
    if (json['redirect_chain'] != null) {
      final chainData = json['redirect_chain'] as List<dynamic>;
      chain = chainData
          .map((hop) => RedirectHop.fromJson(hop as Map<String, dynamic>))
          .toList();
    }

    return DomainStatus(
      id: json['id'] as String,
      domainId: json['domain_id'] as String,
      resolvedIp: json['resolved_ip'] as String?,
      finalUrl: json['final_url'] as String?,
      finalStatusCode: json['final_status_code'] as int?,
      redirectChain: chain,
      lastCheckedAt: DateTime.parse(json['last_checked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'domain_id': domainId,
      'resolved_ip': resolvedIp,
      'final_url': finalUrl,
      'final_status_code': finalStatusCode,
      'redirect_chain': redirectChain?.map((hop) => hop.toJson()).toList(),
      'last_checked_at': lastCheckedAt.toIso8601String(),
    };
  }

  /// Helper to get status label
  String get statusLabel {
    if (finalStatusCode == null) return 'Unknown';
    if (finalStatusCode! >= 200 && finalStatusCode! < 300) return 'Live';
    if (finalStatusCode! >= 300 && finalStatusCode! < 400) return 'Redirect';
    if (finalStatusCode! >= 400) return 'Broken';
    return 'Unknown';
  }

  /// Check if there are redirects
  bool get hasRedirects =>
      redirectChain != null && redirectChain!.length > 1;

  /// Count of redirect hops
  int get redirectCount => redirectChain?.length ?? 0;
}

class RedirectHop {
  final String url;
  final int statusCode;

  RedirectHop({
    required this.url,
    required this.statusCode,
  });

  factory RedirectHop.fromJson(Map<String, dynamic> json) {
    return RedirectHop(
      url: json['url'] as String,
      statusCode: json['status_code'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'status_code': statusCode,
    };
  }
}
