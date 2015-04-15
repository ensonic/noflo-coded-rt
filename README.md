Sample code that does line counting on files and provides a live runtime that
one can use from noflo-ui. One can set parameters (the file to read) in the UI
and run the code several times.

1. Start the runtime: "npm start" (or "node index.js").
2. Start the noflo-ui: ./node_modules/.bin/simple-server . 3005
3. Open a browser and connect to: http://localhost:3005/index.html#runtime/endpoint?protocol%3Dwebsocket%26address%3Dws%3A%2F%2F127.0.0.1%3A3569

