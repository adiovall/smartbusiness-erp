class FuelMapping {
  static const Map<String, String> _toTankKey = {
    'Petrol (PMS)': 'PMS',
    'Diesel (AGO)': 'AGO',
    'Kerosene (HHK)': 'DPK',
    'Gas (LPG)': 'Gas',

    'PMS': 'PMS',
    'AGO': 'AGO',
    'HHK': 'DPK',
    'LPG': 'Gas',
    'DPK': 'DPK',
    'Gas': 'Gas',
  };

  // NEW: maps a stored abbreviation (PMS/AGO/DPK/Gas) back to the
  // full dropdown label used in sale_tab.dart's `fuels` list.
  static const Map<String, String> _toLabel = {
    'PMS': 'Petrol (PMS)',
    'AGO': 'Diesel (AGO)',
    'DPK': 'Kerosene (HHK)',
    'Gas': 'Gas (LPG)',
  };

  static String tankKey(String labelOrStored) {
    if (_toTankKey.containsKey(labelOrStored)) return _toTankKey[labelOrStored]!;

    final m = RegExp(r'\(([^)]+)\)').firstMatch(labelOrStored);
    final extracted = m?.group(1);

    if (extracted != null && _toTankKey.containsKey(extracted)) return _toTankKey[extracted]!;
    if (extracted != null) return extracted;

    return labelOrStored;
  }

  static String abbrFromLabel(String labelOrStored) {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(labelOrStored);
    return m?.group(1) ?? labelOrStored.split(' ').first;
  }

  // NEW
  static String labelFromAbbr(String abbr) {
    return _toLabel[abbr] ?? abbr;
  }
}