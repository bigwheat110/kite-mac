# 代理说明

## 当前默认工作方式

- 默认只修改代码，不主动运行测试。
- 默认只修改代码，不主动执行完整的 build -> test -> restart -> commit -> push 流程。
- 默认不主动提交 commit。
- 默认不主动 push 到 `origin`。
- 默认主动重启 `KiteNative`，除非用户明确要求启动、重启或切到前台。

## 什么时候才执行这些操作

- 只有在用户明确要求“构建 / 测试 / 重启 / 提交 / 推送 / 打包”时，才执行对应步骤。
- 如果用户只是让助手修改界面、逻辑或文案，默认只改代码，不额外做测试和提交流程。
- 每次发布 release，都只把 `KiteNative.app` 发布到 `/Users/dyliu/Desktop/KiteNative-release/` 文件夹，不生成或保留 zip 包。
- 用户要求构建或重启用于体验时，默认构建 Release 版本，并使用 `/Users/dyliu/Desktop/KiteNative-release/KiteNative.app`。

## 测试相关要求

- 默认不要主动运行 `xcodebuild test`。
- UI 测试不应影响正式使用数据。
- 如需运行测试，应优先使用独立测试数据，不要重置用户平时使用的数据。
- Debug 运行数据必须和正式 Release 数据隔离，Debug 不得读写或污染正式 Release 的本地数据。
- 当前约定：Debug 使用 `~/Library/Application Support/KiteNative-Debug/app-state.json`，Release 使用 `~/Library/Application Support/KiteNative/app-state.json`。
- 需要迁移、复制、清理或重置正式 Release 数据时，必须先得到用户明确要求。

## 当前项目使用偏好

- 该项目当前以“用户本人手动体验”为主。
- 助手只负责改代码，用户自行体验效果。
- 如用户后续明确要求，再执行构建、测试、重启、提交或推送。
