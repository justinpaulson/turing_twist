// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Re-initialize TipJar animation on Turbo navigation (fixes mobile display)
document.addEventListener('turbo:load', function() {
  if (window.initializeTipJar) {
    window.initializeTipJar();
  }
});
