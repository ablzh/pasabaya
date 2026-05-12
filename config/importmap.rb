# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

pin "@floating-ui/dom", to: "https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.7.6/+esm"
pin "number-flow", to: "https://esm.sh/number-flow"
pin "number-flow/group", to: "https://esm.sh/number-flow/group"
pin "embla-carousel", to: "https://cdn.jsdelivr.net/npm/embla-carousel/embla-carousel.esm.js"
pin "embla-carousel-wheel-gestures", to: "https://cdn.jsdelivr.net/npm/embla-carousel-wheel-gestures@latest/+esm"
pin "tom-select", to: "https://cdn.jsdelivr.net/npm/tom-select@2.5.2/+esm"
pin "air-datepicker", to: "https://esm.sh/air-datepicker@3.6.0"
pin "air-datepicker/locale/en", to: "https://esm.sh/air-datepicker@3.6.0/locale/en"
pin "emoji-mart", to: "https://cdn.jsdelivr.net/npm/emoji-mart@latest/dist/browser.js"
pin "photoswipe", to: "https://cdn.jsdelivr.net/npm/photoswipe/dist/photoswipe.esm.js"
pin "motion", to: "https://cdn.jsdelivr.net/npm/motion@latest/+esm"