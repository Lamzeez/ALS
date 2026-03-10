import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ViewModel for ALS Center management.
class CenterManagementViewModel extends ChangeNotifier {
  List<AlsCenterModel> _centers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AlsCenterModel> get centers => _centers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalCenters => _centers.length;
  int get activeCenters => _centers.where((c) => c.isActive).length;

  Future<void> loadCenters() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await Supabase.instance.client.from('als_centers').select();
      final items = List<Map<String, dynamic>>.from(res as List);
      _centers = items.map((m) => AlsCenterModel.fromMap(m)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load centers: ${e.toString()}';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createCenter(AlsCenterModel center) async {
    try {
      await Supabase.instance.client.from('als_centers').upsert(center.toMap());
      _centers.add(center);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCenter(AlsCenterModel center) async {
    try {
      await Supabase.instance.client.from('als_centers').upsert(center.toMap());
      final index = _centers.indexWhere((c) => c.id == center.id);
      if (index >= 0) {
        _centers[index] = center;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCenter(String id) async {
    try {
      await Supabase.instance.client.from('als_centers').delete().eq('id', id);
      _centers.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
