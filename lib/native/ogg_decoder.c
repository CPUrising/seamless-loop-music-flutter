#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// stb_vorbis 单头文件库
#define STB_VORBIS_HEADER_ONLY
#include "stb_vorbis.c"

#ifdef __cplusplus
extern "C" {
#endif

// OGG 解码器句柄
typedef struct {
    stb_vorbis* decoder;
    int sample_rate;
    int channels;
    unsigned int total_samples;
} OggDecoder;

// 打开 OGG 文件
OggDecoder* ogg_open(const char* filename) {
    OggDecoder* decoder = (OggDecoder*)malloc(sizeof(OggDecoder));
    if (!decoder) return NULL;

    int error = 0;
    decoder->decoder = stb_vorbis_open_filename(filename, &error, NULL);
    
    if (!decoder->decoder || error != 0) {
        free(decoder);
        return NULL;
    }

    // 获取文件信息
    stb_vorbis_info info = stb_vorbis_get_info(decoder->decoder);
    decoder->sample_rate = info.sample_rate;
    decoder->channels = info.channels;
    decoder->total_samples = stb_vorbis_stream_length_in_samples(decoder->decoder);

    return decoder;
}

// 读取采样数据（返回 float 格式）
int ogg_read_samples(OggDecoder* decoder, int64_t start_sample, int count, float* buffer) {
    if (!decoder || !buffer) return -1;

    // 跳转到指定位置
    if (stb_vorbis_seek(decoder->decoder, (unsigned int)start_sample) == 0) {
        return -1;
    }

    // 分配临时缓冲区（stb_vorbis 返回 float，但是交错格式）
    int total_samples = count * decoder->channels;
    float* temp_buffer = (float*)malloc(total_samples * sizeof(float));
    if (!temp_buffer) return -1;

    // 读取数据（交错格式）
    int samples_read = stb_vorbis_get_samples_float_interleaved(
        decoder->decoder, 
        decoder->channels, 
        temp_buffer, 
        total_samples
    );

    // 转换为单声道（只取左声道）
    for (int i = 0; i < samples_read; i++) {
        buffer[i] = temp_buffer[i * decoder->channels];
    }

    free(temp_buffer);
    return samples_read;
}

// 获取采样率
int ogg_get_sample_rate(OggDecoder* decoder) {
    return decoder ? decoder->sample_rate : 0;
}

// 获取声道数
int ogg_get_channels(OggDecoder* decoder) {
    return decoder ? decoder->channels : 0;
}

// 获取总采样数（单声道）
int64_t ogg_get_total_samples(OggDecoder* decoder) {
    return decoder ? (int64_t)decoder->total_samples : 0;
}

// 关闭解码器
void ogg_close(OggDecoder* decoder) {
    if (decoder) {
        if (decoder->decoder) {
            stb_vorbis_close(decoder->decoder);
        }
        free(decoder);
    }
}

#ifdef __cplusplus
}
#endif
