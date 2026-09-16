import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'gm700sb_decoder.dart';
import 'gm700sb_protocol.dart';
import 'gm700sb_record.dart';

class Gm700sbMetadataResponses {
  final List<int> brand;
  final List<int> model;
  final List<int> meterSetting;
  final List<int> firmware;

  Gm700sbMetadataResponses({
    required List<int> brand,
    required List<int> model,
    required List<int> meterSetting,
    required List<int> firmware,
  }) : brand = List<int>.unmodifiable(
         brand,
       ),
       model = List<int>.unmodifiable(
         model,
       ),
       meterSetting =
           List<int>.unmodifiable(
             meterSetting,
           ),
       firmware =
           List<int>.unmodifiable(
             firmware,
           );
}

class Gm700sbSyncResult {
  final Gm700sbMeterState meterState;

  final int savedRuidBefore;

  /// Number of records determined by:
  ///
  /// current RUID - saved RUID
  final int pendingCount;

  /// The RUID that may become the new checkpoint
  /// only after the caller successfully accepts/imports
  /// every returned record.
  final int candidateNextRuid;

  final List<Gm700sbRecord> records;

  Gm700sbSyncResult({
    required this.meterState,
    required this.savedRuidBefore,
    required this.pendingCount,
    required this.candidateNextRuid,
    required List<Gm700sbRecord>
    records,
  }) : records =
           List<
             Gm700sbRecord
           >.unmodifiable(records);

  bool get hasNewRecords =>
      records.isNotEmpty;
}

class Gm700sbBleService {
  BluetoothDevice? _device;

  BluetoothCharacteristic? _fee1;
  BluetoothCharacteristic? _fee2;
  BluetoothCharacteristic? _fee3;

  StreamSubscription<List<int>>?
  _fee2Subscription;

  final StreamController<List<int>>
  _notificationController =
      StreamController<
        List<int>
      >.broadcast();

  bool _pclOnSent = false;

  bool _transactionInProgress = false;

  BluetoothDevice?
  get connectedDevice => _device;

  bool get isConnected =>
      _device != null;

  bool get isReady =>
      _device != null &&
      _fee1 != null &&
      _fee2 != null &&
      _fee3 != null;

  bool get pclOnSent => _pclOnSent;

  Stream<List<int>> get notifications =>
      _notificationController.stream;

  static bool _matchesUuid(
    String uuid,
    String shortUuid,
  ) {
    final value = uuid.toLowerCase();

    final shortValue = shortUuid
        .toLowerCase();

    return value == shortValue ||
        value ==
            '0000$shortValue-0000-1000-8000-00805f9b34fb';
  }

  static bool _advertisesFee0(
    ScanResult result,
  ) {
    return result
        .advertisementData
        .serviceUuids
        .any(
          (uuid) => _matchesUuid(
            uuid.str,
            'fee0',
          ),
        );
  }

  Future<List<ScanResult>>
  scanForMeters({
    Duration timeout = const Duration(
      seconds: 15,
    ),
  }) async {
    final scanPermission =
        await Permission.bluetoothScan
            .request();

    final connectPermission =
        await Permission
            .bluetoothConnect
            .request();

    if (!scanPermission.isGranted ||
        !connectPermission.isGranted) {
      throw StateError(
        'Bluetooth permissions not granted.',
      );
    }

    final adapterState =
        await FlutterBluePlus
            .adapterState
            .first;

    if (adapterState !=
        BluetoothAdapterState.on) {
      throw StateError(
        'Bluetooth adapter is not ON.',
      );
    }

    final devices =
        <String, ScanResult>{};

    final subscription = FlutterBluePlus
        .scanResults
        .listen((results) {
          for (final result
              in results) {
            if (!_advertisesFee0(
              result,
            )) {
              continue;
            }

            devices[result
                    .device
                    .remoteId
                    .str] =
                result;
          }
        });

    try {
      await FlutterBluePlus.stopScan();

      await FlutterBluePlus.startScan(
        timeout: timeout,
      );

      await Future.delayed(timeout);

      await FlutterBluePlus.stopScan();
    } finally {
      await subscription.cancel();
    }

    final results = devices.values
        .toList();

    results.sort(
      (a, b) =>
          b.rssi.compareTo(a.rssi),
    );

    return results;
  }

  Future<void> connectAndPrepare(
    ScanResult result,
  ) async {
    if (_device != null) {
      throw StateError(
        'A GM700SB device is already connected.',
      );
    }

    final device = result.device;

    try {
      await FlutterBluePlus.stopScan();

      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(
          seconds: 15,
        ),
      );

      final services = await device
          .discoverServices();

      BluetoothCharacteristic? fee1;
      BluetoothCharacteristic? fee2;
      BluetoothCharacteristic? fee3;

      for (final service in services) {
        if (!_matchesUuid(
          service.uuid.str,
          'fee0',
        )) {
          continue;
        }

        for (final characteristic
            in service
                .characteristics) {
          final uuid =
              characteristic.uuid.str;

          if (_matchesUuid(
            uuid,
            'fee1',
          )) {
            fee1 = characteristic;
          }

          if (_matchesUuid(
            uuid,
            'fee2',
          )) {
            fee2 = characteristic;
          }

          if (_matchesUuid(
            uuid,
            'fee3',
          )) {
            fee3 = characteristic;
          }
        }

        break;
      }

      if (fee1 == null ||
          fee2 == null ||
          fee3 == null) {
        throw StateError(
          'Required GM700SB '
          'FEE1/FEE2/FEE3 '
          'characteristics were not found.',
        );
      }

      _device = device;
      _fee1 = fee1;
      _fee2 = fee2;
      _fee3 = fee3;

      await _subscribeFee2();
    } catch (_) {
      try {
        await device.disconnect();
      } catch (_) {}

      _clearConnectionState();

      rethrow;
    }
  }

  Future<void> _subscribeFee2() async {
    final device = _device;

    final fee2 = _fee2;

    if (device == null ||
        fee2 == null) {
      throw StateError(
        'GM700SB device/FEE2 unavailable.',
      );
    }

    await _fee2Subscription?.cancel();

    _fee2Subscription = fee2
        .onValueReceived
        .listen(
          (value) {
            if (_notificationController
                .isClosed) {
              return;
            }

            _notificationController.add(
              List<int>.unmodifiable(
                value,
              ),
            );
          },
          onError: (Object error) {
            if (!_notificationController
                .isClosed) {
              _notificationController
                  .addError(error);
            }
          },
        );

    device.cancelWhenDisconnected(
      _fee2Subscription!,
    );

    final enabled = await fee2
        .setNotifyValue(true);

    if (!enabled || !fee2.isNotifying) {
      await _fee2Subscription?.cancel();

      _fee2Subscription = null;

      throw StateError(
        'Failed to enable GM700SB '
        'FEE2 notifications.',
      );
    }
  }

  Future<void> sendPclOn() async {
    final fee1 = _fee1;

    if (_device == null ||
        fee1 == null) {
      throw StateError(
        'GM700SB is not ready for PCL ON.',
      );
    }

    if (_pclOnSent) {
      return;
    }

    await fee1.write(
      Gm700sbProtocol.pclOnCommand,
      withoutResponse: false,
    );

    _pclOnSent = true;
  }

  Future<List<int>>
  _sendFee3CommandAndWait({
    required List<int> command,
    bool Function(List<int>)?
    responseMatcher,
    Duration timeout = const Duration(
      seconds: 5,
    ),
  }) async {
    final fee3 = _fee3;

    if (_device == null ||
        fee3 == null) {
      throw StateError(
        'GM700SB FEE3 is unavailable.',
      );
    }

    if (!_pclOnSent) {
      throw StateError(
        'GM700SB PCL ON must be sent '
        'before FEE3 commands.',
      );
    }

    if (_transactionInProgress) {
      throw StateError(
        'Another GM700SB transaction '
        'is already in progress.',
      );
    }

    _transactionInProgress = true;

    StreamSubscription<List<int>>?
    responseSubscription;

    final completer =
        Completer<List<int>>();

    try {
      responseSubscription =
          notifications.listen(
            (value) {
              if (responseMatcher !=
                      null &&
                  !responseMatcher(
                    value,
                  )) {
                return;
              }

              if (!completer
                  .isCompleted) {
                completer.complete(
                  List<int>.from(value),
                );
              }
            },
            onError: (Object error) {
              if (!completer
                  .isCompleted) {
                completer.completeError(
                  error,
                );
              }
            },
          );

      await Future.delayed(
        const Duration(seconds: 1),
      );

      await fee3.write(
        command,
        withoutResponse: false,
      );

      final response = await completer
          .future
          .timeout(timeout);

      return List<int>.unmodifiable(
        response,
      );
    } finally {
      await responseSubscription
          ?.cancel();

      _transactionInProgress = false;
    }
  }

  Future<List<int>>
  queryBrandResponse() {
    return _sendFee3CommandAndWait(
      command: Gm700sbProtocol
          .getBrandNameCommand,
    );
  }

  Future<List<int>>
  queryModelResponse() {
    return _sendFee3CommandAndWait(
      command: Gm700sbProtocol
          .getModelNameCommand,
    );
  }

  Future<List<int>>
  queryMeterSettingResponse() {
    return _sendFee3CommandAndWait(
      command: Gm700sbProtocol
          .getMeterSettingCommand,
    );
  }

  Future<List<int>>
  queryFirmwareResponse() {
    return _sendFee3CommandAndWait(
      command: Gm700sbProtocol
          .getFirmwareVersionCommand,
    );
  }

  Future<Gm700sbMetadataResponses>
  queryMetadata() async {
    final brand =
        await queryBrandResponse();

    final model =
        await queryModelResponse();

    final meterSetting =
        await queryMeterSettingResponse();

    final firmware =
        await queryFirmwareResponse();

    return Gm700sbMetadataResponses(
      brand: brand,
      model: model,
      meterSetting: meterSetting,
      firmware: firmware,
    );
  }

  Future<Gm700sbMeterState>
  queryMeterState() async {
    final response =
        await _sendFee3CommandAndWait(
          command: Gm700sbProtocol
              .getRuidTotalLastCommand,
          responseMatcher: (value) {
            return value.length == 13 &&
                value[0] == 0x01 &&
                value[1] == 0x01 &&
                value[2] == 0x4F &&
                value[3] == 0xCC;
          },
        );

    final protocolPacket = response
        .sublist(2);

    return Gm700sbProtocol.decodeMeterStatePacket(
      protocolPacket,
    );
  }

  Future<Gm700sbRecord>
  _requestOneRecord(
    int count, {
    Duration timeout = const Duration(
      seconds: 8,
    ),
  }) async {
    final fee3 = _fee3;

    if (_device == null ||
        fee3 == null) {
      throw StateError(
        'GM700SB FEE3 is unavailable.',
      );
    }

    if (!_pclOnSent) {
      throw StateError(
        'GM700SB PCL ON must be sent '
        'before record requests.',
      );
    }

    if (_transactionInProgress) {
      throw StateError(
        'Another GM700SB transaction '
        'is already in progress.',
      );
    }

    final command =
        Gm700sbProtocol.buildOneRecordCommand(
          count,
        );

    _transactionInProgress = true;

    StreamSubscription<List<int>>?
    responseSubscription;

    final completer =
        Completer<Gm700sbRecord>();

    final receivedFragments =
        <List<int>>[];

    int? expectedFragmentCount;

    int nextExpectedIndex = 1;

    try {
      responseSubscription = notifications.listen(
        (value) {
          if (completer.isCompleted) {
            return;
          }

          Gm700sbFragment fragment;

          try {
            fragment =
                Gm700sbProtocol.parseBleFragment(
                  value,
                );
          } catch (_) {
            // Ignore unrelated/unsolicited
            // notifications such as the meter
            // identifier packet.
            return;
          }

          if (expectedFragmentCount ==
              null) {
            if (fragment.index != 1) {
              return;
            }

            final protocolBytes =
                fragment.protocolBytes;

            if (protocolBytes.length <
                    2 ||
                protocolBytes[0] !=
                    0x4F ||
                protocolBytes[1] !=
                    0x9E) {
              // Not a ONE RECORD response.
              return;
            }

            expectedFragmentCount =
                fragment.totalCount;

            nextExpectedIndex = 1;
          }

          if (fragment.totalCount !=
              expectedFragmentCount) {
            // Ignore a notification that does
            // not belong to the active response.
            return;
          }

          if (fragment.index <
              nextExpectedIndex) {
            // Duplicate fragment. Ignore it.
            return;
          }

          if (fragment.index >
              nextExpectedIndex) {
            completer.completeError(
              FormatException(
                'GM700SB fragment sequence '
                'error. Expected fragment '
                '$nextExpectedIndex, '
                'received ${fragment.index}.',
              ),
            );

            return;
          }

          receivedFragments.add(
            List<int>.from(value),
          );

          nextExpectedIndex++;

          if (receivedFragments
                  .length !=
              expectedFragmentCount) {
            return;
          }

          try {
            final packet =
                Gm700sbProtocol.assembleFragments(
                  receivedFragments,
                );

            final payload =
                Gm700sbProtocol.extractOneRecordPayload(
                  packet,
                );

            final record =
                Gm700sbDecoder.decodePayload(
                  payload,
                );

            completer.complete(record);
          } catch (error, stackTrace) {
            completer.completeError(
              error,
              stackTrace,
            );
          }
        },
        onError:
            (
              Object error,
              StackTrace stackTrace,
            ) {
              if (!completer
                  .isCompleted) {
                completer.completeError(
                  error,
                  stackTrace,
                );
              }
            },
      );

      // Preserve the timing that worked
      // during the physical reverse-
      // engineering tests.
      await Future.delayed(
        const Duration(seconds: 1),
      );

      await fee3.write(
        command,
        withoutResponse: false,
      );

      return await completer.future
          .timeout(timeout);
    } finally {
      await responseSubscription
          ?.cancel();

      _transactionInProgress = false;
    }
  }

  /// Reads records that were created after [savedRuid].
  ///
  /// IMPORTANT:
  /// This method does NOT persist or advance
  /// the checkpoint itself.
  ///
  /// The caller should only store
  /// result.candidateNextRuid after every returned
  /// record has been successfully accepted/imported.
  Future<Gm700sbSyncResult>
  syncNewRecords({
    required int savedRuid,
    Gm700sbMeterState? knownMeterState,
  }) async {
    if (savedRuid < 0) {
      throw RangeError.value(
        savedRuid,
        'savedRuid',
        'Saved RUID cannot be negative.',
      );
    }

    final meterState =
        knownMeterState ??
        await queryMeterState();

    final currentRuid = meterState.ruid;

    if (currentRuid < savedRuid) {
      throw StateError(
        'Current meter RUID '
        '($currentRuid) is lower than '
        'saved RUID ($savedRuid). '
        'The checkpoint may belong to '
        'another meter or the meter state '
        'may have been reset.',
      );
    }

    final pending =
        currentRuid - savedRuid;

    if (pending == 0) {
      return Gm700sbSyncResult(
        meterState: meterState,
        savedRuidBefore: savedRuid,
        pendingCount: 0,
        candidateNextRuid: currentRuid,
        records:
            const <Gm700sbRecord>[],
      );
    }

    if (pending >
        meterState.totalRecords) {
      throw StateError(
        'GM700SB checkpoint is too old '
        'for the records currently stored '
        'in the meter. '
        'Pending=$pending, '
        'TOTAL=${meterState.totalRecords}.',
      );
    }

    final records = <Gm700sbRecord>[];

    // Verified official-style sequence:
    //
    // pending = 2
    // request count 2 -> older pending record
    // request count 1 -> newest pending record
    //
    // Therefore generalize to:
    //
    // pending ... 3, 2, 1
    for (
      var count = pending;
      count >= 1;
      count--
    ) {
      final record =
          await _requestOneRecord(
            count,
          );

      records.add(record);
    }

    return Gm700sbSyncResult(
      meterState: meterState,
      savedRuidBefore: savedRuid,
      pendingCount: pending,
      candidateNextRuid: currentRuid,
      records: records,
    );
  }

  Future<void> disconnect() async {
    final device = _device;

    await _fee2Subscription?.cancel();

    _fee2Subscription = null;

    if (device != null) {
      try {
        await device.disconnect();
      } finally {
        _clearConnectionState();
      }
    } else {
      _clearConnectionState();
    }
  }

  void _clearConnectionState() {
    _device = null;

    _fee1 = null;
    _fee2 = null;
    _fee3 = null;

    _pclOnSent = false;

    _transactionInProgress = false;
  }

  Future<void> dispose() async {
    await disconnect();

    if (!_notificationController
        .isClosed) {
      await _notificationController
          .close();
    }
  }
}
