/*
 * Copyright (c) 2023. Patrick Schmidt.
 * All rights reserved.
 */

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mobileraker/data/converters/integer_converter.dart';
import 'package:mobileraker/data/dto/config/led/config_led.dart';

part 'config_dotstar.freezed.dart';
part 'config_dotstar.g.dart';

@freezed
class ConfigDotstar extends ConfigLed with _$ConfigDotstar {
  const ConfigDotstar._();

  const factory ConfigDotstar({
    required String name,
    @JsonKey(name: 'data_pin', required: true) required String dataPin,
    @JsonKey(name: 'clock_pin', required: true) required String clkPin,
    @IntegerConverter()
    @JsonKey(name: 'chain_count', required: true)
        required int chainCount,
    @JsonKey(name: 'initial_RED') @Default(0) double initialRed,
    @JsonKey(name: 'initial_GREEN') @Default(0) double initialGreen,
    @JsonKey(name: 'initial_BLUE') @Default(0) double initialBlue,
  }) = _ConfigDotstar;

  factory ConfigDotstar.fromJson(String name, Map<String, dynamic> json) =>
      _$ConfigDotstarFromJson({...json, 'name': name});

  @override
  bool get isAddressable => true;


  @override
  bool get hasWhite => false;
}
