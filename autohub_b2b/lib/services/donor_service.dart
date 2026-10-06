import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/donor_model.dart';
import 'api/api_client.dart';

class DonorService {
  final ApiClient _apiClient = ApiClient();

  Future<List<DonorModel>> getDonors() async {
    final response = await _apiClient.dio.get('/api/donors');
    return (response.data as List<dynamic>)
        .map((json) => DonorModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<DonorModel> getDonor(int id) async {
    final response = await _apiClient.dio.get('/api/donors/$id');
    return DonorModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DonorHistoryEntry>> getHistory(int id) async {
    final response = await _apiClient.dio.get('/api/donors/$id/history');
    return (response.data as List<dynamic>)
        .map((json) => DonorHistoryEntry.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<DonorModel> createDonor(Map<String, dynamic> data) async {
    final response = await _apiClient.dio.post('/api/donors', data: data);
    return DonorModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DonorModel> updateDonor(int id, Map<String, dynamic> data) async {
    final response = await _apiClient.dio.put('/api/donors/$id', data: data);
    return DonorModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDonor(int id) async {
    await _apiClient.dio.delete('/api/donors/$id');
  }

  Future<void> addParts(int id, List<Map<String, dynamic>> parts) async {
    await _apiClient.dio.post('/api/donors/$id/parts', data: {'parts': parts});
  }

  Future<DonorModel> uploadPhotos(int id, List<XFile> files) async {
    final formData = FormData();
    for (final file in files) {
      formData.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ),
      );
    }
    final response = await _apiClient.dio.post(
      '/api/donors/$id/photos',
      data: formData,
    );
    return DonorModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<DonorModel> removePhoto(int id, String imageUrl) async {
    final response = await _apiClient.dio.delete(
      '/api/donors/$id/photos',
      data: {'imageUrl': imageUrl},
    );
    return DonorModel.fromJson(response.data as Map<String, dynamic>);
  }

  String photoUrl(String path) => path.startsWith('http')
      ? path
      : '${_apiClient.baseUrl.replaceAll('/api', '')}$path';
}
