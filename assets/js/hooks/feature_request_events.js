// Hook to handle events from the feature request component
export default {
  mounted() {
    // Listen for feature request success events
    this.handleEvent("feature_request_success", ({ message }) => {
      console.log("Received feature_request_success event:", message);
      // Push the event to the dashboard-layout component specifically
      this.pushEventTo("#dashboard-layout", "feature_request_success", { message });
    });

    // Listen for feature request error events
    this.handleEvent("feature_request_error", ({ message }) => {
      console.log("Received feature_request_error event:", message);
      // Push the event to the dashboard-layout component specifically
      this.pushEventTo("#dashboard-layout", "feature_request_error", { message });
    });
  }
};
