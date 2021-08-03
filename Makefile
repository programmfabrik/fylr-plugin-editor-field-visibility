PLUGIN_NAME = easydb-editor-field-visibility
PLUGIN_PATH = easydb-editor-field-visibility-plugin

EASYDB_LIB = easydb-library
L10N_FILES = l10n/$(PLUGIN_NAME).csv

INSTALL_FILES = \
	$(WEB)/l10n/cultures.json \
	$(WEB)/l10n/de-DE.json \
	$(WEB)/l10n/en-US.json \
	$(JS) \
	manifest.yml

COFFEE_FILES = src/webfrontend/EditorFieldVisibility.coffee

all: build

include $(EASYDB_LIB)/tools/base-plugins.make
build: code $(L10N) buildinfojson

code: $(JS)

clean: clean-base

wipe: wipe-base
