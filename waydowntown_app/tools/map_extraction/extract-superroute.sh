#!/bin/bash

get_way_ids() {
    local relation_id=$1
    local url="https://www.openstreetmap.org/api/0.6/relation/${relation_id}.json"
    curl -s "$url" | jq -r '.elements[0].members[] | select(.type == "way") | .ref'
}

get_relation_name() {
    local relation_id=$1
    local url="https://www.openstreetmap.org/api/0.6/relation/${relation_id}.json"
    curl -s "$url" | jq -r '.elements[0].tags.name // "Unnamed Relation \(.elements[0].id)"'
}

root_relation_id=11925427
root_name=$(get_relation_name $root_relation_id)

echo "local walkway_relations = {"
echo "  [\"$root_name\"] = {},"

curl -s "https://www.openstreetmap.org/api/0.6/relation/${root_relation_id}.json" |
jq -r '.elements[0].members[] | select(.type == "relation") | .ref' |
while read -r sub_relation_id; do
    sub_relation_name=$(get_relation_name $sub_relation_id)
    echo "  [\"$sub_relation_name\"] = {"
    get_way_ids $sub_relation_id | while read -r way_id; do
        echo "    \"$way_id\","
    done
    echo "  },"
done

echo "}"
