import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI-IoT SAR Monitor',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State {
  LatLng? selectedLocation;
  String _soilMoistureResult = "Tap a location on the map and click query.";
  bool _isLoading = false;
  String? _lBandImgBase64;
  String? _sBandImgBase64;
  String _selectedCrop = "Banana";
  List _soilHistory = [];

  final List _crops = ["Banana", "Maize"];
  static const LatLng erodeCenter = LatLng(11.3410, 77.7172);

  void _onMapTapped(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      selectedLocation = latLng;
    });
  }

  Future _fetchSarData() async {
    final lat = selectedLocation?.latitude ?? erodeCenter.latitude;
    final lon = selectedLocation?.longitude ?? erodeCenter.longitude;

    setState(() {
      _isLoading = true;
    });

    try {
      final url = Uri.parse('http://127.0.0.1:5000/get_soil_moisture?lat=(lat&lon=)lon&crop=$_selectedCrop');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _lBandImgBase64 = data['l_band_image'];
          _sBandImgBase64 = data['s_band_image'];
          _soilHistory = data['history'] ?? [];
          _soilMoistureResult = 
              "Region: ${data['region']}\n"
              "Coordinates: ({data['latitude'].toStringAsFixed(3)},){data['longitude'].toStringAsFixed(3)}\n"
              "Soil Moisture: ${data['soil_moisture_percentage']}%";
        });
      } else {
        setState(() {
          _soilMoistureResult = "Error connecting to Flask backend.";
        });
      }
    } catch (e) {
      setState(() {
        _soilMoistureResult = "Server connection failed: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {},
        ),
        title: const Text(
          "NISAR Data Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Mobile Map Box
            Container(
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: erodeCenter,
                        initialZoom: 11.0,
                        onTap: _onMapTapped,
                      ),
                      children: [
                        TileLayer(
  urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  userAgentPackageName: 'com.example.sar_erode_app',
),
                        if (selectedLocation != null)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: selectedLocation!,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 35),
                              ),
                            ],
                          ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedLocation != null
                              ? "Lat: ({selectedLocation!.latitude.toStringAsFixed(1)}°N, Lon:){selectedLocation!.longitude.toStringAsFixed(1)}°E"
                              : "Lat: 11.3°N, Lon: 77.7°E",
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Crop Selector Dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Target Crop: ", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton(
                  value: _selectedCrop,
                  items: _crops.map((crop) => DropdownMenuItem(value: crop, child: Text(crop))).toList(),
onChanged: (val) => setState(() => _selectedCrop = val as String),                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Get SAR Data Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B6CB0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: _fetchSarData,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Get SAR Data", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Side-by-Side S-Band and L-Band Image Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cell_tower, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text("S Band Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: _sBandImgBase64 != null
                              ? Image.memory(base64Decode(_sBandImgBase64!), fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade200),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cell_tower, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text("L Band Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: _lBandImgBase64 != null
                              ? Image.memory(base64Decode(_lBandImgBase64!), fit: BoxFit.cover)
                              : Container(color: Colors.grey.shade200),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 5. Current Moisture Metrics & Predict Button
            Text(
              _soilMoistureResult,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 180,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF729ED5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: _fetchSarData,
                child: const Text("Predict the Level", style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),

            // 6. Processed Data Summary Table Header & Content
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Processed Data Summary",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                  columnSpacing: 25,
                  columns: const [
                    DataColumn(label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text("Satellite", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text("Moisture (%)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _soilHistory.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item['date'], style: const TextStyle(fontSize: 11))),
                      DataCell(Text(item['satellite'], style: const TextStyle(fontSize: 11))),
                      DataCell(Text("${item['soil_moisture']}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3B6CB0),
        unselectedItemColor: Colors.grey,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
        ],
      ),
    );
  }
}