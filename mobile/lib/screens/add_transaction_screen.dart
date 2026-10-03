import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api_client.dart';
import '../models.dart';
import '../ocr_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart' show categoryColor, categoryIcon;

/// Harcama/Gelir ekleme veya düzenleme — premium tasarım.
/// Gider notu yazıldıkça GERÇEK eğitilmiş model (/ml/categorize) canlı öneri verir.
class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existing;
  const AddTransactionScreen({super.key, this.existing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = 'expense';
  String? _selectedCategory;
  bool _busy = false;
  Timer? _debounce;

  CategorySuggestion? _suggestion;
  bool _suggesting = false;
  bool _isRecurring = false;

  bool get _isEdit => widget.existing != null;
  bool get _isIncome => _type == 'income';

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      final displayAmount = CurrencyService.convertFromTry(ex.amount, currencyNotifier.value);
      _amount.text = displayAmount.toStringAsFixed(displayAmount % 1 == 0 ? 0 : 2);
      _note.text = ex.note;
      _type = ex.type;
      _selectedCategory = ex.category;
      _isRecurring = ex.isRecurring;
    }
    _note.addListener(_onNote);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onNote() {
    _debounce?.cancel();
    if (_isIncome) {
      setState(() => _suggestion = null);
      return;
    }
    final text = _note.text.trim();
    if (text.length < 3) {
      setState(() {
        _suggestion = null;
        _suggesting = false;
      });
      return;
    }
    setState(() => _suggesting = true);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final s = await ApiClient.instance.categorize(text);
        if (mounted) setState(() => _suggestion = s);
      } catch (_) {
      } finally {
        if (mounted) setState(() => _suggesting = false);
      }
    });
  }

  void _setType(String t) {
    setState(() {
      _type = t;
      if (!_isEdit) {
        _selectedCategory = null;
        _suggestion = null;
        _isRecurring = false;
      }
    });
  }

  void _pick(String c) {
    setState(() => _selectedCategory = c);
  }

  // Fiş OCR: kamera/galeriden fiş oku → tutar+işyeri doldur → model kategorize etsin.
  Future<void> _scanReceipt() async {
    // Kaynak seç: kamera / galeri
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: AppColors.onSurface),
              title: Text('Kamera',
                  style: TextStyle(color: AppColors.onSurface)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  Icon(Icons.photo_library_outlined, color: AppColors.onSurface),
              title: Text('Galeriden seç',
                  style: TextStyle(color: AppColors.onSurface)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    _toast('Fiş okunuyor…');
    try {
      final scan = await OcrService.scan(source);
      if (scan == null) return;
      setState(() {
        if (scan.amount != null) {
          // Fiş tutarı TL; alan seçili para biriminde, kaydederken TL'ye geri çevrilir.
          final shown =
              CurrencyService.convertFromTry(scan.amount!, currencyNotifier.value);
          _amount.text = shown.toStringAsFixed(shown % 1 == 0 ? 0 : 2);
        }
        if (scan.merchant.isNotEmpty) _note.text = scan.merchant;
      });
      if (scan.amount == null) {
        _toast('Tutar okunamadı, elle gir', error: true);
      } else {
        _toast('Fiş okundu — kontrol edip kaydet');
      }
    } catch (e) {
      _toast('Fiş okunamadı: ${e.toString()}', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle,
              color: error ? AppColors.error : const Color(0xFF46F1C5),
              size: 18),
          const SizedBox(width: 10),
          Text(msg),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceContainerHigh,
    ));
  }

  Future<void> _save() async {
    final enteredAmount = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (enteredAmount == null || enteredAmount <= 0) {
      _toast('Lütfen tutar gir', error: true);
      return;
    }
    final amountInTry = CurrencyService.convertToTry(enteredAmount, currencyNotifier.value);
    if (!_isIncome && _selectedCategory == null) {
      _toast('Lütfen kategori seç', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        await ApiClient.instance.updateTransaction(
          widget.existing!.id,
          amount: amountInTry,
          type: _type,
          category: _selectedCategory ??
              (_isIncome ? 'Diğer' : widget.existing!.category),
          note: _note.text.trim(),
          isRecurring: _isRecurring,
        );
      } else {
        await ApiClient.instance.addTransaction(
          amount: amountInTry,
          type: _type,
          category: _selectedCategory, // null → backend modelle/Diğer atar
          note: _note.text.trim(),
          isRecurring: _isRecurring,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast(e.toString().replaceFirst('Exception: ', ''), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeModeNotifier.value == ThemeMode.dark;
    final accent = _isIncome ? const Color(0xFF46F1C5) : AppColors.error;
    final title = _isEdit
        ? (_isIncome ? 'Geliri Düzenle' : 'Gideri Düzenle')
        : (_isIncome ? 'Gelir Ekle' : 'Harcama Ekle');

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 130),
            children: [
              // Başlık
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _circleBtn(Icons.chevron_left,
                      () => Navigator.of(context).maybePop()),
                  Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  _circleBtn(
                      isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      toggleThemeMode),
                ],
              ),
              const SizedBox(height: 24),

              // Gider/Gelir segmenti
              _segmented(),
              const SizedBox(height: 14),

              // Fiş tara (gider + mobil)
              if (!_isIncome && OcrService.supported) ...[
                Press(
                  onTap: _scanReceipt,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.surfaceContainerHigh),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.document_scanner_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Fiş Tara',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ] else
                const SizedBox(height: 12),

              // Tutar
              Column(
                children: [
                  Text('TUTAR',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: AppColors.outline)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_isIncome ? '+${currencyNotifier.value}' : '−${currencyNotifier.value}',
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              fontFeatures: kTnum)),
                      const SizedBox(width: 6),
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amount,
                          autofocus: !_isEdit,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.center,
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: AppColors.onSurface,
                              fontFeatures: kTnum),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w800,
                                color: AppColors.surfaceContainerHigh),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 120,
                    height: 2,
                    decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Kategori (sadece gider)
              if (!_isIncome) ...[
                Text('Kategori',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
                const SizedBox(height: 13),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                  children: kCategories.map(_catCell).toList(),
                ),
                const SizedBox(height: 22),
              ],

              // Not + canlı öneri
              Text('Not',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
              const SizedBox(height: 13),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: TextField(
                  controller: _note,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: AppColors.onSurface),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'örn. Migros\'tan haftalık market alışverişi…',
                    hintStyle:
                        TextStyle(color: AppColors.outline, fontSize: 14),
                  ),
                ),
              ),
              if (_isIncome) ...[
                const SizedBox(height: 18),
                _recurringCheckbox(),
              ],
              if (!_isIncome) _suggestionCard(),
            ],
          ),

          // Kaydet barı
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: Press(
                onTap: _busy ? null : _save,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16)),
                  child: _busy
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onPrimary))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check,
                                size: 18, color: AppColors.onPrimary),
                            const SizedBox(width: 8),
                            Text(
                                _isEdit ? 'Değişiklikleri Kaydet' : 'Kaydet',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimary)),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return Press(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surfaceContainer)),
        child: Icon(icon, size: 19, color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _segmented() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _isIncome ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: _isIncome ? const Color(0xFF46F1C5) : AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _segTab('Gider', Icons.south, !_isIncome,
                  Colors.white, () => _setType('expense')),
              _segTab('Gelir', Icons.north, _isIncome,
                  Colors.black, () => _setType('income')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segTab(
      String label, IconData icon, bool active, Color activeText, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active ? activeText : AppColors.onSurfaceVariant),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: active ? activeText : AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _catCell(String c) {
    final on = _selectedCategory == c;
    final color = categoryColor(c);
    return GestureDetector(
      onTap: () => _pick(c),
      child: Container(
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: on ? color : AppColors.glassBorder, width: on ? 1.5 : 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(categoryIcon(c), size: 18, color: color),
            ),
            const SizedBox(height: 7),
            Text(c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    color: on ? AppColors.onSurface : AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _suggestionCard() {
    if (_suggesting) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.outline)),
              const SizedBox(width: 10),
              Text('Kategori analiz ediliyor…',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }
    final s = _suggestion;
    if (s == null) return const SizedBox.shrink();
    final color = categoryColor(s.category);
    final already = _selectedCategory == s.category;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(categoryIcon(s.category), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 12, color: color),
                      const SizedBox(width: 5),
                      Text('ÖNERİLEN KATEGORİ',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: AppColors.outline)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(s.category,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface)),
                      const SizedBox(width: 6),
                      Text('%${(s.confidence * 100).toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                              fontFeatures: kTnum)),
                    ],
                  ),
                ],
              ),
            ),
            if (already)
              Row(
                children: [
                  Icon(Icons.check, size: 15, color: color),
                  const SizedBox(width: 4),
                  Text('Seçili',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              )
            else
              Press(
                onTap: () => _pick(s.category),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(11)),
                  child: const Text('Kabul et',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF062019))),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recurringCheckbox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Gelir kaydedilsin mi',
              style: TextStyle(fontSize: 14, color: AppColors.onSurface),
            ),
          ),
          Checkbox(
            value: _isRecurring,
            activeColor: const Color(0xFF46F1C5),
            checkColor: Colors.black,
            onChanged: (val) async {
              if (val == true) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: AppColors.glassBorder)),
                      title: Text(
                        'Gelir Kaydedilsin Mi?',
                        style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      content: Text(
                        'Kabul ederseniz her ay otomatik olarak gelir olarak hesaplanacaktır. Devam etmek istiyor musunuz?',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Hayır',
                            style: TextStyle(
                                color: AppColors.outline, fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Evet',
                            style: TextStyle(
                                color: Color(0xFF46F1C5), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  setState(() => _isRecurring = true);
                } else {
                  setState(() => _isRecurring = false);
                }
              } else {
                setState(() => _isRecurring = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
