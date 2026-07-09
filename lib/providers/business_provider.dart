import 'package:flutter/material.dart';
import '../data/db_helper.dart';
import '../models/business.dart';

class BusinessProvider extends ChangeNotifier {
  final DbHelper _dbHelper = DbHelper();
  
  Business? _business;
  bool _isLoading = false;
  bool _isInitialized = false;

  Business? get business => _business;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isOnboarded => _business != null;

  Future<void> loadBusiness() async {
    _isLoading = true;
    notifyListeners();
    try {
      _business = await _dbHelper.getBusiness();
      _isInitialized = true;
    } catch (e) {
      debugPrint("Error loading business: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createBusiness(Business newBusiness) async {
    _isLoading = true;
    notifyListeners();
    try {
      final id = await _dbHelper.insertBusiness(newBusiness);
      if (id > 0) {
        _business = newBusiness.copyWith(id: id);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error creating business: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBusiness(Business updatedBusiness) async {
    _isLoading = true;
    notifyListeners();
    try {
      final count = await _dbHelper.updateBusiness(updatedBusiness);
      if (count > 0) {
        _business = updatedBusiness;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error updating business: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearBusiness() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _dbHelper.clearBusiness();
      _business = null;
    } catch (e) {
      debugPrint("Error clearing business: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
