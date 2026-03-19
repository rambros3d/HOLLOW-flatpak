import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hollow/src/core/services/identity_service.dart';
import 'package:hollow/src/core/services/network_service.dart';
import 'package:hollow/src/core/services/storage_service.dart';

/// Singleton service providers — one instance for the app lifetime.
final networkServiceProvider = Provider<NetworkService>((_) => NetworkService());
final storageServiceProvider = Provider<StorageService>((_) => StorageService());
final identityServiceProvider =
    Provider<IdentityService>((_) => IdentityService());
