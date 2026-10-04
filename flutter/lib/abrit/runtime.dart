import 'package:flutter/material.dart';
import 'dart:io';
import 'smoke.dart';
import '../consts.dart';
import '../models/platform_model.dart';

Locale abritLocale() {
  if (abritSmokeDirectory != null) {
    return Locale(Platform.environment['ABRIT_UI_SMOKE_LANG'] ?? 'en');
  }
  final saved = bind.mainGetLocalOption(key: kCommConfKeyLang);
  final language = (saved.isEmpty ? localeName : saved)
      .toLowerCase()
      .replaceAll('_', '-')
      .split('-')
      .first;
  return Locale(language.isEmpty ? 'en' : language);
}

ThemeMode? abritSmokeThemeMode() => abritSmokeDirectory == null
    ? null
    : Platform.environment['ABRIT_UI_SMOKE_THEME'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;

Future<void> prepareAbritSmokeLanguage() async {
  if (abritSmokeDirectory == null) return;
  final saved = bind.mainGetLocalOption(key: kCommConfKeyLang);
  await bind.mainSetLocalOption(key: kCommConfKeyLang,
      value: Platform.environment['ABRIT_UI_SMOKE_LANG'] ?? 'en');
  abritSmokeRestoreLanguage = () async {
    await bind.mainSetLocalOption(key: kCommConfKeyLang, value: saved);
    abritSmokeRestoreLanguage = null;
  };
}
