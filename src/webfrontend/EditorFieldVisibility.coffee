# { "capture_journey": { "value": "http://uri.gbv.de/terminology/prizepapers_journey_type/f005efa8-7340-4b45-bb52-77ce42a42e25", "fields": ["journey__mehrfach.field1", "journey__mehrfach.journey__mehrfach__mehrfach2.bool"] }, "forced_journey": { "value": "http://uri.gbv.de/terminology/prizepapers_journey_type/db0ecf20-96ca-45bf-b0c2-eb2097adf1f0", "fields": ["place_end_intended", "capture"] }, "journey": { "value": "http://uri.gbv.de/terminology/prizepapers_journey_type/94b943b7-ee9f-4818-8b8e-d7d4beef58fb", "fields": ["place_end_intended", "capture", "journey__mehrfach.journey__mehrfach__mehrfach2.bool", "journey__mehrfach.journey__mehrfach__mehrfach2.sex"] } }


# list of hidden fields, which will be deleted if "save"-button is triggered
hiddenSplitterFields = []

class ez5.EditorFieldVisibility extends CustomMaskSplitter

  isSimpleSplit: ->
    false

  isEnabledForNested: ->
    return true

  ##########################################################################################
  # get a fieldnames <-> field - concordances from a list of fields
  __getFieldNamesFieldConcordanceFromFieldList: (fieldList)->
    fieldsToReturn = {}
    for field in fieldList
      # is it a nested row? than change point to correct object
      if field.__cls == 'NestedRow'
        field = field._field
      if field?.FieldSchema?.kind == 'field' || field?.FieldSchema?.kind == 'link'
        entryKey = field['FieldSchema']['_full_name']
        fieldsToReturn[entryKey] = field;
      if field?.FieldSchema?.kind == 'linked-table'
        # push "linked table" itself to list
        entryKey = field['FieldSchema']['_full_name']
        fieldsToReturn[entryKey] = field;
        # get all fields below the linked table
        nextLevelFieldsToReturn = @__getFieldNamesFieldConcordanceFromFieldList(field.mask.fields)
        for attrname, val of nextLevelFieldsToReturn
          fieldsToReturn[attrname] = nextLevelFieldsToReturn[attrname]
    return fieldsToReturn

  ##########################################################################################
  # get a list of fieldnames inside of this splitter
  __getListOfFieldNamesInsideSplitter: (fieldList)->
    list = @__getFieldNamesFieldConcordanceFromFieldList(fieldList)
    resultList = []
    for key, entry of list
      resultList.push key
    return resultList

  __getFlatListOfAffectedSplitterFields: (innerSplitterFields, prefix = '') ->
    #console.warn "f:__getFlatListOfAffectedSplitterFields"
    #console.log "with innerSplitterFields", innerSplitterFields
    fieldList = []

    # is array?
    for fieldName, field of innerSplitterFields

      #########################################
      # NESTED as field
      # if name contains "_nested:" and not contains ":rendered", if contains fields below
      if (fieldName.indexOf('_nested:') > -1) && (fieldName.indexOf(':rendered') > -1)
        #console.error "nested field:rendered"
        #console.log field
        cleanedFieldName = fieldName.replace(/_nested:/g, '')
        cleanedFieldName = cleanedFieldName.replace(/:rendered/g, '')
        if prefix != ''
          fieldName = prefix + '.' + cleanedFieldName
        else
          fieldName = cleanedFieldName
        fieldName = @objecttype + '.' + fieldName
        #console.error fieldName
        if @splitterFieldNames.indexOf(fieldName) != -1
          fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement()

      #########################################
      # NESTED
      # if name contains "_nested:" and not contains ":rendered", if contains fields below
      if (fieldName.indexOf('_nested:') > -1) && (fieldName.indexOf(':rendered') == -1)
        #console.log "nested field, not rendered"
        #console.log field
        for fieldEntry in field
          cleanedFieldName = fieldName.replace(/_nested:/g, '')
          if prefix != ''
            newPrefix = prefix + '.' + cleanedFieldName
          else
            newPrefix = cleanedFieldName
          fields = @__getFlatListOfAffectedSplitterFields(fieldEntry, newPrefix)
          fieldList = fieldList.concat fields

      #########################################
      # FIELD
      if fieldName.indexOf('_nested:') == -1 &&  (fieldName.indexOf(':rendered') > -1)
        #console.warn "is normal field, push"
        if prefix != ''
          fieldName = prefix + '.' + fieldName.replace(':rendered', '')
        else
          fieldName = fieldName.replace(':rendered', '')
        fieldName = field.opts.field.__dbg_full_name
        #console.log fieldName
        fieldName = fieldName.replace(/_nested:/g, '')
        #console.log fieldName
        #console.log @splitterFieldNames
        if @splitterFieldNames.indexOf(fieldName) != -1
          fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement(), 'type' : field._field.ColumnSchema.type
          #console.warn "push done!"

    return fieldList

  ##########################################################################################
  # main methode
  renderField: (opts) ->
    that = @

    # name of the observed field
    observedFieldName = @getDataOptions().observedfield

    # actual _objecttype
    @objecttype = opts.top_level_data._objecttype

    @splitterFieldNames = []

    # get inner fields
    innerFields = @renderInnerFields(opts)

    # no action in detail-mode
    if opts.mode == "detail"
      return innerFields

    jsonMap = @getDataOptions().jsonmap

    #console.log jsonMap

    if CUI.util.isEmpty(jsonMap)
      return innerFields
    else
      jsonMap = JSON.parse(jsonMap)

    # Renderer given?
    fieldsRendererPlain = @__customFieldsRenderer.fields[0]
    if fieldsRendererPlain not instanceof FieldsRendererPlain
      return innerFields
    innerSplitterFields = fieldsRendererPlain.getFields() or []
    if not innerSplitterFields
      return innerFields

    console.log "innerSplitterFields", innerSplitterFields
    @splitterFieldNames = @__getListOfFieldNamesInsideSplitter(innerSplitterFields)
    console.error "splitterFieldNames",  @splitterFieldNames

    console.error "opts.data", opts.data
    #console.error "fields", fields
    console.error @__getFlatListOfAffectedSplitterFields(opts.data)

    for splitterField in @__getFlatListOfAffectedSplitterFields(opts.data)
      if splitterField.name == observedFieldName
        # get type of observed field
        columnType = splitterField.type
        observedField = splitterField.field
    console.log "observedField", observedField
    console.log "columnType", columnType

    # rerender if editor changes
    CUI.Events.listen
      type: ["editor-changed"]
      call: (ev, info) =>
        @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName)

    @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName)

    return innerFields

  ##########################################################################################
  # show or hide fields, depending on jsonMap and oberservedfield-value
  __manageVisibilitys: (opts, columnType, observedField, jsonMap, observedFieldName) ->
    console.warn "f: __manageVisibilitys"
    hiddenSplitterFields = []
    #console.log opts

    # get Value from observed field
    observedFieldValue = ''
    #console.log jsonMap

    # make a list of field's names, which are in the splitter and may be shown or hidden
    actionFields = []
    console.log "opts.data", opts.data
    actionFields = @__getFlatListOfAffectedSplitterFields(opts.data)
    console.error actionFields

    #########################################
    # if columnType == CustomDataTypeDANTE
    #########################################
    if columnType == 'custom:base.custom-data-type-dante.dante'
      console.log "columnType = DANTE!"
      dataAsString = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      dataAsJson = JSON.parse dataAsString
      observedFieldValue = dataAsJson.conceptURI
      if ! CUI.util.isEmpty(observedFieldValue)
        observedFieldValue = observedFieldValue.replace('https', 'http')
        console.log "observedFieldValue", observedFieldValue

    #########################################
    # if columnType == 'bool'
    #########################################
    if columnType == 'boolean'
      console.error "columnType: boool"
      observedFieldValue = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      #console.warn observedFieldValue
      if observedFieldValue == ''
        observedFieldValue = 'false'
      #console.log "data:" + observedFieldValue
      #console.log "actionFields:", actionFields

    # if observedFieldValue is empty --> hide all fields, except the observed field
    if CUI.util.isEmpty(observedFieldValue) # || CUI.util.isEmpty(jsonMap[observedFieldValue]
      for actionField in actionFields
        #console.log actionField
        # dont hide the observed field
        if actionField.name != observedFieldName
          # dont hide a nested-block, if observedField is in that nested
          if observedFieldName.indexOf(actionField.name) == -1
            CUI.dom.hideElement(actionField.element)
    # if observed field is not empty, show / hide fields in splitter, depending on json-map
    else
      #console.error "jsonMap",jsonMap
      console.log "observedFieldValue:" + observedFieldValue
      for actionField in actionFields
        if actionField.name != observedFieldName
          # try to find observedFieldValue in jsonmap
          foundInMap = false
          for jsonMapEntryName, jsonMapValue of jsonMap
            # if value of observedfield matches jsonMapEntry
            #console.log "jsonMapValue:", jsonMapValue
            if jsonMapValue?.value.trim() == observedFieldValue
              if jsonMapValue?.fields.length > 0
                foundInMap = true
              # compare actionFieldName and jsonMapFields and hide or show
              if jsonMapValue?.fields.indexOf(actionField.name) != -1
                #console.log "hide element"
                #console.log actionField
                CUI.dom.hideElement(actionField.element)
                hiddenSplitterFields.push actionField
                #console.log hiddenSplitterFields
              else
                #console.log "show element!"
                CUI.dom.showElement(actionField.element)
              break
          # if observedFieldValue not in jsonMap, show all fields
          if ! foundInMap
            CUI.dom.showElement(actionField.element)

  ##########################################################################################
  # make Option out of linked-table
  __getOptionsFromLinkedTable: (linkedField)->
    newOptions = []
    for field in linkedField.mask.fields
      if field.kind == 'field'
        newOptions.push @__getOptionFromField(field)
      if field.kind == 'linked-table'
        newOptions = newOptions.concat @__getOptionsFromLinkedTable(field)
    return newOptions

  ##########################################################################################
  # make Option from Field
  __getOptionFromField: (field, complex) ->
    newOption =
      value : field._full_name
      text : field._column._name_localized + ' [' + field.column_name_hint + '] ("' + field._full_name + '")'
    return newOption

  ##########################################################################################
  # get Options from MaskSettings
  getOptions: ->
    fieldOptions = []
    if @opts?.maskEditor
      fields = @opts.maskEditor.opts.schema.fields
      for field in fields
        if field.kind == 'field'
          fieldOptions.push @__getOptionFromField(field)
        if field.kind == 'linked-table'
          test = @__getOptionsFromLinkedTable(field)
          fieldOptions = fieldOptions.concat test
    maskOptions = [
      form:
        label: $$('editor.field.visibility.nameofobservedfield')
      type: CUI.Select
      name: "observedfield"
      options: fieldOptions
      ,
        form:
          label: $$('editor.field.visibility.map')
        type: CUI.Input
        name: "jsonmap"
    ]
    maskOptions

  trashable: ->
    true
CUI.ready =>
  MaskSplitter.plugins.registerPlugin(ez5.EditorFieldVisibility)

##########################################################################################
# also register an EditorPlugin to clear hidden fields inside the editor-fields-visibility-Splitter
##########################################################################################

class ez5.EditorFieldVisibiliyClearHiddenFields extends ez5.EditorPlugin

  checkForm: (opts) ->
    data = opts.resultObject.getData()
    #console.warn data
    #console.warn "hiddenSplitterFields", hiddenSplitterFields
    #console.log "mask changed --> show or hide fields in editor!"
    #console.log opts
    @

  #onSave: (opts) ->#
    #data = opts.resultObject.getData()
    #console.warn "hiddenSplitterFields", hiddenSplitterFields
    #for hiddenFieldsName in hiddenSplitterFields
    #  data[data._objecttype][hiddenFieldsName] = null

    # checken, ob das auch mit wiederholfenldern etc funktioniert....
    ########
    ########
    ########  TODO TODO TODO
    ########

    #opts.resultObject.setData(data)

    #problems = []
    #return problems

ez5.session_ready ->
  Editor.plugins.registerPlugin(ez5.EditorFieldVisibiliyClearHiddenFields)
