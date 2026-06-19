class BusinessEntity {
  final String uuid;
  final String? storeSlug;
  final String businessName;
  final String plan;
  final bool isActive;
  final String? businessType;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstin;
  final String? logoUrl;
  final String? bannerUrl;
  final List<String>? profileImageUrls;
  final DateTime? planExpiryDate;
  final String? subscriptionType; // "monthly" | "yearly"
  final String? upiId;

  const BusinessEntity({
    required this.uuid,
    this.storeSlug,
    required this.businessName,
    required this.plan,
    required this.isActive,
    this.businessType,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstin,
    this.logoUrl,
    this.bannerUrl,
    this.profileImageUrls,
    this.planExpiryDate,
    this.subscriptionType,
    this.upiId,
  });
}
