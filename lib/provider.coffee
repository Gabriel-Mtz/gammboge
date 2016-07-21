fs = require 'fs'
path = require 'path'

#trailingWhitespace = /\s$/
attributePattern = /\s+([a-zA-Z][-a-zA-Z]*)\s*=\s*$/
tagPattern = /<([a-zA-Z][-a-zA-Z]*)(?:\s|$)/
maxOrder = 8

module.exports =
  selector: '*'
  disableForSelector: '.text.html .comment'
  #filterSuggestions: true

  getSuggestions: ({editor, bufferPosition}) ->
    #console.log "determinando gam_HTMLsuggestion"
    #{prefix} = request
    prefix = @getPrefix(editor, bufferPosition)

    console.log "El gam_prefijo era, #{prefix}!"
    @getAttributeNameCompletions(prefix)
#[text: 'Pikachu', text: 'Charmander', text: 'Squirtle', text: 'Bulbasaur', text: 'Bulky']
      #console.log attribute
      #console.log tag

  onDidInsertSuggestion: ({editor, suggestion}) ->
    setTimeout(@triggerAutocomplete.bind(this, editor), 1) if suggestion.type is 'attribute'

  triggerAutocomplete: (editor) ->
    atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:activate', activatedManually: false)

  sort_by: (field, reverse, primer) ->
    key = if primer then ((x) ->
      primer x[field]
    ) else ((x) ->
      x[field]
    )
    reverse = if !reverse then 1 else -1
    (a, b) ->
      a = key(a)
      b = key(b)
      reverse * ((a > b) - (b > a))

  getPrefix: (editor, bufferPosition) ->
    # Whatever your prefix regex might be
    regex = /(\b\w+\b\s?){0,7}$/
    # Get the text for the line up to the triggered buffer position
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    #Or just return the whole line because why not
    line = line.replace(/\s+/g," ")
    line = line.replace(/\s$/g,"")
    # Match the regex to the line, and return the match
    line.match(regex)?[0] or ''

  getAttributeNameCompletions: (prefix) ->
    completions = []
    mostLikely = liveGuess(prefix)
    #console.log "iniciales"
    for index, attribute of mostLikely
      console.log attribute
      completions.push(@buildAttributeCompletion(attribute[0]))


    #completions.sort(@sort_by('snippet', false, (a) -> a.toUpperCase()));

    console.log "la cosa quedo asi"
    tmp_logger =""
    for i in completions
      tmp_logger = tmp_logger + i.snippet + ", "
    console.log tmp_logger

    completions

  buildAttributeCompletion: (attribute, tag) ->
    if tag?
      snippet: "#{attribute} "
      displayText: attribute
      type: 'attribute'
      rightLabel: "<#{tag}>"
      description: "#{attribute} attribute local to <#{tag}> tags"
      #descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)
    else
      snippet: "#{attribute} "
      displayText: attribute
      type: 'attribute'
      description: "Global #{attribute} attribute"
      #descriptionMoreURL: @getGlobalAttributeDocsURL(attribute)

  getAttributeValueCompletions: ({editor, bufferPosition}, prefix) ->
    tag = @getPreviousTag(editor, bufferPosition)
    attribute = @getPreviousAttribute(editor, bufferPosition)
    values = @getAttributeValues(attribute)
    for value in values when not prefix or firstCharsEqual(value, prefix)
      @buildAttributeValueCompletion(tag, attribute, value)

  buildAttributeValueCompletion: (tag, attribute, value) ->
    if @completions.attributes[attribute].global
      text: value
      type: 'value'
      description: "#{value} value for global #{attribute} attribute"
      descriptionMoreURL: @getGlobalAttributeDocsURL(attribute)
    else
      text: value
      type: 'value'
      description: "#{value} value for #{attribute} attribute local to <#{tag}>"
      descriptionMoreURL: @getLocalAttributeDocsURL(attribute, tag)

  loadCompletions: ->
    loadLM()
    @completions = {}
    fs.readFile path.resolve(__dirname, '..', 'completions.json'), (error, content) =>
      @completions = JSON.parse(content) unless error?
      return

  getPreviousTag: (editor, bufferPosition) ->
    {row} = bufferPosition
    while row >= 0
      tag = tagPattern.exec(editor.lineTextForBufferRow(row))?[1]
      return tag if tag
      row--
    return

  getPreviousAttribute: (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition]).trim()

    # Remove everything until the opening quote
    quoteIndex = line.length - 1
    quoteIndex-- while line[quoteIndex] and not (line[quoteIndex] in ['"', "'"])
    line = line.substring(0, quoteIndex)

    attributePattern.exec(line)?[1]

  getAttributeValues: (attribute) ->
    attribute = @completions.attributes[attribute]
    attribute?.attribOption ? []

  getTagAttributes: (tag) ->
    @completions.tags[tag]?.attributes ? []

  getTagDocsURL: (tag) ->
    "https://developer.mozilla.org/en-US/docs/Web/HTML/Element/#{tag}"

  getLocalAttributeDocsURL: (attribute, tag) ->
    "#{@getTagDocsURL(tag)}#attr-#{attribute}"

  getGlobalAttributeDocsURL: (attribute) ->
    "https://developer.mozilla.org/en-US/docs/Web/HTML/Global_attributes/#{attribute}"

firstCharsEqual = (str1, str2) ->
  str1[0].toLowerCase() is str2[0].toLowerCase()


"""Predicion Processing"""

loadLM= ->
  @dictionary = {}
  content = fs.readFileSync path.resolve(__dirname, 'LMObject.json')
  @dictionary = JSON.parse(content) unless error?
  return

getOrderCategory= (Order)->
  return Order.toString() + "-grams"

sortProperties = (obj, property,isNumericSort, ascending) ->
  isNumericSort = isNumericSort or false
  # by default text sort
  sortable = []
  for key of obj
    if obj.hasOwnProperty(key)
      sortable.push [
        key
        obj[key]
      ]
  if isNumericSort
    sortable.sort (a, b) ->
      if ascending
        a[1][property] - (b[1][property])
      else
        b[1][property] - (a[1][property])
  else
    sortable.sort (a, b) ->
      x = a[1][property].toLowerCase()
      y = b[1][property].toLowerCase()
      if x < y then -1 else if x > y then 1 else 0
  sortable

liveGuess= (sentence)->
  maxGuesses = 5
  candidates = {}
  console.log "given: "+sentence
  #console.log (sentence.startsWith("<s>"))
  sentenceOrder = sentence.split(" ").length + 1
  #console.log sentenceOrder
  #console.log getOrderCategory(sentenceOrder-1)
  onCorpus = dictionary[getOrderCategory(sentenceOrder-1)][sentence]
  if (typeof onCorpus == "undefined")
    console.log "Had not seen that one"
    console.log "Lets try one less"
    if (sentenceOrder == 2)
      return
    liveGuess(sentence.substr(sentence.indexOf(" ") + 1))
  else
    for k of dictionary[getOrderCategory(sentenceOrder)]
      if k.startsWith(sentence)
        candidates[k.substr(sentence.length + 1)]=dictionary[getOrderCategory(sentenceOrder)][k];
    #console.log "candidatillos"
    #console.log candidates
    candidates = sortProperties(candidates,"P",true,false)
    #console.log "ordenadillos"
    #console.log candidates
    candidates = candidates.slice(0,maxGuesses)
    #console.log "show these"
    console.log candidates
    return candidates
