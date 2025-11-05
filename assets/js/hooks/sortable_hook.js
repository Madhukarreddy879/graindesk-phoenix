import Sortable from 'sortablejs';

const SortableHook = {
  mounted() {
    const hook = this;
    
    // Initialize Sortable on the container
    this.sortable = Sortable.create(this.el, {
      animation: 150,
      handle: '.drag-handle',
      ghostClass: 'sortable-ghost',
      dragClass: 'sortable-drag',
      chosenClass: 'sortable-chosen',
      
      // Called when dragging ends
      onEnd: function(evt) {
        // Get the new order of widget IDs
        const widgetIds = Array.from(hook.el.children).map(child => {
          return child.dataset.widgetId;
        });
        
        // Send the new order to the server
        hook.pushEvent('reorder_widgets', { order: widgetIds });
      }
    });
  },
  
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
};

export default SortableHook;
