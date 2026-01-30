import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const WeatherHomePage(title: 'Weather App'),
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key, required this.title});
  final String title;

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final _service = WeatherService(
    client: http.Client(),
    apiKey: 'ef1bc8a75498e98ecd3970f3667e1394', // Throwaway API key, store securely in real apps
  );

  late Future<Weather> _weatherFuture;

  static const _lat = 48.5635765;
  static const _lon = -123.4684807;

  @override
  void initState() {
    super.initState();
    _weatherFuture = _service.fetchWeather(lat: _lat, lon: _lon, lang: 'en');
  }

  void _refresh() {
    setState(() {
      _weatherFuture = _service.fetchWeather(lat: _lat, lon: _lon, lang: 'en');
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<Weather>(
            future: _weatherFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }

              final weather = snapshot.data;
              if (weather == null) {
                return ErrorState(
                  message: 'No weather data returned.',
                  onRetry: _refresh,
                );
              }

              return WeatherView(weather: weather);
            },
          ),
        ),
      ),
    );
  }
}

/// ---------------------------
/// Domain model
/// ---------------------------

class Weather {
  final String city;
  final String description;
  final String iconCode;
  final double tempK;
  final double feelsLikeK;
  final int humidity;
  final double windSpeed;
  final int pressure;

  const Weather({
    required this.city,
    required this.description,
    required this.iconCode,
    required this.tempK,
    required this.feelsLikeK,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
  });

  int get tempC => (tempK - 273.15).round();
  int get feelsLikeC => (feelsLikeK - 273.15).round();

  factory Weather.fromJson(Map<String, dynamic> json) {
    final weather0 = (json['weather'] as List).first as Map<String, dynamic>;
    final main = json['main'] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;

    return Weather(
      city: (json['name'] ?? '').toString(),
      description: (weather0['description'] ?? '').toString(),
      iconCode: (weather0['icon'] ?? '').toString(),
      tempK: (main['temp'] as num).toDouble(),
      feelsLikeK: (main['feels_like'] as num).toDouble(),
      humidity: (main['humidity'] as num).toInt(),
      windSpeed: (wind['speed'] as num).toDouble(),
      pressure: (main['pressure'] as num).toInt(),
    );
  }
}

/// ---------------------------
/// Service layer
/// ---------------------------

class WeatherService {
  WeatherService({required http.Client client, required String apiKey})
      : _client = client,
        _apiKey = apiKey;

  final http.Client _client;
  final String _apiKey;

  Future<Weather> fetchWeather({
    required double lat,
    required double lon,
    String lang = 'en',
  }) async {
    final uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'lang': lang,
      'appid': _apiKey,
    });

    final res = await _client.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Failed to load weather: ${res.statusCode} ${res.body}');
    }

    final jsonMap = jsonDecode(res.body) as Map<String, dynamic>;
    return Weather.fromJson(jsonMap);
  }

  void dispose() {
    _client.close();
  }
}

/// ---------------------------
/// UI components
/// ---------------------------

class WeatherView extends StatelessWidget {
  const WeatherView({super.key, required this.weather});
  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(weather.city, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          WeatherEmoji.fromIconCode(weather.iconCode),
          style: const TextStyle(fontSize: 80),
        ),
        const SizedBox(height: 16),
        Text('${weather.tempC}°C', style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          weather.description.toUpperCase(),
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        WeatherDetailsCard(weather: weather),
      ],
    );
  }
}

class WeatherDetailsCard extends StatelessWidget {
  const WeatherDetailsCard({super.key, required this.weather});
  final Weather weather;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _DetailRow(label: 'Feels like', value: '${weather.feelsLikeC}°C'),
            const SizedBox(height: 8),
            _DetailRow(label: 'Humidity', value: '${weather.humidity}%'),
            const SizedBox(height: 8),
            _DetailRow(label: 'Wind Speed', value: '${weather.windSpeed} m/s'),
            const SizedBox(height: 8),
            _DetailRow(label: 'Pressure', value: '${weather.pressure} hPa'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value),
      ],
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 60),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

/// Keep the emoji mapping out of your widget classes.
class WeatherEmoji {
  static String fromIconCode(String iconCode) {
    if (iconCode.length < 2) return '🌤️';

    switch (iconCode.substring(0, 2)) {
      case '01':
        return '☀️';
      case '02':
        return '⛅';
      case '03':
      case '04':
        return '☁️';
      case '09':
        return '🌦️';
      case '10':
        return '🌧️';
      case '11':
        return '⛈️';
      case '13':
        return '❄️';
      case '50':
        return '🌫️';
      default:
        return '🌤️';
    }
  }
}
