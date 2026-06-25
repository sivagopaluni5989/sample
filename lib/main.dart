import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saf/saf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "WA Status Fast Saver",
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

const String generalFolderKey = "general_saf_folder";
const String businessFolderKey = "business_saf_folder";

class FileHelper {
  static Future<List<String>> getFilesPath(String folderUri) async {
    final saf = Saf(folderUri);
    final result = await saf.getFilesPath();
    return result ?? <String>[];
  }

  static Future<File> copyToCache(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final cacheDir = await getTemporaryDirectory();
    final cacheFile = File('${cacheDir.path}/${DateTime.now().millisecondsSinceEpoch}');
    await cacheFile.writeAsBytes(bytes);
    return cacheFile;
  }

  static Future<void> saveToGallery(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final dir = await getExternalStorageDirectory();
    final savePath = "${dir!.path}/WAStatusSaver";
    await Directory(savePath).create(recursive: true);
    final outFile = File("$savePath/${DateTime.now().millisecondsSinceEpoch}${path.endsWith(".mp4") ? ".mp4" : ".jpg"}");
    await outFile.writeAsBytes(bytes);
  }
}

class SafService {
  final SharedPreferences prefs;
  SafService(this.prefs);

  Future<void> saveFolderUri(String key, String uri) async {
    await prefs.setString(key, uri);
  }

  String? getFolderUri(String key) {
    return prefs.getString(key);
  }
}

class StatusScannerService {
  Future<List<String>> scanStatuses(String folderUri) async {
    return await FileHelper.getFilesPath(folderUri);
  }
}

class StatusController {
  final SafService safService;
  final StatusScannerService scanner;
  StatusController(this.safService, this.scanner);

  Future<List<String>> loadStatuses(String key) async {
    final uri = safService.getFolderUri(key);
    if (uri == null) return [];
    return await scanner.scanStatuses(uri);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  List<String> generalFiles = [];
  List<String> businessFiles = [];
  BannerAd? bannerAd;
  bool adLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStatuses();
    _initBannerAd();
  }

  Future<void> _loadStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final safService = SafService(prefs);
    final scanner = StatusScannerService();
    final controller = StatusController(safService, scanner);

    // SAF 1.0.4: hardcode paths
    const generalPath = "/storage/emulated/0/WhatsApp/Media/.Statuses";
    const businessPath = "/storage/emulated/0/WhatsApp Business/Media/.Statuses";

    await safService.saveFolderUri(generalFolderKey, generalPath);
    await safService.saveFolderUri(businessFolderKey, businessPath);

    generalFiles = await controller.loadStatuses(generalFolderKey);
    businessFiles = await controller.loadStatuses(businessFolderKey);

    setState(() {
      isLoading = false;
    });
  }

  void _initBannerAd() {
    bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => setState(() => adLoaded = true),
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF075E54),
        title: const Text(
          "WA Status Fast Saver",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: "WhatsApp"),
            Tab(icon: Icon(Icons.business), text: "Business"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : TabBarView(
              controller: _tabController,
              children: [
                buildGrid(generalFiles),
                buildGrid(businessFiles),
              ],
            ),
      bottomNavigationBar: adLoaded
          ? SizedBox(
              height: bannerAd!.size.height.toDouble(),
              width: bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: bannerAd!),
            )
          : null,
    );
  }

  Widget buildGrid(List<String> files) {
    if (files.isEmpty) {
      return const Center(child: Text("No Status Found"));
    }
    return GridView.builder(
      itemCount: files.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final path = files[index];
        return FutureBuilder<File>(
          future: FileHelper.copyToCache(path),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final file = snapshot.data!;
            return Card(
              elevation: 4,
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PreviewScreen(filePath: file.path),
                          ),
                        );
                      },
                      child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await FileHelper.saveToGallery(path);
                      if (!mounted) return; // ✅ fix async context warning
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Status saved to gallery")),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text("Save"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class PreviewScreen extends StatefulWidget {
  final String filePath;
  const PreviewScreen({super.key, required this.filePath});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.filePath.endsWith(".mp4")) {
      _controller = VideoPlayerController.file(File(widget.filePath))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {});
          _controller!.play();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Preview")),
      body: widget.filePath.endsWith(".mp4")
          ? _controller != null && _controller!.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              : const Center(child: CircularProgressIndicator())
          : Image.file(File(widget.filePath)),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
