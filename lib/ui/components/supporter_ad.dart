/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'supporter_ad.g.dart';

@riverpod
class _SupporterAdController extends _$SupporterAdController {
  late final _boxSettings = Hive.box('settingsbox');

  static const _key = 'supporter_add';

  @override
  bool build() {
    var isSupporter = ref.watch(isSupporterProvider);

    if (isSupporter) return false;

    DateTime? stamp = _boxSettings.get(_key);

    logger.i('Last dismiss of Supporter AD: $stamp');

    return stamp == null || DateTime.now().difference(stamp).inDays > 20;
  }

  dismissAd() {
    _boxSettings.put(_key, DateTime.now());
    state = false;
  }

  navigateToSupporterPage() {
    ref.read(goRouterProvider).pushNamed(AppRoute.supportDev.name);
  }
}

class SupporterAd extends ConsumerWidget {
  const SupporterAd({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        child: (ref.watch(_supporterAdControllerProvider))
            ? Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      onTap: ref
                          .read(_supporterAdControllerProvider.notifier)
                          .navigateToSupporterPage,
                      contentPadding:
                          const EdgeInsets.only(top: 3, left: 16, right: 16),
                      leading:
                          const Icon(FlutterIcons.hand_holding_heart_faw5s),
                      title: const Text('components.supporter_add.title').tr(),
                      subtitle:
                          const Text('components.supporter_add.subtitle').tr(),
                      trailing: IconButton(
                          onPressed: ref
                              .read(_supporterAdControllerProvider.notifier)
                              .dismissAd,
                          icon: const Icon(Icons.close)),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink());
  }
}
