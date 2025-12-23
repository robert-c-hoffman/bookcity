class Setting < ApplicationRecord
  VALID_TYPES = %w[string integer boolean json].freeze

  validates :key, presence: true, uniqueness: true
  validates :value_type, inclusion: { in: VALID_TYPES }

  def typed_value
    return nil if value.nil?

    case value_type
    when "string"
      value
    when "integer"
      value.to_i
    when "boolean"
      ActiveModel::Type::Boolean.new.cast(value)
    when "json"
      JSON.parse(value)
    else
      value
    end
  end

  def typed_value=(new_value)
    self.value = case value_type
    when "json"
      new_value.is_a?(String) ? new_value : new_value.to_json
    else
      new_value.to_s
    end
  end
end
