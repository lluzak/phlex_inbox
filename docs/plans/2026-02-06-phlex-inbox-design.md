# Phlex Inbox -- Design Document

## Overview

A Rails 8 demo project mimicking a Gmail-style email inbox. Showcases Phlex components, Tailwind CSS, Stimulus controllers, and Turbo Frames/Streams working together.

## Tech Stack

- Rails 8.1 with SQLite
- Phlex for all view rendering (no ERB)
- Tailwind CSS for styling
- Stimulus for client-side behavior
- Turbo Frames + Streams for partial page updates
- No authentication -- single hardcoded user

## Data Model

### Contact
- `name` (string)
- `email` (string)
- `avatar_url` (string, nullable)

### Message
- `subject` (string)
- `body` (text)
- `sender_id` (references Contact)
- `recipient_id` (references Contact)
- `read_at` (datetime, nullable -- null means unread)
- `starred` (boolean, default: false)
- `label` (string, enum: inbox/sent/archive/trash, default: inbox)
- `replied_to_id` (references Message, nullable -- for threading)
- `created_at` / `updated_at`

Seeds generate ~30 messages from various contacts with realistic subjects and bodies.

## Layout

Gmail-style 3-column layout:
1. **Sidebar** -- folders (Inbox, Sent, Archive, Trash) with unread counts
2. **Message list** -- scrollable list of message previews for active folder
3. **Message detail** -- full message view with body and actions

## Phlex Components

### Layout
- `AppLayout` -- html shell, asset includes, Stimulus/Turbo setup
- `InboxLayout` -- 3-column CSS grid container

### Structural
- `Sidebar` -- folder nav with unread counts, contact list
- `MessageList` -- scrollable message preview list
- `MessageDetail` -- full message view with reply action

### Reusable
- `MessageRow` -- list row (avatar, subject, preview, timestamp, read dot, star)
- `Avatar` -- contact avatar with initials fallback
- `Badge` -- unread count pill
- `Button` -- styled button (primary, ghost, icon variants)
- `ComposeModal` -- modal form for compose/reply
- `SearchBar` -- search input with Stimulus controller
- `EmptyState` -- empty folder placeholder

## Stimulus Controllers

- `search` -- filters message list, triggers Turbo Frame update
- `compose` -- toggles compose modal open/close
- `star` -- toggles star via Turbo PATCH
- `keyboard` -- keyboard shortcuts (j/k navigate, r reply, s star)

## Turbo Integration

- `MessageList` in a Turbo Frame -- folder clicks swap the list
- `MessageDetail` in a Turbo Frame -- row clicks load detail without full reload
- Star/read/move actions return Turbo Stream responses for in-place updates

## Routes

```
root -> messages#index

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
```

## Controller

Single `MessagesController`:
- `index` -- messages for current folder (default: inbox)
- `show` -- single message, marks as read, Turbo Frame response
- `create` -- compose/reply
- `toggle_star` / `toggle_read` / `move` -- PATCH, Turbo Stream responses
- `search` -- filter by subject/body, Turbo Frame response
- `sent` / `archive` / `trash` -- index scoped by label

Current user is hardcoded as first seeded Contact.

## Implementation Steps

1. Generate Rails app with Tailwind, Stimulus, Turbo (skip ERB default)
2. Add phlex-rails gem
3. Generate models (Contact, Message) and migrations
4. Create seed data
5. Set up routes
6. Build Phlex layout components (AppLayout, InboxLayout)
7. Build Phlex structural components (Sidebar, MessageList, MessageDetail)
8. Build Phlex reusable components (MessageRow, Avatar, Badge, Button, etc.)
9. Build MessagesController with all actions
10. Add Stimulus controllers (search, compose, star, keyboard)
11. Wire up Turbo Frames and Streams
12. Add ComposeModal with compose/reply
13. Polish styling and add seed data variety
