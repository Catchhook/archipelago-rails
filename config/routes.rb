# frozen_string_literal: true

Archipelago::Engine.routes.draw do
  post "/:component/:operation", to: "islands#create"
  get "/__debug", to: "islands#debug"
end
