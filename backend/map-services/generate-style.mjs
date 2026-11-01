import { layers, namedFlavor } from '@protomaps/basemaps';
import fs from 'fs';
const flavor = {
  ...namedFlavor('light'),
  background: '#F1F5F9', earth: '#F1F5F9', water: '#BFDBFE', buildings: '#E2E8F0',
  minor: '#FFFFFF', minor_a: '#FFFFFF', major: '#FFFFFF', highway: '#FDE68A',
  park_a: '#D1FAE5', park_b: '#D1FAE5', wood_a: '#DCFCE7', wood_b: '#DCFCE7',
};
const arabicName = ['coalesce', ['get', 'name:ar'], ['get', 'name']];
let ls = layers('protomaps', flavor, { lang: 'ar' });
ls = ls.filter((l) => !(l.layout && l.layout['icon-image']) && !['pois', 'address_label'].includes(l.id));
for (const l of ls) {
  if (!l.layout || !l.layout['text-field']) continue;
  l.layout['text-field'] = arabicName;
  l.layout['text-font'] = [l.id.startsWith('places') ? 'Noto Sans Bold' : 'Noto Sans Regular'];
  l.layout['text-size'] = l.id.startsWith('roads') ? 12.5 : l.layout['text-size'];
  l.layout['text-letter-spacing'] = 0;
  l.layout['text-max-width'] = 8;
}
for (const l of ls) {
  if (l.type === 'symbol' && l.paint) { l.paint['text-color'] = l.id.startsWith('places') ? '#0F172A' : '#475569'; l.paint['text-halo-color'] = '#FFFFFF'; l.paint['text-halo-width'] = 1.6; }
}
const style = { version: 8, name: 'My Lawyer', glyphs: '{fontstack}/{range}.pbf',
  sources: { protomaps: { type: 'vector', url: 'pmtiles://{protomaps}' } }, layers: ls };
fs.writeFileSync('../styles/mylawyer.json', JSON.stringify(style));
console.log('layers', ls.length);
