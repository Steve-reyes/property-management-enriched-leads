#!/bin/bash
# Export property management enriched leads and push to GitHub repo
# Usage: ./push_pm_enriched.sh <list_name> <vps_number>
#   vps_number: 1 = VPS1 (local), 3 = VPS3 (87.106.124.206)

CITY=$1
VPS=$2
DATE=$(date +%Y-%m-%d)
REPO_DIR="/root/property-management-enriched-leads"

if [ -z "$CITY" ] || [ -z "$VPS" ]; then
  echo "Usage: $0 <list_name> <vps_number>"
  exit 1
fi

# Export CSV from the right VPS
if [ "$VPS" = "1" ]; then
  b64=$(base64 < /root/property-management-enriched-leads/export_pm_enriched.js | tr -d '\n')
  echo "$b64" | base64 -d | docker exec -i -w /app lead-scraper-backend sh -c 'cat > /app/export_pm_enriched.js && node /app/export_pm_enriched.js "'"$CITY"'"'
  docker cp lead-scraper-backend:/tmp/$(docker exec lead-scraper-backend ls -t /tmp/ | grep "$DATE.*property-management.csv" | head -1) /tmp/ 2>/dev/null
elif [ "$VPS" = "3" ]; then
  b64=$(base64 < /root/property-management-enriched-leads/export_pm_enriched.js | tr -d '\n')
  echo "$b64" | base64 -d | sshpass -p 'LL89eVQkZDWsClRz6xbow4N' ssh -o StrictHostKeyChecking=no root@87.106.124.206 "base64 -d | docker exec -i -w /app lead-scraper-v3-backend sh -c 'cat > /app/export_pm_enriched.js && node /app/export_pm_enriched.js \"$CITY\"'"
  FILENAME=$(sshpass -p 'LL89eVQkZDWsClRz6xbow4N' ssh -o StrictHostKeyChecking=no root@87.106.124.206 "docker exec lead-scraper-v3-backend ls -t /tmp/ | grep '$DATE.*property-management.csv' | head -1")
  sshpass -p 'LL89eVQkZDWsClRz6xbow4N' ssh -o StrictHostKeyChecking=no root@87.106.124.206 "cat /tmp/$FILENAME" > "/tmp/$FILENAME"
fi

# Copy to repo and push
CSV_FILE=$(ls /tmp/*"$DATE"*property-management.csv 2>/dev/null | tail -1)
if [ -z "$CSV_FILE" ]; then
  echo "No CSV found"
  exit 1
fi

cp "$CSV_FILE" "$REPO_DIR/"
cd "$REPO_DIR"
git add -A
LEAD_COUNT=$(tail -n +2 "$(basename "$CSV_FILE")" 2>/dev/null | wc -l)
git config user.name "Scorpio Bot"
git config user.email "scorpio@leadgen.com"
git commit -m "enriched leads $DATE - $CITY ($LEAD_COUNT)"
git push origin main 2>&1 | tail -2
echo "Pushed: $(basename "$CSV_FILE") ($LEAD_COUNT leads)"
