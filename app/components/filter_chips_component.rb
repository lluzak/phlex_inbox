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
    @active_label_ids = Array(@active_filters["label_ids"])
  end

  private

  def chip_url_for_status(key, value)
    toggled = @active_filters.dup
    if toggled[key] == value
      toggled.delete(key)
    else
      toggled[key] = value
    end
    build_url(toggled)
  end

  def chip_url_for_label(label_id_str)
    toggled = @active_filters.dup
    ids = Array(toggled["label_ids"]).dup
    if ids.include?(label_id_str)
      ids.delete(label_id_str)
    else
      ids << label_id_str
    end
    if ids.any?
      toggled["label_ids"] = ids
    else
      toggled.delete("label_ids")
    end
    build_url(toggled)
  end

  def build_url(filters)
    parts = []
    filters.each do |key, value|
      if value.is_a?(Array)
        value.each { |v| parts << "#{key}[]=#{v}" }
      else
        parts << "#{key}=#{CGI.escape(value.to_s)}"
      end
    end
    parts.empty? ? @current_path : "#{@current_path}?#{parts.join('&')}"
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
    @active_label_ids.include?(label.id.to_s)
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
