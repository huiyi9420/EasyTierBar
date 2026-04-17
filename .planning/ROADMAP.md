# Roadmap

## Overview

| # | Phase | Goal | Requirements | Success Criteria |
|---|-------|------|-------------|------------------|
| 1 | Core App Structure | 搭建 Swift 菜单栏应用骨架，集成 easytier-cli service 管理连接 | UI-01, UI-02, SVC-01, SVC-02, SVC-03, SVC-04 | 图标显示状态，点击切换连接，退出停止服务 |
| 2 | Node Info Menu | 实现二级子菜单节点列表，解析 JSON，展示 7 字段信息 | UI-03, UI-04, UI-05, UI-06, UI-07 | 右键看到节点列表，全部字段正确显示 |
| 3 | CI/CD Pipeline | GitHub Actions 自动监听上游发版，自动构建发布 | CI-01, CI-02, CI-03, CI-04 | 手动触发 workflow 成功构建并发布 .app |

---

## Phase 1: Core App Structure

**Goal:** 搭建 Swift 菜单栏应用骨架，集成 easytier-cli service 管理连接

**Requirements:** UI-01, UI-02, SVC-01, SVC-02, SVC-03, SVC-04

**Success criteria:**
1. 应用启动后状态栏出现天线图标
2. 图标正确反映 easytier service 运行状态
3. 点击图标可切换连接（启动/停止）
4. 退出应用时停止服务
5. easytier-cli 从 app bundle Resources 加载

**UI hint:** no

---

## Phase 2: Node Info Menu

**Goal:** 实现二级子菜单节点列表，解析 JSON，展示全部字段

**Requirements:** UI-03, UI-04, UI-05, UI-06, UI-07

**Success criteria:**
1. 右键菜单显示"已连接节点"二级子菜单
2. 节点列表包含所有 7 个字段信息
3. 打开菜单时自动刷新状态
4. 关于对话框正常工作
5. 退出功能正常

**UI hint:** yes

---

## Phase 3: CI/CD Pipeline

**Goal:** GitHub Actions 自动监听上游 EasyTier 发版，自动下载、编译、打包、发布

**Requirements:** CI-01, CI-02, CI-03, CI-04

**Success criteria:**
1. workflow_dispatch 手动触发能成功运行
2. 自动下载最新 EasyTier macOS aarch64 二进制
3. Swift 编译成功
4. .app 打包正确（二进制在 Resources 目录）
5. Release 发布成功

**UI hint:** no
