// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

import {Socket, LongPoller} from "phoenix"

class App {
  static init() {
    let socket = new Socket("/socket", {
      logger: ((kind, msg, data) => { console.log(`${kind}: ${msg}`, data) })
    })

    socket.connect({token: window.userToken})

    socket.onOpen( e => console.log("OPEN", e) )
    socket.onError( e => console.log("ERROR", e) )
    socket.onClose( e => console.log("CLOSE", e) )

    var chan = socket.channel("games:public", {})

    chan.join().receive("ignore", () => console.log("Auth error"))
      .receive("error", resp => { console.log("Unable to join", resp) })
      .receive("ok", () => console.log("Join ok"))
      // .after(10000, () => console.log("Connection interruption"))
    chan.onError(e => console.log("Something went wrong", e))
    chan.onClose(e => console.log("Channel closed", e))

    $(document).off("keydown").on("keydown", e => {
      // alert("key "+e.keyCode)
      if (e.keyCode == 65) {
        chan.push("move:left", {})
      }
      if (e.keyCode == 68) {
        chan.push("move:right", {})
      }
      if (e.keyCode == 87) {
        chan.push("move:up", {})
      }
      if (e.keyCode == 83) {
        chan.push("move:down", {})
      }
    })

    chan.on("state:update", state => {
      document.updateState(state)
    })

  } // end init()

} // end App

$( () => App.init() )

export default App
