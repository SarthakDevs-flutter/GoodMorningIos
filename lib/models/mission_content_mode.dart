enum MissionContentMode {
  scriptureAndPrayer,
  scriptureOnly,
  prayerOnly;

  static MissionContentMode fromStorageValue(String? value) {
    return MissionContentMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => MissionContentMode.scriptureAndPrayer,
    );
  }

  bool get includesScripture {
    return this == MissionContentMode.scriptureAndPrayer ||
        this == MissionContentMode.scriptureOnly;
  }

  bool get includesPrayer {
    return this == MissionContentMode.scriptureAndPrayer ||
        this == MissionContentMode.prayerOnly;
  }
}
