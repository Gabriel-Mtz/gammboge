"""ARPA reference: http://cmusphinx.sourceforge.net/wiki/sphinx4:standardgrammarformats"""
"""relevant for us: ARPA: [cumulative_probability]<ngram>[backoff_probability(if_any)]
                    JSON: "ngram" [cumulative, backoff] """

fs = require 'fs'
path = require 'path'

myStaticModel = '/Users/gabomartinez/mitlm-0.4.1/myModel.txt'
#myStaticModel = '/Users/gabomartinez/mitlm-0.4.1/test_against.txt'
myOwnStaticDict = '/Users/gabomartinez/Google Drive/ITESM/8vo-9no Verano Canada/ARPA_Parser/expected.json'
myGenStaticDict = '/Users/gabomartinez/Google Drive/ITESM/8vo-9no Verano Canada/ARPA_Parser/LMObject.json'

parseArpa= ->
  content = fs.readFileSync path.resolve(myStaticModel)
  content = content.toString()
  #console.log("Synchronous read: \n" + content)
  """gram_lines"""
  """ $1 P  $3 ngram  $4 BP """
  regexp = /^(-?[0-9]\d*(\.\d+)?)\s(.+?)\s?(-?[0-9]\d*(\.\d+)?)?$/gm
  replacement = "\t,\"$3\": {\"P\":$1, \"BP\":$4}"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  """gram_count"""
  regexp = /^(ngram [0-9]+)=([0-9]+)$/gm
  replacement = "\t,\"$1\":$2"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  """gram_headers"""
  regexp = /^\\([0-9]+-grams):$\n\t,/gm
  replacement = "},\n\n\"$1\":{\n\t"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  """start"""
  regexp = /^\\data\\$\n\t,/m
  replacement = "{\n\n\"data\":{\n\t"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  """end"""
  regexp = /^\\end\\$/m
  replacement = "}\n\n}"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  """JSON doesnt like empy PB"""
  regexp = /("BP"):}$/gm
  replacement = "$1:0}"
  content = content.replace( regexp, replacement)
  #console.log("Alteration: \n" + content)
  fs.writeFile(myGenStaticDict, content)
  return
    #result = intermedio.replace("^(ngram [0-9]+)=([0-9]+)$", "\t,\"$1\":$2")

loadLM= ->
  @dictionary = {}
  content = fs.readFileSync path.resolve(myGenStaticDict)
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
  maxGuesses = 3
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

#parseArpa()
#"""
console.log "arranca"
loadLM()

liveGuess("<s> She read")
liveGuess("read a different")
liveGuess("You read a")

#gram = 'ngram 1'
#myVal = dictionary['3-grams']['I was bored']['BP']
#myVal = dictionary['data']['ngram 3']
#console.log myVal

#"""
