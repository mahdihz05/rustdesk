import 'package:flutter_hbb/abrit/abrit_identity.dart';
import 'package:flutter_hbb/abrit/abrit_branding.dart';
import 'package:flutter_hbb/common/widgets/peer_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
// import 'package:flutter/services.dart';

import '../../common/shared_state.dart';

const kAbritPrinterTab = 'abrit-printer';
const kAbritHistoryTab = 'abrit-history';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {
      DesktopTabController tabController = Get.find<DesktopTabController>();
      if (isAbritDesk && initialPage == SettingsTabKey.printer) {
        tabController.jumpToByKey(kAbritPrinterTab);
        return;
      }
      tabController.add(TabInfo(
          key: kTabLabelSettingPage,
          label: kTabLabelSettingPage,
          closable: !isAbritDesk,
          selectedIcon: Icons.build_sharp,
          unselectedIcon: Icons.build_outlined,
          page: DesktopSettingPage(
            key: const ValueKey(kTabLabelSettingPage),
            initialTabkey: initialPage,
          )));
    } catch (e) {
      debugPrintStack(label: '$e');
    }
  }
}

class _DesktopTabPageState extends State<DesktopTabPage> {
  final tabController = DesktopTabController(tabType: DesktopTabType.main);

  _DesktopTabPageState() {
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: DesktopHomePage(
          key: const ValueKey(kTabLabelHomePage),
        )));
    if (isAbritDesk) {
      DesktopTabPage.onAddSetting();
      tabController.add(TabInfo(
          key: kAbritPrinterTab,
          label: 'Printer',
          selectedIcon: Icons.print,
          unselectedIcon: Icons.print_outlined,
          closable: false,
          page: Padding(
              padding: const EdgeInsets.all(18),
              child: DesktopSettingPage.printerPage())));
      tabController.add(TabInfo(
          key: kAbritHistoryTab,
          label: 'Recent sessions',
          selectedIcon: Icons.history,
          unselectedIcon: Icons.history_outlined,
          closable: false,
          page: const Padding(
              padding: EdgeInsets.all(18), child: PeerTabPage())));
      tabController.jumpTo(0, callOnSelected: false);
    }
    if (bind.isIncomingOnly()) {
      tabController.onSelected = (key) {
        if (key == kTabLabelHomePage) {
          windowManager.setSize(getIncomingOnlyHomeSize());
          setResizable(false);
        } else {
          windowManager.setSize(getIncomingOnlySettingsSize());
          setResizable(true);
        }
      };
    }
  }

  @override
  void initState() {
    super.initState();
    // HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  /*
  bool _handleKeyEvent(KeyEvent event) {
    if (!mouseIn && event is KeyDownEvent) {
      print('key down: ${event.logicalKey}');
      shouldBeBlocked(_block, canBeBlocked);
    }
    return false; // allow it to propagate
  }
  */

  @override
  void dispose() {
    // HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    Get.delete<DesktopTabController>();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: DesktopTab(
              controller: tabController,
              tail: Offstage(
                offstage: bind.isIncomingOnly() || bind.isDisableSettings(),
                child: ActionIcon(
                  message: 'Settings',
                  icon: IconFont.menu,
                  onTap: DesktopTabPage.onAddSetting,
                  isClose: false,
                ),
              ),
            )));
    final content = isAbritDesk
        ? Directionality(
            textDirection: bind.mainGetLocalOption(key: 'lang').startsWith('fa')
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Theme(
                data: Theme.of(context).copyWith(
                    scaffoldBackgroundColor: AbritStyle.background(context)),
                child: tabWidget))
        : tabWidget;
    return isMacOS || kUseCompatibleUiMode
        ? content
        : Obx(
            () => DragToResizeArea(
              resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
              enableResizeEdges: windowManagerEnableResizeEdges,
              child: content,
            ),
          );
  }
}
