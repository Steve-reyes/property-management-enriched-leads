// Export property management enriched leads to CSV
// Usage: node export_pm_enriched.js "ListName"
// Looks up the enriched group by list_name containing the arg
const D = require('better-sqlite3');
const db = new D('/app/data/leads.db');
const arg = process.argv[2] || 'unknown';
const date = new Date().toISOString().split('T')[0];
const filename = `${date}-${arg.toLowerCase().replace(/[\s,]+/g,'-')}-property-management.csv`.replace(/-+/g,'-');

// Find the enriched group matching this city/name
const group = db.prepare("SELECT * FROM enriched_groups WHERE list_name LIKE ? ORDER BY enriched_at DESC LIMIT 1").get('%'+arg+'%');
if (!group) {
  console.error('No enriched group found for:', arg);
  process.exit(1);
}

console.log('Found group:', group.list_name);
const leads = JSON.parse(group.leads);
// Support both flat ID array and old {id, businessName, ...} format
const leadIds = Array.isArray(leads) ? (typeof leads[0] === 'number' ? leads : leads.map(l => l.id)) : [];
if (!leadIds.length) {
  console.error('No leads in group');
  process.exit(1);
}

const stmt = "SELECT business_name,email,enriched_email,phone,website,address,city,rating,reviews,category FROM leads WHERE id IN ("+leadIds.map(()=>'?').join(',')+")";
console.log('Querying', leadIds.length, 'lead IDs...');
const places = db.prepare(stmt).all(...leadIds);
const csv = ['business_name,email,phone,website,address,city,rating,reviews,category'];
const esc = (s) => (s||'').replace(/"/g,'""');
places.forEach(l => {
  const e = l.email || l.enriched_email || '';
  csv.push('"'+esc(l.business_name)+'","'+esc(e)+'","'+esc(l.phone)+'","'+esc(l.website)+'","'+esc(l.address)+'","'+esc(l.city)+'",'+(l.rating||'')+','+(l.reviews||'')+',"'+esc(l.category)+'"');
});
require('fs').writeFileSync('/tmp/'+filename, csv.join('\n'));
console.log(filename, '-', places.length, 'leads');
