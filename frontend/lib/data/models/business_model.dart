import '../../domain/entities/business_entity.dart';
import '../../core/constants/api_constants.dart';

class BusinessModel extends BusinessEntity {
  const BusinessModel({
    required super.uuid,
    super.storeSlug,
    required super.businessName,
    required super.plan,
    required super.isActive,
    super.businessType,
    super.phone,
    super.email,
    super.address,
    super.city,
    super.state,
    super.pincode,
    super.gstin,
    super.logoUrl,
    super.bannerUrl,
    super.profileImageUrls,
    super.planExpiryDate,
    super.subscriptionType,
    super.upiId,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      uuid: json['uuid'] as String,
      storeSlug: json['store_slug'] as String?,
      businessName: json['business_name'] as String,
      plan: json['plan'] as String,
      isActive: json['is_active'] as bool? ?? true,
      businessType: json['business_type'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      gstin: json['gstin'] as String?,
      logoUrl: json['logo_url'] != null
          ? ApiConstants.fullUrl(json['logo_url'] as String)
          : null,
      bannerUrl: json['banner_url'] != null
          ? ApiConstants.fullUrl(json['banner_url'] as String)
          : null,
      profileImageUrls: (json['profile_image_urls'] as List<dynamic>?)
          ?.map((e) => ApiConstants.fullUrl(e as String))
          .toList(),
      planExpiryDate: json['plan_expiry_date'] != null
          ? DateTime.parse(json['plan_expiry_date'] as String)
          : null,
      subscriptionType: json['subscription_type'] as String?,
      upiId: json['upi_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'business_name': businessName,
      'plan': plan,
      'is_active': isActive,
      if (businessType != null) 'business_type': businessType,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (pincode != null) 'pincode': pincode,
      if (gstin != null) 'gstin': gstin,
      if (logoUrl != null) 'logo_url': logoUrl,
      if (bannerUrl != null) 'banner_url': bannerUrl,
      if (profileImageUrls != null) 'profile_image_urls': profileImageUrls,
      if (planExpiryDate != null)
        'plan_expiry_date': planExpiryDate!.toIso8601String(),
      if (upiId != null) 'upi_id': upiId,
    };
  }
}

class BusinessUpdateRequest {
  final String? businessType;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstin;
  final String? bannerUrl;
  final List<String>? profileImageUrls;
  final String? upiId;

  const BusinessUpdateRequest({
    this.businessType,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstin,
    this.bannerUrl,
    this.profileImageUrls,
    this.upiId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (businessType != null) data['business_type'] = businessType;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (address != null) data['address'] = address;
    if (city != null) data['city'] = city;
    if (state != null) data['state'] = state;
    if (pincode != null) data['pincode'] = pincode;
    if (gstin != null) data['gstin'] = gstin;
    if (bannerUrl != null) data['banner_url'] = bannerUrl;
    if (profileImageUrls != null) data['profile_image_urls'] = profileImageUrls;
    if (upiId != null) data['upi_id'] = upiId;
    return data;
  }
}
