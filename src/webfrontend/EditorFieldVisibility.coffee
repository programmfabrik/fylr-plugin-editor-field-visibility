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
          entryKeyPath = entryKey.split "."
          # remove first pathElement, because it is the name of objecttype
          entryKeyPath.shift()
          entryKey = entryKeyPath.join('.')
          fieldsToReturn[entryKey] = field;
        if field?.FieldSchema?.kind == 'linked-table'
          # push "linked table" itself to list
          entryKey = field['FieldSchema']['_full_name']
          entryKeyPath = entryKey.split "."
          # remove first pathElement, because it is the name of objecttype
          entryKeyPath.shift()
          entryKey = entryKeyPath.join('.')
          fieldsToReturn[entryKey] = field;
          # get all fields below the linked table
          nextLevelFieldsToReturn = @__getFieldNamesFieldConcordanceFromFieldList(field.mask.fields)
          for attrname, val of nextLevelFieldsToReturn
            fieldsToReturn[attrname] = nextLevelFieldsToReturn[attrname]
      return fieldsToReturn

    ##########################################################################################
    # find a given field in opts.data (NOT nested or splitter)
    __findFieldInFieldList: (fieldList, completeFieldName) ->
        # split fieldname in parts
        fieldNameParts = completeFieldName.split('.')
        fieldNamePartsCount = fieldNameParts.length * 1
        fieldName = fieldNameParts[0] + ''
        fieldNameParts.shift()
        completeFieldName = fieldNameParts.join('.')

        # direct field?
        if fieldList[fieldName + ':rendered'] && fieldNamePartsCount == 1
          field = fieldList[fieldName + ':rendered']
          return field
        # path longer than 1 element
        else if fieldNamePartsCount > 1
          # nested field?
          if fieldList['_nested:' + fieldName]
            newFieldList = fieldList['_nested:' + fieldName][0]
            @__findFieldInFieldList(newFieldList, completeFieldName)
          # else go on shifted shortened path..
          else
            @__findFieldInFieldList(fieldList, completeFieldName)
        # path == 1 element and this is a nested
        else if fieldNamePartsCount == 1
            if fieldList['_nested:' + fieldName]
              field = fieldList['_nested:' + fieldName + ':rendered']
              return field

    ##########################################################################################
    # main methode
    renderField: (opts) ->
      that = @

      # name of the observed field
      observedFieldName = @getDataOptions().observedfield

      # get inner fields
      innerFields = @renderInnerFields(opts)

      # no action in detail-mode
      if opts.mode == "detail"
        return innerFields

      jsonMap = @getDataOptions().jsonmap
      if CUI.util.isEmpty(jsonMap)
        return innerFields
      else
        jsonMap = JSON.parse(jsonMap)

      # Renderer given?
      fieldsRendererPlain = @__customFieldsRenderer.fields[0]
      if fieldsRendererPlain not instanceof FieldsRendererPlain
        return innerFields
      fields = fieldsRendererPlain.fields or []
      if not fields
        return innerFields
      # make a list of field's names, which are in the splitter and may be shown or hidden
      actionFields = []
      actionFields = @__getFieldNamesFieldConcordanceFromFieldList(fields)
      # find the observed field
      # split observed path (example: "depending_field_selection_test.depending_field_selection_test__eventblock.eventfeld1")
      observedPath = observedFieldName.split "."
      # remove first pathElement, because it is the name of objecttype
      observedPath.shift()
      observedFieldName = observedPath.join('.')
      observedField = @__findFieldInFieldList(opts.data, observedFieldName)
      # get type of observed field
      columnType = observedField.opts.field.ColumnSchema.type
      # get Element for listener-node
      observedFieldElement = observedField.getElement()

      # rerender if observed field changes
      CUI.Events.listen
        node: observedFieldElement
        type: "data-changed"
        call: (ev, info) =>
          @__manageVisibilitys(opts, columnType, jsonMap, observedField, observedFieldName, actionFields)

      @__manageVisibilitys(opts, columnType, jsonMap, observedField, observedFieldName, actionFields)

      return innerFields

    ##########################################################################################
    # show or hide fields, depending on jsonMap and oberservedfield-value
    __manageVisibilitys: (opts, columnType, jsonMap, observedField, observedFieldName, actionFields, clearValues = false) ->
      # get Value from observed field
      observedFieldValue = ''

      # if columnType == CustomDataTypeDANTE
      if columnType == 'custom:base.custom-data-type-dante.dante'
        dataAsString = observedField._field.getDataAsString(observedField._data, observedField._top_level_data)
        dataAsJson = JSON.parse dataAsString
        observedFieldValue = dataAsJson.conceptURI
        if ! CUI.util.isEmpty(observedFieldValue)
          observedFieldValue = observedFieldValue.replace('https', 'http')
      # if columnType == 'bool' etc...
      #   --> needed?
      # if observedFieldValue is empty --> hide all fields, except the observed field
      if CUI.util.isEmpty(observedFieldValue) # || CUI.util.isEmpty(jsonMap[observedFieldValue]
        for actionFieldName, actionFieldValue of actionFields
          # dont hide the observed field
          if actionFieldName != observedFieldName
            # dont hide a nested-block, if observedField is in that nested
            if observedFieldName.indexOf(actionFieldName) == -1
              actionFieldValue = @__findFieldInFieldList(opts.data, actionFieldName)
              CUI.dom.hideElement(actionFieldValue.getElement())
      else
        # loop all fields and hide or show them, depending on json-map
        for actionFieldName, actionFieldValue of actionFields
          if actionFieldName != observedFieldName
            actionFieldValue = @__findFieldInFieldList(opts.data, actionFieldName)
            # try to find observedFieldValue in jsonmap
            # found?
            foundInMap = false
            for jsonMapEntryName, jsonMapValue of jsonMap
              # if uri of observedfield matches jsonMapEntry
              if jsonMapValue?.uri.trim() == observedFieldValue
                if jsonMapValue?.fields.length > 0
                  foundInMap = true
                # compare actionFieldName and jsonMapFields and hide or show
                if jsonMapValue?.fields.indexOf(actionFieldName) != -1
                  CUI.dom.hideElement(actionFieldValue.getElement())
                  if clearValues == true
                    console.log "vlearValue"
                else
                  CUI.dom.showElement(actionFieldValue.getElement())
                break
            # if observedFieldValue not in jsonMap, show all fields
            if ! foundInMap
              CUI.dom.showElement(actionFieldValue.getElement())

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
  onSave: (opts) ->#
    console.error "f:checkForm"
    data = opts.resultObject.getData()
    console.log data
    console.log data[data._objecttype]

    # checke felder auf visibilty mit :"".visible()"?? oder .isVisible

    problems = []
    return problems

ez5.session_ready ->
  Editor.plugins.registerPlugin(ez5.EditorFieldVisibiliyClearHiddenFields)
