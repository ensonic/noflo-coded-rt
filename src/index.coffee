#!/usr/bin/env node
program = require 'commander'
http = require 'http'
noflo = require 'noflo'
runtime = require 'noflo-runtime-websocket'
querystring = require 'querystring'

program
  .option('--host <hostname>', 'Hostname or IP for the runtime.', '127.0.0.1')
  .option('--port <port>', 'Port for the runtime', parseInt, '3569')
  .option('--capture-output [true/false]', 'Catch writes to stdout and send to the FBP protocol client (default = false)', false)
  .option('--catch-exceptions [true/false]', 'Catch exceptions and report to the FBP protocol client  (default = true)', true)
  .option('--secret <secret>', 'Secret string to be used for the connection.', null)
  .parse process.argv

startServer = (program, graph) ->
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
  rt = runtime server,
    defaultGraph: graph
    baseDir: graph.baseDir
    captureOutput: program.captureOutput
    catchExceptions: program.catchExceptions
    defaultPermissions: permissions[program.secret] unless program.secret
    permissions: permissions if program.secret

  server.listen program.port, ->
    address = 'ws://' + program.host + ':' + program.port
    params = 'protocol=websocket&address=' + address
    params += '&secret=' + program.secret if program.secret
    console.log 'NoFlo runtime listening at ' + address
    console.log 'Live IDE URL: <noflo-ui>#runtime/endpoint?' + querystring.escape(params)
    return
  return

createGraph = ->
  graph = noflo.graph.createGraph "linecount"
  graph.baseDir = process.env.PROJECT_HOME or process.cwd()
  
  graph.addNode "Read File", "filesystem/ReadFile"
  graph.addNode "Split by Lines", "strings/SplitStr"
  graph.addNode "Count Lines", "packets/Counter"
  graph.addNode "Display", "core/Output"
  
  graph.addEdge "Read File", "out", "Split by Lines", "in"
  graph.addEdge "Split by Lines", "out", "Count Lines", "in"
  graph.addEdge "Count Lines", "count", "Display", "in"
  
  # Kick the process off by sending filename to fileReader
  # graph.addInitial "package.json", "Read File", "in"
  
  console.log 'Created the graph'
  # This will start the graph
  # noflo.createNetwork graph
  graph

# create graph and start server
startServer program, createGraph()
