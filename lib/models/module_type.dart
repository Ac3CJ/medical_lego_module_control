enum ModuleType {
  temperature,
  infrared,
  vibration,
  unknown,
}

extension ParseToString on ModuleType {
  String toShortString() {
    return toString().split('.').last;
  }
}