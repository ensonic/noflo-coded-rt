#!/usr/bin/env node
program = require 'commander'
clc = require 'cli-color'
http = require 'http'
noflo = require 'noflo'
runtime = require 'noflo-runtime-websocket'
querystring = require 'querystring'

program
  .option('--host <hostname>', 'Hostname or IP for the runtime.', '127.0.0.1')
  .option('--port <port>', 'Port for the runtime', parseInt, '3569')
  .option('--capture-output [true/false]', 'Catch writes to stdout and send to the FBP protocol client (default = false)', ((val) -> (val is "true")), false)
  .option('--catch-exceptions [true/false]', 'Catch exceptions and report to the FBP protocol client  (default = true)', ((val) -> (val is "true")), true)
  .option('--secret <secret>', 'Secret string to be used for the connection.', null)
  .option('--debug [true/false]', 'Start the runtime in debug mode (default = false)', ((val) -> (val is "true")), false)
  .option('--verbose [true/false]', 'Log in verbose format (default = false)', ((val) -> (val is "true")), false)
  .option('--cache [true/false]', 'Enable component cache (default = false)', ((val) -> (val is "true")), false)
  .option('--interactive [true/false]', 'If true, do not start the graph, if false pass commandline args and start the graph (default = false).', ((val) -> (val is "true")), false)
  .parse process.argv

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
      network.on 'end', (event) ->
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
    if not program.args[0]
      console.log "Need a filename"
    else
      graph.addInitial program.args[0], "Read File", "in"
  graph

# create graph and start server
startServer createGraph()
