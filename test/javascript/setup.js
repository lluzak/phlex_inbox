// Minimal setup for testing live_renderer_controller logic
// We extract pure functions for unit testing

// Mock ActionCable consumer
globalThis.mockConsumer = {
  subscriptions: {
    subscriptions: [],
    create: () => ({ handlers: new Set() }),
    remove: () => {}
  }
}
