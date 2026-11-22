import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_sidebar.dart';

class AdvertsScreen extends StatefulWidget {
  const AdvertsScreen({super.key});

  @override
  State<AdvertsScreen> createState() => _AdvertsScreenState();
}

class _AdvertsScreenState extends State<AdvertsScreen> {
  List<Map<String, dynamic>> _adverts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAdverts());
  }

  Future<void> _loadAdverts([ApiClient? providedApi]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = providedApi ?? context.read<ApiClient>();
      final response = await api.dio.get<List<dynamic>>('adverts/');
      setState(() {
        _adverts = (response.data ?? [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      });
    } on DioException catch (error) {
      setState(() {
        _error = error.response?.data is Map
            ? (error.response?.data['error']?.toString() ??
                'Could not load adverts.')
            : 'Could not load adverts.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _imageUrl(Map<String, dynamic> advert) {
    final value =
        advert['image_url']?.toString() ?? advert['image']?.toString() ?? '';
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;

    final base = Uri.parse(ApiConfig.baseUrl);
    final path = value.startsWith('/') ? value : '/$value';
    return base.replace(path: path, query: '').toString();
  }

  Future<void> _openAdvert(Map<String, dynamic> advert) async {
    final link = advert['link_url']?.toString();
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showCreateDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final linkController = TextEditingController();
    XFile? selectedImage;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create advert'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Link URL (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final image = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() => selectedImage = image);
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: Text(selectedImage == null
                      ? 'Choose image'
                      : 'Image selected'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    selectedImage == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Title and image are required.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created != true) return;
    if (!mounted) return;
    try {
      final image = selectedImage;
      if (image == null) return;
      final api = context.read<ApiClient>();
      final formData = FormData.fromMap({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'link_url': linkController.text.trim(),
        'is_active': 'true',
        'image': await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });
      await api.dio.post<dynamic>(
        'adverts/',
        data: formData,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advert created successfully.')),
      );
      await _loadAdverts(api);
    } on DioException catch (error) {
      if (!mounted) return;
      final responseData = error.response?.data;
      final message = responseData is Map
          ? responseData.toString()
          : 'Could not create advert.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _deleteAdvert(Map<String, dynamic> advert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete advert'),
        content: const Text('Remove this advert permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final api = context.read<ApiClient>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.dio.delete<void>('adverts/${advert['id']}/');
      if (!mounted) return;
      await _loadAdverts(api);
    } on DioException catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete advert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = context.watch<AuthProvider>().user?.name;
    return AppPageShell(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Adverts'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          leading: const AppMenuButton(),
          automaticallyImplyLeading: false,
          actions: const [AppBrandControls()],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create advert'),
        ),
        body: RefreshIndicator(
          onRefresh: _loadAdverts,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.grey.shade500),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: _loadAdverts,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : _adverts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.campaign_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No adverts available',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _adverts.length,
                          itemBuilder: (context, index) {
                            final advert = _adverts[index];
                            final imageUrl = _imageUrl(advert);
                            final canManage =
                                advert['created_by_name']?.toString() ==
                                    userName;

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              margin: const EdgeInsets.only(bottom: 16),
                              child: InkWell(
                                onTap: () => _openAdvert(advert),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (imageUrl.isNotEmpty)
                                      AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const ColoredBox(
                                            color: Color(0xFFE8EEF4),
                                            child: Icon(
                                              Icons.broken_image,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  advert['title']?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              if (canManage)
                                                IconButton(
                                                  tooltip: 'Delete advert',
                                                  onPressed: () =>
                                                      _deleteAdvert(advert),
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          if ((advert['description']
                                                      ?.toString() ??
                                                  '')
                                              .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                advert['description']
                                                    .toString(),
                                              ),
                                            ),
                                          if ((advert['link_url']?.toString() ??
                                                  '')
                                              .isNotEmpty)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 10),
                                              child: Text(
                                                'Open advert',
                                                style: TextStyle(
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
