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
