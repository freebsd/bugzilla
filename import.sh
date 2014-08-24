#!/usr/local/bin/bash

export PR_FROM=`cat pr.num`
if [ "$PR_FROM" = "" ]; then
    export PR_FROM=0
fi
set -e

while true; do
    export PR_TO=$((PR_FROM+1000))
    ./migrate.pl           --from=Gnats
    export PR_FROM=$((PR_FROM+1000))
    echo $PR_FROM > pr.num
    #pg_dump -U pgsql -C bugs > checkpoints/bugs.`printf "%06d" $PR_FROM`.sql
    if [ $PR_FROM = 190000 ]; then
        exit 0;
    fi
done
