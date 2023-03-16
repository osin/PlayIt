import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import 'seekbar.dart';

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
  bool _isUiVisible = false;
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
    ServicesBinding.instance.keyboard.addHandler(_onKey);
    Future.microtask(() async {
      // Create a [VideoController] instance from `package:media_kit_video`.
      // Pass the [handle] of the [Player] from `package:media_kit` to the [VideoController] constructor.
      controller = await VideoController.create(player.handle);
      setState(() {});
    });
  }

  bool _onKey(KeyEvent event) {
    final keyLabel = event.logicalKey.keyLabel;
    if (event is KeyDownEvent) {
      switch (keyLabel) {
        case 'Arrow Left':
          player.state.position.inSeconds > 10
              ? player
                  .seek(Duration(seconds: player.state.position.inSeconds - 10))
              : player.seek(const Duration(seconds: 0));
          break;
        case 'Arrow Right':
          if (player.state.position.inSeconds + 10 <
              player.state.duration.inSeconds) {
            player
                .seek(Duration(seconds: player.state.position.inSeconds + 10));
          }
          break;
        case 'D':
          player.state.isPlaying ? removePlayingItem() : null;
          break;
        case 'Delete':
          player.state.isPlaying ? deletePlayingItem() : null;
          break;
        case 'Escape':
          exit(0);
        case 'F':
          updateFullScreen();
          break;
        case 'H':
          setState(() {
            _isUiVisible = !_isUiVisible;
          });
          break;
        case 'N':
          player.next();
          setState(() {});
          break;
        case 'O':
          openAction();
          break;
        case 'P':
          player.previous();
          setState(() {});
          break;
        case 'R':
          Random randomIndex = Random();
          int next = randomIndex.nextInt(player.state.playlist.medias.length);
          player.jump(next, open: true);
          setState(() {});
          break;
        default:
          int keyId = event.logicalKey.keyId;
          switch (keyId) {
            case 32: //Space pressed
              player.playOrPause();
              break;
            default:
              print('keyId: $keyId');
              print('keyLabel: $keyLabel');
          }
      }
    }
    return false;
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    ServicesBinding.instance.keyboard.removeHandler(_onKey);
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
          children: controlsWidgets,
        ),
        const Divider(height: 1.0, thickness: 1.0),
        for (int i = 0; i < player.state.playlist.medias.length; i++)
          ListTile(
            title: Text(
              player.state.playlist.medias[i].uri,
              style: TextStyle(
                  fontSize: 14.0,
                  color:
                      player.state.playlist.index == i
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
          Visibility(visible: _isUiVisible, child: SeekBar(player: player)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final horizontal =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        floatingActionButton: Visibility(
          visible: !_isUiVisible && player.state.playlist.medias.isEmpty,
          child: FloatingActionButton.extended(
            tooltip: 'Open [File]',
            onPressed: () async {
              await openAction();
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Open'),
          ),
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
                      visible: _isUiVisible,
                      child: const VerticalDivider(width: 1.0, thickness: 1.0),
                    ),
                    Visibility(
                      visible: _isUiVisible,
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

  List<Widget> get controlsWidgets => [
        IconButton(
            onPressed: () async {
              await openAction();
            },
            icon: const Icon(
              Icons.folder_open,
              size: 18,
              color: Colors.pink,
            )),
        IconButton(
            onPressed: () async {
              updateFullScreen();
            },
            icon: const Icon(
              Icons.fullscreen,
              size: 18,
              color: Colors.pink,
            )),
        IconButton(
            onPressed: () {
              setState(() {
                _isUiVisible = !_isUiVisible;
              });
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
                    removePlayingItem();
                  }
                : null),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.delete_forever, size: 18),
          onPressed: player.state.isPlaying
              ? () {
                  deletePlayingItem();
                }
              : null,
        ),
      ];

  void removePlayingItem() {
      var currentIndexInPlaylist = player.state.playlist.index;
      player.remove(player.state.playlist.index);
      player.open(player.state.playlist, play: true);
      player.jump(currentIndexInPlaylist, open: true);
      player.play();
      setState(() {});
  }

  @override
  void onWindowEvent(String eventName) {
    print('[WindowManager] onWindowEvent: $eventName');
  }

  void updateFullScreen() {
    windowManager.ensureInitialized().then((value) => {
          windowManager.setFullScreen(!_isFullScreen).then((value) => {
                windowManager.show().then((value) => {
                      setState(() {
                        _isFullScreen = !_isFullScreen;
                      })
                    })
              })
        });
  }

  void deletePlayingItem() {
    var pathName =
        player.state.playlist.medias[player.state.playlist.index].uri;
    final file = File(pathName);
    file.delete().then((result) => {print("file deleted")});
    removePlayingItem();
  }

  Future<void> openAction() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.video,
    );
    if (result?.files.isNotEmpty ?? false) {
        var files = result?.files.where((element) => true).toList()
            as List<PlatformFile>;
      player.open(
        Playlist(files.map((file) => Media(file.path!)).toList()),
      );
    }
    setState(() {});
  }
}
