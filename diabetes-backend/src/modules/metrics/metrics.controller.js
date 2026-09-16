// src/modules/metrics/metrics.controller.js

import { createHash } from 'crypto';
import { pool } from '../../config/db.js';

// -------- helpers --------
const asDT = (v) => {
  if (!v) {
    return new Date()
      .toISOString()
      .slice(0, 19)
      .replace('T', ' ');
  }

  const d = new Date(v);

  if (Number.isNaN(d.getTime())) {
    return null;
  }

  return d
    .toISOString()
    .slice(0, 19)
    .replace('T', ' ');
};

const num = (x) =>
  x == null ? null : Number(x);

const within = (n, a, b) =>
  Number.isFinite(n) &&
  n >= a &&
  n <= b;

const okWeight = (b) => {
  const w = num(b.weight_kg);
  const h = num(b.height_cm);

  return (
    within(w, 20, 350) &&
    (
      h == null ||
      within(h, 80, 250)
    )
  );
};

const okGlucose = (b) =>
  within(
    num(b.value_mgdl),
    20,
    700
  ) &&
  [
    'FBS',
    'RBS',
    'PP2',
    'BeforeMeal',
    'AfterMeal',
    'Bedtime',
    'Custom',
  ].includes(
    b.kind || 'RBS'
  );

const okA1c = (b) =>
  within(
    num(b.hba1c_percent),
    3.0,
    20.0
  );

const okBP = (b) =>
  within(
    num(b.sys_mmHg),
    60,
    260
  ) &&
  within(
    num(b.dia_mmHg),
    30,
    160
  ) &&
  (
    b.pulse_bpm == null ||
    within(
      num(b.pulse_bpm),
      20,
      220
    )
  ) &&
  [
    'Sitting',
    'Standing',
    'Lying',
    'Unknown',
  ].includes(
    b.posture || 'Unknown'
  );

const okLipids = (b) => {
  const good = (
    value,
    min,
    max
  ) => {
    if (
      value == null ||
      value === ''
    ) {
      return true;
    }

    return within(
      num(value),
      min,
      max
    );
  };

  return (
    good(
      b.total_mgdl,
      50,
      500
    ) &&
    good(
      b.ldl_mgdl,
      10,
      400
    ) &&
    good(
      b.hdl_mgdl,
      5,
      150
    ) &&
    good(
      b.tg_mgdl,
      20,
      1500
    )
  );
};

const okSteps = (b) =>
  within(
    num(b.steps),
    0,
    200000
  ) &&
  (
    b.duration_min == null ||
    within(
      num(b.duration_min),
      0,
      1440
    )
  ) &&
  (
    b.calories_kcal == null ||
    within(
      num(b.calories_kcal),
      0,
      20000
    )
  );

// ✅ FIX: remove fallback-to-1
const uid = (req) =>
  req.user?.id;

// ✅ helper: consistent 401
const requireUid = (
  req,
  res
) => {
  const id = uid(req);

  if (!id) {
    res
      .status(401)
      .json({
        error:
          'Missing Authorization header',
      });

    return null;
  }

  return id;
};

// =====================================================
// GM700SB HELPERS
// =====================================================

const gm700sbAllowedKinds =
  new Set([
    'FBS',
    'RBS',
    'PP2',
    'BeforeMeal',
    'AfterMeal',
    'Bedtime',
    'Custom',
  ]);

/*
 * GM700SB timestamps come from the meter itself.
 *
 * We deliberately preserve the meter's local
 * YYYY-MM-DD HH:mm:ss value rather than converting
 * it through UTC and shifting the clock time.
 */
const asGm700sbDateTime = (
  value
) => {
  if (
    typeof value !== 'string'
  ) {
    return null;
  }

  const match =
    value.match(
      /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?$/
    );

  if (!match) {
    return null;
  }

  const [
    ,
    yearText,
    monthText,
    dayText,
    hourText,
    minuteText,
    secondText,
  ] = match;

  const year =
    Number(yearText);

  const month =
    Number(monthText);

  const day =
    Number(dayText);

  const hour =
    Number(hourText);

  const minute =
    Number(minuteText);

  const second =
    Number(secondText);

  if (
    year < 2000 ||
    year > 2100 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59
  ) {
    return null;
  }

  /*
   * Strict calendar validation.
   *
   * This rejects impossible dates such as:
   * 2026-02-31.
   */
  const check =
    new Date(
      Date.UTC(
        year,
        month - 1,
        day,
        hour,
        minute,
        second
      )
    );

  if (
    check.getUTCFullYear() !==
      year ||
    check.getUTCMonth() !==
      month - 1 ||
    check.getUTCDate() !==
      day ||
    check.getUTCHours() !==
      hour ||
    check.getUTCMinutes() !==
      minute ||
    check.getUTCSeconds() !==
      second
  ) {
    return null;
  }

  return (
    `${yearText}-` +
    `${monthText}-` +
    `${dayText} ` +
    `${hourText}:` +
    `${minuteText}:` +
    `${secondText}`
  );
};

/*
 * The already verified GM700SB ONE RECORD payload
 * is exactly 18 bytes.
 *
 * 18 bytes × 2 hex characters = 36 characters.
 */
const normalizeGm700sbPayloadHex = (
  value
) => {
  if (
    typeof value !== 'string'
  ) {
    return null;
  }

  const normalized =
    value
      .replace(
        /\s+/g,
        ''
      )
      .toUpperCase();

  if (
    normalized.length !== 36 ||
    !/^[0-9A-F]+$/.test(
      normalized
    )
  ) {
    return null;
  }

  return normalized;
};

/*
 * 18-byte decoded payload:
 *
 * bytes 0-1:
 * wrapper/index
 *
 * bytes 2-17:
 * 16-byte Full Security meter record
 *
 * The two wrapper/index bytes are not used as
 * permanent record identity.
 *
 * We create a deterministic SHA-256 fingerprint
 * from:
 *
 * meter identity
 * +
 * stable 16-byte physical meter record
 */
const makeGm700sbRecordKey = ({
  identifier,
  rawPayloadHex,
}) => {
  const stableRecordHex =
    rawPayloadHex.slice(4);

  return createHash(
    'sha256'
  )
    .update(
      `GM700SB|` +
      `${identifier.toUpperCase()}|` +
      stableRecordHex
    )
    .digest('hex');
};

// =====================================================

const logSqlError = (e) => {
  if (
    e &&
    e.sqlMessage
  ) {
    console.error(
      '--- SQL ERROR -----------------------'
    );

    console.error(
      'Message :',
      e.sqlMessage
    );

    if (e.errno) {
      console.error(
        'Errno   :',
        e.errno
      );
    }

    if (e.code) {
      console.error(
        'Code    :',
        e.code
      );
    }

    if (e.sql) {
      console.error(
        'Query   :',
        e.sql
      );
    }

    console.error(
      '-------------------------------------'
    );
  } else {
    console.error(e);
  }
};

// =====================================================
// DEBUG ENDPOINT
// =====================================================

export async function debugPingDb(
  _req,
  res
) {
  try {
    const [rows] =
      await pool.execute(
        'SELECT 1 AS ok'
      );

    res.json(
      rows[0]
    );
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'db_error',
      });
  }
}

// =====================================================
// INSERTS
// =====================================================

// ---------------- Weight ----------------

export async function addWeight(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okWeight(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid weight/height',
        });
    }

    const measured_at =
      asDT(
        b.measured_at
      );

    if (
      !measured_at
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid measured_at',
        });
    }

    await pool.execute(
      `
      INSERT INTO metrics_weight (
        user_id,
        measured_at,
        weight_kg,
        height_cm,
        source,
        note
      )
      VALUES (?,?,?,?,?,?)
      `,
      [
        userId,
        measured_at,
        num(
          b.weight_kg
        ),
        num(
          b.height_cm
        ),
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// ---------------- Existing glucose ----------------

export async function addGlucose(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okGlucose(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid glucose/kind',
        });
    }

    const measured_at =
      asDT(
        b.measured_at
      );

    if (
      !measured_at
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid measured_at',
        });
    }

    /*
     * EXISTING MANUAL/API PATH.
     *
     * We intentionally leave this insert structure
     * unchanged.
     *
     * New device-specific DB columns:
     *
     * user_device_id
     * external_record_key
     *
     * therefore remain NULL for normal manual rows.
     */
    await pool.execute(
      `
      INSERT INTO metrics_glucose (
        user_id,
        measured_at,
        kind,
        value_mgdl,
        context,
        insulin_units,
        source,
        note
      )
      VALUES (?,?,?,?,?,?,?,?)
      `,
      [
        userId,
        measured_at,
        b.kind ||
          'RBS',
        num(
          b.value_mgdl
        ),
        b.context ??
          null,
        num(
          b.insulin_units
        ),
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// =====================================================
// GM700SB TRANSACTIONAL IMPORT
// =====================================================

export async function importGm700sbGlucose(
  req,
  res
) {
  const userId =
    requireUid(
      req,
      res
    );

  if (!userId) {
    return;
  }

  const body =
    req.body || {};

  const device =
    body.device || {};

  /*
   * identifier:
   *
   * use the meter identity presented by the
   * integration, for example:
   *
   * 2782ZAR0740(C)
   *
   * BLE remote ID is retained separately as metadata.
   */
  const identifier =
    typeof device.identifier ===
    'string'
      ? device.identifier.trim()
      : '';

  const bleRemoteId =
    typeof device.ble_remote_id ===
    'string'
      ? device.ble_remote_id.trim()
      : null;

  /*
   * Important:
   *
   * Null must NOT silently become Number(null) = 0.
   */
  const savedRuid =
    body.saved_ruid == null
      ? Number.NaN
      : Number(
          body.saved_ruid
        );

  const currentRuid =
    body.current_ruid == null
      ? Number.NaN
      : Number(
          body.current_ruid
        );

  const records =
    Array.isArray(
      body.records
    )
      ? body.records
      : null;

  // ----------------------------------------------
  // Validate meter identity
  // ----------------------------------------------

  if (
    !identifier ||
    identifier.length >
      128
  ) {
    return res
      .status(400)
      .json({
        error:
          'invalid_device_identifier',
      });
  }

  // ----------------------------------------------
  // Validate RUID
  // ----------------------------------------------

  if (
    !Number.isInteger(
      savedRuid
    ) ||
    savedRuid < 0 ||
    !Number.isInteger(
      currentRuid
    ) ||
    currentRuid < 0
  ) {
    return res
      .status(400)
      .json({
        error:
          'invalid_ruid',
      });
  }

  if (
    currentRuid <
    savedRuid
  ) {
    return res
      .status(400)
      .json({
        error:
          'invalid_ruid_range',
        saved_ruid:
          savedRuid,
        current_ruid:
          currentRuid,
      });
  }

  // ----------------------------------------------
  // Validate records array
  // ----------------------------------------------

  if (
    records == null
  ) {
    return res
      .status(400)
      .json({
        error:
          'records_must_be_array',
      });
  }

  /*
   * Defensive batch-size limit.
   *
   * This can be revisited later after broader
   * meter testing.
   */
  if (
    records.length >
    100
  ) {
    return res
      .status(400)
      .json({
        error:
          'too_many_records',
      });
  }

  const expectedPending =
    currentRuid -
    savedRuid;

  /*
   * Example from our verified meter:
   *
   * saved   = 501
   * current = 503
   *
   * expected pending = 2
   */
  if (
    records.length !==
    expectedPending
  ) {
    return res
      .status(400)
      .json({
        error:
          'record_count_mismatch',
        expected:
          expectedPending,
        received:
          records.length,
      });
  }

  // ----------------------------------------------
  // Validate ALL records before opening transaction
  // ----------------------------------------------

  const validatedRecords =
    [];

  for (
    let index = 0;
    index <
    records.length;
    index += 1
  ) {
    const rawRecord =
      records[index] ||
      {};

    const valueMgdl =
      Number(
        rawRecord.value_mgdl
      );

    const kind =
      typeof rawRecord.kind ===
      'string'
        ? rawRecord.kind
        : 'RBS';

    const measuredAt =
      asGm700sbDateTime(
        rawRecord.measured_at
      );

    const rawPayloadHex =
      normalizeGm700sbPayloadHex(
        rawRecord.raw_payload_hex
      );

    if (
      !within(
        valueMgdl,
        20,
        700
      )
    ) {
      return res
        .status(400)
        .json({
          error:
            'invalid_glucose_value',
          record_index:
            index,
        });
    }

    if (
      !gm700sbAllowedKinds.has(
        kind
      )
    ) {
      return res
        .status(400)
        .json({
          error:
            'invalid_glucose_kind',
          record_index:
            index,
        });
    }

    if (
      !measuredAt
    ) {
      return res
        .status(400)
        .json({
          error:
            'invalid_measured_at',
          record_index:
            index,
        });
    }

    if (
      !rawPayloadHex
    ) {
      return res
        .status(400)
        .json({
          error:
            'invalid_raw_payload',
          record_index:
            index,
        });
    }

    const context =
      rawRecord.context ==
      null
        ? null
        : String(
            rawRecord.context
          ).slice(
            0,
            80
          );

    const note =
      rawRecord.note ==
      null
        ? null
        : String(
            rawRecord.note
          ).slice(
            0,
            255
          );

    const externalRecordKey =
      makeGm700sbRecordKey({
        identifier,
        rawPayloadHex,
      });

    validatedRecords.push({
      measuredAt,
      kind,
      valueMgdl,
      context,
      note,
      externalRecordKey,
    });
  }

  let connection =
    null;

  try {
    // --------------------------------------------
    // Dedicated MySQL connection
    // --------------------------------------------

    connection =
      await pool.getConnection();

    await connection
      .beginTransaction();

    // --------------------------------------------
    // Register/reuse GM700SB device
    // --------------------------------------------

    const metaJson =
      JSON.stringify({
        ble_remote_id:
          bleRemoteId,
      });

    /*
     * user_devices now has:
     *
     * UNIQUE(user_id, identifier)
     *
     * Therefore the same DIAsm user + meter identity
     * resolves to one user_devices row.
     */
    await connection.execute(
      `
      INSERT INTO user_devices (
        user_id,
        vendor,
        model,
        connection,
        identifier,
        meta_json,
        is_active
      )
      VALUES (
        ?,
        ?,
        ?,
        ?,
        ?,
        ?,
        1
      )

      ON DUPLICATE KEY UPDATE
        vendor = VALUES(vendor),
        model = VALUES(model),
        connection = VALUES(connection),
        meta_json = VALUES(meta_json),
        is_active = 1
      `,
      [
        userId,
        'Bionime',
        'RIGHTEST GM700SB',
        'BLE',
        identifier,
        metaJson,
      ]
    );

    // --------------------------------------------
    // Lock meter checkpoint row
    // --------------------------------------------

    /*
     * FOR UPDATE serializes concurrent syncs for
     * this registered meter while this transaction
     * is active.
     */
    const [
      deviceRows,
    ] =
      await connection
        .execute(
          `
          SELECT
            id,
            last_synced_ruid
          FROM user_devices
          WHERE user_id = ?
            AND identifier = ?
          LIMIT 1
          FOR UPDATE
          `,
          [
            userId,
            identifier,
          ]
        );

    if (
      deviceRows.length !==
      1
    ) {
      throw new Error(
        'GM700SB device registration failed'
      );
    }

    const userDevice =
      deviceRows[0];

    const userDeviceId =
      Number(
        userDevice.id
      );

    const serverCheckpoint =
      userDevice
        .last_synced_ruid ==
      null
        ? null
        : Number(
            userDevice
              .last_synced_ruid
          );

    // --------------------------------------------
    // Retry after an already committed import
    // --------------------------------------------

    /*
     * Scenario:
     *
     * server successfully imported through RUID 503
     * and committed,
     *
     * but the phone lost the HTTP response.
     *
     * Phone retries with current RUID 503.
     *
     * Do not insert anything again.
     */
    if (
      serverCheckpoint !=
        null &&
      serverCheckpoint ===
        currentRuid
    ) {
      await connection
        .commit();

      return res
        .status(200)
        .json({
          ok: true,

          already_synced:
            true,

          user_device_id:
            userDeviceId,

          last_synced_ruid:
            serverCheckpoint,

          inserted:
            0,

          duplicates:
            records.length,

          processed:
            records.length,
        });
    }

    // --------------------------------------------
    // Backend checkpoint ahead of meter
    // --------------------------------------------

    if (
      serverCheckpoint !=
        null &&
      serverCheckpoint >
        currentRuid
    ) {
      await connection
        .rollback();

      return res
        .status(409)
        .json({
          error:
            'server_checkpoint_ahead_of_meter',

          server_checkpoint:
            serverCheckpoint,

          current_ruid:
            currentRuid,
        });
    }

    // --------------------------------------------
    // Checkpoint mismatch
    // --------------------------------------------

    /*
     * Once the server already has a checkpoint,
     * the app must sync from exactly that checkpoint.
     */
    if (
      serverCheckpoint !=
        null &&
      serverCheckpoint !==
        savedRuid
    ) {
      await connection
        .rollback();

      return res
        .status(409)
        .json({
          error:
            'checkpoint_mismatch',

          server_checkpoint:
            serverCheckpoint,

          supplied_saved_ruid:
            savedRuid,
        });
    }

    // --------------------------------------------
    // Import records
    // --------------------------------------------

    let inserted = 0;
    let duplicates = 0;

    for (
      const record of
      validatedRecords
    ) {
      /*
       * Application-level duplicate check.
       *
       * The UNIQUE DB key on:
       *
       * user_device_id
       * +
       * external_record_key
       *
       * remains the final database protection.
       */
      const [
        existingRows,
      ] =
        await connection
          .execute(
            `
            SELECT id
            FROM metrics_glucose
            WHERE user_device_id = ?
              AND external_record_key = ?
            LIMIT 1
            `,
            [
              userDeviceId,
              record
                .externalRecordKey,
            ]
          );

      if (
        existingRows.length >
        0
      ) {
        duplicates += 1;

        continue;
      }

      await connection.execute(
        `
        INSERT INTO metrics_glucose (
          user_id,
          user_device_id,
          measured_at,
          kind,
          value_mgdl,
          context,
          insulin_units,
          source,
          external_record_key,
          note
        )
        VALUES (
          ?,
          ?,
          ?,
          ?,
          ?,
          ?,
          NULL,
          'device',
          ?,
          ?
        )
        `,
        [
          userId,
          userDeviceId,
          record.measuredAt,
          record.kind,
          record.valueMgdl,
          record.context,
          record
            .externalRecordKey,
          record.note,
        ]
      );

      inserted += 1;
    }

    // --------------------------------------------
    // Advance checkpoint
    // --------------------------------------------

    /*
     * CRITICAL RULE:
     *
     * last_synced_ruid is updated only after every
     * intended record has either:
     *
     * - been successfully inserted, or
     * - been confirmed as an existing duplicate.
     */
    await connection.execute(
      `
      UPDATE user_devices
      SET
        last_synced_ruid = ?,
        last_sync_at =
          CURRENT_TIMESTAMP
      WHERE id = ?
        AND user_id = ?
      `,
      [
        currentRuid,
        userDeviceId,
        userId,
      ]
    );

    // --------------------------------------------
    // Sync audit log
    // --------------------------------------------

    await connection.execute(
      `
      INSERT INTO device_sync_logs (
        user_device_id,
        started_at,
        finished_at,
        status,
        message,
        rows_ingested
      )
      VALUES (
        ?,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        'success',
        ?,
        ?
      )
      `,
      [
        userDeviceId,

        (
          `GM700SB sync ` +
          `${savedRuid} -> ` +
          `${currentRuid}; ` +
          `${inserted} inserted, ` +
          `${duplicates} duplicate`
        ),

        inserted,
      ]
    );

    // --------------------------------------------
    // Transaction success
    // --------------------------------------------

    await connection
      .commit();

    return res
      .status(201)
      .json({
        ok: true,

        already_synced:
          false,

        user_device_id:
          userDeviceId,

        saved_ruid_before:
          savedRuid,

        last_synced_ruid:
          currentRuid,

        inserted,

        duplicates,

        processed:
          validatedRecords.length,
      });
  } catch (e) {
    /*
     * Any failure before COMMIT rolls back:
     *
     * glucose inserts
     * checkpoint update
     * device sync log
     */
    if (connection) {
      try {
        await connection
          .rollback();
      } catch (_) {
        // Ignore rollback failure while
        // handling original error.
      }
    }

    logSqlError(e);

    return res
      .status(500)
      .json({
        error:
          'gm700sb_import_failed',
      });
  } finally {
    if (connection) {
      connection.release();
    }
  }
}


// =====================================================
// GM700SB CHECKPOINT
// =====================================================

export async function getGm700sbCheckpoint(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const identifier =
      typeof req.query.identifier === 'string'
        ? req.query.identifier.trim()
        : '';

    if (
      !identifier ||
      identifier.length > 128
    ) {
      return res
        .status(400)
        .json({
          error:
            'invalid_device_identifier',
        });
    }

    const [rows] =
      await pool.execute(
        `
        SELECT
          id,
          last_synced_ruid,
          last_sync_at
        FROM user_devices
        WHERE user_id = ?
          AND identifier = ?
        LIMIT 1
        `,
        [
          userId,
          identifier,
        ]
      );

    /*
     * First-time meter:
     *
     * No user_devices row exists yet.
     *
     * Flutter will receive:
     *
     * registered = false
     * last_synced_ruid = null
     *
     * Later Flutter can calculate an initial
     * checkpoint from the meter's own
     * RUID + total-record count.
     */
    if (
      rows.length === 0
    ) {
      return res.json({
        ok: true,

        registered:
          false,

        user_device_id:
          null,

        last_synced_ruid:
          null,

        last_sync_at:
          null,
      });
    }

    const device =
      rows[0];

    return res.json({
      ok: true,

      registered:
        true,

      user_device_id:
        Number(
          device.id
        ),

      last_synced_ruid:
        device.last_synced_ruid == null
          ? null
          : Number(
              device.last_synced_ruid
            ),

      last_sync_at:
        device.last_sync_at ??
        null,
    });
  } catch (e) {
    logSqlError(e);

    return res
      .status(500)
      .json({
        error:
          'gm700sb_checkpoint_failed',
      });
  }
}
// ---------------- HbA1c ----------------

export async function addA1c(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okA1c(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid hba1c_percent',
        });
    }

    const measured_at =
      asDT(
        b.measured_at
      );

    if (
      !measured_at
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid measured_at',
        });
    }

    await pool.execute(
      `
      INSERT INTO metrics_hba1c (
        user_id,
        measured_at,
        hba1c_percent,
        lab_name,
        source,
        note
      )
      VALUES (?,?,?,?,?,?)
      `,
      [
        userId,
        measured_at,
        num(
          b.hba1c_percent
        ),
        b.lab_name ??
          null,
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// ---------------- Blood pressure ----------------

export async function addBP(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okBP(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid BP fields',
        });
    }

    const measured_at =
      asDT(
        b.measured_at
      );

    if (
      !measured_at
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid measured_at',
        });
    }

    await pool.execute(
      `
      INSERT INTO metrics_bp (
        user_id,
        measured_at,
        sys_mmHg,
        dia_mmHg,
        pulse_bpm,
        posture,
        source,
        note
      )
      VALUES (?,?,?,?,?,?,?,?)
      `,
      [
        userId,
        measured_at,
        num(
          b.sys_mmHg
        ),
        num(
          b.dia_mmHg
        ),
        num(
          b.pulse_bpm
        ),
        b.posture ||
          'Unknown',
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// ---------------- Lipids ----------------

export async function addLipids(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okLipids(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid lipid ranges',
        });
    }

    const measured_at =
      asDT(
        b.measured_at
      );

    if (
      !measured_at
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid measured_at',
        });
    }

    await pool.execute(
      `
      INSERT INTO metrics_cholesterol (
        user_id,
        measured_at,
        total_mgdl,
        ldl_mgdl,
        hdl_mgdl,
        tg_mgdl,
        source,
        note
      )
      VALUES (?,?,?,?,?,?,?,?)
      `,
      [
        userId,
        measured_at,
        num(
          b.total_mgdl
        ),
        num(
          b.ldl_mgdl
        ),
        num(
          b.hdl_mgdl
        ),
        num(
          b.tg_mgdl
        ),
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// ---------------- Steps ----------------

export async function addSteps(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const b =
      req.body || {};

    if (
      !okSteps(b)
    ) {
      return res
        .status(400)
        .json({
          error:
            'Invalid steps/duration/calories',
        });
    }

    const measured_at =
      b.measured_at
        ? asDT(
            b.measured_at
          )
        : null;

    const day_date =
      b.day_date
        ? b.day_date
        : measured_at
        ? measured_at.slice(
            0,
            10
          )
        : new Date()
            .toISOString()
            .slice(
              0,
              10
            );

    await pool.execute(
      `
      INSERT INTO metrics_steps (
        user_id,
        day_date,
        measured_at,
        steps,
        duration_min,
        calories_kcal,
        source,
        note
      )
      VALUES (?,?,?,?,?,?,?,?)
      `,
      [
        userId,
        day_date,
        measured_at,
        num(
          b.steps
        ),
        num(
          b.duration_min
        ),
        num(
          b.calories_kcal
        ),
        b.source ||
          'manual',
        b.note ??
          null,
      ]
    );

    res
      .status(201)
      .json({
        ok: true,
      });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// =====================================================
// LISTS
// =====================================================

export async function listWeight(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const page =
      Math.max(
        1,
        parseInt(
          req.query.page ??
            '1',
          10
        )
      );

    const limit =
      Math.min(
        100,
        Math.max(
          1,
          parseInt(
            req.query.limit ??
              '20',
            10
          )
        )
      );

    const offset =
      (page - 1) *
      limit;

    const from =
      req.query.from
        ? `${req.query.from} 00:00:00`
        : null;

    const to =
      req.query.to
        ? `${req.query.to} 23:59:59`
        : null;

    const where = [
      '`user_id` = ?',
    ];

    const args = [
      userId,
    ];

    if (
      from &&
      to
    ) {
      where.push(
        '`measured_at` BETWEEN ? AND ?'
      );

      args.push(
        from,
        to
      );
    }

    const sql = `
      SELECT
        id,
        user_id,
        measured_at,
        weight_kg,
        height_cm,
        bmi,
        source,
        note,
        created_at,
        updated_at
      FROM \`metrics_weight\`
      WHERE ${where.join(
        ' AND '
      )}
      ORDER BY
        \`measured_at\` DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    const [rows] =
      await pool.execute(
        sql,
        args
      );

    res.json({
      page,
      limit,
      rows,
    });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

export async function listGlucose(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const page =
      Math.max(
        1,
        parseInt(
          req.query.page ??
            '1',
          10
        )
      );

    const limit =
      Math.min(
        100,
        Math.max(
          1,
          parseInt(
            req.query.limit ??
              '20',
            10
          )
        )
      );

    const offset =
      (page - 1) *
      limit;

    const from =
      req.query.from
        ? `${req.query.from} 00:00:00`
        : null;

    const to =
      req.query.to
        ? `${req.query.to} 23:59:59`
        : null;

    const where = [
      '`user_id` = ?',
    ];

    const args = [
      userId,
    ];

    if (
      from &&
      to
    ) {
      where.push(
        '`measured_at` BETWEEN ? AND ?'
      );

      args.push(
        from,
        to
      );
    }

    const sql = `
      SELECT
        id,
        user_id,
        measured_at,
        kind,
        value_mgdl,
        value_mmoll,
        context,
        insulin_units,
        source,
        note,
        created_at,
        updated_at
      FROM \`metrics_glucose\`
      WHERE ${where.join(
        ' AND '
      )}
      ORDER BY
        \`measured_at\` DESC
      LIMIT ${limit}
      OFFSET ${offset}
    `;

    const [rows] =
      await pool.execute(
        sql,
        args
      );

    res.json({
      page,
      limit,
      rows,
    });
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// =====================================================
// LATEST GLUCOSE
// =====================================================

export async function getLatestGlucose(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const [rows] =
      await pool.execute(
        `
        SELECT
          id,
          user_id,
          measured_at,
          kind,
          value_mgdl,
          value_mmoll,
          context,
          insulin_units,
          source,
          note,
          created_at,
          updated_at
        FROM metrics_glucose
        WHERE user_id = ?
        ORDER BY
          measured_at DESC
        LIMIT 1
        `,
        [
          userId,
        ]
      );

    res.json(
      rows[0] ||
      null
    );
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

// =====================================================
// SUMMARIES
// =====================================================

export async function glucoseDailySeries(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const {
      from,
      to,
    } =
      req.query;

    if (
      !from ||
      !to
    ) {
      return res
        .status(400)
        .json({
          error:
            'from & to required',
        });
    }

    const [rows] =
      await pool.execute(
        `
        SELECT
          DATE(measured_at) AS day,
          ROUND(
            AVG(value_mgdl),
            1
          ) AS avg_mgdl
        FROM metrics_glucose
        WHERE
          user_id = ?
          AND measured_at
          BETWEEN
            CONCAT(
              ?,
              ' 00:00:00'
            )
          AND
            CONCAT(
              ?,
              ' 23:59:59'
            )
        GROUP BY
          DATE(measured_at)
        ORDER BY day
        `,
        [
          userId,
          from,
          to,
        ]
      );

    res.json(rows);
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

export async function stepsWeekly(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const weeks =
      Math.max(
        1,
        parseInt(
          req.query.weeks ??
            '8',
          10
        )
      );

    const [rows] =
      await pool.execute(
        `
        SELECT
          YEARWEEK(
            COALESCE(
              measured_at,
              CONCAT(
                day_date,
                ' 00:00:00'
              )
            ),
            3
          ) AS iso_week,

          SUM(
            steps
          ) AS week_steps

        FROM metrics_steps

        WHERE
          user_id = ?

          AND COALESCE(
            measured_at,
            CONCAT(
              day_date,
              ' 00:00:00'
            )
          ) >=
            UTC_TIMESTAMP()
            - INTERVAL ? WEEK

        GROUP BY
          YEARWEEK(
            COALESCE(
              measured_at,
              CONCAT(
                day_date,
                ' 00:00:00'
              )
            ),
            3
          )

        ORDER BY
          iso_week
        `,
        [
          userId,
          weeks,
        ]
      );

    res.json(rows);
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

export async function weightDailySeries(
  req,
  res
) {
  try {
    const userId =
      requireUid(
        req,
        res
      );

    if (!userId) {
      return;
    }

    const [rows] =
      await pool.execute(
        `
        SELECT
          day,
          weight_kg,
          bmi
        FROM v_weight_daily
        WHERE user_id = ?
        ORDER BY day
        `,
        [
          userId,
        ]
      );

    res.json(rows);
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}

export async function dashboardSnapshot(
  req,
  res
) {
  try {
    const id =
      requireUid(
        req,
        res
      );

    if (!id) {
      return;
    }

    const [rows] =
      await pool.execute(
        `
        SELECT

          (
            SELECT weight_kg
            FROM metrics_weight
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_weight,

          (
            SELECT bmi
            FROM metrics_weight
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_bmi,

          (
            SELECT value_mgdl
            FROM metrics_glucose
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_glucose,

          (
            SELECT CONCAT(
              sys_mmHg,
              '/',
              dia_mmHg
            )
            FROM metrics_bp
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_bp,

          (
            SELECT steps
            FROM metrics_steps
            WHERE user_id = ?
            ORDER BY
              COALESCE(
                day_date,
                DATE(
                  measured_at
                )
              ) DESC,
              measured_at DESC
            LIMIT 1
          ) AS last_steps,

          (
            SELECT hba1c_percent
            FROM metrics_hba1c
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_hba1c,

          (
            SELECT total_mgdl
            FROM metrics_cholesterol
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_chol_total,

          (
            SELECT hdl_mgdl
            FROM metrics_cholesterol
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_chol_hdl,

          (
            SELECT ldl_mgdl
            FROM metrics_cholesterol
            WHERE user_id = ?
            ORDER BY
              measured_at DESC
            LIMIT 1
          ) AS last_chol_ldl
        `,
        [
          id,
          id,
          id,
          id,
          id,
          id,
          id,
          id,
          id,
        ]
      );

    res.json(
      rows[0] ||
      {}
    );
  } catch (e) {
    logSqlError(e);

    res
      .status(500)
      .json({
        error:
          'server_error',
      });
  }
}