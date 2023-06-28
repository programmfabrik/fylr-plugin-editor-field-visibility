class EditorFieldVisibility extends CustomMaskSplitter

  __uniqueArray: (arr) ->
    a = []
    i = 0
    l = arr.length
    while i < l
      if a.indexOf(arr[i]) == -1 and arr[i] != ''
        a.push arr[i]
      i++
    a

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

  __getFlatListOfAffectedSplitterFields: (optsData, prefix = '', splitterFieldNames) ->
    fieldList = []

    fieldnames = []
    for fieldName, field of optsData
      fieldnames.push fieldName

    # is array?
    for fieldName, field of optsData
      if ! fieldName.startsWith '_version'
        #########################################
        # NESTED as field
        # if name contains "_nested:" and contains ":rendered", if contains fields below
        fieldNameOriginal = fieldName
        if (fieldName.indexOf('_nested:') > -1) && (fieldName.indexOf(':rendered') > -1)
          cleanedFieldName = fieldName.replace(/_nested:/g, '')
          cleanedFieldName = cleanedFieldName.replace(/:rendered/g, '')
          if prefix != ''
            fieldName = prefix + '.' + cleanedFieldName
          else
            fieldName = cleanedFieldName
          fieldName = @objecttype + '.' + fieldName
          if splitterFieldNames.indexOf(fieldName) != -1
            fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement()
          # it is the block and not a field
          else
            fieldList.push 'name' : fieldName, 'field' : field, 'element' : field.getElement(), 'type' : 'block'

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
            fields = @__getFlatListOfAffectedSplitterFields(fieldEntry, newPrefix, splitterFieldNames)
            fieldList = fieldList.concat fields

        #########################################
        # FIELD
        if fieldName.indexOf('_nested:') == -1 && (fieldName.indexOf(':rendered') > -1)
          if prefix != ''
            fieldName = prefix + '.' + fieldName.replace(':rendered', '')
          else
            fieldName = fieldName.replace(':rendered', '')
          if ! field?.opts?.field?.__dbg_full_name
            continue
          fieldName = field.opts.field.__dbg_full_name
          fieldName = fieldName.replace(/_nested:/g, '')
          fieldNameParts = fieldName.split('.')
          lastPartOfFieldName = fieldNameParts.pop()
          if splitterFieldNames.indexOf(fieldName) != -1
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
    observedFieldName = @getDataOptions()?.observedfield
    if !observedFieldName
      return

    # actual _objecttype
    @objecttype = opts.top_level_data?._objecttype

    splitterFieldNames = []

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

    splitterFieldNames = @__getListOfFieldNamesInsideSplitter(innerSplitterFields)

    splitterFieldNamesFlat = @__getFlatListOfAffectedSplitterFields(opts.data, '', splitterFieldNames)

    for splitterField in splitterFieldNamesFlat
      if splitterField.name == observedFieldName
        # get type of observed field
        columnType = splitterField.type
        observedField = splitterField.field

    CUI.Events.listen
      type: ["data-changed", "editor-changed"]
      node: observedField.element
      call: (ev, info) =>
        @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName, splitterFieldNamesFlat)

    @__manageVisibilitys(opts, columnType, observedField, jsonMap, observedFieldName, splitterFieldNamesFlat)

    div = CUI.dom.element("div", class: "fylr-editor-field-visibility")
    if @getDataOptions()?.debugwithborder
      CUI.dom.setStyle div,
        border: "4px dashed #CCC"

    return CUI.dom.append(div, innerFields)

  ##########################################################################################
  # show or hide fields, depending on jsonMap and oberservedfield-value
  ##########################################################################################

  __manageVisibilitys: (opts, columnType, observedField, jsonMap, observedFieldName, actionFields) ->
    that = @

    # get Value from observed field
    observedFieldValue = ''

    #########################################
    # observedfield: if columnType == CustomDataTypeDANTE
    #########################################
    if columnType == 'custom:base.custom-data-type-dante.dante'
      dataAsString = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      if ! CUI.util.isEmpty(dataAsString)
        dataAsJson = JSON.parse dataAsString
        observedFieldValue = dataAsJson.conceptURI
      else
        observedFieldValue = null

    #########################################
    # observedfield: if columnType == 'bool'
    #########################################
    if columnType == 'boolean'
      observedFieldValue = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      if observedFieldValue == ''
        observedFieldValue = 'false'
      else
        observedFieldValue = 'true'

    #########################################
    # observedfield: if columnType == 'link' (interal objecttype)
    #########################################
    if columnType == 'link'
      observedFieldValueString = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
      if observedFieldValueString
        observedFieldValueObject = JSON.parse observedFieldValueString
        globalObjId = observedFieldValueObject?._global_object_id
        idParts = globalObjId.split '@'
        observedFieldValue = idParts[0]

    ##################################################################################
    # help activated? Then echo all actionfield.names to console
    ##################################################################################
    if @getDataOptions()?.helpwithactionfieldnames == 1
      console.warn "List of actionfield-path-names inside the splitter:"
      listOfFlatFields = []
      for actionField in actionFields
        if actionField.name != observedFieldName
          console.log actionField.name
          listOfFlatFields.push actionField.name

      jsonFieldList = []
      for jsonMapEntryName, jsonMapValue of jsonMap
          if jsonMapValue?.fields
            for jsonFieldKey, jsonFieldName of jsonMapValue.fields
              jsonFieldList.push jsonFieldName
      jsonFieldList = that.__uniqueArray(jsonFieldList)

      console.warn "List of all JSON-Fields, which are not available as field in active mask:"
      for jsonFieldListKey, jsonFieldListName of jsonFieldList
        for actionField in actionFields
          if actionField.name == jsonFieldListName
            jsonFieldList[jsonFieldListKey] = null
      jsonFieldList = jsonFieldList.filter (value) -> value isnt null
      console.log jsonFieldList


    ##################################################################################
    # if observedFieldValue is empty --> hide all fields, except the observed field
    ##################################################################################
    if CUI.util.isEmpty(observedFieldValue) # || CUI.util.isEmpty(jsonMap[observedFieldValue]
      for actionField in actionFields
        # dont hide the observed field
        if actionField.name != observedFieldName
          # dont hide a nested-block, if observedField is in that nested
          if observedFieldName.indexOf(actionField.name) == -1 || actionField.type != 'block'
            that.hideAndClearActionField(actionField)

    ##################################################################################
    # if observed field is not empty, show / hide fields in splitter, depending on json-map
    ##################################################################################
    else
      # check if a mapping exists in jsonmap for the given observedfieldvalue
      jsonMatchedMappingFields = false;
      for jsonMapEntryName, jsonMapValue of jsonMap
        if jsonMapValue?.value?.trim() == observedFieldValue
          if jsonMapValue?.fields
            jsonMatchedMappingFields = jsonMapValue.fields
            break;

      # go through all fields in splitter and show or hide, depending on mapping
      for actionField in actionFields
        if actionField.name != observedFieldName
          if jsonMatchedMappingFields
            if jsonMatchedMappingFields.indexOf(actionField.name) != -1 || jsonMatchedMappingFields.includes(actionField.name) != false
              that.hideAndClearActionField(actionField)
            else
              CUI.dom.showElement(actionField.element)
          else
            CUI.dom.showElement(actionField.element)


  ##################################################################################
  # hide an clear a mask-field
  ##########################################################################################

  hideAndClearActionField: (actionField) ->
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
                    actionField.dataReference[actionField.dataTarget][deletionValue] = null
              if actionField.dataReference[actionField.dataTarget].hasOwnProperty('conceptURI')
                actionField.dataReference[actionField.dataTarget] = null

        ##################################
        # clear base-fields
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
        if actionField.type.startsWith('custom:')

          node = CUI.dom.matchSelector(actionField.element, ".customPluginEditorLayout")

          # if dante-dropdown-mode
          if node.length == 0
            node = CUI.dom.matchSelector(actionField.element, ".dante_InlineSelect")

          if node.length == 0
            node = actionField.element

          # call plugins, which use syntax from commons.coffee (customPluginEditorLayout)
          if node
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
      if field.kind == 'link'
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
        if field.kind == 'link'
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
      ,
        form:
          label: $$('editor.field.visibility.debugwithborder')
        type: CUI.Select
        undo_and_changed_support: false
        name: 'debugwithborder'
        empty_text: $$('editor.field.visibility.debugwithborder_no')
        options: (thisSelect) =>
          select_items = []
          itemNo = (
            text: $$('editor.field.visibility.debugwithborder_no')
            value: 0
          )
          select_items.push itemNo
          itemYes = (
            text: $$('editor.field.visibility.debugwithborder_yes')
            value: 1
          )
          select_items.push itemYes
          return select_items
    ]
    maskOptions

  trashable: ->
    true
CUI.ready =>
  MaskSplitter.plugins.registerPlugin(EditorFieldVisibility)
