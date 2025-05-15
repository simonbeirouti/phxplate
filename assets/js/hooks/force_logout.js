const ForceLogout = {
  mounted() {
    this.handleEvent("js_force_logout", (payload) => {
      window.location.href = "/";
    });
  },
  destroyed() {
    console.log("ForceLogout hook destroyed.");
  },
  updated() {
    console.log("ForceLogout hook updated.");
  }
}

export default ForceLogout; 