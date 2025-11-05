/**
 * ConnectionStatus Hook
 * 
 * Monitors the LiveView WebSocket connection status and displays
 * a notification when the connection is lost or restored.
 */
export const ConnectionStatus = {
  mounted() {
    this.container = this.el;
    this.disconnectedEl = this.el.querySelector('.connection-disconnected');
    this.reconnectedEl = this.el.querySelector('.connection-reconnected');
    this.closeBtn = this.el.querySelector('.connection-close');
    this.reconnectDots = this.el.querySelector('.reconnect-dots');
    
    this.reconnectAttempts = 0;
    this.dotsInterval = null;
    this.hideTimeout = null;

    // Listen for Phoenix LiveView connection events
    this.handleEvent('phx:page-loading-start', () => this.showDisconnected());
    this.handleEvent('phx:page-loading-stop', () => this.showReconnected());

    // Close button handler
    if (this.closeBtn) {
      this.closeBtn.addEventListener('click', () => this.hide());
    }

    // Monitor connection state changes
    window.addEventListener('phx:page-loading-start', () => {
      this.reconnectAttempts++;
      this.updateReconnectMessage();
    });

    window.addEventListener('phx:page-loading-stop', () => {
      this.reconnectAttempts = 0;
    });
  },

  destroyed() {
    if (this.dotsInterval) {
      clearInterval(this.dotsInterval);
    }
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
  },

  showDisconnected() {
    // Clear any pending hide timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    // Show container
    this.container.classList.remove('hidden');
    this.container.setAttribute('data-status', 'disconnected');

    // Show disconnected state
    this.disconnectedEl.classList.remove('hidden');
    this.reconnectedEl.classList.add('hidden');

    // Animate dots
    this.animateDots();
  },

  showReconnected() {
    // Stop dots animation
    if (this.dotsInterval) {
      clearInterval(this.dotsInterval);
      this.dotsInterval = null;
    }

    // Only show reconnected message if we were previously disconnected
    if (this.container.getAttribute('data-status') === 'disconnected') {
      this.container.setAttribute('data-status', 'reconnected');
      
      // Show reconnected state
      this.disconnectedEl.classList.add('hidden');
      this.reconnectedEl.classList.remove('hidden');

      // Auto-hide after 3 seconds
      this.hideTimeout = setTimeout(() => {
        this.hide();
      }, 3000);
    } else {
      // If we were never disconnected, just hide
      this.hide();
    }
  },

  hide() {
    this.container.classList.add('hidden');
    this.container.setAttribute('data-status', 'connected');
    this.disconnectedEl.classList.add('hidden');
    this.reconnectedEl.classList.add('hidden');
    
    if (this.dotsInterval) {
      clearInterval(this.dotsInterval);
      this.dotsInterval = null;
    }
    
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }
  },

  animateDots() {
    if (this.dotsInterval) {
      clearInterval(this.dotsInterval);
    }

    let dotCount = 0;
    this.dotsInterval = setInterval(() => {
      dotCount = (dotCount + 1) % 4;
      if (this.reconnectDots) {
        this.reconnectDots.textContent = '.'.repeat(dotCount || 1);
      }
    }, 500);
  },

  updateReconnectMessage() {
    // Could update the message based on reconnect attempts
    // For now, we just keep the same message
  }
};
