#!/usr/bin/env bash
# Fails when a comment in a tracked Dart, shell, rules, JavaScript or workflow
# file uses wording that only makes sense at the time it was written: "for
# now", version or phase numbers, and the like (the list is $phrases below).
# scripts/comment-allowlist.txt allows a phrase in one file, one
# "<path> <phrase>" per line, for a use that stays true.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

phrases='for now|for the time being|previously|any ?more|eventually|in the future|later on|todo later|v[0-9]+|phase [0-9]+'
allowlist=scripts/comment-allowlist.txt

git ls-files -z -- '*.dart' '*.sh' '*.rules' '*.js' '*.yml' '.githooks/*' '.claude/hooks/*' |
  PHRASES=$phrases ALLOWLIST=$allowlist perl -0 -ne '
    BEGIN {
      local $/ = "\n";
      if (open my $fh, "<", $ENV{ALLOWLIST}) {
        while (<$fh>) { chomp; $allowed{lc $_} = 1 if /\S/ && !/^#/ }
      }
    }
    chomp(my $path = $_);
    next if $path eq "lib/firebase_options.dart" || !-f $path;
    local $/ = "\n";
    open my $file, "<", $path or die "$path: $!\n";
    while (my $line = <$file>) {
      my ($comment) = $line =~ m{^\s*(?://|#(?!!))(.*)};
      ($comment) = $line =~ m{\s(?://|#)\s(.*)} unless defined $comment;
      next unless defined $comment;
      while ($comment =~ /\b($ENV{PHRASES})\b/gi) {
        next if $allowed{lc "$path $1"};
        print STDERR "$path:$.: \"$1\" in a comment only makes sense when it was written.\n";
        $found = 1;
      }
    }
    # Setting $? rather than calling exit keeps a die'"'"'s failure status.
    END { $? = 1 if $found && !$? }
  '
