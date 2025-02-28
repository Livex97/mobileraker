/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/firebase/remote_config.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/service/setting_service.dart';
import 'package:mobileraker/util/extensions/async_ext.dart';
import 'package:mobileraker/util/extensions/object_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'machine_deletion_warning.g.dart';

@riverpod
class _MachineDeletionWarningController extends _$MachineDeletionWarningController {
  SettingService get _settingService => ref.read(settingServiceProvider);

  @override
  int build() {
    var isSupporter = ref.watch(isSupporterProvider);
    var maxNonSupporterMachines = ref.watch(remoteConfigProvider).maxNonSupporterMachines;
    var machineCount = ref.watch(allMachinesProvider.selectAs((d) => d.length)).valueOrNull ?? 0;
    logger.i('Max allowed machines for non Supporters is $maxNonSupporterMachines');
    DateTime? dismissStamp = _settingService.read(UtilityKeys.nonSupporterDismiss, null);

    if (isSupporter ||
        maxNonSupporterMachines <= -1 ||
        machineCount <= maxNonSupporterMachines ||
        (dismissStamp?.let((s) => DateTime.now().difference(s).inHours < 2) ?? false)) {
      return -1;
    }

    DateTime initialDeletionDate =
        _settingService.read(UtilityKeys.nonSupporterMachineCleanup, DateTime.now());
    return initialDeletionDate.difference(DateTime.now()).inDays;
  }

  dismiss() {
    _settingService.write(UtilityKeys.nonSupporterDismiss, DateTime.now());
    state = -1;
  }

  navigateToSupporterPage() {
    ref.read(goRouterProvider).pushNamed(AppRoute.supportDev.name);
  }
}

class MachineDeletionWarning extends ConsumerWidget {
  const MachineDeletionWarning({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int daysUntilDeletion = ref.watch(_machineDeletionWarningControllerProvider);

    var themeData = Theme.of(context);
    return AnimatedSwitcher(
        duration: kThemeAnimationDuration,
        switchInCurve: Curves.easeInCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              child: FadeTransition(
                opacity: anim,
                child: child,
              ),
            ),
        child: (daysUntilDeletion > 0)
            ? Card(
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(top: 3, left: 16, right: 16),
                      title: const Text('components.machine_deletion_warning.title').tr(),
                      subtitle: const Text('components.machine_deletion_warning.subtitle').tr(
                          args: [
                            ref.read(remoteConfigProvider).maxNonSupporterMachines.toString(),
                            daysUntilDeletion.toString()
                          ]),
                      trailing: IconButton(
                          onPressed:
                              ref.read(_machineDeletionWarningControllerProvider.notifier).dismiss,
                          icon: const Icon(Icons.close)),
                    ),
                    TextButton(
                        onPressed: ref
                            .read(_machineDeletionWarningControllerProvider.notifier)
                            .navigateToSupporterPage,
                        child: const Text(
                          'components.supporter_only_feature.button',
                          style: TextStyle(fontSize: 11),
                        ).tr())
                  ],
                ),
              )
            : const SizedBox.shrink());
  }
}
