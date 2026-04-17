---
wave: 2
depends_on:
  - 01
  - 02
files_modified:
  - EasyTierBar/main.swift
  - EasyTierBar/Info.plist
autonomous: true
requirements:
  - UI-01
  - SVC-04
objective: 更新入口文件和 Info.plist，完成构建脚本配置
---

# Plan 04: main.swift + Info.plist — 入口和构建配置

## Objective

重写 `main.swift` 为最小入口点（仅创建 AppDelegate 并启动 run loop），更新 `Info.plist` 添加版本信息，并提供构建脚本用于 swiftc 编译多文件项目。

## Context

从 CONTEXT.md 决策：
- 4 文件结构：main.swift（入口）+ AppDelegate.swift + ServiceManager.swift + ConfigManager.swift
- 构建方式：swiftc 命令行编译

## Tasks

### Task 1: 重写 main.swift 为最小入口

<read_first>
- EasyTierBar/main.swift — 当前完整内容（将被替换）
- EasyTierBar/AppDelegate.swift — 确认 AppDelegate 不在 main.swift 中
</read_first>

<action>
将 `EasyTierBar/main.swift` 替换为最小入口：

```swift
import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```
</action>

<acceptance_criteria>
- `EasyTierBar/main.swift` 仅包含 5 行代码
- 不包含任何 class 定义
- 使用 `setActivationPolicy(.accessory)` 隐藏 Dock 图标
- AppDelegate 由 AppDelegate.swift 提供
</acceptance_criteria>

### Task 2: 更新 Info.plist

<read_first>
- EasyTierBar/Info.plist — 当前配置
</read_first>

<action>
在 `EasyTierBar/Info.plist` 的 `<dict>` 中添加版本信息（如果不存在）：

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

确保已有：
- `LSUIElement = true`（隐藏 Dock 图标）
- `CFBundleName = EasyTierBar`
- `CFBundleExecutable = EasyTierBar`
</action>

<acceptance_criteria>
- Info.plist 包含 CFBundleShortVersionString = "1.0.0"
- Info.plist 包含 CFBundleVersion = "1"
- Info.plist 包含 LSUIElement = true
</acceptance_criteria>

### Task 3: 创建构建脚本

<read_first>
- EasyTierBar/ — 确认所有 Swift 文件列表
</read_first>

<action>
创建文件 `Makefile`：

```makefile
APP_NAME = EasyTierBar
SOURCE_DIR = EasyTierBar
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

SOURCES = $(SOURCE_DIR)/main.swift \
          $(SOURCE_DIR)/ConfigManager.swift \
          $(SOURCE_DIR)/ServiceManager.swift \
          $(SOURCE_DIR)/AppDelegate.swift

.PHONY: all clean

all: $(APP_BUNDLE)

$(APP_BUNDLE): $(SOURCES) $(SOURCE_DIR)/Info.plist
	@mkdir -p $(BUILD_DIR)
	swiftc -o $(BUILD_DIR)/$(APP_NAME) $(SOURCES) -framework Cocoa
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	mv $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp $(SOURCE_DIR)/Info.plist $(APP_BUNDLE)/Contents/
	@echo "Build complete: $(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR)
```
</action>

<acceptance_criteria>
- `Makefile` 文件存在
- 包含所有 4 个 Swift 文件
- 使用 swiftc 编译
- 创建正确的 app bundle 目录结构（Contents/MacOS/、Contents/Resources/）
- 复制 Info.plist 到 Contents/
- 有 clean target
</acceptance_criteria>

## Verification

1. `EasyTierBar/main.swift` 是最小入口（<10 行）
2. Info.plist 包含版本号和 LSUIElement
3. Makefile 可编译全部 4 个文件
4. `make` 生成正确的 app bundle 结构
5. `make clean` 清理构建产物

## must_haves

- main.swift 最小入口
- Info.plist 版本信息
- Makefile 多文件编译
- 正确的 app bundle 目录结构
