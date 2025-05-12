const ResetForm = {
  mounted() {
    this.handleEvent("reset-form", ({ id }) => {
      if (this.el.id === id) {
        this.el.reset();
      }
    });
  }
};

export default ResetForm; 