# DeepSeek Harness 桌面版

DeepSeek Harness（dsh）Web UI 的原生 macOS 客户端：以独立应用窗口内嵌
`http://127.0.0.1:3080`，并会在服务未启动时自动拉起 dsh。

## 构建与运行

```sh
./script/build_and_run.sh          # 一键：结束旧进程 → 编译 → 打包 .app → 启动
./script/build_and_run.sh --verify # 构建并校验进程在运行
```

产物输出到 `dist/DeepSeek Harness.app`。

## 使用

- 首次使用请先在窗口内的 **Settings → Models** 配置 DeepSeek API 密钥。
- 菜单栏 **视图 → 重新加载 / 在浏览器中打开 / 复制地址**。
- 菜单栏 **DeepSeek Harness → 登录时自动启动** 可让应用随登录启动。
- 应用会优先复用已运行的 3080 服务（例如之前配置的 LaunchAgent），
  只有服务不可达时才自行拉起，日志写入 `~/.dsh/dsh-desktop.log`。

## 要求

- macOS 13+
- 全局安装的 dsh：`npm i -g @deepseek-ai/dsh`
