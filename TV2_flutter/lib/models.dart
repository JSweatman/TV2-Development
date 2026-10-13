class ResourceRecord {
  const ResourceRecord({
    required this.key,
    required this.type,
    required this.uri,
    required this.metadata,
  });

  final String key;
  final String type;
  final String? uri;
  final Map<String, dynamic> metadata;

  factory ResourceRecord.fromJson(Map<String, dynamic> json) => ResourceRecord(
        key: json['key'] as String,
        type: json['type'] as String,
        uri: json['uri'] as String?,
        metadata: Map<String, dynamic>.from(
          (json['metadata'] as Map?) ?? const <String, dynamic>{},
        ),
      );
}

class ButtonRecord {
  const ButtonRecord({
    required this.slot,
    required this.label,
    required this.resourceKey,
  });

  final int slot;
  final String? label;
  final String resourceKey;

  factory ButtonRecord.fromJson(Map<String, dynamic> json) => ButtonRecord(
        slot: json['slot'] as int,
        label: json['label'] as String?,
        resourceKey: json['resource_key'] as String,
      );
}

class Listing {
  const Listing({
    required this.countryCode,
    required this.listNumber,
    required this.tldx,
    required this.displayName,
    required this.entityType,
    required this.templateKey,
    required this.resources,
    required this.buttons,
  });

  final String? countryCode;
  final String listNumber;
  final String? tldx;
  final String displayName;
  final String entityType;
  final String templateKey;
  final List<ResourceRecord> resources;
  final List<ButtonRecord> buttons;

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
        countryCode: json['country_code'] as String?,
        listNumber: json['list_number'] as String,
        tldx: json['tldx'] as String?,
        displayName: json['display_name'] as String,
        entityType: json['entity_type'] as String,
        templateKey: json['template_key'] as String,
        resources: (json['resources'] as List<dynamic>? ?? const [])
            .map((item) => ResourceRecord.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        buttons: (json['buttons'] as List<dynamic>? ?? const [])
            .map((item) => ButtonRecord.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
      );

  String get qualifiedIdentity {
    final body = tldx == null ? listNumber : '$listNumber.$tldx';
    return countryCode == null ? '*$body' : '$countryCode*$body';
  }

  ResourceRecord? resource(String key) {
    for (final item in resources) {
      if (item.key == key) return item;
    }
    return null;
  }

  bool hasType(String type) => resources.any((item) => item.type == type);
}

class MatchRecord {
  const MatchRecord({
    required this.countryCode,
    required this.listNumber,
    required this.tldx,
    required this.displayName,
    required this.entityType,
    required this.qualifiedInput,
    required this.exact,
  });

  final String? countryCode;
  final String listNumber;
  final String? tldx;
  final String displayName;
  final String entityType;
  final String qualifiedInput;
  final bool exact;

  factory MatchRecord.fromJson(Map<String, dynamic> json) => MatchRecord(
        countryCode: json['country_code'] as String?,
        listNumber: json['list_number'] as String,
        tldx: json['tldx'] as String?,
        displayName: json['display_name'] as String,
        entityType: json['entity_type'] as String,
        qualifiedInput: json['qualified_input'] as String,
        exact: json['exact'] as bool,
      );
}

class PrefixResponse {
  const PrefixResponse({
    required this.countryContext,
    required this.input,
    required this.matches,
    required this.hasMore,
  });

  final String? countryContext;
  final String input;
  final List<MatchRecord> matches;
  final bool hasMore;

  factory PrefixResponse.fromJson(Map<String, dynamic> json) => PrefixResponse(
        countryContext: json['country_context'] as String?,
        input: json['input'] as String,
        matches: (json['matches'] as List<dynamic>? ?? const [])
            .map((item) => MatchRecord.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        hasMore: json['has_more'] as bool? ?? false,
      );
}

class ResolveResponse {
  const ResolveResponse({
    required this.status,
    required this.countryContext,
    required this.input,
    required this.listing,
  });

  final String status;
  final String? countryContext;
  final String input;
  final Listing? listing;

  factory ResolveResponse.fromJson(Map<String, dynamic> json) => ResolveResponse(
        status: json['status'] as String,
        countryContext: json['country_context'] as String?,
        input: json['input'] as String,
        listing: json['listing'] == null
            ? null
            : Listing.fromJson(json['listing'] as Map<String, dynamic>),
      );
}
