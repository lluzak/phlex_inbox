let optimisticCounter = 0

export function buildOptimisticData({ fieldMap, userInfo, body, subject }) {
  optimisticCounter++
  const tempId = `message_optimistic_${Date.now()}_${optimisticCounter}`

  const valueMap = {
    "@message.sender.name": userInfo.name,
    "@message.sender.initials": userInfo.initials,
    "@message.sender_avatar_url": userInfo.avatarUrl || null,
    "avatar_color(@message.sender)": userInfo.avatarColor,
    "@message.read?": true,
    "@message.starred?": false,
    "time_ago_in_words(@message.created_at)": "less than a minute",
    "@message.subject": subject,
    "@message.labels": [],
    "@message.preview": body.substring(0, 100),
    "message_path(@message)": "#"
  }

  const data = { dom_id: tempId, id: null, selected: false }

  for (const [expression, key] of Object.entries(fieldMap)) {
    if (expression in valueMap) {
      data[key] = valueMap[expression]
    }
  }

  return data
}
