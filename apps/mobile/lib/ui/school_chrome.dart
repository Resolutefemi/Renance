/// Shared chrome for the school workspace (founder directive
/// 2026-10-05): the top navbar carries the graduation-cap badge +
/// school name at the LEFT - the web portal's header, with the page
/// title riding underneath - and the menu moved from the bottom bar to
/// the RIGHT of the navbar on phones.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers.dart';
import '../models.dart';
import 'msymbols.dart';
import 'theme.dart';

/// Provided by the workspace shell: how a tab's navbar opens the full
/// page drawer, and whether the phone layout wants the menu icon at
/// all (the tablet rail carries every destination itself, so it hides
/// the menu). Pushed detail screens sit outside the shell and simply
/// get the navbar chrome without the menu icon.
class SchoolShellScope extends InheritedWidget {
  const SchoolShellScope({
    super.key,
    required this.openDrawer,
    required this.showMenu,
    required super.child,
  });

  final VoidCallback openDrawer;
  final bool showMenu;

  static SchoolShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SchoolShellScope>();

  @override
  bool updateShouldNotify(SchoolShellScope oldWidget) =>
      oldWidget.showMenu != showMenu;
}

/// The school workspace top navbar, the app twin of the web portal's
/// header: the amber graduation-cap badge + the school name at the
/// left (the page title rides underneath), and on phones the menu
/// button at the right edge - moved off the bottom bar.
PreferredSizeWidget schoolWorkspaceAppBar(
  BuildContext context, {
  required String pageTitle,
  List<Widget> actions = const <Widget>[],
}) {
  final SchoolShellScope? scope = SchoolShellScope.maybeOf(context);
  final SchoolContextModel? ctx =
      context.watch<SchoolController>().activeContext;
  final String schoolName = ctx?.school.name ?? 'School workspace';
  final bool hasSubtitle = pageTitle.isNotEmpty && pageTitle != schoolName;

  return AppBar(
    title: Row(
      children: <Widget>[
        Container(alignment: Alignment.center,
          
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC800), // amber-400 - the web badge
            borderRadius: BorderRadius.circular(8),
          ),
          child: const MsIcon(
            'school', // the graduation cap
            size: 18,
            color: Color(0xFF3B0764), // purple-900 glyph, like the web
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                schoolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (hasSubtitle)
                Text(
                  pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RenanceText.caption.copyWith(
                    color: context.textSecondary,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    actions: <Widget>[
      ...actions,
      if (scope?.showMenu ?? false)
        IconButton(
          icon: const MsIcon('menu', fill: true),
          tooltip: 'Menu',
          onPressed: scope!.openDrawer,
        ),
    ],
  );
}
