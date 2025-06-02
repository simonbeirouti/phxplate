const DialogDrawerMode = {
  mounted() {
    const phxTarget = this.el.getAttribute("phx-target");
    this.currentMode = window.innerWidth >= 768 ? "dialog" : "drawer";

    if (phxTarget) {
      this.pushEventTo(`[data-phx-component="${phxTarget}"]`, "set_screen_mode", { mode: this.currentMode });

      this.handleResize = () => {
        const newMode = window.innerWidth >= 768 ? "dialog" : "drawer";
        if (newMode !== this.currentMode) {
          this.currentMode = newMode;
          this.pushEventTo(`[data-phx-component="${phxTarget}"]`, "set_screen_mode", { mode: newMode });
        }
      };

      let resizeTimeout;
      window.addEventListener("resize", () => {
        clearTimeout(resizeTimeout);
        resizeTimeout = setTimeout(this.handleResize, 250);
      });
    } else {
      console.error("No phx-target attribute found on the element. Events will not be sent.");
    }
  },
  destroyed() {
    if (this.handleResize) {
      window.removeEventListener("resize", this.handleResize);
    }
  }
};

export default DialogDrawerMode;
