#import "Whisper/WhisperBridge.h"
#import <Foundation/Foundation.h>
#import <whisper.h>

int pt_whisper_transcribe(const char *model_path, const char *audio_path, const char *out_text_path) {
    // Load the Whisper model
    struct whisper_context *ctx = whisper_init_from_file(model_path);
    if (!ctx) {
        return -1; // Failed to load model
    }

    // Load the audio file (expects WAV: 44-byte header + int16 PCM samples)
    FILE *audio_file = fopen(audio_path, "rb");
    if (!audio_file) {
        whisper_free(ctx);
        return -2; // Failed to open audio file
    }

    // Skip the 44-byte WAV header
    fseek(audio_file, 44, SEEK_SET);

    // Read remaining bytes as int16 PCM samples
    fseek(audio_file, 0, SEEK_END);
    long file_size = ftell(audio_file);
    fseek(audio_file, 44, SEEK_SET);

    long pcm_size = file_size - 44;
    int num_samples = (int)(pcm_size / sizeof(int16_t));

    int16_t *pcm_data = (int16_t *)malloc(pcm_size);
    if (!pcm_data) {
        fclose(audio_file);
        whisper_free(ctx);
        return -3; // Memory allocation failure
    }

    fread(pcm_data, 1, pcm_size, audio_file);
    fclose(audio_file);

    // Convert int16 PCM to float samples (whisper expects float in [-1, 1])
    float *audio_data = (float *)malloc(num_samples * sizeof(float));
    if (!audio_data) {
        free(pcm_data);
        whisper_free(ctx);
        return -3; // Memory allocation failure
    }

    for (int i = 0; i < num_samples; i++) {
        audio_data[i] = (float)pcm_data[i] / 32768.0f;
    }
    free(pcm_data);

    // Perform transcription
    struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    if (whisper_full(ctx, params, audio_data, num_samples) != 0) {
        free(audio_data);
        whisper_free(ctx);
        return -4; // Transcription failed
    }

    free(audio_data);

    // Retrieve and write the transcription result
    const char *result = whisper_full_get_segment_text(ctx, 0);
    whisper_free(ctx);

    if (!result) {
        return -5; // Failed to retrieve transcription
    }

    NSString *output = [NSString stringWithUTF8String:result];
    NSError *error = nil;
    [output writeToFile:[NSString stringWithUTF8String:out_text_path]
             atomically:YES
               encoding:NSUTF8StringEncoding
                  error:&error];

    if (error) {
        return -6; // Failed to write output
    }

    return 0; // Success
}
