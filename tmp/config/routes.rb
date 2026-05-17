Rails.application.routes.draw do
  mount Archipelago::Engine => "/islands"
end
