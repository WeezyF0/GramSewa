import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/services/serper_news.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, String>> centralNews = [];
  List<Map<String, String>> stateNews = [];
  List<Map<String, String>> generalStateNews = [];
  bool isLoading = false;
  String currentState = "";

  late SerperService serperService;

  @override
  void initState() {
    super.initState();
    final serperApiKey = dotenv.env['serper-api'] ?? "";
    serperService = SerperService(serperApiKey);
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    String locationName = await _getLocationName(position.latitude, position.longitude) ?? "Unknown";
    setState(() {
      currentState = locationName;
    });
    fetchNews(currentState);
  }

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      return placemarks.isNotEmpty ? placemarks.first.administrativeArea ?? "Unknown Location" : "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  Future<void> fetchNews(String state) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final centralNewsFuture = serperService.fetchSerperNews("Latest central government agriculture scheme site:.gov.in");
    final stateNewsFuture = serperService.fetchSerperNews("Latest $state state agriculture schemes site:.gov.in");
    final generalStateNewsFuture = serperService.fetchSerperNews("$state agriculture news site:news.google.com");

    final results = await Future.wait([centralNewsFuture, stateNewsFuture, generalStateNewsFuture]);

    setState(() {
      centralNews = results[0];
      stateNews = results[1];
      generalStateNews = results[2];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            foregroundDecoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "State & Central News",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark
                  ? 'assets/images/home_bg_night.jpeg'
                  : 'assets/images/home_bg_day.jpeg',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNewsSection(
                              "Central Government Agricultural Schemes",
                              centralNews,
                            ),
                            SizedBox(height: 24),
                            _buildNewsSection(
                              "State Government Agricultural Schemes",
                              stateNews,
                            ),
                            SizedBox(height: 24),
                            _buildNewsSection(
                              "General State News from $currentState",
                              generalStateNews,
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildNewsSection(String title, List<Map<String, String>> newsList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12),
        if (newsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No news available",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ...newsList.map((news) => _buildNewsCard(news)).toList(),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, String> news) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(news['url']!)),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                news['title']!,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                news['summary']!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
