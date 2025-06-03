const DialogDrawerMode = {
  mounted() {
    // Store the element ID for debugging
    this.elementId = this.el.id;
    
    // Initialize the current mode based on screen width
    this.currentMode = window.innerWidth >= 768 ? "dialog" : "drawer";
    const phxTarget = this.el.getAttribute("phx-target");

    // Set up the resize handler function with proper binding
    this.handleResize = () => {
      const newMode = window.innerWidth >= 768 ? "dialog" : "drawer";
      if (newMode !== this.currentMode) {
        this.currentMode = newMode;
        this.pushScreenModeEvent(newMode, phxTarget);
      }
    };

    // Initial push of the screen mode
    this.pushScreenModeEvent(this.currentMode, phxTarget);

    // Set up the resize event listener with debounce
    let resizeTimeout;
    this.resizeListener = () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(this.handleResize, 250);
    };
    
    window.addEventListener("resize", this.resizeListener);
  },

  pushScreenModeEvent(mode, phxTarget) {
    // If there's a phx-target, push to the component
    if (phxTarget) {
      this.pushEventTo(`[data-phx-component="${phxTarget}"]`, "set_screen_mode", { mode });
    } else {
      // Otherwise push directly to the LiveView
      this.pushEvent("set_screen_mode", { mode });
    }
  },

  destroyed() {
    if (this.resizeListener) {
      window.removeEventListener("resize", this.resizeListener);
    }
  }
};

export default DialogDrawerMode;
