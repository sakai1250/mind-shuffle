// lib/features/word_card/view/word_card_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

// (WordCategoryクラスは変更なし)
class WordCategory {
  final String name;
  final String filePath;
  WordCategory({required this.name, required this.filePath});
  @override
  bool operator ==(Object other) => other is WordCategory && other.filePath == filePath;
  @override
  int get hashCode => filePath.hashCode;
}

class WordCardScreen extends StatefulWidget {
  const WordCardScreen({super.key});
  @override
  State<WordCardScreen> createState() => _WordCardScreenState();
}

class _WordCardScreenState extends State<WordCardScreen> {
  // --- State Variables ---
  bool _isLoading = true;
  String _englishWord = '';
  String _japaneseTranslation = '';
  String? _error;
  bool _isAutoplaying = false;
  Timer? _autoplayTimer;
  double _autoplayIntervalSeconds = 7.0;

  // --- Services ---
  final GoogleTranslator _translator = GoogleTranslator();
  final FlutterTts _flutterTts = FlutterTts();
  
  // --- Data ---
  List<String> _wordList = [];
  List<WordCategory> _categories = [];
  WordCategory? _selectedCategory;
  // ★★★ 全てのJSONファイルのパスを保持するリストを追加 ★★★
  List<String> _allJsonPaths = [];

  @override
  void initState() {
    super.initState();
    _discoverCategoriesAndLoadFirst();
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _discoverCategoriesAndLoadFirst() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    
    // 全てのJSONパスを抽出し、状態として保持
    _allJsonPaths = manifestMap.keys
        .where((path) => path.startsWith('assets/data/') && path.endsWith('.json'))
        .toList();

    List<WordCategory> discoveredCategories = [];
    
    // ★★★ 「All Words」カテゴリをリストの先頭に追加 ★★★
    discoveredCategories.add(WordCategory(name: "All Words", filePath: "__ALL__"));

    for (var path in _allJsonPaths) {
      List<String> parts = path
          .replaceAll('assets/data/', '')
          .replaceAll('.json', '')
          .split('/');
      String indent = '  ' * (parts.length - 1);
      String displayName = parts.last.replaceAll('_', ' ');
      displayName = displayName[0].toUpperCase() + displayName.substring(1);
      String finalName = indent + displayName;
      discoveredCategories.add(WordCategory(name: finalName, filePath: path));
    }
    
    setState(() {
      _categories = discoveredCategories;
      // デフォルトで「All Words」を選択状態にする
      if (_categories.isNotEmpty) {
        _selectedCategory = _categories.first;
      }
    });

    if (_selectedCategory != null) {
      await _loadWordListFromJson();
      if (_wordList.isNotEmpty) {
        await _fetchNewWord();
      }
    } else {
      setState(() {
        _isLoading = false;
        _error = "単語ファイルが見つかりませんでした。";
      });
    }
  }

  // ★★★ JSONデータから単語リストを抽出するロジックを独立したメソッドに ★★★
  List<String> _parseWordsFromJsonData(dynamic jsonData) {
    List<String> foundWords = [];
    if (jsonData is Map<String, dynamic>) {
      for (var key in jsonData.keys) {
        if (jsonData[key] is List) {
          final list = jsonData[key] as List;
          if (list.isNotEmpty) {
            final firstElement = list.first;
            if (firstElement is String) {
              foundWords = List<String>.from(list);
              return foundWords; // 最初に見つかったリストを返す
            } else if (firstElement is Map && firstElement.containsKey('name')) {
              foundWords = list.map((item) => item['name'].toString()).toList();
              return foundWords; // 最初に見つかったリストを返す
            }
          }
        }
      }
      // リストが見つからない場合は、キー自体を単語リストと見なす
      if (foundWords.isEmpty) {
        foundWords = jsonData.keys.toList();
      }
    } else if (jsonData is List) {
      if (jsonData.isNotEmpty && jsonData.first is String) {
        foundWords = List<String>.from(jsonData);
      }
    }
    return foundWords;
  }

  // ★★★ 「All Words」選択時の処理を追加 ★★★
  Future<void> _loadWordListFromJson() async {
    if (_selectedCategory == null) return;
    setState(() { _isLoading = true; _error = null; _wordList = []; });

    List<String> newWordList = [];

    try {
      if (_selectedCategory!.filePath == "__ALL__") {
        // 「All Words」が選択された場合、全てのJSONを読み込む
        for (final path in _allJsonPaths) {
          final String jsonString = await rootBundle.loadString(path);
          final dynamic jsonData = json.decode(jsonString);
          newWordList.addAll(_parseWordsFromJsonData(jsonData));
        }
      } else {
        // 通常のカテゴリが選択された場合
        final String jsonString = await rootBundle.loadString(_selectedCategory!.filePath);
        final dynamic jsonData = json.decode(jsonString);
        newWordList = _parseWordsFromJsonData(jsonData);
      }

      // 重複する単語を削除して最終的なリストを作成
      _wordList = newWordList.toSet().toList();

      if (_wordList.isEmpty) {
        _error = "このカテゴリから単語を読み込めませんでした。";
      }
    } catch (e) {
      _error = "単語ファイルの解析中にエラーが発生しました。";
    }
  }
  
  // ( ... 他のメソッドは変更なし ... )
  // ... buildメソッドも変更なし ...
  
  // 以下、変更のないメソッド群です
  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('設定'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('自動再生の間隔: ${_autoplayIntervalSeconds.toStringAsFixed(1)} 秒'),
                  Slider(
                    value: _autoplayIntervalSeconds,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    label: _autoplayIntervalSeconds.toStringAsFixed(1),
                    onChanged: (double value) {
                      setDialogState(() {
                        _autoplayIntervalSeconds = value;
                      });
                      setState(() {
                         _autoplayIntervalSeconds = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('閉じる'),
                  onPressed: () {
                    if (_isAutoplaying) {
                      _stopAutoplay();
                      _startAutoplay();
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _startAutoplay() {
    if (_isLoading || _wordList.isEmpty) return;
    setState(() { _isAutoplaying = true; });
    _runAutoplaySequence();
    _autoplayTimer = Timer.periodic(
      Duration(milliseconds: (_autoplayIntervalSeconds * 1000).toInt()),
      (timer) {
        if (!_isAutoplaying) {
          timer.cancel();
        } else {
          _runAutoplaySequence();
        }
      },
    );
  }
  void _stopAutoplay() {
    _autoplayTimer?.cancel();
    setState(() { _isAutoplaying = false; });
  }
  Future<void> _playAudio(String text, String languageCode) async {
    String lang = languageCode == 'en' ? "en-US" : "ja-JP";
    await _flutterTts.setLanguage(lang);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak(text);
  }
  Future<void> _runAutoplaySequence() async {
    if (!_isAutoplaying || !mounted) return;
    await _fetchNewWord();
    if (_japaneseTranslation.isNotEmpty && _isAutoplaying && mounted) {
      await _playAudio(_japaneseTranslation, 'ja');
    }
  }
  Future<void> _fetchNewWord() async {
    if (_wordList.isEmpty) {
       setState(() { _isLoading = false; _error ??= "表示できる単語がありません。"; });
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      final randomWord = _wordList[Random().nextInt(_wordList.length)];
      final translation = await _translator.translate(randomWord, from: 'en', to: 'ja');
      setState(() {
        _englishWord = randomWord;
        _japaneseTranslation = translation.text;
      });
    } catch (e) {
      setState(() { _error = "翻訳に失敗しました: ${e.toString()}"; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }
  void _onCategoryChanged(WordCategory? newCategory) {
    if (newCategory != null && newCategory != _selectedCategory) {
      if(_isAutoplaying) {
        _stopAutoplay();
      }
      setState(() {
        _selectedCategory = newCategory;
        _englishWord = '';
        _japaneseTranslation = '';
        _loadWordListFromJson().then((_) => _fetchNewWord());
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Random Word Flashcard'),
        actions: [
          if (_categories.isNotEmpty)
            SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButton<WordCategory>(
                  isExpanded: true,
                  value: _selectedCategory,
                  onChanged: _onCategoryChanged,
                  underline: Container(),
                  icon: const Icon(Icons.category, color: Colors.white),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: Colors.blueGrey[700],
                  items: _categories.map((WordCategory category) {
                    return DropdownMenuItem<WordCategory>(
                      value: category,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              if (value == 'autoplay') {
                 _isAutoplaying ? _stopAutoplay() : _startAutoplay();
              } else if (value == 'settings') {
                _showSettingsDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'autoplay',
                child: ListTile(
                  leading: Icon(_isAutoplaying ? Icons.stop : Icons.play_arrow),
                  title: Text(_isAutoplaying ? '自動再生を停止' : '自動再生を開始'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('間隔設定'),
                ),
              ),
            ],
          ),
        ],
        backgroundColor: Colors.blueGrey[800],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading && _wordList.isEmpty
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("単語を読み込んでいます..."),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildWordCard(),
                    const SizedBox(height: 40),
                    _buildNextWordButton(),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ]
                  ],
                ),
        ),
      ),
    );
  }
  Widget _buildWordCard() {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
        child: Column(
          children: [
            Text(_englishWord, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.blueAccent),
              onPressed: _englishWord.isEmpty ? null : () => _playAudio(_englishWord, 'en'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(_japaneseTranslation, style: Theme.of(context).textTheme.headlineMedium),
             IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.redAccent),
              onPressed: _japaneseTranslation.isEmpty ? null : () => _playAudio(_japaneseTranslation, 'ja'),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildNextWordButton() {
    return ElevatedButton.icon(
      icon: _isLoading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.sync),
      label: const Text('Next Word', style: TextStyle(fontSize: 18)),
      onPressed: _isLoading || _isAutoplaying ? null : _fetchNewWord,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.blueGrey[700],
      ),
    );
  }
}