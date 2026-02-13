# frozen_string_literal: true

module LiveComponent
  class LiveDataSerializer
    AVATAR_COLORS = %w[
      bg-red-500 bg-orange-500 bg-amber-500 bg-yellow-500
      bg-lime-500 bg-green-500 bg-emerald-500 bg-teal-500
      bg-cyan-500 bg-sky-500 bg-blue-500 bg-indigo-500
      bg-violet-500 bg-purple-500 bg-fuchsia-500 bg-pink-500
    ].freeze

    LABEL_BADGE_COLORS = {
      "blue" => "bg-blue-100 text-blue-700",
      "green" => "bg-green-100 text-green-700",
      "red" => "bg-red-100 text-red-700",
      "yellow" => "bg-yellow-100 text-yellow-700",
      "purple" => "bg-purple-100 text-purple-700",
      "indigo" => "bg-indigo-100 text-indigo-700"
    }.freeze

    LABEL_BADGE_BASE = "inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium"

    attr_reader :component_class

    def initialize(component_class)
      @component_class = component_class
    end

    def serialize(record)
      data = { "id" => record.id }

      component_class._data_fields.each do |field|
        data[field.to_s] = format_value(record.public_send(field))
      end

      component_class._data_predicates.each do |pred|
        data[pred.to_s] = !!record.public_send(:"#{pred}?")
      end

      component_class._data_helpers.each do |helper|
        data[helper.to_s] = Rails.application.routes.url_helpers.public_send(helper, record)
      end

      component_class._data_iterations.each do |collection_name, fields|
        collection = record.public_send(collection_name)
        data[collection_name.to_s] = collection.map do |item|
          item_data = {}
          fields.each do |f|
            item_data[f.to_s] = item.public_send(f).to_s if item.respond_to?(f)
          end
          if item_data.key?("color")
            item_data["badge_classes"] = label_badge_classes(item_data["color"])
          end
          item_data
        end
      end

      component_class._data_derived.each do |method|
        data[method.to_s] = component_class.public_send(:"compute_#{method}", record)
      end

      data["selected"] = false
      data
    end

    def serialize_changes(record)
      return nil unless record.respond_to?(:saved_changes)

      changed = record.saved_changes.keys
      relevant_keys = changed_keys_for(changed)
      return nil if relevant_keys.empty?

      data = { "id" => record.id }
      relevant_keys.each { |key| data[key] = serialize_key(record, key) }
      data
    end

    private

    def serialize_key(record, key)
      if component_class._data_fields.include?(key.to_sym)
        return format_value(record.public_send(key))
      end

      if component_class._data_predicates.include?(key.to_sym)
        return !!record.public_send(:"#{key}?")
      end

      if component_class._data_helpers.include?(key.to_sym)
        return Rails.application.routes.url_helpers.public_send(key, record)
      end

      component_class._data_derived.each do |method|
        if method.to_s == key
          return component_class.public_send(:"compute_#{method}", record)
        end
      end

      nil
    end

    def changed_keys_for(changed_columns)
      keys = Set.new

      component_class._data_fields.each do |field|
        keys << field.to_s if changed_columns.include?(field.to_s)
      end

      component_class._data_predicates.each do |pred|
        base_col = pred.to_s
        if changed_columns.include?(base_col) ||
           changed_columns.include?("#{base_col}_at") ||
           changed_columns.include?(base_col.delete_suffix("ed"))
          keys << pred.to_s
        end
      end

      keys.to_a
    end

    def format_value(value)
      case value
      when Time, DateTime, ActiveSupport::TimeWithZone
        time_ago_in_words(value)
      when ActiveRecord::Base
        nil
      else
        value.to_s
      end
    end

    def time_ago_in_words(time)
      distance = (Time.current - time).abs
      case distance
      when 0..59 then "less than a minute"
      when 60..3599
        minutes = (distance / 60).round
        minutes == 1 ? "1 minute" : "#{minutes} minutes"
      when 3600..86_399
        hours = (distance / 3600).round
        hours == 1 ? "about 1 hour" : "about #{hours} hours"
      when 86_400..2_591_999
        days = (distance / 86_400).round
        days == 1 ? "1 day" : "#{days} days"
      else
        months = (distance / 2_592_000).round
        months <= 1 ? "about 1 month" : "#{months} months"
      end
    end

    def label_badge_classes(color)
      color_classes = LABEL_BADGE_COLORS.fetch(color.to_s, LABEL_BADGE_COLORS["blue"])
      "#{LABEL_BADGE_BASE} #{color_classes}"
    end

    def avatar_color(name)
      return AVATAR_COLORS.first unless name
      AVATAR_COLORS[name.sum % AVATAR_COLORS.length]
    end

    def initials_for(name)
      return "" unless name
      name.split.map(&:first).join.upcase.first(2)
    end
  end
end
