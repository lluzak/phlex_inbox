# Skeleton Loading for Turbo Frames — Design

**Goal:** Add skeleton loading screens for empty turbo frames and fade existing content during frame navigations, so the UI never feels frozen.

**Test ground:** Message detail panel (clicking a message from the list).

---

## Architecture

Two mechanisms:

1. **Skeleton component** — rendered as initial content inside the `message_detail` turbo frame when no message is selected. When the user clicks a message, Turbo replaces the skeleton with the real detail. Defined in Ruby/ERB as a dedicated ViewComponent.

2. **Busy state CSS** — `turbo-frame[busy]` fades existing content during any frame navigation (folder switches, search, filter changes, message clicks). Pure CSS, no JS.

---

## Components

### MessageDetailSkeletonComponent

Replaces `EmptyStateComponent` as the default content in the `message_detail` frame. Mimics the message detail layout with gray pulsing placeholder shapes (Tailwind `animate-pulse` + `bg-gray-200`).

Structure:
- Header area: subject line placeholder + avatar circle + sender name line
- Body area: 4-5 text line placeholders of varying widths
- Reply area: button placeholder at the bottom

Simple ViewComponent with static ERB template. No props, no model data.

### No message list skeleton

The message list is always eagerly server-rendered on page load. Folder switches keep old content visible. No skeleton needed.

---

## Turbo Frame Changes

### message_detail frame (inbox_layout_component.html.erb)

**Before:**
```erb
<turbo-frame id="message_detail">
  <% if @message %>
    ...detail...
  <% else %>
    <%= render EmptyStateComponent.new(title: "Select a message", ...) %>
  <% end %>
</turbo-frame>
```

**After:**
```erb
<turbo-frame id="message_detail">
  <% if @message %>
    ...detail...
  <% else %>
    <%= render MessageDetailSkeletonComponent.new %>
  <% end %>
</turbo-frame>
```

---

## CSS

Add to `app/assets/stylesheets/application.css`:

```css
turbo-frame[busy] > :not(.skeleton) {
  opacity: 0.5;
  pointer-events: none;
  transition: opacity 0.15s ease;
}
```

This fades existing content in any turbo frame during navigation. No skeleton is shown during busy — the fade alone signals loading when content already exists.

---

## Scope

**In scope:**
- `MessageDetailSkeletonComponent` — skeleton for empty message detail panel
- `turbo-frame[busy]` CSS fade for all frame navigations

**Out of scope:**
- Message list skeleton (eagerly rendered, not needed)
- Lazy loading frames (no architecture change)
- JS-based loading indicators
- Progress bars
