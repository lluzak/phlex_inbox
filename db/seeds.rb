# Clear existing data
Labeling.destroy_all
Label.destroy_all
Message.destroy_all
Contact.destroy_all

puts "Seeding contacts..."

current_user = Contact.create!(
  name: "You",
  email: "you@example.com"
)

contacts = [
  Contact.create!(name: "Alice Johnson", email: "alice.johnson@example.com"),
  Contact.create!(name: "Bob Martinez", email: "bob.martinez@example.com"),
  Contact.create!(name: "Carol Chen", email: "carol.chen@example.com"),
  Contact.create!(name: "David Kim", email: "david.kim@example.com"),
  Contact.create!(name: "Elena Petrov", email: "elena.petrov@example.com"),
  Contact.create!(name: "Frank Nguyen", email: "frank.nguyen@example.com"),
  Contact.create!(name: "Grace Okafor", email: "grace.okafor@example.com"),
  Contact.create!(name: "Henry Walsh", email: "henry.walsh@example.com")
]

puts "Created #{Contact.count} contacts."

puts "Seeding labels..."

labels = {
  work: Label.create!(name: "Work", color: "blue"),
  personal: Label.create!(name: "Personal", color: "green"),
  urgent: Label.create!(name: "Urgent", color: "red"),
  finance: Label.create!(name: "Finance", color: "yellow"),
  travel: Label.create!(name: "Travel", color: "purple"),
  team: Label.create!(name: "Team", color: "indigo")
}

puts "Created #{Label.count} labels."

puts "Seeding inbox messages..."

inbox_messages = [
  {
    sender: contacts[0], subject: "Q1 Budget Review",
    body: "Hi, I have finished compiling the Q1 budget figures. Could you take a look at the attached spreadsheet and let me know if anything stands out? We need to finalize it before the board meeting on Friday.",
    starred: true, read: true, days_ago: 0, tags: [:work, :finance]
  },
  {
    sender: contacts[1], subject: "Lunch tomorrow?",
    body: "Hey! Are you free for lunch tomorrow? I was thinking about trying that new Thai place on Main Street. Let me know if noon works for you.",
    starred: false, read: false, days_ago: 0, tags: [:personal]
  },
  {
    sender: contacts[2], subject: "Re: Project Phoenix timeline",
    body: "Thanks for the update. I agree that pushing the deadline to March 15th makes sense given the scope changes. I will update the project plan and share it with the team this afternoon.",
    starred: false, read: true, days_ago: 1, tags: [:work]
  },
  {
    sender: contacts[3], subject: "Design mockups ready for review",
    body: "The latest design mockups for the dashboard redesign are ready. I have uploaded them to Figma. Please review when you get a chance -- we need feedback by end of week so we can start the sprint on Monday.",
    starred: true, read: false, days_ago: 1, tags: [:work, :urgent]
  },
  {
    sender: contacts[4], subject: "Conference registration reminder",
    body: "Just a reminder that early-bird registration for RailsConf closes this Friday. If you are planning to attend, you should register soon to get the discounted rate. Let me know if you want me to handle the team registrations.",
    starred: false, read: true, days_ago: 2, tags: [:travel, :team]
  },
  {
    sender: contacts[5], subject: "Bug report: login page crash",
    body: "We have a critical bug on the login page. Users on Safari are experiencing a crash when they click the forgot password link. I have attached the error logs. Can you prioritize this for today?",
    starred: true, read: true, days_ago: 2, tags: [:work, :urgent]
  },
  {
    sender: contacts[6], subject: "Team offsite planning",
    body: "I am starting to plan the team offsite for next month. Do you have any preferences on location? I was thinking somewhere within a two-hour drive. Also, any activity suggestions would be appreciated.",
    starred: false, read: false, days_ago: 3, tags: [:team, :travel]
  },
  {
    sender: contacts[7], subject: "Invoice #4521 attached",
    body: "Please find attached invoice #4521 for the consulting work completed in January. Payment terms are net-30. Let me know if you have any questions about the line items.",
    starred: false, read: true, days_ago: 3, tags: [:finance]
  },
  {
    sender: contacts[0], subject: "Re: Marketing campaign results",
    body: "The numbers from the holiday campaign are in. We saw a 23% increase in click-through rates compared to last year. I think the new creative direction really paid off. Let us discuss next steps in our Monday meeting.",
    starred: false, read: true, days_ago: 4, tags: [:work]
  },
  {
    sender: contacts[1], subject: "New hire onboarding checklist",
    body: "I have put together an onboarding checklist for the two new developers starting next week. Could you review it and add any technical setup steps I might have missed? I want to make sure their first day goes smoothly.",
    starred: false, read: false, days_ago: 5, tags: [:work, :team]
  },
  {
    sender: contacts[2], subject: "Quarterly review feedback",
    body: "I wanted to share some thoughts ahead of our quarterly review. Overall the team has been performing well, but I think we need to improve our sprint estimation process. Can we set up a 30-minute call to discuss?",
    starred: true, read: true, days_ago: 5, tags: [:work]
  },
  {
    sender: contacts[3], subject: "API rate limiting proposal",
    body: "I have drafted a proposal for implementing rate limiting on our public API. The document covers token bucket algorithms, suggested thresholds, and error response formats. Would love your input before I present it to the team.",
    starred: false, read: true, days_ago: 6, tags: [:work]
  },
  {
    sender: contacts[4], subject: "Happy birthday!",
    body: "Happy birthday! I hope you have a wonderful day. The team is planning a little celebration at the office -- be prepared for cake around 3pm!",
    starred: true, read: true, days_ago: 7, tags: [:personal, :team]
  },
  {
    sender: contacts[5], subject: "Security audit findings",
    body: "The external security audit is complete. They found three medium-severity issues and one low-severity issue. None are critical, but we should address them within the next sprint. I have created tickets for each finding.",
    starred: false, read: false, days_ago: 8, tags: [:work, :urgent]
  },
  {
    sender: contacts[6], subject: "Re: Database migration plan",
    body: "I reviewed the migration plan and it looks solid. One suggestion: we should schedule the migration during our lowest-traffic window, which is typically Sunday between 2-4am. I can be on call if needed.",
    starred: false, read: true, days_ago: 9, tags: [:work]
  },
  {
    sender: contacts[7], subject: "Partnership opportunity",
    body: "I had an interesting conversation with the team at Acme Corp. They are looking for a technology partner for their upcoming product launch. I think there could be a good fit with what we are building. Can we discuss this week?",
    starred: false, read: true, days_ago: 10, tags: [:work]
  },
  {
    sender: contacts[0], subject: "Vacation request",
    body: "I would like to take time off from March 10-14 for a family vacation. I will make sure all my current tasks are either completed or handed off before I leave. Please let me know if there are any concerns.",
    starred: false, read: false, days_ago: 11, tags: [:personal, :travel]
  },
  {
    sender: contacts[1], subject: "CI/CD pipeline improvements",
    body: "I have been looking into ways to speed up our CI/CD pipeline. By parallelizing our test suite and caching dependencies more aggressively, I think we can cut build times by about 40%. Want to pair on this next week?",
    starred: false, read: true, days_ago: 12, tags: [:work]
  },
  {
    sender: contacts[2], subject: "Client demo prep",
    body: "The demo for Globex Industries is next Thursday. I have prepared the slide deck and demo environment. Could you run through the technical demo portion once to make sure everything works end to end? Let me know a good time.",
    starred: true, read: true, days_ago: 14, tags: [:work, :urgent]
  },
  {
    sender: contacts[3], subject: "Weekly standup notes",
    body: "Here are the notes from today's standup. Key highlights: the auth service migration is on track, the new search feature enters QA tomorrow, and we still need to resolve the caching issue in staging. Full notes attached.",
    starred: false, read: true, days_ago: 15, tags: [:team]
  },
  {
    sender: contacts[4], subject: "Recommendation letter request",
    body: "I hope this is not too much of an ask, but would you be willing to write a recommendation letter for my graduate school application? You have seen my work firsthand and I think your perspective would be valuable.",
    starred: false, read: false, days_ago: 16, tags: [:personal]
  },
  {
    sender: contacts[5], subject: "Server capacity planning",
    body: "Based on our current growth trajectory, we will need to scale up our infrastructure by Q3. I have put together cost estimates for both vertical and horizontal scaling options. Can we review them in our next one-on-one?",
    starred: false, read: true, days_ago: 18, tags: [:work, :finance]
  },
  {
    sender: contacts[6], subject: "Open source contribution guidelines",
    body: "I have drafted contribution guidelines for our open source project. It covers code style, PR process, issue templates, and community standards. Would you mind reviewing it before we publish? I want to make sure it is welcoming to new contributors.",
    starred: false, read: true, days_ago: 20, tags: [:team]
  },
  {
    sender: contacts[7], subject: "Re: Contract renewal",
    body: "I have reviewed the renewal terms and everything looks good on our end. The only change I would suggest is extending the support hours to include weekends, given the recent uptick in weekend deployments. Let me know your thoughts.",
    starred: false, read: false, days_ago: 22, tags: [:finance]
  },
  {
    sender: contacts[0], subject: "Book recommendation",
    body: "I just finished reading Designing Data-Intensive Applications by Martin Kleppmann. It is an excellent deep dive into distributed systems. Given the architecture work you are doing, I think you would really enjoy it.",
    starred: true, read: true, days_ago: 24, tags: [:personal]
  },
  {
    sender: contacts[1], subject: "Feedback on code review process",
    body: "I have been thinking about our code review process and have a few suggestions. First, we should aim for smaller PRs to speed up reviews. Second, using a checklist template could help ensure consistency. What do you think?",
    starred: false, read: true, days_ago: 25, tags: [:work, :team]
  },
  {
    sender: contacts[2], subject: "Holiday party planning committee",
    body: "We are forming a planning committee for the annual holiday party. Would you be interested in joining? We are looking for volunteers to help with venue selection, catering, and entertainment. First meeting is next Wednesday.",
    starred: false, read: true, days_ago: 27, tags: [:personal, :team]
  },
  {
    sender: contacts[3], subject: "Performance benchmarks",
    body: "I ran the performance benchmarks on the new caching layer. Response times improved by 65% on average, and we are seeing a 90th percentile latency of under 50ms. The detailed report is attached. Great work on this optimization!",
    starred: false, read: false, days_ago: 28, tags: [:work]
  },
  {
    sender: contacts[4], subject: "Emergency contact update",
    body: "HR asked me to remind everyone to update their emergency contact information in the system. Apparently several records are outdated. It only takes a minute -- here is the link to the portal.",
    starred: false, read: true, days_ago: 29, tags: []
  },
  {
    sender: contacts[5], subject: "Re: Deployment checklist",
    body: "I have updated the deployment checklist based on lessons learned from last week's incident. Added steps for verifying database backups and checking rollback procedures. Please review and share with the team.",
    starred: false, read: true, days_ago: 30, tags: [:work]
  }
]

inbox_messages.each do |msg|
  message = Message.create!(
    sender: msg[:sender],
    recipient: current_user,
    subject: msg[:subject],
    body: msg[:body],
    label: "inbox",
    starred: msg[:starred],
    read_at: msg[:read] ? msg[:days_ago].days.ago : nil,
    created_at: msg[:days_ago].days.ago,
    updated_at: msg[:days_ago].days.ago
  )
  msg[:tags].each { |tag| message.labels << labels[tag] }
end

puts "Created #{Message.inbox.count} inbox messages."

puts "Seeding sent messages..."

sent_messages = [
  {
    recipient: contacts[0], subject: "Re: Q1 Budget Review",
    body: "Thanks Alice, I have reviewed the spreadsheet and everything looks accurate. I made a few minor adjustments to the travel expenses column. Let us finalize it in tomorrow's meeting.",
    days_ago: 0
  },
  {
    recipient: contacts[2], subject: "Project Phoenix timeline",
    body: "Hi Carol, I wanted to give you a heads up that we may need to adjust the Project Phoenix timeline. The new requirements from the client are more extensive than originally scoped. Can we discuss options?",
    days_ago: 2
  },
  {
    recipient: contacts[5], subject: "Re: Bug report: login page crash",
    body: "Thanks for flagging this Frank. I have assigned it as a P1 and the frontend team is looking into it now. We should have a fix deployed by end of day.",
    days_ago: 2
  },
  {
    recipient: contacts[7], subject: "Contract renewal",
    body: "Hi Henry, our current contract is up for renewal next month. I would like to discuss terms before we proceed. Are you available for a call this week?",
    days_ago: 21
  },
  {
    recipient: contacts[4], subject: "Re: Conference registration reminder",
    body: "Great reminder Elena. Please go ahead and register the whole team. I have approved the budget for five attendees. Let me know the total so I can process the expense.",
    days_ago: 2
  }
]

sent_messages.each do |msg|
  Message.create!(
    sender: current_user,
    recipient: msg[:recipient],
    subject: msg[:subject],
    body: msg[:body],
    label: "sent",
    starred: false,
    read_at: msg[:days_ago].days.ago,
    created_at: msg[:days_ago].days.ago,
    updated_at: msg[:days_ago].days.ago
  )
end

puts "Created #{Message.sent_box.count} sent messages."

puts "Seeding archived messages..."

archived_messages = [
  {
    sender: contacts[6], subject: "Old meeting notes - October retro",
    body: "Attached are the notes from our October retrospective. Key action items included improving documentation and setting up automated testing for the payment module. Archiving for reference.",
    days_ago: 25
  },
  {
    sender: contacts[7], subject: "Welcome to the team!",
    body: "Welcome aboard! We are excited to have you join the team. I have set up your accounts and you should have received login credentials via email. Do not hesitate to reach out if you need anything during your first week.",
    days_ago: 30
  }
]

archived_messages.each do |msg|
  Message.create!(
    sender: msg[:sender],
    recipient: current_user,
    subject: msg[:subject],
    body: msg[:body],
    label: "archive",
    starred: false,
    read_at: msg[:days_ago].days.ago,
    created_at: msg[:days_ago].days.ago,
    updated_at: msg[:days_ago].days.ago
  )
end

puts "Created #{Message.archived.count} archived messages."

puts "Seeding complete!"
puts "  Contacts:  #{Contact.count}"
puts "  Labels:    #{Label.count}"
puts "  Inbox:     #{Message.inbox.count}"
puts "  Sent:      #{Message.sent_box.count}"
puts "  Archived:  #{Message.archived.count}"
puts "  Total:     #{Message.count}"
puts "  Labelings: #{Labeling.count}"
