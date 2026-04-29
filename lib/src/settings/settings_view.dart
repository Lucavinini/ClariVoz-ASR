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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/app_localizations.dart';
import '../repos/settings_repository.dart';

class SettingsView extends StatelessWidget {
  final TextEditingController transcriptionURLController;
  // [MIGRAÇÃO] Controllers para configuração do Azure Blob Storage
  final TextEditingController storageUrlController;
  final TextEditingController sasTokenController;
  final String defaultTranscriptURL;
  final SettingsRepository settings;

  const SettingsView(
      {super.key,
      required this.transcriptionURLController,
      required this.storageUrlController,
      required this.sasTokenController,
      required this.defaultTranscriptURL,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final children = [
      const SizedBox(height: 36),
      ListTile(
          title: Text(AppLocalizations.of(context)!.trainModeTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.blue))),
      ListTile(
        title: Text(AppLocalizations.of(context)!.autoAdvanceSettingTitle,
            style: Theme.of(context).textTheme.headlineSmall),
        subtitle:
            Text(AppLocalizations.of(context)!.autoAdvanceSettingSubtitle),
        trailing: Switch(
            value: settings.autoAdvance,
            onChanged: (newValue) {
              settings.updateAutoAdvance(newValue);
            }),
      ),
      const SizedBox(height: 36),
      ListTile(
          title: Text(AppLocalizations.of(context)!.transcribeModeTitle,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.blue))),
      ListTile(
          title: TextField(
        controller: transcriptionURLController,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: AppLocalizations.of(context)!.cloudRunTextFieldLabel,
          hintText: 'https://project-euphoina.us-west2.run.app',
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        onChanged: (newValue) {
          Provider.of<SettingsRepository>(context, listen: false)
              .updateTranscribeEndpoint(newValue);
        },
      )),
      // [MIGRAÇÃO] Seção de configuração do Azure Blob Storage
      // O usuário informa a URL do container e o SAS Token gerado no Azure Portal
      const SizedBox(height: 36),
      ListTile(
          title: Text('Azure Blob Storage',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.blue))),
      ListTile(
          title: TextField(
        controller: storageUrlController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Storage Base URL',
          hintText:
              'https://<account>.blob.core.windows.net/<container>',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        onChanged: (newValue) {
          Provider.of<SettingsRepository>(context, listen: false)
              .updateStorageBaseUrl(newValue);
        },
      )),
      const SizedBox(height: 8),
      ListTile(
          title: TextField(
        controller: sasTokenController,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'SAS Token',
          hintText: '?sv=2022-11-02&ss=b&srt=co&sp=rwlac...',
          hintStyle: TextStyle(color: Colors.grey),
        ),
        obscureText: true,
        onChanged: (newValue) {
          Provider.of<SettingsRepository>(context, listen: false)
              .updateSasToken(newValue);
        },
      )),
      const SizedBox(height: 64)
    ];

    return Scaffold(
        body: CustomScrollView(slivers: [
      SliverAppBar(
        pinned: true,
        flexibleSpace: AppBar(
            centerTitle: false,
            title: Text(AppLocalizations.of(context)!.settingsMenuDrawerTitle)),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return children[index];
        }, childCount: children.length),
      )
    ]));
  }
}
