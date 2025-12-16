import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

abstract class UploadLocalizations {
  UploadLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static UploadLocalizations? of(BuildContext context) {
    return Localizations.of<UploadLocalizations>(context, UploadLocalizations);
  }

  static const LocalizationsDelegate<UploadLocalizations> delegate = _UploadLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  String get saveSuccess;
  String saveError(String error);
  String get tourName;
  String get enterTourName;
  String get departureDate;
  String get selectDepartureDate;
  String get duration;
  String get enterDuration;
  String get transport;
  String get departureLocation;
  String get destination;
  String get price;
  String get enterPrice;
  String get priceMustBeNumber;
  String get description;
  String get media;
  String get saving;
  String get saveInfo;
}

class _UploadLocalizationsDelegate extends LocalizationsDelegate<UploadLocalizations> {
  const _UploadLocalizationsDelegate();

  @override
  Future<UploadLocalizations> load(Locale locale) {
    return SynchronousFuture<UploadLocalizations>(lookupUploadLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_UploadLocalizationsDelegate old) => false;
}

UploadLocalizations lookupUploadLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en': return UploadLocalizationsEn();
    case 'vi': return UploadLocalizationsVi();
  }

  throw FlutterError(
    'UploadLocalizations.delegate failed to load unsupported locale "$locale".'
  );
}

class UploadLocalizationsEn extends UploadLocalizations {
  UploadLocalizationsEn() : super('en');

  @override
  String get saveSuccess => 'Information saved successfully!';

  @override
  String saveError(String error) => 'Error saving information: $error';

  @override
  String get tourName => 'Tour name';

  @override
  String get enterTourName => 'Please enter tour name';

  @override
  String get departureDate => 'Departure date (dd/mm/yy)';

  @override
  String get selectDepartureDate => 'Please select departure date';

  @override
  String get duration => 'Duration (N days N nights)';

  @override
  String get enterDuration => 'Please enter duration';

  @override
  String get transport => 'Transportation';

  @override
  String get departureLocation => 'Departure from';

  @override
  String get destination => 'Destination';

  @override
  String get price => 'Price (VNĐ)';

  @override
  String get enterPrice => 'Please enter price';

  @override
  String get priceMustBeNumber => 'Price must be a number';

  @override
  String get description => 'Short description';

  @override
  String get media => 'Images / Videos';

  @override
  String get saving => 'Saving...';

  @override
  String get saveInfo => 'Save information';
}

class UploadLocalizationsVi extends UploadLocalizations {
  UploadLocalizationsVi() : super('vi');

  @override
  String get saveSuccess => 'Thông tin đã được lưu thành công!';

  @override
  String saveError(String error) => 'Lỗi khi lưu thông tin: $error';

  @override
  String get tourName => 'Tên tour';

  @override
  String get enterTourName => 'Vui lòng nhập tên tour';

  @override
  String get departureDate => 'Ngày khởi hành (dd/mm/yy)';

  @override
  String get selectDepartureDate => 'Vui lòng chọn ngày khởi hành';

  @override
  String get duration => 'Thời gian (N ngày N đêm)';

  @override
  String get enterDuration => 'Vui lòng nhập thời gian';

  @override
  String get transport => 'Phương tiện di chuyển';

  @override
  String get departureLocation => 'Khởi hành từ';

  @override
  String get destination => 'Điểm đến';

  @override
  String get price => 'Giá (VNĐ)';

  @override
  String get enterPrice => 'Vui lòng nhập giá';

  @override
  String get priceMustBeNumber => 'Giá phải là số';

  @override
  String get description => 'Mô tả ngắn';

  @override
  String get media => 'Hình ảnh / Video';

  @override
  String get saving => 'Đang lưu...';

  @override
  String get saveInfo => 'Lưu thông tin';
}