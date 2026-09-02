#!/usr/bin/env sh
awk '
  /^\+\+\+ / { path = substr($2, 3); next }
  /^@@ /     { split($3, a, ","); line = substr(a[1], 2) + 0; next }
  /^-/       { next }
  /^\+/      {
    if ($0 ~ /console\.(log|debug)|debugger|\.only\(|\.skip\(|\/\/ *(TODO|FIXME|HACK|temp)|XXX|dd\(\)|binding\.pry|print\(/)
      printf "%s:%d - %s\n", path, line, substr($0, 2)
    line++; next
  }
  { line++ }
'
