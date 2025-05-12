const Modal = {
  mounted() {
    this.handleEvent("hide-modal", ({ id }) => {
      const modal = document.getElementById(id);
      if (modal) {
        // Find and click the cancel button to properly close the dialog
        const cancelButton = modal.querySelector('[phx-click*="hide"]');
        if (cancelButton) {
          cancelButton.click();
        }
      }
    });
  }
};

export default Modal; 