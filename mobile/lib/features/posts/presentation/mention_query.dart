import 'package:flutter/services.dart';

class PostMentionQuery {
  const PostMentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  final int start;
  final int end;
  final String query;
}

PostMentionQuery? postMentionAtCursor(TextEditingValue value) {
  final cursor = value.selection.baseOffset;
  if (!value.selection.isValid || !value.selection.isCollapsed || cursor < 0) {
    return null;
  }
  final beforeCursor = value.text.substring(0, cursor);
  final match = RegExp(r'(?:^|\s)@([A-Za-z0-9._-]*)$').firstMatch(beforeCursor);
  if (match == null) return null;
  return PostMentionQuery(
    start: beforeCursor.lastIndexOf('@'),
    end: cursor,
    query: match.group(1) ?? '',
  );
}
