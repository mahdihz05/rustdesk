import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';

bool get isAbritDesk => isWindows && bind.mainGetAppNameSync() == 'abritDesk';
String abritText(String english, String persian) =>
    bind.mainGetLocalOption(key: 'lang').startsWith('fa')
        ? persian
        : translate(english);
