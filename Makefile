APP_NAME = EasyTierBar
SOURCE_DIR = EasyTierBar
BUILD_DIR = build
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

SOURCES = $(SOURCE_DIR)/main.swift \
          $(SOURCE_DIR)/ConfigManager.swift \
          $(SOURCE_DIR)/ServiceManager.swift \
          $(SOURCE_DIR)/AppDelegate.swift

.PHONY: all clean

ICONSET = $(SOURCE_DIR)/AppIcon.iconset
ICNS = $(SOURCE_DIR)/AppIcon.icns

all: $(APP_BUNDLE)

$(ICNS): scripts/generate_icon.py
	python3 scripts/generate_icon.py
	@for s in 16 32 128 256 512; do \
		sips -z $$s $$s $(ICONSET)/icon_512x512@2x.png \
			--out $(ICONSET)/icon_$${s}x$${s}.png -s format png >/dev/null 2>&1; \
		d=$$((s * 2)); \
		sips -z $$d $$d $(ICONSET)/icon_512x512@2x.png \
			--out $(ICONSET)/icon_$${s}x$${s}@2x.png -s format png >/dev/null 2>&1; \
	done
	iconutil -c icns $(ICONSET) -o $(ICNS)

$(APP_BUNDLE): $(SOURCES) $(SOURCE_DIR)/Info.plist $(ICNS)
	@mkdir -p $(BUILD_DIR)
	swiftc -o $(BUILD_DIR)/$(APP_NAME) $(SOURCES) -framework Cocoa
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	mv $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp $(SOURCE_DIR)/Info.plist $(APP_BUNDLE)/Contents/
	cp $(ICNS) $(APP_BUNDLE)/Contents/Resources/
	@echo "Build complete: $(APP_BUNDLE)"

clean:
	rm -rf $(BUILD_DIR)
