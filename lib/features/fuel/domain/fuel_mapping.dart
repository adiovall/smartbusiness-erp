class FuelMapping {
  static const Map<String, String> _toTankKey = {
    'Petrol (PMS)': 'PMS',
    'Diesel (AGO)': 'AGO',
    'Kerosene (HHK)': 'DPK', // tank uses DPK
    'Gas (LPG)': 'Gas',      // tank uses Gas

    // allow abbreviations too
    'PMS': 'PMS',
    'AGO': 'AGO',
    'HHK': 'DPK',
    'LPG': 'Gas',
    'DPK': 'DPK',
    'Gas': 'Gas',
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
}
