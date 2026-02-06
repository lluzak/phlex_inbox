# frozen_string_literal: true

class Views::Layouts::ApplicationLayout < Phlex::HTML
  include Phlex::Rails::Layout

  def view_template
    doctype
    html(class: "h-full bg-gray-100") do
      head do
        title { "Phlex Inbox" }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag "tailwind", "data-turbo-track": "reload"
        stylesheet_link_tag "application", "data-turbo-track": "reload"
        javascript_importmap_tags
      end
      body(class: "h-full", data: { controller: "keyboard" }) do
        yield
      end
    end
  end
end
