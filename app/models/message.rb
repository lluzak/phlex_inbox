class Message < ApplicationRecord
  include Broadcastable

  LABELS = %w[inbox sent archive trash].freeze

  broadcasts_component MessageRowComponent,
    stream: ->(message) { [message.recipient, :messages] },
    component: ->(message) { MessageRowComponent.new(message: message) },
    prepend_target: "message_items"

  belongs_to :sender, class_name: "Contact"
  belongs_to :recipient, class_name: "Contact"
  belongs_to :replied_to, class_name: "Message", optional: true
  has_many :replies, class_name: "Message", foreign_key: :replied_to_id, dependent: :nullify, inverse_of: :replied_to
  has_many :labelings, dependent: :destroy
  has_many :labels, through: :labelings

  validates :subject, presence: true
  validates :body, presence: true
  validates :label, inclusion: { in: LABELS }

  scope :inbox, -> { where(label: "inbox") }
  scope :sent_box, -> { where(label: "sent") }
  scope :archived, -> { where(label: "archive") }
  scope :trashed, -> { where(label: "trash") }
  scope :unread, -> { where(read_at: nil) }
  scope :starred_messages, -> { where(starred: true) }
  scope :newest_first, -> { order(created_at: :desc) }

  delegate :name, :avatar_url, to: :sender, prefix: :sender

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  def toggle_starred!
    update!(starred: !starred)
  end

  def preview(length = 100)
    body.truncate(length)
  end
end
