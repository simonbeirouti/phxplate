const Sortable = {
  mounted() {
    this.initSortable();
  },

  updated() {
    this.initSortable();
  },

  initSortable() {
    // Clean up any existing sortable
    if (this.sortableInstance) {
      this.sortableInstance.destroy();
    }

    const container = this.el;
    const items = Array.from(container.querySelectorAll('[data-index]'));
    
    if (items.length === 0) return;

    let draggedElement = null;
    let draggedIndex = null;

    // Add drag event listeners to all items
    items.forEach((item, index) => {
      const dragHandle = item.querySelector('.drag-handle');
      if (!dragHandle) return;

      // Make the item draggable
      item.draggable = true;

      // Drag start
      item.addEventListener('dragstart', (e) => {
        draggedElement = item;
        draggedIndex = index;
        item.classList.add('opacity-50');
        
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/html', '');
      });

      // Drag end
      item.addEventListener('dragend', (e) => {
        item.classList.remove('opacity-50');
        draggedElement = null;
        draggedIndex = null;
      });

      // Drag over
      item.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
      });

      // Drop
      item.addEventListener('drop', (e) => {
        e.preventDefault();
        
        if (!draggedElement || draggedElement === item || draggedIndex === null) return;

        const dropIndex = index;
        
        if (draggedIndex !== dropIndex) {
          // Send the reorder event to LiveView
          this.pushEvent('reorder_features', {
            from: draggedIndex.toString(),
            to: dropIndex.toString()
          });
        }
      });

      // Drag enter
      item.addEventListener('dragenter', (e) => {
        e.preventDefault();
        if (draggedElement && draggedElement !== item) {
          const rect = item.getBoundingClientRect();
          const midpoint = rect.top + rect.height / 2;
          
          if (e.clientY < midpoint) {
            item.classList.add('border-t-4', 'border-blue-500');
            item.classList.remove('border-b-4');
          } else {
            item.classList.add('border-b-4', 'border-blue-500');
            item.classList.remove('border-t-4');
          }
        }
      });

      // Drag leave
      item.addEventListener('dragleave', (e) => {
        // Only remove classes if we're actually leaving the element
        if (!item.contains(e.relatedTarget)) {
          item.classList.remove('border-t-4', 'border-b-4', 'border-blue-500');
        }
      });
    });

    // Handle drag over on container
    container.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
    });

    // Handle drop on container (for empty areas)
    container.addEventListener('drop', (e) => {
      e.preventDefault();
      
      // Clean up any visual indicators
      items.forEach(item => {
        item.classList.remove('border-t-4', 'border-b-4', 'border-blue-500');
      });
    });

    this.sortableInstance = {
      destroy: () => {
        items.forEach(item => {
          item.draggable = false;
          item.classList.remove('border-t-4', 'border-b-4', 'border-blue-500');
          // Remove all event listeners by cloning the element
          const newItem = item.cloneNode(true);
          if (item.parentNode) {
            item.parentNode.replaceChild(newItem, item);
          }
        });
      }
    };
  },

  destroyed() {
    if (this.sortableInstance) {
      this.sortableInstance.destroy();
    }
  }
}; 

export default Sortable;