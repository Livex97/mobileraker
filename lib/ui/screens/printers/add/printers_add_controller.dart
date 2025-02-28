/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobileraker/data/data_source/json_rpc_client.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_connection_info_response.dart';
import 'package:mobileraker/data/dto/octoeverywhere/app_portal_result.dart';
import 'package:mobileraker/data/model/hive/machine.dart';
import 'package:mobileraker/data/model/hive/octoeverywhere.dart';
import 'package:mobileraker/exceptions.dart';
import 'package:mobileraker/logger.dart';
import 'package:mobileraker/routing/app_router.dart';
import 'package:mobileraker/service/firebase/remote_config.dart';
import 'package:mobileraker/service/machine_service.dart';
import 'package:mobileraker/service/octoeverywhere/app_connection_service.dart';
import 'package:mobileraker/service/payment_service.dart';
import 'package:mobileraker/service/ui/snackbar_service.dart';
import 'package:mobileraker/ui/screens/printers/components/http_headers.dart';
import 'package:mobileraker/ui/screens/qr_scanner/qr_scanner_page.dart';
import 'package:mobileraker/ui/theme/theme_pack.dart';
import 'package:mobileraker/util/extensions/uri_extension.dart';
import 'package:mobileraker/util/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'printers_add_controller.freezed.dart';
part 'printers_add_controller.g.dart';

@riverpod
GlobalKey<FormBuilderState> formKey(FormKeyRef ref) {
  return GlobalKey<FormBuilderState>();
}

@riverpod
class PrinterAddViewController extends _$PrinterAddViewController {
  @override
  PrinterAddState build() {
    var isSupporter = ref.watch(isSupporterProvider);
    var maxNonSupporterMachines = ref.watch(remoteConfigProvider).maxNonSupporterMachines;
    if (!isSupporter && maxNonSupporterMachines > 0) {
      ref.watch(allMachinesProvider.selectAsync((data) => data.length)).then((value) {
        if (value >= maxNonSupporterMachines) {
          state = state.copyWith(
              nonSupporterError: tr('components.supporter_only_feature.printer_add',
                  args: [maxNonSupporterMachines.toString()]));
        }
      });
    }

    return const PrinterAddState();
  }

  onStepTapped(int step) {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: step);
  }

  previousStep() {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: max(0, state.step - 1));
  }

  addFromOcto() async {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: 3);
    var appConnectionService = ref.read(appConnectionServiceProvider);

    try {
      AppPortalResult appPortalResult = await appConnectionService.linkAppWithOcto();

      AppConnectionInfoResponse appConnectionInfo =
          await appConnectionService.getInfo(appPortalResult.appApiToken);

      var infoResult = appConnectionInfo.result;
      var localIp = infoResult.printerLocalIp;
      logger.i('OctoEverywhere returned Local IP: $localIp');

      if (localIp == null) {
        throw const OctoEverywhereException('Could not retrieve Printer\'s local IP.');
      }

      var wsUrl = buildMoonrakerWebSocketUri(localIp);
      var httpUri = buildMoonrakerHttpUri(localIp);
      if (wsUrl == null || httpUri == null) {
        throw const OctoEverywhereException('Could not retrieve Printer\'s local IP.');
      }

      var machine = Machine(
          name: infoResult.printerName,
          wsUri: wsUrl,
          httpUri: httpUri,
          octoEverywhere: OctoEverywhere.fromDto(appPortalResult));
      machine = await ref.read(machineServiceProvider).addMachine(machine);
      state = state.copyWith(addedMachine: true, machineToAdd: machine);
    } on OctoEverywhereException catch (e, s) {
      logger.e('Error while trying to add printer via Ocot', e, s);
      ref.read(snackBarServiceProvider).show(SnackBarConfig(
          type: SnackbarType.error, title: 'OctoEverywhere-Error:', message: e.message));
      state = state.copyWith(step: 0);
    }
  }

  Future<bool> onWillPopScope() async {
    var stepperIndex = ref.read(printerAddViewControllerProvider.select((value) => value.step));

    if (stepperIndex == 0 || stepperIndex == 3) return true;

    ref.watch(printerAddViewControllerProvider.notifier).previousStep();
    return false;
  }

  selectMode(bool isExpert) {
    if (isExpert != state.isExpert) {
      ref.invalidate(formKeyProvider);
    }
    state = state.copyWith(isExpert: isExpert, step: 1);
  }

  provideMachine(Machine machine) {
    logger.i('provideMachine got: $machine');
    state = state.copyWith(
      step: state.step + 1,
      machineToAdd: machine,
    );
  }

  submitMachine() async {
    if (state.nonSupporterError != null) return;
    state = state.copyWith(step: state.step + 1);
    await ref.read(machineServiceProvider).addMachine(state.machineToAdd!);
    state = state.copyWith(addedMachine: true);
  }

  goToDashboard() {
    ref.read(goRouterProvider).goNamed(AppRoute.dashBoard.name);
  }
}

@riverpod
class SimpleFormController extends _$SimpleFormController {
  static String formKey = 'simple';

  FormBuilderState get _formState => ref.read(formKeyProvider).currentState!;

  FormBuilderFieldState get _displayNameField => _formState.fields['simple.name']!;

  FormBuilderFieldState get _urlField => _formState.fields['simple.url']!;

  FormBuilderFieldState get _apiKeyField => _formState.fields['simple.apikey']!;

  @override
  SimpleFormState build() => const SimpleFormState();

  toggleProtocol() {
    state = state.copyWith(isHttps: !state.isHttps);
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      _apiKeyField.didChange(qr!.rawValue);
    }
  }

  proceed() {
    if (!_formState.saveAndValidate()) return;

    ref.read(printerAddViewControllerProvider.notifier).provideMachine(Machine(
        name: _displayNameField.transformedValue,
        wsUri: buildMoonrakerWebSocketUri('${state.scheme}${_urlField.transformedValue}')!,
        httpUri: buildMoonrakerHttpUri('${state.scheme}${_urlField.transformedValue}')!,
        apiKey: _apiKeyField.transformedValue));
  }
}

@riverpod
class AdvancedFormController extends _$AdvancedFormController {
  static String formKey = 'advanced';

  FormBuilderState get _formState => ref.read(formKeyProvider).currentState!;

  FormBuilderFieldState get _displayNameField => _formState.fields['advanced.name']!;

  FormBuilderFieldState get _httpField => _formState.fields['advanced.http']!;

  FormBuilderFieldState get _wsField => _formState.fields['advanced.ws']!;

  FormBuilderFieldState get _apiKeyField => _formState.fields['advanced.apikey']!;

  @override
  AdvancedFormState build() {
    var pState = ref.read(printerAddViewControllerProvider);

    if (pState.machineToAdd != null) {
      return AdvancedFormState(
          wsUriFromHttpUri: buildMoonrakerWebSocketUri(pState.machineToAdd!.httpUri.toString()),
          headers: pState.machineToAdd!.httpHeaders);
    }

    return const AdvancedFormState();
  }

  openQrScanner(BuildContext context) async {
    Barcode? qr = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (ctx) => const QrScannerPage()));
    if (qr?.rawValue != null) {
      _apiKeyField.didChange(qr!.rawValue);
    }
  }

  proceed() {
    if (!_formState.saveAndValidate()) return;

    var httpInput = _httpField.transformedValue;
    var wsInput =
        (_wsField.transformedValue?.isEmpty ?? true) ? httpInput : _wsField.transformedValue;

    var headers = ref.read(headersControllerProvider(state.headers));

    ref.read(printerAddViewControllerProvider.notifier).provideMachine(Machine(
          name: _displayNameField.transformedValue,
          httpUri: buildMoonrakerHttpUri(httpInput)!,
          wsUri: buildMoonrakerWebSocketUri(wsInput, false)!,
          apiKey: _apiKeyField.transformedValue,
          httpHeaders: headers,
        ));
  }

  onHttpUriChanged(String? httpInput) {
    state = state.copyWith(
        wsUriFromHttpUri: (httpInput == null || httpInput.isEmpty)
            ? null
            : buildMoonrakerWebSocketUri(httpInput));
  }
}

@riverpod
class TestConnectionController extends _$TestConnectionController {
  StreamSubscription? _testConnectionRPCState;
  late JsonRpcClient _client;
  late HttpClient _httpClient;
  late Map<String, String> _httpHeaders;

  @override
  TestConnectionState build() {
    ref.onDispose(dispose);
    ref.listenSelf((previous, next) {
      logger.wtf('TestConnectionState: $previous -> $next');
    });
    PrinterAddState printerAddState = ref.watch(printerAddViewControllerProvider);
    var machineToAdd = printerAddState.machineToAdd;
    if (machineToAdd == null) {
      throw ArgumentError('Expected the machine to add to be available. However it is null?');
    }

    TestConnectionState s;
    HttpClient httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    JsonRpcClientBuilder jsonRpcClientBuilder = JsonRpcClientBuilder()
      ..headers = machineToAdd.httpHeaders
      ..timeout = httpClient.connectionTimeout!
      ..uri = machineToAdd.wsUri
      ..trustSelfSignedCertificate = machineToAdd.trustUntrustedCertificate;
    // ..headers = machineToAdd.headers;

    s = TestConnectionState(
      wsUri: machineToAdd.wsUri,
      httpUri: machineToAdd.httpUri,
    );

    _httpClient = httpClient;
    _client = jsonRpcClientBuilder.build();
    _httpHeaders = machineToAdd.headerWithApiKey;
    _testWebsocket();
    _testHttp(s.httpUri);
    return s;
  }

  proceed() {
    ref.read(printerAddViewControllerProvider.notifier).submitMachine();
  }

  _testWebsocket() async {
    _client.openChannel();
    _testConnectionRPCState = _client.stateStream.listen((event) {
      state = switch (event) {
        ClientState.connected => state.copyWith(wsState: event, wsError: null),
        ClientState.error => state.copyWith(
            wsState: event, wsError: _client.errorReason?.toString() ?? 'Unknown Error'),
        _ => state.copyWith(wsState: event),
      };
      if (event == ClientState.connected || event == ClientState.error) {
        _testConnectionRPCState?.cancel();
        _client.dispose();

        logger.i('Test connection got a result, cancel stream and dispose client.');
      }
    });
  }

  _testHttp(Uri? httpUri) async {
    if (httpUri == null) return;
    try {
      var request = await _httpClient.getUrl(httpUri.appendPath('/access/info'));
      _httpHeaders.forEach((key, value) {
        request.headers.add(key, value);
      });
      var response = await request.close();

      var isSuccess = response.statusCode == 200;
      state = state.copyWith(
          httpState: isSuccess,
          httpError: isSuccess ? null : '${response.statusCode} - ${response.reasonPhrase}');
    } catch (e) {
      logger.w('_testHttp returned error', e);

      state = state.copyWith(httpState: false, httpError: e.toString());
    }
  }

  dispose() {
    _testConnectionRPCState?.cancel();
    _client.dispose();
  }
}

@freezed
class PrinterAddState with _$PrinterAddState {
  const PrinterAddState._();

  const factory PrinterAddState({
    String? nonSupporterError,
    @Default(false) bool isExpert,
    @Default(0) int step,
    Machine? machineToAdd,
    // This might be usefull later maybe.
    bool? addedMachine,
  }) = _PrinterAddState;
}

@freezed
class SimpleFormState with _$SimpleFormState {
  const SimpleFormState._();

  const factory SimpleFormState({
    // String? displayName,
    // Uri? wsUri,
    // Uri? httpUri,
    // String? apiKey,
    // @Default(false) bool isValid,
    @Default(false) isHttps,
  }) = _SimpleFormState;

  String get scheme => (isHttps) ? 'https://' : 'http://';
}

@freezed
class AdvancedFormState with _$AdvancedFormState {
  const AdvancedFormState._();

  const factory AdvancedFormState({
    Uri? wsUriFromHttpUri,
    @Default({}) Map<String, String> headers,
  }) = _AdvancedFormState;
}

@freezed
class TestConnectionState with _$TestConnectionState {
  const TestConnectionState._();

  const factory TestConnectionState({
    Uri? wsUri,
    ClientState? wsState,
    String? wsError,
    Uri? httpUri,
    bool? httpState,
    String? httpError,
  }) = _TestConnectionState;

  bool get hasResults => wsState != null && httpState != null;

  bool get combinedResult => wsState == ClientState.connected && httpState == true;

  String get wsStateText => tr(switch (wsState) {
        ClientState.connected => 'general.valid',
        ClientState.error => 'general.invalid',
        _ => 'general.unknown'
      });

  String get httpStateText => tr(switch (httpState) {
        true => 'general.valid',
        false => 'general.invalid',
        _ => 'general.unknown'
      });

  Color wsStateColor(ThemeData theme) => switch (wsState) {
        ClientState.connected => theme.extension<CustomColors>()?.success ?? Colors.green,
        ClientState.error => theme.extension<CustomColors>()?.danger ?? Colors.yellow,
        _ => theme.extension<CustomColors>()?.info ?? Colors.lightBlue
      };

  Color httpStateColor(ThemeData theme) => switch (httpState) {
        true => theme.extension<CustomColors>()?.success ?? Colors.green,
        false => theme.extension<CustomColors>()?.danger ?? Colors.yellow,
        _ => theme.extension<CustomColors>()?.info ?? Colors.lightBlue
      };
}
