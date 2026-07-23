import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'weather_preferences_service.dart';

class WeatherForecastService {
  WeatherForecastService._();

  static const _cacheKeyPrefix = 'local_weather_forecast_cache_v1';
  static const _cacheMaxAge = Duration(minutes: 45);
  static const _timeout = Duration(seconds: 12);

  static String _cacheKey(WeatherTemperatureUnit unit) =>
      '${_cacheKeyPrefix}_${unit.name}';

  static Future<WeatherForecast?> getCachedForecast({
    required WeatherTemperatureUnit unit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey(unit));
    if (raw == null || raw.isEmpty) return null;
    try {
      return WeatherForecast.fromJson(
        Map<String, Object?>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WeatherForecast> getLocalForecast({
    bool forceRefresh = false,
    required WeatherTemperatureUnit unit,
  }) async {
    final cached = await getCachedForecast(unit: unit);
    final now = DateTime.now();
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt) < _cacheMaxAge) {
      return cached;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const WeatherForecastException(
        WeatherForecastError.locationServicesDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const WeatherForecastException(WeatherForecastError.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const WeatherForecastException(WeatherForecastError.deniedForever);
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(_timeout);

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': position.latitude.toStringAsFixed(4),
      'longitude': position.longitude.toStringAsFixed(4),
      'current':
          'temperature_2m,apparent_temperature,weather_code,precipitation,wind_speed_10m',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum',
      'hourly': 'temperature_2m,weather_code',
      'temperature_unit': unit.apiValue,
      'wind_speed_unit': unit.windSpeedApiValue,
      'precipitation_unit': unit == WeatherTemperatureUnit.fahrenheit
          ? 'inch'
          : 'mm',
      'timezone': 'auto',
      'forecast_days': '10',
    });

    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const WeatherForecastException(WeatherForecastError.network);
    }

    final json = Map<String, Object?>.from(jsonDecode(response.body) as Map);
    final forecast = WeatherForecast.fromOpenMeteo(json, fetchedAt: now);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey(unit), jsonEncode(forecast.toJson()));
    return forecast;
  }
}

enum WeatherForecastError {
  denied,
  deniedForever,
  locationServicesDisabled,
  network,
  parse,
}

class WeatherForecastException implements Exception {
  const WeatherForecastException(this.error);

  final WeatherForecastError error;
}

class WeatherForecast {
  const WeatherForecast({
    required this.fetchedAt,
    required this.timezone,
    required this.currentTemperature,
    required this.currentApparentTemperature,
    required this.currentWeatherCode,
    required this.currentPrecipitation,
    required this.currentWindSpeed,
    required this.days,
    this.hours = const [],
  });

  final DateTime fetchedAt;
  final String timezone;
  final double currentTemperature;
  final double currentApparentTemperature;
  final int currentWeatherCode;
  final double currentPrecipitation;
  final double currentWindSpeed;
  final List<WeatherDay> days;
  final List<WeatherHour> hours;

  WeatherDay? get today => days.isEmpty ? null : days.first;

  factory WeatherForecast.fromOpenMeteo(
    Map<String, Object?> json, {
    required DateTime fetchedAt,
  }) {
    try {
      final current = Map<String, Object?>.from(json['current'] as Map);
      final daily = Map<String, Object?>.from(json['daily'] as Map);

      final times = List<String>.from(daily['time'] as List);
      final codes = _numList(daily['weather_code']);
      final highs = _numList(daily['temperature_2m_max']);
      final lows = _numList(daily['temperature_2m_min']);
      final rainChances = _numList(daily['precipitation_probability_max']);
      final precipitation = _numList(daily['precipitation_sum']);

      final days = <WeatherDay>[];
      for (var i = 0; i < times.length; i++) {
        days.add(
          WeatherDay(
            date: DateTime.parse(times[i]),
            weatherCode: codes[i].round(),
            highTemperature: highs[i],
            lowTemperature: lows[i],
            precipitationProbability: rainChances[i].round(),
            precipitationSum: precipitation[i],
          ),
        );
      }

      final hours = <WeatherHour>[];
      final hourly = json['hourly'];
      if (hourly is Map) {
        final hourlyMap = Map<String, Object?>.from(hourly);
        final hourTimes = List<String>.from(hourlyMap['time'] as List);
        final hourTemps = _numList(hourlyMap['temperature_2m']);
        final hourCodes = _numList(hourlyMap['weather_code']);
        for (var i = 0; i < hourTimes.length; i++) {
          hours.add(
            WeatherHour(
              time: DateTime.parse(hourTimes[i]),
              temperature: hourTemps[i],
              weatherCode: hourCodes[i].round(),
            ),
          );
        }
      }

      return WeatherForecast(
        fetchedAt: fetchedAt,
        timezone: json['timezone']?.toString() ?? 'auto',
        currentTemperature: _asDouble(current['temperature_2m']),
        currentApparentTemperature: _asDouble(current['apparent_temperature']),
        currentWeatherCode: _asDouble(current['weather_code']).round(),
        currentPrecipitation: _asDouble(current['precipitation']),
        currentWindSpeed: _asDouble(current['wind_speed_10m']),
        days: days,
        hours: hours,
      );
    } catch (_) {
      throw const WeatherForecastException(WeatherForecastError.parse);
    }
  }

  factory WeatherForecast.fromJson(Map<String, Object?> json) {
    return WeatherForecast(
      fetchedAt: DateTime.parse(json['fetchedAt'].toString()),
      timezone: json['timezone']?.toString() ?? 'auto',
      currentTemperature: _asDouble(json['currentTemperature']),
      currentApparentTemperature: _asDouble(json['currentApparentTemperature']),
      currentWeatherCode: _asDouble(json['currentWeatherCode']).round(),
      currentPrecipitation: _asDouble(json['currentPrecipitation']),
      currentWindSpeed: _asDouble(json['currentWindSpeed']),
      days: (json['days'] as List? ?? const [])
          .map(
            (item) =>
                WeatherDay.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
      hours: (json['hours'] as List? ?? const [])
          .map(
            (item) =>
                WeatherHour.fromJson(Map<String, Object?>.from(item as Map)),
          )
          .toList(),
    );
  }

  Map<String, Object?> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'timezone': timezone,
    'currentTemperature': currentTemperature,
    'currentApparentTemperature': currentApparentTemperature,
    'currentWeatherCode': currentWeatherCode,
    'currentPrecipitation': currentPrecipitation,
    'currentWindSpeed': currentWindSpeed,
    'days': days.map((day) => day.toJson()).toList(),
    'hours': hours.map((hour) => hour.toJson()).toList(),
  };
}

/// 시간별 예보 한 칸.
class WeatherHour {
  const WeatherHour({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final int weatherCode;

  factory WeatherHour.fromJson(Map<String, Object?> json) {
    return WeatherHour(
      time: DateTime.parse(json['time'].toString()),
      temperature: _asDouble(json['temperature']),
      weatherCode: _asDouble(json['weatherCode']).round(),
    );
  }

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'temperature': temperature,
    'weatherCode': weatherCode,
  };
}

class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.weatherCode,
    required this.highTemperature,
    required this.lowTemperature,
    required this.precipitationProbability,
    required this.precipitationSum,
  });

  final DateTime date;
  final int weatherCode;
  final double highTemperature;
  final double lowTemperature;
  final int precipitationProbability;
  final double precipitationSum;

  factory WeatherDay.fromJson(Map<String, Object?> json) {
    return WeatherDay(
      date: DateTime.parse(json['date'].toString()),
      weatherCode: _asDouble(json['weatherCode']).round(),
      highTemperature: _asDouble(json['highTemperature']),
      lowTemperature: _asDouble(json['lowTemperature']),
      precipitationProbability: _asDouble(
        json['precipitationProbability'],
      ).round(),
      precipitationSum: _asDouble(json['precipitationSum']),
    );
  }

  Map<String, Object?> toJson() => {
    'date': date.toIso8601String(),
    'weatherCode': weatherCode,
    'highTemperature': highTemperature,
    'lowTemperature': lowTemperature,
    'precipitationProbability': precipitationProbability,
    'precipitationSum': precipitationSum,
  };
}

List<double> _numList(Object? raw) {
  return (raw as List).map(_asDouble).toList();
}

double _asDouble(Object? raw) {
  if (raw is num) return raw.toDouble();
  return double.parse(raw.toString());
}
