# frozen_string_literal: true

class Components::Button < Components::Base
  VARIANTS = {
    primary:
      "inline-flex items-center px-4 py-2 border border-transparent text-sm " \
      "font-medium rounded-md shadow-sm text-white bg-blue-600 " \
      "hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 " \
      "focus:ring-blue-500",
    ghost:
      "inline-flex items-center px-3 py-2 text-sm font-medium text-gray-700 " \
      "hover:text-gray-900 hover:bg-gray-100 rounded-md",
    icon:
      "inline-flex items-center justify-center w-8 h-8 rounded-full " \
      "text-gray-400 hover:text-gray-600 hover:bg-gray-100 " \
      "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
  }.freeze

  def initialize(variant: :primary, **attrs)
    @variant = variant
    @attrs = attrs
  end

  def view_template(&block)
    base_class = VARIANTS.fetch(@variant)
    extra_class = @attrs.delete(:class)
    merged_class = [base_class, extra_class].compact.join(" ")

    button(class: merged_class, **@attrs, &block)
  end
end
