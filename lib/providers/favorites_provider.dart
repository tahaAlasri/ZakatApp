import 'package:flutter/material.dart';
import '../core/database/local_db_service.dart';
import '../models/favorite_item.dart';

class FavoritesProvider extends ChangeNotifier {
  List<FavoriteItem> _favorites = [];

  List<FavoriteItem> get favorites => _favorites;

  FavoritesProvider() {
    loadFavorites();
  }

  void loadFavorites() {
    _favorites = LocalDbService.getAllFavorites();
    notifyListeners();
  }

  bool isFavorite(String id) {
    return LocalDbService.isFavorite(id);
  }

  Future<void> toggleFavorite(FavoriteItem item) async {
    if (LocalDbService.isFavorite(item.id)) {
      await LocalDbService.removeFavorite(item.id);
    } else {
      await LocalDbService.saveFavorite(item);
    }
    loadFavorites();
  }

  Future<void> addFavorite(FavoriteItem item) async {
    await LocalDbService.saveFavorite(item);
    loadFavorites();
  }

  Future<void> removeFavorite(String id) async {
    await LocalDbService.removeFavorite(id);
    loadFavorites();
  }
}
