/// Question text rendering for past questions.
///
/// Past questions arrive in three shapes:
///   1. plain text (the founder's banks),
///   2. LaTeX inline math \( … \) (calculation subjects),
///   3. small HTML fragments from the myschool archive
///      (<sub>, <sup>, <br>, <table>, entities).
///
/// The player used to print all three verbatim — the "raw markup in
/// maths questions" bug. This library converts the safe subset into
/// Flutter inline spans: unknown tags are unwrapped (text kept),
/// <script>/<style> content is discarded, entities are decoded, and
/// LaTeX is turned into unicode super/subscripts and symbols.
library;

import 'package:flutter/material.dart';

import 'config.dart';

/// Resolves an origin-less media path (/qimages/…) against the study API
/// the app already talks to.
String resolveQImageUrl(String src) {
  if (src.startsWith('http://') || src.startsWith('https://')) return src;
  return '$apiBaseUrl${src.startsWith('/') ? src : '/$src'}';
}

// ----------------------------------------------------------------- entities

const Map<String, String> _entities = <String, String>{
  'nbsp': '\u00a0', 'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"',
  'apos': "'", 'ldquo': '\u201c', 'rdquo': '\u201d', 'lsquo': '\u2018',
  'rsquo': '\u2019', 'ndash': '\u2013', 'mdash': '\u2014',
  'hellip': '\u2026', 'bull': '\u2022', 'middot': '\u00b7',
  'deg': '\u00b0', 'plusmn': '\u00b1', 'times': '\u00d7',
  'divide': '\u00f7', 'frac12': '\u00bd', 'frac14': '\u00bc',
  'frac34': '\u00be', 'minus': '\u2212', 'le': '\u2264', 'ge': '\u2265',
  'ne': '\u2260', 'asymp': '\u2248', 'infin': '\u221e', 'prime': '\u2032',
  'Alpha': '\u0391', 'Beta': '\u0392', 'Gamma': '\u0393', 'Delta': '\u0394',
  'Theta': '\u0398', 'Lambda': '\u039b', 'Pi': '\u03a0', 'Sigma': '\u03a3',
  'Phi': '\u03a6', 'Omega': '\u03a9', 'alpha': '\u03b1', 'beta': '\u03b2',
  'gamma': '\u03b3', 'delta': '\u03b4', 'theta': '\u03b8',
  'lambda': '\u03bb', 'mu': '\u03bc', 'pi': '\u03c0', 'rho': '\u03c1',
  'sigma': '\u03c3', 'phi': '\u03c6', 'omega': '\u03c9', 'sup2': '\u00b2',
  'sup3': '\u00b3', 'frac13': '\u2153',
};

String decodeEntities(String text) {
  return text
      .replaceAll(RegExp(r'&nbsp(?![a-zA-Z0-9;])'), '\u00a0')
      .replaceAllMapped(
    RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);'),
    (Match m) {
      final String body = m.group(1)!;
      final bool hex = body.startsWith('#x') || body.startsWith('#X');
      if (hex || body.startsWith('#')) {
        final int? code = int.tryParse(
          body.startsWith('#') ? body.substring(hex ? 2 : 1) : body,
          radix: hex ? 16 : 10,
        );
        if (code != null && code >= 0) return String.fromCharCode(code);
        return m.group(0)!;
      }
      return _entities[body] ?? m.group(0)!;
    },
  );
}

// --------------------------------------------------------------------- LaTeX

const Map<String, String> _greek = <String, String>{
  'alpha': '\u03b1', 'beta': '\u03b2', 'gamma': '\u03b3', 'delta': '\u03b4',
  'epsilon': '\u03b5', 'varepsilon': '\u03b5', 'zeta': '\u03b6',
  'eta': '\u03b7', 'theta': '\u03b8', 'vartheta': '\u03d1', 'iota': '\u03b9',
  'kappa': '\u03ba', 'lambda': '\u03bb', 'mu': '\u03bc', 'nu': '\u03bd',
  'xi': '\u03be', 'pi': '\u03c0', 'rho': '\u03c1', 'sigma': '\u03c3',
  'tau': '\u03c4', 'upsilon': '\u03c5', 'phi': '\u03c6', 'varphi': '\u03c6',
  'chi': '\u03c7', 'psi': '\u03c8', 'omega': '\u03c9', 'Gamma': '\u0393',
  'Delta': '\u0394', 'Theta': '\u0398', 'Lambda': '\u039b', 'Xi': '\u039e',
  'Pi': '\u03a0', 'Sigma': '\u03a3', 'Phi': '\u03a6', 'Psi': '\u03a8',
  'Omega': '\u03a9',
};

const Map<String, String> _symbols = <String, String>{
  'times': '\u00d7', 'div': '\u00f7', 'cdot': '\u00b7', 'pm': '\u00b1',
  'mp': '\u2213', 'leq': '\u2264', 'le': '\u2264', 'geq': '\u2265',
  'ge': '\u2265', 'neq': '\u2260', 'ne': '\u2260', 'approx': '\u2248',
  'equiv': '\u2261', 'infty': '\u221e', 'propto': '\u221d',
  'degree': '\u00b0', 'circ': '\u00b0', 'sum': '\u2211', 'prod': '\u220f',
  'int': '\u222b', 'partial': '\u2202', 'nabla': '\u2207',
  'sqrt': '\u221a', 'perp': '\u22a5', 'parallel': '\u2225',
  'angle': '\u2220', 'triangle': '\u25b3', 'therefore': '\u2234',
  'because': '\u2235', 'in': '\u2208', 'notin': '\u2209',
  'subset': '\u2282', 'supset': '\u2283', 'cup': '\u222a', 'cap': '\u2229',
  'emptyset': '\u2205', 'forall': '\u2200', 'exists': '\u2203',
  'rightarrow': '\u2192', 'to': '\u2192', 'leftarrow': '\u2190',
  'Rightarrow': '\u21d2', 'Leftarrow': '\u21d0',
  'leftrightarrow': '\u2194', 'Leftrightarrow': '\u21d4',
  'uparrow': '\u2191', 'downarrow': '\u2193', 'ldots': '\u2026',
  'cdots': '\u22ef', 'dots': '\u2026', 'quad': '\u2003',
  'qquad': '\u2003\u2003', 'langle': '\u27e8', 'rangle': '\u27e9',
  'ell': '\u2113', 'hbar': '\u210f',
};

/// Reads a balanced `{…}` group at `i` (or one bare character).
/// Returns the group's inner content and the index just past it.
(String, int) _latexGroup(String src, int i) {
  if (i >= src.length) return ('', i);
  if (src[i] != '{') return (src[i], i + 1);
  int depth = 0;
  for (int j = i; j < src.length; j++) {
    if (src[j] == '{') {
      depth++;
    } else if (src[j] == '}') {
      depth--;
      if (depth == 0) return (src.substring(i + 1, j), j + 1);
    }
  }
  return (src.substring(i + 1), src.length);
}

const Map<String, String> _subDigits = <String, String>{
  '0': '\u2080', '1': '\u2081', '2': '\u2082', '3': '\u2083', '4': '\u2084',
  '5': '\u2085', '6': '\u2086', '7': '\u2087', '8': '\u2088', '9': '\u2089',
  '+': '\u208a', '-': '\u208b', '=': '\u208c', '(': '\u208d', ')': '\u208e',
  'n': '\u2099', 'm': '\u2098', 'x': '\u2093', 'e': '\u2091', 'o': '\u2092',
  'a': '\u2090', 'i': '\u1d62', 'r': '\u1d63', 'u': '\u1d64', 'v': '\u1d65',
};

const Map<String, String> _supDigits = <String, String>{
  '0': '\u2070', '1': '\u00b9', '2': '\u00b2', '3': '\u00b3', '4': '\u2074',
  '5': '\u2075', '6': '\u2076', '7': '\u2077', '8': '\u2078', '9': '\u2079',
  '+': '\u207a', '-': '\u207b', '=': '\u207c', '(': '\u207d', ')': '\u207e',
  'n': '\u207f', 'i': '\u2071',
};

String _scripted(String content, bool sub) {
  final Map<String, String> map = sub ? _subDigits : _supDigits;
  if (content.isEmpty) return '';
  final bool all = content.runes
      .every((int r) => map.containsKey(String.fromCharCode(r)));
  if (all) {
    return String.fromCharCodes(
      content.runes.map((int r) => map[String.fromCharCode(r)]!.runes.first),
    );
  }
  if (content.length == 1) return content;
  return sub ? '_[$content]' : '^[$content]';
}

/// Converts a LaTeX inline-math body into plain text with unicode
/// super/subscripts — enough for MCQ options, no TeX engine involved.
String latexToText(String src) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < src.length) {
    final String c = src[i];
    if (c == '\\') {
      final RegExpMatch? m =
          RegExp(r'^\\([a-zA-Z]+|.)').firstMatch(src.substring(i));
      if (m == null) {
        i++;
        continue;
      }
      final String cmd = m.group(1)!;
      i += m.end;
      if (cmd == 'frac' || cmd == 'dfrac' || cmd == 'tfrac') {
        final (String num, int i1) = _latexGroup(src, i);
        final (String den, int i2) = _latexGroup(src, i1);
        final String n = latexToText(num);
        final String d = latexToText(den);
        out.write(n.length == 1 && d.length == 1 ? '$n\u2044$d' : '($n)\u2044($d)');
        i = i2;
        continue;
      }
      if (cmd == 'sqrt') {
        while (i < src.length && src[i] == ' ') {
          i++;
        }
        final (String body, int i1) = _latexGroup(src, i);
        out.write('\u221a(${latexToText(body)})');
        i = i1;
        continue;
      }
      if (cmd == 'text' || cmd == 'mathrm' || cmd == 'mbox' || cmd == 'operatorname') {
        final (String body, int i1) = _latexGroup(src, i);
        out.write(body);
        i = i1;
        continue;
      }
      if (cmd == 'left' || cmd == 'right') continue;
      if (_greek.containsKey(cmd)) {
        out.write(_greek[cmd]);
        continue;
      }
      if (_symbols.containsKey(cmd)) {
        out.write(_symbols[cmd]);
        continue;
      }
      if (cmd == ' ') {
        out.write(' ');
        continue;
      }
      out.write(cmd);
      continue;
    }
    if (c == '^' || c == '_') {
      final (String body, int i1) = _latexGroup(src, i + 1);
      out.write(_scripted(latexToText(body), c == '_'));
      i = i1;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Converts \( … \), \[ … \] and $$ … $$ spans into converted text.
String convertMath(String text) {
  // Adjacent raw strings keep every segment from ending on a
  // backslash (illegal in Dart): r'\\' r'\(' == regex \\ \( — a
  // literal backslash followed by a literal '('.
  final RegExp inlineRe =
      RegExp(r'\\' r'\(' r'([\s\S]*?)' r'\\' r'\)');
  final RegExp displayRe =
      RegExp(r'\\' r'\[' r'([\s\S]*?)' r'\\' r'\]');
  final RegExp dollarRe = RegExp(r'\$\$?([\s\S]*?)\$\$?');
  return text
      .replaceAllMapped(inlineRe, (Match m) => latexToText(m.group(1)!))
      .replaceAllMapped(displayRe, (Match m) => latexToText(m.group(1)!))
      .replaceAllMapped(dollarRe, (Match m) => latexToText(m.group(1)!));
}

// ------------------------------------------------------------------ HTML

enum _TokKind { text, open, close }

class _Tok {
  _Tok.text(this.text)
      : kind = _TokKind.text,
        tag = '',
        attrs = const <String, String>{};
  _Tok.open(this.tag, this.attrs) : kind = _TokKind.open, text = '';
  _Tok.close(this.tag) : kind = _TokKind.close, text = '', attrs = const {};

  final _TokKind kind;
  final String tag;
  final String text;
  final Map<String, String> attrs;
}

final RegExp _tagRe = RegExp(
  r'<(/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[a-zA-Z-]+(?:\s*=\s*("[^"]*"|'
  "'[^']*'"
  r'|[^\s>]+))?)*)\s*/?>|([^<]+)',
);

List<_Tok> _tokenize(String html) {
  // HTML5 rule: a '<' not opening a tag is literal text.
  final String src = html.replaceAll(RegExp(r'<(?![a-zA-Z/!])'), '&lt;');
  final List<_Tok> toks = <_Tok>[];
  for (final RegExpMatch m in _tagRe.allMatches(src)) {
    final String? text = m.group(5);
    if (text != null) {
      toks.add(_Tok.text(text));
      continue;
    }
    final String tag = m.group(2)!.toLowerCase();
    if (m.group(1)!.isNotEmpty) {
      toks.add(_Tok.close(tag));
      continue;
    }
    final Map<String, String> attrs = <String, String>{};
    final String rawAttrs = m.group(3) ?? '';
    final RegExp attrRe = RegExp(
      r'([a-zA-Z-]+)(?:\s*=\s*("[^"]*)"|'
      "'([^']*)'"
      r'|([^\s>]+))?',
    );
    for (final RegExpMatch am in attrRe.allMatches(rawAttrs)) {
      final String key = am.group(1)!.toLowerCase();
      String? v = am.group(2) ?? am.group(3) ?? am.group(4);
      v ??= '';
      if (v.length >= 2 && ((v.startsWith('"') && v.endsWith('"')) ||
          (v.startsWith("'") && v.endsWith("'")))) {
        v = v.substring(1, v.length - 1);
      }
      attrs[key] = v;
    }
    toks.add(_Tok.open(tag, attrs));
  }
  return toks;
}

const Set<String> _voidTags = <String>{
  'br', 'img', 'hr', 'input', 'meta', 'link',
};

const Set<String> _dropTags = <String>{
  'script', 'style', 'iframe', 'object', 'embed', 'form', 'head', 'title',
  'svg', 'video', 'audio', 'source',
};

class _Parser {
  final List<InlineSpan> spans = <InlineSpan>[];

  void _addText(String raw, TextStyle style) {
    final String text = convertMath(decodeEntities(raw));
    if (text.isEmpty) return;
    spans.add(TextSpan(text: text, style: style));
  }

  /// Block-level: '\n' before the element's content, mimicking margins.
  static const Set<String> _blockTags = <String>{
    'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'table', 'tr', 'li',
    'blockquote', 'pre', 'ul', 'ol', 'figure', 'figcaption', 'center', 'hr',
  };

  void _newline() {
    spans.add(const TextSpan(text: '\n'));
  }

  /// Parses from `toks[i]` (an open tag). Returns the index AFTER the
  /// element's matching close tag.
  int parse(List<_Tok> toks, int i, TextStyle style) {
    final _Tok tok = toks[i];
    final String tag = tok.tag;
    if (tag == 'br') {
      _newline();
      return i + 1;
    }
    if (tag == 'img') {
      final String src = tok.attrs['src'] ?? '';
      if (src.isNotEmpty) _addText('[figure]', style);
      return i + 1;
    }
    if (tag == 'li') {
      _addText('\u2022 ', style);
    } else if (_blockTags.contains(tag)) {
      _newline();
    }

    TextStyle inner = style;
    if (tag == 'sub' || tag == 'sup') {
      inner = style.copyWith(fontSize: (style.fontSize ?? 14) * 0.72);
    } else if (tag == 'th') {
      inner = style.copyWith(fontWeight: FontWeight.w700);
    }

    int j = i + 1;
    final List<InlineSpan> children = <InlineSpan>[];
    final List<InlineSpan> swap = spans.toList();
    spans.clear();
    for (; j < toks.length; j++) {
      final _Tok t = toks[j];
      if (t.kind == _TokKind.close && t.tag == tag) {
        j++;
        break;
      }
      if (t.kind == _TokKind.text) {
        _addText(t.text, inner);
        continue;
      }
      if (t.kind == _TokKind.open) {
        if (_voidTags.contains(t.tag)) {
          parse(toks, j, inner);
          continue;
        }
        if (_dropTags.contains(t.tag)) {
          int depth = 1;
          j++;
          for (; j < toks.length && depth > 0; j++) {
            final _Tok d = toks[j];
            if (d.kind == _TokKind.open && d.tag == t.tag) {
              depth++;
            } else if (d.kind == _TokKind.close && d.tag == t.tag) {
              depth--;
            }
          }
          j--;
          continue;
        }
        j = parse(toks, j, inner) - 1;
        continue;
      }
    }
    children.addAll(spans);
    spans
      ..clear()
      ..addAll(swap);

    if (tag == 'sub' || tag == 'sup') {
      // unicode-ify plain digit content; otherwise keep smaller font text
      final String plain = children
          .whereType<TextSpan>()
          .map((TextSpan s) => s.text ?? '')
          .join();
      if (children.length == 1 && children.first is TextSpan) {
        final String mapped = _scripted(plain, tag == 'sub');
        if (mapped != plain || plain.length == 1) {
          spans.add(TextSpan(text: mapped, style: style));
          if (_blockTags.contains(tag)) _newline();
          return j;
        }
      }
      spans.add(
        WidgetSpan(
          alignment: tag == 'sup'
              ? PlaceholderAlignment.aboveBaseline
              : PlaceholderAlignment.belowBaseline,
          child: Transform.translate(
            offset: Offset(0, tag == 'sub' ? 2.5 : -3.5),
            child: Text(plain, style: inner),
          ),
        ),
      );
      if (_blockTags.contains(tag)) _newline();
      return j;
    }
    spans.addAll(children);
    if (tag == 'td' || tag == 'th') {
      // table cells flow inline; keep a visible column gap
      spans.add(const TextSpan(text: '  '));
    }
    if (_blockTags.contains(tag)) _newline();
    return j;
  }
}

/// Renders a question stem / option / explanation into inline spans.
List<InlineSpan> buildQuestionSpans(String html, TextStyle base) {
  if (html.isEmpty) return <InlineSpan>[];
  final _Parser p = _Parser();
  final List<_Tok> toks = _tokenize(html);
  int i = 0;
  while (i < toks.length) {
    final _Tok t = toks[i];
    if (t.kind == _TokKind.text) {
      p._addText(t.text, base);
      i++;
      continue;
    }
    if (t.kind == _TokKind.open) {
      if (_voidTags.contains(t.tag) || t.tag == 'img') {
        p.parse(toks, i, base);
        i++;
        continue;
      }
      if (_dropTags.contains(t.tag)) {
        int depth = 1;
        i++;
        for (; i < toks.length && depth > 0; i++) {
          final _Tok d = toks[i];
          if (d.kind == _TokKind.open && d.tag == t.tag) {
            depth++;
          } else if (d.kind == _TokKind.close && d.tag == t.tag) {
            depth--;
          }
        }
        continue;
      }
      i = p.parse(toks, i, base);
      continue;
    }
    i++; // stray close tag
  }
  return p.spans;
}

/// Rich, self-contained question text (HTML + LaTeX aware).
class QuestionText extends StatelessWidget {
  const QuestionText(
    this.text, {
    super.key,
    this.style = const TextStyle(),
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final TextStyle base =
        (style ?? const TextStyle()).copyWith(height: 1.45);
    if (!text.contains('<')) {
      // plain text (possibly with LaTeX): keep line breaks
      final String plain = convertMath(decodeEntities(text)).replaceAll('\r\n', '\n');
      return Text(
        plain,
        style: base,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    return RichText(
      text: TextSpan(
        children: buildQuestionSpans(text, base),
        style: base,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
