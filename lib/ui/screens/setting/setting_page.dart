/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/data/dto/machine/print_stats.dart';
import 'package:mobileraker/data/model/hive/progress_notification_mode.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/service/theme_service.dart';
import 'package:mobileraker/service/ui/dialog_service.dart';
import 'package:mobileraker/ui/components/app_version_text.dart';
import 'package:mobileraker/ui/components/drawer/nav_drawer_view.dart';
import 'package:mobileraker/ui/screens/setting/setting_controller.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingPage extends ConsumerWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingService = ref.watch(settingServiceProvider);
    var themeData = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('pages.setting.title').tr(),
      ),
      body: FormBuilder(
        key: ref.watch(settingPageFormKeyProvider),
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
            children: <Widget>[
              _SectionHeader(title: 'pages.setting.general.title'.tr()),
              const _LanguageSelector(),
              const _TimeFormatSelector(),
              const _ThemeSelector(),
              const _ThemeModeSelector(),
              FormBuilderSwitch(
                name: 'emsConfirmation',
                title: const Text('pages.setting.general.ems_confirm').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.confirmEmergencyStop, b ?? false),
                initialValue:
                    ref.watch(boolSettingProvider(AppSettingKeys.confirmEmergencyStop, true)),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                activeColor: themeData.colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'alwaysShowBaby',
                title: const Text('pages.setting.general.always_baby').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.alwaysShowBabyStepping, b ?? false),
                initialValue: ref.watch(boolSettingProvider(AppSettingKeys.alwaysShowBabyStepping)),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                activeColor: themeData.colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'useTextInputForNum',
                title: const Text('pages.setting.general.num_edit').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.defaultNumEditMode, b ?? false),
                initialValue: ref.watch(boolSettingProvider(AppSettingKeys.defaultNumEditMode)),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                activeColor: themeData.colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'startWithOverview',
                title: const Text('pages.setting.general.start_with_overview').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.overviewIsHomescreen, b ?? false),
                initialValue: ref.watch(boolSettingProvider(AppSettingKeys.overviewIsHomescreen)),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                activeColor: themeData.colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'useLivePos',
                title: const Text('pages.setting.general.use_offset_pos').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.applyOffsetsToPostion, b ?? false),
                initialValue: ref.watch(boolSettingProvider(AppSettingKeys.applyOffsetsToPostion)),
                decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
                activeColor: themeData.colorScheme.primary,
              ),
              FormBuilderSwitch(
                name: 'lcFullCam',
                title: const Text('pages.setting.general.lcFullCam').tr(),
                onChanged: (b) =>
                    settingService.writeBool(AppSettingKeys.fullscreenCamOrientation, b ?? false),
                initialValue:
                    ref.watch(boolSettingProvider(AppSettingKeys.fullscreenCamOrientation)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                activeColor: themeData.colorScheme.primary,
              ),
              const _NotificationSection(),
              const Divider(),
              const _DeveloperSection(),
              const Divider(),
              if (Platform.isIOS)
                TextButton(
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero, // Set this
                        padding: EdgeInsets.zero,
                        textStyle: themeData.textTheme.bodySmall
                            ?.copyWith(color: themeData.colorScheme.secondary)),
                    child: const Text('EULA'),
                    onPressed: () async {
                      const String url =
                          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
                      if (await canLaunchUrlString(url)) {
                        await launchUrlString(url, mode: LaunchMode.externalApplication);
                      } else {
                        throw 'Could not launch $url';
                      }
                    }),
              TextButton(
                style: TextButton.styleFrom(
                    minimumSize: Size.zero, // Set this
                    padding: EdgeInsets.zero,
                    textStyle: themeData.textTheme.bodySmall
                        ?.copyWith(color: themeData.colorScheme.secondary)),
                child: Text(MaterialLocalizations.of(context).viewLicensesButtonLabel),
                onPressed: () {
                  var version = ref.watch(versionInfoProvider).maybeWhen(
                      orElse: () => 'unavailable', data: (d) => '${d.version}-${d.buildNumber}');

                  showLicensePage(
                      context: context,
                      applicationVersion: version,
                      applicationLegalese:
                          'Copyright (c) 2021 - ${DateTime.now().year} Patrick Schmidt',
                      applicationIcon: Center(
                        child: SvgPicture.asset(
                          'assets/vector/mr_logo.svg',
                          width: 80,
                          height: 80,
                        ),
                      ));
                },
              ),
              Align(
                alignment: Alignment.center,
                child: AppVersionText(
                  prefix: tr('components.app_version_display.version'),
                ),
              ),
              // _SectionHeader(title: 'Notifications'),
            ],
          ),
        ),
      ),
      drawer: const NavigationDrawerWidget(),
    );
  }
}

class _NotificationSection extends ConsumerWidget {
  const _NotificationSection({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return Column(
      children: [
        _SectionHeader(title: 'pages.setting.notification.title'.tr()),
        const CompanionMissingWarning(),
        const NotificationPermissionWarning(),
        const NotificationFirebaseWarning(),
        const _ProgressNotificationSettingField(),
        const _StateNotificationSettingField(),
        const Divider(),
        RichText(
          text: TextSpan(
              style: themeData.textTheme.bodySmall,
              text: tr('pages.setting.general.companion'),
              children: [
                TextSpan(
                  text: '\nOfficial GitHub ',
                  style: TextStyle(color: themeData.colorScheme.secondary),
                  children: const [
                    WidgetSpan(
                      child: Icon(FlutterIcons.github_alt_faw, size: 18),
                    ),
                  ],
                  recognizer: TapGestureRecognizer()
                    ..onTap = ref.read(settingPageControllerProvider.notifier).openCompanion,
                ),
              ]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return Column(
      children: [
        _SectionHeader(title: tr('pages.setting.developer.title')),
        FormBuilderSwitch(
          name: 'crashalytics',
          title: const Text('pages.setting.developer.crashlytics').tr(),
          enabled: !kDebugMode,
          onChanged: (b) => FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(b ?? true),
          initialValue: FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
          ),
          activeColor: themeData.colorScheme.primary,
        ),
        TextButton(
          style: TextButton.styleFrom(
              minimumSize: Size.zero, // Set this
              padding: EdgeInsets.zero,
              textStyle:
                  themeData.textTheme.bodySmall?.copyWith(color: themeData.colorScheme.secondary)),
          child: const Text('Debug-Logs'),
          onPressed: () {
            var dialogService = ref.read(dialogServiceProvider);
            dialogService.show(DialogRequest(type: DialogType.logging));
          },
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 12.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({Key? key}) : super(key: key);

  String constructLanguageText(Locale local) {
    String out = 'languages.languageCode.${local.languageCode}.nativeName'.tr();

    if (local.countryCode != null) {
      String country = 'languages.countryCode.${local.countryCode}.nativeName'.tr();
      out += " ($country)";
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<Locale> supportedLocals = context.supportedLocales.toList();
    supportedLocals.sort((a, b) => a.languageCode.compareTo(b.languageCode));
    return FormBuilderDropdown(
      initialValue: context.locale,
      name: 'lan',
      items: supportedLocals
          .map((local) => DropdownMenuItem(value: local, child: Text(constructLanguageText(local))))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'pages.setting.general.language'.tr(),
      ),
      onChanged: (Locale? local) => context.setLocale(local ?? context.fallbackLocale!),
    );
  }
}

class _TimeFormatSelector extends ConsumerWidget {
  const _TimeFormatSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // context.locale.
    // DateFormat
    // initializeDateFormatting()
    var now = DateTime.now();

    return FormBuilderDropdown(
        initialValue: ref.watch(boolSettingProvider(AppSettingKeys.timeFormat)),
        name: 'timeMode',
        items: [
          DropdownMenuItem(value: false, child: Text(DateFormat.Hm().format(now))),
          DropdownMenuItem(value: true, child: Text(DateFormat('h:mm a').format(now)))
        ],
        decoration: InputDecoration(
          labelStyle: Theme.of(context).textTheme.labelLarge,
          labelText: 'Time Format',
        ),
        onChanged: (bool? b) =>
            ref.read(settingServiceProvider).writeBool(AppSettingKeys.timeFormat, b ?? false));
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);

    List<ThemePack> themeList = themeService.themePacks;
    return FormBuilderDropdown(
      initialValue: ref
          .watch(activeThemeProvider.selectAs(
            (value) => value.themePack,
          ))
          .valueOrFullNull!,
      name: 'theme',
      items: themeList
          .map((theme) => DropdownMenuItem(value: theme, child: Text(theme.name)))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'Theme',
      ),
      onChanged: (ThemePack? themePack) => themeService.selectThemePack(themePack!),
      // themeService.selectThemePack(themeData!),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeService = ref.watch(themeServiceProvider);

    return FormBuilderDropdown(
      initialValue: ref.watch(activeThemeProvider.select((d) => d.valueOrFullNull!.themeMode)),
      name: 'themeMode',
      items: ThemeMode.values
          .map((themeMode) =>
              DropdownMenuItem(value: themeMode, child: Text(themeMode.name.capitalize)))
          .toList(),
      decoration: InputDecoration(
        labelStyle: Theme.of(context).textTheme.labelLarge,
        labelText: 'Theme Mode',
      ),
      onChanged: (ThemeMode? themeMode) =>
          themeService.selectThemeMode(themeMode ?? ThemeMode.system),
    );
  }
}

class _ProgressNotificationSettingField extends ConsumerWidget {
  const _ProgressNotificationSettingField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var progressSettings = ref.watch(notificationProgressSettingControllerProvider);

    return FormBuilderDropdown<ProgressNotificationMode>(
      initialValue: progressSettings,
      name: 'progressNotifyMode',
      items: ProgressNotificationMode.values
          .map((mode) =>
              DropdownMenuItem(value: mode, child: Text(mode.progressNotificationModeStr())))
          .toList(),
      onChanged: (v) => ref
          .read(notificationProgressSettingControllerProvider.notifier)
          .onProgressChanged(v ?? ProgressNotificationMode.TWENTY_FIVE),
      decoration: InputDecoration(
          labelStyle: Theme.of(context).textTheme.labelLarge,
          labelText: 'pages.setting.notification.progress_label'.tr(),
          helperText: 'pages.setting.notification.progress_helper'.tr()),
    );
  }
}

class _StateNotificationSettingField extends ConsumerWidget {
  const _StateNotificationSettingField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var stateSettings = ref.watch(notificationStateSettingControllerProvider);

    var themeData = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FormBuilderField<Set<PrintState>>(
          name: 'notificationStates',
          initialValue: stateSettings,
          onChanged: (values) {
            if (values == null) return;
            ref.read(notificationStateSettingControllerProvider.notifier).onStatesChanged(values);
          },
          builder: (FormFieldState<Set<PrintState>> field) {
            Set<PrintState> value = field.value ?? {};

            return InputDecorator(
              decoration: InputDecoration(
                  labelText: 'pages.setting.notification.state_label'.tr(),
                  labelStyle: themeData.textTheme.labelLarge,
                  helperText: 'pages.setting.notification.state_helper'.tr()),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                children: PrintState.values.map((e) {
                  var selected = value.contains(e);
                  return FilterChip(
                    selected: selected,
                    elevation: 2,
                    label: Text(
                      e.displayName,
                    ),
                    onSelected: (bool s) {
                      if (s) {
                        field.didChange({...value, e});
                      } else {
                        var set = value.toSet();
                        set.remove(e);
                        field.didChange(set);
                      }
                    },
                  );
                }).toList(growable: false),
              ),
            );
          }),
    );
  }
}

class NotificationPermissionWarning extends ConsumerWidget {
  const NotificationPermissionWarning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);
    return AnimatedSwitcher(
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
      duration: kThemeAnimationDuration,
      child: (ref.watch(notificationPermissionControllerProvider))
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ListTile(
                tileColor: themeData.colorScheme.errorContainer,
                textColor: themeData.colorScheme.onErrorContainer,
                iconColor: themeData.colorScheme.onErrorContainer,
                onTap:
                    ref.watch(notificationPermissionControllerProvider.notifier).requestPermission,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15))),
                leading: const Icon(
                  Icons.notifications_off_outlined,
                  size: 40,
                ),
                title: const Text(
                  'pages.setting.notification.no_permission_title',
                ).tr(),
                subtitle: const Text('pages.setting.notification.no_permission_desc').tr(),
              ),
            ),
    );
  }
}

class NotificationFirebaseWarning extends ConsumerWidget {
  const NotificationFirebaseWarning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var themeData = Theme.of(context);

    return AnimatedSwitcher(
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
      duration: kThemeAnimationDuration,
      child: (ref.watch(notificationFirebaseAvailableProvider))
          ? const SizedBox.shrink()
          : Padding(
              key: UniqueKey(),
              padding: const EdgeInsets.only(top: 16),
              child: ListTile(
                tileColor: themeData.colorScheme.errorContainer,
                textColor: themeData.colorScheme.onErrorContainer,
                iconColor: themeData.colorScheme.onErrorContainer,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15))),
                leading: const Icon(
                  FlutterIcons.notifications_paused_mdi,
                  size: 40,
                ),
                title: const Text(
                  'pages.setting.notification.no_firebase_title',
                ).tr(),
                subtitle: const Text('pages.setting.notification.no_firebase_desc').tr(),
              ),
            ),
    );
  }
}

class CompanionMissingWarning extends ConsumerWidget {
  const CompanionMissingWarning({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var machinesWithoutCompanion = ref.watch(machinesWithoutCompanionProvider);

    var machineNames = (machinesWithoutCompanion.valueOrFullNull ?? []).map((e) => e.name);

    var themeData = Theme.of(context);
    return Material(
      child: AnimatedSwitcher(
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
        duration: kThemeAnimationDuration,
        child: (machineNames.isEmpty)
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ListTile(
                  onTap: ref.read(settingPageControllerProvider.notifier).openCompanion,
                  tileColor: themeData.colorScheme.errorContainer,
                  textColor: themeData.colorScheme.onErrorContainer,
                  iconColor: themeData.colorScheme.onErrorContainer,
                  // onTap: ref
                  //     .watch(notificationPermissionControllerProvider.notifier)
                  //     .requestPermission,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15))),
                  leading: const Icon(
                    FlutterIcons.uninstall_ent,
                    size: 40,
                  ),
                  title: const Text(
                    'pages.setting.notification.missing_companion_title',
                  ).tr(),
                  subtitle: const Text('pages.setting.notification.missing_companion_body')
                      .tr(args: [machineNames.join(', ')]),
                ),
              ),
      ),
    );
  }
}
