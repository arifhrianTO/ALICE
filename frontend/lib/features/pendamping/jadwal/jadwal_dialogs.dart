import 'package:flutter/material.dart';

import '../../../core/colors.dart';
import 'jadwal_data.dart';


// =====================================================================
//  FUNGSI PUBLIK POP UP (tambah / ubah / hapus)
// =====================================================================

// Fungsi publik pop up jadwal (tambah / ubah / hapus).

/// Pop up "Tambahkan Jadwal"
Future<void> showAddScheduleDialog(BuildContext context) async {
  final draft = await _showAnimatedDialog<ScheduleDraft>(
    context,
    const ScheduleFormDialog(),
  );
  if (draft == null || !context.mounted) return;
  scheduleStore.add(draft.title, draft.repeat, draft.time, draft.weekday);
  _snack(context, 'Jadwal ditambahkan, menunggu persetujuan');
}

/// Pop up "Ubah Jadwal"
Future<void> showEditScheduleDialog(BuildContext context, Schedule s) async {
  final draft = await _showAnimatedDialog<ScheduleDraft>(
    context,
    ScheduleFormDialog(initial: s),
  );
  if (draft == null || !context.mounted) return;
  scheduleStore.update(
    s.id,
    draft.title,
    draft.repeat,
    draft.time,
    draft.weekday,
  );
  _snack(context, 'Jadwal diperbarui');
}

/// Pop up "Yakin ingin menghapus jadwal?"
Future<void> showDeleteScheduleDialog(BuildContext context, Schedule s) async {
  final ok = await _showAnimatedDialog<bool>(context, const DeleteDialog());
  if (ok != true || !context.mounted) return;
  scheduleStore.remove(s.id);
  _snack(context, 'Jadwal dihapus');
}

/// Dialog dengan animasi fade + scale (membal)
Future<T?> _showAnimatedDialog<T>(BuildContext context, Widget child) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Tutup',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, _, _) => child,
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kDarkPurple,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}


// =====================================================================
//  FORM TAMBAH / UBAH
// =====================================================================

/// Hasil isian form (dikirim balik lewat Navigator.pop)
class ScheduleDraft {
  final String title;
  final RepeatType repeat;
  final TimeOfDay time;
  final int weekday; // 1 = Senin ... 7 = Minggu
  const ScheduleDraft(this.title, this.repeat, this.time, this.weekday);
}

// =====================================================================
//  POP UP TAMBAH / UBAH
// =====================================================================
class ScheduleFormDialog extends StatefulWidget {
  final Schedule? initial;
  const ScheduleFormDialog({super.key, this.initial});

  @override
  State<ScheduleFormDialog> createState() => _ScheduleFormDialogState();
}

class _ScheduleFormDialogState extends State<ScheduleFormDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?.title ?? '');
  late RepeatType _repeat = widget.initial?.repeat ?? RepeatType.once;
  late TimeOfDay _time =
      widget.initial?.time ?? const TimeOfDay(hour: 0, minute: 0);
  late int _weekday = widget.initial?.date.weekday ?? DateTime.now().weekday;
  bool _error = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kPurple),
          ),
          child: child!,
        ),
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final text = _title.text.trim();
    if (text.isEmpty) {
      setState(() => _error = true);
      return;
    }
    Navigator.of(context).pop(ScheduleDraft(text, _repeat, _time, _weekday));
  }

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEdit ? 'Ubah Jadwal' : 'Tambahkan Jadwal',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTitleIndigo,
            ),
          ),
          const SizedBox(height: 18),
          // Baris 1: hari + jam
          Row(
            children: [
              Expanded(child: _buildDayDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _buildTimeField()),
            ],
          ),
          const SizedBox(height: 10),
          // Baris 2: pengulangan
          _buildRepeatDropdown(),
          const SizedBox(height: 10),
          // Baris 3: nama jadwal
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_error) setState(() => _error = false);
            },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Masukkan Jadwal',
              hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
              errorText: _error ? 'Nama jadwal wajib diisi' : null,
              filled: true,
              fillColor: kFieldBg,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: _outline(const Color(0xFFE8E2EA)),
              enabledBorder: _outline(const Color(0xFFE8E2EA)),
              focusedBorder: _outline(kPurple, width: 1.5),
              errorBorder: _outline(const Color(0xFFD32F2F)),
              focusedErrorBorder: _outline(const Color(0xFFD32F2F), width: 1.5),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DialogButton(
                label: 'Batal',
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              DialogButton(
                label: _isEdit ? 'Ubah' : 'Tambah',
                primary: true,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _outline(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Dropdown generik dengan gaya yang sama untuk semua field pop up.
  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: fieldDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 22, color: Colors.black87),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// Pilih hari Senin–Minggu (nonaktif kalau pengulangan "Setiap hari")
  Widget _buildDayDropdown() {
    final disabled = _repeat == RepeatType.daily;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: _dropdown<int>(
        value: _weekday,
        items: [
          for (int d = 1; d <= 7; d++)
            DropdownMenuItem(value: d, child: Text(dayFull[d - 1])),
        ],
        onChanged:
            disabled ? null : (v) => setState(() => _weekday = v ?? _weekday),
      ),
    );
  }

  /// Pilih pengulangan: sekali saja / tiap hari X / setiap hari / tiap minggu
  Widget _buildRepeatDropdown() {
    return _dropdown<RepeatType>(
      value: _repeat,
      items: [
        for (final r in RepeatType.values)
          DropdownMenuItem(value: r, child: Text(r.dropdownLabel(_weekday))),
      ],
      onChanged: (v) => setState(() => _repeat = v ?? _repeat),
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: _pickTime,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: fieldDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatTime(_time),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 22, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}


// =====================================================================
//  POP UP HAPUS
// =====================================================================

// =====================================================================
//  POP UP HAPUS
// =====================================================================
class DeleteDialog extends StatelessWidget {
  const DeleteDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Yakin ingin menghapus jadwal?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextPurple,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DialogButton(
                label: 'Batal',
                onTap: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 10),
              DialogButton(
                label: 'Hapus',
                primary: true,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// =====================================================================
//  KOMPONEN BERSAMA POP UP
// =====================================================================

/// Kerangka kartu putih bulat untuk semua pop up
class DialogShell extends StatelessWidget {
  final Widget child;
  const DialogShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: MediaQuery.of(context).viewInsets, // naik saat keyboard muncul
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DialogButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const DialogButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? kPurple : kBtnLight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: primary ? Colors.white : const Color(0xFF2A2A5C),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration fieldDecoration() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFEAE6F2)),
      boxShadow: [
        BoxShadow(
          color: kPurple.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    );
