import 'package:mugen_ui/shared/domain/failure.dart';

class Result<T> {
  const Result._({this.data, this.failure});

  const Result.success(T value) : this._(data: value, failure: null);

  const Result.failure(Failure value) : this._(data: null, failure: value);

  final T? data;
  final Failure? failure;

  bool get isSuccess => failure == null;
  bool get isFailure => failure != null;
}
