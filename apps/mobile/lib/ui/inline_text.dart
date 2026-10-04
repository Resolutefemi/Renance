import 'package:flutter/material.dart';

import 'theme.dart';

/// Renders the lesson inline markers into styled spans:
/// **bold**, *italic*, `code`. Lessons are linted HTML-free at build
/// time, so this renderer is the only styling path, no injection
/// surface exists anywhere in the pipeline.
List<InlineSpan> buildInlineSpans(
  BuildContext context,
  String text, {
  TextStyle? base,
}) {
  final TextStyle style = base ?? RenanceText.bodyBase.copyWith(height: 1.55);
  final RegExp pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)');
  final List<InlineSpan> spans = <InlineSpan>[];
  int last = 0;
  for (final RegExpMatch m in pattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: style));
    }
    final String token = m.group(0)!;
    if (token.startsWith('**')) {
      spans.add(
        TextSpan(
          text: token.substring(2, token.length - 2),
          style: style.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    } else if (token.startsWith('`')) {
      spans.add(
        TextSpan(
          text: token.substring(1, token.length - 1),
          style: style.copyWith(
            fontFamily: 'JetBrains Mono',
            fontSize: (style.fontSize ?? 14) * 0.92,
            background: Paint()..color = context.cardLow,
          ),
        ),
      );
    } else {
      spans.add(TextSpan(text: token.substring(1, token.length - 1)));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: style));
  }
  return spans;
}

/// Convenience rich-text widget for one lesson block of prose.
class InlineText extends StatelessWidget {
  const InlineText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: buildInlineSpans(context, text, base: style)),
    );
  }
}
