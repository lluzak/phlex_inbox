class Labeling < ApplicationRecord
  belongs_to :message
  belongs_to :label

  validates :label_id, uniqueness: { scope: :message_id }
end
