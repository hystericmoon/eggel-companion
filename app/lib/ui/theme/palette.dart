import 'package:flutter/material.dart';

import '../../settings/settings_store.dart';

/// One color theme: the accent that glows, and two aurora colors behind it.
class EggelPalette {
  const EggelPalette(this.name, this.accent, this.glow2, this.glow3);

  final String name;
  final Color accent;
  final Color glow2;
  final Color glow3;
}

const ember = EggelPalette(
  'Ember',
  Color(0xFFFF7A45),
  Color(0xFF7A5CFF),
  Color(0xFFE2418A),
);
const aqua = EggelPalette(
  'Aqua',
  Color(0xFF3DDCFF),
  Color(0xFF3B6BFF),
  Color(0xFF2EE6A6),
);
const violet = EggelPalette(
  'Violet',
  Color(0xFFA78BFA),
  Color(0xFFFF5C9A),
  Color(0xFF3B82F6),
);
const mint = EggelPalette(
  'Mint',
  Color(0xFF4ADE80),
  Color(0xFF14B8A6),
  Color(0xFFFACC15),
);
const rose = EggelPalette(
  'Rose',
  Color(0xFFFF5C8A),
  Color(0xFFFF9A45),
  Color(0xFF8B5CF6),
);

const allPalettes = [ember, aqua, violet, mint, rose];

/// Fixed surface colors shared by every theme.
const eggelBackground = Color(0xFF07080C);
const eggelText = Color(0xFFF4F4F6);
const eggelMuted = Color(0xFFA9ACBA);

/// Text drawn on top of the accent color.
const eggelOnAccent = Color(0xFF0A0B10);

/// Holds the chosen palette and remembers it in [settings] when given.
class ThemeController extends ChangeNotifier {
  ThemeController([EggelPalette initial = ember, this.settings])
    : _palette = _saved(settings) ?? initial;

  final AppSettings? settings;
  EggelPalette _palette;
  EggelPalette get palette => _palette;

  static EggelPalette? _saved(AppSettings? s) {
    final name = s?.get<String>('theme');
    for (final p in allPalettes) {
      if (p.name == name) return p;
    }
    return null;
  }

  void select(EggelPalette p) {
    if (p == _palette) return;
    _palette = p;
    settings?.set('theme', p.name);
    notifyListeners();
  }
}
