import 'package:flutter/material.dart';
import 'dart:io';
import 'smoke.dart';
import '../consts.dart';
import '../models/platform_model.dart';
import '../common.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart' as window_size;
import 'window.dart';
import '../utils/multi_window_manager.dart' show WindowType;

Future<bool> initializeAbritMainWindow() async {
  if (!isWindows || bind.isIncomingOnly()) return false;
  if (bind.getLocalFlutterOption(k: abritWindowLayoutKey) == 'Y' &&
      LastWindowPosition.loadFromString(bind.getLocalFlutterOption(
          k: windowFramePrefix + WindowType.Main.name)) != null) {
    return false;
  }
  // Reset the previous preview's maximized frame once; subsequent user frames
  // continue through the existing restore path.
  await windowManager.setFullScreen(false);
  await windowManager.unmaximize();
  final screen = (await window_size.getWindowInfo()).screen;
  final size = screen == null
      ? abritInitialWindowSize
      : abritWindowSizeForWorkArea(screen.visibleFrame.size, screen.scaleFactor);
  await windowManager.setSize(size);
  await windowManager.center();
  await saveWindowPosition(WindowType.Main, flush: true);
  await bind.setLocalFlutterOption(k: abritWindowLayoutKey, v: 'Y');
  return true;
}

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
  abritSmokeSaveWindowPosition = () => saveWindowPosition(WindowType.Main, flush: true);
  final saved = bind.mainGetLocalOption(key: kCommConfKeyLang);
  await bind.mainSetLocalOption(key: kCommConfKeyLang,
      value: Platform.environment['ABRIT_UI_SMOKE_LANG'] ?? 'en');
  abritSmokeRestoreLanguage = () async {
    await bind.mainSetLocalOption(key: kCommConfKeyLang, value: saved);
    await bind.mainChangeLanguage(lang: saved);
    abritSmokeRestoreLanguage = null;
  };
}
