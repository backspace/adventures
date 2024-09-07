// Mocks generated by Mockito 5.4.4 from annotations
// in waydowntown/test/games/bluetooth_collector_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:flutter_blue_plus/flutter_blue_plus.dart' as _i2;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i5;
import 'package:waydowntown/flutter_blue_plus_mockable.dart' as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakePhySupport_0 extends _i1.SmartFake implements _i2.PhySupport {
  _FakePhySupport_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeDeviceIdentifier_1 extends _i1.SmartFake
    implements _i2.DeviceIdentifier {
  _FakeDeviceIdentifier_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeBluetoothDevice_2 extends _i1.SmartFake
    implements _i2.BluetoothDevice {
  _FakeBluetoothDevice_2(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeAdvertisementData_3 extends _i1.SmartFake
    implements _i2.AdvertisementData {
  _FakeAdvertisementData_3(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeDateTime_4 extends _i1.SmartFake implements DateTime {
  _FakeDateTime_4(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [FlutterBluePlusMockable].
///
/// See the documentation for Mockito's code generation for more information.
class MockFlutterBluePlusMockable extends _i1.Mock
    implements _i3.FlutterBluePlusMockable {
  MockFlutterBluePlusMockable() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Stream<_i2.BluetoothAdapterState> get adapterState => (super.noSuchMethod(
        Invocation.getter(#adapterState),
        returnValue: _i4.Stream<_i2.BluetoothAdapterState>.empty(),
      ) as _i4.Stream<_i2.BluetoothAdapterState>);

  @override
  _i4.Stream<List<_i2.ScanResult>> get scanResults => (super.noSuchMethod(
        Invocation.getter(#scanResults),
        returnValue: _i4.Stream<List<_i2.ScanResult>>.empty(),
      ) as _i4.Stream<List<_i2.ScanResult>>);

  @override
  _i4.Stream<List<_i2.ScanResult>> get onScanResults => (super.noSuchMethod(
        Invocation.getter(#onScanResults),
        returnValue: _i4.Stream<List<_i2.ScanResult>>.empty(),
      ) as _i4.Stream<List<_i2.ScanResult>>);

  @override
  bool get isScanningNow => (super.noSuchMethod(
        Invocation.getter(#isScanningNow),
        returnValue: false,
      ) as bool);

  @override
  _i4.Stream<bool> get isScanning => (super.noSuchMethod(
        Invocation.getter(#isScanning),
        returnValue: _i4.Stream<bool>.empty(),
      ) as _i4.Stream<bool>);

  @override
  _i2.LogLevel get logLevel => (super.noSuchMethod(
        Invocation.getter(#logLevel),
        returnValue: _i2.LogLevel.none,
      ) as _i2.LogLevel);

  @override
  _i4.Future<bool> get isSupported => (super.noSuchMethod(
        Invocation.getter(#isSupported),
        returnValue: _i4.Future<bool>.value(false),
      ) as _i4.Future<bool>);

  @override
  _i4.Future<String> get adapterName => (super.noSuchMethod(
        Invocation.getter(#adapterName),
        returnValue: _i4.Future<String>.value(_i5.dummyValue<String>(
          this,
          Invocation.getter(#adapterName),
        )),
      ) as _i4.Future<String>);

  @override
  List<_i2.BluetoothDevice> get connectedDevices => (super.noSuchMethod(
        Invocation.getter(#connectedDevices),
        returnValue: <_i2.BluetoothDevice>[],
      ) as List<_i2.BluetoothDevice>);

  @override
  _i4.Future<List<_i2.BluetoothDevice>> get systemDevices =>
      (super.noSuchMethod(
        Invocation.getter(#systemDevices),
        returnValue: _i4.Future<List<_i2.BluetoothDevice>>.value(
            <_i2.BluetoothDevice>[]),
      ) as _i4.Future<List<_i2.BluetoothDevice>>);

  @override
  _i4.Future<List<_i2.BluetoothDevice>> get bondedDevices =>
      (super.noSuchMethod(
        Invocation.getter(#bondedDevices),
        returnValue: _i4.Future<List<_i2.BluetoothDevice>>.value(
            <_i2.BluetoothDevice>[]),
      ) as _i4.Future<List<_i2.BluetoothDevice>>);

  @override
  _i4.Future<void> startScan({
    List<_i2.Guid>? withServices = const [],
    Duration? timeout,
    Duration? removeIfGone,
    bool? continuousUpdates = false,
    bool? oneByOne = false,
    bool? androidUsesFineLocation = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #startScan,
          [],
          {
            #withServices: withServices,
            #timeout: timeout,
            #removeIfGone: removeIfGone,
            #continuousUpdates: continuousUpdates,
            #oneByOne: oneByOne,
            #androidUsesFineLocation: androidUsesFineLocation,
          },
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> stopScan() => (super.noSuchMethod(
        Invocation.method(
          #stopScan,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  void setLogLevel(
    _i2.LogLevel? level, {
    dynamic color = true,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #setLogLevel,
          [level],
          {#color: color},
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i4.Future<void> turnOn({int? timeout = 60}) => (super.noSuchMethod(
        Invocation.method(
          #turnOn,
          [],
          {#timeout: timeout},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<_i2.PhySupport> getPhySupport() => (super.noSuchMethod(
        Invocation.method(
          #getPhySupport,
          [],
        ),
        returnValue: _i4.Future<_i2.PhySupport>.value(_FakePhySupport_0(
          this,
          Invocation.method(
            #getPhySupport,
            [],
          ),
        )),
      ) as _i4.Future<_i2.PhySupport>);
}

/// A class which mocks [BluetoothDevice].
///
/// See the documentation for Mockito's code generation for more information.
class MockBluetoothDevice extends _i1.Mock implements _i2.BluetoothDevice {
  MockBluetoothDevice() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.DeviceIdentifier get remoteId => (super.noSuchMethod(
        Invocation.getter(#remoteId),
        returnValue: _FakeDeviceIdentifier_1(
          this,
          Invocation.getter(#remoteId),
        ),
      ) as _i2.DeviceIdentifier);

  @override
  String get platformName => (super.noSuchMethod(
        Invocation.getter(#platformName),
        returnValue: _i5.dummyValue<String>(
          this,
          Invocation.getter(#platformName),
        ),
      ) as String);

  @override
  String get advName => (super.noSuchMethod(
        Invocation.getter(#advName),
        returnValue: _i5.dummyValue<String>(
          this,
          Invocation.getter(#advName),
        ),
      ) as String);

  @override
  List<_i2.BluetoothService> get servicesList => (super.noSuchMethod(
        Invocation.getter(#servicesList),
        returnValue: <_i2.BluetoothService>[],
      ) as List<_i2.BluetoothService>);

  @override
  bool get isAutoConnectEnabled => (super.noSuchMethod(
        Invocation.getter(#isAutoConnectEnabled),
        returnValue: false,
      ) as bool);

  @override
  bool get isConnected => (super.noSuchMethod(
        Invocation.getter(#isConnected),
        returnValue: false,
      ) as bool);

  @override
  bool get isDisconnected => (super.noSuchMethod(
        Invocation.getter(#isDisconnected),
        returnValue: false,
      ) as bool);

  @override
  _i4.Stream<_i2.BluetoothConnectionState> get connectionState =>
      (super.noSuchMethod(
        Invocation.getter(#connectionState),
        returnValue: _i4.Stream<_i2.BluetoothConnectionState>.empty(),
      ) as _i4.Stream<_i2.BluetoothConnectionState>);

  @override
  int get mtuNow => (super.noSuchMethod(
        Invocation.getter(#mtuNow),
        returnValue: 0,
      ) as int);

  @override
  _i4.Stream<int> get mtu => (super.noSuchMethod(
        Invocation.getter(#mtu),
        returnValue: _i4.Stream<int>.empty(),
      ) as _i4.Stream<int>);

  @override
  _i4.Stream<void> get onServicesReset => (super.noSuchMethod(
        Invocation.getter(#onServicesReset),
        returnValue: _i4.Stream<void>.empty(),
      ) as _i4.Stream<void>);

  @override
  _i4.Stream<_i2.BluetoothBondState> get bondState => (super.noSuchMethod(
        Invocation.getter(#bondState),
        returnValue: _i4.Stream<_i2.BluetoothBondState>.empty(),
      ) as _i4.Stream<_i2.BluetoothBondState>);

  @override
  _i4.Stream<bool> get isDiscoveringServices => (super.noSuchMethod(
        Invocation.getter(#isDiscoveringServices),
        returnValue: _i4.Stream<bool>.empty(),
      ) as _i4.Stream<bool>);

  @override
  _i2.DeviceIdentifier get id => (super.noSuchMethod(
        Invocation.getter(#id),
        returnValue: _FakeDeviceIdentifier_1(
          this,
          Invocation.getter(#id),
        ),
      ) as _i2.DeviceIdentifier);

  @override
  String get localName => (super.noSuchMethod(
        Invocation.getter(#localName),
        returnValue: _i5.dummyValue<String>(
          this,
          Invocation.getter(#localName),
        ),
      ) as String);

  @override
  String get name => (super.noSuchMethod(
        Invocation.getter(#name),
        returnValue: _i5.dummyValue<String>(
          this,
          Invocation.getter(#name),
        ),
      ) as String);

  @override
  _i4.Stream<_i2.BluetoothConnectionState> get state => (super.noSuchMethod(
        Invocation.getter(#state),
        returnValue: _i4.Stream<_i2.BluetoothConnectionState>.empty(),
      ) as _i4.Stream<_i2.BluetoothConnectionState>);

  @override
  _i4.Stream<List<_i2.BluetoothService>> get servicesStream =>
      (super.noSuchMethod(
        Invocation.getter(#servicesStream),
        returnValue: _i4.Stream<List<_i2.BluetoothService>>.empty(),
      ) as _i4.Stream<List<_i2.BluetoothService>>);

  @override
  _i4.Stream<List<_i2.BluetoothService>> get services => (super.noSuchMethod(
        Invocation.getter(#services),
        returnValue: _i4.Stream<List<_i2.BluetoothService>>.empty(),
      ) as _i4.Stream<List<_i2.BluetoothService>>);

  @override
  void cancelWhenDisconnected(
    _i4.StreamSubscription<dynamic>? subscription, {
    bool? next = false,
    bool? delayed = false,
  }) =>
      super.noSuchMethod(
        Invocation.method(
          #cancelWhenDisconnected,
          [subscription],
          {
            #next: next,
            #delayed: delayed,
          },
        ),
        returnValueForMissingStub: null,
      );

  @override
  _i4.Future<void> connect({
    Duration? timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool? autoConnect = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #connect,
          [],
          {
            #timeout: timeout,
            #mtu: mtu,
            #autoConnect: autoConnect,
          },
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> disconnect({
    int? timeout = 35,
    bool? queue = true,
    int? androidDelay = 2000,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #disconnect,
          [],
          {
            #timeout: timeout,
            #queue: queue,
            #androidDelay: androidDelay,
          },
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<List<_i2.BluetoothService>> discoverServices({
    bool? subscribeToServicesChanged = true,
    int? timeout = 15,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #discoverServices,
          [],
          {
            #subscribeToServicesChanged: subscribeToServicesChanged,
            #timeout: timeout,
          },
        ),
        returnValue: _i4.Future<List<_i2.BluetoothService>>.value(
            <_i2.BluetoothService>[]),
      ) as _i4.Future<List<_i2.BluetoothService>>);

  @override
  _i4.Future<int> readRssi({int? timeout = 15}) => (super.noSuchMethod(
        Invocation.method(
          #readRssi,
          [],
          {#timeout: timeout},
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<int> requestMtu(
    int? desiredMtu, {
    double? predelay = 0.35,
    int? timeout = 15,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #requestMtu,
          [desiredMtu],
          {
            #predelay: predelay,
            #timeout: timeout,
          },
        ),
        returnValue: _i4.Future<int>.value(0),
      ) as _i4.Future<int>);

  @override
  _i4.Future<void> requestConnectionPriority(
          {required _i2.ConnectionPriority? connectionPriorityRequest}) =>
      (super.noSuchMethod(
        Invocation.method(
          #requestConnectionPriority,
          [],
          {#connectionPriorityRequest: connectionPriorityRequest},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> setPreferredPhy({
    required int? txPhy,
    required int? rxPhy,
    required _i2.PhyCoding? option,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #setPreferredPhy,
          [],
          {
            #txPhy: txPhy,
            #rxPhy: rxPhy,
            #option: option,
          },
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> createBond({int? timeout = 90}) => (super.noSuchMethod(
        Invocation.method(
          #createBond,
          [],
          {#timeout: timeout},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> removeBond({int? timeout = 30}) => (super.noSuchMethod(
        Invocation.method(
          #removeBond,
          [],
          {#timeout: timeout},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> clearGattCache() => (super.noSuchMethod(
        Invocation.method(
          #clearGattCache,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> pair() => (super.noSuchMethod(
        Invocation.method(
          #pair,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);
}

/// A class which mocks [ScanResult].
///
/// See the documentation for Mockito's code generation for more information.
class MockScanResult extends _i1.Mock implements _i2.ScanResult {
  MockScanResult() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i2.BluetoothDevice get device => (super.noSuchMethod(
        Invocation.getter(#device),
        returnValue: _FakeBluetoothDevice_2(
          this,
          Invocation.getter(#device),
        ),
      ) as _i2.BluetoothDevice);

  @override
  _i2.AdvertisementData get advertisementData => (super.noSuchMethod(
        Invocation.getter(#advertisementData),
        returnValue: _FakeAdvertisementData_3(
          this,
          Invocation.getter(#advertisementData),
        ),
      ) as _i2.AdvertisementData);

  @override
  int get rssi => (super.noSuchMethod(
        Invocation.getter(#rssi),
        returnValue: 0,
      ) as int);

  @override
  DateTime get timeStamp => (super.noSuchMethod(
        Invocation.getter(#timeStamp),
        returnValue: _FakeDateTime_4(
          this,
          Invocation.getter(#timeStamp),
        ),
      ) as DateTime);
}
