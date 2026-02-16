class Labeling < ApplicationRecord
  belongs_to :message, touch: true
  belongs_to :label

  validates :label_id, uniqueness: { scope: :message_id }
end
