import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MedicineApp());
}

class Medicine {
  final String id;
  final String ingredient;
  final String category;
  final String comment;

  const Medicine({
    required this.id,
    required this.ingredient,
    required this.category,
    required this.comment,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingredient': ingredient,
        'category': category,
        'comment': comment,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        ingredient: json['ingredient'] as String,
        category: json['category'] as String,
        comment: json['comment'] as String,
      );
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '약물 검색 사전',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          scaffoldBackgroundColor: const Color(0xFFF7F9FA),
        ),
        home: const MedicineHome(),
      );
}

class MedicineHome extends StatefulWidget {
  const MedicineHome({super.key});

  @override
  State<MedicineHome> createState() => _MedicineHomeState();
}

class _MedicineHomeState extends State<MedicineHome> {
  static const _storageKey = 'medicines_v1';
  final _preferences = SharedPreferencesAsync();
  final _searchController = TextEditingController();
  List<Medicine> _medicines = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_refreshSearch);
  }

  void _refreshSearch() => setState(() {});

  @override
  void dispose() {
    _searchController.removeListener(_refreshSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final raw = await _preferences.getString(_storageKey);
      if (raw != null) {
        final values = jsonDecode(raw) as List<dynamic>;
        _medicines = values
            .map((item) => Medicine.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      if (mounted) _notice('저장된 데이터를 불러오지 못했어.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _save(List<Medicine> next) async {
    setState(() => _busy = true);
    try {
      await _preferences.setString(
        _storageKey,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
      if (mounted) setState(() => _medicines = next);
      return true;
    } catch (_) {
      if (mounted) _notice('저장에 실패했어. 다시 시도해 줘.');
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _edit({Medicine? original}) async {
    if (_busy) return;
    final ingredient = TextEditingController(text: original?.ingredient ?? '');
    final category = TextEditingController(text: original?.category ?? '');
    final comment = TextEditingController(text: original?.comment ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Medicine>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(original == null ? '약물 등록' : '약물 수정'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: ingredient,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '성분명 *',
                      hintText: '예: 멜록시캄',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '성분명을 입력해 줘.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: category,
                    decoration: const InputDecoration(
                      labelText: '약물 분류 *',
                      hintText: '예: 소염진통제, 심장, 갑상선',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '분류를 입력해 줘.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: comment,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '간단한 코멘트',
                      hintText: '예: 메타캄',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                Medicine(
                  id: original?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  ingredient: ingredient.text.trim(),
                  category: category.text.trim(),
                  comment: comment.text.trim(),
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    // Dialog is closed before its controllers are disposed.
    // Delay disposal until the route's closing animation completes.
    Future.delayed(const Duration(milliseconds: 500), () {
      ingredient.dispose();
      category.dispose();
      comment.dispose();
    });

    if (!mounted || result == null) return;
    final duplicate = _medicines.any(
      (item) =>
          item.id != result.id &&
          item.ingredient.toLowerCase() == result.ingredient.toLowerCase(),
    );
    if (duplicate) {
      _notice('이미 등록된 성분명이야.');
      return;
    }
    final next = [..._medicines];
    if (original == null) {
      next.add(result);
    } else {
      final index = next.indexWhere((item) => item.id == original.id);
      if (index < 0) return;
      next[index] = result;
    }
    if (await _save(next) && mounted) {
      _notice(original == null ? '약물을 등록했어.' : '약물을 수정했어.');
    }
  }

  Future<void> _delete(Medicine medicine) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('약물 삭제'),
        content: Text('${medicine.ingredient}을(를) 삭제할까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final next = _medicines.where((item) => item.id != medicine.id).toList();
    if (await _save(next) && mounted) _notice('약물을 삭제했어.');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final results = _medicines
        .where((item) => item.ingredient.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.ingredient.compareTo(b.ingredient));

    return Scaffold(
      appBar: AppBar(
        title: const Text('약물 검색 사전'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_loading || _busy) ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('약물 등록'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: '성분명으로 검색',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                icon: const Icon(Icons.close),
                                onPressed: _searchController.clear,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('가나다순 · ${results.length}개 검색 결과'),
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Text(
                              _medicines.isEmpty
                                  ? '아직 등록된 약물이 없어.\n아래 버튼으로 첫 약물을 등록해 봐!'
                                  : '검색된 약물이 없어.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final medicine = results[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 5),
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medicine.ingredient,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('분류: ${medicine.category}'),
                                      if (medicine.comment.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('코멘트: ${medicine.comment}'),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _edit(original: medicine),
                                            icon: const Icon(Icons.edit_outlined),
                                            label: const Text('수정'),
                                          ),
                                          TextButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () => _delete(medicine),
                                            icon: const Icon(Icons.delete_outline),
                                            label: const Text('삭제'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
