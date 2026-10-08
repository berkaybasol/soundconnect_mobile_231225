import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/network/dio_api_client.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/profile_media_upload_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_draft_media_cleanup_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/pending_profile_upload_store.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';

import 'support/recording_api_client.dart';
import 'support/event_audience_fakes.dart';

part 'support/profile_upload_repository_test_support.dart';

part 'profile_upload_repository_test_register_profile_media_upload_repository_impl1.dart';
part 'profile_upload_repository_test_register_profile_media_upload_repository_impl2.dart';
part 'profile_upload_repository_test_register_profile_media_upload_repository_impl3.dart';
part 'profile_upload_repository_test_register_profile_upload_repository4.dart';

void main() {
  _registerProfileUploadRepository4();
}
