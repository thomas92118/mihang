# Godot 本地运行环境

项目内运行时：`.tools/Godot.app/Contents/MacOS/Godot`。已在 Apple Silicon macOS 上执行 `--version`，结果为 `4.7.2.stable.official.ed1daf0bf`，并通过 `codesign --verify --deep --strict` 校验。

来源：[Godot 官方 macOS 下载页](https://godotengine.org/download/macos/)，2026-09-13 获取的稳定版。运行时自包含，不需要系统安装；`.tools/` 不应提交版本控制。

在项目目录启动游戏：

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

导入资源后退出，再运行 120 帧检查启动错误：

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --import
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 120
```

打开编辑器：

```sh
.tools/Godot.app/Contents/MacOS/Godot --editor --path .
```
`--check-only --script res://scripts/example.gd` 只解析指定脚本，不能替代游戏运行验证。`--import` 会等待导入完成后退出，不能仅用第一帧就退出的 `--quit` 代替。

截图需要正常渲染窗口；`--headless` 使用 dummy renderer。脚本应等待 `RenderingServer.frame_post_draw`，再调用 `get_viewport().get_texture().get_image().save_png(path)`；过早在 `_ready()` 读取可能得到黑图。

Compatibility 渲染器支持普通 `Environment.fog_enabled` 深度/高度雾；体积雾只支持 Forward+。见 [命令行文档](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)、[Viewport 文档](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-texture)、[渲染器功能](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)。
