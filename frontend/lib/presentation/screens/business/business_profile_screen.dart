import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';
import '../../../core/constants/api_constants.dart';
import 'business_edit_screen.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusinessProvider>(context, listen: false).loadProfile();
    });
  }

  String _imgUrl(String? path) {
    if (path == null) return '';
    return ApiConstants.fullUrl(path);
  }

  String _subTypeLabel(String sub) {
    switch (sub) {
      case 'monthly': return 'Monthly subscription';
      case 'yearly': return 'Yearly subscription';
      case 'trial': return 'Trial period';
      default: return sub;
    }
  }

  Future<void> _pickAndUploadBanner() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final success = await provider.uploadBanner(bytes, file.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Banner updated' : 'Upload failed: ${provider.error}'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 500, imageQuality: 85);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final success = await provider.uploadLogo(bytes, file.name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Logo updated' : 'Upload failed: ${provider.error}'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  Future<void> _pickAndUploadProfileImages(int currentCount) async {
    final remaining = 10 - currentCount;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 10 profile images reached')),
      );
      return;
    }

    final files = await _picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;

    final selected = files.take(remaining).toList();
    final List<Uint8List> bytes = [];
    final List<String> names = [];
    for (final f in selected) {
      bytes.add(await f.readAsBytes());
      names.add(f.name);
    }

    if (!mounted) return;
    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final success = await provider.uploadImages(bytes, names);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? '${bytes.length} image(s) uploaded'
            : 'Upload failed: ${provider.error}'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        actions: [
          Consumer<BusinessProvider>(
            builder: (context, provider, _) {
              if (provider.business != null) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BusinessEditScreen(),
                      ),
                    );
                    if (result == true) {
                      provider.loadProfile();
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<BusinessProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadProfile(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final business = provider.business;
          if (business == null) {
            return const Center(child: Text('No business profile found'));
          }

          final profileImages = business.profileImageUrls ?? [];

          return RefreshIndicator(
            onRefresh: () => provider.loadProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner Section ──────────────────────────────────────────
                  _BannerSection(
                    bannerUrl: _imgUrl(business.bannerUrl),
                    onUpload: _pickAndUploadBanner,
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Logo + Name ─────────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.blue.shade100,
                                    backgroundImage: business.logoUrl != null && business.logoUrl!.isNotEmpty
                                        ? NetworkImage(_imgUrl(business.logoUrl))
                                        : null,
                                    child: business.logoUrl == null || business.logoUrl!.isEmpty
                                        ? Text(
                                            business.businessName[0].toUpperCase(),
                                            style: const TextStyle(fontSize: 48),
                                          )
                                        : null,
                                  ),
                                  GestureDetector(
                                    onTap: _pickAndUploadLogo,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                business.businessName,
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Builder(builder: (ctx) {
                                final isPaid = business.plan == 'PAID' &&
                                    business.subscriptionType != 'trial';
                                final isTrial = business.plan == 'PAID' &&
                                    business.subscriptionType == 'trial';
                                final planLabel = isPaid
                                    ? '💎 PRO Plan'
                                    : isTrial
                                        ? '⏳ Trial'
                                        : '🆓 FREE Plan';
                                final planColor = isPaid
                                    ? Colors.green
                                    : isTrial
                                        ? Colors.purple
                                        : Colors.orange;
                                return Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: planColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        planLabel,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (business.subscriptionType != null &&
                                        business.plan == 'PAID') ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _subTypeLabel(business.subscriptionType!),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ],
                                    if (business.planExpiryDate != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Expires: ${DateFormat('MMM dd, yyyy').format(business.planExpiryDate!)}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: 200,
                                      child: ElevatedButton.icon(
                                        onPressed: () => context.push('/upgrade'),
                                        icon: Icon(
                                          isPaid ? Icons.manage_accounts : Icons.rocket_launch,
                                          size: 16,
                                        ),
                                        label: Text(isPaid ? 'Manage Plan' : 'Explore PRO'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isPaid ? Colors.green.shade700 : Colors.deepOrange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Profile Images Section ──────────────────────────
                        _ProfileImagesSection(
                          imageUrls: profileImages.map((u) => _imgUrl(u)).toList(),
                          onAdd: () => _pickAndUploadProfileImages(profileImages.length),
                        ),
                        const SizedBox(height: 16),

                        // ── Contact Info ────────────────────────────────────
                        _buildInfoCard(
                          context,
                          'Contact Information',
                          [
                            if (business.phone != null)
                              _buildInfoRow(Icons.phone, 'Phone', business.phone!),
                            if (business.email != null)
                              _buildInfoRow(Icons.email, 'Email', business.email!),
                            if (business.upiId != null)
                              _buildInfoRow(Icons.payment, 'UPI ID', business.upiId!),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          context,
                          'Business Details',
                          [
                            if (business.businessType != null)
                              _buildInfoRow(Icons.business, 'Type', business.businessType!),
                            if (business.gstin != null)
                              _buildInfoRow(Icons.receipt, 'GSTIN', business.gstin!),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          context,
                          'Address',
                          [
                            if (business.address != null)
                              _buildInfoRow(Icons.location_on, 'Street', business.address!),
                            if (business.city != null)
                              _buildInfoRow(Icons.location_city, 'City', business.city!),
                            if (business.state != null)
                              _buildInfoRow(Icons.map, 'State', business.state!),
                            if (business.pincode != null)
                              _buildInfoRow(Icons.pin_drop, 'Pincode', business.pincode!),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // ── Danger Zone ─────────────────────────────────────
                        OutlinedButton.icon(
                          onPressed: () => _confirmDeleteAccount(context),
                          icon: const Icon(Icons.delete_forever, color: Colors.red),
                          label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your business account and all associated data. This action cannot be undone.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await provider.deleteAccount();

    if (!mounted) return;
    if (success) {
      await authProvider.logout();
      if (!mounted) return;
      context.go('/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.error ?? 'Failed to delete account'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildInfoCard(BuildContext context, String title, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Banner Section
// ─────────────────────────────────────────────────────────────
class _BannerSection extends StatelessWidget {
  final String bannerUrl;
  final VoidCallback onUpload;

  const _BannerSection({required this.bannerUrl, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: double.infinity,
          height: 180,
          color: Colors.grey.shade200,
          child: bannerUrl.isNotEmpty
              ? Image.network(bannerUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)))
              : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.panorama, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No banner image', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add_photo_alternate, size: 16),
            label: Text(bannerUrl.isNotEmpty ? 'Change Banner' : 'Add Banner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Profile Images Section
// ─────────────────────────────────────────────────────────────
class _ProfileImagesSection extends StatelessWidget {
  final List<String> imageUrls;
  final VoidCallback onAdd;

  const _ProfileImagesSection({required this.imageUrls, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final canAdd = imageUrls.length < 10;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Store Photos (${imageUrls.length}/10)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (canAdd)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_photo_alternate, size: 16),
                    label: const Text('Add Photos'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrls.isEmpty)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate, size: 32, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Tap to add store photos', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ...imageUrls.map((url) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    )),
                    if (canAdd)
                      GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Icon(Icons.add_photo_alternate, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
