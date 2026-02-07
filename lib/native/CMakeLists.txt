cmake_minimum_required(VERSION 3.14)
project(mp3_decoder)

# 设置 C 标准
set(CMAKE_C_STANDARD 11)

# 创建共享库
add_library(mp3_decoder SHARED
    mp3_decoder.c
)

# 包含目录
target_include_directories(mp3_decoder PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Windows 特定设置
if(WIN32)
    # 导出所有符号
    set_target_properties(mp3_decoder PROPERTIES
        WINDOWS_EXPORT_ALL_SYMBOLS ON
    )
endif()

# 安装规则
install(TARGETS mp3_decoder
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)
