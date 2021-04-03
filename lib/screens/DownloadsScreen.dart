import 'package:flutter/material.dart';

import '../components/DownloadsScreen/DownloadsOverview.dart';
import '../components/DownloadsScreen/DownloadedAlbumsList.dart';
import '../components/DownloadsScreen/DownloadErrorScreenButton.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Downloads"),
        actions: [DownloadErrorScreenButton()],
      ),
      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              DownloadsOverview(),
              Divider(),
            ]),
          ),
          DownloadedAlbumsList(),
          // CurrentDownloadsList(),
        ],
      ),
    );
  }
}
