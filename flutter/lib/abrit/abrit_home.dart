import 'package:get/get.dart';
import 'package:flutter_hbb/desktop/widgets/tabbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'abrit_identity.dart';
import 'abrit_branding.dart';
import 'abrit_config.dart';
import 'abrit_promotion.dart';
import 'abrit_peer_style.dart';

class AbritHomeLayout extends StatelessWidget {
  final Widget remoteControl;
  final Widget localDevice;
  final Widget? notices;
  final Widget status;
  final VoidCallback onHistory;
  const AbritHomeLayout(
      {super.key,
      required this.remoteControl,
      required this.localDevice,
      this.notices,
      required this.status,
      required this.onHistory});
  @override
  Widget build(BuildContext context) => Container(
        color: AbritStyle.background(context),
        child: Column(children: [
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (notices != null) notices!,
                              if (constraints.maxWidth >= 850)
                                Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                              flex: 55,
                                              child: Directionality(
                                                  textDirection:
                                                      Directionality.of(
                                                          context),
                                                  child: remoteControl)),
                                          const SizedBox(width: 18),
                                          Expanded(
                                              flex: 45,
                                              child: Directionality(
                                                  textDirection:
                                                      Directionality.of(
                                                          context),
                                                  child: localDevice)),
                                        ]))
                              else ...[
                                localDevice,
                                const SizedBox(height: 14),
                                remoteControl
                              ],
                              const SizedBox(height: 18),
                              Container(
                                  decoration: AbritStyle.panel(context),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(children: [
                                    Row(children: [
                                      const Icon(Icons.history,
                                          color: AbritStyle.blue),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              abritText('Recent sessions',
                                                  'نشست‌های اخیر'),
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                      TextButton(
                                          onPressed: onHistory,
                                          child: Text(abritText(
                                              'Show all', 'نمایش همه'))),
                                    ]),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                        height: 172,
                                        child: LayoutBuilder(
                                            builder: (context, constraints) =>
                                                Obx(() => AbritPeerStyle(
                                                    active:
                                                        Get.find<DesktopTabController>()
                                                                .state
                                                                .value
                                                                .selected ==
                                                            0,
                                                    cardWidth: ((constraints
                                                                    .maxWidth -
                                                                24) /
                                                            3)
                                                        .clamp(220.0, 500.0),
                                                    child: RecentPeersView(
                                                        menuPadding:
                                                            kDesktopMenuPadding))))),
                                  ])),
                              const SizedBox(height: 18),
                              const AbritPromotionBanner(),
                            ]),
                      ))),
          const Divider(height: 1),
          SizedBox(
              height: 36,
              child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(children: [
                    const SizedBox(width: 12),
                    TextButton(
                        onPressed: () async {
                          final config = await AbritConfig.instance;
                          await launchUrl(config.website,
                              mode: LaunchMode.externalApplication);
                        },
                        child: const Text('abrit.ir',
                            style: TextStyle(fontSize: 12))),
                    FutureBuilder<String>(
                        future: bind.mainGetVersion(),
                        builder: (context, snapshot) => Text(
                            'abritDesk ${snapshot.data ?? ''}',
                            style: const TextStyle(fontSize: 11))),
                    const Spacer(),
                    Flexible(child: status),
                    const SizedBox(width: 8),
                  ]))),
        ]),
      );
}

class AbritConnectionActions extends StatelessWidget {
  final String selectedConnectionType;
  final VoidCallback onConnect;
  final VoidCallback onLocalNetwork;
  final ValueChanged<String?> onTypeChanged;
  const AbritConnectionActions(
      {super.key,
      required this.selectedConnectionType,
      required this.onConnect,
      required this.onLocalNetwork,
      required this.onTypeChanged});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Wrap(
            textDirection: TextDirection.ltr,
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AbritStyle.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                          padding: const EdgeInsets.symmetric(horizontal: 28)),
                      onPressed: onConnect,
                      icon: const Icon(Icons.bolt, size: 18),
                      label: Text(translate('Connect'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
              Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF4F8FF),
                      borderRadius: BorderRadius.circular(9)),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: selectedConnectionType,
                    dropdownColor: const Color(0xFFF4F8FF),
                    style: const TextStyle(color: AbritStyle.navy, fontSize: 13, fontWeight: FontWeight.w600),
                    items: [
                      'Connect',
                      'Transfer file',
                      'View camera',
                      'Terminal',
                      'TCP tunneling'
                    ]
                        .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value == 'Connect'
                                ? abritText('Connect', 'کنترل و دسترسی کامل')
                                : translate(value))))
                        .toList(),
                    onChanged: onTypeChanged,
                  ))),
              OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF334764),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF657FA4)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 10)),
                  onPressed: onLocalNetwork,
                  icon: const Icon(Icons.computer, color: AbritStyle.blue, size: 22),
                  label: Text(abritText('Local network', 'میزکار محلی'),
                      style: const TextStyle(fontSize: 12))),
            ]),
      );
}
