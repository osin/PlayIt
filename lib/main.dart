import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'Seekbar.dart';

Future<void> main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlayIt',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.pink,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: OpenUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: OpenUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const MyHomePage(title: 'Play It'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  late FilePickerResult result;
  bool isUiVisible = false;
  late List<PlatformFile> files = [];
  bool _isFullScreen = false;

  // Create a [Player] instance from `package:media_kit`.
  final Player player = Player(
    configuration: const PlayerConfiguration(),
  );

  // Reference to the [VideoController] instance.
  VideoController? controller;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    Future.microtask(() async {
      // Create a [VideoController] instance from `package:media_kit_video`.
      // Pass the [handle] of the [Player] from `package:media_kit` to the [VideoController] constructor.
      controller = await VideoController.create(player.handle);
      setState(() {});
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    Future.microtask(() async {
      debugPrint('Disposing [Player] and [VideoController]...');
      await controller?.dispose();
      await player.dispose();
    });
    super.dispose();
  }

  List<Widget> get playlist => [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: uIControlsWidgets,
        ),
        const Divider(height: 1.0, thickness: 1.0),
        for (int i = 0; i < files.length; i++)
          ListTile(
            title: Text(
              files[i].name,
              style: TextStyle(
                  fontSize: 14.0,
                  color:
                      player.state.isPlaying && player.state.playlist.index == i
                          ? Colors.pinkAccent
                          : Colors.black),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              setState(() {
                player.jump(i, open: true);
              });
            },
          ),
      ];

  Widget get video => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Card(
              elevation: 8.0,
              clipBehavior: Clip.antiAlias,
              child: Video(
                controller: controller,
              ),
            ),
          ),
          SeekBar(player: player),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final horizontal =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: 'Open [File]',
          onPressed: () async {
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.video,
            );
            if (result?.files.isNotEmpty ?? false) {
              setState(() {
                files = result?.files.where((element) => true).toList()
                    as List<PlatformFile>;
              });
              player.open(
                Playlist(files.map((file) => Media(file.path!)).toList()),
              );
            }
          },
          icon: const Icon(Icons.file_open),
          label: const Text('Open'),
        ), // This trailing comma makes auto-formatting nicer for build methods.
        body: SizedBox.expand(
          child: horizontal
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        alignment: Alignment.center,
                        child: video,
                      ),
                    ),
                    Visibility(
                      visible: isUiVisible,
                      child: const VerticalDivider(width: 1.0, thickness: 1.0),
                    ),
                    Visibility(
                      visible: isUiVisible,
                      child: Expanded(
                        flex: 1,
                        child: ListView(
                          children: [...playlist],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  key: const Key("ListView"),
                  children: [
                    Container(
                      alignment: Alignment.center,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.width * 12.0 / 16.0,
                      child: video,
                    ),
                    const Divider(height: 1.0, thickness: 1.0),
                    ...playlist,
                  ],
                ),
        ));
  }

  List<Widget> get uIControlsWidgets => [
        IconButton(
            onPressed: () async {
              await windowManager.ensureInitialized();
              _isFullScreen = !_isFullScreen;
              await windowManager.setFullScreen(_isFullScreen);
              await windowManager.show();
            },
            icon: const Icon(
              Icons.fullscreen,
              size: 18,
              color: Colors.pink,
            )),
        IconButton(
            onPressed: () async {
              //todo: récupérer les éléments à masquer
              print("Hide UI Controls");
            },
            icon: const Icon(
              Icons.tv,
              size: 18,
              color: Colors.pink,
            )),
        const SizedBox(width: 12),
        IconButton(
            icon: const Icon(Icons.delete, size: 18),
            onPressed: player.state.isPlaying
                ? () {
                    removeItemFromPlaylist();
                  }
                : null),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.delete_forever, size: 18),
          onPressed: player.state.isPlaying
              ? () {
                  var pathName = files[player.state.playlist.index].path;
                  if (pathName != null) {
                    final file = File(pathName);
                    file.delete().then((result) => {print("file deleted")});
                    removeItemFromPlaylist();
                  }
                }
              : null,
        ),
      ];

  void removeItemFromPlaylist() {
    setState(() {
      files.removeAt(player.state.playlist.index!);
      player.open(Playlist(files.map((file) => Media(file.path!)).toList()),
          play: false);
      //todo: modifier plus tard pour jouer quand on supprime un élément
    });
  }

  @override
  void onWindowEvent(String eventName) {
    print('[WindowManager] onWindowEvent: $eventName');
  }
}
