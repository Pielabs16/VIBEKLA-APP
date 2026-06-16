// ─── Capabilities ─────────────────────────────────────────────────────────────
// Flat capability set returned by GET /api/auth/capabilities. The backend is the
// single authority on what a role may do (see role_capabilities() in config.php),
// so the app never hardcodes role-name logic — it reads these flags. A role-derived
// fallback keeps the UI functional before/if the capabilities call fails.

class Capabilities {
  final String role;
  final Map<String, bool> _flags;

  const Capabilities(this.role, this._flags);

  bool has(String key) => _flags[key] ?? false;

  // Every authenticated user
  bool get canRate            => has('canRate');
  bool get canCheckin         => has('canCheckin');
  bool get canBook            => has('canBook');
  bool get canReserve         => has('canReserve');
  bool get canViewOwnBookings => has('canViewOwnBookings');
  bool get canViewOwnRatings  => has('canViewOwnRatings');
  // Owner / admin
  bool get canManageVenue        => has('canManageVenue');
  bool get canManageEvents       => has('canManageEvents');
  bool get canViewVenueBookings  => has('canViewVenueBookings');
  bool get canViewVenueGuests    => has('canViewVenueGuests');
  bool get canManageReservations => has('canManageReservations');
  bool get canBulkManage         => has('canBulkManage');
  bool get canExportData         => has('canExportData');
  bool get canManageSubscription => has('canManageSubscription');
  bool get canViewAnalytics      => has('canViewAnalytics');
  // Admin / staff
  bool get canAccessAdminPanel => has('canAccessAdminPanel');
  bool get canModerateContent  => has('canModerateContent');
  bool get canManageUsers      => has('canManageUsers');

  factory Capabilities.fromJson(Map<String, dynamic> json) {
    final raw = json['capabilities'];
    final flags = <String, bool>{};
    if (raw is Map) {
      raw.forEach((k, v) => flags[k.toString()] = v == true);
    }
    return Capabilities(json['role'] as String? ?? 'user', flags);
  }

  // Mirrors backend role_capabilities() so the UI degrades gracefully offline.
  factory Capabilities.fromRole(String role) {
    final owner = role == 'venue_owner' || role == 'admin' || role == 'super_admin';
    final staff = role == 'admin' ||
        role == 'super_admin' ||
        role == 'operations' ||
        role == 'auditor';
    return Capabilities(role, {
      'canRate': true,
      'canCheckin': true,
      'canBook': true,
      'canReserve': true,
      'canViewOwnBookings': true,
      'canViewOwnRatings': true,
      'canManageVenue': owner,
      'canManageEvents': owner,
      'canViewVenueBookings': owner,
      'canViewVenueGuests': owner,
      'canManageReservations': owner,
      'canBulkManage': owner,
      'canExportData': owner,
      'canManageSubscription': owner,
      'canViewAnalytics': owner,
      'canAccessAdminPanel': staff,
      'canModerateContent': staff,
      'canManageUsers': staff,
    });
  }

  static const empty = Capabilities('user', {});
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum UserRole { user, venueOwner, admin }

enum SubscriptionTier { free, pro, premium }

enum VenueApplicationStatus { pending, approved, rejected }

enum BookingStatus { pending, paid, issued, cancelled, refunded }

enum ReservationStatus { requested, confirmed, seated, cancelled, noShow }

// ─── Helpers ─────────────────────────────────────────────────────────────────

SubscriptionTier _tierFrom(String s) {
  switch (s) {
    case 'pro':
      return SubscriptionTier.pro;
    case 'premium':
      return SubscriptionTier.premium;
    default:
      return SubscriptionTier.free;
  }
}

// ─── User ────────────────────────────────────────────────────────────────────

class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final UserRole role;
  final bool isVerified;
  final DateTime? createdAt;

  const User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.role = UserRole.user,
    this.isVerified = false,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        role: _roleFrom(json['role'] as String? ?? 'user'),
        isVerified: json['isVerified'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  static UserRole _roleFrom(String s) {
    switch (s) {
      case 'venue_owner':
        return UserRole.venueOwner;
      case 'admin':
      case 'super_admin':
      case 'operations':
      case 'auditor':
        return UserRole.admin;
      default:
        return UserRole.user;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'avatarUrl': avatarUrl,
        'role': role.name,
        'isVerified': isVerified,
        'createdAt': createdAt?.toIso8601String(),
      };

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }

  bool get isVenueOwner => role == UserRole.venueOwner;
  bool get isAdmin => role == UserRole.admin;
}

// ─── Venue ───────────────────────────────────────────────────────────────────

class Venue {
  final String id;
  final String name;
  final String category;
  final String neighborhood;
  final String region;
  final String city;
  final String country;
  final String address;
  final String description;
  final List<String> vibe;
  final int priceLevel;
  final double rating;
  final int ratingCount;
  final String hours;
  final String coverCharge;
  final String dressCode;
  final String? websiteUrl;
  final String imageType;
  final String signature;
  final String djTonight;
  final double latitude;
  final double longitude;
  final String? ownerId;
  final SubscriptionTier subscriptionTier;
  final bool isVerified;
  final bool isActive;
  final String? contactPhone;
  final String? contactEmail;
  final String? instagramHandle;
  final String? imageUrl;
  final double vibeScore;
  final double bayesRating;
  final double trendingScore;
  final double? distanceKm;
  final String? status;
  final String? createdAt;

  const Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.neighborhood,
    this.region = '',
    this.city = 'Kampala',
    this.country = 'Uganda',
    required this.address,
    required this.description,
    required this.vibe,
    required this.priceLevel,
    required this.rating,
    this.ratingCount = 0,
    required this.hours,
    this.coverCharge = '',
    this.dressCode = '',
    this.websiteUrl,
    required this.imageType,
    required this.signature,
    required this.djTonight,
    required this.latitude,
    required this.longitude,
    this.ownerId,
    this.subscriptionTier = SubscriptionTier.free,
    this.isVerified = false,
    this.isActive = true,
    this.contactPhone,
    this.contactEmail,
    this.instagramHandle,
    this.imageUrl,
    this.vibeScore = 0.0,
    this.bayesRating = 0.0,
    this.trendingScore = 0.0,
    this.distanceKm,
    this.status,
    this.createdAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        neighborhood: json['neighborhood'] as String,
        region: json['region'] as String? ?? '',
        city: json['city'] as String? ?? 'Kampala',
        country: json['country'] as String? ?? 'Uganda',
        address: json['address'] as String,
        description: json['description'] as String? ?? '',
        vibe: List<String>.from(json['vibe'] ?? []),
        priceLevel: (json['priceLevel'] as num?)?.toInt() ?? 2,
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        hours: json['hours'] as String? ?? '',
        coverCharge: json['coverCharge'] as String? ?? '',
        dressCode: json['dressCode'] as String? ?? '',
        websiteUrl: json['websiteUrl'] as String?,
        imageType: json['imageType'] as String? ?? 'neon',
        signature: json['signature'] as String? ?? '',
        djTonight: json['djTonight'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        ownerId: json['ownerId'] as String?,
        subscriptionTier: _tierFrom(json['subscriptionTier'] as String? ?? 'free'),
        isVerified: json['isVerified'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        contactPhone: json['contactPhone'] as String?,
        contactEmail: json['contactEmail'] as String?,
        instagramHandle: json['instagramHandle'] as String?,
        imageUrl: json['imageUrl'] as String?,
        vibeScore: (json['vibeScore'] as num?)?.toDouble() ?? 0.0,
        bayesRating: (json['bayesRating'] as num?)?.toDouble() ?? 0.0,
        trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0.0,
        distanceKm: (json['distanceKm'] as num?)?.toDouble(),
        status: json['status'] as String?,
        createdAt: json['createdAt'] as String?,
      );

  String get locationDisplay => city != 'Kampala' || country != 'Uganda'
      ? '$city, $country'
      : 'Kampala, UG';

  String get vibeLabel {
    if (vibeScore >= 75) return 'Lit';
    if (vibeScore >= 45) return 'Vibing';
    if (vibeScore >= 20) return 'Chill';
    return 'Dead';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'neighborhood': neighborhood,
        'region': region,
        'city': city,
        'country': country,
        'address': address,
        'description': description,
        'vibe': vibe,
        'priceLevel': priceLevel,
        'rating': rating,
        'ratingCount': ratingCount,
        'hours': hours,
        'coverCharge': coverCharge,
        'dressCode': dressCode,
        'websiteUrl': websiteUrl,
        'imageType': imageType,
        'signature': signature,
        'djTonight': djTonight,
        'latitude': latitude,
        'longitude': longitude,
        'ownerId': ownerId,
        'subscriptionTier': subscriptionTier.name,
        'isVerified': isVerified,
        'isActive': isActive,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'instagramHandle': instagramHandle,
      };
}

// ─── Event ───────────────────────────────────────────────────────────────────

class Event {
  final String id;
  final String title;
  final String venueId;
  final String? venueName;
  final String date;
  final String startTime;
  final String endTime;
  final String cover;
  final String description;
  final List<String> artists;
  final String genre;
  final String imageType;
  final bool featured;
  final String? ticketUrl;
  final int? capacity;
  final String? createdBy;
  final bool isApproved;
  final String? imageUrl;
  final List<TicketType> ticketTypes;

  const Event({
    required this.id,
    required this.title,
    required this.venueId,
    this.venueName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.cover,
    required this.description,
    required this.artists,
    required this.genre,
    required this.imageType,
    required this.featured,
    this.ticketUrl,
    this.capacity,
    this.createdBy,
    this.isApproved = true,
    this.imageUrl,
    this.ticketTypes = const [],
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        title: json['title'] as String,
        venueId: json['venueId'] as String,
        venueName: json['venueName'] as String?,
        date: json['date'] as String,
        startTime: json['startTime'] as String,
        endTime: json['endTime'] as String? ?? '',
        cover: json['cover'] as String? ?? '0',
        description: json['description'] as String? ?? '',
        artists: List<String>.from(json['artists'] ?? []),
        genre: json['genre'] as String,
        imageType: json['imageType'] as String? ?? 'neon',
        featured: json['featured'] as bool? ?? false,
        ticketUrl: json['ticketUrl'] as String?,
        capacity: (json['capacity'] as num?)?.toInt(),
        createdBy: json['createdBy'] as String?,
        isApproved: json['isApproved'] as bool? ?? true,
        imageUrl: json['imageUrl'] as String?,
        ticketTypes: (json['ticketTypes'] as List?)
                ?.map((t) => TicketType.fromJson(t as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// True when the event sells tickets through the in-app booking flow (as opposed
  /// to a free RSVP or an external ticket URL).
  bool get hasInternalTicketing => ticketTypes.isNotEmpty;
  bool get hasExternalTickets => ticketUrl != null && ticketUrl!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'venueId': venueId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'cover': cover,
        'description': description,
        'artists': artists,
        'genre': genre,
        'imageType': imageType,
        'featured': featured,
        'ticketUrl': ticketUrl,
        'capacity': capacity,
        'createdBy': createdBy,
        'isApproved': isApproved,
      };
}

// ─── TicketType ───────────────────────────────────────────────────────────────

class TicketType {
  final String id;
  final String eventId;
  final String name;
  final int priceUgx;
  final int? quantityTotal;
  final int quantitySold;
  final bool isActive;

  const TicketType({
    required this.id,
    required this.eventId,
    required this.name,
    required this.priceUgx,
    this.quantityTotal,
    this.quantitySold = 0,
    this.isActive = true,
  });

  factory TicketType.fromJson(Map<String, dynamic> json) => TicketType(
        id: json['id'] as String,
        eventId: json['eventId'] as String? ?? '',
        name: json['name'] as String,
        priceUgx: (json['priceUgx'] as num?)?.toInt() ?? 0,
        quantityTotal: (json['quantityTotal'] as num?)?.toInt(),
        quantitySold: (json['quantitySold'] as num?)?.toInt() ?? 0,
        isActive: json['isActive'] as bool? ?? true,
      );

  int get available => quantityTotal == null ? 9999 : quantityTotal! - quantitySold;
  bool get isFree => priceUgx == 0;
}

// ─── Booking ─────────────────────────────────────────────────────────────────

class Booking {
  final String id;
  final String bookingCode;
  final String eventId;
  final String? eventTitle;
  final String? eventDate;
  final String? venueName;
  final String ticketTypeId;
  final String? ticketTypeName;
  final int quantity;
  final int unitPriceUgx;
  final int totalUgx;
  final BookingStatus status;
  final String? issuedAt;
  final String createdAt;

  const Booking({
    required this.id,
    required this.bookingCode,
    required this.eventId,
    this.eventTitle,
    this.eventDate,
    this.venueName,
    required this.ticketTypeId,
    this.ticketTypeName,
    required this.quantity,
    required this.unitPriceUgx,
    required this.totalUgx,
    required this.status,
    this.issuedAt,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: json['id'] as String,
        bookingCode: json['bookingCode'] as String,
        eventId: json['eventId'] as String,
        eventTitle: json['eventTitle'] as String?,
        eventDate: json['eventDate'] as String?,
        venueName: json['venueName'] as String?,
        ticketTypeId: json['ticketTypeId'] as String,
        ticketTypeName: json['ticketTypeName'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        unitPriceUgx: (json['unitPriceUgx'] as num).toInt(),
        totalUgx: (json['totalUgx'] as num).toInt(),
        status: _bookingStatusFrom(json['status'] as String? ?? 'pending'),
        issuedAt: json['issuedAt'] as String?,
        createdAt: json['createdAt'] as String,
      );

  static BookingStatus _bookingStatusFrom(String s) {
    switch (s) {
      case 'paid':
        return BookingStatus.paid;
      case 'issued':
        return BookingStatus.issued;
      case 'cancelled':
        return BookingStatus.cancelled;
      case 'refunded':
        return BookingStatus.refunded;
      default:
        return BookingStatus.pending;
    }
  }

  bool get isFree => totalUgx == 0;
  bool get isCancellable =>
      status == BookingStatus.pending || status == BookingStatus.paid;
}

// ─── Reservation ─────────────────────────────────────────────────────────────

class Reservation {
  final String id;
  final String reservationCode;
  final String venueId;
  final String? venueName;
  final String? eventId;
  final String? eventTitle;
  final String reservedFor;
  final int partySize;
  final int depositUgx;
  final ReservationStatus status;
  final String? notes;
  final String createdAt;

  const Reservation({
    required this.id,
    required this.reservationCode,
    required this.venueId,
    this.venueName,
    this.eventId,
    this.eventTitle,
    required this.reservedFor,
    required this.partySize,
    this.depositUgx = 0,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'] as String,
        reservationCode: json['reservationCode'] as String,
        venueId: json['venueId'] as String,
        venueName: json['venueName'] as String?,
        eventId: json['eventId'] as String?,
        eventTitle: json['eventTitle'] as String?,
        reservedFor: json['reservedFor'] as String,
        partySize: (json['partySize'] as num).toInt(),
        depositUgx: (json['depositUgx'] as num?)?.toInt() ?? 0,
        status: _reservationStatusFrom(json['status'] as String? ?? 'requested'),
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] as String,
      );

  static ReservationStatus _reservationStatusFrom(String s) {
    switch (s) {
      case 'confirmed':
        return ReservationStatus.confirmed;
      case 'seated':
        return ReservationStatus.seated;
      case 'cancelled':
        return ReservationStatus.cancelled;
      case 'no_show':
        return ReservationStatus.noShow;
      default:
        return ReservationStatus.requested;
    }
  }

  bool get isCancellable =>
      status == ReservationStatus.requested ||
      status == ReservationStatus.confirmed;
}

// ─── VibeRating ───────────────────────────────────────────────────────────────

class VibeRating {
  final String id;
  final String entityId;
  final String entityType; // 'venue' | 'event'
  final String userId;
  final double rating; // 1-5
  final String? comment;
  final List<String> vibeTagsSelected;
  final DateTime createdAt;

  const VibeRating({
    required this.id,
    required this.entityId,
    required this.entityType,
    required this.userId,
    required this.rating,
    this.comment,
    this.vibeTagsSelected = const [],
    required this.createdAt,
  });

  factory VibeRating.fromJson(Map<String, dynamic> json) => VibeRating(
        id: json['id'] as String,
        entityId: json['entityId'] as String,
        entityType: json['entityType'] as String,
        userId: json['userId'] as String,
        rating: (json['rating'] as num).toDouble(),
        comment: json['comment'] as String?,
        vibeTagsSelected: List<String>.from(json['vibeTagsSelected'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityId': entityId,
        'entityType': entityType,
        'userId': userId,
        'rating': rating,
        'comment': comment,
        'vibeTagsSelected': vibeTagsSelected,
        'createdAt': createdAt.toIso8601String(),
      };
}

// ─── PaymentPlan ──────────────────────────────────────────────────────────────

class PaymentPlan {
  final String id;
  final String name;
  final String tier;
  final int priceUgx;
  final String billingCycle; // 'monthly' | 'quarterly' | 'yearly'
  final List<String> features;
  final int maxEvents;
  final bool featuredListing;
  final bool analyticsAccess;
  final bool prioritySupport;

  const PaymentPlan({
    required this.id,
    required this.name,
    required this.tier,
    required this.priceUgx,
    required this.billingCycle,
    required this.features,
    required this.maxEvents,
    required this.featuredListing,
    required this.analyticsAccess,
    required this.prioritySupport,
  });

  factory PaymentPlan.fromJson(Map<String, dynamic> json) => PaymentPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        tier: json['tier'] as String,
        priceUgx: (json['priceUgx'] as num).toInt(),
        billingCycle: json['billingCycle'] as String? ?? 'monthly',
        features: List<String>.from(json['features'] ?? []),
        maxEvents: (json['maxEvents'] as num?)?.toInt() ?? 0,
        featuredListing: json['featuredListing'] as bool? ?? false,
        analyticsAccess: json['analyticsAccess'] as bool? ?? false,
        prioritySupport: json['prioritySupport'] as bool? ?? false,
      );

  static List<PaymentPlan> get defaults => [
        const PaymentPlan(
          id: 'free',
          name: 'Basic Listing',
          tier: 'free',
          priceUgx: 0,
          billingCycle: 'monthly',
          features: [
            'Basic venue profile',
            'Up to 2 events/month',
            'Standard listing',
            'Customer check-ins',
          ],
          maxEvents: 2,
          featuredListing: false,
          analyticsAccess: false,
          prioritySupport: false,
        ),
        const PaymentPlan(
          id: 'pro',
          name: 'Pro Venue',
          tier: 'pro',
          priceUgx: 50000,
          billingCycle: 'monthly',
          features: [
            'Full venue profile',
            'Up to 10 events/month',
            'Priority listing',
            'Basic analytics',
            'Vibe boost (1×/month)',
            'DJ Tonight banner',
          ],
          maxEvents: 10,
          featuredListing: false,
          analyticsAccess: true,
          prioritySupport: false,
        ),
        const PaymentPlan(
          id: 'premium',
          name: 'Premium Partner',
          tier: 'premium',
          priceUgx: 120000,
          billingCycle: 'monthly',
          features: [
            'Featured venue profile',
            'Unlimited events',
            'Featured homepage listing',
            'Advanced analytics dashboard',
            'Unlimited vibe boosts',
            'Priority support',
            'Social media kit',
            'VibeKLA verified badge',
          ],
          maxEvents: 999,
          featuredListing: true,
          analyticsAccess: true,
          prioritySupport: true,
        ),
      ];
}

// ─── Subscription ─────────────────────────────────────────────────────────────

class Subscription {
  final String id;
  final String venueId;
  final String planId;
  final String? planName;
  final SubscriptionTier tier;
  final String startDate;
  final String endDate;
  final bool isActive;
  final int amountPaid;
  final int? maxEvents;
  final bool featuredListing;
  final bool analyticsAccess;
  final bool prioritySupport;
  final List<String> features;

  const Subscription({
    required this.id,
    required this.venueId,
    required this.planId,
    this.planName,
    required this.tier,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.amountPaid,
    this.maxEvents,
    this.featuredListing = false,
    this.analyticsAccess = false,
    this.prioritySupport = false,
    this.features = const [],
  });

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        venueId: json['venueId'] as String? ?? '',
        planId: json['planId'] as String? ?? '',
        planName: json['planName'] as String?,
        tier: _tierFrom(json['tier'] as String? ?? 'free'),
        startDate: json['startDate'] as String,
        endDate: json['endDate'] as String,
        isActive: json['isActive'] as bool? ?? false,
        amountPaid: (json['amountPaid'] as num?)?.toInt() ?? 0,
        maxEvents: (json['maxEvents'] as num?)?.toInt(),
        featuredListing: json['featuredListing'] as bool? ?? false,
        analyticsAccess: json['analyticsAccess'] as bool? ?? false,
        prioritySupport: json['prioritySupport'] as bool? ?? false,
        features: List<String>.from(json['features'] ?? []),
      );
}

// ─── VenueApplication ─────────────────────────────────────────────────────────

class VenueApplication {
  final String id;
  final String applicantId;
  final String venueName;
  final String category;
  final String neighborhood;
  final String address;
  final String description;
  final String contactPhone;
  final String contactEmail;
  final String? instagramHandle;
  final VenueApplicationStatus status;
  final DateTime submittedAt;
  final String? reviewNote;

  const VenueApplication({
    required this.id,
    required this.applicantId,
    required this.venueName,
    required this.category,
    required this.neighborhood,
    required this.address,
    required this.description,
    required this.contactPhone,
    required this.contactEmail,
    this.instagramHandle,
    required this.status,
    required this.submittedAt,
    this.reviewNote,
  });

  factory VenueApplication.fromJson(Map<String, dynamic> json) =>
      VenueApplication(
        id: json['id'] as String,
        applicantId: json['applicantId'] as String,
        venueName: json['venueName'] as String,
        category: json['category'] as String,
        neighborhood: json['neighborhood'] as String,
        address: json['address'] as String,
        description: json['description'] as String,
        contactPhone: json['contactPhone'] as String,
        contactEmail: json['contactEmail'] as String,
        instagramHandle: json['instagramHandle'] as String?,
        status: _statusFrom(json['status'] as String),
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        reviewNote: json['reviewNote'] as String?,
      );

  static VenueApplicationStatus _statusFrom(String s) {
    switch (s) {
      case 'approved':
        return VenueApplicationStatus.approved;
      case 'rejected':
        return VenueApplicationStatus.rejected;
      default:
        return VenueApplicationStatus.pending;
    }
  }
}

// ─── Analytics ────────────────────────────────────────────────────────────────

class VenueAnalytics {
  final String venueId;
  final int totalViews;
  final int totalCheckIns;
  final int totalBookmarks;
  final double averageRating;
  final int ratingCount;
  final Map<String, int> checkInsByDay;
  final List<String> topVibeTags;

  const VenueAnalytics({
    required this.venueId,
    required this.totalViews,
    required this.totalCheckIns,
    required this.totalBookmarks,
    required this.averageRating,
    required this.ratingCount,
    required this.checkInsByDay,
    required this.topVibeTags,
  });

  factory VenueAnalytics.fromJson(Map<String, dynamic> json) => VenueAnalytics(
        venueId: json['venueId'] as String? ?? '',
        totalViews: (json['totalViews'] as num?)?.toInt() ?? 0,
        totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
        totalBookmarks: (json['totalBookmarks'] as num?)?.toInt() ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
        checkInsByDay: Map<String, int>.from(json['checkInsByDay'] ?? {}),
        topVibeTags: List<String>.from(json['topVibeTags'] ?? []),
      );
}

// ─── CheckIn ──────────────────────────────────────────────────────────────────

class CheckIn {
  final String id;
  final String venueId;
  final String userName;
  final DateTime createdAt;

  const CheckIn({
    required this.id,
    required this.venueId,
    required this.userName,
    required this.createdAt,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
        id: json['id'] as String,
        venueId: json['venueId'] as String,
        userName: json['userName'] as String? ?? 'Guest',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'venueId': venueId,
        'userName': userName,
        'createdAt': createdAt.toIso8601String(),
      };
}

// ─── Boost ───────────────────────────────────────────────────────────────────

class Boost {
  final String id;
  final String entityType;
  final String entityId;
  final String entityName;
  final DateTime boostedAt;
  final DateTime boostedUntil;
  final bool active;

  const Boost({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.boostedAt,
    required this.boostedUntil,
    required this.active,
  });

  factory Boost.fromJson(Map<String, dynamic> json) => Boost(
        id: json['id'] as String,
        entityType: json['entityType'] as String? ?? 'venue',
        entityId: json['entityId'] as String,
        entityName: json['entityName'] as String? ?? '',
        boostedAt: DateTime.parse(json['boostedAt'] as String),
        boostedUntil: DateTime.parse(json['boostedUntil'] as String),
        active: json['active'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'entityName': entityName,
        'boostedAt': boostedAt.toIso8601String(),
        'boostedUntil': boostedUntil.toIso8601String(),
        'active': active,
      };
}

// ─── AppStats ─────────────────────────────────────────────────────────────────

class AppStats {
  final String id;
  final DateTime date;
  final int downloads;
  final int activeUsers;

  const AppStats({
    required this.id,
    required this.date,
    required this.downloads,
    required this.activeUsers,
  });

  factory AppStats.fromJson(Map<String, dynamic> json) => AppStats(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        downloads: (json['downloads'] as num?)?.toInt() ?? 0,
        activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'downloads': downloads,
        'activeUsers': activeUsers,
      };
}

// ─── VibeTag (from admin content config) ──────────────────────────────────────

class VibeTag {
  final String name;
  final String emoji;

  const VibeTag({required this.name, required this.emoji});

  factory VibeTag.fromJson(Map<String, dynamic> json) => VibeTag(
        name: json['name'] as String,
        emoji: json['emoji'] as String? ?? '',
      );

  String get display => emoji.isNotEmpty ? '$emoji $name' : name;
}

// ─── AppBanner (from admin content config) ────────────────────────────────────

class AppBanner {
  final int id;
  final String title;
  final String subtitle;
  final String bgColor;
  final String? actionUrl;

  const AppBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    this.actionUrl,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) => AppBanner(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        bgColor: json['bgColor'] as String? ?? '#8b5cf6',
        actionUrl: json['actionUrl'] as String?,
      );
}
