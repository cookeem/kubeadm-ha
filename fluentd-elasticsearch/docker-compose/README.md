```
cat <<EOF >  /etc/sysctl.d/es.conf
vm.max_map_count = 262144
EOF

sysctl --system

curl localhost:19200/_cat/nodes
curl localhost:19200/_cat/health

echo '
{ "index" : { "_index" : "test", "_type" : "_doc", "_id" : "1" } }
{ "field1" : "value1" }
{ "create" : { "_index" : "test", "_type" : "_doc", "_id" : "2" } }
{ "field1" : "value2" }
{ "create" : { "_index" : "test", "_type" : "_doc", "_id" : "3" } }
{ "field1" : "value3" }
{ "create" : { "_index" : "test", "_type" : "_doc", "_id" : "4" } }
{ "field1" : "value4", "field2": "valuex" }
{ "update" : { "_index" : "test", "_type" : "_doc", "_id" : "1" } }
{ "doc" : {"field2" : "value2"} }
' > test.json

curl -s -H "Content-Type: application/x-ndjson" -XPOST localhost:19200/_bulk --data-binary "@test.json";

curl localhost:19200/test/_search | jq .
```
