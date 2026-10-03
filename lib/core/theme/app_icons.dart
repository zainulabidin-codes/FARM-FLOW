import 'package:flutter/material.dart';

class AppIcons {
  static Widget cowHoof({double? size, Color? color}) {
    return ImageIcon(
      const AssetImage('assets/images/hoof-print.png'),
      size: size ?? 24,
      color: color,
    );
  }
}
