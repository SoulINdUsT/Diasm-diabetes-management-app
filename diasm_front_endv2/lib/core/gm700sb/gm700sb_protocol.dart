class Gm700sbFragment {
  final int totalCount;
  final int index;
  final List<int> protocolBytes;

  Gm700sbFragment({
    required this.totalCount,
    required this.index,
    required List<int> protocolBytes,
  }) : protocolBytes =
           List<int>.unmodifiable(
             protocolBytes,
           );
}

class Gm700sbMeterState {
  final int ruid;
  final int totalRecords;
  final int lastTransmission;

  const Gm700sbMeterState({
    required this.ruid,
    required this.totalRecords,
    required this.lastTransmission,
  });

  @override
  String toString() {
    return 'Gm700sbMeterState('
        'ruid: $ruid, '
        'totalRecords: $totalRecords, '
        'lastTransmission: $lastTransmission'
        ')';
  }
}

class Gm700sbProtocol {
  const Gm700sbProtocol._();

  static const List<int> pclOnCommand =
      <int>[0x00];

  static const List<int>
  getBrandNameCommand = <int>[
    0xB0,
    0x38,
    0xE8,
  ];

  static const List<int>
  getModelNameCommand = <int>[
    0xB0,
    0x00,
    0xB0,
  ];

  static const List<int>
  getMeterSettingCommand = <int>[
    0xB0,
    0x06,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0xB6,
  ];

  static const List<int>
  getFirmwareVersionCommand = <int>[
    0xB0,
    0x01,
    0xB1,
  ];

  static const List<int>
  getRuidTotalLastCommand = <int>[
    0xB0,
    0x33,
    0xE3,
  ];

  /// Calculates the unsigned 8-bit checksum used by
  /// outgoing GM700SB commands and incoming protocol packets.
  static int calculateChecksum(
    List<int> bytes,
  ) {
    return bytes.fold<int>(
      0,
      (sum, byte) =>
          (sum + (byte & 0xFF)) & 0xFF,
    );
  }

  /// Validates the checksum byte at the end of an
  /// assembled GM700SB protocol packet.
  static bool isChecksumValid(
    List<int> packet,
  ) {
    if (packet.length < 2) {
      return false;
    }

    final expected = packet.last & 0xFF;

    final calculated =
        calculateChecksum(
          packet.sublist(
            0,
            packet.length - 1,
          ),
        );

    return calculated == expected;
  }

  /// Builds:
  ///
  /// B0 61 [count_low] [count_high] [checksum]
  ///
  /// for GET_FULL_SECURITY_ONE_RECORD.
  static List<int>
  buildOneRecordCommand(int count) {
    if (count <= 0 || count > 0xFFFF) {
      throw RangeError.range(
        count,
        1,
        0xFFFF,
        'count',
      );
    }

    final low = count & 0xFF;

    final high = (count >> 8) & 0xFF;

    final base = <int>[
      0xB0,
      0x61,
      low,
      high,
    ];

    final checksum = calculateChecksum(
      base,
    );

    return List<int>.unmodifiable(<int>[
      ...base,
      checksum,
    ]);
  }

  /// Parses the two-byte BLE notification prefix:
  ///
  /// byte 0 = total fragment count
  /// byte 1 = fragment index
  ///
  /// The returned protocolBytes exclude those two bytes.
  static Gm700sbFragment
  parseBleFragment(
    List<int> notification,
  ) {
    if (notification.length < 3) {
      throw const FormatException(
        'GM700SB BLE fragment is too short.',
      );
    }

    final totalCount =
        notification[0] & 0xFF;

    final index =
        notification[1] & 0xFF;

    if (totalCount < 1) {
      throw const FormatException(
        'GM700SB fragment count must be at least 1.',
      );
    }

    if (index < 1 ||
        index > totalCount) {
      throw FormatException(
        'Invalid GM700SB fragment index '
        '$index of $totalCount.',
      );
    }

    return Gm700sbFragment(
      totalCount: totalCount,
      index: index,
      protocolBytes: notification
          .sublist(2),
    );
  }

  /// Reassembles one complete protocol packet from
  /// BLE notifications.
  ///
  /// All fragments must belong to the same response
  /// and must be supplied in fragment order.
  static List<int> assembleFragments(
    List<List<int>> notifications,
  ) {
    if (notifications.isEmpty) {
      throw const FormatException(
        'No GM700SB fragments supplied.',
      );
    }

    final fragments = notifications
        .map(parseBleFragment)
        .toList();

    final expectedCount =
        fragments.first.totalCount;

    if (fragments.length !=
        expectedCount) {
      throw FormatException(
        'Expected $expectedCount GM700SB fragments, '
        'received ${fragments.length}.',
      );
    }

    final assembled = <int>[];

    for (
      var i = 0;
      i < fragments.length;
      i++
    ) {
      final fragment = fragments[i];

      if (fragment.totalCount !=
          expectedCount) {
        throw const FormatException(
          'GM700SB fragment count changed '
          'during reassembly.',
        );
      }

      final expectedIndex = i + 1;

      if (fragment.index !=
          expectedIndex) {
        throw FormatException(
          'Expected GM700SB fragment '
          '$expectedIndex, '
          'received ${fragment.index}.',
        );
      }

      assembled.addAll(
        fragment.protocolBytes,
      );
    }

    return List<int>.unmodifiable(
      assembled,
    );
  }

  /// Decodes the assembled protocol packet returned by:
  ///
  /// GET_RUID_TOTAL_AND_LAST_TRANSMISSION
  ///
  /// Expected protocol layout after the BLE
  /// fragment prefix has been removed:
  ///
  /// 4F CC
  /// [RUID 4 bytes little-endian]
  /// [TOTAL 2 bytes little-endian]
  /// [LAST 2 bytes little-endian]
  /// [checksum]
  static Gm700sbMeterState
  decodeMeterStatePacket(
    List<int> packet,
  ) {
    if (packet.length != 11) {
      throw FormatException(
        'GM700SB meter-state packet must be '
        '11 bytes, received ${packet.length}.',
      );
    }

    if (packet[0] != 0x4F ||
        packet[1] != 0xCC) {
      throw const FormatException(
        'Unexpected GM700SB meter-state '
        'header. Expected 4F CC.',
      );
    }

    if (!isChecksumValid(packet)) {
      throw const FormatException(
        'GM700SB meter-state checksum failed.',
      );
    }

    final ruid =
        (packet[2] & 0xFF) |
        ((packet[3] & 0xFF) << 8) |
        ((packet[4] & 0xFF) << 16) |
        ((packet[5] & 0xFF) << 24);

    final totalRecords =
        (packet[6] & 0xFF) |
        ((packet[7] & 0xFF) << 8);

    final lastTransmission =
        (packet[8] & 0xFF) |
        ((packet[9] & 0xFF) << 8);

    return Gm700sbMeterState(
      ruid: ruid,
      totalRecords: totalRecords,
      lastTransmission:
          lastTransmission,
    );
  }

  /// Validates an assembled ONE RECORD packet and
  /// returns its 18-byte payload.
  ///
  /// Expected packet:
  ///
  /// 4F 9E
  /// [18-byte payload]
  /// [checksum]
  ///
  /// Total = 21 bytes.
  static List<int>
  extractOneRecordPayload(
    List<int> packet,
  ) {
    if (packet.length != 21) {
      throw FormatException(
        'GM700SB ONE RECORD packet must be '
        '21 bytes, received ${packet.length}.',
      );
    }

    if (packet[0] != 0x4F ||
        packet[1] != 0x9E) {
      throw const FormatException(
        'Unexpected GM700SB ONE RECORD '
        'header. Expected 4F 9E.',
      );
    }

    if (!isChecksumValid(packet)) {
      throw const FormatException(
        'GM700SB ONE RECORD checksum failed.',
      );
    }

    return List<int>.unmodifiable(
      packet.sublist(2, 20),
    );
  }
}
