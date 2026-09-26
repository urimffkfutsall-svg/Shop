import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/store_state.dart';

enum AdminContentKind { hero, sponsors, ads }

extension AdminContentKindInfo on AdminContentKind {
  String get title => switch (this) {
        AdminContentKind.hero => 'Slideshow',
        AdminContentKind.sponsors => 'Sponsorët',
        AdminContentKind.ads => 'Reklamat',
      };

  String get addLabel => switch (this) {
        AdminContentKind.hero => 'Shto slide',
        AdminContentKind.sponsors => 'Shto sponsor',
        AdminContentKind.ads => 'Shto reklamë',
      };

  String get mediaField => switch (this) {
        AdminContentKind.hero => 'media_url',
        AdminContentKind.sponsors => 'logo_url',
        AdminContentKind.ads => 'banner_url',
      };

  String get folder => switch (this) {
        AdminContentKind.hero => 'hero',
        AdminContentKind.sponsors => 'sponsors',
        AdminContentKind.ads => 'advertising',
      };
}

class AdminHomepageContentView extends StatefulWidget {
  final StoreState state;
  final AdminContentKind kind;

  const AdminHomepageContentView({
    super.key,
    required this.state,
    required this.kind,
  });

  @override
  State<AdminHomepageContentView> createState() =>
      _AdminHomepageContentViewState();
}

class _AdminHomepageContentViewState extends State<AdminHomepageContentView> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void didUpdateWidget(covariant AdminHomepageContentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => switch (widget.kind) {
        AdminContentKind.hero => widget.state.service.adminHeroSlides(),
        AdminContentKind.sponsors => widget.state.service.adminSponsors(),
        AdminContentKind.ads => widget.state.service.adminAdCampaigns(),
      };

  void _refresh() => setState(() => future = _load());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.kind.title,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _edit(null),
                icon: const Icon(Icons.add),
                label: Text(widget.kind.addLabel),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Rifresko',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _CmsError(onRetry: _refresh);
                }
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) {
                  return Center(
                    child: Text('Nuk ka ${widget.kind.title.toLowerCase()}.'),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _ContentTile(
                      kind: widget.kind,
                      row: row,
                      onEdit: () => _edit(row),
                      onDelete: () => _delete(row),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic>? row) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ContentDialog(
        state: widget.state,
        kind: widget.kind,
        row: row,
      ),
    );
    if (changed == true && mounted) {
      _refresh();
      await widget.state.init();
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmo fshirjen'),
        content: Text('“${_rowTitle(widget.kind, row)}” do të fshihet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anulo'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Fshi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.state.service.deleteHomepageContent(
        kind: widget.kind.name,
        id: '${row['id']}',
        mediaUrls: [
          row[widget.kind.mediaField]?.toString(),
          if (widget.kind == AdminContentKind.ads) row['logo_url']?.toString(),
        ].whereType<String>().toList(),
      );
      if (mounted) {
        _refresh();
        await widget.state.init();
      }
    } catch (_) {
      if (mounted) _showCmsError(context);
    }
  }
}

String _rowTitle(AdminContentKind kind, Map<String, dynamic> row) {
  return switch (kind) {
    AdminContentKind.hero => row['title']?.toString() ?? '',
    AdminContentKind.sponsors => row['company_name']?.toString() ?? '',
    AdminContentKind.ads => row['title']?.toString() ?? '',
  };
}

class _ContentTile extends StatelessWidget {
  final AdminContentKind kind;
  final Map<String, dynamic> row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContentTile({
    required this.kind,
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final media = row[kind.mediaField]?.toString() ?? '';
    final active = row['is_active'] == true;
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 72,
          height: 58,
          child: media.isEmpty ||
                  (kind == AdminContentKind.hero &&
                      row['media_type'] == 'video')
              ? ColoredBox(
                  color: Colors.black12,
                  child: Icon(
                    row['media_type'] == 'video'
                        ? Icons.play_circle_outline
                        : Icons.image_outlined,
                  ),
                )
              : Image.network(
                  media,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
        ),
        title: Text(
          _rowTitle(kind, row),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${row['description'] ?? row['subtitle'] ?? ''}\n'
          'Renditja: ${row['sort_order'] ?? 0} • '
          '${active ? 'Aktive' : 'Joaktive'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Ndrysho',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Fshi',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentDialog extends StatefulWidget {
  final StoreState state;
  final AdminContentKind kind;
  final Map<String, dynamic>? row;

  const _ContentDialog({
    required this.state,
    required this.kind,
    this.row,
  });

  @override
  State<_ContentDialog> createState() => _ContentDialogState();
}

class _ContentDialogState extends State<_ContentDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController title;
  late final TextEditingController subtitle;
  late final TextEditingController description;
  late final TextEditingController buttonText;
  late final TextEditingController destinationUrl;
  late final TextEditingController website;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController address;
  late final TextEditingController advertisingText;
  late final TextEditingController sortOrder;
  late final TextEditingController secondaryLogoUrl;

  String mediaType = 'image';
  bool active = true;
  bool saving = false;
  DateTime? startDate;
  DateTime? endDate;
  _PickedMedia? pickedMedia;

  @override
  void initState() {
    super.initState();
    final row = widget.row ?? <String, dynamic>{};
    title = TextEditingController(
      text: widget.kind == AdminContentKind.sponsors
          ? row['company_name']?.toString() ?? ''
          : row['title']?.toString() ?? '',
    );
    subtitle = TextEditingController(text: row['subtitle']?.toString() ?? '');
    description =
        TextEditingController(text: row['description']?.toString() ?? '');
    buttonText =
        TextEditingController(text: row['button_text']?.toString() ?? '');
    destinationUrl = TextEditingController(
      text: switch (widget.kind) {
        AdminContentKind.hero => row['button_url']?.toString() ?? '',
        AdminContentKind.sponsors => row['advertising_url']?.toString() ?? '',
        AdminContentKind.ads => row['destination_url']?.toString() ?? '',
      },
    );
    website = TextEditingController(text: row['website']?.toString() ?? '');
    phone = TextEditingController(text: row['phone']?.toString() ?? '');
    email = TextEditingController(text: row['email']?.toString() ?? '');
    address = TextEditingController(text: row['address']?.toString() ?? '');
    advertisingText = TextEditingController(
      text: row['advertising_text']?.toString() ?? '',
    );
    sortOrder =
        TextEditingController(text: row['sort_order']?.toString() ?? '0');
    secondaryLogoUrl =
        TextEditingController(text: row['logo_url']?.toString() ?? '');
    mediaType = row['media_type']?.toString() ?? 'image';
    active = row['is_active'] as bool? ?? true;
    startDate = _parseDate(row['start_date']);
    endDate = _parseDate(row['end_date']);
  }

  DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  @override
  void dispose() {
    for (final controller in [
      title,
      subtitle,
      description,
      buttonText,
      destinationUrl,
      website,
      phone,
      email,
      address,
      advertisingText,
      sortOrder,
      secondaryLogoUrl,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existingMedia = widget.row?[widget.kind.mediaField]?.toString() ?? '';
    return AlertDialog(
      title: Text(
        widget.row == null
            ? widget.kind.addLabel
            : 'Ndrysho ${widget.kind.title.toLowerCase()}',
      ),
      content: SizedBox(
        width: 680,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: title,
                  validator: _required,
                  decoration: InputDecoration(
                    labelText: widget.kind == AdminContentKind.sponsors
                        ? 'Emri i kompanisë *'
                        : 'Titulli *',
                  ),
                ),
                if (widget.kind == AdminContentKind.hero)
                  TextFormField(
                    controller: subtitle,
                    decoration: const InputDecoration(labelText: 'Nëntitulli'),
                  ),
                TextFormField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Përshkrimi'),
                ),
                if (widget.kind == AdminContentKind.hero) ...[
                  DropdownButtonFormField<String>(
                    value: mediaType,
                    decoration:
                        const InputDecoration(labelText: 'Lloji i medias'),
                    items: const [
                      DropdownMenuItem(value: 'image', child: Text('Imazh')),
                      DropdownMenuItem(value: 'video', child: Text('Video')),
                    ],
                    onChanged: (value) =>
                        setState(() => mediaType = value ?? 'image'),
                  ),
                  TextFormField(
                    controller: buttonText,
                    decoration:
                        const InputDecoration(labelText: 'Teksti i butonit'),
                  ),
                ],
                if (widget.kind == AdminContentKind.sponsors) ...[
                  TextFormField(
                    controller: website,
                    decoration: const InputDecoration(labelText: 'Website'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: phone,
                          decoration:
                              const InputDecoration(labelText: 'Telefoni'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: email,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Adresa'),
                  ),
                  TextFormField(
                    controller: advertisingText,
                    decoration:
                        const InputDecoration(labelText: 'Teksti reklamues'),
                  ),
                ],
                TextFormField(
                  controller: destinationUrl,
                  decoration: InputDecoration(
                    labelText: widget.kind == AdminContentKind.hero
                        ? 'URL-ja e butonit'
                        : 'URL-ja e destinacionit',
                  ),
                ),
                if (widget.kind == AdminContentKind.ads)
                  TextFormField(
                    controller: secondaryLogoUrl,
                    decoration: const InputDecoration(
                      labelText: 'URL-ja e logos (opsionale)',
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pickedMedia == null
                            ? (existingMedia.isEmpty
                                ? 'Media nuk është zgjedhur.'
                                : 'Media aktuale do të ruhet.')
                            : pickedMedia!.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: saving ? null : _pickMedia,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        widget.kind == AdminContentKind.hero &&
                                mediaType == 'video'
                            ? 'Ngarko video'
                            : 'Ngarko imazh',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _CmsDateField(
                        label: 'Data e fillimit',
                        value: startDate,
                        onChanged: (value) => setState(() => startDate = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CmsDateField(
                        label: 'Data e përfundimit',
                        value: endDate,
                        onChanged: (value) => setState(() => endDate = value),
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: sortOrder,
                  keyboardType: TextInputType.number,
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? 'Vendos një numër të plotë.'
                      : null,
                  decoration: const InputDecoration(labelText: 'Renditja'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setState(() => active = value),
                  title: const Text('Aktive'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Anulo'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? 'Duke ruajtur…' : 'Ruaj'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Fusha është e detyrueshme.' : null;

  Future<void> _pickMedia() async {
    final allowsVideo =
        widget.kind == AdminContentKind.hero && mediaType == 'video';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowsVideo
          ? const ['mp4', 'webm']
          : const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    if (file.size > 25 * 1024 * 1024) {
      if (mounted) _showCmsError(context, 'Skedari është më i madh se 25 MB.');
      return;
    }
    setState(() {
      pickedMedia = _PickedMedia(
        name: file.name,
        bytes: file.bytes!,
        contentType: _mimeType(file.extension),
      );
    });
  }

  String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        _ => 'image/jpeg',
      };

  Future<void> _save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (startDate != null && endDate != null && !endDate!.isAfter(startDate!)) {
      _showCmsError(
        context,
        'Data e përfundimit duhet të jetë pas datës së fillimit.',
      );
      return;
    }
    final oldMedia = widget.row?[widget.kind.mediaField]?.toString();
    if ((oldMedia == null || oldMedia.isEmpty) && pickedMedia == null) {
      _showCmsError(context, 'Ngarko median para ruajtjes.');
      return;
    }
    setState(() => saving = true);
    String? mediaUrl = oldMedia;
    try {
      if (pickedMedia != null) {
        mediaUrl = await widget.state.service.uploadMedia(
          bytes: pickedMedia!.bytes,
          fileName: pickedMedia!.name,
          contentType: pickedMedia!.contentType,
          folder: widget.kind.folder,
        );
      }
      final common = <String, dynamic>{
        widget.kind.mediaField: mediaUrl,
        'description': description.text.trim(),
        'start_date': startDate?.toUtc().toIso8601String(),
        'end_date': endDate?.toUtc().toIso8601String(),
        'is_active': active,
        'sort_order': int.parse(sortOrder.text),
      };
      final data = switch (widget.kind) {
        AdminContentKind.hero => {
            ...common,
            'title': title.text.trim(),
            'subtitle': subtitle.text.trim(),
            'media_type': mediaType,
            'button_text': buttonText.text.trim(),
            'button_url': destinationUrl.text.trim(),
          },
        AdminContentKind.sponsors => {
            ...common,
            'company_name': title.text.trim(),
            'website': _nullable(website.text),
            'phone': _nullable(phone.text),
            'email': _nullable(email.text),
            'address': _nullable(address.text),
            'advertising_text': advertisingText.text.trim(),
            'advertising_url': _nullable(destinationUrl.text),
          },
        AdminContentKind.ads => {
            ...common,
            'title': title.text.trim(),
            'destination_url': _nullable(destinationUrl.text),
            'logo_url': _nullable(secondaryLogoUrl.text),
          },
      };
      await widget.state.service.saveHomepageContent(
        kind: widget.kind.name,
        id: widget.row?['id']?.toString(),
        data: data,
      );
      if (pickedMedia != null &&
          oldMedia != null &&
          oldMedia.isNotEmpty &&
          oldMedia != mediaUrl) {
        await widget.state.service.deleteMedia(oldMedia);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (pickedMedia != null && mediaUrl != null && mediaUrl != oldMedia) {
        await widget.state.service.deleteMedia(mediaUrl);
      }
      if (mounted) {
        setState(() => saving = false);
        _showCmsError(context);
      }
    }
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
}

class AdminHomepageSectionsView extends StatefulWidget {
  final StoreState state;

  const AdminHomepageSectionsView({super.key, required this.state});

  @override
  State<AdminHomepageSectionsView> createState() =>
      _AdminHomepageSectionsViewState();
}

class _AdminHomepageSectionsViewState extends State<AdminHomepageSectionsView> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = widget.state.service.adminHomepageSections();
  }

  void _refresh() => setState(
        () => future = widget.state.service.adminHomepageSections(),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seksionet e ballinës',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('Ndrysho titullin, dukshmërinë dhe renditjen.'),
          const SizedBox(height: 20),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _CmsError(onRetry: _refresh);
                return ListView.separated(
                  itemCount: snapshot.data?.length ?? 0,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final section = snapshot.data![index];
                    return Card(
                      elevation: 0,
                      child: ListTile(
                        leading: Icon(
                          section['is_visible'] == true
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        title: Text(
                          section['title']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${section['section_key']} • Renditja: ${section['sort_order'] ?? 0}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Ndrysho',
                          onPressed: () => _edit(section),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Map<String, dynamic> section) async {
    final title =
        TextEditingController(text: section['title']?.toString() ?? '');
    final order =
        TextEditingController(text: section['sort_order']?.toString() ?? '0');
    var visible = section['is_visible'] as bool? ?? true;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ndrysho seksionin'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Titulli'),
                ),
                TextField(
                  controller: order,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Renditja'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: visible,
                  onChanged: (value) => setDialogState(() => visible = value),
                  title: const Text('Shfaq në ballinë'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Anulo'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ruaj'),
            ),
          ],
        ),
      ),
    );
    if (saved != true ||
        title.text.trim().isEmpty ||
        int.tryParse(order.text) == null) {
      title.dispose();
      order.dispose();
      return;
    }
    try {
      await widget.state.service.saveHomepageSection(
        section['section_key'].toString(),
        {
          'title': title.text.trim(),
          'sort_order': int.parse(order.text),
          'is_visible': visible,
        },
      );
      await widget.state.init();
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) _showCmsError(context);
    } finally {
      title.dispose();
      order.dispose();
    }
  }
}

class _PickedMedia {
  final String name;
  final Uint8List bytes;
  final String contentType;

  const _PickedMedia({
    required this.name,
    required this.bytes,
    required this.contentType,
  });
}

class _CmsDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _CmsDateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 3650)),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
        );
        if (selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: 'Pastro',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null
              ? 'Pa kufizim'
              : '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}',
        ),
      ),
    );
  }
}

class _CmsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CmsError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            const Text('Të dhënat nuk mund të ngarkohen.'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Provo përsëri'),
            ),
          ],
        ),
      );
}

void _showCmsError(
  BuildContext context, [
  String message = 'Veprimi nuk u krye. Provo përsëri.',
]) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
  );
}
