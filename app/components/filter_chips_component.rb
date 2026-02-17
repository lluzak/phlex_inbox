# frozen_string_literal: true

class FilterChipsComponent < ApplicationComponent
  STATUS_FILTERS = [
    { key: "unread", label: "Unread" },
    { key: "starred", label: "Starred" }
  ].freeze

  def initialize(current_path:, active_filters:, labels:)
    @current_path = current_path
    @active_filters = active_filters
    @labels = labels
  end

  private

  def chip_url(key, value)
    toggled = @active_filters.dup
    if toggled[key]
      toggled.delete(key)
    else
      toggled[key] = value
    end
    query = toggled.to_query
    query.empty? ? @current_path : "#{@current_path}?#{query}"
  end

  def active?(key)
    @active_filters.key?(key)
  end

  def status_chip_classes(key)
    base = "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium transition-colors"
    if active?(key)
      "#{base} bg-blue-600 text-white hover:bg-blue-700"
    else
      "#{base} border border-gray-300 text-gray-600 hover:bg-gray-50"
    end
  end

  def label_chip_classes(label)
    base = "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium transition-colors"
    if label_active?(label)
      color_active_classes(label.color, base)
    else
      "#{base} border border-gray-300 text-gray-600 hover:bg-gray-50"
    end
  end

  def label_active?(label)
    active?("label_id") && @active_filters["label_id"] == label.id.to_s
  end

  def color_active_classes(color, base)
    mapping = {
      "blue" => "bg-blue-600 text-white hover:bg-blue-700",
      "green" => "bg-green-600 text-white hover:bg-green-700",
      "red" => "bg-red-600 text-white hover:bg-red-700",
      "yellow" => "bg-yellow-500 text-white hover:bg-yellow-600",
      "purple" => "bg-purple-600 text-white hover:bg-purple-700",
      "indigo" => "bg-indigo-600 text-white hover:bg-indigo-700"
    }
    "#{base} #{mapping.fetch(color, mapping['blue'])}"
  end
end
