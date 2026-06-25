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
    return result ?? <String>[]; // ✅ ensures non-null List<String>
  }
}

class ThumbnailCacheService {
  static Future<String> getCacheDir() async {
    final dir = await getTemporaryDirectory();
    return dir.path;
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
        onAdLoaded: (ad) {
          setState(() => adLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
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
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final file = files[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PreviewScreen(filePath: file),
              ),
            );
          },
          child: Image.file(File(file), fit: BoxFit.cover),
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
