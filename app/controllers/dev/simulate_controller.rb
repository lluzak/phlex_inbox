# frozen_string_literal: true

module Dev
  class SimulateController < ApplicationController
    SUBJECTS = [
      "Quick question about the project",
      "Meeting notes from today",
      "Updated timeline for Q2",
      "Thoughts on the new design?",
      "FYI: server maintenance tonight",
      "Can you review this PR?",
      "Lunch plans for Friday",
      "Re: Budget approval needed",
      "New feature idea",
      "Follow-up from our call"
    ].freeze

    BODIES = [
      "Hey, just wanted to follow up on our earlier conversation. Let me know your thoughts when you get a chance.",
      "I have been working on this and wanted to share an update. Things are progressing well and we should be on track for the deadline.",
      "Could you take a look at this when you have a moment? I think it needs a second pair of eyes before we move forward.",
      "Just a heads up that I will be making some changes to the shared repo today. Should not affect your work but wanted to let you know.",
      "Great news! The client loved the demo. They want to move forward with the full implementation. Let us sync up tomorrow to plan next steps."
    ].freeze

    def create
      current_user = Contact.find_by(email: "you@example.com")
      sender = Contact.where.not(id: current_user.id).order("RANDOM()").first

      message = Message.create!(
        sender: sender,
        recipient: current_user,
        subject: SUBJECTS.sample,
        body: BODIES.sample,
        label: "inbox",
        starred: false
      )

      render json: { id: message.id, subject: message.subject }
    end
  end
end
