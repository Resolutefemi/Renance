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
  // 2026-10-20 pass: the 18 glyphs the founder's screens hit as EMPTY
  // WHITE BOXES (assignment = the university Courses tile,
  // import_contacts = the Notes tile, rate_review = the Review tile)
  // plus the rest of the web vocabulary the old subset dropped.
  // Codepoints from the official MaterialSymbolsOutlined.codepoints.
  'ac_unit': IconData(0xeb3b, fontFamily: 'MaterialSymbolsOutlined'),
  'add_circle': IconData(0xe990, fontFamily: 'MaterialSymbolsOutlined'),
  'alarm_off': IconData(0xe857, fontFamily: 'MaterialSymbolsOutlined'),
  'assignment': IconData(0xe85d, fontFamily: 'MaterialSymbolsOutlined'),
  'avg_time': IconData(0xf813, fontFamily: 'MaterialSymbolsOutlined'),
  'backspace': IconData(0xe14a, fontFamily: 'MaterialSymbolsOutlined'),
  'brightness_medium': IconData(0xe1ae, fontFamily: 'MaterialSymbolsOutlined'),
  'chat': IconData(0xe0c9, fontFamily: 'MaterialSymbolsOutlined'),
  'diversity_3': IconData(0xf8d9, fontFamily: 'MaterialSymbolsOutlined'),
  'drive_file_move': IconData(0xe9a1, fontFamily: 'MaterialSymbolsOutlined'),
  'expand_less': IconData(0xe5ce, fontFamily: 'MaterialSymbolsOutlined'),
  'import_contacts': IconData(0xe0e0, fontFamily: 'MaterialSymbolsOutlined'),
  'memory': IconData(0xe322, fontFamily: 'MaterialSymbolsOutlined'),
  'play_circle': IconData(0xe1c4, fontFamily: 'MaterialSymbolsOutlined'),
  'rate_review': IconData(0xe560, fontFamily: 'MaterialSymbolsOutlined'),
  'restart_alt': IconData(0xf053, fontFamily: 'MaterialSymbolsOutlined'),
  'right_panel_open': IconData(0xf704, fontFamily: 'MaterialSymbolsOutlined'),
  'table_view': IconData(0xf1be, fontFamily: 'MaterialSymbolsOutlined'),
  'upload': IconData(0xf09b, fontFamily: 'MaterialSymbolsOutlined'),
  'access_time_filled': IconData(0xefd6, fontFamily: 'MaterialSymbolsOutlined'),
  'account_balance': IconData(0xe84f, fontFamily: 'MaterialSymbolsOutlined'),
  'account_tree': IconData(0xe97a, fontFamily: 'MaterialSymbolsOutlined'),
  'add': IconData(0xe145, fontFamily: 'MaterialSymbolsOutlined'),
  'admin_panel_settings': IconData(0xef3d, fontFamily: 'MaterialSymbolsOutlined'),
  'agriculture': IconData(0xea79, fontFamily: 'MaterialSymbolsOutlined'),
  'alternate_email': IconData(0xe0e6, fontFamily: 'MaterialSymbolsOutlined'),
  'apartment': IconData(0xea40, fontFamily: 'MaterialSymbolsOutlined'),
  'apps': IconData(0xe5c3, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_back': IconData(0xe5c4, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_back_ios_new': IconData(0xe2ea, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_downward': IconData(0xe5db, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_drop_down': IconData(0xe5c5, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_forward': IconData(0xe5c8, fontFamily: 'MaterialSymbolsOutlined'),
  'arrow_upward': IconData(0xe5d8, fontFamily: 'MaterialSymbolsOutlined'),
  'auto_awesome': IconData(0xe65f, fontFamily: 'MaterialSymbolsOutlined'),
  'auto_stories': IconData(0xe666, fontFamily: 'MaterialSymbolsOutlined'),
  'badge': IconData(0xea67, fontFamily: 'MaterialSymbolsOutlined'),
  'bar_chart': IconData(0xe26b, fontFamily: 'MaterialSymbolsOutlined'),
  'battery_1_bar': IconData(0xf09c, fontFamily: 'MaterialSymbolsOutlined'),
  'battery_charging_full': IconData(0xe1a3, fontFamily: 'MaterialSymbolsOutlined'),
  'bedtime': IconData(0xf159, fontFamily: 'MaterialSymbolsOutlined'),
  'biotech': IconData(0xea3a, fontFamily: 'MaterialSymbolsOutlined'),
  'block': IconData(0xf08c, fontFamily: 'MaterialSymbolsOutlined'),
  'bolt': IconData(0xea0b, fontFamily: 'MaterialSymbolsOutlined'),
  'book': IconData(0xe86e, fontFamily: 'MaterialSymbolsOutlined'),
  'bookmark': IconData(0xe8e7, fontFamily: 'MaterialSymbolsOutlined'),
  'calculate': IconData(0xea5f, fontFamily: 'MaterialSymbolsOutlined'),
  'calendar_month': IconData(0xebcc, fontFamily: 'MaterialSymbolsOutlined'),
  'campaign': IconData(0xef49, fontFamily: 'MaterialSymbolsOutlined'),
  'cancel': IconData(0xe888, fontFamily: 'MaterialSymbolsOutlined'),
  'category': IconData(0xe72c, fontFamily: 'MaterialSymbolsOutlined'),
  'celebration': IconData(0xea65, fontFamily: 'MaterialSymbolsOutlined'),
  'chat_bubble': IconData(0xe0cb, fontFamily: 'MaterialSymbolsOutlined'),
  'check': IconData(0xe668, fontFamily: 'MaterialSymbolsOutlined'),
  'check_circle': IconData(0xf0be, fontFamily: 'MaterialSymbolsOutlined'),
  'checkroom': IconData(0xf19e, fontFamily: 'MaterialSymbolsOutlined'),
  'chevron_left': IconData(0xe5cb, fontFamily: 'MaterialSymbolsOutlined'),
  'chevron_right': IconData(0xe5cc, fontFamily: 'MaterialSymbolsOutlined'),
  'child_care': IconData(0xeb41, fontFamily: 'MaterialSymbolsOutlined'),
  'church': IconData(0xeaae, fontFamily: 'MaterialSymbolsOutlined'),
  'circle': IconData(0xef4a, fontFamily: 'MaterialSymbolsOutlined'),
  'close': IconData(0xe5cd, fontFamily: 'MaterialSymbolsOutlined'),
  'cloud_download': IconData(0xe2c0, fontFamily: 'MaterialSymbolsOutlined'),
  'cloud_off': IconData(0xe2c1, fontFamily: 'MaterialSymbolsOutlined'),
  'cloud_sync': IconData(0xeb5a, fontFamily: 'MaterialSymbolsOutlined'),
  'co_present': IconData(0xeaf0, fontFamily: 'MaterialSymbolsOutlined'),
  'code': IconData(0xe86f, fontFamily: 'MaterialSymbolsOutlined'),
  'collections_bookmark': IconData(0xe431, fontFamily: 'MaterialSymbolsOutlined'),
  'computer': IconData(0xe31e, fontFamily: 'MaterialSymbolsOutlined'),
  'content_copy': IconData(0xe14d, fontFamily: 'MaterialSymbolsOutlined'),
  'create_new_folder': IconData(0xe2cc, fontFamily: 'MaterialSymbolsOutlined'),
  'dark_mode': IconData(0xe51c, fontFamily: 'MaterialSymbolsOutlined'),
  'dashboard': IconData(0xe871, fontFamily: 'MaterialSymbolsOutlined'),
  'delete': IconData(0xe92e, fontFamily: 'MaterialSymbolsOutlined'),
  'delete_forever': IconData(0xe92b, fontFamily: 'MaterialSymbolsOutlined'),
  'description': IconData(0xe873, fontFamily: 'MaterialSymbolsOutlined'),
  'devices_other': IconData(0xe337, fontFamily: 'MaterialSymbolsOutlined'),
  'diamond': IconData(0xead5, fontFamily: 'MaterialSymbolsOutlined'),
  'directions_run': IconData(0xe566, fontFamily: 'MaterialSymbolsOutlined'),
  'done_all': IconData(0xe877, fontFamily: 'MaterialSymbolsOutlined'),
  'download': IconData(0xf090, fontFamily: 'MaterialSymbolsOutlined'),
  'downloading': IconData(0xf001, fontFamily: 'MaterialSymbolsOutlined'),
  'eco': IconData(0xea35, fontFamily: 'MaterialSymbolsOutlined'),
  'edit': IconData(0xf097, fontFamily: 'MaterialSymbolsOutlined'),
  'edit_note': IconData(0xe745, fontFamily: 'MaterialSymbolsOutlined'),
  'edit_square': IconData(0xf88d, fontFamily: 'MaterialSymbolsOutlined'),
  'emoji_events': IconData(0xea23, fontFamily: 'MaterialSymbolsOutlined'),
  'emoji_objects': IconData(0xea24, fontFamily: 'MaterialSymbolsOutlined'),
  'error': IconData(0xf8b6, fontFamily: 'MaterialSymbolsOutlined'),
  'escalator_warning': IconData(0xf1ac, fontFamily: 'MaterialSymbolsOutlined'),
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
  'folder': IconData(0xe2c7, fontFamily: 'MaterialSymbolsOutlined'),
  'format_list_numbered': IconData(0xe242, fontFamily: 'MaterialSymbolsOutlined'),
  'forum': IconData(0xe8af, fontFamily: 'MaterialSymbolsOutlined'),
  'functions': IconData(0xe24a, fontFamily: 'MaterialSymbolsOutlined'),
  'gavel': IconData(0xe90e, fontFamily: 'MaterialSymbolsOutlined'),
  'gpp_good': IconData(0xf013, fontFamily: 'MaterialSymbolsOutlined'),
  'grade': IconData(0xf09a, fontFamily: 'MaterialSymbolsOutlined'),
  'grid_on': IconData(0xe3ec, fontFamily: 'MaterialSymbolsOutlined'),
  'grid_view': IconData(0xe9b0, fontFamily: 'MaterialSymbolsOutlined'),
  'group': IconData(0xea21, fontFamily: 'MaterialSymbolsOutlined'),
  'group_add': IconData(0xe7f0, fontFamily: 'MaterialSymbolsOutlined'),
  'groups': IconData(0xf233, fontFamily: 'MaterialSymbolsOutlined'),
  'headphones': IconData(0xf01f, fontFamily: 'MaterialSymbolsOutlined'),
  'healing': IconData(0xe3f3, fontFamily: 'MaterialSymbolsOutlined'),
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
  'library_books': IconData(0xe02f, fontFamily: 'MaterialSymbolsOutlined'),
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
  'mark_email_unread': IconData(0xf18a, fontFamily: 'MaterialSymbolsOutlined'),
  'medical_services': IconData(0xf109, fontFamily: 'MaterialSymbolsOutlined'),
  'meeting_room': IconData(0xeb4f, fontFamily: 'MaterialSymbolsOutlined'),
  'menu': IconData(0xe5d2, fontFamily: 'MaterialSymbolsOutlined'),
  'menu_book': IconData(0xea19, fontFamily: 'MaterialSymbolsOutlined'),
  'military_tech': IconData(0xea3f, fontFamily: 'MaterialSymbolsOutlined'),
  'more_horiz': IconData(0xe5d3, fontFamily: 'MaterialSymbolsOutlined'),
  'more_vert': IconData(0xe5d4, fontFamily: 'MaterialSymbolsOutlined'),
  'mosque': IconData(0xeab2, fontFamily: 'MaterialSymbolsOutlined'),
  'music_note': IconData(0xe405, fontFamily: 'MaterialSymbolsOutlined'),
  'newspaper': IconData(0xeb81, fontFamily: 'MaterialSymbolsOutlined'),
  'note_add': IconData(0xe89c, fontFamily: 'MaterialSymbolsOutlined'),
  'notifications': IconData(0xe7f5, fontFamily: 'MaterialSymbolsOutlined'),
  'notifications_active': IconData(0xe7f7, fontFamily: 'MaterialSymbolsOutlined'),
  'notifications_none': IconData(0xe7f5, fontFamily: 'MaterialSymbolsOutlined'),
  'offline_bolt': IconData(0xe932, fontFamily: 'MaterialSymbolsOutlined'),
  'open_in_new': IconData(0xe89e, fontFamily: 'MaterialSymbolsOutlined'),
  'palette': IconData(0xe40a, fontFamily: 'MaterialSymbolsOutlined'),
  'park': IconData(0xea63, fontFamily: 'MaterialSymbolsOutlined'),
  'pause_circle': IconData(0xe1a2, fontFamily: 'MaterialSymbolsOutlined'),
  'payments': IconData(0xef63, fontFamily: 'MaterialSymbolsOutlined'),
  'person': IconData(0xf0d3, fontFamily: 'MaterialSymbolsOutlined'),
  'person_add': IconData(0xea4d, fontFamily: 'MaterialSymbolsOutlined'),
  'person_off': IconData(0xe510, fontFamily: 'MaterialSymbolsOutlined'),
  'phonelink_lock': IconData(0xf2be, fontFamily: 'MaterialSymbolsOutlined'),
  'photo_camera': IconData(0xe412, fontFamily: 'MaterialSymbolsOutlined'),
  'picture_as_pdf': IconData(0xe415, fontFamily: 'MaterialSymbolsOutlined'),
  'play_arrow': IconData(0xe037, fontFamily: 'MaterialSymbolsOutlined'),
  'podcasts': IconData(0xf048, fontFamily: 'MaterialSymbolsOutlined'),
  'precision_manufacturing': IconData(0xf049, fontFamily: 'MaterialSymbolsOutlined'),
  'priority_high': IconData(0xe645, fontFamily: 'MaterialSymbolsOutlined'),
  'progress_activity': IconData(0xe9d0, fontFamily: 'MaterialSymbolsOutlined'),
  'psychology': IconData(0xea4a, fontFamily: 'MaterialSymbolsOutlined'),
  'public': IconData(0xe80b, fontFamily: 'MaterialSymbolsOutlined'),
  'push_pin': IconData(0xf10d, fontFamily: 'MaterialSymbolsOutlined'),
  'quiz': IconData(0xf04c, fontFamily: 'MaterialSymbolsOutlined'),
  'radio_button_checked': IconData(0xe837, fontFamily: 'MaterialSymbolsOutlined'),
  'radio_button_unchecked': IconData(0xe836, fontFamily: 'MaterialSymbolsOutlined'),
  'receipt_long': IconData(0xef6e, fontFamily: 'MaterialSymbolsOutlined'),
  'record_voice_over': IconData(0xe91f, fontFamily: 'MaterialSymbolsOutlined'),
  'redeem': IconData(0xe8f6, fontFamily: 'MaterialSymbolsOutlined'),
  'refresh': IconData(0xe5d5, fontFamily: 'MaterialSymbolsOutlined'),
  'remove': IconData(0xe15b, fontFamily: 'MaterialSymbolsOutlined'),
  'replay': IconData(0xe042, fontFamily: 'MaterialSymbolsOutlined'),
  'rocket_launch': IconData(0xeb9b, fontFamily: 'MaterialSymbolsOutlined'),
  'save': IconData(0xe161, fontFamily: 'MaterialSymbolsOutlined'),
  'savings': IconData(0xe2eb, fontFamily: 'MaterialSymbolsOutlined'),
  'schedule': IconData(0xefd6, fontFamily: 'MaterialSymbolsOutlined'),
  'school': IconData(0xe80c, fontFamily: 'MaterialSymbolsOutlined'),
  'science': IconData(0xea4b, fontFamily: 'MaterialSymbolsOutlined'),
  'search': IconData(0xef7a, fontFamily: 'MaterialSymbolsOutlined'),
  'search_off': IconData(0xea76, fontFamily: 'MaterialSymbolsOutlined'),
  'self_improvement': IconData(0xea78, fontFamily: 'MaterialSymbolsOutlined'),
  'send': IconData(0xe163, fontFamily: 'MaterialSymbolsOutlined'),
  'sentiment_satisfied': IconData(0xe813, fontFamily: 'MaterialSymbolsOutlined'),
  'settings': IconData(0xe8b8, fontFamily: 'MaterialSymbolsOutlined'),
  'share': IconData(0xe80d, fontFamily: 'MaterialSymbolsOutlined'),
  'shield': IconData(0xe9e0, fontFamily: 'MaterialSymbolsOutlined'),
  'shuffle': IconData(0xe043, fontFamily: 'MaterialSymbolsOutlined'),
  'signal_cellular_alt': IconData(0xe202, fontFamily: 'MaterialSymbolsOutlined'),
  'smart_toy': IconData(0xf06c, fontFamily: 'MaterialSymbolsOutlined'),
  'smartphone': IconData(0xe7ba, fontFamily: 'MaterialSymbolsOutlined'),
  'speed': IconData(0xe9e4, fontFamily: 'MaterialSymbolsOutlined'),
  'sports_esports': IconData(0xea28, fontFamily: 'MaterialSymbolsOutlined'),
  'sports_soccer': IconData(0xea2f, fontFamily: 'MaterialSymbolsOutlined'),
  'stairs': IconData(0xf1a9, fontFamily: 'MaterialSymbolsOutlined'),
  'star': IconData(0xf09a, fontFamily: 'MaterialSymbolsOutlined'),
  'stars': IconData(0xe8d0, fontFamily: 'MaterialSymbolsOutlined'),
  'stop': IconData(0xe047, fontFamily: 'MaterialSymbolsOutlined'),
  'storage': IconData(0xe1db, fontFamily: 'MaterialSymbolsOutlined'),
  'storefront': IconData(0xea12, fontFamily: 'MaterialSymbolsOutlined'),
  'style': IconData(0xe41d, fontFamily: 'MaterialSymbolsOutlined'),
  'subject': IconData(0xe8d2, fontFamily: 'MaterialSymbolsOutlined'),
  'sunny': IconData(0xe81a, fontFamily: 'MaterialSymbolsOutlined'),
  'support_agent': IconData(0xf0e2, fontFamily: 'MaterialSymbolsOutlined'),
  'swap_horiz': IconData(0xe8d4, fontFamily: 'MaterialSymbolsOutlined'),
  'swords': IconData(0xf889, fontFamily: 'MaterialSymbolsOutlined'),
  'sync': IconData(0xe627, fontFamily: 'MaterialSymbolsOutlined'),
  'target': IconData(0xe719, fontFamily: 'MaterialSymbolsOutlined'),
  'terminal': IconData(0xeb8e, fontFamily: 'MaterialSymbolsOutlined'),
  'thumb_up': IconData(0xf577, fontFamily: 'MaterialSymbolsOutlined'),
  'timeline': IconData(0xe922, fontFamily: 'MaterialSymbolsOutlined'),
  'timer': IconData(0xe425, fontFamily: 'MaterialSymbolsOutlined'),
  'timer_off': IconData(0xe426, fontFamily: 'MaterialSymbolsOutlined'),
  'touch_app': IconData(0xe913, fontFamily: 'MaterialSymbolsOutlined'),
  'track_changes': IconData(0xe8e1, fontFamily: 'MaterialSymbolsOutlined'),
  'translate': IconData(0xe8e2, fontFamily: 'MaterialSymbolsOutlined'),
  'travel_explore': IconData(0xe2db, fontFamily: 'MaterialSymbolsOutlined'),
  'trending_down': IconData(0xe8e3, fontFamily: 'MaterialSymbolsOutlined'),
  'trending_up': IconData(0xe8e5, fontFamily: 'MaterialSymbolsOutlined'),
  'trophy': IconData(0xea23, fontFamily: 'MaterialSymbolsOutlined'),
  'tune': IconData(0xe429, fontFamily: 'MaterialSymbolsOutlined'),
  'verified': IconData(0xef76, fontFamily: 'MaterialSymbolsOutlined'),
  'videocam': IconData(0xe04b, fontFamily: 'MaterialSymbolsOutlined'),
  'visibility': IconData(0xe8f4, fontFamily: 'MaterialSymbolsOutlined'),
  'visibility_off': IconData(0xe8f5, fontFamily: 'MaterialSymbolsOutlined'),
  'volume_up': IconData(0xe050, fontFamily: 'MaterialSymbolsOutlined'),
  'volunteer_activism': IconData(0xea70, fontFamily: 'MaterialSymbolsOutlined'),
  'warning': IconData(0xf083, fontFamily: 'MaterialSymbolsOutlined'),
  'water_drop': IconData(0xe798, fontFamily: 'MaterialSymbolsOutlined'),
  'wifi': IconData(0xe63e, fontFamily: 'MaterialSymbolsOutlined'),
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

/// An input-decorator-proof field prefix glyph: a fixed [box] hit area
/// with the glyph CENTERED inside it (plus a leading [leftInset] off
/// the field wall).
///
/// Founder report 2026-10-21 ("the icons inside the boxes is not well
/// positioned, look at the password icon"): the input decorator centres
/// the prefix CONSTRAINTS box, but a bare glyph [Text] parks at that
/// box's TOP-LEFT corner - at the founder's large system font the 20px
/// glyph rode the 48px box's top-left corner, visibly outside the well
/// (login email/password, picture 3). Centering the glyph inside a
/// fixed square keeps every field and search bar centred on the text
/// line at any text scale, on any device.
class MsFieldIcon extends StatelessWidget {
  const MsFieldIcon(
    this.name, {
    super.key,
    this.size = 20,
    this.color,
    this.fill = false,
    this.box = 44,
    this.leftInset = 12,
  });

  final String name;
  final double size;
  final Color? color;
  final bool fill;

  /// The fixed square hit area the glyph is centred inside. The input
  /// decorator can only grow this box, never un-centre the glyph.
  final double box;

  /// Leading room between the field wall and the glyph.
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: box,
      child: Padding(
        padding: EdgeInsets.only(left: leftInset),
        child: Center(
          child: MsIcon(name, size: size, fill: fill, color: color),
        ),
      ),
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
