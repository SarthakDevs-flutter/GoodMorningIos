import 'package:shared_preferences/shared_preferences.dart';

enum WeatherTemperatureUnit {
  fahrenheit,
  celsius;

  String get apiValue {
    switch (this) {
      case WeatherTemperatureUnit.fahrenheit:
        return 'fahrenheit';
      case WeatherTemperatureUnit.celsius:
        return 'celsius';
    }
  }

  String get symbol {
    switch (this) {
      case WeatherTemperatureUnit.fahrenheit:
        return '°F';
      case WeatherTemperatureUnit.celsius:
        return '°C';
    }
  }

  String get windSpeedApiValue {
    switch (this) {
      case WeatherTemperatureUnit.fahrenheit:
        return 'mph';
      case WeatherTemperatureUnit.celsius:
        return 'kmh';
    }
  }

  String get windSpeedLabel {
    switch (this) {
      case WeatherTemperatureUnit.fahrenheit:
        return 'mph';
      case WeatherTemperatureUnit.celsius:
        return 'km/h';
    }
  }
}

class WeatherPreferencesService {
  WeatherPreferencesService._();

  static const _enabledKey = 'local_weather_enabled_v1';
  static const _temperatureUnitKey = 'local_weather_temperature_unit_v1';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  static Future<WeatherTemperatureUnit> getTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_temperatureUnitKey);
    return WeatherTemperatureUnit.values.firstWhere(
      (unit) => unit.name == raw,
      orElse: () => WeatherTemperatureUnit.fahrenheit,
    );
  }

  static Future<void> setTemperatureUnit(WeatherTemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_temperatureUnitKey, unit.name);
  }
}
