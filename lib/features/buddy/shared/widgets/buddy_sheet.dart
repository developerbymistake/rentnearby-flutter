import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../buddy_look.dart';

abstract final class BuddySheet {
  static Widget frame({
    required Widget child,
    String? art,
    Widget? avatar,
    String? title,
    String? subtitle,
    Widget? footer,
    ListingTone? tone,
    bool closeEnabled = true,
  }) =>
      SheetFrame(
        tone: tone ?? BuddyLook.teal,
        art: avatar == null ? art : null,
        title: avatar == null ? title : null,
        subtitle: avatar == null ? subtitle : null,
        footer: footer,
        closeEnabled: closeEnabled,
        child: avatar == null
            ? child
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: avatar),
                  if (title != null)
                    Padding(
                      padding: EdgeInsets.only(top: DS.s(10)),
                      child: Text(title, textAlign: TextAlign.center, style: Ink3D.text(21, FontWeight.w700, Ink3D.title, height: 1.3, letterSpacing: 0)),
                    ),
                  if (subtitle != null)
                    Padding(
                      padding: EdgeInsets.only(top: DS.s(2)),
                      child: Text(subtitle, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w600, BuddyLook.tealEnd, height: 1.5, letterSpacing: 0)),
                    ),
                  Gap.v(12),
                  child,
                ],
              ),
      );

  static Future<T?> show<T>(
    BuildContext context, {
    String? art,
    Widget? avatar,
    String? title,
    String? subtitle,
    required WidgetBuilder builder,
    Widget? footer,
    ListingTone? tone,
  }) =>
      SheetFrame.show<T>(
        context,
        builder: (c) => frame(art: art, avatar: avatar, title: title, subtitle: subtitle, footer: footer, tone: tone, child: builder(c)),
      );
}
