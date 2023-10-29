source .secret

curl -v $URL \
-H "Content-Type: application/json" \
-H "Authorization: Bearer $AUTH_TOKEN" \
-X POST \
-d '{
"genres": "",
"moods": "Funny & Weird",
"themes": "",
"length": 60
}'
