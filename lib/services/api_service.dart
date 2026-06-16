import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/models.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  ApiService._internal();
  factory ApiService() => _instance;

  String? _accessToken;
  String? _storedRefreshToken;
  bool _refreshing = false;

  String? get storedRefreshToken => _storedRefreshToken;

  void setTokens(String? access, String? refresh) {
    _accessToken = access;
    _storedRefreshToken = refresh;
  }

  void clearTokens() {
    _accessToken = null;
    _storedRefreshToken = null;
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  // Build URL with optional query params. All API endpoints use query params,
  // not path segments (e.g. /venues?id=abc, not /venues/abc).
  Uri _url(String path, [Map<String, String>? params]) {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    return params != null && params.isNotEmpty
        ? uri.replace(queryParameters: params)
        : uri;
  }

  // Silently refresh the access token using the stored refresh token.
  // Returns true if successful. Clears tokens on failure.
  Future<bool> _tryRefresh() async {
    if (_refreshing || _storedRefreshToken == null) return false;
    _refreshing = true;
    try {
      final result = await refreshTokens(_storedRefreshToken!);
      _accessToken = result.accessToken;
      if (result.refreshToken != null) _storedRefreshToken = result.refreshToken;
      return true;
    } catch (_) {
      clearTokens();
      return false;
    } finally {
      _refreshing = false;
    }
  }

  // Authenticated HTTP helpers — each retries once after a 401 by refreshing.
  Future<http.Response> _get(Uri url) async {
    var res = await http.get(url, headers: _authHeaders)
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.get(url, headers: _authHeaders)
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    }
    return res;
  }

  Future<http.Response> _post(Uri url, {Object? body}) async {
    var res = await http.post(url, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.post(url, headers: _authHeaders, body: body)
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    }
    return res;
  }

  Future<http.Response> _put(Uri url, {Object? body}) async {
    var res = await http.put(url, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.put(url, headers: _authHeaders, body: body)
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    }
    return res;
  }

  Future<http.Response> _patch(Uri url, {Object? body}) async {
    var res = await http.patch(url, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    if (res.statusCode == 401 && await _tryRefresh()) {
      res = await http.patch(url, headers: _authHeaders, body: body)
          .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    }
    return res;
  }

  // Decode a response that returns a JSON object.
  Future<Map<String, dynamic>> _decode(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
        body['error'] as String? ?? body['message'] as String? ?? 'Request failed',
        res.statusCode,
      );
    }
    return Future.value(body);
  }

  // Decode a response that returns a JSON array directly.
  Future<List<dynamic>> _decodeList(http.Response res) {
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      final msg = body is Map
          ? (body['error'] as String? ?? body['message'] as String? ?? 'Request failed')
          : 'Request failed';
      throw ApiException(msg, res.statusCode);
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return Future.value(decoded);
    // Some endpoints return {data: [...]} — unwrap gracefully.
    if (decoded is Map) {
      final list = decoded['data'] as List<dynamic>?;
      if (list != null) return Future.value(list);
    }
    return Future.value([]);
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<AuthResult> login(String email, String password) async {
    final res = await http
        .post(_url('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}))
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    final body = await _decode(res);
    return AuthResult.fromJson(body);
  }

  /// Returns a map with keys: status ('pending_verification'), email, otp (dev only).
  Future<Map<String, dynamic>> register(
      String email, String password, String firstName, String lastName,
      {String role = 'user'}) async {
    final res = await http
        .post(_url('/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
              'firstName': firstName,
              'lastName': lastName,
              'role': role,
            }))
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    return _decode(res);
  }

  /// Verify email OTP after registration. Returns full AuthResult on success.
  Future<AuthResult> verifyOtp(String email, String code) async {
    final res = await http
        .post(_url('/auth/verify-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'code': code}))
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    final body = await _decode(res);
    return AuthResult.fromJson(body);
  }

  /// Request a new OTP for an unverified account.
  Future<Map<String, dynamic>> resendOtp(String email) async {
    final res = await http
        .post(_url('/auth/resend-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}))
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    return _decode(res);
  }

  Future<AuthResult> refreshTokens(String refreshToken) async {
    final res = await http
        .post(_url('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}))
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    final body = await _decode(res);
    return AuthResult.fromJson(body);
  }

  Future<void> logout(String? refreshToken) async {
    await _post(_url('/auth/logout'),
        body: jsonEncode({'refreshToken': refreshToken}));
  }

  Future<User> getMe() async {
    final res = await _get(_url('/auth/me'));
    final body = await _decode(res);
    return User.fromJson(body['user'] as Map<String, dynamic>? ?? body);
  }

  Future<Map<String, dynamic>> getCapabilities() async {
    return _decode(await _get(_url('/auth/capabilities')));
  }

  // ── Venues ──────────────────────────────────────────────────────────────────

  Future<PaginatedResult<Venue>> fetchVenues({
    int page = 1,
    int perPage = 20,
    String? search,
    String? category,
    String? tier,
    String? sort,
    String? region,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'perPage': '$perPage',
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tier != null && tier.isNotEmpty) 'tier': tier,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
      if (region != null && region.isNotEmpty) 'region': region,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (radiusKm != null) 'radiusKm': '$radiusKm',
    };
    final body = await _decode(await _get(_url('/venues', params)));
    return PaginatedResult.fromJson(
        body, (j) => Venue.fromJson(j as Map<String, dynamic>));
  }

  Future<List<Venue>> fetchMyVenues() async {
    final list = await _decodeList(await _get(_url('/venues', {'id': 'mine'})));
    return list.map((j) => Venue.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Venue> fetchVenue(String id) async {
    final body = await _decode(await _get(_url('/venues', {'id': id})));
    return Venue.fromJson(body['venue'] as Map<String, dynamic>? ?? body);
  }

  Future<Venue> createVenue(Map<String, dynamic> payload) async {
    final body = await _decode(
        await _post(_url('/venues'), body: jsonEncode(payload)));
    return Venue.fromJson(body['venue'] as Map<String, dynamic>? ?? body);
  }

  Future<Venue> updateVenue(String id, Map<String, dynamic> payload) async {
    final body = await _decode(
        await _put(_url('/venues', {'id': id}), body: jsonEncode(payload)));
    return Venue.fromJson(body['venue'] as Map<String, dynamic>? ?? body);
  }

  Future<Map<String, dynamic>> fetchVenueMap({
    String? region,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final params = <String, String>{
      'action': 'map',
      if (region != null && region.isNotEmpty) 'region': region,
      if (lat != null) 'lat': '$lat',
      if (lng != null) 'lng': '$lng',
      if (radiusKm != null) 'radiusKm': '$radiusKm',
    };
    return _decode(await _get(_url('/venues', params)));
  }

  // ── Events ──────────────────────────────────────────────────────────────────

  Future<PaginatedResult<Event>> fetchEvents({
    int page = 1,
    int perPage = 20,
    String? venueId,
    String? search,
    String? genre,
    bool? featured,
    bool? upcoming,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'perPage': '$perPage',
      if (venueId != null && venueId.isNotEmpty) 'venueId': venueId,
      if (search != null && search.isNotEmpty) 'search': search,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (featured == true) 'featured': '1',
      if (upcoming == true) 'upcoming': '1',
    };
    final body = await _decode(await _get(_url('/events', params)));
    return PaginatedResult.fromJson(
        body, (j) => Event.fromJson(j as Map<String, dynamic>));
  }

  Future<Event> fetchEvent(String id) async {
    final body = await _decode(await _get(_url('/events', {'id': id})));
    return Event.fromJson(body['event'] as Map<String, dynamic>? ?? body);
  }

  Future<Event> createEvent(Map<String, dynamic> payload) async {
    final body = await _decode(
        await _post(_url('/events'), body: jsonEncode(payload)));
    return Event.fromJson(body['event'] as Map<String, dynamic>? ?? body);
  }

  Future<Event> updateEvent(String id, Map<String, dynamic> payload) async {
    final body = await _decode(
        await _put(_url('/events', {'id': id}), body: jsonEncode(payload)));
    return Event.fromJson(body['event'] as Map<String, dynamic>? ?? body);
  }

  // ── Bookings ────────────────────────────────────────────────────────────────

  Future<PaginatedResult<Booking>> fetchBookings({
    int page = 1,
    String? status,
  }) async {
    final params = <String, String>{
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final body = await _decode(await _get(_url('/bookings', params)));
    return PaginatedResult.fromJson(
        body, (j) => Booking.fromJson(j as Map<String, dynamic>));
  }

  Future<Booking> fetchBooking(String id) async {
    final body = await _decode(await _get(_url('/bookings', {'id': id})));
    return Booking.fromJson(body['booking'] as Map<String, dynamic>? ?? body);
  }

  Future<Booking> createBooking({
    required String eventId,
    required String ticketTypeId,
    required int quantity,
  }) async {
    final body = await _decode(await _post(_url('/bookings'),
        body: jsonEncode({
          'eventId': eventId,
          'ticketTypeId': ticketTypeId,
          'quantity': quantity,
        })));
    return Booking.fromJson(body['booking'] as Map<String, dynamic>? ?? body);
  }

  Future<void> cancelBooking(String id) async {
    await _decode(await _post(
        _url('/bookings', {'id': id, 'action': 'cancel'})));
  }

  // ── Reservations ────────────────────────────────────────────────────────────

  Future<PaginatedResult<Reservation>> fetchReservations({
    int page = 1,
    String? status,
  }) async {
    final params = <String, String>{
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final body = await _decode(await _get(_url('/reservations', params)));
    return PaginatedResult.fromJson(
        body, (j) => Reservation.fromJson(j as Map<String, dynamic>));
  }

  Future<Reservation> fetchReservation(String id) async {
    final body =
        await _decode(await _get(_url('/reservations', {'id': id})));
    return Reservation.fromJson(
        body['reservation'] as Map<String, dynamic>? ?? body);
  }

  Future<Reservation> createReservation({
    required String venueId,
    required String reservedFor,
    required int partySize,
    String? eventId,
    String? notes,
    int depositUgx = 0,
  }) async {
    final body = await _decode(await _post(_url('/reservations'),
        body: jsonEncode({
          'venueId': venueId,
          'reservedFor': reservedFor,
          'partySize': partySize,
          if (eventId != null) 'eventId': eventId,
          if (notes != null) 'notes': notes,
          'depositUgx': depositUgx,
        })));
    return Reservation.fromJson(
        body['reservation'] as Map<String, dynamic>? ?? body);
  }

  Future<Reservation> updateReservation(
      String id, Map<String, dynamic> payload) async {
    final body = await _decode(await _patch(
        _url('/reservations', {'id': id}),
        body: jsonEncode(payload)));
    return Reservation.fromJson(
        body['reservation'] as Map<String, dynamic>? ?? body);
  }

  // ── Check-ins ───────────────────────────────────────────────────────────────

  Future<CheckIn> createCheckIn(String venueId, String userName) async {
    final body = await _decode(await _post(_url('/checkins'),
        body: jsonEncode({'venueId': venueId, 'userName': userName})));
    return CheckIn.fromJson(body['checkin'] as Map<String, dynamic>? ?? body);
  }

  Future<List<CheckIn>> fetchCheckins(String venueId) async {
    final body =
        await _decode(await _get(_url('/checkins', {'venueId': venueId})));
    final list = body['checkins'] as List<dynamic>? ?? [];
    return list
        .map((j) => CheckIn.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  // ── Ratings ─────────────────────────────────────────────────────────────────

  Future<void> submitRating({
    required String entityId,
    required String entityType,
    required double rating,
    List<String>? vibeTags,
    String? comment,
  }) async {
    await _decode(await _post(_url('/ratings'),
        body: jsonEncode({
          'entityId': entityId,
          'entityType': entityType,
          'rating': rating,
          if (vibeTags != null) 'vibeTags': vibeTags,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        })));
  }

  Future<Map<String, dynamic>> fetchRatings(
      String entityId, String entityType) async {
    return _decode(await _get(
        _url('/ratings', {'entityId': entityId, 'entityType': entityType})));
  }

  Future<Map<String, dynamic>> fetchMyRating(
      String entityId, String entityType) async {
    return _decode(await _get(_url('/ratings', {
      'action': 'mine',
      'entityId': entityId,
      'entityType': entityType,
    })));
  }

  // ── Vibe Score ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchVibeScore(String venueId) async {
    return _decode(await _get(
        _url('/vibe', {'action': 'score', 'venueId': venueId})));
  }

  Future<List<dynamic>> fetchVibeLeaderboard() async {
    final body =
        await _decode(await _get(_url('/vibe', {'action': 'leaderboard'})));
    return body['venues'] as List<dynamic>? ??
        body['data'] as List<dynamic>? ??
        [];
  }

  Future<Map<String, dynamic>> checkBoostStatus(String venueId) async {
    return _decode(await _get(
        _url('/vibe', {'action': 'boost_status', 'venueId': venueId})));
  }

  Future<Map<String, dynamic>> applyBoost(String venueId) async {
    return _decode(await _post(
        _url('/vibe', {'action': 'boost', 'venueId': venueId})));
  }

  // ── Applications ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitApplication(
      Map<String, dynamic> payload) async {
    return _decode(
        await _post(_url('/applications'), body: jsonEncode(payload)));
  }

  Future<PaginatedResult<VenueApplication>> fetchApplications({
    int page = 1,
    String? status,
  }) async {
    final params = <String, String>{
      'page': '$page',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final body = await _decode(await _get(_url('/applications', params)));
    return PaginatedResult.fromJson(
        body, (j) => VenueApplication.fromJson(j as Map<String, dynamic>));
  }

  // ── Payments ─────────────────────────────────────────────────────────────────

  Future<List<PaymentPlan>> fetchPlans() async {
    final list = await _decodeList(
        await _get(_url('/payments', {'action': 'plans'})));
    if (list.isEmpty) return PaymentPlan.defaults;
    return list
        .map((j) => PaymentPlan.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> subscribe(
      String venueId, String planId, String paymentRef) async {
    return _decode(await _post(_url('/payments', {'action': 'subscribe'}),
        body: jsonEncode({
          'venueId': venueId,
          'planId': planId,
          'paymentRef': paymentRef,
        })));
  }

  Future<Map<String, dynamic>> initiatePayment({
    required String venueId,
    required String planId,
    required String method,
    required String reference,
    String? phoneNumber,
  }) async {
    final res = await _post(
      _url('/payments', {'action': 'initiate'}),
      body: jsonEncode({
        'venueId': venueId,
        'planId': planId,
        'method': method,
        'reference': reference,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      }),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
          body['message'] as String? ?? 'Payment failed', res.statusCode);
    }
    return body['data'] as Map<String, dynamic>? ?? body;
  }

  Future<String> checkPaymentStatus(String reference) async {
    final res = await _get(
        _url('/payments', {'action': 'payment_status', 'reference': reference}));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw ApiException(
          body['message'] as String? ?? 'Status check failed', res.statusCode);
    }
    return body['status'] as String? ?? 'pending';
  }

  Future<Map<String, dynamic>> subscriptionStatus(String venueId) async {
    return _decode(await _get(
        _url('/payments', {'action': 'status', 'venueId': venueId})));
  }

  // ── Owner Dashboard ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchOwnerDashboard() async {
    return _decode(await _get(_url('/owner', {'action': 'dashboard'})));
  }

  Future<Map<String, dynamic>> fetchOwnerVenueStats(String venueId) async {
    return _decode(await _get(
        _url('/owner', {'action': 'venue_stats', 'venueId': venueId})));
  }

  Future<PaginatedResult<Reservation>> fetchOwnerReservations({
    int page = 1,
    String? venueId,
    String? status,
  }) async {
    final params = <String, String>{
      'action': 'reservations',
      'page': '$page',
      if (venueId != null) 'venueId': venueId,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final body = await _decode(await _get(_url('/owner', params)));
    return PaginatedResult.fromJson(
        body, (j) => Reservation.fromJson(j as Map<String, dynamic>));
  }

  Future<PaginatedResult<Booking>> fetchOwnerBookings({
    int page = 1,
    String? eventId,
    String? status,
  }) async {
    final params = <String, String>{
      'action': 'bookings',
      'page': '$page',
      if (eventId != null) 'eventId': eventId,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final body = await _decode(await _get(_url('/owner', params)));
    return PaginatedResult.fromJson(
        body, (j) => Booking.fromJson(j as Map<String, dynamic>));
  }

  // ── Content (admin-managed dynamic data) ────────────────────────────────────

  Future<Map<String, dynamic>> fetchContent() async {
    final res = await http
        .get(_url('/content'), headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
    return _decode(res);
  }

  // ── Analytics ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchVenueAnalytics(String venueId) async {
    return _decode(await _get(
        _url('/analytics', {'action': 'venue_analytics', 'venueId': venueId})));
  }

  Future<Map<String, dynamic>> fetchAdminOverview() async {
    return _decode(
        await _get(_url('/analytics', {'action': 'admin_overview'})));
  }
}

// ── Supporting types ────────────────────────────────────────────────────────

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class AuthResult {
  final String accessToken;
  final String? refreshToken;
  final User user;

  const AuthResult({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String?,
        user: User.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class PaginatedResult<T> {
  final List<T> data;
  final int total;
  final int page;
  final int perPage;

  const PaginatedResult({
    required this.data,
    required this.total,
    required this.page,
    required this.perPage,
  });

  int get totalPages => perPage > 0 ? (total / perPage).ceil() : 1;
  bool get hasNext => page < totalPages;

  factory PaginatedResult.fromJson(
      Map<String, dynamic> j, T Function(dynamic) fromJson) {
    final raw = j['data'] as List<dynamic>? ?? [];
    return PaginatedResult(
      data: raw.map(fromJson).toList(),
      total: (j['total'] as num?)?.toInt() ?? raw.length,
      page: (j['page'] as num?)?.toInt() ?? 1,
      perPage: (j['perPage'] as num?)?.toInt() ?? raw.length,
    );
  }
}
