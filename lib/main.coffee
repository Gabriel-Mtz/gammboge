provider = require './provider'

console.log "estoy en gam_html_main"

module.exports =
  activate: -> provider.loadCompletions()

  getProvider: -> provider
