import '../monitoring_models.dart';
import '../monitoring_repository.dart';
import 'gm700sb_ble_service.dart';
import 'gm700sb_decoder.dart';
import 'gm700sb_record.dart';
import 'gm700sb_sync_store.dart';

class Gm700sbImportBatch {
  final int targetRuid;
  final int importedCount;
  final List<Gm700sbRecord> records;

  Gm700sbImportBatch({
    required this.targetRuid,
    required this.importedCount,
    required List<Gm700sbRecord>
    records,
  }) : records =
           List<
             Gm700sbRecord
           >.unmodifiable(records);

  int get totalCount => records.length;

  int get remainingCount =>
      totalCount - importedCount;

  bool get isComplete =>
      importedCount >= totalCount;
}

class Gm700sbImportResult {
  final int importedNow;
  final int totalImported;
  final int targetRuid;

  const Gm700sbImportResult({
    required this.importedNow,
    required this.totalImported,
    required this.targetRuid,
  });
}

class Gm700sbImportService {
  final MonitoringRepository
  _monitoringRepository;
  final Gm700sbSyncStore _syncStore;

  Gm700sbImportService({
    MonitoringRepository?
    monitoringRepository,
    Gm700sbSyncStore? syncStore,
  }) : _monitoringRepository =
           monitoringRepository ??
           MonitoringRepository(),
       _syncStore =
           syncStore ??
           Gm700sbSyncStore();

  Future<int> resolveSavedRuid({
    required String meterId,
    required int currentRuid,
    required int totalRecords,
  }) async {
    final savedRuid = await _syncStore
        .readSavedRuid(
          meterId: meterId,
        );

    // Existing user + meter checkpoint.
    if (savedRuid != null) {
      return savedRuid;
    }

    // First-ever sync:
    // treat all records currently stored
    // in the meter as pending.
    final initialRuid =
        currentRuid - totalRecords;

    if (initialRuid < 0) {
      throw StateError(
        'Invalid GM700SB initial sync state. '
        'RUID=$currentRuid, '
        'TOTAL=$totalRecords.',
      );
    }

    return initialRuid;
  }

  Future<Gm700sbImportBatch?>
  loadStagedBatch({
    required String meterId,
  }) async {
    final progress = await _syncStore
        .readProgress(meterId: meterId);

    if (progress == null) {
      return null;
    }

    final records = progress
        .recordPayloads
        .map(
          Gm700sbDecoder.decodePayload,
        )
        .toList(growable: false);

    if (progress.importedCount >
        records.length) {
      throw StateError(
        'Stored GM700SB imported count exceeds '
        'the stored batch size.',
      );
    }

    return Gm700sbImportBatch(
      targetRuid: progress.targetRuid,
      importedCount:
          progress.importedCount,
      records: records,
    );
  }

  Future<Gm700sbImportBatch?>
  stageSyncResult({
    required String meterId,
    required Gm700sbSyncResult
    syncResult,
  }) async {
    if (syncResult.pendingCount == 0) {
      return null;
    }

    if (syncResult.records.length !=
        syncResult.pendingCount) {
      throw StateError(
        'GM700SB sync returned '
        '${syncResult.records.length} records '
        'for ${syncResult.pendingCount} '
        'pending readings.',
      );
    }

    final existing = await _syncStore
        .readProgress(meterId: meterId);

    if (existing != null) {
      throw StateError(
        'A GM700SB import batch is already '
        'waiting to be completed.',
      );
    }

    final progress =
        Gm700sbSyncProgress(
          targetRuid: syncResult
              .candidateNextRuid,
          importedCount: 0,
          recordPayloads: syncResult
              .records
              .map(
                (record) =>
                    record.rawPayload,
              )
              .toList(growable: false),
        );

    await _syncStore.saveProgress(
      meterId: meterId,
      progress: progress,
    );

    return Gm700sbImportBatch(
      targetRuid: progress.targetRuid,
      importedCount: 0,
      records: syncResult.records,
    );
  }

  Future<Gm700sbImportResult>
  importStagedBatch({
    required String meterId,
  }) async {
    final progress = await _syncStore
        .readProgress(meterId: meterId);

    if (progress == null) {
      throw StateError(
        'There is no staged GM700SB '
        'import batch.',
      );
    }

    final records = progress
        .recordPayloads
        .map(
          Gm700sbDecoder.decodePayload,
        )
        .toList(growable: false);

    if (progress.importedCount >
        records.length) {
      throw StateError(
        'Stored GM700SB imported count exceeds '
        'the batch size.',
      );
    }

    var importedCount =
        progress.importedCount;

    final importedBefore =
        importedCount;

    for (
      var index = importedCount;
      index < records.length;
      index++
    ) {
      final record = records[index];

      final payload = _toGlucosePayload(
        record,
      );

      final success =
          await _monitoringRepository
              .addGlucose(payload);

      if (!success) {
        throw StateError(
          'DIAsm rejected GM700SB reading '
          '${index + 1} of '
          '${records.length}.',
        );
      }

      importedCount = index + 1;

      await _syncStore.saveProgress(
        meterId: meterId,
        progress: Gm700sbSyncProgress(
          targetRuid:
              progress.targetRuid,
          importedCount: importedCount,
          recordPayloads:
              progress.recordPayloads,
        ),
      );
    }

    // Advance the real checkpoint only
    // after every intended glucose record
    // has successfully reached DIAsm.
    await _syncStore.saveSavedRuid(
      meterId: meterId,
      ruid: progress.targetRuid,
    );

    await _syncStore.clearProgress(
      meterId: meterId,
    );

    return Gm700sbImportResult(
      importedNow:
          importedCount -
          importedBefore,
      totalImported: importedCount,
      targetRuid: progress.targetRuid,
    );
  }

  AddGlucosePayload _toGlucosePayload(
    Gm700sbRecord record,
  ) {
    final kind = _kindForMarker(
      record.marker,
    );

    final context = _contextForRecord(
      record,
    );

    return AddGlucosePayload(
      measuredAt: record.measuredAt,
      kind: kind,
      valueMgdl: record.glucoseMgDl
          .toDouble(),
      context: context,
      source: 'device',
    );
  }

  String _kindForMarker(
    Gm700sbMealMarker marker,
  ) {
    switch (marker) {
      case Gm700sbMealMarker.beforeMeal:
        return 'BeforeMeal';

      case Gm700sbMealMarker.afterMeal:
        return 'AfterMeal';

      case Gm700sbMealMarker.none:
        return 'RBS';

      case Gm700sbMealMarker.sport:
        return 'Custom';

      case Gm700sbMealMarker.unknown:
        return 'Custom';
    }
  }

  String? _contextForRecord(
    Gm700sbRecord record,
  ) {
    switch (record.marker) {
      case Gm700sbMealMarker.sport:
        return 'Sport';

      case Gm700sbMealMarker.unknown:
        final hex = record.rawMarker
            .toRadixString(16)
            .padLeft(2, '0')
            .toUpperCase();

        return 'GM700SB marker 0x$hex';

      case Gm700sbMealMarker.none:
      case Gm700sbMealMarker.beforeMeal:
      case Gm700sbMealMarker.afterMeal:
        return null;
    }
  }
}
