###
  TODO TODO # TODO:

  bestehende Probleme:
  - wenn in einem Wiederholblock keine felder mehr sind, soll der ganze block weg sein, auch der Plus-Button etc..
###
class ez5.EditorFieldVisibility extends CustomMaskSplitter

  isSimpleSplit: ->
    false

  isEnabledForNested: ->
    return true

  ##########################################################################################
  # get a fieldnames <-> field - concordances from a list of fields
  ##########################################################################################

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
  ##########################################################################################

  __getListOfFieldNamesInsideSplitter: (fieldList)->
    list = @__getFieldNamesFieldConcordanceFromFieldList(fieldList)
    resultList = []
    for key, entry of list
      resultList.push key
    return resultList

  __getFlatListOfAffectedSplitterFields: (optsData, prefix = '') ->
    fieldList = []
    #console.warn "__getFlatListOfAffectedSplitterFields"
    #console.warn "optsData", optsData
    # is array?
    for fieldName, field of optsData
      if ! fieldName.startsWith '_version'
        #########################################
        # NESTED as field
        # if name contains "_nested:" and contains ":rendered", if contains fields below
        if (fieldName.indexOf('_nested:') > -1) && (fieldName.indexOf(':rendered') > -1)
          cleanedFieldName = fieldName.replace(/_nested:/g, '')
          cleanedFieldName = cleanedFieldName.replace(/:rendered/g, '')
          #console.warn "cleanedFieldName", cleanedFieldName
          if prefix != ''
            fieldName = prefix + '.' + cleanedFieldName
          else
            fieldName = cleanedFieldName
          fieldName = @objecttype + '.' + fieldName
          #console.warn "fieldName", fieldName
          if @splitterFieldNames.indexOf(fieldName) != -1
            fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement()
          # it is the block and not a field
          else
            fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement(), 'type' : 'block'
            #console.warn "ist jetzt drin!!2"

        #########################################
        # NESTED
        # if name contains "_nested:" and not contains ":rendered", if contains fields below
        if (fieldName.indexOf('_nested:') > -1) && (fieldName.indexOf(':rendered') == -1)
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
        if fieldName.indexOf('_nested:') == -1 && (fieldName.indexOf(':rendered') > -1)
          if prefix != ''
            fieldName = prefix + '.' + fieldName.replace(':rendered', '')
          else
            fieldName = fieldName.replace(':rendered', '')
          fieldName = field.opts.field.__dbg_full_name
          fieldName = fieldName.replace(/_nested:/g, '')
          fieldNameParts = fieldName.split('.')
          lastPartOfFieldName = fieldNameParts.pop()
          if @splitterFieldNames.indexOf(fieldName) != -1
            fieldType = field._field.ColumnSchema.type
            if fieldType.indexOf('custom-data-type') > 0
              isCustomType = true
            else
              isCustomType = false
            fieldList.push 'dataTarget' : lastPartOfFieldName, 'dataReference' : optsData, 'name' : fieldName, 'field' : field, 'element' : field.getElement(), 'type' : fieldType, 'isCustomType' : isCustomType

    return fieldList

  ##########################################################################################
  # main methode
  ##########################################################################################

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
    jsonTargetPath = @getDataOptions().jsontargetpath

    if CUI.util.isEmpty(jsonMap)
      return innerFields
    else
      jsonMap = JSON.parse(jsonMap)

    for jsonMapKey, jsonMapEntry of jsonMap
      for fieldsValue, fieldsKey in jsonMapEntry.fields
        jsonMap[jsonMapKey].fields[fieldsKey] = jsonTargetPath + '.' + jsonMapEntry.fields[fieldsKey]

    # Renderer given?
    fieldsRendererPlain = @__customFieldsRenderer.fields[0]
    if fieldsRendererPlain not instanceof FieldsRendererPlain
      return innerFields
    innerSplitterFields = fieldsRendererPlain.getFields() or []
    if not innerSplitterFields
      return innerFields

    @splitterFieldNames = @__getListOfFieldNamesInsideSplitter(innerSplitterFields)

    for splitterField in @__getFlatListOfAffectedSplitterFields(opts.data)
      if splitterField.name == observedFieldName
        # get type of observed field
        columnType = splitterField.type
        observedField = splitterField.field

    CUI.Events.listen
      type: ["data-changed"]
      node: innerFields[0]
      call: (ev, info) =>
        @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName)

    CUI.Events.listen
      type: ["editor-changed"]
      call: (ev, info) =>
        @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName)

    @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName)

    return innerFields

  ##########################################################################################
  # show or hide fields, depending on jsonMap and oberservedfield-value
  ##########################################################################################

  __manageVisibilitys: (opts, columnType, observedField, jsonMap, observedFieldName) ->
    that = @

    # get Value from observed field
    observedFieldValue = ''

    # make a list of field's names, which are in the splitter and may be shown or hidden
    actionFields = []
    #console.error "opts.data", opts.data
    actionFields = @__getFlatListOfAffectedSplitterFields(opts.data)

    #########################################
    # observedfield: if columnType == CustomDataTypeDANTE
    #########################################
    if columnType == 'custom:base.custom-data-type-dante.dante'
      dataAsString = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      if ! CUI.util.isEmpty(dataAsString)
        dataAsJson = JSON.parse dataAsString
        observedFieldValue = dataAsJson.conceptURI
        if observedFieldValue
          observedFieldValue = observedFieldValue.replace('https', 'http')
      else
        observedFieldValue = null

    #########################################
    # observedfield: if columnType == 'bool'
    #########################################
    if columnType == 'boolean'
      observedFieldValue = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      if observedFieldValue == ''
        observedFieldValue = 'false'

    ##################################################################################
    # if observedFieldValue is empty --> hide all fields, except the observed field
    ##################################################################################
    if CUI.util.isEmpty(observedFieldValue) # || CUI.util.isEmpty(jsonMap[observedFieldValue]
      for actionField in actionFields
        # dont hide the observed field
        if actionField.name != observedFieldName
          # dont hide a nested-block, if observedField is in that nested
          if observedFieldName.indexOf(actionField.name) == -1
            that.hideAndClearActionField(actionField)

    ##################################################################################
    # if observed field is not empty, show / hide fields in splitter, depending on json-map
    ##################################################################################
    else
      #console.warn "observedFieldValue", observedFieldValue
      #console.warn "observedFieldName", observedFieldName
      #console.warn "jsonMap", jsonMap

      # check if a mapping exists in jsonmap for the given observedfieldvalue
      jsonMatchedMappingFields = false;
      for jsonMapEntryName, jsonMapValue of jsonMap
        #console.log "jsonMapEntryName", jsonMapEntryName
        #console.log "jsonMapValue", jsonMapValue
        if jsonMapValue?.value?.trim() == observedFieldValue
          if jsonMapValue?.fields
            jsonMatchedMappingFields = jsonMapValue.fields
            break;

      #console.warn jsonMatchedMappingFields
      #console.warn typeof jsonMatchedMappingFields

      # help activated? Then echo all actionfield.names in console
      if @getDataOptions()?.helpwithactionfieldnames == 1
        console.warn "List of actionfield-path-names inside the splitter:"
        for actionField in actionFields
          if actionField.name != observedFieldName
            console.log actionField.name

      # go through all fields in splitter and show or hide, depending on mapping
      for actionField in actionFields
        if actionField.name != observedFieldName
          #console.log "now in " + actionField.name
          if jsonMatchedMappingFields
            # console.log "111"
            # console.warn "jsonMatchedMappingFields.indexOf(actionField.name)", jsonMatchedMappingFields.indexOf(actionField.name)
            # console.warn "jsonMatchedMappingFields.includes(actionField.name)", jsonMatchedMappingFields.includes(actionField.name)
            if jsonMatchedMappingFields.indexOf(actionField.name) != -1 || jsonMatchedMappingFields.includes(actionField.name) != false
              #console.log "222"
              that.hideAndClearActionField(actionField)
            else
              CUI.dom.showElement(actionField.element)
          else
            CUI.dom.showElement(actionField.element)


  ##################################################################################
  # hide an clear a mask-field
  ##########################################################################################

  hideAndClearActionField: (actionField) ->
    #console.error actionField
    #console.log("hide field: " + actionField.name)
    domInput = CUI.dom.matchSelector(actionField.element, ".cui-data-field")[0]
    domData = CUI.dom.data(domInput, "element")

    if domData
      rowType = domData.constructor.name
    else
      rowType = ''

    # hide field
    CUI.dom.hideElement(actionField.element)

    # clear value of field
    if domData || actionField.isCustomType
        if actionField?.dataReference
          if actionField.dataReference[actionField.dataTarget]
            if typeof actionField.dataReference[actionField.dataTarget] == 'object'
              for deletionValue of actionField.dataReference[actionField.dataTarget]
                if actionField.dataReference[actionField.dataTarget][deletionValue]
                  if actionField.type == 'text_l10n' || actionField.type == 'text_l10n_oneline'
                    actionField.dataReference[actionField.dataTarget][deletionValue] = ''
                  else
                    delete actionField.dataReference[actionField.dataTarget][deletionValue]

        #console.error rowType,  actionField.type

        ##################################
        # hide multifield
        ##################################

        ##################################
        # easy to clear values
        ##################################
        easyTypes =
          'Input' : ''
          'Checkbox' : false
          'DateTime' : ''
          'NumberInput' : null

        if rowType of easyTypes
          domData.setValue(easyTypes[rowType])

        ##################################
        # clear more complex fields
        ##################################
        if rowType == 'MultiInput'
          for input in domData.__inputs
            input.setValue('')

        if actionField.type == 'daterange'
          for input in domData.getFields()
            input.setValue('')

        ##################################
        # clear custom-Types
        ##################################
        customDataTypes = [
          'custom:base.custom-data-type-dante.dante'
          'custom:base.custom-data-type-geonames.geonames'
          'custom:base.custom-data-type-getty.getty'
          'custom:base.custom-data-type-gnd.gnd'
          'custom:base.custom-data-type-gn250.gn250'
          'custom:base.custom-data-type-georef.georef'
          'custom:base.custom-data-type-gazetteer.gazetteer'
          'custom:base.custom-data-type-link.link'
          'custom:base.custom-data-type-gvk.gvk'
          'custom:base.custom-data-type-nomisma.nomisma'
        ]
        if actionField.type in customDataTypes

          actionField.field.setChanges()
          actionField.field.initOpts()

          if domData
            domData.unsetData()

          node = CUI.dom.matchSelector(actionField.element, ".customPluginEditorLayout")
          if ! node
            node = CUI.dom.matchSelector(actionField.element, ".dante_InlineSelect")

          if node
            CUI.Events.registerEvent
              type: "custom-deleteDataFromPlugin"
              bubble: false
            CUI.Events.trigger
              type: 'custom-deleteDataFromPlugin'
              node: node[0]
              bubble: false

        if (! actionField.isCustomType || domData) && actionField.type != 'text_l10n' && actionField.type != 'text_l10n_oneline'
          if domData
            domData.displayValue()

  ##########################################################################################
  # make Option out of linked-table
  ##########################################################################################

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
  ##########################################################################################

  __getOptionFromField: (field, complex) ->
    newOption =
      value : field._full_name
      text : field._column._name_localized + ' [' + field.column_name_hint + '] ("' + field._full_name + '")'
    return newOption

  ##########################################################################################
  # get Options from MaskSettings
  ##########################################################################################

  getOptions: ->
    that = @
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
          label: $$('editor.field.visibility.targetpath')
        type: CUI.Input
        name: "jsontargetpath"
      ,
        form:
          label: $$('editor.field.visibility.map')
        type: CUI.Input
        name: "jsonmap"
      ,
        form:
          label: $$('editor.field.visibility.helpwithactionfieldnames')
        type: CUI.Select
        undo_and_changed_support: false
        name: 'helpwithactionfieldnames'
        empty_text: $$('editor.field.visibility.helpwithactionfieldnames_no')
        options: (thisSelect) =>
          select_items = []
          itemNo = (
            text: $$('editor.field.visibility.helpwithactionfieldnames_no')
            value: 0
          )
          select_items.push itemNo
          itemYes = (
            text: $$('editor.field.visibility.helpwithactionfieldnames_yes')
            value: 1
          )
          select_items.push itemYes
          return select_items
    ]
    maskOptions

  trashable: ->
    true
CUI.ready =>
  MaskSplitter.plugins.registerPlugin(ez5.EditorFieldVisibility)
