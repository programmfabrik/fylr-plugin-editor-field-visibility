ZIP_NAME ?= "EditorFieldVisibility.zip"

PLUGIN_NAME = easydb-editor-field-visibility
PLUGIN_PATH = easydb-editor-field-visibility-plugin

EASYDB_LIB = easydb-library
L10N_FILES = l10n/$(PLUGIN_NAME).csv

COFFEE_FILES = EditorFieldVisibility.coffee

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

all: build ## build all

build: clean ## clean, compile, copy files to build folder

					mkdir -p build
					mkdir -p build/$(PLUGIN_NAME)
					mkdir -p build/$(PLUGIN_NAME)/webfrontend
					mkdir -p build/$(PLUGIN_NAME)/l10n

					mkdir -p src/tmp # build code from coffee
					cp src/webfrontend/*.coffee src/tmp
					cd src/tmp && coffee -b --compile ${COFFEE_FILES} # bare-parameter is obligatory!
					cat src/tmp/*.js > build/$(PLUGIN_NAME)/webfrontend/fylr-editor-field-visibility.js

					rm -rf src/tmp # clean tmp

					cp l10n/fylr-editor-field-visibility.csv build/$(PLUGIN_NAME)/l10n/fylr-editor-field-visibility.csv # copy l10n

					cp manifest.master.yml build/$(PLUGIN_NAME)/manifest.yml # copy manifest

clean: ## clean
				rm -rf build

zip: build ## build zip file
			cd build && zip ${ZIP_NAME} -r $(PLUGIN_NAME)/
