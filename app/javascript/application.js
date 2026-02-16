// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
if (Turbo.config?.hover) Turbo.config.hover.prefetch = false
import "controllers"
