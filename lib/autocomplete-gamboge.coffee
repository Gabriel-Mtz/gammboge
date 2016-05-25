###
module.exports =
  provider: null

  activate: ->

  deactivate: ->
    @provider = null
###
  provide: ->
    #unless @provider?
      SnippetsProvider = require('./gamboge-provider')
      @provider = new GambogeProvider()
      #@provider.setSnippetsSource(@snippets) if @snippets?

    @provider

  consumeSnippets: (@snippets) ->
    @provider?.setSnippetsSource(@snippets)
