import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/supabase_service.dart';

class ProducerMarketRepository {
  ProducerMarketRepository._();
  static final instance = ProducerMarketRepository._();
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<Map<String, dynamic>> bootstrap() async =>
      Map<String, dynamic>.from(await _supabase.rpc('get_producers_market_season') as Map);

  Future<Map<String, dynamic>> reelQuota() async =>
      Map<String, dynamic>.from(await _supabase.rpc('get_my_reel_quota') as Map);

  Future<Map<String, dynamic>> tenderQuota() async =>
      Map<String, dynamic>.from(await _supabase.rpc('get_my_tender_quota') as Map);

  Future<List<Map<String, dynamic>>> reels() async {
    final rows = await _supabase.rpc('get_producer_reels_feed', params: {'p_limit': 100});
    return _dedupeById(List<Map<String, dynamic>>.from(rows));
  }

  List<Map<String, dynamic>> _dedupeById(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    return rows.where((row) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) return false;
      return seen.add(id);
    }).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> sectors() async {
    final rows = await _supabase.from('garment_sectors').select('sector_key,name_ar,is_active').eq('is_active', true).order('name_ar');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, String>> profiles(List<String> ids) async {
    if (ids.isEmpty) return {};
    final raw = await _supabase.rpc('get_producer_reel_owners', params: {'p_user_ids': ids});
    final result = <String, String>{};
    for (final row in List<Map<String, dynamic>>.from(raw as List)) {
      final name = (row['username'] ?? row['display_name'] ?? 'منتج أزياء').toString().trim();
      result[row['id'].toString()] = name.isEmpty ? 'منتج أزياء' : name;
    }
    return result;
  }

  Future<Set<String>> myInteractions(List<String> ids, String table) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || ids.isEmpty) return {};
    final rows = await _supabase.from(table).select('reel_id').eq('user_id', uid).inFilter('reel_id', ids);
    return rows.map<String>((e) => e['reel_id'].toString()).toSet();
  }

  Future<String> mediaUrl({required String kind, required String id, String variant = 'video', String purpose = 'play', String? path, String? filename}) async {
    if (path != null && path.startsWith('http')) return path;
    final response = await _supabase.functions.invoke('producer-media-url', body: {
      'kind': kind,
      'id': id,
      'variant': variant,
      'purpose': purpose,
      if (path != null) 'path': path,
      if (filename != null) 'filename': filename,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final url = data['url']?.toString();
    if (url == null || url.isEmpty) throw Exception(data['error'] ?? 'تعذر تجهيز رابط الوسائط');
    return url;
  }

  Future<PlatformFile?> pickVideo() async =>
      (await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'webm', 'mov'],
        allowMultiple: false,
        withData: kIsWeb,
      ))?.files.single;

  Future<PlatformFile?> pickImage() async =>
      (await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
        allowMultiple: false,
        withData: kIsWeb,
      ))?.files.single;

  Future<PlatformFile?> pickAttachment() async =>
      (await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'doc',
          'docx',
          'xls',
          'xlsx',
        ],
        allowMultiple: false,
        withData: kIsWeb,
      ))?.files.single;

  Future<String> uploadReelVideo(PlatformFile file) async {
    final extension = (file.extension ?? '').toLowerCase();
    if (!const {'mp4', 'webm', 'mov'}.contains(extension)) {
      throw Exception('صيغة الفيديو يجب أن تكون MP4 أو WebM أو MOV');
    }
    return uploadBytes(folder: 'reels', file: file, extension: extension);
  }

  Future<String> uploadReelCover(PlatformFile file) async {
    final extension = (file.extension ?? '').toLowerCase();
    if (!const {'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(extension)) {
      throw Exception('صيغة الغلاف يجب أن تكون PNG أو JPG أو JPEG أو WEBP أو GIF');
    }
    return uploadBytes(folder: 'reels', file: file, extension: extension);
  }

  Future<String> uploadBytes({required String folder, required PlatformFile file, required String extension}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('AUTH_REQUIRED');
    final normalizedExtension = extension.toLowerCase();
    if (folder == 'reels' && !const {'mp4', 'webm', 'mov', 'png', 'jpg', 'jpeg', 'webp', 'gif'}.contains(normalizedExtension)) {
      throw Exception('صيغة ملف الريلز غير مدعومة');
    }
    final fileId = _uuid.v4();
    final path = '$folder/$uid/$fileId.$normalizedExtension';
    Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      bytes = await file.xFile.readAsBytes();
    }
    if (bytes.isEmpty) throw Exception('الملف فارغ');
    if (bytes.length > 100 * 1024 * 1024) throw Exception('الملف يتجاوز الحد 100MB');
    final stored = await SupabaseService.uploadBytesToBucket(
      bucket: 'producer-market-media',
      path: path,
      bytes: bytes,
      contentType: _mimeFor(extension),
      upsert: false,
      fileName: file.name,
    );
    return 'storage://producer-market-media/$stored';
  }

  String _mimeFor(String ext) => switch (ext.toLowerCase()) {
        'mp4' => 'video/mp4',
        'webm' => 'video/webm',
        'mov' => 'video/quicktime',
        'gif' => 'image/gif',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xls' => 'application/vnd.ms-excel',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _ => 'image/jpeg',
      };

  Future<List<Map<String, dynamic>>> garmentServiceAds({String? sectorKey}) async =>
      List<Map<String, dynamic>>.from(await _supabase.rpc('get_garment_service_ads', params: {'p_sector_key': sectorKey}));

  Future<Map<String, dynamic>> publishGarmentServiceAd({
    required String serviceKey,
    required String sectorKey,
    required String title,
    required String description,
    int? priceMinorUnits,
    String currency = 'sham_cash',
    String? unit,
    int? minQty,
    String? city,
    String? address,
    String? phone,
    String? whatsapp,
    List<String> images = const [],
    Map<String, dynamic> specs = const {},
    String publicationCurrency = 'points',
  }) async => Map<String, dynamic>.from(await _supabase.rpc('publish_garment_service_ad', params: {
    'p_service_key': serviceKey,
    'p_sector_key': sectorKey,
    'p_title': title,
    'p_description': description,
    'p_price_minor_units': priceMinorUnits,
    'p_currency': currency,
    'p_unit': unit,
    'p_min_qty': minQty,
    'p_city': city,
    'p_address': address,
    'p_phone': phone,
    'p_whatsapp': whatsapp,
    'p_images': images,
    'p_specs': specs,
    'p_publication_currency': publicationCurrency,
    'p_request_id': _uuid.v4(),
  }) as Map);

  Future<Map<String, dynamic>> setGarmentServiceAdStatus(String adId, String status) async =>
      Map<String, dynamic>.from(await _supabase.rpc('admin_set_garment_service_ad_status', params: {'p_ad_id': adId, 'p_status': status}) as Map);

  Future<String> uploadGarmentServiceImage(PlatformFile file) async {
    final ext = (file.extension ?? '').toLowerCase();
    if (!const {'png','jpg','jpeg','webp'}.contains(ext)) throw Exception('INVALID_IMAGE');
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (bytes.isEmpty || bytes.length > 6 * 1024 * 1024) throw Exception('INVALID_IMAGE_SIZE');
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('AUTH_REQUIRED');
    final storedPath = '$uid/${_uuid.v4()}.$ext';
    return SupabaseService.uploadBytesToBucket(bucket: 'garment-service-media', path: storedPath, bytes: bytes, contentType: _mimeFor(ext), upsert: false, fileName: file.name);
  }

  Future<Map<String, dynamic>> publishReel({required String title, required String description, required int duration, required String? videoPath, required String? coverPath, required bool allowDownload, required String sector, String? priceLabel, String? city, List<String> tags = const [], String publicationCurrency = 'points'}) async {
    final result = await _supabase.rpc('publish_producer_reel_paid', params: {
      'p_title': title,
      'p_video_url': videoPath,
      'p_duration_seconds': duration,
      'p_description': description,
      'p_thumbnail_url': coverPath,
      'p_sector_key': sector,
      'p_price_minor_units': priceLabel == null ? null : int.tryParse(priceLabel),
      'p_city': city,
      'p_tags': tags,
      'p_allow_download': allowDownload,
      'p_publication_currency': publicationCurrency,
      'p_request_id': _uuid.v4(),
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> interact(String reelId, String action) async => Map<String, dynamic>.from(await _supabase.rpc('reel_interact', params: {'p_reel_id': reelId, 'p_action': action}) as Map);
  Future<Map<String, dynamic>> addComment(String reelId, String body, {String? replyTo}) async => Map<String, dynamic>.from(await _supabase.rpc('add_reel_comment', params: {'p_reel_id': reelId, 'p_body': body, 'p_reply_to': replyTo}) as Map);

  Future<List<Map<String, dynamic>>> comments(String reelId) async {
    final rows = await _supabase.from('reel_comments').select('id,reel_id,user_id,body,reply_to_id,is_hidden,created_at').eq('reel_id', reelId).eq('is_hidden', false).order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> allReelsForAdmin() async {
    final rows = await _supabase.from('producer_reels').select('id,owner_uid,title,description,video_url,thumbnail_url,duration_seconds,price_minor_units,currency,city,tags,allow_download,is_pinned,is_published,is_blocked,is_featured,promotion_score,views_count,likes_count,comments_count,shares_count,saves_count,created_at').order('created_at', ascending: false).limit(250);
    return _dedupeById(List<Map<String, dynamic>>.from(rows));
  }

  Future<List<Map<String, dynamic>>> allTendersForAdmin({String? scope}) async {
    var query = _supabase.from('tenders').select('id,owner_uid,scope,title,description,sector_key,quantity,unit,budget_min_minor_units,budget_max_minor_units,currency,city,target_country,incoterm,shipping_method,customs_handled_by,payment_terms,required_certificates,packaging_requirements,sample_required,attachments,images,specs,deadline_at,delivery_deadline_at,status,awarded_bid_id,bids_count,views_count,is_blocked,created_at');
    if (scope != null) query = query.eq('scope', scope);
    final rows = await query.order('created_at', ascending: false).limit(250);
    return _dedupeById(List<Map<String, dynamic>>.from(rows));
  }

  Future<List<Map<String, dynamic>>> tenders({required String scope}) async {
    final rows = await _supabase.from('tenders').select('id,owner_uid,scope,title,description,sector_key,quantity,unit,budget_min_minor_units,budget_max_minor_units,currency,city,target_country,incoterm,shipping_method,customs_handled_by,payment_terms,required_certificates,packaging_requirements,sample_required,attachments,images,specs,deadline_at,delivery_deadline_at,status,awarded_bid_id,bids_count,views_count,is_blocked,created_at').eq('scope', scope).neq('is_blocked', true).neq('status', 'draft').order('created_at', ascending: false).limit(100);
    return _dedupeById(List<Map<String, dynamic>>.from(rows));
  }

  Future<List<Map<String, dynamic>>> bids(String tenderId) async {
    final rows = await _supabase.from('tender_bids').select('id,tender_id,bidder_uid,business_id,price_minor_units,currency,delivery_days,notes,attachments,status,created_at,updated_at').eq('tender_id', tenderId).order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> publishTender({required String scope, required String title, required String description, required String sector, required int? quantity, required String unit, required int? budgetMin, required int? budgetMax, required String? city, required String? country, required String? incoterm, required String? shipping, required String? customs, required String? payment, required List<String> certificates, required String? packaging, required bool sample, required String? sampleDetails, required String? technicalSpecs, required DateTime? deadline, required DateTime? deliveryDeadline, String publicationCurrency = 'points'}) async => Map<String, dynamic>.from(await _supabase.rpc('publish_tender', params: {
    'p_title': title, 'p_description': description, 'p_scope': scope, 'p_sector_key': sector, 'p_quantity': quantity, 'p_unit': unit,
    'p_budget_min': budgetMin, 'p_budget_max': budgetMax, 'p_city': city, 'p_target_country': country, 'p_incoterm': incoterm,
    'p_shipping_method': shipping, 'p_customs_handled_by': customs, 'p_payment_terms': payment, 'p_required_certificates': certificates,
    'p_packaging_requirements': packaging, 'p_sample_required': sample, 'p_attachments': [], 'p_images': [], 'p_specs': {'sample_details': sampleDetails, 'technical': technicalSpecs, 'publication_request_id': _uuid.v4(), 'publication_currency': publicationCurrency},
    'p_deadline_at': deadline?.toUtc().toIso8601String(), 'p_delivery_deadline_at': deliveryDeadline?.toUtc().toIso8601String(),
  }) as Map);

  Future<Map<String, dynamic>> submitBid({required String tenderId, required int price, required int? deliveryDays, required String? notes}) async => Map<String, dynamic>.from(await _supabase.rpc('submit_tender_bid', params: {
    'p_tender_id': tenderId, 'p_price_minor_units': price, 'p_delivery_days': deliveryDays, 'p_notes': notes, 'p_business_id': null, 'p_attachments': [],
  }) as Map);
  Future<Map<String, dynamic>> awardTender(String tenderId, String bidId) async => Map<String, dynamic>.from(await _supabase.rpc('award_tender', params: {'p_tender_id': tenderId, 'p_bid_id': bidId}) as Map);
  Future<Map<String, dynamic>> updateTender(String tenderId, Map<String, dynamic> values) async => Map<String, dynamic>.from(await _supabase.rpc('update_tender', params: {
    'p_tender_id': tenderId,
    'p_patch': values,
  }) as Map);

  Future<Map<String, dynamic>> setTenderStatus(String tenderId, String status) async => Map<String, dynamic>.from(await _supabase.rpc('set_tender_status', params: {
    'p_tender_id': tenderId,
    'p_status': status,
  }) as Map);

  Future<Map<String, dynamic>> setTenderBlocked(String tenderId, bool blocked) async => Map<String, dynamic>.from(await _supabase.rpc('set_tender_blocked', params: {
    'p_tender_id': tenderId,
    'p_blocked': blocked,
  }) as Map);

  Future<Map<String, dynamic>> setReelBlocked(String reelId, bool blocked) async => Map<String, dynamic>.from(await _supabase.rpc('set_producer_reel_blocked', params: {
    'p_reel_id': reelId,
    'p_blocked': blocked,
  }) as Map);

  Future<Map<String, dynamic>> setReelPinned(String reelId, bool pinned) async => Map<String, dynamic>.from(await _supabase.rpc('set_producer_reel_pinned', params: {
    'p_reel_id': reelId,
    'p_pinned': pinned,
  }) as Map);

  Future<Map<String, dynamic>> deleteReel(String reelId) async => Map<String, dynamic>.from(await _supabase.rpc('delete_producer_reel', params: {'p_reel_id': reelId}) as Map);

  Future<List<Map<String, dynamic>>> myReels() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('AUTH_REQUIRED');
    final rows = await _supabase
        .from('producer_reels')
        .select(
          'id,owner_uid,business_id,product_id,sector_key,title,description,'
          'video_url,thumbnail_url,duration_seconds,price_minor_units,currency,'
          'city,tags,allow_download,is_pinned,is_published,is_blocked,'
          'views_count,likes_count,comments_count,shares_count,saves_count,'
          'created_at,updated_at,promotion_score,is_featured',
        )
        .eq('owner_uid', uid)
        .order('created_at', ascending: false);
    return _dedupeById(List<Map<String, dynamic>>.from(rows));
  }

  Future<Map<String, dynamic>> updateReel({
    required String reelId,
    required String title,
    String? description,
    String? videoUrl,
    required int durationSeconds,
    String? thumbnailUrl,
    String? sectorKey,
    int? priceMinorUnits,
    String? city,
    List<String> tags = const [],
    required bool allowDownload,
  }) async =>
      Map<String, dynamic>.from(
        await _supabase.rpc('update_producer_reel', params: {
          'p_reel_id': reelId,
          'p_title': title,
          'p_description': description,
          'p_video_url': videoUrl,
          'p_duration_seconds': durationSeconds,
          'p_thumbnail_url': thumbnailUrl,
          'p_sector_key': sectorKey,
          'p_price_minor_units': priceMinorUnits,
          'p_city': city,
          'p_tags': tags,
          'p_allow_download': allowDownload,
        }) as Map,
      );

  Future<Map<String, dynamic>> setReelPublished(
    String reelId,
    bool published,
  ) async =>
      Map<String, dynamic>.from(
        await _supabase.rpc('set_producer_reel_published', params: {
          'p_reel_id': reelId,
          'p_is_published': published,
        }) as Map,
      );
  Future<Map<String, dynamic>> deleteTender(String tenderId) async => Map<String, dynamic>.from(await _supabase.rpc('delete_tender', params: {'p_tender_id': tenderId}) as Map);

  Future<List<Map<String, dynamic>>> reelRules() async => List<Map<String, dynamic>>.from(await _supabase.from('reel_membership_quotas').select('*').order('tier_id'));
  Future<List<Map<String, dynamic>>> tenderRules() async => List<Map<String, dynamic>>.from(await _supabase.from('tender_membership_quotas').select('*').order('tier_id'));

  Future<Map<String, dynamic>> updateReelRule(Map<String, dynamic> row) async => Map<String, dynamic>.from(await _supabase.rpc('update_reel_membership_quota', params: {
    'p_tier_id': row['tier_id'],
    'p_reels_per_month': row['reels_per_month'],
    'p_max_duration_seconds': row['max_duration_seconds'],
    'p_publish_cost_points': row['publish_cost_points'],
    'p_publish_cost_gems': row['publish_cost_gems'],
    'p_can_pin': row['can_pin'] == true,
    'p_allow_download': row['allow_download'] != false,
    'p_is_enabled': row['is_enabled'] != false,
  }) as Map);

  Future<Map<String, dynamic>> updateTenderRule(Map<String, dynamic> row) async => Map<String, dynamic>.from(await _supabase.rpc('update_tender_membership_quota', params: {
    'p_tier_id': row['tier_id'],
    'p_tenders_per_month': row['tenders_per_month'],
    'p_external_per_month': row['external_per_month'],
    'p_bids_per_month': row['bids_per_month'],
    'p_can_publish_external': row['can_publish_external'] == true,
    'p_publish_cost_points': row['publish_cost_points'],
    'p_publish_cost_gems': row['publish_cost_gems'] ?? 0,
    'p_is_enabled': row['is_enabled'] != false,
  }) as Map);

  Future<void> updateSeason(Map<String, dynamic> data) async => _supabase.rpc('set_producers_market_season', params: data);

  Future<Map<String, dynamic>> updateOwnerReelControl({
    required String reelId,
    required String title,
    String? description,
    String? videoUrl,
    required int durationSeconds,
    String? thumbnailUrl,
    String? sectorKey,
    int? priceMinorUnits,
    String? city,
    List<String> tags = const [],
    required bool allowDownload,
    required bool published,
    required bool blocked,
    required bool pinned,
    required bool featured,
    required int promotionScore,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('admin_update_producer_reel_control', params: {
    'p_reel_id': reelId,
    'p_title': title,
    'p_description': description,
    'p_video_url': videoUrl,
    'p_duration_seconds': durationSeconds,
    'p_thumbnail_url': thumbnailUrl,
    'p_sector_key': sectorKey,
    'p_price_minor_units': priceMinorUnits,
    'p_city': city,
    'p_tags': tags,
    'p_allow_download': allowDownload,
    'p_is_published': published,
    'p_is_blocked': blocked,
    'p_is_pinned': pinned,
    'p_is_featured': featured,
    'p_promotion_score': promotionScore,
  }) as Map);

  Future<List<Map<String, dynamic>>> wallpapers() async => List<Map<String, dynamic>>.from(await _supabase.rpc('get_chat_wallpaper_catalog', params: {'p_scope': 'both'}));

  Future<Map<String, dynamic>> upsertWallpaper({
    required String key,
    required String nameAr,
    required String scope,
    required String kind,
    String? color1,
    String? color2,
    String? imageUrl,
    required bool premium,
    required int pricePoints,
    required bool active,
    required int sortOrder,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('admin_upsert_chat_wallpaper', params: {
    'p_wallpaper_key': key,
    'p_name_ar': nameAr,
    'p_scope': scope,
    'p_kind': kind,
    'p_color1': color1,
    'p_color2': color2,
    'p_image_url': imageUrl,
    'p_is_premium': premium,
    'p_price_points': pricePoints,
    'p_is_active': active,
    'p_sort_order': sortOrder,
  }) as Map);

  Future<Map<String, dynamic>> deleteWallpaper(String key) async => Map<String, dynamic>.from(await _supabase.rpc('admin_delete_chat_wallpaper', params: {'p_wallpaper_key': key}) as Map);

  Future<String> uploadChatWallpaper(PlatformFile file) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('AUTH_REQUIRED');
    final ext = (file.extension ?? '').toLowerCase();
    if (!const {'png','jpg','jpeg','webp'}.contains(ext)) throw Exception('INVALID_IMAGE');
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (bytes.isEmpty) throw Exception('INVALID_IMAGE');
    if (bytes.length > 6 * 1024 * 1024) throw Exception('IMAGE_TOO_LARGE');
    final path = 'catalog/$uid/${_uuid.v4()}.$ext';
    await _supabase.storage.from('chat-wallpapers').uploadBinary(path, bytes, fileOptions: FileOptions(upsert: false, contentType: _mimeFor(ext)));
    return _supabase.storage.from('chat-wallpapers').getPublicUrl(path);
  }


  Future<List<Map<String, dynamic>>> garmentServiceCatalog() async =>
      List<Map<String, dynamic>>.from(await _supabase.rpc('get_garment_service_catalog'));

  Future<List<Map<String, dynamic>>> garmentPublishedServices({String? sectorKey}) async =>
      List<Map<String, dynamic>>.from(await _supabase.rpc('get_garment_published_services', params: {'p_sector_key': sectorKey}));

  Future<List<Map<String, dynamic>>> garmentDirectory({
    String? sectorKey,
    String? city,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async =>
      List<Map<String, dynamic>>.from(
        await _supabase.rpc(
          'browse_garment_directory',
          params: {
            'p_sector_key': sectorKey,
            'p_city': city,
            'p_search': search,
            'p_limit': limit,
            'p_offset': offset,
          },
        ),
      );

  Future<List<Map<String, dynamic>>> myGarmentBusinesses() async =>
      List<Map<String, dynamic>>.from(await _supabase.rpc('get_my_garment_businesses'));

  Future<List<Map<String, dynamic>>> garmentPublicationFees() async =>
      List<Map<String, dynamic>>.from(await _supabase.rpc('get_garment_publication_fees'));

  Future<Map<String, dynamic>> upsertGarmentService({
    String? id,
    required String businessId,
    required String title,
    String? description,
    required String sectorKey,
    int? priceMinorUnits,
    String? unit,
    int? minQty,
    bool published = false,
    required String publicationCurrency,
  }) async {
    final requestId = _uuid.v4();
    return Map<String, dynamic>.from(await _supabase.rpc('upsert_garment_product', params: {
      'p_id': id,
      'p_business_id': businessId,
      'p_title': title,
      'p_description': description,
      'p_sector_key': sectorKey,
      'p_price_minor_units': priceMinorUnits,
      'p_unit': unit,
      'p_min_qty': minQty,
      'p_images': [],
      'p_specs': {
        'publication_request_id': requestId,
        'publication_currency': publicationCurrency,
      },
      'p_is_service': true,
      'p_is_published': published,
    }) as Map);
  }

  Future<Map<String, dynamic>> upsertGarmentBusiness({
    String? id,
    required String businessName,
    required String sectorKey,
    String? description,
    String? city,
    String? address,
    String? phone,
    String? whatsapp,
    String? logoUrl,
    String? coverUrl,
    List<dynamic> gallery = const [],
    int? minOrderQty,
    int? capacityPerMonth,
    int? establishedYear,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('upsert_garment_business', params: {
    'p_id': id,
    'p_business_name': businessName,
    'p_sector_key': sectorKey,
    'p_description': description,
    'p_city': city,
    'p_address': address,
    'p_phone': phone,
    'p_whatsapp': whatsapp,
    'p_logo_url': logoUrl,
    'p_cover_url': coverUrl,
    'p_gallery': gallery,
    'p_min_order_qty': minOrderQty,
    'p_capacity_per_month': capacityPerMonth,
    'p_established_year': establishedYear,
    'p_is_published': false,
  }) as Map);

  Future<Map<String, dynamic>> publishGarmentBusiness({
    required String businessId,
    required String publicationCurrency,
    required String requestId,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('publish_garment_business', params: {
    'p_business_id': businessId,
    'p_currency': publicationCurrency,
    'p_request_id': requestId,
  }) as Map);

  Future<Map<String, dynamic>> adminUpsertGarmentServiceCatalog({
    required String serviceKey,
    required String sectorKey,
    required String nameAr,
    required String descriptionAr,
    required String iconKey,
    required bool active,
    required int sortOrder,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('admin_upsert_garment_service_catalog', params: {
    'p_service_key': serviceKey,
    'p_sector_key': sectorKey,
    'p_name_ar': nameAr,
    'p_description_ar': descriptionAr,
    'p_icon_key': iconKey,
    'p_is_active': active,
    'p_sort_order': sortOrder,
  }) as Map);

  Future<Map<String, dynamic>> adminUpsertGarmentPublicationFee({
    required String contentType,
    required int pointsCost,
    required int gemsCost,
    required bool enabled,
  }) async => Map<String, dynamic>.from(await _supabase.rpc('admin_upsert_garment_publication_fee', params: {
    'p_content_type': contentType,
    'p_points_cost': pointsCost,
    'p_gems_cost': gemsCost,
    'p_is_enabled': enabled,
  }) as Map);

  Future<String> uploadSeasonAsset(PlatformFile file, {required bool gif}) async {
    final ext = (file.extension ?? (gif ? 'gif' : 'jpg')).toLowerCase();
    final id = _uuid.v4();
    final path = 'season/$id.$ext';
    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    await _supabase.storage.from('producer-market-media').uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: _mimeFor(ext)));
    return 'storage://producer-market-media/$path';
  }
}