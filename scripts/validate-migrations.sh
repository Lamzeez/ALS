#!/usr/bin/env bash
# Basic validation for SQL migration files.
set -euo pipefail
repo_root=$(dirname "${BASH_SOURCE[0]}")/..
echo "Checking SQL migrations under supabase/migrations"      
errors=0
for file in $(find "$repo_root/supabase/migrations" -type f -name '*.sql' 2>/dev/null); do
  echo "- Checking $file"
  # Check for missing semicolons at end of file (very naive)
  last=$(tail -n 1 "$file" | tr -d '[:space:]')
  if [[ -n "$last" && "${last: -1}" != ";" ]]; then
    echo "  WARNING: Last line does not end with a semicolon"
    errors=$((errors+1))
  fi
  # Check for duplicate CREATE TABLE names
  grep -i "create table" -n "$file" | sed -E "s/.*create table[[:space:]]+([^"]+).*/\1/I" | tr -d '"' >> /tmp/_migration_tables 2>/dev/null || true
done
if [ -f /tmp/_migration_tables ]; then
  sort /tmp/_migration_tables | uniq -d > /tmp/_migration_duplicates || true
  if [ -s /tmp/_migration_duplicates ]; then
    echo "Duplicate table names found across migrations:" && cat /tmp/_migration_duplicates
    errors=$((errors+1))
  fi
  rm -f /tmp/_migration_tables /tmp/_migration_duplicates
fi

if [ "$errors" -gt 0 ]; then
  echo "Validation completed: $errors potential issues found. Please review the warnings above."
  exit 2
else
  echo "Validation completed: no obvious issues found."
fi
