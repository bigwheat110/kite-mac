# Kite iCloud 同步架构

## 目标

这份文档只服务 Kite 第一版 Apple 生态多端同步落地，不做完整跨平台 SaaS 架构设计。

当前目标：

- Mac 和 iPhone 使用同一份习惯数据
- 用户不需要提供服务器
- 数据使用用户自己的 Apple ID / iCloud 承载
- 先跑通个人多端同步，不做多人共享

## 当前主线

第一版同步主线改为：

- Core Data
- CloudKit
- `NSPersistentCloudKitContainer`
- 用户私有 iCloud 数据库

自建 `FastAPI + PostgreSQL` 后端不再作为当前主线，只保留为未来跨平台或 SaaS 化时的备选。

## 为什么不用自建服务器

自建服务器的优点是灵活，后续可以做 Web、团队、后台管理和跨平台。

但对 Kite 当前阶段来说，它会带来明显门槛：

- 用户需要信任或配置服务器
- 需要处理部署、运维、备份和 HTTPS
- App 首版会被后端复杂度拖慢

Kite 第一版先面向 Apple 生态，使用 iCloud 更符合普通用户预期。

## 为什么不用 OneDrive / iCloud Drive 文件同步

Obsidian 适合文件夹同步，是因为它的核心数据天然是一组 Markdown 文件。

Kite 当前是结构化 App 状态，包含习惯、打卡、每日覆盖和隐藏记录。直接同步一个 JSON 文件或文件夹会有几个问题：

- Mac/iOS 同时编辑时容易产生文件冲突
- 很难做字段级合并
- iOS 沙盒和文件选择会增加使用成本
- 后续结构化查询、软删除和冲突提示会变别扭

因此第一版不采用 OneDrive、Dropbox 或 iCloud Drive 文件夹同步作为主线。

## 当前边界

第一版只做：

- 个人数据同步
- macOS + iOS
- 用户私有 iCloud 数据库
- 习惯和打卡相关数据

第一版不做：

- Windows / Android / Web
- 团队和共享
- 自建服务器
- 实时协同
- 复杂冲突 UI
