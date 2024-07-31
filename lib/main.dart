import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CityWeatherProvider(),
      child: MaterialApp(
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
        title: Text(
          'Weather App',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.pinkAccent,
        actions: [
          Consumer<CityWeatherProvider>(
            builder: (context, provider, child) {
              return DropdownButton<String>(
                value: provider.temperatureUnit.isNotEmpty ? provider.temperatureUnit : null,
                hint: Text(
                  'Select Unit ',
                  style: TextStyle(color: Colors.white, fontSize: 15)
                ),
                icon: Icon(Icons.sunny_snowing, color: Colors.white, size: 20),
                underline: Container(
                  height: 1.5,
                  color: Colors.white,
                ),
                onChanged: (String? newValue) {
                  provider.setTemperatureUnit(newValue ?? 'Celsius');
                },
                items: <String>['Celsius', 'Fahrenheit']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
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
                child: Stack(
                  children: [
                    Card(
                      margin: EdgeInsets.all(10.0),
                      child: ListTile(
                        title: Text(city.name),
                        trailing: Text(
                          provider.temperatureUnit == 'Celsius'
                              ? '${city.temperature}°C'
                              : '${city.toFahrenheit()}°F',
                        ),
                      ),
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.black.withOpacity(0.1),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.close, color: Colors.black, size: 14),
                          onPressed: () {
                            provider.removeCity(index);
                          },
                        ),
                      ),
                    ),
                  ],
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
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.pinkAccent,
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
      title: Text('Add City'),
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
              final provider =
              Provider.of<CityWeatherProvider>(context, listen: false);
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
          child: Text('Add'),
        ),
      ],
    );
  }
}

class City {
  final String name;
  final int temperature;
  final String weatherDescription;

  City(this.name, this.temperature, this.weatherDescription);

  int toFahrenheit() {
    return ((temperature * 9 / 5) + 32).round();
  }
}

class CityWeatherProvider with ChangeNotifier {
  List<City> _cities = [];
  final String _apiKey = '8b222abc8d47cc21c73e5e055b1936a9'; // OpenWeatherMap API anahtarınızı buraya ekleyin.

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
      final city = City(cityName, cityData['temperature'], cityData['description']);
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
      print('Failed to fetch weather for $cityName: ${response.body}');
      return null;
    }

    final weatherData = json.decode(response.body);
    final temperature = weatherData['main']['temp'].toInt();
    final description = weatherData['weather'][0]['description'];

    return {'temperature': temperature, 'description': description};
  }

  void removeCity(int index) {
    if (index >= 0 && index < _cities.length) {
      _cities.removeAt(index);
      notifyListeners();
    }
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
        backgroundImage = 'assets/sunny.png';
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
      default:
        backgroundImage = 'assets/cloudy.png';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${city.name} Weather'),
        backgroundColor: Colors.pinkAccent,
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
              return Text(
                '${city.name}\n${provider.temperatureUnit == 'Celsius' ? city.temperature : city.toFahrenheit()}°${provider.temperatureUnit == 'Celsius' ? 'C' : 'F'}\n${city.weatherDescription}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  backgroundColor: Colors.black.withOpacity(0.5),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
