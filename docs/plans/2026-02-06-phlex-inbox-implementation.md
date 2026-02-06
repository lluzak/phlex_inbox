# Phlex Inbox Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Gmail-style inbox demo app in Rails 8 showcasing Phlex components, Tailwind CSS, Stimulus, and Turbo.

**Architecture:** Single-controller Rails app with Phlex for all views. 3-column Gmail layout using CSS grid + Tailwind. Turbo Frames for panel navigation, Turbo Streams for inline updates. No auth -- single hardcoded user.

**Tech Stack:** Rails 8.1, SQLite, Phlex 2.x / phlex-rails 2.x, Tailwind CSS, Stimulus, Turbo

---

### Task 1: Generate Rails app and install dependencies

**Files:**
- Create: `phlex_inbox/` (entire Rails app)
- Modify: `Gemfile`

**Step 1: Generate the Rails app**

Run from `/Users/przemek/private`:

```bash
rails new phlex_inbox --css=tailwind --skip-jbuilder --skip-action-mailbox --skip-action-mailer --skip-action-text --skip-active-storage
```

This gives us Rails 8 with Tailwind, Turbo, and Stimulus out of the box.

**Step 2: Add phlex-rails to Gemfile**

Add to `Gemfile` (after the rails gem):

```ruby
gem "phlex-rails", "~> 2.1"
```

**Step 3: Bundle and run Phlex install generator**

```bash
cd phlex_inbox
bundle install
bin/rails generate phlex:install
```

The generator creates the `Views` and `Components` module autoloading in `config/initializers/phlex.rb`.

**Step 4: Verify the app boots**

```bash
bin/rails server -p 3000 &
sleep 3
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200 or 302
kill %1
```

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: generate Rails app with Tailwind, Turbo, Stimulus, and Phlex"
```

---

### Task 2: Create Contact and Message models

**Files:**
- Create: `app/models/contact.rb`
- Create: `app/models/message.rb`
- Create: `db/migrate/*_create_contacts.rb`
- Create: `db/migrate/*_create_messages.rb`
- Create: `test/models/contact_test.rb`
- Create: `test/models/message_test.rb`

**Step 1: Generate Contact model**

```bash
bin/rails generate model Contact name:string email:string avatar_url:string
```

**Step 2: Generate Message model**

```bash
bin/rails generate model Message \
  subject:string \
  body:text \
  sender:references \
  recipient:references \
  read_at:datetime \
  starred:boolean \
  label:string \
  replied_to:references
```

**Step 3: Fix the Message migration**

Edit the generated migration file. The `references` columns need to point to the `contacts` table (not `senders`/`recipients`). Replace the migration `create_table` block:

```ruby
class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.string :subject, null: false
      t.text :body, null: false
      t.references :sender, null: false, foreign_key: { to_table: :contacts }
      t.references :recipient, null: false, foreign_key: { to_table: :contacts }
      t.datetime :read_at
      t.boolean :starred, default: false, null: false
      t.string :label, default: "inbox", null: false
      t.references :replied_to, foreign_key: { to_table: :messages }

      t.timestamps
    end

    add_index :messages, :label
    add_index :messages, :starred
    add_index :messages, :read_at
  end
end
```

**Step 4: Set up model associations and validations**

`app/models/contact.rb`:

```ruby
class Contact < ApplicationRecord
  has_many :sent_messages, class_name: "Message", foreign_key: :sender_id, dependent: :destroy, inverse_of: :sender
  has_many :received_messages, class_name: "Message", foreign_key: :recipient_id, dependent: :destroy, inverse_of: :recipient

  validates :name, presence: true
  validates :email, presence: true

  def initials
    name.split.map(&:first).join.upcase.first(2)
  end
end
```

`app/models/message.rb`:

```ruby
class Message < ApplicationRecord
  LABELS = %w[inbox sent archive trash].freeze

  belongs_to :sender, class_name: "Contact"
  belongs_to :recipient, class_name: "Contact"
  belongs_to :replied_to, class_name: "Message", optional: true
  has_many :replies, class_name: "Message", foreign_key: :replied_to_id, dependent: :nullify, inverse_of: :replied_to

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
```

**Step 5: Run migration**

```bash
bin/rails db:migrate
```

**Step 6: Write model tests**

`test/models/contact_test.rb`:

```ruby
require "test_helper"

class ContactTest < ActiveSupport::TestCase
  test "initials returns first letters of name" do
    contact = Contact.new(name: "John Doe", email: "john@example.com")
    assert_equal "JD", contact.initials
  end

  test "validates presence of name and email" do
    contact = Contact.new
    assert_not contact.valid?
    assert_includes contact.errors[:name], "can't be blank"
    assert_includes contact.errors[:email], "can't be blank"
  end
end
```

`test/models/message_test.rb`:

```ruby
require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
  end

  test "mark_as_read! sets read_at" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
    assert_nil msg.read_at
    msg.mark_as_read!
    assert_not_nil msg.read_at
  end

  test "toggle_starred! flips starred" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
    assert_not msg.starred
    msg.toggle_starred!
    assert msg.starred
    msg.toggle_starred!
    assert_not msg.starred
  end

  test "preview truncates body" do
    msg = Message.new(body: "a" * 200)
    assert_equal 100, msg.preview.length
  end

  test "scopes filter by label" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "inbox")
    assert_includes Message.inbox, msg
    assert_not_includes Message.sent_box, msg
  end

  test "validates label inclusion" do
    msg = Message.new(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "bogus")
    assert_not msg.valid?
  end
end
```

**Step 7: Run tests**

```bash
bin/rails test test/models/
```

Expected: All pass.

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: add Contact and Message models with validations and scopes"
```

---

### Task 3: Create seed data

**Files:**
- Modify: `db/seeds.rb`

**Step 1: Write seeds**

`db/seeds.rb`:

```ruby
# Clear existing data
Message.destroy_all
Contact.destroy_all

# Create the "current user"
me = Contact.create!(
  name: "You",
  email: "you@example.com",
  avatar_url: nil
)

# Create contacts
contacts = [
  { name: "Alice Johnson", email: "alice@example.com" },
  { name: "Bob Smith", email: "bob@example.com" },
  { name: "Carol Williams", email: "carol@example.com" },
  { name: "David Brown", email: "david@example.com" },
  { name: "Eve Davis", email: "eve@example.com" },
  { name: "Frank Miller", email: "frank@example.com" },
  { name: "Grace Wilson", email: "grace@example.com" },
  { name: "Henry Taylor", email: "henry@example.com" }
].map { |attrs| Contact.create!(attrs) }

# Message templates
subjects_and_bodies = [
  { subject: "Q4 Budget Review", body: "Hi, I've attached the Q4 budget review for your consideration. The numbers look promising this quarter with a 15% increase in revenue. Let me know if you have any questions about the projections." },
  { subject: "Team Lunch Friday", body: "Hey! Want to grab lunch with the team on Friday? We're thinking of trying that new Thai place on 5th street. Everyone's been raving about their pad thai." },
  { subject: "Project Update: Phoenix", body: "Quick update on Project Phoenix - we've completed the first sprint and all user stories are done. The client demo is scheduled for next Wednesday. I'll send the presentation deck tomorrow." },
  { subject: "Re: Conference Tickets", body: "Great news! I managed to get us 3 tickets for RubyConf this year. The early bird discount saved us about $400. I'll forward the confirmation emails shortly." },
  { subject: "Code Review Request", body: "Could you take a look at PR #247 when you get a chance? It's the refactor of the authentication module. I've added comprehensive tests but would love a second pair of eyes on the approach." },
  { subject: "Vacation Request", body: "I'd like to take off the week of March 15th for a family trip. I've already coordinated with the team and David has agreed to cover my on-call duties. Let me know if this works." },
  { subject: "New Design Mockups", body: "The design team just finished the mockups for the new dashboard. I think the data visualization components look fantastic. Check them out in Figma when you have a moment." },
  { subject: "Meeting Notes: Sprint Planning", body: "Here are the notes from today's sprint planning. We've committed to 34 story points this sprint. The priority items are the search feature and the notification system overhaul." },
  { subject: "Server Alert: High CPU", body: "Just a heads up - we got an alert for high CPU usage on prod-web-03 around 2 AM. I investigated and it was caused by a runaway background job. I've added a timeout and deployed the fix." },
  { subject: "Happy Birthday!", body: "Happy birthday! Hope you have an amazing day. The team chipped in for a little something - check your desk when you get in! We're also planning a small celebration at 3 PM in the break room." },
  { subject: "Client Feedback: Wave 2", body: "The client just sent over their feedback on the Wave 2 release. Overall very positive! They love the new search functionality. There are a few minor UI tweaks they'd like - I've created tickets for each." },
  { subject: "Reminder: 1-on-1 Tomorrow", body: "Just a reminder about our 1-on-1 tomorrow at 10 AM. I'd like to discuss your career goals for the next quarter and any blockers you're facing on the current project." },
  { subject: "Open Source Contribution", body: "I submitted a PR to the Phlex repository last night fixing that rendering bug we discussed. It's a small change but should help with our edge case. Would you mind reviewing it?" },
  { subject: "Expense Report Due", body: "Friendly reminder that expense reports for January are due by end of day Friday. Please make sure to include receipts for anything over $25. The new expense system makes it pretty painless." },
  { subject: "Architecture Decision Record", body: "I've drafted an ADR for the migration from REST to GraphQL for the internal API. Before I share it with the wider team, could you review it? I want to make sure the trade-offs are well-articulated." },
  { subject: "Welcome to the Team!", body: "Welcome aboard! I'm so excited to have you join our team. I've set up your accounts and you should have received login credentials via email. Let me know if you need anything to get started." },
  { subject: "Book Recommendation", body: "I just finished reading 'Designing Data-Intensive Applications' and it's incredible. Given your work on the data pipeline, I think you'd find chapters 5-7 particularly relevant." },
  { subject: "Deployment Schedule Change", body: "We're moving the deployment window from Thursday evenings to Tuesday mornings starting next week. This should reduce the risk of weekend incidents. Updated schedule is on the wiki." },
  { subject: "Hackathon Ideas", body: "The quarterly hackathon is coming up! I'm thinking of building a real-time collaboration feature using WebSockets. Want to team up? I think we could build something really cool in 48 hours." },
  { subject: "Re: Database Migration Plan", body: "I've reviewed the migration plan and it looks solid. One suggestion - let's add a rollback step between phases 2 and 3 just in case. Also, can we schedule a dry run for next Tuesday?" },
  { subject: "Parking Lot Update", body: "Starting next Monday, the east parking lot will be closed for repaving. Please use the west lot or the street parking on Oak Avenue. This should take about two weeks." },
  { subject: "Performance Review Prep", body: "Performance review season is here. Please fill out your self-assessment by March 1st. I've updated the template with the new competency framework. Reach out if you have questions about any of the criteria." },
  { subject: "API Rate Limiting Discussion", body: "We need to decide on rate limiting strategy for the public API. I'm leaning toward token bucket with a 1000 req/min limit for free tier. Can we discuss this in tomorrow's architecture meeting?" },
  { subject: "Office Plants", body: "Good news - the new office plants arrived! I've placed a few around the engineering area. If anyone wants one for their desk, there are extras in the supply room. They're low-maintenance succulents." },
  { subject: "Security Audit Results", body: "The security audit is complete. No critical findings! There are 3 medium-severity items we should address within 30 days. I've created Jira tickets and assigned them to the relevant teams." },
  { subject: "Lunch and Learn: Rust", body: "I'm organizing a lunch and learn session on Rust next Thursday. If you've been curious about systems programming or want to understand why everyone's excited about it, this is a great intro." },
  { subject: "Re: Feature Flag Cleanup", body: "I went through all the feature flags and identified 12 that can be removed. They've all been fully rolled out for at least 2 months. PR is up for review - it's mostly deleting code, which is satisfying." },
  { subject: "Weekend On-Call Swap", body: "Hey, would you be able to swap on-call weekends with me? I have a family event on March 8th. I'd take your April 5th weekend in return. Let me know!" },
  { subject: "New Coffee Machine!", body: "The new coffee machine in the kitchen is operational! It makes espresso, cappuccino, and even matcha lattes. There's a quick guide taped to the wall next to it. Enjoy!" },
  { subject: "Quarterly OKR Check-in", body: "Time for our quarterly OKR check-in. Please update your key results in the shared spreadsheet by EOD Wednesday. We'll review together in Thursday's team meeting and plan adjustments for Q2." }
]

# Generate inbox messages (received by me)
subjects_and_bodies.each_with_index do |msg_data, i|
  sender = contacts[i % contacts.length]
  starred = [true, false, false, false, false].sample
  read = [true, true, true, false, false].sample
  created = rand(1..30).days.ago + rand(0..23).hours + rand(0..59).minutes

  Message.create!(
    subject: msg_data[:subject],
    body: msg_data[:body],
    sender: sender,
    recipient: me,
    starred: starred,
    read_at: read ? created + rand(1..120).minutes : nil,
    label: "inbox",
    created_at: created
  )
end

# Generate some sent messages
5.times do |i|
  recipient = contacts[i]
  Message.create!(
    subject: "Re: #{subjects_and_bodies[i][:subject]}",
    body: "Thanks for the update. I'll review this and get back to you shortly.",
    sender: me,
    recipient: recipient,
    starred: false,
    read_at: Time.current,
    label: "sent",
    created_at: rand(1..15).days.ago
  )
end

# A couple archived messages
2.times do |i|
  Message.create!(
    subject: subjects_and_bodies[-(i + 1)][:subject],
    body: subjects_and_bodies[-(i + 1)][:body],
    sender: contacts.sample,
    recipient: me,
    starred: false,
    read_at: 2.weeks.ago,
    label: "archive",
    created_at: 1.month.ago
  )
end

puts "Seeded #{Contact.count} contacts and #{Message.count} messages."
```

**Step 2: Run seeds**

```bash
bin/rails db:seed
```

Expected: "Seeded 9 contacts and 37 messages."

**Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: add seed data with realistic inbox messages"
```

---

### Task 4: Set up routes and ApplicationController helper

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`

**Step 1: Define routes**

`config/routes.rb`:

```ruby
Rails.application.routes.draw do
  root "messages#index"

  resources :messages, only: [:index, :show, :create] do
    member do
      patch :toggle_star
      patch :toggle_read
      patch :move
    end
    collection do
      get :search
      get :sent
      get :archive
      get :trash
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

**Step 2: Add current_contact helper**

`app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_contact

  def current_contact
    @current_contact ||= Contact.find_by!(email: "you@example.com")
  end
end
```

**Step 3: Commit**

```bash
git add config/routes.rb app/controllers/application_controller.rb
git commit -m "feat: add routes and current_contact helper"
```

---

### Task 5: Build Phlex layout components

**Files:**
- Create: `app/views/layouts/application_layout.rb`
- Create: `app/views/components/inbox_layout.rb`

**Step 1: Create ApplicationLayout**

`app/views/layouts/application_layout.rb`:

```ruby
class ApplicationLayout < Phlex::HTML
  include Phlex::Rails::Layout

  def view_template
    doctype
    html(class: "h-full bg-gray-100") do
      head do
        title { "Phlex Inbox" }
        meta(name: "viewport", content: "width=device-width,initial-scale=1")
        csrf_meta_tags
        csp_meta_tag
        stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload"
        stylesheet_link_tag "application", "data-turbo-track": "reload"
        javascript_importmap_tags
      end

      body(class: "h-full") do
        yield
      end
    end
  end
end
```

**Step 2: Create InboxLayout component**

`app/views/components/inbox_layout.rb`:

```ruby
class Components::InboxLayout < Phlex::HTML
  def initialize(sidebar:, message_list:, message_detail: nil)
    @sidebar = sidebar
    @message_list = message_list
    @message_detail = message_detail
  end

  def view_template
    div(class: "h-screen flex flex-col") do
      # Top bar
      header(class: "bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between shrink-0") do
        h1(class: "text-xl font-bold text-gray-900") { "Phlex Inbox" }
        render Components::SearchBar.new
      end

      # 3-column layout
      div(class: "flex flex-1 overflow-hidden") do
        # Sidebar
        aside(class: "w-56 bg-white border-r border-gray-200 overflow-y-auto shrink-0") do
          render @sidebar
        end

        # Message list
        div(class: "w-96 border-r border-gray-200 overflow-y-auto bg-white shrink-0") do
          turbo_frame_tag("message_list") do
            render @message_list
          end
        end

        # Message detail
        main(class: "flex-1 overflow-y-auto bg-white") do
          turbo_frame_tag("message_detail") do
            if @message_detail
              render @message_detail
            else
              render Components::EmptyState.new(
                title: "Select a message",
                description: "Choose a message from the list to read it."
              )
            end
          end
        end
      end
    end
  end
end
```

**Step 3: Commit**

```bash
git add app/views/layouts/application_layout.rb app/views/components/inbox_layout.rb
git commit -m "feat: add ApplicationLayout and InboxLayout Phlex components"
```

---

### Task 6: Build reusable Phlex components

**Files:**
- Create: `app/views/components/avatar.rb`
- Create: `app/views/components/badge.rb`
- Create: `app/views/components/button.rb`
- Create: `app/views/components/empty_state.rb`
- Create: `app/views/components/search_bar.rb`

**Step 1: Avatar component**

`app/views/components/avatar.rb`:

```ruby
class Components::Avatar < Phlex::HTML
  SIZES = {
    sm: "w-8 h-8 text-xs",
    md: "w-10 h-10 text-sm",
    lg: "w-12 h-12 text-base"
  }.freeze

  COLORS = %w[
    bg-red-500 bg-blue-500 bg-green-500 bg-purple-500
    bg-yellow-500 bg-pink-500 bg-indigo-500 bg-teal-500
  ].freeze

  def initialize(contact:, size: :md)
    @contact = contact
    @size = size
  end

  def view_template
    if @contact.avatar_url.present?
      img(
        src: @contact.avatar_url,
        alt: @contact.name,
        class: "#{SIZES[@size]} rounded-full object-cover"
      )
    else
      div(
        class: "#{SIZES[@size]} rounded-full flex items-center justify-center text-white font-medium #{color_for_contact}"
      ) { @contact.initials }
    end
  end

  private

  def color_for_contact
    COLORS[@contact.name.bytes.sum % COLORS.length]
  end
end
```

**Step 2: Badge component**

`app/views/components/badge.rb`:

```ruby
class Components::Badge < Phlex::HTML
  def initialize(count:)
    @count = count
  end

  def view_template
    return if @count.zero?

    span(
      class: "inline-flex items-center justify-center px-2 py-0.5 text-xs font-medium bg-blue-600 text-white rounded-full"
    ) { @count.to_s }
  end
end
```

**Step 3: Button component**

`app/views/components/button.rb`:

```ruby
class Components::Button < Phlex::HTML
  VARIANTS = {
    primary: "bg-blue-600 text-white hover:bg-blue-700 px-4 py-2 rounded-lg font-medium",
    ghost: "text-gray-600 hover:text-gray-900 hover:bg-gray-100 px-3 py-1.5 rounded-lg",
    icon: "text-gray-400 hover:text-gray-600 p-1.5 rounded-full hover:bg-gray-100"
  }.freeze

  def initialize(variant: :primary, **attrs)
    @variant = variant
    @attrs = attrs
  end

  def view_template
    button(class: VARIANTS[@variant], **@attrs) { yield }
  end
end
```

**Step 4: EmptyState component**

`app/views/components/empty_state.rb`:

```ruby
class Components::EmptyState < Phlex::HTML
  def initialize(title:, description:)
    @title = title
    @description = description
  end

  def view_template
    div(class: "flex flex-col items-center justify-center h-full text-center p-8") do
      svg(
        class: "w-16 h-16 text-gray-300 mb-4",
        fill: "none",
        stroke: "currentColor",
        viewBox: "0 0 24 24"
      ) do |s|
        s.path(
          stroke_linecap: "round",
          stroke_linejoin: "round",
          stroke_width: "1.5",
          d: "M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
        )
      end
      h3(class: "text-lg font-medium text-gray-900 mb-1") { @title }
      p(class: "text-sm text-gray-500") { @description }
    end
  end
end
```

**Step 5: SearchBar component**

`app/views/components/search_bar.rb`:

```ruby
class Components::SearchBar < Phlex::HTML
  include Phlex::Rails::Helpers::FormWith

  def view_template
    div(data: { controller: "search" }) do
      form_with(
        url: helpers.search_messages_path,
        method: :get,
        data: { turbo_frame: "message_list", search_target: "form" }
      ) do |f|
        div(class: "relative") do
          input(
            type: "search",
            name: "q",
            placeholder: "Search messages...",
            class: "w-72 pl-10 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
            data: { search_target: "input", action: "input->search#submit" }
          )
          div(class: "absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none") do
            svg(class: "h-4 w-4 text-gray-400", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
              s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z")
            end
          end
        end
      end
    end
  end
end
```

**Step 6: Commit**

```bash
git add app/views/components/
git commit -m "feat: add reusable Phlex components (Avatar, Badge, Button, EmptyState, SearchBar)"
```

---

### Task 7: Build Sidebar component

**Files:**
- Create: `app/views/components/sidebar.rb`

**Step 1: Create Sidebar component**

`app/views/components/sidebar.rb`:

```ruby
class Components::Sidebar < Phlex::HTML
  include Phlex::Rails::Helpers::LinkTo

  FOLDERS = [
    { label: "Inbox", path: :root_path, icon: "M2.25 13.5h3.86a2.25 2.25 0 012.012 1.244l.256.512a2.25 2.25 0 002.013 1.244h3.218a2.25 2.25 0 002.013-1.244l.256-.512a2.25 2.25 0 012.013-1.244h3.859m-19.5.338V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 2.25 0 00-2.15-1.588H6.911a2.25 2.25 0 00-2.15 1.588L2.35 13.177a2.25 2.25 0 00-.1.661z", scope: :inbox },
    { label: "Sent", path: :sent_messages_path, icon: "M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5", scope: :sent_box },
    { label: "Archive", path: :archive_messages_path, icon: "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z", scope: :archived },
    { label: "Trash", path: :trash_messages_path, icon: "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0", scope: :trashed }
  ].freeze

  def initialize(current_folder:, current_contact:)
    @current_folder = current_folder
    @current_contact = current_contact
  end

  def view_template
    nav(class: "py-4") do
      # Compose button
      div(class: "px-4 mb-4") do
        button(
          class: "w-full bg-blue-600 text-white rounded-xl px-4 py-3 text-sm font-medium hover:bg-blue-700 transition-colors flex items-center justify-center gap-2",
          data: { action: "click->compose#open" }
        ) do
          svg(class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
            s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M12 4.5v15m7.5-7.5h-15")
          end
          span { "Compose" }
        end
      end

      # Folder list
      ul(class: "space-y-1 px-2") do
        FOLDERS.each do |folder|
          active = @current_folder == folder[:label].downcase
          count = @current_contact.received_messages.send(folder[:scope]).unread.count

          li do
            link_to(
              helpers.send(folder[:path]),
              class: "flex items-center gap-3 px-3 py-2 rounded-lg text-sm #{active ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-700 hover:bg-gray-100'}",
              data: { turbo_frame: "message_list" }
            ) do
              svg(class: "w-5 h-5 #{active ? 'text-blue-600' : 'text-gray-400'}", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
                s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "1.5", d: folder[:icon])
              end
              span { folder[:label] }
              if count > 0
                render Components::Badge.new(count: count)
              end
            end
          end
        end
      end
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/views/components/sidebar.rb
git commit -m "feat: add Sidebar component with folder navigation and unread counts"
```

---

### Task 8: Build MessageRow and MessageList components

**Files:**
- Create: `app/views/components/message_row.rb`
- Create: `app/views/components/message_list.rb`

**Step 1: MessageRow component**

`app/views/components/message_row.rb`:

```ruby
class Components::MessageRow < Phlex::HTML
  include Phlex::Rails::Helpers::LinkTo

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  def view_template
    div(
      id: helpers.dom_id(@message),
      class: "border-b border-gray-100 #{@selected ? 'bg-blue-50' : 'hover:bg-gray-50'} #{@message.read? ? '' : 'bg-blue-50/30'}"
    ) do
      link_to(
        helpers.message_path(@message),
        class: "flex items-start gap-3 px-4 py-3",
        data: { turbo_frame: "message_detail" }
      ) do
        # Avatar
        render Components::Avatar.new(contact: @message.sender, size: :sm)

        # Content
        div(class: "flex-1 min-w-0") do
          div(class: "flex items-center justify-between") do
            span(class: "text-sm #{@message.read? ? 'text-gray-700' : 'font-semibold text-gray-900'} truncate") do
              @message.sender.name
            end
            span(class: "text-xs text-gray-400 whitespace-nowrap ml-2") do
              helpers.time_ago_in_words(@message.created_at) + " ago"
            end
          end

          p(class: "text-sm #{@message.read? ? 'text-gray-500' : 'font-medium text-gray-800'} truncate") do
            @message.subject
          end

          p(class: "text-xs text-gray-400 truncate mt-0.5") do
            @message.preview(80)
          end
        end

        # Star button
        div(class: "flex flex-col items-center gap-1 ml-2 shrink-0") do
          button(
            class: "p-1 rounded-full hover:bg-gray-200",
            data: {
              controller: "star",
              action: "click->star#toggle",
              star_url_value: helpers.toggle_star_message_path(@message)
            }
          ) do
            if @message.starred?
              svg(class: "w-4 h-4 text-yellow-400 fill-current", viewBox: "0 0 24 24") do |s|
                s.path(d: "M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z")
              end
            else
              svg(class: "w-4 h-4 text-gray-300", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
                s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "1.5", d: "M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z")
              end
            end
          end

          # Unread dot
          unless @message.read?
            div(class: "w-2 h-2 bg-blue-600 rounded-full")
          end
        end
      end
    end
  end
end
```

**Step 2: MessageList component**

`app/views/components/message_list.rb`:

```ruby
class Components::MessageList < Phlex::HTML
  def initialize(messages:, folder:, selected_id: nil)
    @messages = messages
    @folder = folder
    @selected_id = selected_id
  end

  def view_template
    div(class: "divide-y divide-gray-100") do
      # Folder header
      div(class: "px-4 py-3 bg-gray-50 border-b border-gray-200 sticky top-0") do
        h2(class: "text-sm font-semibold text-gray-700 capitalize") { @folder }
        span(class: "text-xs text-gray-400") { "#{@messages.size} messages" }
      end

      if @messages.any?
        @messages.each do |message|
          render Components::MessageRow.new(
            message: message,
            selected: message.id == @selected_id
          )
        end
      else
        render Components::EmptyState.new(
          title: "No messages",
          description: "Your #{@folder} folder is empty."
        )
      end
    end
  end
end
```

**Step 3: Commit**

```bash
git add app/views/components/message_row.rb app/views/components/message_list.rb
git commit -m "feat: add MessageRow and MessageList Phlex components"
```

---

### Task 9: Build MessageDetail and ComposeModal components

**Files:**
- Create: `app/views/components/message_detail.rb`
- Create: `app/views/components/compose_modal.rb`

**Step 1: MessageDetail component**

`app/views/components/message_detail.rb`:

```ruby
class Components::MessageDetail < Phlex::HTML
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo

  def initialize(message:)
    @message = message
  end

  def view_template
    div(class: "p-6 max-w-3xl") do
      # Actions bar
      div(class: "flex items-center gap-2 mb-6") do
        action_button("Archive", helpers.move_message_path(@message, label: "archive"), icon: archive_icon)
        action_button("Trash", helpers.move_message_path(@message, label: "trash"), icon: trash_icon)
        toggle_button("Mark unread", helpers.toggle_read_message_path(@message), icon: envelope_icon)
      end

      # Subject
      h1(class: "text-xl font-semibold text-gray-900 mb-4") { @message.subject }

      # Sender info
      div(class: "flex items-start gap-3 mb-6") do
        render Components::Avatar.new(contact: @message.sender, size: :lg)

        div(class: "flex-1") do
          div(class: "flex items-center gap-2") do
            span(class: "font-medium text-gray-900") { @message.sender.name }
            span(class: "text-sm text-gray-400") { "<#{@message.sender.email}>" }
          end
          p(class: "text-sm text-gray-500") do
            "to #{@message.recipient.name} - #{helpers.time_ago_in_words(@message.created_at)} ago"
          end
        end
      end

      # Body
      div(class: "prose prose-sm max-w-none text-gray-700 mb-8 whitespace-pre-wrap") do
        @message.body
      end

      # Reply button
      div(class: "border-t border-gray-200 pt-4") do
        button(
          class: "inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-50",
          data: { action: "click->compose#reply", compose_message_id_param: @message.id, compose_sender_param: @message.sender.name, compose_subject_param: @message.subject }
        ) do
          svg(class: "w-4 h-4", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
            s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3")
          end
          span { "Reply" }
        end
      end
    end
  end

  private

  def action_button(label, path, icon:)
    button_to(
      path,
      method: :patch,
      class: "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg",
      data: { turbo_stream: true }
    ) do
      raw(icon)
      plain(label)
    end
  end

  def toggle_button(label, path, icon:)
    button_to(
      path,
      method: :patch,
      class: "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg",
      data: { turbo_stream: true }
    ) do
      raw(icon)
      plain(label)
    end
  end

  def archive_icon
    '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"/></svg>'
  end

  def trash_icon
    '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"/></svg>'
  end

  def envelope_icon
    '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"/></svg>'
  end
end
```

**Step 2: ComposeModal component**

`app/views/components/compose_modal.rb`:

```ruby
class Components::ComposeModal < Phlex::HTML
  include Phlex::Rails::Helpers::FormWith

  def initialize(contacts:, reply_to: nil)
    @contacts = contacts
    @reply_to = reply_to
  end

  def view_template
    div(
      data: { controller: "compose", compose_open_class: "flex", compose_closed_class: "hidden" },
      class: "hidden fixed inset-0 z-50 items-center justify-center bg-black/50"
    ) do
      div(class: "bg-white rounded-xl shadow-2xl w-full max-w-lg mx-4") do
        # Header
        div(class: "flex items-center justify-between px-4 py-3 border-b border-gray-200") do
          h2(class: "text-base font-semibold text-gray-900") do
            @reply_to ? "Reply" : "New Message"
          end
          button(
            class: "text-gray-400 hover:text-gray-600 p-1",
            data: { action: "click->compose#close" }
          ) do
            svg(class: "w-5 h-5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
              s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M6 18L18 6M6 6l12 12")
            end
          end
        end

        # Form
        form_with(url: helpers.messages_path, class: "p-4 space-y-3") do |f|
          if @reply_to
            f.hidden_field :replied_to_id, value: @reply_to.id
            f.hidden_field :recipient_id, value: @reply_to.sender_id
          end

          # To field (only for new messages)
          unless @reply_to
            div do
              f.label :recipient_id, "To", class: "block text-sm font-medium text-gray-700 mb-1"
              f.select(
                :recipient_id,
                @contacts.map { |c| [c.name, c.id] },
                { prompt: "Select recipient..." },
                class: "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              )
            end
          end

          # Subject
          div do
            f.label :subject, "Subject", class: "block text-sm font-medium text-gray-700 mb-1"
            f.text_field(
              :subject,
              value: @reply_to ? "Re: #{@reply_to.subject}" : "",
              class: "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500",
              data: { compose_target: "subject" }
            )
          end

          # Body
          div do
            f.label :body, "Message", class: "block text-sm font-medium text-gray-700 mb-1"
            f.text_area(
              :body,
              rows: 8,
              class: "w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none",
              data: { compose_target: "body" }
            )
          end

          # Submit
          div(class: "flex justify-end gap-2 pt-2") do
            button(
              type: "button",
              class: "px-4 py-2 text-sm text-gray-600 hover:text-gray-900",
              data: { action: "click->compose#close" }
            ) { "Cancel" }
            f.submit(
              "Send",
              class: "px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700 cursor-pointer"
            )
          end
        end
      end
    end
  end
end
```

**Step 3: Commit**

```bash
git add app/views/components/message_detail.rb app/views/components/compose_modal.rb
git commit -m "feat: add MessageDetail and ComposeModal Phlex components"
```

---

### Task 10: Build MessagesController and Phlex views

**Files:**
- Create: `app/controllers/messages_controller.rb`
- Create: `app/views/messages/index.rb`
- Create: `app/views/messages/show.rb`

**Step 1: Create the controller**

`app/controllers/messages_controller.rb`:

```ruby
class MessagesController < ApplicationController
  layout -> { ApplicationLayout }

  before_action :set_message, only: [:show, :toggle_star, :toggle_read, :move]

  def index
    @folder = "inbox"
    @messages = current_contact.received_messages.inbox.newest_first
    render Views::Messages::Index.new(messages: @messages, folder: @folder, current_contact: current_contact)
  end

  def sent
    @folder = "sent"
    @messages = current_contact.sent_messages.sent_box.newest_first
    render Views::Messages::Index.new(messages: @messages, folder: @folder, current_contact: current_contact)
  end

  def archive
    @folder = "archive"
    @messages = current_contact.received_messages.archived.newest_first
    render Views::Messages::Index.new(messages: @messages, folder: @folder, current_contact: current_contact)
  end

  def trash
    @folder = "trash"
    @messages = current_contact.received_messages.trashed.newest_first
    render Views::Messages::Index.new(messages: @messages, folder: @folder, current_contact: current_contact)
  end

  def show
    @message.mark_as_read!
    render Views::Messages::Show.new(message: @message)
  end

  def create
    recipient_id = params[:recipient_id] || params.dig(:message, :recipient_id)
    replied_to_id = params[:replied_to_id] || params.dig(:message, :replied_to_id)

    @message = Message.new(
      subject: params[:subject] || params.dig(:message, :subject),
      body: params[:body] || params.dig(:message, :body),
      sender: current_contact,
      recipient_id: recipient_id,
      replied_to_id: replied_to_id,
      label: "sent",
      read_at: Time.current
    )

    if @message.save
      redirect_to root_path, notice: "Message sent!"
    else
      redirect_to root_path, alert: "Failed to send message."
    end
  end

  def search
    query = params[:q].to_s.strip
    @messages = if query.present?
      current_contact.received_messages
        .where("subject LIKE :q OR body LIKE :q", q: "%#{query}%")
        .newest_first
    else
      current_contact.received_messages.inbox.newest_first
    end
    @folder = query.present? ? "search" : "inbox"

    render Views::Messages::Index.new(messages: @messages, folder: @folder, current_contact: current_contact)
  end

  def toggle_star
    @message.toggle_starred!
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @message,
          Components::MessageRow.new(message: @message)
        )
      end
      format.html { redirect_to root_path }
    end
  end

  def toggle_read
    if @message.read?
      @message.update!(read_at: nil)
    else
      @message.mark_as_read!
    end
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          @message,
          Components::MessageRow.new(message: @message)
        )
      end
      format.html { redirect_to root_path }
    end
  end

  def move
    @message.update!(label: params[:label])
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@message)
      end
      format.html { redirect_to root_path }
    end
  end

  private

  def set_message
    @message = Message.find(params[:id])
  end
end
```

**Step 2: Create index view**

`app/views/messages/index.rb`:

```ruby
class Views::Messages::Index < Phlex::HTML
  def initialize(messages:, folder:, current_contact:)
    @messages = messages
    @folder = folder
    @current_contact = current_contact
  end

  def view_template
    render Components::InboxLayout.new(
      sidebar: Components::Sidebar.new(current_folder: @folder, current_contact: @current_contact),
      message_list: Components::MessageList.new(messages: @messages, folder: @folder)
    )

    # Compose modal (always present in DOM)
    contacts = Contact.where.not(id: @current_contact.id).order(:name)
    render Components::ComposeModal.new(contacts: contacts)
  end
end
```

**Step 3: Create show view (for Turbo Frame)**

`app/views/messages/show.rb`:

```ruby
class Views::Messages::Show < Phlex::HTML
  def initialize(message:)
    @message = message
  end

  def view_template
    turbo_frame_tag("message_detail") do
      render Components::MessageDetail.new(message: @message)
    end
  end
end
```

**Step 4: Verify routes and boot**

```bash
bin/rails routes | head -20
bin/rails db:seed
bin/rails server -p 3000 &
sleep 3
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
kill %1
```

Expected: 200

**Step 5: Commit**

```bash
git add app/controllers/messages_controller.rb app/views/messages/
git commit -m "feat: add MessagesController and Phlex views for inbox"
```

---

### Task 11: Add Stimulus controllers

**Files:**
- Create: `app/javascript/controllers/search_controller.js`
- Create: `app/javascript/controllers/compose_controller.js`
- Create: `app/javascript/controllers/star_controller.js`
- Create: `app/javascript/controllers/keyboard_controller.js`

**Step 1: Search controller**

`app/javascript/controllers/search_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input"]

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.formTarget.requestSubmit()
    }, 300)
  }
}
```

**Step 2: Compose controller**

`app/javascript/controllers/compose_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = ["open", "closed"]
  static targets = ["subject", "body"]

  open() {
    this.element.classList.remove(...this.closedClasses)
    this.element.classList.add(...this.openClasses)
  }

  close() {
    this.element.classList.remove(...this.openClasses)
    this.element.classList.add(...this.closedClasses)
  }

  reply(event) {
    const { messageIdParam, senderParam, subjectParam } = event.params
    this.open()
    if (this.hasSubjectTarget) {
      this.subjectTarget.value = `Re: ${subjectParam}`
    }
    if (this.hasBodyTarget) {
      this.bodyTarget.focus()
    }
  }
}
```

**Step 3: Star controller**

`app/javascript/controllers/star_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })
  }
}
```

**Step 4: Keyboard controller**

`app/javascript/controllers/keyboard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    // Don't handle if user is typing in an input
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA" || event.target.tagName === "SELECT") {
      return
    }

    const rows = document.querySelectorAll("[id^='message_']")
    const current = document.querySelector("[id^='message_'].bg-blue-50")
    const currentIndex = current ? Array.from(rows).indexOf(current) : -1

    switch (event.key) {
      case "j": // Next message
        if (currentIndex < rows.length - 1) {
          const next = rows[currentIndex + 1]
          const link = next.querySelector("a")
          if (link) link.click()
        }
        break
      case "k": // Previous message
        if (currentIndex > 0) {
          const prev = rows[currentIndex - 1]
          const link = prev.querySelector("a")
          if (link) link.click()
        }
        break
      case "s": // Star
        if (current) {
          const starBtn = current.querySelector("[data-controller='star']")
          if (starBtn) starBtn.click()
        }
        break
    }
  }
}
```

**Step 5: Register keyboard controller on body**

Update `app/views/layouts/application_layout.rb` -- change the body tag to:

```ruby
body(class: "h-full", data: { controller: "keyboard" }) do
```

**Step 6: Commit**

```bash
git add app/javascript/controllers/ app/views/layouts/application_layout.rb
git commit -m "feat: add Stimulus controllers for search, compose, star, and keyboard"
```

---

### Task 12: Wire up Turbo Frames in index response

The folder links and search need to return just the message list frame, not the full layout, when requested via Turbo Frame.

**Files:**
- Modify: `app/controllers/messages_controller.rb`
- Create: `app/views/messages/message_list_frame.rb`

**Step 1: Create a frame-only view**

`app/views/messages/message_list_frame.rb`:

```ruby
class Views::Messages::MessageListFrame < Phlex::HTML
  def initialize(messages:, folder:)
    @messages = messages
    @folder = folder
  end

  def view_template
    turbo_frame_tag("message_list") do
      render Components::MessageList.new(messages: @messages, folder: @folder)
    end
  end
end
```

**Step 2: Update controller actions to respond to Turbo Frames**

In `app/controllers/messages_controller.rb`, update each folder action to detect Turbo Frame requests. Add this helper method:

```ruby
private

def render_message_list(messages, folder)
  if turbo_frame_request?
    render Views::Messages::MessageListFrame.new(messages: messages, folder: folder), layout: false
  else
    render Views::Messages::Index.new(messages: messages, folder: folder, current_contact: current_contact)
  end
end
```

Then update `index`, `sent`, `archive`, `trash`, and `search` actions to call `render_message_list(@messages, @folder)` instead of their current render.

**Step 3: Commit**

```bash
git add app/controllers/messages_controller.rb app/views/messages/message_list_frame.rb
git commit -m "feat: add Turbo Frame responses for folder navigation and search"
```

---

### Task 13: Run full test suite and smoke test in browser

**Step 1: Run tests**

```bash
bin/rails test
```

Expected: All pass.

**Step 2: Boot and visually verify**

```bash
bin/rails db:seed
bin/rails server -p 3000
```

Open http://localhost:3000 and verify:
- 3-column layout renders
- Sidebar folders show with unread counts
- Clicking a message loads detail in right pane
- Clicking folders swaps message list
- Star toggle works
- Compose modal opens/closes
- Search filters messages
- j/k keyboard navigation works

**Step 3: Commit any fixes**

```bash
git add -A
git commit -m "chore: final polish and bug fixes"
```
