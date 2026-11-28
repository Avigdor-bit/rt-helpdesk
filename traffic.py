end=$((SECONDS+180))
while [ $SECONDS -lt $end ]; do
  curl -s -o /dev/null 'http://localhost:8000/api/tickets?limit=5'
  curl -s -o /dev/null 'http://localhost:8000/metrics'
  sleep 1
done
