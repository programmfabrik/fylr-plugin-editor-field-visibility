# easydb-editor-field-visibility
Custom Mask Splitter to show / hide fields in Editor, depending on other fields. Right now, the triggerfield must be a custom-data-type-dante, in future it also can be bool, int or whatever.

This is a plugin for [easyDB 5](http://5.easydb.de/) with MaskSplitter `EditorFieldSelection`.

## configuration

As defined in `Splitter.config.yml` this masksplitter can be configured:
 
### Mask options

* Name of the observed field, which triggers the visibility of fields
* JSON-Config about the fields to hide. See example below

##### Example JSON-Config

~~~~
{
	"männlich": {
		"uri": "http://uri.gbv.de/terminology/gender/a0e9160d-2db0-4030-80df-c96b6bfc49e5",
		"fields": ["easydb_editor_field_visibility__eventblock.easydb_editor_field_visibility__eventblock__unterblock.unterfeld2"]
	},
	"unbekannt": {
		"uri": "http://uri.gbv.de/terminology/gender/bd847cc5-5583-4081-909f-37545090b77b",
		"fields": ["easydb_editor_field_visibility__eventblock.easydb_editor_field_visibility__eventblock__unterblock.unterfeld2", "depending_field_selection_test__eventblock.depending_field_selection_test__eventblock__unterblock.unterfeld3"]
	},
	"transgender": {
		"uri": "http://uri.gbv.de/terminology/gender/e8d90fc1-de50-416f-91bf-5650005813b8",
		"fields": ["easydb_editor_field_visibility__eventblock.easydb_editor_field_visibility__eventblock__unterblock.unterfeld3"]
	}
}
~~~~

## sources

The source code of this plugin is managed in a git repository at <https://github.com/programmfabrik/easydb-editor-field-visibility>. Please use [the issue tracker](https://github.com/programmfabrik/easydb-editor-field-visibility/issues) for bug reports and feature requests!
