import 'package:material_ui/material_ui.dart';
import '../../theme/app_colors.dart';

/// Renderer Markdown ringan tanpa dependensi tambahan untuk balasan Tanya Feen.
///
/// Mendukung paragraf, heading ringan (`#`/`##`/`###`), daftar poin (`- `/`1. `),
/// teks tebal (`**tebal**`), miring (`*miring*`), serta kode inline (`` `kode` ``).
class FeenMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color accentColor;

  const FeenMarkdownText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.accentColor = primaryGreen,
  });

  /// Mengembalikan versi teks polos bersih untuk aksi salin ke clipboard.
  static String toPlainText(String markdown) {
    return markdown
        .replaceAll(RegExp(r'^#{1,3}\s+', multiLine: true), '')
        .replaceAll('**', '')
        .replaceAll('`', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final normalized = text.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = normalized.split('\n');
    final List<Widget> blocks = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        if (blocks.isNotEmpty) {
          blocks.add(const SizedBox(height: 6));
        }
        continue;
      }

      // Heading ringan: ### Judul
      final headingMatch = RegExp(r'^#{1,3}\s+(.+)$').firstMatch(trimmed);
      if (headingMatch != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: Text.rich(
              TextSpan(
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: (baseStyle.fontSize ?? 14) + 0.5,
                ),
                children: _parseInline(headingMatch.group(1)!, baseStyle),
              ),
            ),
          ),
        );
        continue;
      }

      // Daftar poin: - item atau * item
      final bulletMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: baseStyle,
                      children: _parseInline(bulletMatch.group(1)!, baseStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Daftar bernomor: 1. item
      final numberedMatch = RegExp(r'^(\d+\.)\s+(.+)$').firstMatch(trimmed);
      if (numberedMatch != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    numberedMatch.group(1)!,
                    style: baseStyle.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: baseStyle,
                      children: _parseInline(numberedMatch.group(2)!, baseStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Paragraf biasa
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(
            TextSpan(
              style: baseStyle,
              children: _parseInline(trimmed, baseStyle),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<InlineSpan> _parseInline(String input, TextStyle base) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
    int cursor = 0;

    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: _cleanUnmatchedMarkers(input.substring(cursor, match.start)),
          ),
        );
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**') && token.length > 4) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w800),
          ),
        );
      } else if (token.startsWith('*') &&
          token.endsWith('*') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (token.startsWith('`') &&
          token.endsWith('`') &&
          token.length > 2) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              backgroundColor: accentColor.withValues(alpha: 0.1),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token));
      }

      cursor = match.end;
    }

    if (cursor < input.length) {
      spans.add(
        TextSpan(text: _cleanUnmatchedMarkers(input.substring(cursor))),
      );
    }

    return spans;
  }

  String _cleanUnmatchedMarkers(String chunk) => chunk.replaceAll('**', '');
}
