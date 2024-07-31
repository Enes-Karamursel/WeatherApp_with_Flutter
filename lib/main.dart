import 'package:flutter/material.dart';
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
                  canvasColor: Colors.black.withOpacity(0.7), // Açılan kutunun arka plan rengi
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
  final int temperature;
  final String weatherDescription;
  final String time;

  City(this.name, this.temperature, this.weatherDescription, this.time);

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
      final city = City(cityName, cityData['temperature'], cityData['description'], cityData['time']);
      _cities.add(city);
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> _fetchCityWeather(String cityName) async {
    final weatherUrl = 'https://api.openweathermap.org/data/2.5/weather?q=$cityName&units=metric&appid=$_apiKey';
    final response = await http.get(Uri.parse(weatherUrl));
    if (response.statusCode != 200) {
      return null;
    }

    final weatherData = json.decode(response.body);
    final temperature = weatherData['main']['temp'].toInt();
    final description = weatherData['weather'][0]['description'];
    final time = DateTime.now().toString();

    return {'temperature': temperature, 'description': description, 'time': time};
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
            const SizedBox(height: 5),
            Text(
              city.time,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
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
    String backgroundImage;

    switch (city.weatherDescription.toLowerCase()) {
      case 'clear sky':
      case 'few clouds':
        backgroundImage = 'assets/sunny2.png';
        break;
      case 'rain':
      case 'shower rain':
      case 'thunderstorm':
        backgroundImage = 'assets/rainy.png';
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
      default:
        backgroundImage = 'assets/cloudy.png';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${city.name} Weather',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF093DAB),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Consumer<CityWeatherProvider>(
            builder: (context, provider, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Derece
                  Text(
                    '${provider.temperatureUnit == 'Celsius' ? city.temperature : city.toFahrenheit()}°${provider.temperatureUnit == 'Celsius' ? 'C' : 'F'}',
                    style: const TextStyle(
                      fontSize: 64,
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
                      fontSize: 28,
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
                  const SizedBox(height: 140),
                  // Şehir ismi
                  const Text('My Location',
                    style: TextStyle(
                      fontSize: 30,
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
