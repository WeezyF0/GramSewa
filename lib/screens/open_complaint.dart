import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:string_similarity/string_similarity.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;


class OpenComplaintScreen extends StatefulWidget {
  final Map<String, dynamic> complaintData;
  final String complaintId;

  const OpenComplaintScreen({
    super.key, 
    required this.complaintData,
    required this.complaintId,
  });

  @override
  State<OpenComplaintScreen> createState() => _OpenComplaintScreenState();
}

class _OpenComplaintScreenState extends State<OpenComplaintScreen> {
  final ComplaintAnalyzer _analyzer = ComplaintAnalyzer();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _analysisResult = {};
  bool _isAnalyzing = false;
  final TextEditingController _updateController = TextEditingController(); // Added missing controller

  @override
  void initState() {
    super.initState();
    _analyzeComplaint();
  }

  @override
  void dispose() {
    _isAnalyzing = false;
    _updateController.dispose(); // Added disposal of controller
    super.dispose();
  }

  Future<void> _analyzeComplaint() async {
    if (_isAnalyzing || !mounted) return;

    try {
      _isAnalyzing = true;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      }

      double? latitude;
      double? longitude;
      if (widget.complaintData.containsKey('latitude') && 
          widget.complaintData.containsKey('longitude')) {
        latitude = (widget.complaintData['latitude'] as num).toDouble();
        longitude = (widget.complaintData['longitude'] as num).toDouble();
      }

      final result = await _analyzer.analyzeComplaint(
        widget.complaintData['location'] ?? 'Unknown location',
        widget.complaintData['text'] ?? 'No complaint text',
        latitude: latitude,
        longitude: longitude
      );

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to analyze complaint: ${e.toString()}';
        });
      }
    } finally {
      _isAnalyzing = false;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  void _navigateToChatbot() {
    // Navigate to your chatbot screen here
    Navigator.pushNamed(context, '/chatbot', arguments: {
      'complaintId': widget.complaintId,
      'complaintText': widget.complaintData['text'] ?? 'No complaint text',
      'location': widget.complaintData['location'] ?? 'Unknown location',
    });
  }

  Widget _buildAddUpdateButton() {
    return FloatingActionButton(
      mini: true,
      backgroundColor: Theme.of(context).primaryColor,
      onPressed: _showAddUpdateDialog,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
  
  Future<void> _showAddUpdateDialog() async {
    return showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Update'),
            content: TextField(
              controller: _updateController,
              decoration: const InputDecoration(
                hintText: 'Enter update details...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_updateController.text.isEmpty) return;
                  await _addUpdateToFirestore(_updateController.text);
                  Navigator.pop(context);
                  _updateController.clear();
                },
                child: const Text('Add Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _addUpdateToFirestore(String updateText) async {
    try {
      final updateData = {
        'context': updateText,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('complaints')
          .doc(widget.complaintId)
          .update({
            'Updates': FieldValue.arrayUnion([updateData]),
            'update_count': FieldValue.increment(1),
          });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add update: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration( // Added missing const
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
                  Colors.purple.withOpacity(0.3)
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color ?? Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text( // Added missing const
                        "COMPLAINT DETAILS",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: theme.appBarTheme.iconTheme?.color ?? Colors.white,
                        ),
                        onPressed: _analyzeComplaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildAnalysisView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToChatbot,
        icon: const Icon(Icons.chat),
        label: const Text('Get AI Insights'),
      ),
    );
  }

  Widget _buildErrorView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _analyzeComplaint,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComplaintCard(),
          const SizedBox(height: 16),
          _buildChatbotRedirectCard(),
          const SizedBox(height: 16),
          _buildUpdatesCard(), // Added missing widget call
          const SizedBox(height: 16),
          _buildSimilarComplaintsSection(),
          const SizedBox(height: 16),
          _buildNewsSection(),
        ],
      ),
    );
  }

  Widget _buildComplaintCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.complaintData['issue_type'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.complaintData['issue_type'],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 12),
            Text(
              widget.complaintData['text'] ?? 'No complaint text',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16,
                    color: theme.iconTheme.color ?? Colors.black54),
                const SizedBox(width: 4),
                Text(
                  widget.complaintData['location'] ?? 'Unknown location',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (widget.complaintData['timestamp'] != null)
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 16,
                      color: theme.iconTheme.color ?? Colors.black54),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(widget.complaintData['timestamp']),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotRedirectCard() {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: _navigateToChatbot,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: theme.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Need Insights?',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Get AI-powered solutions and analysis for this complaint by chatting with our assistant.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _navigateToChatbot,
                  icon: const Icon(Icons.chat),
                  label: const Text('Open Chatbot'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesCard() {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('complaints')
              .doc(widget.complaintId)
              .snapshots(),
      builder: (context, snapshot) {
        // Error handling
        if (snapshot.hasError) {
          return Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading updates: ${snapshot.error}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          );
        }

        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // Data handling
        final docData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final updates = docData['Updates'] as List<dynamic>? ?? [];
        final updateCount = docData['update_count'] as int? ?? 0;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Updates ($updateCount)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(children: [_buildAddUpdateButton()]),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                if (updates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No updates available yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),

                ...updates.map((update) {
                  final data = update as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.update,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatTimestamp(data['timestamp'] ?? ''),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['context'] ?? 'No context provided',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimilarComplaintsSection() {
    final theme = Theme.of(context);
    final matchedComplaints = _analysisResult['matched_complaints'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Similar Complaints',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (matchedComplaints.isEmpty)
              Text(
                'No similar complaints found in the database.',
                style: theme.textTheme.bodyMedium,
              ),
            for (var complaint in matchedComplaints)
              Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint['text'] ?? '',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${complaint['similarity']?.toStringAsFixed(1) ?? 0}% match',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsSection() {
    final theme = Theme.of(context);
    final newsResults = _analysisResult['news_results'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Related News',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            if (newsResults.isEmpty)
              Text(
                'No related news found.',
                style: theme.textTheme.bodyMedium,
              ),
            for (var news in newsResults)
              Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          final url = news['link'];
                          if (url != null) {
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Text(
                          news['title'] ?? 'No Title',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news['snippet'] ?? 'No snippet available.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            final url = news['link'];
                            if (url != null) {
                              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            }
                          },
                          child: const Text('Read More'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ComplaintAnalyzer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String? _serperApiKey;
  
  ComplaintAnalyzer() {
    _serperApiKey = dotenv.env['serper-api'];
    
    if (_serperApiKey == null) {
      throw Exception('Missing API Key: Ensure serper-api key is present.');
    }
  }
  
  ComplaintAnalyzer.withKey(this._serperApiKey) {
    if (_serperApiKey == null) {
      throw Exception('Missing API Key: Serper API key must be provided.');
    }
  }

  double _calculateSimilarity(String text1, String text2) {
    return text1.similarityTo(text2) * 100;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double latDelta = _degreesToRadians(lat2 - lat1);
    final double lonDelta = _degreesToRadians(lon2 - lon1);

    final double a = sin(latDelta / 2) * sin(latDelta / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(lonDelta / 2) * sin(lonDelta / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  Future<List<Map<String, dynamic>>> _searchFirebase(
    String location, 
    String problem, 
    {double threshold = 70.0, 
    double? latitude, 
    double? longitude, 
    double radiusInKm = 5.0}
  ) async {
    
    QuerySnapshot complaintsSnapshot = await _firestore
        .collection("complaints")
        .get();

    List<Map<String, dynamic>> matchedComplaints = [];
    
    for (var doc in complaintsSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String complaintText = data["text"] ?? "";
      
      double textSimilarity = _calculateSimilarity(complaintText, problem);
      bool isInRadius = true;
      double distance = double.infinity;
      
      if (latitude != null && longitude != null && 
          data.containsKey("latitude") && data.containsKey("longitude")) {
        
        double docLat = (data["latitude"] as num).toDouble();
        double docLong = (data["longitude"] as num).toDouble();
        
        distance = _calculateDistance(latitude, longitude, docLat, docLong);
        isInRadius = distance <= radiusInKm;
      }
      
      if (!isInRadius && latitude != null && longitude != null) {
        continue;
      }
      
      if (textSimilarity >= threshold) {
        matchedComplaints.add({
          "text": complaintText,
          "similarity": textSimilarity,
          "location": data["location"] ?? "Unknown",
          "distance_km": distance != double.infinity ? distance : null,
          "id": doc.id
        });
      }
    }

    matchedComplaints.sort((a, b) {
      final aValue = a["similarity"] as double;
      final bValue = b["similarity"] as double;
      return bValue.compareTo(aValue);
    });
    
    return matchedComplaints;
  }

  Future<List<Map<String, dynamic>>> _searchOnline(String location, String problem) async {
    final response = await http.post(
      Uri.parse("https://google.serper.dev/search"),
      headers: {"X-API-KEY": _serperApiKey!, "Content-Type": "application/json"},
      body: jsonEncode({"q": "$problem in $location", "num": 5}),
    );

    if (response.statusCode == 200) {
      List<dynamic> results = jsonDecode(response.body)["organic"] ?? [];
      return results
          .map((r) => {
                "title": r["title"] ?? "No Title",
                "link": r["link"] ?? "#",
                "snippet": r["snippet"] ?? "No snippet available."
              })
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> analyzeComplaint(
    String location, 
    String problem, 
    {double? latitude, 
    double? longitude}
  ) async {
    location = location.trim();
    problem = problem.trim();

    if (location.isEmpty || problem.isEmpty) {
      return {"error": "Both 'location' and 'problem' fields are required!"};
    }

    List<Map<String, dynamic>> complaints = await _searchFirebase(
      location, 
      problem, 
      latitude: latitude, 
      longitude: longitude,
      radiusInKm: 5.0
    );
    
    List<Map<String, dynamic>> newsResults = await _searchOnline(location, problem);

    return {
      "location": location,
      "problem": problem,
      "matched_complaints": complaints,
      "news_results": newsResults,
      "coordinates": latitude != null && longitude != null ? 
                    {"latitude": latitude, "longitude": longitude} : null
    };
  }
}