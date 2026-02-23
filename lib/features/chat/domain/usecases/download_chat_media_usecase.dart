import 'package:mugen_ui/features/chat/domain/entities/chat_media_download_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class DownloadChatMediaUseCase {
  const DownloadChatMediaUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatMediaDownloadEntity>> call({
    required String mediaUrl,
    String? suggestedFilename,
    String? suggestedMimeType,
  }) {
    return _repository.downloadMedia(
      mediaUrl: mediaUrl,
      suggestedFilename: suggestedFilename,
      suggestedMimeType: suggestedMimeType,
    );
  }
}
