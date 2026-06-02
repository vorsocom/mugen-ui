import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';

void main() {
  test('transcript result resolves latest sequence from payload or items', () {
    const explicit = HumanHandoffTranscriptResultEntity(
      items: <HumanHandoffTranscriptItemEntity>[],
      count: 0,
      hasMore: false,
      latestSequenceNo: 9,
    );
    const empty = HumanHandoffTranscriptResultEntity(
      items: <HumanHandoffTranscriptItemEntity>[],
      count: 0,
      hasMore: false,
    );
    const derived = HumanHandoffTranscriptResultEntity(
      items: <HumanHandoffTranscriptItemEntity>[
        HumanHandoffTranscriptItemEntity(
          sequenceNo: 2,
          role: 'assistant',
          content: 'reply',
          source: 'human_handoff',
        ),
        HumanHandoffTranscriptItemEntity(
          sequenceNo: 5,
          role: 'user',
          content: 'hello',
          source: 'human_handoff_user_turn',
        ),
      ],
      count: 2,
      hasMore: false,
    );

    expect(explicit.resolvedLatestSequenceNo, 9);
    expect(empty.resolvedLatestSequenceNo, isNull);
    expect(derived.resolvedLatestSequenceNo, 5);
  });
}
