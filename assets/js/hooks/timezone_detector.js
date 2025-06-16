export default {
  mounted() {
    // Format any timestamps on the page to local time
    this.formatTimestamps();
  },

  updated() {
    // Re-format timestamps when the page updates
    this.formatTimestamps();
  },

  formatTimestamps() {
    // Find all elements with data-utc-time attribute and convert them to local time
    const timestampElements = this.el.querySelectorAll('[data-utc-time]');
    
    timestampElements.forEach(element => {
      const utcTime = element.getAttribute('data-utc-time');
      if (utcTime) {
        try {
          const date = new Date(utcTime);
          const localTime = date.toLocaleDateString('en-GB', {
            day: '2-digit',
            month: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            hour12: false
          });
          element.textContent = localTime;
        } catch (error) {
          console.warn('Failed to format timestamp:', utcTime, error);
        }
      }
    });
  }
} 