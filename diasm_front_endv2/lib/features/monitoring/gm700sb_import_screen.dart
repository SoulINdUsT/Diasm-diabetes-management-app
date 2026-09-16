import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/gm700sb/gm700sb_ble_service.dart';
import '../../core/gm700sb/gm700sb_protocol.dart';
import '../../core/gm700sb/gm700sb_record.dart';
import '../../core/monitoring_repository.dart';

class Gm700sbImportScreen
    extends StatefulWidget {
  static const routeName =
      '/monitoring/gm700sb';

  const Gm700sbImportScreen({
    super.key,
  });

  @override
  State<Gm700sbImportScreen>
  createState() =>
      _Gm700sbImportScreenState();
}

class _Gm700sbImportScreenState
    extends State<Gm700sbImportScreen> {
  final Gm700sbBleService _bleService =
      Gm700sbBleService();

  final MonitoringRepository
  _monitoringRepository =
      MonitoringRepository();

  List<ScanResult> _scanResults = [];

  bool _isScanning = false;
  bool _isPreviewing = false;
  bool _isLoadingCheckpoint = false;
  bool _isImporting = false;

  bool _checkpointRegistered = false;
  bool _importCompleted = false;

  String? _connectingDeviceId;

  String? _connectedMeterIdentifier;
  String? _connectedBleRemoteId;

  int? _savedRuid;

  Gm700sbMeterState? _meterState;
  Gm700sbSyncResult? _previewResult;

  String? _importMessage;

  String _status =
      'Turn on your GM700SB meter, then scan.';

  // =====================================================
  // DEVICE NAME
  // =====================================================

  String _deviceName(
    ScanResult result,
  ) {
    final advertisedName = result
        .advertisementData
        .advName;

    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    if (result
        .device
        .platformName
        .isNotEmpty) {
      return result.device.platformName;
    }

    return 'GM700SB Meter';
  }

  // =====================================================
  // DATE FORMAT
  // =====================================================

  String _formatDateTime(
    DateTime value,
  ) {
    final year = value.year
        .toString()
        .padLeft(4, '0');

    final month = value.month
        .toString()
        .padLeft(2, '0');

    final day = value.day
        .toString()
        .padLeft(2, '0');

    final hour = value.hour
        .toString()
        .padLeft(2, '0');

    final minute = value.minute
        .toString()
        .padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  // =====================================================
  // GM700SB -> DIASM IMPORT PAYLOAD
  // =====================================================

  String _gm700sbRawPayloadHex(
    List<int> bytes,
  ) {
    if (bytes.length != 18) {
      throw StateError(
        'GM700SB record payload must contain '
        'exactly 18 bytes. '
        'Received ${bytes.length}.',
      );
    }

    return bytes
        .map(
          (byte) => (byte & 0xFF)
              .toRadixString(16)
              .padLeft(2, '0')
              .toUpperCase(),
        )
        .join();
  }

  /// The GM700SB marker byte is preserved, but its
  /// meal-context semantics are not considered verified.
  ///
  /// We therefore import the reading using DIAsm's neutral
  /// Custom category instead of claiming BeforeMeal,
  /// AfterMeal, RBS, Bedtime, etc.
  String _gm700sbKind(
    Gm700sbRecord record,
  ) {
    return 'Custom';
  }

  String _gm700sbContext(
    Gm700sbRecord record,
  ) {
    return 'GM700SB raw marker ${record.rawMarker}; '
        'meal context unverified';
  }

  String _gm700sbNote(
    Gm700sbRecord record,
  ) {
    return 'Imported from Bionime RIGHTEST GM700SB. '
        'Raw marker ${record.rawMarker}; '
        'meal-context semantics not verified.';
  }

  Map<String, dynamic>
  _gm700sbImportRecord(
    Gm700sbRecord record,
  ) {
    return {
      'measured_at': record.measuredAt
          .toIso8601String(),

      'kind': _gm700sbKind(record),

      'value_mgdl': record.glucoseMgDl,

      'raw_payload_hex':
          _gm700sbRawPayloadHex(
            record.rawPayload,
          ),

      'context': _gm700sbContext(
        record,
      ),

      'note': _gm700sbNote(record),
    };
  }

  // =====================================================
  // SCAN
  // =====================================================

  Future<void> _scan() async {
    if (_isScanning ||
        _connectingDeviceId != null ||
        _isPreviewing ||
        _isImporting) {
      return;
    }

    if (_bleService.isConnected) {
      setState(() {
        _status =
            'Disconnect the current meter before scanning again.';
      });

      return;
    }

    setState(() {
      _isScanning = true;

      _scanResults = [];

      _meterState = null;
      _previewResult = null;

      _savedRuid = null;

      _checkpointRegistered = false;
      _isLoadingCheckpoint = false;

      _importCompleted = false;
      _importMessage = null;

      _connectedMeterIdentifier = null;
      _connectedBleRemoteId = null;

      _status =
          'Scanning for GM700SB meters...';
    });

    try {
      final results = await _bleService
          .scanForMeters();

      if (!mounted) {
        return;
      }

      setState(() {
        _scanResults = results;

        if (results.isEmpty) {
          _status =
              'No compatible GM700SB meter found.';
        } else {
          _status =
              '${results.length} compatible meter(s) found. '
              'Tap a meter to connect.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Scan failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // =====================================================
  // CONNECT + CHECKPOINT
  // =====================================================

  Future<void> _connect(
    ScanResult result,
  ) async {
    if (_connectingDeviceId != null ||
        _isPreviewing ||
        _isImporting) {
      return;
    }

    if (_bleService.isConnected) {
      setState(() {
        _status =
            'A GM700SB meter is already connected.';
      });

      return;
    }

    final deviceId =
        result.device.remoteId.str;

    final name = _deviceName(result);

    setState(() {
      _connectingDeviceId = deviceId;

      _meterState = null;
      _previewResult = null;

      _savedRuid = null;

      _checkpointRegistered = false;
      _isLoadingCheckpoint = false;

      _importCompleted = false;
      _importMessage = null;

      _connectedMeterIdentifier = null;
      _connectedBleRemoteId = null;

      _status =
          'Connecting to $name...';
    });

    try {
      await _bleService
          .connectAndPrepare(result);

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Connected. Initializing GM700SB...';
      });

      await _bleService.sendPclOn();

      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'GM700SB initialized. '
            'Reading meter state...';
      });

      final meterState =
          await _bleService
              .queryMeterState();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCheckpoint = true;

        _status =
            'Meter state received. '
            'Checking DIAsm sync checkpoint...';
      });

      final checkpoint =
          await _monitoringRepository
              .getGm700sbCheckpoint(
                identifier: name,
              );

      if (!mounted) {
        return;
      }

      final registered =
          checkpoint['registered'] ==
          true;

      final rawSavedRuid =
          checkpoint['last_synced_ruid'];

      int? serverSavedRuid;

      if (rawSavedRuid is num) {
        serverSavedRuid = rawSavedRuid
            .toInt();
      }

      final firstSyncSavedRuid =
          meterState.ruid -
          meterState.totalRecords;

      if (firstSyncSavedRuid < 0) {
        throw StateError(
          'Invalid GM700SB meter state: '
          'RUID ${meterState.ruid}, '
          'TOTAL ${meterState.totalRecords}.',
        );
      }

      final savedRuid =
          serverSavedRuid ??
          firstSyncSavedRuid;

      if (savedRuid < 0) {
        throw StateError(
          'Invalid DIAsm checkpoint: '
          '$savedRuid.',
        );
      }

      if (savedRuid > meterState.ruid) {
        throw StateError(
          'Stored DIAsm checkpoint '
          '$savedRuid is ahead of meter RUID '
          '${meterState.ruid}.',
        );
      }

      final pending =
          meterState.ruid - savedRuid;

      setState(() {
        _meterState = meterState;

        _savedRuid = savedRuid;

        _checkpointRegistered =
            registered;

        _connectedMeterIdentifier =
            name;

        _connectedBleRemoteId =
            deviceId;

        _isLoadingCheckpoint = false;

        if (registered) {
          _status =
              'Connected to $name. '
              'DIAsm checkpoint loaded. '
              '$pending new record(s).';
        } else {
          _status =
              'Connected to $name. '
              'First sync detected. '
              '$pending stored record(s) available.';
        }
      });
    } catch (error) {
      try {
        if (_bleService.isConnected) {
          await _bleService
              .disconnect();
        }
      } catch (_) {
        // Preserve original setup error.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _meterState = null;
        _previewResult = null;

        _savedRuid = null;

        _checkpointRegistered = false;
        _isLoadingCheckpoint = false;

        _importCompleted = false;
        _importMessage = null;

        _connectedMeterIdentifier =
            null;
        _connectedBleRemoteId = null;

        _status =
            'GM700SB connection/setup failed: '
            '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
        });
      }
    }
  }

  // =====================================================
  // PREVIEW
  // =====================================================

  Future<void>
  _previewNewRecords() async {
    final meterState = _meterState;

    final savedRuid = _savedRuid;

    if (meterState == null ||
        savedRuid == null ||
        !_bleService.isConnected ||
        !_bleService.pclOnSent ||
        _isPreviewing ||
        _isImporting ||
        _isLoadingCheckpoint) {
      return;
    }

    setState(() {
      _isPreviewing = true;

      _previewResult = null;

      _importCompleted = false;
      _importMessage = null;

      _status =
          'Reading new glucose records '
          'from GM700SB...';
    });

    try {
      final result = await _bleService
          .syncNewRecords(
            savedRuid: savedRuid,
            knownMeterState: meterState,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _previewResult = result;

        if (result.records.isEmpty) {
          _status =
              'No new glucose records found. '
              'Nothing has been saved.';
        } else {
          _status =
              '${result.records.length} '
              'glucose record(s) retrieved. '
              'Review them before importing.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _previewResult = null;

        _status =
            'Record preview failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewing = false;
        });
      }
    }
  }

  // =====================================================
  // IMPORT TO DIASM
  // =====================================================

  Future<void>
  _importPreviewedRecords() async {
    final result = _previewResult;

    final identifier =
        _connectedMeterIdentifier;

    final bleRemoteId =
        _connectedBleRemoteId;

    if (result == null ||
        result.records.isEmpty ||
        identifier == null ||
        identifier.trim().isEmpty ||
        _isImporting ||
        _importCompleted) {
      return;
    }

    final records = result.records
        .map(_gm700sbImportRecord)
        .toList(growable: false);

    setState(() {
      _isImporting = true;

      _importMessage = null;

      _status =
          'Saving ${records.length} '
          'GM700SB glucose record(s) '
          'to DIAsm...';
    });

    try {
      await _monitoringRepository
          .importGm700sbGlucose(
            identifier: identifier,
            bleRemoteId: bleRemoteId,
            savedRuid:
                result.savedRuidBefore,
            currentRuid: result
                .candidateNextRuid,
            records: records,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        // IMPORTANT:
        // advance the local checkpoint only
        // AFTER the backend transaction succeeds.
        _savedRuid =
            result.candidateNextRuid;

        _checkpointRegistered = true;
        _importCompleted = true;

        _importMessage =
            '${records.length} glucose record(s) '
            'were accepted by DIAsm. '
            'Checkpoint advanced to '
            '${result.candidateNextRuid}.';

        _status =
            'GM700SB import completed successfully.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        // Do NOT advance _savedRuid here.
        _importCompleted = false;

        _importMessage =
            'Import failed. '
            'The DIAsm checkpoint was not advanced.';

        _status =
            'GM700SB import failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  // =====================================================
  // DISCONNECT
  // =====================================================

  Future<void> _disconnect() async {
    if (!_bleService.isConnected ||
        _isPreviewing ||
        _isImporting) {
      return;
    }

    setState(() {
      _status =
          'Disconnecting GM700SB...';
    });

    try {
      await _bleService.disconnect();

      if (!mounted) {
        return;
      }

      setState(() {
        _meterState = null;
        _previewResult = null;

        _savedRuid = null;

        _checkpointRegistered = false;
        _isLoadingCheckpoint = false;

        _importCompleted = false;
        _importMessage = null;

        _connectedMeterIdentifier =
            null;
        _connectedBleRemoteId = null;

        _status = 'Meter disconnected.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status =
            'Disconnect failed: $error';
      });
    }
  }

  // =====================================================
  // DISPOSE
  // =====================================================

  @override
  void dispose() {
    unawaited(_bleService.dispose());

    super.dispose();
  }

  // =====================================================
  // METER STATE CARD
  // =====================================================

  Widget _buildMeterStateCard(
    Gm700sbMeterState meterState,
  ) {
    final savedRuid = _savedRuid;

    final pending = savedRuid == null
        ? null
        : meterState.ruid - savedRuid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                Text(
                  'Meter Ready',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (_connectedMeterIdentifier !=
                null)
              Text(
                'METER: '
                '$_connectedMeterIdentifier',
              ),

            if (_connectedMeterIdentifier !=
                null)
              const SizedBox(height: 4),

            if (_connectedBleRemoteId !=
                null)
              Text(
                'BLE ID: '
                '$_connectedBleRemoteId',
              ),

            if (_connectedBleRemoteId !=
                null)
              const SizedBox(height: 8),

            Text(
              'RUID: ${meterState.ruid}',
            ),

            const SizedBox(height: 4),

            Text(
              'TOTAL RECORDS: '
              '${meterState.totalRecords}',
            ),

            const SizedBox(height: 4),

            Text(
              'LAST TRANSMISSION: '
              '${meterState.lastTransmission}',
            ),

            const Divider(height: 24),

            Text(
              'DIAsm SAVED RUID: '
              '${savedRuid ?? 'Not loaded'}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              'CHECKPOINT: '
              '${_checkpointRegistered ? 'Existing DIAsm checkpoint' : 'First sync'}',
            ),

            const SizedBox(height: 4),

            Text(
              'PENDING RECORDS: '
              '${pending ?? '-'}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isPreviewing ||
                        _isImporting ||
                        _isLoadingCheckpoint ||
                        savedRuid ==
                            null ||
                        _importCompleted
                    ? null
                    : _previewNewRecords,

                icon: _isPreviewing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                      )
                    : const Icon(
                        Icons
                            .download_outlined,
                      ),

                label: Text(
                  _isPreviewing
                      ? 'Reading Records...'
                      : _importCompleted
                      ? 'Import Complete'
                      : 'Preview New Records',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // PREVIEW SUMMARY + IMPORT BUTTON
  // =====================================================

  Widget _buildPreviewSummary(
    Gm700sbSyncResult result,
  ) {
    final hasRecords =
        result.records.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'PREVIEW RESULT',
              style: TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Saved RUID used: '
              '${result.savedRuidBefore}',
            ),

            Text(
              'Current RUID: '
              '${result.meterState.ruid}',
            ),

            Text(
              'Pending: '
              '${result.pendingCount}',
            ),

            Text(
              'Records returned: '
              '${result.records.length}',
            ),

            Text(
              'Candidate next RUID: '
              '${result.candidateNextRuid}',
            ),

            const SizedBox(height: 10),

            if (!_importCompleted)
              Text(
                hasRecords
                    ? 'Review the readings below. '
                          'Nothing is saved until you press Import.'
                    : 'No new records to import.',
                style: TextStyle(
                  color: hasRecords
                      ? Colors.orange
                      : Colors.green,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

            if (_importMessage !=
                null) ...[
              const SizedBox(
                height: 10,
              ),

              Text(
                _importMessage!,
                style: TextStyle(
                  color:
                      _importCompleted
                      ? Colors.green
                      : Colors.red,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],

            if (hasRecords) ...[
              const SizedBox(
                height: 16,
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isImporting ||
                          _isPreviewing ||
                          _importCompleted
                      ? null
                      : _importPreviewedRecords,

                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : Icon(
                          _importCompleted
                              ? Icons
                                    .check
                              : Icons
                                    .save_outlined,
                        ),

                  label: Text(
                    _isImporting
                        ? 'Importing...'
                        : _importCompleted
                        ? 'Imported to DIAsm'
                        : 'Import ${result.records.length} Records to DIAsm',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =====================================================
  // RECORD CARD
  // =====================================================

  Widget _buildRecordCard(
    Gm700sbRecord record,
    int index,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'RECORD ${index + 1}',
              style: const TextStyle(
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .end,
              children: [
                Text(
                  '${record.glucoseMgDl}',
                  style:
                      const TextStyle(
                        fontSize: 30,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                ),

                const SizedBox(
                  width: 6,
                ),

                const Padding(
                  padding:
                      EdgeInsets.only(
                        bottom: 4,
                      ),
                  child: Text(
                    'mg/dL',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors
                          .black54,
                    ),
                  ),
                ),
              ],
            ),

            Text(
              '${record.glucoseMmolL.toStringAsFixed(1)} mmol/L',
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Meter raw marker: '
              '${record.rawMarker}',
            ),

            const SizedBox(height: 4),

            const Text(
              'Meal context: Not verified',
            ),

            const SizedBox(height: 4),

            Text(
              'DIAsm type: '
              '${_gm700sbKind(record)}',
            ),

            const SizedBox(height: 4),

            Text(
              'Measured: '
              '${_formatDateTime(record.measuredAt)}',
            ),

            const SizedBox(height: 4),

            Text(
              'Wrapper index: '
              '${record.wrapperIndex}',
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // FOUND METER CARD
  // =====================================================

  Widget _buildFoundMeterCard(
    ScanResult result,
  ) {
    final deviceId =
        result.device.remoteId.str;

    final connectedDeviceId =
        _bleService
            .connectedDevice
            ?.remoteId
            .str;

    final isConnecting =
        _connectingDeviceId == deviceId;

    final isConnected =
        connectedDeviceId == deviceId;

    return Card(
      child: ListTile(
        leading: Icon(
          isConnected
              ? Icons
                    .bluetooth_connected
              : Icons
                    .monitor_heart_outlined,
          color: isConnected
              ? Colors.green
              : null,
        ),

        title: Text(
          _deviceName(result),
        ),

        subtitle: Text(
          'ID: $deviceId\n'
          'RSSI: ${result.rssi}',
        ),

        isThreeLine: true,

        trailing: isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
              )
            : isConnected
            ? const Icon(
                Icons.check_circle,
                color: Colors.green,
              )
            : const Icon(
                Icons.chevron_right,
              ),

        onTap:
            _bleService.isConnected ||
                _connectingDeviceId !=
                    null ||
                _isPreviewing ||
                _isImporting
            ? null
            : () => _connect(result),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final meterState = _meterState;

    final previewResult =
        _previewResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import from GM700SB',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(
            16,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              const Text(
                'Bionime RIGHTEST GM700SB',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _status,
                style: TextStyle(
                  color:
                      _importCompleted
                      ? Colors.green
                      : _bleService
                            .isConnected
                      ? Colors.green
                      : Colors.black54,
                  fontWeight:
                      _bleService
                              .isConnected ||
                          _importCompleted
                      ? FontWeight.w700
                      : FontWeight
                            .normal,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      _isScanning ||
                          _connectingDeviceId !=
                              null ||
                          _isPreviewing ||
                          _isImporting ||
                          _bleService
                              .isConnected
                      ? null
                      : _scan,

                  icon: _isScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .bluetooth_searching,
                        ),

                  label: Text(
                    _isScanning
                        ? 'Scanning...'
                        : _bleService
                              .isConnected
                        ? 'GM700SB Connected'
                        : 'Scan for GM700SB',
                  ),
                ),
              ),

              if (_bleService
                  .isConnected) ...[
                const SizedBox(
                  height: 10,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        _isPreviewing ||
                            _isImporting ||
                            _connectingDeviceId !=
                                null
                        ? null
                        : _disconnect,

                    icon: const Icon(
                      Icons
                          .bluetooth_disabled,
                    ),

                    label: const Text(
                      'Disconnect GM700SB',
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 12,
              ),

              Expanded(
                child: ListView(
                  children: [
                    if (meterState !=
                        null) ...[
                      _buildMeterStateCard(
                        meterState,
                      ),

                      const SizedBox(
                        height: 12,
                      ),
                    ],

                    if (previewResult !=
                        null) ...[
                      _buildPreviewSummary(
                        previewResult,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      if (previewResult
                          .records
                          .isNotEmpty)
                        const Text(
                          'GLUCOSE RECORDS',
                          style: TextStyle(
                            fontSize:
                                16,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),

                      const SizedBox(
                        height: 8,
                      ),

                      for (
                        var i = 0;
                        i <
                            previewResult
                                .records
                                .length;
                        i++
                      ) ...[
                        _buildRecordCard(
                          previewResult
                              .records[i],
                          i,
                        ),

                        const SizedBox(
                          height: 8,
                        ),
                      ],
                    ],

                    if (_scanResults
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Found meters',
                        style: TextStyle(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      for (final result
                          in _scanResults)
                        _buildFoundMeterCard(
                          result,
                        ),
                    ],

                    const SizedBox(
                      height: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
