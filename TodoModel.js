.pragma library

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function dateKey(timestamp) {
  var d = new Date(timestamp)
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function formatDateLabel(timestamp) {
  var target = new Date(timestamp)
  var now = new Date()

  var todayKey = dateKey(now.getTime())
  var targetKey = dateKey(timestamp)

  if (targetKey === todayKey) {
    return "Today"
  }

  var yesterday = new Date(now.getTime() - 86400000)
  if (targetKey === dateKey(yesterday.getTime())) {
    return "Yesterday"
  }

  var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  var dayName = days[target.getDay()]
  var monthName = months[target.getMonth()]
  var dayNum = target.getDate()

  if (target.getFullYear() === now.getFullYear()) {
    return dayName + ", " + monthName + " " + dayNum
  } else {
    return monthName + " " + dayNum + ", " + target.getFullYear()
  }
}

function formatTimeLabel(timestamp) {
  var d = new Date(timestamp)
  var hours = d.getHours()
  var minutes = d.getMinutes()
  var ampm = hours >= 12 ? "PM" : "AM"
  hours = hours % 12
  hours = hours ? hours : 12
  return hours + ":" + pad2(minutes) + " " + ampm
}

function parseItems(raw) {
  if (!raw || typeof raw !== "string") return []
  try {
    var parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) return []
    var clean = []
    for (var i = 0; i < parsed.length; i++) {
      var item = parsed[i]
      if (item && typeof item === "object" && typeof item.text === "string") {
        clean.push({
          id: String(item.id || ("act_" + Date.now() + "_" + i)),
          text: String(item.text),
          completed: !!item.completed,
          createdAt: Number(item.createdAt) || Date.now(),
          completedAt: item.completedAt ? Number(item.completedAt) : null
        })
      }
    }
    return clean
  } catch (e) {
    return []
  }
}

function addItem(items, text) {
  var trimmed = String(text || "").trim()
  if (!trimmed) return items

  var newItem = {
    id: "todo_" + Date.now() + "_" + Math.floor(Math.random() * 100000),
    text: trimmed,
    completed: false,
    createdAt: Date.now(),
    completedAt: null
  }

  var next = items.slice()
  next.unshift(newItem)
  return next
}

function toggleItem(items, id) {
  var next = []
  for (var i = 0; i < items.length; i++) {
    var it = items[i]
    if (it.id === id) {
      var willComplete = !it.completed
      next.push({
        id: it.id,
        text: it.text,
        completed: willComplete,
        createdAt: it.createdAt,
        completedAt: willComplete ? Date.now() : null
      })
    } else {
      next.push(it)
    }
  }
  return next
}

function deleteItem(items, id) {
  var next = []
  for (var i = 0; i < items.length; i++) {
    if (items[i].id !== id) {
      next.push(items[i])
    }
  }
  return next
}

function clearHistory(items) {
  var next = []
  for (var i = 0; i < items.length; i++) {
    if (!items[i].completed) {
      next.push(items[i])
    }
  }
  return next
}

function countActive(items) {
  var count = 0
  for (var i = 0; i < items.length; i++) {
    if (!items[i].completed) count++
  }
  return count
}

function countCompleted(items) {
  var count = 0
  for (var i = 0; i < items.length; i++) {
    if (items[i].completed) count++
  }
  return count
}

function organizeByDate(items, tab) {
  var isHistory = tab === "history"
  var filtered = []

  for (var i = 0; i < items.length; i++) {
    var it = items[i]
    if (isHistory ? it.completed : !it.completed) {
      filtered.push(it)
    }
  }

  // Sort by date descending (newest first)
  filtered.sort(function(a, b) {
    var timeA = isHistory ? (a.completedAt || a.createdAt) : a.createdAt
    var timeB = isHistory ? (b.completedAt || b.createdAt) : b.createdAt
    return timeB - timeA
  })

  // Group by dateKey
  var groups = []
  var groupMap = {}

  for (var j = 0; j < filtered.length; j++) {
    var item = filtered[j]
    var timestamp = isHistory ? (item.completedAt || item.createdAt) : item.createdAt
    var key = dateKey(timestamp)

    if (!groupMap[key]) {
      groupMap[key] = {
        key: key,
        label: formatDateLabel(timestamp),
        items: []
      }
      groups.push(groupMap[key])
    }
    groupMap[key].items.push(item)
  }

  // Flatten into rows with section headers
  var rows = []
  for (var g = 0; g < groups.length; g++) {
    var grp = groups[g]
    var count = grp.items.length
    var countStr = count === 1 ? "1 task" : count + " tasks"

    rows.push({
      isHeader: true,
      headerTitle: grp.label,
      headerCount: countStr,
      itemId: "header_" + grp.key,
      itemText: "",
      timeLabel: "",
      completed: false
    })

    for (var k = 0; k < grp.items.length; k++) {
      var act = grp.items[k]
      var actTime = isHistory ? (act.completedAt || act.createdAt) : act.createdAt
      rows.push({
        isHeader: false,
        headerTitle: "",
        headerCount: "",
        itemId: act.id,
        itemText: act.text,
        timeLabel: formatTimeLabel(actTime),
        completed: act.completed
      })
    }
  }

  return rows
}
