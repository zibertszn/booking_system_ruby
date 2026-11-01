# Pin npm packages by running ./bin/importmap

pin "application"
pin "vue", to: "https://unpkg.com/vue@3/dist/vue.esm-browser.prod.js"
pin_all_from "app/javascript/components", under: "components"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
