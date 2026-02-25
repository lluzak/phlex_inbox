import { describe, it, expect } from "vitest"
import { buildOptimisticData } from "../../app/javascript/lib/optimistic_utils.js"

describe("buildOptimisticData", () => {
  const fieldMap = {
    "@message.sender.name": "v2",
    "@message.sender.initials": "v3",
    "@message.sender_avatar_url": "v1",
    "avatar_color(@message.sender)": "v4",
    "@message.read?": "v5",
    "@message.starred?": "v6",
    "time_ago_in_words(@message.created_at)": "v7",
    "@message.subject": "v8",
    "@message.labels": "v9",
    "@message.preview": "v12",
    "message_path(@message)": "v0"
  }

  const userInfo = {
    name: "You",
    initials: "YO",
    avatarUrl: null,
    avatarColor: "bg-blue-500"
  }

  it("builds data with correct opaque keys from field map", () => {
    const data = buildOptimisticData({
      fieldMap,
      userInfo,
      body: "Hello there!",
      subject: "Re: Hi"
    })

    expect(data.v2).toBe("You")
    expect(data.v3).toBe("YO")
    expect(data.v1).toBeNull()
    expect(data.v4).toBe("bg-blue-500")
    expect(data.v5).toBe(true)
    expect(data.v6).toBe(false)
    expect(data.v8).toBe("Re: Hi")
    expect(data.v12).toBe("Hello there!")
    expect(data.v9).toEqual([])
    expect(data.v0).toBe("#")
  })

  it("generates a temporary dom_id", () => {
    const data = buildOptimisticData({ fieldMap, userInfo, body: "Hi", subject: "Re: Hi" })
    expect(data.dom_id).toMatch(/^message_optimistic_/)
    expect(data.id).toBeNull()
  })

  it("sets time_ago_in_words to 'less than a minute'", () => {
    const data = buildOptimisticData({ fieldMap, userInfo, body: "Hi", subject: "Re: Hi" })
    expect(data.v7).toBe("less than a minute")
  })

  it("truncates preview to 100 chars", () => {
    const longBody = "x".repeat(200)
    const data = buildOptimisticData({ fieldMap, userInfo, body: longBody, subject: "Re: Hi" })
    expect(data.v12.length).toBeLessThanOrEqual(100)
  })

  it("generates unique dom_ids across calls", () => {
    const d1 = buildOptimisticData({ fieldMap, userInfo, body: "A", subject: "S" })
    const d2 = buildOptimisticData({ fieldMap, userInfo, body: "B", subject: "S" })
    expect(d1.dom_id).not.toBe(d2.dom_id)
  })
})
