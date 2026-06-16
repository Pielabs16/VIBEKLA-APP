import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _keyAccess = 'vk_access_token';
  static const _keyRefresh = 'vk_refresh_token';
  static const _keyUserId = 'vk_user_id';
  static const _keyUserEmail = 'vk_user_email';
  static const _keyUserRole = 'vk_user_role';
  static const _keyFirstName = 'vk_first_name';
  static const _keyLastName = 'vk_last_name';

  bool _isAuthenticated = false;
  bool _isLoading = false;
  User? _user;
  String? _error;
  Capabilities _capabilities = Capabilities.empty;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get user => _user;
  String? get userId => _user?.id;
  String? get userEmail => _user?.email;
  UserRole get userRole => _user?.role ?? UserRole.user;
  bool get isAdmin => userRole == UserRole.admin;
  bool get isVenueOwner => userRole == UserRole.venueOwner || isAdmin;
  String? get error => _error;

  // ── Capabilities (server-authoritative role gating) ────────────────────────
  Capabilities get capabilities => _capabilities;
  bool get canManageVenue        => _capabilities.canManageVenue;
  bool get canManageReservations => _capabilities.canManageReservations;
  bool get canViewAnalytics      => _capabilities.canViewAnalytics;
  bool get canAccessAdminPanel   => _capabilities.canAccessAdminPanel;

  // Counts updated after profile fetch
  int _checkInCount = 0;
  int _savedEventCount = 0;
  int get checkInCount => _checkInCount;
  int get savedEventCount => _savedEventCount;

  void updateStats({int? checkIns, int? savedEvents}) {
    if (checkIns != null) _checkInCount = checkIns;
    if (savedEvents != null) _savedEventCount = savedEvents;
    notifyListeners();
  }

  final ApiService _api = ApiService();

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_keyAccess);
    final refresh = prefs.getString(_keyRefresh);
    if (access == null) return;

    _api.setTokens(access, refresh);

    try {
      final user = await _api.getMe();
      _user = user;
      _isAuthenticated = true;
      _applyRoleCapabilities();
    } catch (e) {
      // Access token expired — try refresh
      if (refresh != null) {
        try {
          final result = await _api.refreshTokens(refresh);
          await _persist(result, prefs);
          _user = result.user;
          _isAuthenticated = true;
          _applyRoleCapabilities();
        } catch (_) {
          await _clear(prefs);
        }
      } else {
        await _clear(prefs);
      }
    }
    notifyListeners();
    if (_isAuthenticated) _loadCapabilities();
  }

  /// Optimistic, offline-safe capability set derived from the JWT role. Applied
  /// immediately on auth so the UI gates correctly even before the server call.
  void _applyRoleCapabilities() {
    final role = _user?.role == UserRole.venueOwner
        ? 'venue_owner'
        : _user?.role == UserRole.admin
            ? 'admin'
            : 'user';
    _capabilities = Capabilities.fromRole(role);
  }

  /// Refines capabilities from the server (authoritative). Failure is non-fatal —
  /// the role-derived set already applied stays in effect.
  Future<void> _loadCapabilities() async {
    try {
      final res = await _api.getCapabilities();
      _capabilities = Capabilities.fromJson(res);
      notifyListeners();
    } catch (_) {
      // keep role-derived fallback
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    _setLoading(true);
    try {
      final result = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await _persist(result, prefs);
      _user = result.user;
      _isAuthenticated = true;
      _error = null;
      _applyRoleCapabilities();
      _loadCapabilities();
    } on ApiException catch (e) {
      _error = e.message;
      _isAuthenticated = false;
    } catch (e) {
      _error = 'Connection error. Check your network.';
      _isAuthenticated = false;
    } finally {
      _setLoading(false);
    }
  }

  String? _pendingEmail;
  String? get pendingEmail => _pendingEmail;

  Future<bool> signUp(
      String email, String password, String firstName, String lastName) async {
    _setLoading(true);
    try {
      final result = await _api.register(email, password, firstName, lastName);
      _pendingEmail = result['email'] as String? ?? email;
      _error = null;
      return true; // needs OTP verification
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Connection error. Check your network.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyOtp(String email, String code) async {
    _setLoading(true);
    try {
      final result = await _api.verifyOtp(email, code);
      final prefs = await SharedPreferences.getInstance();
      await _persist(result, prefs);
      _user = result.user;
      _isAuthenticated = true;
      _pendingEmail = null;
      _error = null;
      _applyRoleCapabilities();
      _loadCapabilities();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Connection error. Check your network.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _api.resendOtp(email);
    } catch (_) {}
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_keyRefresh);
    try {
      await _api.logout(refresh);
    } catch (_) {}
    _api.clearTokens();
    await _clear(prefs);
    _user = null;
    _isAuthenticated = false;
    _capabilities = Capabilities.empty;
    _error = null;
    notifyListeners();
  }

  Future<void> refreshAuth() async {
    if (!_isAuthenticated) return;
    try {
      _user = await _api.getMe();
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  Future<void> _persist(AuthResult result, SharedPreferences prefs) async {
    _api.setTokens(result.accessToken, result.refreshToken);
    await prefs.setString(_keyAccess, result.accessToken);
    if (result.refreshToken != null) {
      await prefs.setString(_keyRefresh, result.refreshToken!);
    }
    await prefs.setString(_keyUserId, result.user.id);
    await prefs.setString(_keyUserEmail, result.user.email);
    await prefs.setString(_keyUserRole, result.user.role.name);
    await prefs.setString(_keyFirstName, result.user.firstName ?? '');
    await prefs.setString(_keyLastName, result.user.lastName ?? '');
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_keyAccess);
    await prefs.remove(_keyRefresh);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyFirstName);
    await prefs.remove(_keyLastName);
  }
}
