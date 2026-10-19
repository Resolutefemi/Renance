/// Material Symbols Outlined - the exact icon font the Renance website
/// renders its UI with (globals.css: font-variation-settings 'FILL' 0,
/// 'wght' 600, 'GRAD' 0, 'opsz' 24), subset to the app's icon
/// vocabulary and loaded as a variable font so [MsIcon.fill] can switch
/// to the solid glyphs the web paints inside filled buttons.
///
/// Every codepoint comes from the official Material Symbols codepoints
/// file; the names match the web's material-symbols-outlined ligature
/// names one-to-one, so a tile that reads `sports_esports` on the web
/// reads MsIcons.sports_esports here.
library;

import 'package:flutter/material.dart';

/// The codepoint table. Look up by the web's ligature name.
const Map<String, IconData> msCodepoints = <String, IconData>{
  'ac_unit': IconData(0xeb3b, fontFamily: 'MaterialSymbolsOutlined'),
  'account_balance': IconData(0xe84f, fontFamily: 'MaterialSymbolsOutlined'),
  'add': IconData(0xe145, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_back': IconData(0xe5c4, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_forward': IconData(0xe5c8, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_upward': IconData(0xe5d8, fontFamily: 'MaterialSymbolsOutlined'),
  'auto_awesome': IconData(0xe65f, fontFamily: 'MaterialSymbolsOutlined'),
  'auto_stories': IconData(0xe666, fontFamily: 'MaterialSymbolsOutlined'),
  'bedtime': IconData(0xf159, fontFamily: 'MaterialSymbolsOutlined'),
  'bolt': IconData(0xea0b, fontFamily: 'MaterialSymbolsOutlined'),
  'bookmark': IconData(0xe8e7, fontFamily: 'MaterialSymbolsOutlined'),
  'calculate': IconData(0xea5f, fontFamily: 'MaterialSymbolsOutlined'),
  'calendar_month': IconData(0xebcc, fontFamily: 'MaterialSymbolsOutlined'),
  'campaign': IconData(0xef49, fontFamily: 'MaterialSymbolsOutlined'),
  'category': IconData(0xe72c, fontFamily: 'MaterialSymbolsOutlined'),
  'celebration': IconData(0xea65, fontFamily: 'MaterialSymbolsOutlined'),
  'chat_bubble': IconData(0xe0cb, fontFamily: 'MaterialSymbolsOutlined'),
  'check': IconData(0xe668, fontFamily: 'MaterialSymbolsOutlined'),
  'check_circle': IconData(0xf0be, fontFamily: 'MaterialSymbolsOutlined'),
  'chevron_right': IconData(0xe5cc, fontFamily: 'MaterialSymbolsOutlined'),
  'circle': IconData(0xef4a, fontFamily: 'MaterialSymbolsOutlined'),
  'close': IconData(0xe5cd, fontFamily: 'MaterialSymbolsOutlined'),
  'cloud_off': IconData(0xe2c1, fontFamily: 'MaterialSymbolsOutlined'),
  'collections_bookmark': IconData(0xe431, fontFamily: 'MaterialSymbolsOutlined'),
  'content_copy': IconData(0xe14d, fontFamily: 'MaterialSymbolsOutlined'),
  'dark_mode': IconData(0xe51c, fontFamily: 'MaterialSymbolsOutlined'),
  'delete': IconData(0xe92e, fontFamily: 'MaterialSymbolsOutlined'),
  'description': IconData(0xe873, fontFamily: 'MaterialSymbolsOutlined'),
  'diamond': IconData(0xead5, fontFamily: 'MaterialSymbolsOutlined'),
  'done_all': IconData(0xe877, fontFamily: 'MaterialSymbolsOutlined'),
  'download': IconData(0xf090, fontFamily: 'MaterialSymbolsOutlined'),
  'eco': IconData(0xea35, fontFamily: 'MaterialSymbolsOutlined'),
  'edit_note': IconData(0xe745, fontFamily: 'MaterialSymbolsOutlined'),
  'emoji_events': IconData(0xea23, fontFamily: 'MaterialSymbolsOutlined'),
  'emoji_objects': IconData(0xea24, fontFamily: 'MaterialSymbolsOutlined'),
  'error': IconData(0xf8b6, fontFamily: 'MaterialSymbolsOutlined'),
  'event': IconData(0xe878, fontFamily: 'MaterialSymbolsOutlined'),
  'event_note': IconData(0xe616, fontFamily: 'MaterialSymbolsOutlined'),
  'event_repeat': IconData(0xeb7b, fontFamily: 'MaterialSymbolsOutlined'),
  'expand_more': IconData(0xe5cf, fontFamily: 'MaterialSymbolsOutlined'),
  'fact_check': IconData(0xf0c5, fontFamily: 'MaterialSymbolsOutlined'),
  'favorite': IconData(0xe87e, fontFamily: 'MaterialSymbolsOutlined'),
  'favorite_border': IconData(0xe87e, fontFamily: 'MaterialSymbolsOutlined'),
  'fitness_center': IconData(0xeb43, fontFamily: 'MaterialSymbolsOutlined'),
  'flag': IconData(0xf0c6, fontFamily: 'MaterialSymbolsOutlined'),
  'flare': IconData(0xe3e4, fontFamily: 'MaterialSymbolsOutlined'),
  'forum': IconData(0xe8af, fontFamily: 'MaterialSymbolsOutlined'),
  'functions': IconData(0xe24a, fontFamily: 'MaterialSymbolsOutlined'),
  'grade': IconData(0xf09a, fontFamily: 'MaterialSymbolsOutlined'),
  'group': IconData(0xea21, fontFamily: 'MaterialSymbolsOutlined'),
  'headphones': IconData(0xf01f, fontFamily: 'MaterialSymbolsOutlined'),
  'help': IconData(0xe8fd, fontFamily: 'MaterialSymbolsOutlined'),
  'history': IconData(0xe8b3, fontFamily: 'MaterialSymbolsOutlined'),
  'history_edu': IconData(0xea3e, fontFamily: 'MaterialSymbolsOutlined'),
  'home': IconData(0xe9b2, fontFamily: 'MaterialSymbolsOutlined'),
  'hourglass_top': IconData(0xea5b, fontFamily: 'MaterialSymbolsOutlined'),
  'image': IconData(0xe3f4, fontFamily: 'MaterialSymbolsOutlined'),
  'info': IconData(0xe88e, fontFamily: 'MaterialSymbolsOutlined'),
  'insights': IconData(0xf092, fontFamily: 'MaterialSymbolsOutlined'),
  'inventory_2': IconData(0xe1a1, fontFamily: 'MaterialSymbolsOutlined'),
  'ios_share': IconData(0xe6b8, fontFamily: 'MaterialSymbolsOutlined'),
  'keyboard_arrow_down': IconData(0xe313, fontFamily: 'MaterialSymbolsOutlined'),
  'keyboard_arrow_right': IconData(0xe315, fontFamily: 'MaterialSymbolsOutlined'),
  'keyboard_arrow_up': IconData(0xe316, fontFamily: 'MaterialSymbolsOutlined'),
  'language': IconData(0xea07, fontFamily: 'MaterialSymbolsOutlined'),
  'laptop_mac': IconData(0xe320, fontFamily: 'MaterialSymbolsOutlined'),
  'leaderboard': IconData(0xf20c, fontFamily: 'MaterialSymbolsOutlined'),
  'light_mode': IconData(0xe518, fontFamily: 'MaterialSymbolsOutlined'),
  'lightbulb': IconData(0xe90f, fontFamily: 'MaterialSymbolsOutlined'),
  'link': IconData(0xe250, fontFamily: 'MaterialSymbolsOutlined'),
  'local_fire_department': IconData(0xef55, fontFamily: 'MaterialSymbolsOutlined'),
  'local_library': IconData(0xe54b, fontFamily: 'MaterialSymbolsOutlined'),
  'lock': IconData(0xe899, fontFamily: 'MaterialSymbolsOutlined'),
  'lock_open': IconData(0xe898, fontFamily: 'MaterialSymbolsOutlined'),
  'logout': IconData(0xe9ba, fontFamily: 'MaterialSymbolsOutlined'),
  'mail': IconData(0xe159, fontFamily: 'MaterialSymbolsOutlined'),
  'mark_email_read': IconData(0xf18c, fontFamily: 'MaterialSymbolsOutlined'),
  'menu_book': IconData(0xea19, fontFamily: 'MaterialSymbolsOutlined'),
  'military_tech': IconData(0xea3f, fontFamily: 'MaterialSymbolsOutlined'),
  'more_horiz': IconData(0xe5d3, fontFamily: 'MaterialSymbolsOutlined'),
  'more_vert': IconData(0xe5d4, fontFamily: 'MaterialSymbolsOutlined'),
  'newspaper': IconData(0xeb81, fontFamily: 'MaterialSymbolsOutlined'),
  'notifications': IconData(0xe7f5, fontFamily: 'MaterialSymbolsOutlined'),
  'open_in_new': IconData(0xe89e, fontFamily: 'MaterialSymbolsOutlined'),
  'palette': IconData(0xe40a, fontFamily: 'MaterialSymbolsOutlined'),
  'park': IconData(0xea63, fontFamily: 'MaterialSymbolsOutlined'),
  'pause_circle': IconData(0xe1a2, fontFamily: 'MaterialSymbolsOutlined'),
  'person': IconData(0xf0d3, fontFamily: 'MaterialSymbolsOutlined'),
  'person_add': IconData(0xea4d, fontFamily: 'MaterialSymbolsOutlined'),
  'person_off': IconData(0xe510, fontFamily: 'MaterialSymbolsOutlined'),
  'photo_camera': IconData(0xe412, fontFamily: 'MaterialSymbolsOutlined'),
  'play_arrow': IconData(0xe037, fontFamily: 'MaterialSymbolsOutlined'),
  'podcasts': IconData(0xf048, fontFamily: 'MaterialSymbolsOutlined'),
  'precision_manufacturing': IconData(0xf049, fontFamily: 'MaterialSymbolsOutlined'),
  'priority_high': IconData(0xe645, fontFamily: 'MaterialSymbolsOutlined'),
  'progress_activity': IconData(0xe9d0, fontFamily: 'MaterialSymbolsOutlined'),
  'psychology': IconData(0xea4a, fontFamily: 'MaterialSymbolsOutlined'),
  'quiz': IconData(0xf04c, fontFamily: 'MaterialSymbolsOutlined'),
  'redeem': IconData(0xe8f6, fontFamily: 'MaterialSymbolsOutlined'),
  'refresh': IconData(0xe5d5, fontFamily: 'MaterialSymbolsOutlined'),
  'remove': IconData(0xe15b, fontFamily: 'MaterialSymbolsOutlined'),
  'rocket_launch': IconData(0xeb9b, fontFamily: 'MaterialSymbolsOutlined'),
  'schedule': IconData(0xefd6, fontFamily: 'MaterialSymbolsOutlined'),
  'school': IconData(0xe80c, fontFamily: 'MaterialSymbolsOutlined'),
  'science': IconData(0xea4b, fontFamily: 'MaterialSymbolsOutlined'),
  'search': IconData(0xef7a, fontFamily: 'MaterialSymbolsOutlined'),
  'self_improvement': IconData(0xea78, fontFamily: 'MaterialSymbolsOutlined'),
  'send': IconData(0xe163, fontFamily: 'MaterialSymbolsOutlined'),
  'sentiment_satisfied': IconData(0xe813, fontFamily: 'MaterialSymbolsOutlined'),
  'settings': IconData(0xe8b8, fontFamily: 'MaterialSymbolsOutlined'),
  'share': IconData(0xe80d, fontFamily: 'MaterialSymbolsOutlined'),
  'shield': IconData(0xe9e0, fontFamily: 'MaterialSymbolsOutlined'),
  'smart_toy': IconData(0xf06c, fontFamily: 'MaterialSymbolsOutlined'),
  'speed': IconData(0xe9e4, fontFamily: 'MaterialSymbolsOutlined'),
  'sports_esports': IconData(0xea28, fontFamily: 'MaterialSymbolsOutlined'),
  'star': IconData(0xf09a, fontFamily: 'MaterialSymbolsOutlined'),
  'stars': IconData(0xe8d0, fontFamily: 'MaterialSymbolsOutlined'),
  'storefront': IconData(0xea12, fontFamily: 'MaterialSymbolsOutlined'),
  'sunny': IconData(0xe81a, fontFamily: 'MaterialSymbolsOutlined'),
  'swords': IconData(0xf889, fontFamily: 'MaterialSymbolsOutlined'),
  'target': IconData(0xe719, fontFamily: 'MaterialSymbolsOutlined'),
  'thumb_up': IconData(0xf577, fontFamily: 'MaterialSymbolsOutlined'),
  'timer': IconData(0xe425, fontFamily: 'MaterialSymbolsOutlined'),
  'translate': IconData(0xe8e2, fontFamily: 'MaterialSymbolsOutlined'),
  'trophy': IconData(0xea23, fontFamily: 'MaterialSymbolsOutlined'),
  'tune': IconData(0xe429, fontFamily: 'MaterialSymbolsOutlined'),
  'verified': IconData(0xef76, fontFamily: 'MaterialSymbolsOutlined'),
  'videocam': IconData(0xe04b, fontFamily: 'MaterialSymbolsOutlined'),
  'visibility': IconData(0xe8f4, fontFamily: 'MaterialSymbolsOutlined'),
  'visibility_off': IconData(0xe8f5, fontFamily: 'MaterialSymbolsOutlined'),
  'volunteer_activism': IconData(0xea70, fontFamily: 'MaterialSymbolsOutlined'),
  'warning': IconData(0xf083, fontFamily: 'MaterialSymbolsOutlined'),
  'water_drop': IconData(0xe798, fontFamily: 'MaterialSymbolsOutlined'),
  'wifi_off': IconData(0xe648, fontFamily: 'MaterialSymbolsOutlined'),
  'workspace_premium': IconData(0xe7af, fontFamily: 'MaterialSymbolsOutlined'),
};

/// One Material Symbols glyph at the website's default weight (600).
///
/// [fill] mirrors the web's .fill-current rule (FILL 1): solid white
/// icons inside filled action buttons. [wght] defaults to 600 like the
/// web; the learn tiles bump to 700 where globals.css does.
class MsIcon extends StatelessWidget {
  const MsIcon(
    this.name, {
    super.key,
    this.size = 22,
    this.fill = false,
    this.wght = 600,
    this.grad = 0,
    this.opsz = 24,
    this.color,
  });

  final String name;
  final double size;
  final bool fill;
  final double wght;
  final double grad;
  final double opsz;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconData? data = msCodepoints[name];
    if (data == null) {
      return SizedBox.square(dimension: size);
    }
    return Text(
      String.fromCharCode(data.codePoint),
      style: MsIcon.style(
        fill: fill,
        wght: wght,
        grad: grad,
        opsz: opsz,
        fontSize: size,
        color: color,
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
    );
  }

  /// The TextStyle carrying the variation axes - used when the glyph
  /// rides inside a Text.rich (letter chips, button labels).
  static TextStyle style({
    bool fill = false,
    double wght = 600,
    double grad = 0,
    double opsz = 24,
    double fontSize = 22,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'MaterialSymbolsOutlined',
      fontSize: fontSize,
      color: color,
      fontVariations: <FontVariation>[
        FontVariation('FILL', fill ? 1 : 0),
        FontVariation('wght', wght),
        FontVariation('GRAD', grad),
        FontVariation('opsz', opsz),
      ],
    );
  }
}

/// Renders [name] with the FILL/wght variation axes applied - the icon
/// twin of MsIcon for RichText contexts.
class MsIconSpan extends WidgetSpan {
  MsIconSpan(
    String name, {
    double size = 22,
    bool fill = false,
    double wght = 600,
    Color? color,
  }) : super(
          alignment: PlaceholderAlignment.middle,
          child: _MsVariationalIcon(
            name: name,
            size: size,
            fill: fill,
            wght: wght,
            color: color,
          ),
        );
}

class _MsVariationalIcon extends StatelessWidget {
  const _MsVariationalIcon({
    required this.name,
    required this.size,
    required this.fill,
    required this.wght,
    this.color,
  });

  final String name;
  final double size;
  final bool fill;
  final double wght;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final IconData? data = msCodepoints[name];
    if (data == null) return SizedBox.square(dimension: size);
    return Text(
      String.fromCharCode(data.codePoint),
      style: MsIcon.style(
        fill: fill,
        wght: wght,
        fontSize: size,
        color: color,
      ),
    );
  }
}
