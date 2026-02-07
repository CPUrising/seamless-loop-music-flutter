#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// minimp3 单头文件库
#define MINIMP3_IMPLEMENTATION
#include "minimp3.h"
#include "minimp3_ex.h"

#ifdef __cplusplus
extern "C" {
#endif

// MP3 解码器句柄
typedef struct {
    mp3dec_ex_t dec;
    int sample_rate;
    int channels;
    uint64_t samples;
} Mp3Decoder;

// 打开 MP3 文件
Mp3Decoder* mp3_open(const char* filename) {
    Mp3Decoder* decoder = (Mp3Decoder*)malloc(sizeof(Mp3Decoder));
    if (!decoder) return NULL;

    if (mp3dec_ex_open(&decoder->dec, filename, MP3D_SEEK_TO_SAMPLE) != 0) {
        free(decoder);
        return NULL;
    }

    decoder->sample_rate = decoder->dec.info.hz;
    decoder->channels = decoder->dec.info.channels;
    decoder->samples = decoder->dec.samples;

    return decoder;
}

// 读取采样数据（返回 float 格式）
int mp3_read_samples(Mp3Decoder* decoder, int64_t start_sample, int count, float* buffer) {
    if (!decoder || !buffer) return -1;

    // 跳转到指定位置
    if (mp3dec_ex_seek(&decoder->dec, start_sample) != 0) {
        return -1;
    }

    // 分配临时缓冲区（minimp3 返回 int16）
    int total_samples = count * decoder->channels;
    mp3d_sample_t* temp_buffer = (mp3d_sample_t*)malloc(total_samples * sizeof(mp3d_sample_t));
    if (!temp_buffer) return -1;

    // 读取数据
    size_t samples_read = mp3dec_ex_read(&decoder->dec, temp_buffer, total_samples);
    
    // 转换为 float（归一化到 -1.0 ~ 1.0）
    // 只取第一个声道（左声道）
    int mono_samples = (int)(samples_read / decoder->channels);
    for (int i = 0; i < mono_samples; i++) {
        buffer[i] = temp_buffer[i * decoder->channels] / 32768.0f;
    }

    free(temp_buffer);
    return mono_samples;
}

// 获取采样率
int mp3_get_sample_rate(Mp3Decoder* decoder) {
    return decoder ? decoder->sample_rate : 0;
}

// 获取声道数
int mp3_get_channels(Mp3Decoder* decoder) {
    return decoder ? decoder->channels : 0;
}

// 获取总采样数（单声道）
int64_t mp3_get_total_samples(Mp3Decoder* decoder) {
    return decoder ? (int64_t)(decoder->samples / decoder->channels) : 0;
}

// 关闭解码器
void mp3_close(Mp3Decoder* decoder) {
    if (decoder) {
        mp3dec_ex_close(&decoder->dec);
        free(decoder);
    }
}

#ifdef __cplusplus
}
#endif
