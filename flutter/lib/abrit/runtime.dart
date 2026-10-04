import 'package:flutter/material.dart';
import '../consts.dart';
import '../models/platform_model.dart';

Locale abritLocale() {
  final saved = bind.mainGetLocalOption(key: kCommConfKeyLang);
  final language = (saved.isEmpty ? localeName : saved)
      .toLowerCase()
      .replaceAll('_', '-')
      .split('-')
      .first;
  return Locale(language.isEmpty ? 'en' : language);
}
