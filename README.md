> This Plugin / Repo is being maintained by a community of developers.
There is no warranty given or bug fixing guarantee; especially not by
Programmfabrik GmbH. Please use the github issue tracking to report bugs
and self organize bug fixing. Feel free to directly contact the committing
developers.

# easydb-editor-field-visibility
Custom Mask Splitter to hide fields in Editor, depending on another fields value. Right now, the triggerfield must be a custom-data-type-dante or a boolean-field

This is a plugin for [easyDB 5](http://5.easydb.de/) with MaskSplitter `EditorFieldSelection`.

<img src="https://github.com/programmfabrik/easydb-editor-field-visibility/blob/master/examples/images/example1.gif" />
<img src="https://github.com/programmfabrik/easydb-editor-field-visibility/blob/master/examples/images/example2.gif" />

## configuration

This masksplitter can be configured:

### Mask options

* Name of the observed field, which triggers the visibility of fields
* JSON-Map about the fields to hide. See example below
* JSON-Path with which the JSON-Map starts

##### Example JSON-Config

~~~~
{
	"capture_journey": {
		"value": "http://uri.gbv.de/terminology/prizepapers_journey_type/f005efa8-7340-4b45-bb52-77ce42a42e25",
		"fields": ["journey.journey__mehrfach.field1", "journey.journey__mehrfach.journey__mehrfach__mehrfach2.bool"]
	},
	"forced_journey": {
		"value": "http://uri.gbv.de/terminology/prizepapers_journey_type/db0ecf20-96ca-45bf-b0c2-eb2097adf1f0",
		"fields": ["journey.place_end_intended", "journey.capture", "journey.journey__mehrfach.journey__mehrfach__mehrfach2"]
	},
	"journey": {
		"value": "http://uri.gbv.de/terminology/prizepapers_journey_type/94b943b7-ee9f-4818-8b8e-d7d4beef58fb",
		"fields": ["journey.place_end_intended", "journey.capture", "journey.journey__mehrfach.journey__mehrfach__mehrfach2.bool", "journey.journey__mehrfach.journey__mehrfach__mehrfach2.sex"]
	}
}
~~~~

## sources

The source code of this plugin is managed in a git repository at <https://github.com/programmfabrik/easydb-editor-field-visibility>. Please use [the issue tracker](https://github.com/programmfabrik/easydb-editor-field-visibility/issues) for bug reports and feature requests!
