import 'package:flutter/material.dart';
import '../../abrit/brand.dart';
import '../../abrit/shell.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/peer_tab_model.dart';
import '../../models/ab_model.dart';
// import 'package:flutter/services.dart';

import '../../common/shared_state.dart';

class DesktopTabPage extends StatefulWidget {
  const DesktopTabPage({Key? key}) : super(key: key);

  @override
  State<DesktopTabPage> createState() => _DesktopTabPageState();

  static void onAddSetting(
      {SettingsTabKey initialPage = SettingsTabKey.general}) {
    try {
      DesktopTabController tabController = Get.find<DesktopTabController>();
      if (Get.isRegistered<ValueNotifier<AbritDestination>>()) {
        Get.find<ValueNotifier<AbritDestination>>().value = AbritDestination.settings;
      }
      tabController.add(TabInfo(
          key: kTabLabelSettingPage,
          label: kTabLabelSettingPage,
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
  final destination = ValueNotifier(AbritDestination.home);

  _DesktopTabPageState() {
    RemoteCountState.init();
    Get.put<DesktopTabController>(tabController);
    Get.put<ValueNotifier<AbritDestination>>(destination);
    tabController.add(TabInfo(
        key: kTabLabelHomePage,
        label: kTabLabelHomePage,
        selectedIcon: Icons.home_sharp,
        unselectedIcon: Icons.home_outlined,
        closable: false,
        page: DesktopHomePage(
          key: const ValueKey(kTabLabelHomePage),
        )));
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
    Get.delete<ValueNotifier<AbritDestination>>();
    destination.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabWidget = Container(
        child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.background,
            body: bind.isIncomingOnly() ? DesktopTab(
              controller: tabController,
              tail: Offstage(offstage: bind.isDisableSettings(),
                child: ActionIcon(message: 'Settings', icon: IconFont.menu,
                  onTap: DesktopTabPage.onAddSetting, isClose: false)),
            ) : AbritDesktopShell(
              destination: destination,
              version: version,
              onLayout: (metrics) {
                stateGlobal.isPortrait.value = metrics.compactContent;
              },
              destinations: [
                AbritDestination.home,
                if (!bind.isIncomingOnly()) AbritDestination.connection,
                if (!bind.isIncomingOnly()) AbritDestination.devices,
                if (!bind.isIncomingOnly() && !bind.isDisableAb() && !bind.isDisableAccount())
                  AbritDestination.addressBook,
                if (!bind.isDisableSettings() && DesktopSettingPage.tabKeys.isNotEmpty)
                  AbritDestination.settings,
              ],
              onSelected: (page) {
                destination.value = page;
                if (page == AbritDestination.settings) {
                  DesktopTabPage.onAddSetting(initialPage: DesktopSettingPage.tabKeys.first);
                } else {
                  if (page == AbritDestination.addressBook) {
                    gFFI.peerTabModel.setCurrentTabCachedPeers([]);
                    gFFI.peerTabModel.setMultiSelectionMode(false);
                    gFFI.peerTabModel.setCurrentTab(PeerTabIndex.ab.index);
                    gFFI.abModel.pullAb(force: ForcePullAb.listAndCurrent, quiet: false);
                  } else if (page == AbritDestination.devices &&
                      gFFI.peerTabModel.currentTab == PeerTabIndex.ab.index) {
                    final indexes = gFFI.peerTabModel.visibleEnabledOrderedIndexs
                        .where((index) => index != PeerTabIndex.ab.index);
                    if (indexes.isNotEmpty) {
                      gFFI.peerTabModel.setCurrentTabCachedPeers([]);
                      gFFI.peerTabModel.setMultiSelectionMode(false);
                      gFFI.peerTabModel.setCurrentTab(indexes.first);
                    }
                  }
                  tabController.jumpToByKey(kTabLabelHomePage);
                }
              },
              onDrag: () => startDragging(true),
              onMaximize: () {
                if (!bind.isIncomingOnly()) toggleMaximize(true);
              },
              windowControls: WindowActionPanel(
                isMainWindow: true,
                state: tabController.state,
                tabController: tabController,
                invisibleTabKeys: RxList<String>(),
              ),
              child: DesktopTab(
              showTabBar: false,
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
            ))));
    return isMacOS || kUseCompatibleUiMode
        ? tabWidget
        : Obx(
            () => DragToResizeArea(
              resizeEdgeSize: stateGlobal.resizeEdgeSize.value,
              enableResizeEdges: windowManagerEnableResizeEdges,
              child: tabWidget,
            ),
          );
  }
}
