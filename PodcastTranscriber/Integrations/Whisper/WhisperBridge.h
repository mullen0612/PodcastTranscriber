#ifndef WhisperBridge_h
#define WhisperBridge_h

#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Transcribes a WAV audio file using whisper.cpp.
/// Returns 0 on success, negative error code on failure.
int pt_whisper_transcribe(const char* model_path, const char* audio_path, const char* out_text_path);

#ifdef __cplusplus
}
#endif

#endif /* WhisperBridge_h */
