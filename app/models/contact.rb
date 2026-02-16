class Contact < ApplicationRecord
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy, inverse_of: :sender
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  validates :name, presence: true
  validates :email, presence: true

  AVATAR_COLORS = %w[
    bg-red-500 bg-orange-500 bg-amber-500 bg-yellow-500
    bg-lime-500 bg-green-500 bg-emerald-500 bg-teal-500
    bg-cyan-500 bg-sky-500 bg-blue-500 bg-indigo-500
    bg-violet-500 bg-purple-500 bg-fuchsia-500 bg-pink-500
  ].freeze

  def initials
    name.split.map(&:first).join.upcase.first(2)
  end

  def avatar_color
    AVATAR_COLORS[name.sum % AVATAR_COLORS.length]
  end
end
