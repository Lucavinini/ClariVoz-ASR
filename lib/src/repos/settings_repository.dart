// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// [MIGRAÇÃO] Adicionado suporte a configuração do Azure Blob Storage.
// Novos campos: storageBaseUrl e sasToken, persistidos em SharedPreferences.
// Ao carregar/salvar, aplica a configuração em Phrase.configureStorage().

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phrase.dart';

final class SettingsRepository extends ChangeNotifier {
  static const _transcribeEndpointKey = 'TRANSCRIBE_URL_KEY';
  static const _autoAdvanceKey = 'AUTO_ADVANCE_KEY';
  // [MIGRAÇÃO] Chaves para Azure Blob Storage
  static const _storageBaseUrlKey = 'AZURE_STORAGE_BASE_URL_KEY';
  static const _sasTokenKey = 'AZURE_SAS_TOKEN_KEY';

  String _transcribeEndpoint = '';
  bool _autoAdvance = false;
  String _storageBaseUrl = '';
  String _sasToken = '';

  String get transcribeEndpoint => _transcribeEndpoint;
  bool get autoAdvance => _autoAdvance;
  String get storageBaseUrl => _storageBaseUrl;
  String get sasToken => _sasToken;

  Future<void> initFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _transcribeEndpoint = prefs.getString(_transcribeEndpointKey) ?? '';
    _autoAdvance = prefs.getBool(_autoAdvanceKey) ?? false;
    _storageBaseUrl = prefs.getString(_storageBaseUrlKey) ?? '';
    _sasToken = prefs.getString(_sasTokenKey) ?? '';
    _applyStorageConfig();
    notifyListeners();
  }

  void _applyStorageConfig() {
    if (_storageBaseUrl.isNotEmpty && _sasToken.isNotEmpty) {
      Phrase.configureStorage(
          storageBaseUrl: _storageBaseUrl, sasToken: _sasToken);
    }
  }

  Future<void> updateTranscribeEndpoint(String updatedEndpoint) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_transcribeEndpointKey, updatedEndpoint.trim());
    _transcribeEndpoint = updatedEndpoint.trim();
    notifyListeners();
  }

  Future<void> updateAutoAdvance(bool updatedAutoAdvancePref) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_autoAdvanceKey, updatedAutoAdvancePref);
    _autoAdvance = updatedAutoAdvancePref;
    notifyListeners();
  }

  Future<void> updateStorageBaseUrl(String updatedUrl) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_storageBaseUrlKey, updatedUrl.trim());
    _storageBaseUrl = updatedUrl.trim();
    _applyStorageConfig();
    notifyListeners();
  }

  Future<void> updateSasToken(String updatedToken) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_sasTokenKey, updatedToken.trim());
    _sasToken = updatedToken.trim();
    _applyStorageConfig();
    notifyListeners();
  }
}
