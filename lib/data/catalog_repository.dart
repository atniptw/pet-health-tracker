import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'symptom_catalog.dart';

class CatalogRepository {
  CatalogRepository(this._firestore, this._assets);

  final FirebaseFirestore _firestore;
  final AssetBundle _assets;

  /// The copy shipped with the app, used until a published one is read.
  Future<SymptomCatalog> loadBundled() async {
    final json = await _assets.loadString('assets/catalog/symptoms.json');
    return SymptomCatalog.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// The published catalog, or null while none has been published.
  Stream<SymptomCatalog?> watchPublished() {
    return _firestore
        .doc('catalog/symptoms')
        .snapshots()
        .map((snapshot) => snapshot.exists ? SymptomCatalog.fromMap(snapshot.data()!) : null);
  }
}
