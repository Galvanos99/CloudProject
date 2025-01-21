import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_charts/charts.dart'; // Import syncfusion_flutter_charts
import 'package:intl/intl.dart'; // Import intl package
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore
import 'login_screen.dart';

class HomeScreenWebAnalitic extends StatefulWidget {
  @override
  _HomeScreenWebAnaliticState createState() => _HomeScreenWebAnaliticState();
}

class _HomeScreenWebAnaliticState extends State<HomeScreenWebAnalitic> {
  int totalFiles = 0;
  int originalFiles = 0;
  int thumbnailFiles = 0;

  double totalStorageUsed = 0.0; // In MB
  double originalFilesSize = 0.0; // In MB
  double thumbnailFilesSize = 0.0; // In MB

  double avgOriginalFileSize = 0.0; // In KB
  double avgThumbnailFileSize = 0.0; // In KB

  final double maxStorageLimit = 1.0 * 1024.0; // Max Storage in MB (100GB)
  bool isDataLoaded = false; // Flag to track if data is loaded
  int createThumbnailsCounter = 0; // Licznik dla create_thumbnails

  
  int smallestFileSize = 0; // W bajtach
  int largestFileSize = 0; // W bajtach
  int filesBelow100KB = 0;
  int filesBelow1MB = 0;
  int filesAbove1MB = 0;

 @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
    _fetchFunctionRuns(); // Pobieranie licznika create_thumbnails
  }


  Future<void> _fetchAnalyticsData() async {
    try {
      final storage = FirebaseStorage.instance;


      // Pobieramy pliki oryginalne
      final originalFilesBucket = await storage.ref().child('/').listAll();
      int originalFileCount = 0;
      double totalOriginalSize = 0.0;

      for (var item in originalFilesBucket.items) {
        final metadata = await item.getMetadata();
        originalFileCount++;
        totalOriginalSize += metadata.size?.toDouble() ?? 0.0;
      }

      // Pobieramy pliki w katalogu thumbnails
      final thumbnailFilesBucket = await storage.ref('thumbnails').listAll();
      int thumbnailFileCount = 0;
      double totalThumbnailSize = 0.0;

      for (var item in thumbnailFilesBucket.items) {
        final metadata = await item.getMetadata();
        thumbnailFileCount++;
        totalThumbnailSize += metadata.size?.toDouble() ?? 0.0;
      }

      for (var item in originalFilesBucket.items + thumbnailFilesBucket.items) {
        final metadata = await item.getMetadata();
        final fileSize = metadata.size ?? 0;

        // Aktualizacja rozmiarów najmniejszego i największego pliku
        if (smallestFileSize == 0 || fileSize < smallestFileSize) {
          smallestFileSize = fileSize;
        }
        if (fileSize > largestFileSize) {
          largestFileSize = fileSize;
        }

        // Liczenie plików w przedziałach rozmiarów
        if (fileSize <= 100 * 1024) {
          filesBelow100KB++;
        } else if (fileSize <= 1024 * 1024) {
          filesBelow1MB++;
        } else {
          filesAbove1MB++;
        }
      }

      setState(() {
        totalStorageUsed = (totalOriginalSize + totalThumbnailSize) / (1024.0 * 1024.0); // MB

        originalFilesSize = totalOriginalSize / (1024.0 * 1024.0); // MB
        thumbnailFilesSize = totalThumbnailSize / (1024.0 * 1024.0); // MB

        avgOriginalFileSize = originalFileCount > 0
            ? (totalOriginalSize / originalFileCount) / 1024.0 // KB
            : 0.0;
        avgThumbnailFileSize = thumbnailFileCount > 0
            ? (totalThumbnailSize / thumbnailFileCount) / 1024.0 // KB
            : 0.0;

        originalFiles = originalFileCount;
        thumbnailFiles = thumbnailFileCount;
        totalFiles = originalFileCount + thumbnailFileCount;
        isDataLoaded = true;
      });
    } catch (e) {
      print('Error fetching analytics data: $e');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _fetchFunctionRuns() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('analytics')
        .doc('create_thumbnails')
        .get();
    if (doc.exists) {
      setState(() {
        createThumbnailsCounter = doc['counter'] ?? 0;
      });
    }
  } catch (e) {
    print('Error fetching function runs data: $e');
  }
}

@override
Widget build(BuildContext context) {
  final numberFormat1 = NumberFormat('##0.000000');
  final numberFormat2 = NumberFormat('##0.00');

  double storageUsedPercentage = (totalStorageUsed / maxStorageLimit) * 100;

  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.black,
      title: Row(
        children: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
          SizedBox(width: 10),
          Text('Analytic Dashboard', style: TextStyle(color: Colors.white)),
        ],
      ),
    ),
    body: Container(
      color: Color(0xFF121212), // Bardzo ciemne szare tło
      height: double.infinity,
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            
            if (isDataLoaded)
            // Pierwszy rząd - Firebase Storage Analytics, Files Distribution, Functions Runs
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Firebase Storage Analytics
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 30),
                        Text(
                          'Firebase Storage Analytics',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text('Total Files: $totalFiles', style: TextStyle(color: Colors.white)),
                        Text('Original Files: $originalFiles', style: TextStyle(color: Colors.white)),
                        Text('Thumbnail Files: $thumbnailFiles', style: TextStyle(color: Colors.white)),
                        SizedBox(height: 20),
                        Text('Total Storage Used: ${totalStorageUsed.toStringAsFixed(2)} MB', style: TextStyle(color: Colors.white)),
                        Text('Original Files Size: ${originalFilesSize.toStringAsFixed(2)} MB', style: TextStyle(color: Colors.white)),
                        Text('Thumbnail Files Size: ${thumbnailFilesSize.toStringAsFixed(2)} MB', style: TextStyle(color: Colors.white)),
                        SizedBox(height: 20),
                        Text('Average Original File Size: ${avgOriginalFileSize.toStringAsFixed(2)} KB', style: TextStyle(color: Colors.white)),
                        Text('Average Thumbnail File Size: ${avgThumbnailFileSize.toStringAsFixed(2)} KB', style: TextStyle(color: Colors.white)),
                        SizedBox(height: 20),
                        if (storageUsedPercentage >= 80)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_outlined, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Warning: Storage is more than 80% used!',
                                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  SizedBox(width: 20),

                  // Files Distribution i Functions Runs
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Files Distribution
                        Text(
                          'Files Distribution:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Smallest File Size: ${(smallestFileSize / 1024).toStringAsFixed(2)} KB',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Largest File Size: ${(largestFileSize / 1024).toStringAsFixed(2)} KB',
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text('Files 0-100 KB: $filesBelow100KB', style: TextStyle(color: Colors.white)),
                        Text('Files 100 KB - 1 MB: $filesBelow1MB', style: TextStyle(color: Colors.white)),
                        Text('Files > 1 MB: $filesAbove1MB', style: TextStyle(color: Colors.white)),
                        SizedBox(height: 20),

                        // Functions Runs
                        Text(
                          'Functions runs:',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'create_thumbnails: $createThumbnailsCounter',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Drugi rząd - Wykresy
            if (isDataLoaded)
              Center(
                child: Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        primaryYAxis: NumericAxis(
                          minimum: 0,
                          maximum: 100,
                          interval: 10,
                          title: AxisTitle(text: 'Percentage (%)', textStyle: TextStyle(color: Colors.white)),
                        ),
                        title: ChartTitle(
                          text: 'Total Storage Usage Percentage',
                          textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        legend: Legend(isVisible: false),
                        series: <ChartSeries>[
                          ColumnSeries<StorageData, String>(
                            dataSource: [
                              StorageData('Storage Used', storageUsedPercentage),
                            ],
                            xValueMapper: (StorageData data, _) => data.category,
                            yValueMapper: (StorageData data, _) => data.value,
                            dataLabelSettings: DataLabelSettings(isVisible: true, textStyle: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      child: SfCartesianChart(
                        primaryXAxis: CategoryAxis(),
                        title: ChartTitle(
                          text: 'Storage Usage Breakdown',
                          textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        legend: Legend(isVisible: false),
                        series: <ChartSeries>[
                          ColumnSeries<StorageData, String>(
                            dataSource: [
                              StorageData('Original Files', (originalFilesSize / totalStorageUsed) * 100),
                              StorageData('Thumbnails', (thumbnailFilesSize / totalStorageUsed) * 100),
                            ],
                            xValueMapper: (StorageData data, _) => data.category,
                            yValueMapper: (StorageData data, _) => data.value,
                            dataLabelSettings: DataLabelSettings(isVisible: true, textStyle: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              // Wskaźnik ładowania danych z ciemnym tłem
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                color: Color(0xFF121212), // Ciemne tło
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    ),
  );
}


}

class StorageData {
  StorageData(this.category, this.value);
  final String category;
  final double value;
}