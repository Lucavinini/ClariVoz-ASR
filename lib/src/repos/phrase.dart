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

// [MIGRAÇÃO] Firebase Storage substituído por Azure Blob Storage.
// Upload e download agora usam HTTP REST API com SAS Token.
// Anteriormente: usava FirebaseStorage.instance.ref() para upload/download.

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final class Phrase {
  final int index;
  final String text;

  Phrase({required this.index, required this.text});

  /// Base URL for Azure Blob Storage.
  /// Format: https://<account>.blob.core.windows.net/<container>
  /// The SAS token is appended separately.
  static String _storageBaseUrl = '';
  static String _sasToken = '';

  /// Configura o Azure Blob Storage com a URL base do container e o SAS Token.
  /// Chamado automaticamente pelo SettingsRepository ao carregar preferências.
  static void configureStorage(
      {required String storageBaseUrl, required String sasToken}) {
    _storageBaseUrl = storageBaseUrl.trimRight();
    _sasToken = sasToken.trimLeft();
    // Ensure sasToken starts with '?'
    if (_sasToken.isNotEmpty && !_sasToken.startsWith('?')) {
      _sasToken = '?$_sasToken';
    }
  }

  static bool get isStorageConfigured =>
      _storageBaseUrl.isNotEmpty && _sasToken.isNotEmpty;

  Future<bool> get isRecordingAvailableLocally =>
      localRecordingPath.then((x) => File(x).existsSync());

  Future<String> get localRecordingPath =>
      getApplicationDocumentsDirectory().then(
        (value) => '${value.path}/prompt$index.wav',
      );

  Future<String> get localTempPath => getApplicationDocumentsDirectory().then(
        (value) => '${value.path}/prompt_temp_$index.wav',
      );

  /// Monta a URL completa do blob: baseUrl/blobPath?sasToken
  String _blobUrl(String blobPath) => '$_storageBaseUrl/$blobPath$_sasToken';

  /// Baixa a gravação do Azure Blob Storage via HTTP GET.
  /// Anteriormente: usava FirebaseStorage.instance.ref().child().getData()
  Future<void> downloadRecording() async {
    final url = _blobUrl('data/$index/recording.wav');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw FileSystemException(
          'Remote file not found or empty (HTTP ${response.statusCode})',
          'data/$index/recording.wav');
    }
    final localAudioFile = File(await localRecordingPath);
    localAudioFile.writeAsBytesSync(response.bodyBytes);
  }

  /// Faz upload da gravação e texto da frase para o Azure Blob Storage via HTTP PUT.
  /// Usa o header 'x-ms-blob-type: BlockBlob' exigido pela API REST do Azure.
  /// Anteriormente: usava FirebaseStorage.instance.ref().putFile() e putString()
  Future<void> uploadRecording() async {
    final audioPath = await localRecordingPath;
    final localAudioFile = File(audioPath);
    if (!localAudioFile.existsSync()) {
      throw FileSystemException('File doesn\'t exist', audioPath);
    }

    // Upload phrase text
    final phraseUrl = _blobUrl('data/$index/phrase.txt');
    final phraseResponse = await http.put(
      Uri.parse(phraseUrl),
      headers: {
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': 'text/plain; charset=utf-8',
      },
      body: text,
    );
    if (phraseResponse.statusCode != 201) {
      throw HttpException(
          'Failed to upload phrase (HTTP ${phraseResponse.statusCode})');
    }

    // Upload audio file
    final audioUrl = _blobUrl('data/$index/recording.wav');
    final audioBytes = localAudioFile.readAsBytesSync();
    final audioResponse = await http.put(
      Uri.parse(audioUrl),
      headers: {
        'x-ms-blob-type': 'BlockBlob',
        'Content-Type': 'audio/wav',
      },
      body: audioBytes,
    );
    if (audioResponse.statusCode != 201) {
      throw HttpException(
          'Failed to upload recording (HTTP ${audioResponse.statusCode})');
    }
  }
}
