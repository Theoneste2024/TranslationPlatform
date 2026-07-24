import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offline_provider.dart';
import '../../core/constants/languages.dart';

class OfflinePacksScreen extends StatefulWidget {
  const OfflinePacksScreen({super.key});

  @override
  State<OfflinePacksScreen> createState() => _OfflinePacksScreenState();
}

class _OfflinePacksScreenState extends State<OfflinePacksScreen> {
  final List<OfflinePack> _availablePacks = [
    OfflinePack(
      id: 'basic_rw',
      name: 'Basic Kinyarwanda Pack',
      description: 'Essential phrases and common vocabulary',
      size: '15 MB',
      languages: ['rw', 'en'],
      isFree: true,
      icon: Icons.translate,
    ),
    OfflinePack(
      id: 'complete_rw',
      name: 'Complete Kinyarwanda Pack',
      description: 'Full Kinyarwanda-English-French dictionary',
      size: '85 MB',
      languages: ['rw', 'en', 'fr'],
      isFree: true, // Temporarily set to true to avoid payment
      price: 5000, // RWF (commented out but kept for future)
      icon: Icons.translate,
    ),
    OfflinePack(
      id: 'motorist_rw',
      name: 'Motorist Communication Pack',
      description: 'Transportation and navigation phrases',
      size: '25 MB',
      languages: ['rw', 'en'],
      isFree: true,
      icon: Icons.motorcycle,
    ),
    OfflinePack(
      id: 'medical_rw',
      name: 'Medical & Emergency Pack',
      description: 'Healthcare and emergency vocabulary',
      size: '35 MB',
      languages: ['rw', 'en', 'fr'],
      isFree: true, // Temporarily set to true to avoid payment
      price: 3000, // RWF
      icon: Icons.local_hospital,
    ),
    OfflinePack(
      id: 'education_rw',
      name: 'Education Pack',
      description: 'Academic vocabulary and terminology',
      size: '45 MB',
      languages: ['rw', 'en', 'fr'],
      isFree: true, // Temporarily set to true to avoid payment
      price: 4000, // RWF
      icon: Icons.school,
    ),
    OfflinePack(
      id: 'tourism_rw',
      name: 'Tourism & Hospitality Pack',
      description: 'Tourist phrases and service vocabulary',
      size: '30 MB',
      languages: ['rw', 'en', 'fr', 'sw'],
      isFree: true, // Temporarily set to true to avoid payment
      price: 3500, // RWF
      icon: Icons.tour,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final offlineProvider = Provider.of<OfflineProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Translation Packs'),
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.downloading),
                onPressed: () {
                  // Show active downloads
                },
              ),
              if (offlineProvider.activeDownloads > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${offlineProvider.activeDownloads}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Storage Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Icon(Icons.storage, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Device Storage',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 0.45,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '245 MB used • 2.1 GB free',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Downloaded Packs Summary
          if (offlineProvider.downloadedPacks.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Packs',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Show all downloaded packs
                    },
                    child: const Text('View All'),
                  ),
                ],
              ),
            ),

          // Packs List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _availablePacks.length,
              itemBuilder: (context, index) {
                final pack = _availablePacks[index];
                final isDownloaded = offlineProvider.isPackDownloaded(pack.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                pack.icon,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pack.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    pack.description,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.sd_storage,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pack.size,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 16),
                            ...pack.languages.map((code) {
                              final language = Languages.africanLanguages
                                  .firstWhere((l) => l.code == code);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      language.flagEmoji,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      code.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Price tag - hidden if free
                            if (!pack.isFree)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${pack.price} RWF',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified,
                                      size: 14,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Free',
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Download button
                            if (isDownloaded)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Downloaded',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () {
                                  _downloadPack(context, pack);
                                },
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text(
                                  'Download', // All packs are free now
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
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
    );
  }

  // ✅ DOWNLOAD PACK - FIXED with pack.id
  void _downloadPack(BuildContext context, OfflinePack pack) {
    final offlineProvider = Provider.of<OfflineProvider>(
      context,
      listen: false,
    );

    // ✅ All packs are free for now - payment code commented out
    // if (!pack.isFree) {
    //   _showPaymentDialog(context, pack);
    // } else {
    // Start free download
    offlineProvider.downloadPack(pack.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${pack.name}...'),
        backgroundColor: Theme.of(context).primaryColor,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.white,
          onPressed: () {
            offlineProvider.cancelDownload(pack.id);
          },
        ),
      ),
    );
    // }
  }

  // 💰 PAYMENT METHODS - COMMENTED OUT FOR NOW
  /*
  void _showPaymentDialog(BuildContext context, OfflinePack pack) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchase Offline Pack',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are purchasing: ${pack.name}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Price: ${pack.price} RWF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Payment Method',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              'MTN Mobile Money',
              'assets/icons/mtn.png',
              () {
                Navigator.pop(context);
                _processPayment(context, pack, 'MTN');
              },
            ),
            _buildPaymentOption(
              'Airtel Money',
              'assets/icons/airtel.png',
              () {
                Navigator.pop(context);
                _processPayment(context, pack, 'Airtel');
              },
            ),
            _buildPaymentOption(
              'Credit/Debit Card',
              'assets/icons/card.png',
              () {
                Navigator.pop(context);
                _processPayment(context, pack, 'Card');
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String name, String iconPath, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            name.substring(0, 1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      title: Text(name),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _processPayment(BuildContext context, OfflinePack pack, String method) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing payment...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      
      final offlineProvider = Provider.of<OfflineProvider>(
        context,
        listen: false,
      );
      
      // ✅ FIXED: Using pack.id instead of pack
      offlineProvider.downloadPack(pack.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment successful! Downloading ${pack.name}...'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }
  */
}

class OfflinePack {
  final String id;
  final String name;
  final String description;
  final String size;
  final List<String> languages;
  final bool isFree;
  final int? price;
  final IconData icon;

  OfflinePack({
    required this.id,
    required this.name,
    required this.description,
    required this.size,
    required this.languages,
    required this.isFree,
    this.price,
    required this.icon,
  });
}
