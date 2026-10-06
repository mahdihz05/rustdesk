import 'package:flutter/material.dart';
import 'dart:io';
import 'smoke.dart';
import '../consts.dart';
import '../models/platform_model.dart';
import '../common.dart';
import 'package:get/get.dart';

Future<void> changeAbritLanguage(String language) async {
  if (isOptionFixed(kCommConfKeyLang)) return;
  await bind.mainSetLocalOption(key: kCommConfKeyLang, value: language);
  await Get.updateLocale(abritLocale());
  reloadAllWindows();
  await bind.mainChangeLanguage(lang: language);
}

Locale abritLocale() {
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
    await bind.mainChangeLanguage(lang: saved);
    abritSmokeRestoreLanguage = null;
  };
}
