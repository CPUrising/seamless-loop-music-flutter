cmake_minimum_required(VERSION 3.14)
project(audio_decoders)

# 设置 C 标准
set(CMAKE_C_STANDARD 11)

# ========== MP3 解码器 ==========
add_library(mp3_decoder SHARED
    mp3_decoder.c
)

target_include_directories(mp3_decoder PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Windows 特定设置
if(WIN32)
    set_target_properties(mp3_decoder PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

# ========== OGG 解码器 ==========
add_library(ogg_decoder SHARED
    ogg_decoder.c
    stb_vorbis.c
)

target_include_directories(ogg_decoder PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Windows 特定设置
if(WIN32)
    set_target_properties(ogg_decoder PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

# ========== 安装规则 ==========
install(TARGETS mp3_decoder ogg_decoder
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
