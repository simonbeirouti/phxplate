// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import {getHooks} from "live_svelte"
import * as Components from "../svelte/**/*.svelte"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.MobileMenu = {
  mounted() {
    const menu = document.getElementById("mobile-menu")
    const menuIcon = document.getElementById("menu-icon")
    const closeIcon = document.getElementById("close-icon")
    const button = this.el

    button.addEventListener("click", () => {
      if (menu.classList.contains("hidden")) {
        // Opening menu
        menu.classList.remove("hidden")
        menuIcon.classList.add("hidden")
        closeIcon.classList.remove("hidden")
        menu.style.opacity = "0"
        menu.style.transform = "scale(0.95)"
        
        // Force a reflow
        menu.offsetHeight
        
        menu.style.transition = "opacity 100ms ease-out, transform 100ms ease-out"
        menu.style.opacity = "1"
        menu.style.transform = "scale(1)"
      } else {
        // Closing menu
        menu.style.transition = "opacity 75ms ease-in, transform 75ms ease-in"
        menu.style.opacity = "0"
        menu.style.transform = "scale(0.95)"
        
        setTimeout(() => {
          menu.classList.add("hidden")
          menuIcon.classList.remove("hidden")
          closeIcon.classList.add("hidden")
          // Reset styles after animation
          menu.style.transition = ""
          menu.style.opacity = ""
          menu.style.transform = ""
        }, 75)
      }
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Allows to execute JS commands from the server
window.addEventListener("phx:js-exec", ({detail}) => {
  document.querySelectorAll(detail.to).forEach(el => {
    liveSocket.execJS(el, el.getAttribute(detail.attr))
  })
})
