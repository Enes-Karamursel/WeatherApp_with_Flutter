import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      home: Home(),
    );
  }
}

class City {
  final String name;
  final int temperature;
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

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'temperature': temperature,
      'weatherDescription': weatherDescription,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'sunrise': sunrise,
      'sunset': sunset,
      'hourly': jsonEncode(hourly),
    };
  }

  factory City.fromMap(Map<String, dynamic> map) {
    return City(
      map['name'],
      map['temperature'],
      map['weatherDescription'],
      map['humidity'],
      map['windSpeed'].toDouble(),
      map['sunrise'],
      map['sunset'],
      List<Map<String, dynamic>>.from(jsonDecode(map['hourly'])),
    );
  }
}

class CityWeatherController extends GetxController {
  var cities = <City>[].obs;
  var temperatureUnit = 'Celsius'.obs;
  Timer? _timer;

  CityWeatherController() {
    loadCities();
    _startAutoRefresh();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void setTemperatureUnit(String unit) {
    temperatureUnit.value = unit;
  }

  String formatTemperature(int celsius) {
    if (temperatureUnit.value == 'Fahrenheit') {
      return '${((celsius * 9 / 5) + 32).round()}°F';
    } else {
      return '$celsius°C';
    }
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
      cities.add(city);
      saveCities();
      return true;
    } else {
      return false;
    }
  }

  void removeCity(int index) {
    cities.removeAt(index);
    saveCities();
  }

  Future<void> saveCities() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> cityList = cities.map((city) => jsonEncode(city.toMap())).toList();
    prefs.setStringList('cities', cityList);
  }

  Future<void> loadCities() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? cityList = prefs.getStringList('cities');
    if (cityList != null) {
      cities.value = cityList.map((cityString) {
        Map<String, dynamic> cityMap = jsonDecode(cityString);
        return City.fromMap(cityMap);
      }).toList();
    }
  }

  Future<void> refreshCities() async {
    for (var i = 0; i < cities.length; i++) {
      final updatedCityData = await _fetchCityWeather(cities[i].name);
      if (updatedCityData != null) {
        cities[i] = City(
          cities[i].name,
          updatedCityData['temperature'],
          updatedCityData['description'],
          updatedCityData['humidity'],
          updatedCityData['windSpeed'],
          updatedCityData['sunrise'],
          updatedCityData['sunset'],
          updatedCityData['hourly'] ?? [],
        );
      }
    }
    saveCities();
  }

  void _startAutoRefresh() {
    _timer = Timer.periodic(const Duration(minutes: 10), (timer)
    {
      refreshCities();
    });
  }

  Future<Map<String, dynamic>?> _fetchCityWeather(String cityName) async {
    try {
      final weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?q=$cityName&units=metric&appid=8b222abc8d47cc21c73e5e055b1936a9';
      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?q=$cityName&units=metric&appid=8b222abc8d47cc21c73e5e055b1936a9';

      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      final forecastResponse = await http.get(Uri.parse(forecastUrl));

      if (weatherResponse.statusCode == 200 && forecastResponse.statusCode == 200) {
        final weatherData = json.decode(weatherResponse.body);
        final forecastData = json.decode(forecastResponse.body);

        final temperature = weatherData['main']['temp'].toInt();
        final description = weatherData['weather'][0]['description'];
        final humidity = weatherData['main']['humidity'];
        final windSpeed = weatherData['wind']['speed'].toDouble();
        final sunrise =
        DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunrise'] * 1000).toLocal().toString();
        final sunset =
        DateTime.fromMillisecondsSinceEpoch(weatherData['sys']['sunset'] * 1000).toLocal().toString();

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
          'humidity': humidity,
          'windSpeed': windSpeed,
          'sunrise': sunrise,
          'sunset': sunset,
          'hourly': hourly,
        };
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final CityWeatherController controller = Get.put(CityWeatherController());

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Weather App',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Obx(() {
            return DropdownButton<String>(
              hint: const Text(
                'Select Unit ',
                style: TextStyle(color: Colors.black),
              ),
              icon: const Icon(Icons.sunny_snowing, color: Colors.black),
              underline: Container(
                height: 1.5,
                color: Colors.black,
              ),
              value: controller.temperatureUnit.value.isEmpty ? null : controller.temperatureUnit.value,
              onChanged: (newValue) {
                controller.setTemperatureUnit(newValue ?? 'Celsius');
              },
              items: <String>['Celsius', 'Fahrenheit'].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(color: Colors.black)),
                );
              }).toList(),
            );
          }),
        ],
      ),
      body: Obx(() => ListView.builder(
        itemCount: controller.cities.length,
        itemBuilder: (context, index) {
          final city = controller.cities[index];
          return GestureDetector(
            onTap: () {
              Get.to(() => WeatherDetailScreen(city: city));
            },
            child: WeatherCard(
              city: city,
              onDelete: () {
                controller.removeCity(index);
              },
            ),
          );
        },
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) {
              return AddCityDialog(controller: controller);
            },
          );
        },
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class AddCityDialog extends StatefulWidget {
  final CityWeatherController controller;

  const AddCityDialog({super.key, required this.controller});

  @override
  _AddCityDialogState createState() {
    return _AddCityDialogState();
  }
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
        ElevatedButton(
          onPressed: () async {
            final cityName = _controller.text;
            if (cityName.isNotEmpty) {
              final isValid = await widget.controller.addCity(cityName);
              if (isValid) {
                Get.back();
                Get.snackbar(
                  'Success',
                  'City is added successfully!',
                  snackPosition: SnackPosition.TOP,
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 1),
                );
              } else {
                setState(() {
                  errorMessage = 'Invalid city name. Please try again.';
                });
              }
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class WeatherCard extends StatelessWidget {
  final City city;
  final VoidCallback onDelete;
  final CityWeatherController controller = Get.find();

  WeatherCard({
    super.key,
    required this.city,
    required this.onDelete,
  });

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
      case 'heavy intensity rain':
      case 'light rain':
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
        backgroundImage = 'assets/cloudy3.png';
        break;
      default:
        backgroundImage = 'assets/cloudy.png';
    }

    return Card(
      margin: const EdgeInsets.all(10.0),
      child: Container(
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
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
            Obx(() {
              String temperature = controller.temperatureUnit.value == 'Celsius'
                  ? '${city.temperature}°C'
                  : '${city.toFahrenheit()}°F';
              return Text(
                temperature,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }),
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


class WeatherDetailScreen extends StatelessWidget {
  final City city;

  const WeatherDetailScreen({super.key, required this.city});

  @override
  Widget build(BuildContext context) {
    // Obtain the controller using Get.find()
    final CityWeatherController controller = Get.find<CityWeatherController>();

    String backgroundImage;

    switch (city.weatherDescription.toLowerCase()) {
      case 'clear sky':
        backgroundImage = 'assets/sunny2.png';
        break;
      case 'rain':
      case 'shower rain':
      case 'thunderstorm':
      case 'light rain':
      case 'heavy intensity rain':
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
        backgroundImage = 'assets/cloudy3.png';
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
      if (hour >= currentHour || next24Hours.length < 9) {
        next24Hours.add(hourData);
      }
      if (next24Hours.length >= 9) break;
    }

    // If less than 24 hours of data, wrap around to the beginning of the list
    if (next24Hours.length < 9) {
      for (int i = 0; i < city.hourly.length; i++) {
        if (next24Hours.length >= 9) break;
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
          Container(
            decoration: const BoxDecoration(
              color: Colors.black12,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Obx(() {
                    String temperature = controller.temperatureUnit.value == 'Celsius'
                        ? '${city.temperature}°C'
                        : '${city.toFahrenheit()}°F';

                    return Column(
                      children: [
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 30),
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
                                  SizedBox(
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
                                          controller: controller, // Pass controller
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
                  }),
                ],
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () {
                Get.back();
              },
            ),
          ),
          const Positioned(
            top: 42,
            left: 50,
            right: 50,
            child: Center(
              child: Text(
                'Weather Details',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decorationColor: Colors.white,
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
      color: const Color.fromARGB(5, 255, 255, 255),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xEDEFEFEF), size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xEDEFEFEF),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xEDEFEFEF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyCard(BuildContext context, {required String time, required int temp, required String weather, required CityWeatherController controller}) {
    return Container(
      width: 70,
      margin: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            time,
            style: const TextStyle(
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
          Obx(() {
            String formattedTemp = controller.formatTemperature(temp);
            return Text(
              formattedTemp,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }),
          const SizedBox(height: 5),
          Text(
            weather,
            style: const TextStyle(
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
      case 'light rain':
      case 'heavy intensity rain':
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

