# frozen_string_literal: true

class Components::EmptyState < Components::Base
  def initialize(title:, description:)
    @title = title
    @description = description
  end

  def view_template
    div(class: "flex flex-col items-center justify-center h-full text-center px-6 py-12") do
      svg(
        xmlns: "http://www.w3.org/2000/svg",
        fill: "none",
        viewbox: "0 0 24 24",
        stroke_width: "1.5",
        stroke: "currentColor",
        class: "w-16 h-16 text-gray-300 mb-4"
      ) do |s|
        s.path(
          stroke_linecap: "round",
          stroke_linejoin: "round",
          d: "M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 " \
             "01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 " \
             "2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 " \
             "4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
        )
      end

      h3(class: "text-lg font-medium text-gray-900 mb-1") { @title }
      p(class: "text-sm text-gray-500") { @description }
    end
  end
end
