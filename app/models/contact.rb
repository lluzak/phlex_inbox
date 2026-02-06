class Contact < ApplicationRecord
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy, inverse_of: :sender
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  validates :name, presence: true
  validates :email, presence: true

  def initials
    name.split.map(&:first).join.upcase.first(2)
  end
end
