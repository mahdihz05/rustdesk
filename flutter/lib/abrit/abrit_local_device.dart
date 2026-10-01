import 'package:flutter_hbb/abrit/abrit_identity.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';
import '../desktop/pages/desktop_setting_page.dart';
import 'abrit_branding.dart';

class AbritLocalDevice extends StatefulWidget {
  const AbritLocalDevice({super.key});
  @override
  State<AbritLocalDevice> createState() => _AbritLocalDeviceState();
}

class _AbritLocalDeviceState extends State<AbritLocalDevice> {
  bool _showPassword = false;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: gFFI.serverModel,
        child: Consumer<ServerModel>(builder: (context, model, child) {
          final temporary = model.approveMode != 'click' &&
              model.verificationMethod != kUsePermanentPassword;
          final light = Theme.of(context).brightness == Brightness.light;
          Widget copy(TextEditingController controller, String label) =>
              IconButton(
                tooltip: translate('Copy'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_outlined,
                    size: 18, color: AbritStyle.blue),
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: controller.text.replaceAll(' ', '')));
                  showToast(translate('Copied'));
                },
              );
          Widget tile({required String title, required IconData icon, required Widget child}) =>
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: light
                        ? Colors.white.withOpacity(0.7)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Icon(icon, size: 18, color: const Color(0xFF687CA3)), const SizedBox(width: 6), Expanded(child: Text(title,
                          style: TextStyle(
                              fontSize: 12,
                              color: light
                                  ? const Color(0xFF687CA3)
                                  : Colors.white70, fontWeight: FontWeight.w600))),]),
                      const SizedBox(height: 12),
                      child,
                    ]),
              );
          return Container(
              decoration: AbritStyle.panel(context),
              constraints: const BoxConstraints(minHeight: 268),
              padding: const EdgeInsets.all(20),
              child: AbritPanelContent(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.ltr, children: [
                      Text(abritText('Your Desktop', 'دستگاه شما'), style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: light ? AbritStyle.navy : Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.desktop_windows_outlined, color: AbritStyle.blue, size: 29),
                    ])),
                    const SizedBox(height: 8),
                    Text(
                        abritText('desk_tip',
                            'این شناسه را در اختیار طرف مقابل قرار دهید'),
                        style: TextStyle(
                            color: light
                                ? const Color(0xFF7386A8)
                                : Colors.white60,
                            fontSize: 14)),
                    const Divider(height: 24),
                    LayoutBuilder(builder: (context, size) {
                      final id = tile(
                          title: abritText('ID', 'شناسه شما'), icon: Icons.copy_outlined,
                          child: Column(children: [
                            Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(children: [
                                  Expanded(child: ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: model.serverId,
                                      builder: (context, value, _) => FittedBox(
                                          fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                                          child: Text(value.text, style: TextStyle(fontSize: 24,
                                              fontWeight: FontWeight.bold, color: light ? AbritStyle.navy : Colors.white))))),
                                  copy(model.serverId, 'ID'),
                                ])),
                            Obx(() {
                              final ready = stateGlobal.svcStatus.value ==
                                      SvcStatus.ready &&
                                  !Get.find<RxBool>(tag: 'stop-service').value;
                              return Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: (ready
                                                  ? Colors.green
                                                  : Colors.orange)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(7)),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle,
                                                size: 8,
                                                color: ready
                                                    ? Colors.green
                                                    : Colors.orange),
                                            const SizedBox(width: 5),
                                            Flexible(
                                                child: Text(
                                                    ready
                                                        ? abritText('Ready',
                                                            'آماده برای ارتباط')
                                                        : translate(
                                                            'Not ready'),
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: ready
                                                            ? Colors.green
                                                            : Colors.orange))),
                                          ])));
                            }),
                          ]));
                      final password = tile(
                          title: abritText(
                              'One-time Password', 'رمز عبور یکبار مصرف'), icon: Icons.lock_outline,
                          child: Column(children: [
                            Directionality(
                                textDirection: TextDirection.ltr,
                                child: Row(children: [
                                  Expanded(
                                      child: TextField(
                                          controller: model.serverPasswd,
                                          readOnly: true,
                                          obscureText:
                                              temporary && !_showPassword,
                                          decoration: const InputDecoration(
                                              filled: false,
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero),
                                          style: const TextStyle(
                                              fontSize: 23, fontWeight: FontWeight.bold, letterSpacing: 3))),
                                  if (temporary)
                                    copy(model.serverPasswd, 'Password'),
                                ])),
                            Wrap(textDirection: TextDirection.ltr, spacing: 4, children: [
                              if (temporary)
                                IconButton(
                                    tooltip: translate('Password'),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(
                                        () => _showPassword = !_showPassword),
                                    icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20)),
                              if (temporary)
                                IconButton(
                                    tooltip: translate('Refresh Password'),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        bind.mainUpdateTemporaryPassword(),
                                    icon: const Icon(Icons.refresh, size: 20)),
                              if (!bind.isDisableSettings())
                                IconButton(
                                    tooltip: translate('Change Password'),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () =>
                                        DesktopSettingPage.switch2page(
                                            SettingsTabKey.safety),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20)),
                            ]),
                          ]));
                      return size.maxWidth < 280
                          ? Column(children: [
                              id,
                              const SizedBox(height: 8),
                              password
                            ])
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(child: id),
                                  const SizedBox(width: 8),
                                  Expanded(child: password)
                                ]);
                    }),
                  ])));
        }),
      );
}
