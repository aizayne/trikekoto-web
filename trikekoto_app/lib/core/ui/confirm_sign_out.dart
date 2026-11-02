import 'package:flutter/material.dart';

import 'locale_controller.dart';

/// Asks before signing out. The button sits among other app bar icons, where a
/// stray tap is easy and getting back in can mean waiting for a code.
Future<bool> confirmSignOut(BuildContext context) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(context.l.signOutQuestion),
      content: Text(context.l.signOutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: Text(context.l.signOutNo),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: Text(context.l.signOut),
        ),
      ],
    ),
  );
  return sure ?? false;
}
