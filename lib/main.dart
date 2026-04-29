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

// [MIGRAÇÃO] Firebase removido. O app agora usa Azure Blob Storage para
// armazenamento de gravações, configurado via tela de Settings.
// Anteriormente: firebase_core e firebase_options eram importados e
// Firebase.initializeApp() era chamado antes do runApp().

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/project_euphonia.dart';
import 'src/repos/audio_player.dart';
import 'src/repos/audio_recorder.dart';
import 'src/repos/phrases_repository.dart';
import 'src/repos/settings_repository.dart';
import 'src/repos/uploader.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // [MIGRAÇÃO] Removido: await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // A configuração do Azure Blob Storage é feita em SettingsRepository.initFromPreferences()
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => PhrasesRepository()),
    ChangeNotifierProxyProvider<PhrasesRepository, AudioRecorder>(
        create: (context) => AudioRecorder(),
        update: (context, phraseRepoChangeNotifier, audioRecorder) =>
            audioRecorder!
              ..updateAudioPathForPhrase(
                  phraseRepoChangeNotifier.currentPhrase)),
    ChangeNotifierProxyProvider<PhrasesRepository, AudioPlayer>(
        create: (context) => AudioPlayer(),
        update: (context, phraseRepoChangeNotifier, audioPlayer) =>
            audioPlayer!..loadPhrase(phraseRepoChangeNotifier.currentPhrase)),
    ChangeNotifierProvider(create: (context) => Uploader()),
    ChangeNotifierProvider(create: (context) => SettingsRepository()),
  ], child: const ProjectEuphonia()));
}
