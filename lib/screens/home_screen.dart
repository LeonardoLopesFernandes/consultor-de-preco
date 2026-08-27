import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

import '../database/app_database.dart';
import '../models/product.dart';
import '../services/americanas_bff.dart';
import '../services/americanas_scraper.dart';
import '../services/google_search_api.dart';
import '../services/image_search_api.dart';
import '../services/serp_api_image_search.dart';
import '../services/text_search_api.dart';
import '../utils/constants.dart';
import '../utils/icons.dart';
import '../utils/download_image.dart';
import '../screens/barcode_scanner_screen.dart';
import '../screens/floating_permission_screen.dart';
import '../utils/overlay_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _etBarcode = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading = false;
  String _loadingText = 'Consultando...';
  final List<String> _loadingMessages = [
    'Consultando preço...',
    'Buscando informações...',
    'Quase lá...',
    'Processando...',
  ];

  bool _resultCardVisible = false;
  String _resultText =
      'Aguardando consulta...\n\nDigite o código de barras, descrição, use o microfone, câmera ou pesquise por imagem';

  String _currentImageUrl = '';
  String _currentProductName = '';
  String _currentProductEan = '';
  String _currentPriceText = '';
  String _currentBarcodeText = '';
  String _currentSapText = '';
  bool _sapVisible = false;
  bool _isFavorite = false;

  List<HistoryEntity> _history = [];
  bool _historyVisible = false;

  late stt.SpeechToText _speech;
  bool _speechEnabled = false;
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _loadHistory();
  }

  @override
  void dispose() {
    _etBarcode.dispose();
    _barcodeFocusNode.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ---------- Histórico ----------
  Future<void> _loadHistory() async {
    final list = await AppDatabase.getHistory();
    if (!mounted) return;
    setState(() {
      _history = list;
      _historyVisible = list.isNotEmpty;
    });
  }

  Future<void> _saveToHistory(String name, String price) async {
    await AppDatabase.insertHistory(HistoryEntity(
      barcode: _currentProductEan.isEmpty ? 'Código inválido' : _currentProductEan,
      productName: name.isEmpty ? 'Produto sem nome' : name,
      price: price,
    ));
    _loadHistory();
  }

  Future<void> _clearHistory() async {
    await AppDatabase.clearHistory();
    _loadHistory();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Histórico limpo')),
    );
  }

  // ---------- Consulta principal ----------
  Future<void> _consultarPreco(String barcode) async {
    _showLoading(true);
    _setLoadingMessages();

    try {
      final produto = await AmericanasBff.getProduct(barcode);
      if (!mounted) return;
      if (produto.ean.isNotEmpty) {
        final preco = _getPriceFromProduct(produto);
        if (preco != 'R\$ 0,00') {
          _displayProduct(produto, preco, barcode);
          _saveToHistory(produto.description.isEmpty ? 'Produto EAN: $barcode' : produto.description, preco);
        } else {
          _searchCompleteProductInfo(barcode, produto.description);
        }
      } else {
        _searchCompleteProductInfo(barcode, null);
      }
    } catch (_) {
      if (!mounted) return;
      _searchCompleteProductInfo(barcode, null);
    } finally {
      _showLoading(false);
    }
  }

  String _getPriceFromProduct(ProductResponse product) {
    if (product.price?.promotional != null &&
        product.price!.promotional!.isNotEmpty) {
      final p = product.price!.promotional!;
      if (p != 'R\$ 0,00' && p != 'R\$0,00') return p;
    }
    if (product.price?.regular != null && product.price!.regular!.isNotEmpty) {
      final p = product.price!.regular!;
      if (p != 'R\$ 0,00' && p != 'R\$0,00') return p;
    }
    return 'R\$ 0,00';
  }

  Future<void> _searchCompleteProductInfo(String ean, String? apiDescription) async {
    String? description = apiDescription;
    if (description == null ||
        description.isEmpty ||
        description.contains(ean) ||
        description == 'Produto encontrado' ||
        description == 'Produto sem nome') {
      description = await GoogleSearchApi.searchProductDescription(ean);
      description ??= 'Produto EAN: $ean';
    }

    if (!mounted) return;
    setState(() {
      _currentProductName = description!;
      _currentProductEan = ean;
      _currentBarcodeText = '🔢 Código: $ean';
      _currentSapText = '';
      _sapVisible = false;
      _currentPriceText = 'Preço indisponível';
      _resultCardVisible = true;
      _resultText = '';
    });

    final price = await AmericanasWebScraper.searchPriceByEan(ean);
    if (!mounted) return;
    setState(() {
      _currentPriceText = price ?? 'Preço indisponível';
    });

    _searchImageByEan(ean, description);
    _checkFavoriteStatus();
  }

  void _displayProduct(ProductResponse product, String price, String ean) {
    String nome = product.description.isEmpty ? 'Produto EAN: $ean' : product.description;

    if (nome.contains(ean) || nome == 'Produto Americanas') {
      GoogleSearchApi.searchProductDescription(ean).then((clean) {
        if (clean != null && clean.isNotEmpty && mounted) {
          setState(() {
            _currentProductName = clean;
            _currentBarcodeText = '🔢 Código: ${product.ean}';
          });
        }
      });
    }

    setState(() {
      _currentProductName = nome;
      _currentProductEan = ean;
      _currentBarcodeText = '🔢 Código: ${product.ean}';
      _currentSapText = (product.sapId.isNotEmpty && !product.sapId.contains('null'))
          ? '🆔 SAP: ${product.sapId}'
          : '';
      _sapVisible = _currentSapText.isNotEmpty;
      _currentPriceText = price;
      _resultCardVisible = true;
      _resultText = '';
    });

    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      _currentImageUrl = product.imageUrl!;
      setState(() {});
    } else {
      _searchImageByEan(ean, nome);
    }
    _checkFavoriteStatus();
  }

  Future<void> _searchImageByEan(String ean, String productName) async {
    final imageUrl = await SerpApiImageSearch.searchImageByEan(ean, productName);
    if (!mounted) return;
    if (imageUrl != null) {
      setState(() {
        _currentImageUrl = imageUrl;
      });
    } else {
      setState(() {
        _currentImageUrl = '';
      });
    }
  }

  // ---------- Busca por descrição ----------
  Future<void> _searchByDescription(String query) async {
    _showLoading(true);
    try {
      final results = await TextSearchApi.searchProductByDescription(query);
      if (!mounted) return;
      if (results.isNotEmpty) {
        _showSearchResultsDialog(results);
      } else {
        setState(() {
          _resultText = 'Nenhum produto encontrado para:\n$query';
          _resultCardVisible = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum resultado encontrado')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na busca: $e')),
      );
    } finally {
      _showLoading(false);
    }
  }

  void _showSearchResultsDialog(List<ProductSearchResult> results) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Resultados da busca',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFED0030), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: ListView.separated(
            itemCount: results.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final r = results[i];
              return ListTile(
                leading: SizedBox(
                  width: 60,
                  height: 60,
                  child: r.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: r.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              AppIcons.asset(AppIcons.productPlaceholder, size: 60),
                          errorWidget: (c, u, e) =>
                              AppIcons.asset(AppIcons.productPlaceholder, size: 60),
                        )
                      : AppIcons.asset(AppIcons.productPlaceholder, size: 60),
                ),
                title: Text(r.title,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.price,
                        style: const TextStyle(
                            color: Color(0xFFED0030), fontWeight: FontWeight.bold)),
                    Text(r.source,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
                trailing: IconButton(
                  icon: AppIcons.asset(AppIcons.openLink, size: 24, color: const Color(0xFFED0030)),
                  onPressed: () async {
                    if (r.link.isNotEmpty) {
                      await _openLink(r.link);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link não disponível para este produto')),
                      );
                    }
                  },
                ),
                onTap: () => _showProductFromSearchResult(r),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _showProductFromSearchResult(ProductSearchResult r) {
    setState(() {
      _currentProductName = r.title;
      _currentImageUrl = r.imageUrl;
      _currentProductEan = r.ean;
      _currentBarcodeText = '🔍 Busca: ${_etBarcode.text}';
      _currentSapText = '';
      _sapVisible = false;
      _currentPriceText = r.price;
      _resultCardVisible = true;
      _resultText = '';
    });
    _checkFavoriteStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Produto encontrado: ${r.source}')),
    );
  }

  Future<void> _openLink(String link) async {
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ---------- Favoritos ----------
  Future<void> _toggleFavorite() async {
    final count = await AppDatabase.isFavorite(_currentProductEan);
    if (count > 0) {
      await _removeFromFavorites();
    } else {
      await _addToFavorites();
    }
  }

  Future<void> _addToFavorites() async {
    await AppDatabase.insertFavorite(FavoriteEntity(
      ean: _currentProductEan,
      productName: _currentProductName,
      price: _currentPriceText,
      imageUrl: _currentImageUrl,
    ));
    if (mounted) {
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicionado aos favoritos')),
      );
    }
  }

  Future<void> _removeFromFavorites() async {
    await AppDatabase.deleteFavorite(_currentProductEan);
    if (mounted) {
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removido dos favoritos')),
      );
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_currentProductEan.isEmpty) return;
    final count = await AppDatabase.isFavorite(_currentProductEan);
    if (mounted) setState(() => _isFavorite = count > 0);
  }

  Future<void> _showFavoritesDialog() async {
    final favorites = await AppDatabase.getFavorites();
    if (!mounted) return;
    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum favorito adicionado')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Meus Favoritos',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFED0030), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.separated(
            itemCount: favorites.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (ctx, i) {
              final f = favorites[i];
              return ListTile(
                leading: SizedBox(
                  width: 50,
                  height: 50,
                  child: f.imageUrl != null && f.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: f.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (c, u) =>
                              AppIcons.asset(AppIcons.productPlaceholder, size: 50),
                          errorWidget: (c, u, e) =>
                              AppIcons.asset(AppIcons.productPlaceholder, size: 50),
                        )
                      : AppIcons.asset(AppIcons.productPlaceholder, size: 50),
                ),
                title: Text(f.productName,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔢 Código: ${f.ean}',
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color)),
                    Text(f.price,
                        style: const TextStyle(
                            color: Color(0xFFED0030), fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: IconButton(
                  icon: AppIcons.asset(AppIcons.delete, size: 24, color: const Color(0xFF999999)),
                  onPressed: () async {
                    await AppDatabase.deleteFavorite(f.ean);
                    Navigator.pop(context);
                    _showFavoritesDialog();
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _etBarcode.text = f.ean;
                  _consultarPreco(f.ean);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  // ---------- Tema ----------
  void _showThemeDialog() {
    int selected = 0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Escolha o tema',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: StatefulBuilder(
          builder: (ctx, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<int>(
                title: const Text('Seguir sistema'),
                value: 0,
                groupValue: selected,
                onChanged: (v) => setSt(() => selected = v!),
              ),
              RadioListTile<int>(
                title: const Text('Modo claro'),
                value: 1,
                groupValue: selected,
                onChanged: (v) => setSt(() => selected = v!),
              ),
              RadioListTile<int>(
                title: const Text('Modo escuro'),
                value: 2,
                groupValue: selected,
                onChanged: (v) => setSt(() => selected = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // importa ThemeProvider via Provider
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              // aplica via ThemeProvider
              Provider.of<ThemeProvider>(context, listen: false).saveTheme(selected);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tema alterado!')),
              );
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  // ---------- Voz ----------
  Future<void> _startVoiceRecognition() async {
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize(
        onError: (e) => ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro: ${e.errorMsg}'))),
      );
    }
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconhecimento de voz indisponível')),
      );
      return;
    }
    _speech.listen(
      localeId: 'pt_BR',
      onResult: (result) {
        final spoken = result.recognizedWords;
        final numbers = spoken.replaceAll(RegExp(r'[^0-9]'), '');
        if (numbers.isNotEmpty) {
          _etBarcode.text = numbers;
          _consultarPreco(numbers);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível identificar números. Falado: $spoken')),
          );
        }
      },
    );
  }

  // ---------- Busca por imagem ----------
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pesquisar por imagem',
                style: TextStyle(
                    color: Color(0xFFED0030), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED0030),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _openCamera();
                },
                child: const Text('Tirar foto', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFED0030),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _openGallery();
                },
                child: const Text('Escolher da galeria', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) await _searchByImage(File(picked.path));
  }

  Future<void> _openGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) await _searchByImage(File(picked.path));
  }

  Future<void> _searchByImage(File file) async {
    _showLoading(true);
    try {
      final inputImage = InputImage.fromFile(file);
      final recognized = await _textRecognizer.processImage(inputImage);
      final text = recognized.text.trim();
      if (text.isNotEmpty) {
        final results = await ImageSearchApi.searchByText(text);
        if (!mounted) return;
        if (results.isNotEmpty) {
          _showSearchResultsDialog(results);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${results.length} produtos encontrados!')),
          );
        } else {
          setState(() {
            _resultText = 'Nenhum produto encontrado.\nTire uma foto com texto visível';
            _resultCardVisible = false;
          });
        }
      } else {
        setState(() {
          _resultText = 'Nenhum produto encontrado.\nTire uma foto com texto visível';
          _resultCardVisible = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na busca: $e')),
      );
    } finally {
      _showLoading(false);
    }
  }

  // ---------- Compartilhar ----------
  void _shareApp() {
    Share.share('Baixe o Consultor Preço - Consulte preços rapidamente!');
  }

  void _shareProduct() {
    if (_currentProductName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum produto para compartilhar')),
      );
      return;
    }
    final text = '''
📱 *PRODUTO ENCONTRADO*

📦 *Produto:* $_currentProductName
🔢 *Código:* $_currentProductEan
💰 *Preço:* $_currentPriceText

🔍 *App:* Consultor Preço
📲 Consulte preços rapidamente!''';
    Share.share(text);
  }

  // ---------- Bolinha flutuante ----------
  void _showFloatingDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FloatingPermissionScreen()),
    );
  }

  Future<void> _stopFloating() async {
    await OverlayService.stop();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bolinha flutuante desativada')),
    );
  }

  // ---------- Clipboard ----------
  void _copyToClipboard(String text, String msg) {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---------- Loading ----------
  void _showLoading(bool show) {
    if (!mounted) return;
    setState(() {
      _loading = show;
      if (show) {
        _loadingText = _loadingMessages.first;
      }
    });
  }

  void _setLoadingMessages() {
    int idx = 0;
    Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (!_loading || !mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _loadingText = _loadingMessages[idx % _loadingMessages.length];
        idx++;
      });
    });
  }

  // ---------- Exit ----------
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcons.asset(AppIcons.exit, size: 60, color: const Color(0xFFED0030)),
            const SizedBox(height: 16),
            const Text('Sair do App',
                style: TextStyle(color: Color(0xFFED0030), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Tem certeza que deseja sair?',
                style: TextStyle(color: Color(0xFF666666)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF999999)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFED0030)),
                    onPressed: () => SystemNavigator.pop(),
                    child: const Text('Sair', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onDrawerItem(int id) {
    Navigator.of(context).pop(); // fecha drawer
    switch (id) {
      case 0:
        _barcodeFocusNode.requestFocus();
        break;
      case 1:
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
        break;
      case 2:
        _showFavoritesDialog();
        break;
      case 3:
        _openBarcodeScanner();
        break;
      case 4:
        _startVoiceRecognition();
        break;
      case 5:
        _showThemeDialog();
        break;
      case 6:
        _showFloatingDialog();
        break;
      case 7:
        _stopFloating();
        break;
      case 8:
        _shareApp();
        break;
      case 9:
        _showExitDialog();
        break;
    }
  }

  Future<void> _openBarcodeScanner() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (barcode != null && barcode.isNotEmpty) {
      _etBarcode.text = barcode;
      _consultarPreco(barcode);
    }
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).cardColor;
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      drawer: _buildDrawer(textPrimary, textSecondary),
      body: Column(
        children: [
          _buildToolbar(isDark),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _buildSearchCard(),
                _buildCameraCard(),
                if (_loading)
                  _buildLoading(),
                if (_resultCardVisible)
                  _buildResultCard(surface, textPrimary, textSecondary),
                if (!_resultCardVisible && !_loading)
                  _buildResultTextCard(surface, textPrimary),
                if (_historyVisible) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Últimas consultas',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: _clearHistory,
                        child: const Text('Limpar', style: TextStyle(color: Color(0xFFED0030))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._history.map(_buildHistoryItem),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(bool isDark) {
    return Container(
      height: 100,
      color: const Color(0xFFED0030),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: AppIcons.asset(AppIcons.menu, size: 32, color: Colors.white),
          ),
          const Expanded(
            child: Center(
              child: Image(
                image: AssetImage('assets/images/ic_toolbar_logo.png'),
                height: 70,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFED0030),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _etBarcode,
              focusNode: _barcodeFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Digitar código de barras ou descrição',
                hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (value) {
                final codigo = value.trim();
                if (codigo.isNotEmpty) {
                  if (RegExp(r'^\d+$').hasMatch(codigo)) {
                    _consultarPreco(codigo);
                  } else {
                    _searchByDescription(codigo);
                  }
                }
              },
            ),
            Container(height: 1, color: Colors.white.withOpacity(0.3), margin: const EdgeInsets.symmetric(vertical: 8)),
            Row(
              children: [
                Expanded(
                  child: IconButton(
                    icon: AppIcons.asset(AppIcons.imageSearch, size: 28, color: Colors.white),
                    onPressed: _showImageSourceDialog,
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: AppIcons.asset(AppIcons.search, size: 28, color: Colors.white),
                    onPressed: () {
                      final codigo = _etBarcode.text.trim();
                      if (codigo.isNotEmpty) {
                        if (RegExp(r'^\d+$').hasMatch(codigo)) {
                          _consultarPreco(codigo);
                        } else {
                          _searchByDescription(codigo);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Digite um código de barras ou descrição')),
                        );
                      }
                    },
                  ),
                ),
                Expanded(
                  child: IconButton(
                    icon: AppIcons.asset(AppIcons.mic, size: 28, color: Colors.white),
                    onPressed: _startVoiceRecognition,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFED0030),
      elevation: 4,
      child: InkWell(
        onTap: _openBarcodeScanner,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, color: Colors.white, size: 32),
              SizedBox(width: 12),
              Text('ler código de barras',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Color(0xFFED0030)),
          const SizedBox(height: 16),
          Text(_loadingText, style: const TextStyle(color: Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _buildResultCard(Color surface, Color? textPrimary, Color? textSecondary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: surface,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 400,
              width: double.infinity,
              child: GestureDetector(
                onLongPress: () {
                  if (_currentImageUrl.isNotEmpty) {
                    ImageDownloader.downloadImage(
                        context, _currentImageUrl, _currentProductName);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nenhuma imagem disponível para download')),
                    );
                  }
                },
                child: _currentImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _currentImageUrl,
                        fit: BoxFit.contain,
                        placeholder: (c, u) =>
                            AppIcons.asset(AppIcons.productPlaceholder, size: 80),
                        errorWidget: (c, u, e) =>
                            AppIcons.asset(AppIcons.productPlaceholder, size: 80),
                      )
                    : AppIcons.asset(AppIcons.productPlaceholder, size: 80),
              ),
            ),
            GestureDetector(
              onTap: () => _copyToClipboard(_currentProductName, 'Nome do produto copiado!'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_currentProductName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
              ),
            ),
            Container(height: 1, color: const Color(0xFFE0E0E0), margin: const EdgeInsets.only(bottom: 12)),
            GestureDetector(
              onTap: () => _copyToClipboard(
                  _currentBarcodeText.replaceAll('🔢 Código: ', ''), 'Código de barras copiado!'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_currentBarcodeText,
                    style: TextStyle(fontSize: 14, color: textSecondary)),
              ),
            ),
            if (_sapVisible)
              GestureDetector(
                onTap: () => _copyToClipboard(
                    _currentSapText.replaceAll('🆔 SAP: ', ''), 'SAP copiado!'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_currentSapText, style: TextStyle(fontSize: 14, color: textSecondary)),
                ),
              ),
            GestureDetector(
              onTap: () => _copyToClipboard(_currentPriceText, 'Preço copiado!'),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_currentPriceText,
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFED0030))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: AppIcons.asset(
                    _isFavorite ? AppIcons.favorite : AppIcons.favoriteBorder,
                    size: 36,
                    color: const Color(0xFFED0030),
                  ),
                  onPressed: () {
                    if (_currentProductEan.isNotEmpty) {
                      _toggleFavorite();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhum produto para adicionar aos favoritos')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                    ),
                    onPressed: _shareProduct,
                    child: const Text('compartilhar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTextCard(Color surface, Color? textPrimary) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: surface,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_resultText, style: TextStyle(fontSize: 14, color: textPrimary)),
      ),
    );
  }

  Widget _buildHistoryItem(HistoryEntity h) {
    final textPrimary = Theme.of(context).textTheme.bodyMedium?.color;
    final textSecondary = Theme.of(context).textTheme.bodySmall?.color;
    final priceColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFF6B6B)
        : const Color(0xFFED0030);
    final date = DateTime.fromMillisecondsSinceEpoch(h.timestamp);
    final dateStr = '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _etBarcode.text = h.barcode;
          _consultarPreco(h.barcode);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.productName,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 4),
              Text('🔢 ${h.barcode}', style: TextStyle(fontSize: 12, color: textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(h.price,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: priceColor)),
                  ),
                  Text(dateStr, style: TextStyle(fontSize: 11, color: textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(Color? textPrimary, Color? textSecondary) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFED0030)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/ic_sidebar_logo.png', height: 70),
                const SizedBox(height: 12),
                const Text('Scanner da Americanas',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Consulte preços rapidamente',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
          _drawerItem(AppIcons.home, 'Início', 0, textPrimary),
          _drawerItem(AppIcons.history, 'Histórico', 1, textPrimary),
          _drawerItem(AppIcons.favorite, 'Favoritos', 2, textPrimary),
          _drawerItem(AppIcons.camera, 'Scanner de Código', 3, textPrimary),
          _drawerItem(AppIcons.mic, 'Pesquisa por Voz', 4, textPrimary),
          _drawerItem(AppIcons.theme, 'Tema', 5, textPrimary),
          _drawerItem(AppIcons.float, 'Ativar Bolinha Flutuante', 6, textPrimary),
          _drawerItem(AppIcons.floatOff, 'Desativar Bolinha', 7, textPrimary),
          _drawerItem(AppIcons.share, 'Compartilhar App', 8, textPrimary),
          _drawerItem(AppIcons.exit, 'Sair', 9, textPrimary),
        ],
      ),
    );
  }

  Widget _drawerItem(String icon, String title, int id, Color? textPrimary) {
    return ListTile(
      leading: AppIcons.asset(icon, size: 24, color: const Color(0xFFED0030)),
      title: Text(title, style: TextStyle(color: textPrimary)),
      onTap: () => _onDrawerItem(id),
    );
  }
}
