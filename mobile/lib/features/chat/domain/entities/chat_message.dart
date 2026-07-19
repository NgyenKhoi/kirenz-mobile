class ChatAttachment {
  const ChatAttachment({
    required this.type,
    required this.url,
    required this.cloudinaryPublicId,
    required this.metadata,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    type: json['type']?.toString().toUpperCase() ?? 'FILE',
    url: json['url']?.toString() ?? '',
    cloudinaryPublicId: json['cloudinaryPublicId']?.toString() ?? '',
    metadata: json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const {},
  );

  final String type;
  final String url;
  final String cloudinaryPublicId;
  final Map<String, dynamic> metadata;

  String get name => metadata['name']?.toString() ?? 'Attachment';
  int? get bytes => int.tryParse(metadata['bytes']?.toString() ?? '');
  String? get contentType => metadata['contentType']?.toString();

  Map<String, dynamic> toJson() => {
    'type': type,
    'url': url,
    'cloudinaryPublicId': cloudinaryPublicId,
    'metadata': metadata,
  };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.content,
    required this.type,
    required this.attachments,
    required this.sentAt,
    required this.status,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final conversationId = json['conversationId']?.toString().trim() ?? '';
    if (id.isEmpty || conversationId.isEmpty) {
      throw const FormatException('Message response has an invalid shape.');
    }
    final rawAttachments = json['attachments'];
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Unknown',
      senderAvatar: json['senderAvatar']?.toString(),
      content: json['content']?.toString() ?? '',
      type: json['type']?.toString().toUpperCase() ?? 'TEXT',
      attachments: rawAttachments is List
          ? rawAttachments
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? ''),
      status: json['status']?.toString().toUpperCase() ?? 'ACTIVE',
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String type;
  final List<ChatAttachment> attachments;
  final DateTime? sentAt;
  final String status;

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderAvatar': senderAvatar,
    'content': content,
    'type': type,
    'attachments': attachments
        .map((attachment) => attachment.toJson())
        .toList(growable: false),
    'sentAt': sentAt?.toUtc().toIso8601String(),
    'status': status,
  };
}

enum DraftAttachmentStatus { local, uploading, uploaded, failed }

class DraftAttachment {
  const DraftAttachment({
    required this.path,
    required this.name,
    required this.bytes,
    required this.contentType,
    required this.type,
    this.status = DraftAttachmentStatus.local,
    this.progress = 0,
    this.uploaded,
    this.error,
  });

  final String path;
  final String name;
  final int bytes;
  final String contentType;
  final String type;
  final DraftAttachmentStatus status;
  final double progress;
  final ChatAttachment? uploaded;
  final String? error;

  DraftAttachment copyWith({
    DraftAttachmentStatus? status,
    double? progress,
    ChatAttachment? uploaded,
    String? error,
    bool clearError = false,
  }) => DraftAttachment(
    path: path,
    name: name,
    bytes: bytes,
    contentType: contentType,
    type: type,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    uploaded: uploaded ?? this.uploaded,
    error: clearError ? null : error ?? this.error,
  );
}
