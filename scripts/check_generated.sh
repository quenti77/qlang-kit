#!/bin/sh
# Generates every kind of file into a fresh web project and checks that it all passes `qlang fmt --check`,
# `qlang check` and the tests of the generated controller.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
cd "$work"
qlang init --web . >/dev/null
for spec in "controller BlogPost" "model BlogPost" "migration create_blog_posts_table" "migration add_age_to_users" "provider Mailer" \
  "job SendWelcome" "middleware RequestId" "policy Post" "resource Post" "factory BlogPost" "seeder BlogPost" \
  "command GreetUser"; do
  # shellcheck disable=SC2086
  qlang run "$here/main.q" -- make $spec
done
qlang fmt --check
for f in app.q migrations.q providers/*.q controllers/*.q models/*.q migrations/*.q jobs/*.q middleware/*.q policies/*.q resources/*.q factories/*.q seeders/*.q commands/*.q; do
  qlang check "$f" >/dev/null
done
# the migrations are all in migrations.q, and the application can still be put together
test "$(grep -c '\.migration(),' migrations.q)" = 2
test "$(grep -c 'providers_mailer' app.q)" = 2
qlang test
echo "generated files are in order"
