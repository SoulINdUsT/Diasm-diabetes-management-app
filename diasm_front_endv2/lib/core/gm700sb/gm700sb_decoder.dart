import 'gm700sb_record.dart';

class Gm700sbDecoder {
  const Gm700sbDecoder._();

  /// Decodes the 18-byte payload from a verified
  /// GET_FULL_SECURITY_ONE_RECORD protocol response.
  ///
  /// Payload layout:
  ///
  /// [0..1]  = wrapper/index
  /// [2..17] = 16-byte Full Security record
  ///
  /// This method expects the protocol header, checksum,
  /// and BLE fragment headers to have already been removed.
  static Gm700sbRecord decodePayload(
    List<int> payload,
  ) {
    if (payload.length != 18) {
      throw FormatException(
        'GM700SB record payload must be exactly '
        '18 bytes, received ${payload.length}.',
      );
    }

    final wrapperIndex =
        (payload[0] & 0xFF) |
        ((payload[1] & 0xFF) << 8);

    final record = payload.sublist(
      2,
      18,
    );

    if (record.length != 16) {
      throw const FormatException(
        'GM700SB Full Security record must be '
        'exactly 16 bytes.',
      );
    }

    final year =
        2000 + (record[3] & 0x7F);

    final month =
        ((record[1] & 0xC0) >> 4) +
        ((record[0] & 0xC0) >> 6) +
        1;

    final day = (record[0] & 0x1F) + 1;

    final hour = record[1] & 0x1F;

    final minute = record[2] & 0x3F;

    if (month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31 ||
        hour > 23 ||
        minute > 59) {
      throw FormatException(
        'Invalid GM700SB timestamp fields: '
        '$year-$month-$day $hour:$minute.',
      );
    }

    final glucoseMgDl =
        ((record[4] & 0x03) << 8) |
        (record[5] & 0xFF);

    final rawMarker = record[8] & 0xFF;

    final marker = _decodeMarker(
      rawMarker,
    );

    final measuredAt = DateTime(
      year,
      month,
      day,
      hour,
      minute,
    );

    return Gm700sbRecord(
      wrapperIndex: wrapperIndex,
      glucoseMgDl: glucoseMgDl,
      measuredAt: measuredAt,
      marker: marker,
      rawMarker: rawMarker,
      rawPayload:
          List<int>.unmodifiable(
            payload,
          ),
    );
  }

  static Gm700sbMealMarker
  _decodeMarker(int marker) {
    switch (marker) {
      case 0x00:
        return Gm700sbMealMarker.none;

      case 0x01:
        return Gm700sbMealMarker
            .beforeMeal;

      case 0x02:
        return Gm700sbMealMarker
            .afterMeal;

      case 0x03:
        return Gm700sbMealMarker.sport;

      default:
        return Gm700sbMealMarker
            .unknown;
    }
  }
}
