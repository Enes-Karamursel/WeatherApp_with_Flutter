import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CityWeatherProvider(),
      child: const MaterialApp(
        home: Home(),
      ),
    ),
  );
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weather App',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'YourFontFamily',
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF093DAB),
        actions: [
          Consumer<CityWeatherProvider>(
            builder: (context, provider, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: Colors.black.withOpacity(0.7),
                ),
                child: DropdownButton<String>(
                  value: provider.temperatureUnit.isNotEmpty ? provider.temperatureUnit : null,
                  hint: const Text(
                    'Select Unit ',
                    style: TextStyle(color: Colors.white),
                  ),
                  icon: const Icon(Icons.sunny_snowing, color: Colors.white),
                  underline: Container(
                    height: 2,
                    color: Colors.white,
                  ),
                  onChanged: (String? newValue) {
                    provider.setTemperatureUnit(newValue ?? 'Celsius');
                  },
                  items: <String>['Celsius', 'Fahrenheit']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(color: Colors.white), // Yazı rengini beyaz yap
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CityWeatherProvider>(
        builder: (context, provider, child) {
          return ListView.builder(
            itemCount: provider.cities.length,
            itemBuilder: (context, index) {
              final city = provider.cities[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeatherDetailScreen(city: city),
                    ),
                  );
                },
                child: WeatherCard(
                  city: city,
                  temperatureUnit: provider.temperatureUnit,
                  onDelete: () {
                    provider.removeCity(index);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AddCityDialog();
            },
          );
        },
        backgroundColor: const Color(0xFF093DAB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddCityDialog extends StatefulWidget {
  @override
  _AddCityDialogState createState() => _AddCityDialogState();
}

class _AddCityDialogState extends State<AddCityDialog> {
  final TextEditingController _controller = TextEditingController();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add City'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Enter city name',
              errorText: errorMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final cityName = _controller.text;
            if (cityName.isNotEmpty) {
              final provider = Provider.of<CityWeatherProvider>(context, listen: false);
              final isValid = await provider.addCity(cityName);
              if (isValid) {
                Navigator.of(context).pop();
              } else {
                setState(() {
                  errorMessage = 'Invalid city name. Please try again.';
                });
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class City {
  final String name;
  final int temperature; // Celsius as int
  final String weatherDescription;
  final int humidity;
  final double windSpeed;
  final String sunrise;
  final String sunset;
  final List<Map<String, dynamic>> hourly;

  City(
      this.name,
      this.temperature,
      this.weatherDescription,
      this.humidity,
      this.windSpeed,
      this.sunrise,
      this.sunset,
      this.hourly,
      );

  int toFahrenheit() {
    return ((temperature * 9 / 5) + 32).round();
  }
}



class CityWeatherProvider with ChangeNotifier {
  List<City> _cities = [];
  final String _apiKey = '8b222abc8d47cc21c73e5e055b1936a9';

  List<City> get cities => _cities;
  String _temperatureUnit = '';

  String get temperatureUnit => _temperatureUnit;

  void setTemperatureUnit(String unit) {
    _temperatureUnit = unit;
    notifyListeners();
  }

  Future<bool> addCity(String cityName) async {
    final cityData = await _fetchCityWeather(cityName);
    if (cityData != null) {
      final city = City(
        cityName,
        cityData['temperature'],
        cityData['description'],
        cityData['humidity'],
        cityData['windSpeed'],
        cityData['sunrise'],
        cityData['sunset'],
        cityData['hourly'] ?? [],
      );
      _cities.add(city);
      notifyListeners();
      return true;
    }
    return false;
  }



  Future<Map<String, dynamic>?> _fetchCityWeather(String cityName) async {
    final weatherUrl = 'https://api.openweathermap.org/data/2.5/weather?q=$cityName&units=metric&appid=$_apiKey';
    final forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast?q=$cityName&units=metric&appid=$_apiKey';

    final weatherResponse = await http.get(Uri.parse(weatherUrl));
    final forecastResponse = await http.get(Uri.parse(forecastUrl));

    if (weatherResponse.statusCode != 200 || forecastResponse.statusCode != 200) {
      return null;
    }

    final weatherData = json.decode(weatherResponse.body);
    final forecastData = json.decode(forecastResponse.body);

    final temperature = weatherData['main']['temp'].toInt();
    final description = weatherData['weather'][0]['description'];
    final time = DateTime.now().toString();
    final humidity = weatherData['main']['humidity'];
    final windSpeed = weatherData['wind']['speed'].toDouble();
    final sunrise = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunrise'] * 1000).toLocal().toString();
    final sunset = DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunset'] * 1000).toLocal().toString();

    final hourly = (forecastData['list'] as List).map((entry) {
      final dateTime = DateTime.parse(entry['dt_txt']).toLocal();
      final temp = entry['main']['temp'].toInt();
      final weather = entry['weather'][0]['description'];
      return {
        'time': DateFormat('HH:mm').format(dateTime),
        'temp': temp,
        'weather': weather,
      };
    }).cast<Map<String, dynamic>>().toList();

    return {
      'temperature': temperature,
      'description': description,
      'time': time,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'sunrise': sunrise,
      'sunset': sunset,
      'hourly': hourly,
    };
  }



  void removeCity(int index) {
    if (index >= 0 && index < _cities.length) {
      _cities.removeAt(index);
      notifyListeners();
    }
  }
}

class WeatherCard extends StatelessWidget {
  final City city;
  final String temperatureUnit;
  final VoidCallback onDelete;

  const WeatherCard({
    super.key,
    required this.city,
    required this.temperatureUnit,
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(10.0),
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [Colors.blue, Colors.lightBlueAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  city.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              temperatureUnit == 'Celsius'
                  ? '${city.temperature}°C'
                  : '${city.toFahrenheit()}°F',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              city.weatherDescription,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData getWeatherIcon(String description) {
  switch (description.toLowerCase()) {
    case 'clear sky':
      return Icons.wb_sunny;
    case 'rain':
    case 'shower rain':
    case 'thunderstorm':
      return Icons.beach_access;
    case 'few clouds':
    case 'scattered clouds':
    case 'broken clouds':
      return Icons.cloud;
    case 'snow':
      return Icons.ac_unit;
    case 'mist':
    case 'fog':
      return Icons.blur_on;
    default:
      return Icons.cloud;
  }
}


class WeatherDetailScreen extends StatelessWidget {
  final City city;

  const WeatherDetailScreen({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    String backgroundImage;

    switch (city.weatherDescription.toLowerCase()) {
      case 'clear sky':
        backgroundImage = 'assets/sunny2.png';
        break;
      case 'rain':
      case 'shower rain':
      case 'thunderstorm':
        backgroundImage = 'assets/rainy.png';
        break;
      case 'few clouds':
        backgroundImage = 'assets/few_clouds.png';
        break;
      case 'snow':
        backgroundImage = 'assets/snowy.png';
        break;
      case 'mist':
      case 'fog':
        backgroundImage = 'assets/foggy.png';
        break;
      case 'scattered clouds':
        backgroundImage = 'assets/cloudy2.png';
        break;
      default:
        backgroundImage = 'assets/cloudy.png';
    }

    // Format the sunrise and sunset times to show only hours and minutes
    String formatTime(String dateTimeString) {
      final DateTime dateTime = DateTime.parse(dateTimeString).toLocal();
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    // Get current hour
    final currentHour = DateTime.now().hour;

    // Get the next 24 hourly data starting from current hour
    List<Map<String, dynamic>> next24Hours = [];
    for (int i = 0; i < city.hourly.length; i++) {
      final hourData = city.hourly[i];
      final hour = int.parse(hourData['time'].split(':')[0]);
      if (hour >= currentHour || next24Hours.length < 24) {
        next24Hours.add(hourData);
      }
      if (next24Hours.length >= 24) break;
    }

    // If less than 24 hours of data, wrap around to the beginning of the list
    if (next24Hours.length < 24) {
      for (int i = 0; i < city.hourly.length; i++) {
        if (next24Hours.length >= 24) break;
        next24Hours.add(city.hourly[i]);
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(backgroundImage),
                fit: BoxFit.cover,
              ),
            ),
          ),

          SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  Consumer<CityWeatherProvider>(
                    builder: (context, provider, child) {
                      String temperature = provider.temperatureUnit == 'Celsius'
                          ? '${city.temperature}°C'
                          : '${city.toFahrenheit()}°F';

                      return Column(
                        children: [
                          const SizedBox(height: 110),
                          // Derece
                          Text(
                            temperature,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 5.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          // Hava durumu açıklaması
                          Text(
                            city.weatherDescription,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w400,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Şehir ismi
                          const Text('My Location',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 1.1,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            city.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 1.1,
                              shadows: [
                                Shadow(
                                  offset: Offset(2.0, 2.0),
                                  blurRadius: 2.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Bilgileri card şeklinde göster
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        context,
                                        title: 'Humidity',
                                        value: '${city.humidity}%',
                                        icon: Icons.water_drop,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildInfoCard(
                                        context,
                                        title: 'Wind Speed',
                                        value: '${city.windSpeed} m/s',
                                        icon: Icons.wind_power,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildInfoCard(
                                        context,
                                        title: 'Sunrise',
                                        value: formatTime(city.sunrise), // Format time
                                        icon: Icons.wb_sunny,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildInfoCard(
                                        context,
                                        title: 'Sunset',
                                        value: formatTime(city.sunset), // Format time
                                        icon: Icons.nightlight_round,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                // Saatlik hava durumu
                                Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Text(
                                        'Hourly Prediction',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(2.0, 2.0),
                                              blurRadius: 2.0,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: 150,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: next24Hours.length,
                                        itemBuilder: (context, index) {
                                          final hourData = next24Hours[index];
                                          return _buildHourlyCard(
                                            context,
                                            time: hourData['time'],
                                            temp: hourData['temp'],
                                            weather: hourData['weather'],
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                print('buton çalışıyor');
                Navigator.pop(context);
              },
            ),
          ),
          Positioned(
            top: 40,
            left: 50,
            right: 50,
            child: Center(
              child: Text(
                'Weather Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2.0, 2.0),
                      blurRadius: 5.0,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blueAccent, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyCard(BuildContext context, {required String time, required int temp, required String weather}) {
    return Container(
      width: 70,
      margin: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Icon(
            getWeatherIcon(weather),
            color: weather.toLowerCase() == 'clear sky' ? Colors.orange : Colors.white,
            size: 24,
          ),
          const SizedBox(height: 5),
          Text(
            '$temp°',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            weather,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  IconData getWeatherIcon(String description) {
    switch (description.toLowerCase()) {
      case 'clear sky':
        return Icons.wb_sunny;
      case 'rain':
      case 'shower rain':
      case 'thunderstorm':
        return Icons.beach_access;
      case 'few clouds':
      case 'scattered clouds':
      case 'broken clouds':
        return Icons.cloud;
      case 'snow':
        return Icons.ac_unit;
      case 'mist':
      case 'fog':
        return Icons.blur_on;
      default:
        return Icons.cloud;
    }
  }
}











