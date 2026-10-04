# Summarises AI agent usage records into the JSON the agents panel shows.
# Input: one object per line, {agent, id, t (epoch s), model, tokens, cache_read, session}
# plus optional {agent, limit: {label, used_percent, resets_at}} lines.
# $days: how many days to show; $now: current epoch seconds.
def day: strflocaltime("%Y-%m-%d");
[inputs] as $all
| ($all | map(select(.limit | not))) as $recs
| ($all | map(select(.limit))) as $limits
| [range(0; $days) as $i | ($now - ($days - 1 - $i) * 86400) | day] as $dates
| {
    updated: $now,
    agents: (
      $recs | group_by(.agent) | map(
        (.[0].agent) as $name
        | (unique_by(.id)) as $r
        | {
            name: $name,
            days: [ $dates[] as $d
                    | ($r | map(select((.t | day) == $d))) as $x
                    | { date: $d,
                        tokens: ($x | map(.tokens) | add // 0),
                        cache_read: ($x | map(.cache_read) | add // 0),
                        messages: ($x | length),
                        sessions: ($x | map(.session) | unique | length) } ],
            models: ($r | map(select((.t | day) as $d | $dates | index($d)))
                        | group_by(.model) | map({ model: .[0].model, tokens: (map(.tokens) | add // 0) })
                        | sort_by(-.tokens)),
            limits: ($limits | map(select(.agent == $name)) | map(.limit) | group_by(.label) | map(last))
          }
        | .today = .days[-1]
      )
      | map(select((.days | map(.messages) | add) > 0))
    )
  }
