import 'package:flutter/material.dart';
import 'services/api_client.dart';
import 'services/marketplace_api_service.dart';

void main() {
  runApp(TestApp());
}

class TestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B2B Data Test',
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final ApiClient _apiClient = ApiClient();
  late final MarketplaceApiService _marketplaceService;
  List<dynamic> _parts = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _marketplaceService = MarketplaceApiService(_apiClient);
    _loadParts();
  }

  Future<void> _loadParts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Тест прямого API вызова
      final response = await _apiClient.get('/b2c/parts?limit=5');
      print('API Response: ${response.data}');
      
      // Тест через сервис
      final products = await _marketplaceService.getProducts(limit: 5);
      print('Products from service: ${products.length}');
      
      setState(() {
        _parts = response.data['data'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('B2B Data Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'B2B Parts Integration Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadParts,
              child: Text('Reload Parts'),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_error.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red[700]),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _parts.length,
                  itemBuilder: (context, index) {
                    final part = _parts[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(part['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category: ${part['category'] ?? 'N/A'}'),
                            Text('Brand: ${part['brand'] ?? 'N/A'}'),
                            Text('Price: ${part['price'] ?? 'N/A'} ₸'),
                            Text('Stock: ${part['stock'] ?? 'N/A'}'),
                            Text('Seller: ${part['sellerName'] ?? 'N/A'}'),
                          ],
                        ),
                        trailing: Text('ID: ${part['id']}'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
