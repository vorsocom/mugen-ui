import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/application/pagination.dart';

void main() {
  test('PageRequest.skip handles first and subsequent pages', () {
    expect(const PageRequest(page: 1, pageSize: 25).skip, 0);
    expect(const PageRequest(page: 3, pageSize: 25).skip, 50);
  });

  test('PageResult.pages handles non-positive and normal page sizes', () {
    expect(
      const PageResult<int>(
        items: <int>[],
        total: 100,
        page: 1,
        pageSize: 0,
      ).pages,
      1,
    );
    expect(
      const PageResult<int>(
        items: <int>[],
        total: 101,
        page: 1,
        pageSize: 10,
      ).pages,
      11,
    );
  });
}
