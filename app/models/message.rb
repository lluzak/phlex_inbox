class Message < ApplicationRecord
  include Broadcastable

  LABELS = %w[inbox sent archive trash].freeze

  broadcasts_with MessageRowComponent, MessageDetailComponent, MessageLabelsComponent

  belongs_to :sender, class_name: "Contact"
  belongs_to :recipient, class_name: "Contact"
  belongs_to :replied_to, class_name: "Message", optional: true
  has_many :replies, class_name: "Message", foreign_key: :replied_to_id, dependent: :nullify, inverse_of: :replied_to

  has_many :labelings, dependent: :destroy
  has_many :labels, through: :labelings

  after_create_commit :touch_replied_to

  validates :subject, presence: true
  validates :body, presence: true
  validates :label, inclusion: { in: LABELS }

  scope :inbox, -> { where(label: "inbox") }
  scope :sent_box, -> { where(label: "sent") }
  scope :archived, -> { where(label: "archive") }
  scope :trashed, -> { where(label: "trash") }
  scope :unread, -> { where(read_at: nil) }
  scope :starred_messages, -> { where(starred: true) }
  scope :filter_by_label, ->(label_id) { joins(:labelings).where(labelings: { label_id: label_id }) }
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

  def thread_root
    root = self
    seen = Set.new
    while root.replied_to_id.present? && root.replied_to_id != root.id && seen.add?(root.id)
      root = root.replied_to
    end
    root
  end

  def thread_messages
    root = thread_root
    ids = Set.new([root.id])
    loop do
      new_ids = Message.where(replied_to_id: ids.to_a).where.not(id: ids.to_a).pluck(:id)
      break if new_ids.empty?

      ids.merge(new_ids)
    end
    Message.where(id: ids.to_a).includes(:sender, :recipient).order(:created_at)
  end

  private

  def touch_replied_to
    replied_to&.touch
  end
end
