# Flutter 无缝循环播放器

**目标**: 构建一个跨平台 (Windows + Android/iOS) 的本地音乐播放器，核心功能是基于**采样点 (Sample)** 级精度的无缝循环播放。

---

## 1. 核心设计理念 (Core Philosophy)

* **极致精度**: 采用**采样点 (Sample)** 级数据存储与控制，确保无缝连接时的绝对平滑。
* **差异化定位**:
  * **电脑端 (Windows)**: **生产与管理中心**。集成 `pymusiclooper` 进行音频分析，生成循环数据；提供强大的管理与播放界面。
  * **手机端 (Mobile)**: **纯粹播放终端**。轻量化设计，直接读取电脑端生成的音频与配置文件，随时随地享受无缝音乐。
* **单项目，多形态**: 使用同一个 Flutter 工程，但根据平台加载完全不同的 UI 布局，共享底层核心逻辑。

---

## 2. 技术栈选型 (Tech Stack)

| 组件                    | 选型                         | 理由                                                                                                          |
| :---------------------- | :--------------------------- | :------------------------------------------------------------------------------------------------------------ |
| **UI 框架**       | **Flutter**            | 跨平台能力强，渲染性能高，UI 定制灵活。                                                                       |
| **音频引擎**      | **media_kit**          | 基于**libmpv**。支持无缝播放 (Gapless)，格式兼容性极强，支持底层属性控制 (Properties)，适合高精度需求。 |
| **音频分析 (PC)** | **pymusiclooper**      | Python 命令行工具。利用其成熟的算法自动提取最佳循环点。                                                       |
| **数据存储**      | **JSON**               | 自定义结构，存储采样率与循环点，通用性强，易于跨端解析。                                                      |
| **状态管理**      | *待定* (Provider/Riverpod) | 用于管理播放列表、当前歌曲状态等。                                                                            |

---

## 3. 架构设计 (Architecture)

采用 **"One Project, Multiple Layouts"** (单工程，多布局) 策略。

### 📂 目录结构规划

```text
lib/
├── core/                // 核心逻辑 (全平台共用)
│   ├── audio/           // 音频服务 (封装 media_kit)
│   ├── data/            // 数据模型 (LoopConfig, Song)
│   ├── utils/           // 工具类 (JSON解析, 采样转时间)
│   └── services/        // 外部服务 (调用 pymusiclooper)
├── ui/                  // 界面层 (按平台区分)
│   ├── desktop/         // 💻 Windows 专用界面
│   │   ├── analysis/    // 分析面板 (调用 Python)
│   │   ├── playlist/    // 桌面级列表管理
│   │   └── player_ui/   // 桌面播放器 UI
│   └── mobile/          // 📱 Android/iOS 专用界面
│       ├── home/        // 手机主页
│       └── player_page/ // 沉浸式播放页 (大封面, 触摸交互)
└── main.dart            // 入口 (判断平台 -> 加载对应 UI)
```

---

## 4. 核心数据格式 (Loop Configuration)

文件命名: `loop_config.json` (或类似的数据库文件)
**关键**: 必须记录 `sample_rate` (采样率)，以便将 Sample 转换为时间。

```json
{
  "version": "1.0",
  "library": [
    {
      "filename": "01.ogg",
      "title": "BGM_Title",
      "artist": "Artist_Name",
      "sample_rate": 44100,        // 核心参数：采样率
      "total_samples": 15876000,   // 总采样数 (校验用)
      "loops": [
        {
          "start_point": 2158092,  // 精确循环起点 (Sample Index)
          "end_point": 5819712,    // 精确循环终点 (Sample Index)
          "score": 0.98,           // 推荐度评分
          "is_primary": true       // 是否为默认循环段
        }
      ]
    }
  ]
}
```

---

## 5. 工作流 (Workflow)

### 阶段一：电脑端生产 (Windows)

1. 用户导入音频文件/文件夹。
2. App 后台调用 `pymusiclooper` (CLI) 分析音频。
3. 获取分析结果 (采样点数据)，写入 `loop_config.json`。
4. 用户在 App 内试听，确认无缝效果。

### 阶段二：同步 (Sync)

1. 用户将 **音频文件** 和 **`loop_config.json`** 传输到手机 (通过 USB/网盘/局域网)。

### 阶段三：手机端消费 (Mobile)

1. App 启动，读取 `loop_config.json` 建立索引。
2. 用户点击播放 -> `media_kit` 加载音频。
3. **循环逻辑**:
   * 读取 `sample_rate` 和 `start/end_point`。
   * 底层设置 `loop-file` 或在到达 `end_point` 时精确 Seek 回 `start_point`。
4. 实现完美无缝循环。

---

*Validated by cpu & Lev Zenith*
