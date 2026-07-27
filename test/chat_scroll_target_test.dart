import 'package:flutter_test/flutter_test.dart';
import 'package:mangotalk/features/chat/presentation/chat_scroll_target.dart';

void main() {
  group('estimateMessageScrollOffset', () {
    test('목록의 상대 인덱스로 예상 스크롤 위치를 계산한다', () {
      expect(
        estimateMessageScrollOffset(
          targetIndex: 25,
          itemCount: 51,
          maxScrollExtent: 1000,
        ),
        500,
      );
    });

    test('첫 메시지와 마지막 메시지는 스크롤 경계에 맞춘다', () {
      expect(
        estimateMessageScrollOffset(
          targetIndex: 0,
          itemCount: 10,
          maxScrollExtent: 900,
        ),
        0,
      );
      expect(
        estimateMessageScrollOffset(
          targetIndex: 9,
          itemCount: 10,
          maxScrollExtent: 900,
        ),
        900,
      );
    });
  });

  group('directionToMessage', () {
    test('목표가 렌더링 범위 위나 아래에 있는 방향을 반환한다', () {
      expect(directionToMessage(targetIndex: 2, visibleIndices: [5, 6, 7]), -1);
      expect(directionToMessage(targetIndex: 9, visibleIndices: [5, 6, 7]), 1);
      expect(directionToMessage(targetIndex: 6, visibleIndices: [5, 6, 7]), 0);
    });
  });
}
