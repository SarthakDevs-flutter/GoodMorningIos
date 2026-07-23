enum ScripturePlan {
  daily,
  beloved52;

  static ScripturePlan fromStorageValue(String? value) {
    return ScripturePlan.values.firstWhere(
      (plan) => plan.name == value,
      orElse: () => ScripturePlan.daily,
    );
  }
}
