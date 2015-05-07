#!/usr/bin/env node
clc = require 'cli-color'
http = require 'http'
noflo = require 'noflo'
runtime = require 'noflo-runtime-websocket'
querystring = require 'querystring'

program = (require 'yargs')
  .options(
    host:
      describe: 'Hostname or IP for the runtime. Use "autodetect" or "autodetect(<iface>)" for dynamic detection.'
    port:
      describe: 'Port for the runtime.'
      type: 'number'
    'capture-output':
      default: false
      description: 'Catch writes to stdout and send to the FBP protocol client'
      type: 'boolean'
    'catch-exceptions':
      default: true
      description: 'Catch exceptions and report to the FBP protocol client'
      type: 'boolean'
    secret:
      describe: 'Secret string to be used for the connection.'
    debug:
      default: false
      description: 'Start the runtime in debug mode'
      type: 'boolean'
    verbose:
      default: false
      description: 'Log in verbose format'
      type: 'boolean'
    cache:
      default: false
      description: 'Enable component cache'
      type: 'boolean'
    interactive:
      default: false
      description: 'If true, do not start the graph, if false pass commandline args and start the graph'
      type: 'boolean'
  )
  .usage('Usage: $0 [options]')
  .help('h').alias('h', 'help')
  .wrap(null)
  .argv      

require 'coffee-cache' if program.cache

addDebug = (network, verbose, logSubgraph) ->

  identifier = (data) ->
    result = ''
    result += "#{clc.magenta.italic(data.subgraph.join(':'))} " if data.subgraph
    result += clc.blue.italic data.id
    result

  network.on 'connect', (data) ->
    return if data.subgraph and not logSubgraph
    console.log "#{identifier(data)} #{clc.yellow('CONN')}"

  network.on 'begingroup', (data) ->
    return if data.subgraph and not logSubgraph
    console.log "#{identifier(data)} #{clc.cyan('< ' + data.group)}"

  network.on 'data', (data) ->
    return if data.subgraph and not logSubgraph
    if verbose
      console.log "#{identifier(data)} #{clc.green('DATA')}", data.data
      return
    console.log "#{identifier(data)} #{clc.green('DATA')}"

  network.on 'endgroup', (data) ->
    return if data.subgraph and not logSubgraph
    console.log "#{identifier(data)} #{clc.cyan('> ' + data.group)}"

  network.on 'disconnect', (data) ->
    return if data.subgraph and not logSubgraph
    console.log "#{identifier(data)} #{clc.yellow('DISC')}"

startServer = (graph) ->
  server = http.createServer ->

  permissions = {}
  permissions[program.secret] = [
    'protocol:graph'
    'protocol:component'
    'protocol:network'
    'protocol:runtime'
    'component:setsource'
    'component:getsource'
  ]
  options =
    defaultGraph: graph
    baseDir: process.env.PROJECT_HOME or process.cwd()
    captureOutput: program.captureOutput
    catchExceptions: program.catchExceptions
    defaultPermissions: permissions[program.secret] unless program.secret
    permissions: permissions if program.secret
    cache: program.cache
  rt = runtime server, options

  rt.network.on 'addnetwork', (network) ->
    console.log 'Created the network'
    addDebug network, program.verbose, false if program.debug
    if not program.interactive
      network.once 'end', (event) ->
        server.close()

  console.log 'Start the server'
  server.listen program.port, ->
    if program.interactive
      address = 'ws://' + program.host + ':' + program.port
      params = 'protocol=websocket&address=' + address
      params += '&secret=' + program.secret if program.secret
      console.log 'NoFlo runtime listening at ' + address
      console.log 'Live IDE URL: <noflo-ui>#runtime/endpoint?' + querystring.escape(params)
    else
      console.log "Running graph"
      noflo.createNetwork graph, (->), options
    return
  return

createGraph = ->
  graph = noflo.graph.createGraph "linecount"
  console.log 'Created a new graph'
  
  graph.addNode "Read File", "filesystem/ReadFile"
  graph.addNode "Split by Lines", "strings/SplitStr"
  graph.addNode "Count Lines", "packets/Counter"
  graph.addNode "Display", "core/Output"
  
  graph.addEdge "Read File", "out", "Split by Lines", "in"
  graph.addEdge "Split by Lines", "out", "Count Lines", "in"
  graph.addEdge "Count Lines", "count", "Display", "in"
  
  console.log 'Setup the graph'

  if not program.interactive
    if program._.length is 0 or not program._[0]
      console.log "Need a filename"
    else
      graph.addInitial program._[0], "Read File", "in"
  graph

# create graph and start server
startServer createGraph()
